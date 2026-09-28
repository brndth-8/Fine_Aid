import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import '../../core/navigation/app_navigator.dart';
import '../../features/journal/screens/entry_detail_screen.dart';

const String _healingCheckInPayloadPrefix = 'healing_checkin:';
const String _lastSeenAnnouncementPrefsKey = 'last_seen_system_announcement_ms';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _announcementSubscription;

  Future<void> initialize() async {
    await _messaging.requestPermission(alert: true, badge: true, sound: true);
    // Lets a deployed sendSystemNotificationPush Cloud Function reach every
    // install via FCM without needing a per-device token registry — the
    // function just sends to this topic. Harmless to call even while that
    // function isn't deployed yet.
    await _messaging.subscribeToTopic('all_users');
    tz_data.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initSettings = InitializationSettings(android: androidSettings);
    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    const channel = AndroidNotificationChannel(
      'fine_aid_reminders',
      'Fine Aid Reminders',
      description: 'Healing milestone and journal reminders',
      importance: Importance.high,
    );

    final androidImplementation = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidImplementation?.createNotificationChannel(channel);
    // Belt-and-suspenders alongside the FCM permission request above:
    // flutter_local_notifications' scheduled reminders (the healing
    // check-in) are a separate code path from FCM push and need this same
    // Android 13+ runtime permission explicitly requested too, or they
    // silently never show.
    await androidImplementation?.requestNotificationsPermission();

    // Deliver a response for the notification that launched the app (the
    // user tapped an action while the app was fully closed) once the
    // handler above is wired up, instead of it being silently dropped.
    // Deliberately not awaited: this call itself waits for the navigator
    // to attach, which only happens once runApp() below has run — awaiting
    // it here would deadlock main() against its own prerequisite.
    final launchDetails = await _localNotifications
        .getNotificationAppLaunchDetails();
    final launchResponse = launchDetails?.notificationResponse;
    if (launchDetails?.didNotificationLaunchApp == true &&
        launchResponse != null) {
      unawaited(_onNotificationResponse(launchResponse));
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showLocalNotification(message);
    });
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    const androidDetails = AndroidNotificationDetails(
      'fine_aid_reminders',
      'Fine Aid Reminders',
      channelDescription: 'Healing milestone and journal reminders',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      id: message.hashCode,
      title: message.notification?.title ?? 'Fine Aid',
      body: message.notification?.body ?? '',
      notificationDetails: details,
    );
  }

  //It would be stored once we upgrade Blaze plan
  Future<String?> getToken() async {
    return await _messaging.getToken();
  }

  // Pops a local notification while the app is open whenever the admin
  // panel sends a new system announcement. There's no deployed Cloud
  // Function to fan these out as true push notifications while the app is
  // fully closed (see the Forgot Password OTP functions for the same
  // build-but-don't-deploy precedent), so this covers the foreground case;
  // any announcement sent while the app was closed is still visible next
  // time the Notifications screen is opened, since it reads the same
  // shared collection directly. Safe to call more than once per app
  // lifetime — later calls are no-ops while a subscription is active.
  Future<void> listenForSystemAnnouncements() async {
    if (_announcementSubscription != null) return;

    final prefs = await SharedPreferences.getInstance();
    var lastSeenMs = prefs.getInt(_lastSeenAnnouncementPrefsKey);
    if (lastSeenMs == null) {
      // First time this device has ever listened — don't replay the whole
      // announcement history as a flood of popups, only what comes next.
      lastSeenMs = DateTime.now().millisecondsSinceEpoch;
      await prefs.setInt(_lastSeenAnnouncementPrefsKey, lastSeenMs);
    }

    _announcementSubscription = FirebaseFirestore.instance
        .collection('systemNotifications')
        .orderBy('sentAt', descending: true)
        .limit(5)
        .snapshots()
        .listen((snapshot) async {
          var newestMs = lastSeenMs!;
          for (final doc in snapshot.docs) {
            final sentAt = doc.data()['sentAt'] as Timestamp?;
            if (sentAt == null) continue;
            final ms = sentAt.millisecondsSinceEpoch;
            if (ms <= lastSeenMs!) continue;
            if (ms > newestMs) newestMs = ms;

            const androidDetails = AndroidNotificationDetails(
              'fine_aid_reminders',
              'Fine Aid Reminders',
              channelDescription: 'Healing milestone and journal reminders',
              importance: Importance.high,
              priority: Priority.high,
            );
            const details = NotificationDetails(android: androidDetails);
            await _localNotifications.show(
              id: doc.id.hashCode & 0x7fffffff,
              title: doc.data()['title'] as String? ?? 'Fine Aid Update',
              body: doc.data()['body'] as String? ?? '',
              notificationDetails: details,
            );
          }
          if (newestMs != lastSeenMs) {
            lastSeenMs = newestMs;
            await prefs.setInt(_lastSeenAnnouncementPrefsKey, newestMs);
          }
        });
  }

  void stopListeningForSystemAnnouncements() {
    _announcementSubscription?.cancel();
    _announcementSubscription = null;
  }

  // Schedules a local, on-device reminder for the moment a journal entry's
  // typical healing timeframe elapses. This is entirely local (no network
  // call), so it fires and can be responded to even while offline; the
  // resulting Firestore write in _onNotificationResponse queues via the
  // app's existing offline persistence and syncs once connectivity returns.
  Future<void> scheduleHealingCheckIn({
    required String entryId,
    required String classification,
    required DateTime scheduledDate,
  }) async {
    final id = entryId.hashCode & 0x7fffffff;
    final tzDate = tz.TZDateTime.from(scheduledDate, tz.UTC);

    const androidDetails = AndroidNotificationDetails(
      'fine_aid_reminders',
      'Fine Aid Reminders',
      channelDescription: 'Healing milestone and journal reminders',
      importance: Importance.high,
      priority: Priority.high,
      actions: [
        AndroidNotificationAction(
          'feeling_better',
          'Feeling Better',
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          'wound_worsened',
          'Wound Worsened',
          showsUserInterface: true,
        ),
      ],
    );
    const details = NotificationDetails(android: androidDetails);

    // Use exact scheduling when the OS already permits it — inexact
    // delivery can drift by a long margin (sometimes hours) under Doze/
    // battery-optimization, which is especially aggressive on some OEM
    // skins. Never prompts for the exact-alarm permission here (that opens
    // a system settings screen), so this only upgrades reliability when
    // it's already available and otherwise keeps working as before.
    final androidImplementation = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final canScheduleExact =
        await androidImplementation?.canScheduleExactNotifications() ?? false;

    await _localNotifications.zonedSchedule(
      id: id,
      title: 'Healing Progress Check-In',
      body:
          'It\'s been a while since your $classification entry — how is it '
          'healing?',
      scheduledDate: tzDate,
      notificationDetails: details,
      androidScheduleMode: canScheduleExact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      payload: '$_healingCheckInPayloadPrefix$entryId',
    );
  }

  Future<void> cancelHealingCheckIn(String entryId) async {
    await _localNotifications.cancel(id: entryId.hashCode & 0x7fffffff);
  }

  @pragma('vm:entry-point')
  static Future<void> _onNotificationResponse(
    NotificationResponse response,
  ) async {
    final payload = response.payload;
    if (payload == null || !payload.startsWith(_healingCheckInPayloadPrefix)) {
      return;
    }
    final entryId = payload.substring(_healingCheckInPayloadPrefix.length);
    final actionId = response.actionId;

    // A plain tap on the notification body (no action button) has no
    // check-in answer to record — just take the user to the entry it's
    // about, exactly like tapping an action does after recording the
    // answer below.
    if (actionId != 'feeling_better' && actionId != 'wound_worsened') {
      await _navigateToJournalEntry(entryId);
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final feelingBetter = actionId == 'feeling_better';

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('journalEntries')
          .doc(entryId)
          .update({'milestoneResponded': true, 'feelingBetter': feelingBetter});
    } catch (_) {
      // Firestore's offline cache still queues this for later sync even if
      // the call above throws for another reason; nothing else to do here.
    }

    // This just relays the user's own answer back to them — never a
    // clinical judgment about whether the wound is actually improving or
    // worsening, since this check-in is a preliminary prompt, not a
    // diagnosis.
    await NotificationService()._logNotification(
      title: 'Healing Progress Check-In',
      body: feelingBetter
          ? 'You told us you\'re feeling better. Glad to hear it!'
          : 'You told us you\'re not feeling better yet — consider having '
                'this looked at by a professional.',
      entryId: entryId,
    );

    await _navigateToJournalEntry(entryId);
  }

  /// Opens the specific journal entry a notification (or its action) was
  /// about, fetching the entry's current data first since EntryDetailScreen
  /// needs it up front. Best-effort: if the navigator isn't attached yet
  /// (eg this ran before the widget tree finished its first build) or the
  /// entry can't be read, this silently does nothing rather than crash —
  /// the entry is still reachable normally from the Health Journal list.
  static Future<void> _navigateToJournalEntry(String entryId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('journalEntries')
          .doc(entryId)
          .get()
          .timeout(const Duration(seconds: 10));
      if (!doc.exists) return;

      // A cold start (app was fully closed, this tap is what launched it)
      // runs this before runApp() has built the widget tree, so the
      // navigator isn't attached yet — briefly poll for it rather than
      // giving up immediately, since this only runs once at startup.
      NavigatorState? state = navigatorKey.currentState;
      var attempts = 0;
      while (state == null && attempts < 20) {
        await Future.delayed(const Duration(milliseconds: 200));
        state = navigatorKey.currentState;
        attempts++;
      }
      if (state == null) return;

      state.push(
        MaterialPageRoute(
          builder: (context) =>
              EntryDetailScreen(entryId: entryId, data: doc.data()!),
        ),
      );
    } catch (_) {
      // Nothing else to do — see doc comment above.
    }
  }

  Future<void> _logNotification({
    required String title,
    required String body,
    String? entryId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .add({
            'title': title,
            'body': body,
            'entryId': entryId,
            'read': false,
            'createdAt': FieldValue.serverTimestamp(),
          })
          .timeout(const Duration(seconds: 10));
    } catch (_) {}
  }
}
