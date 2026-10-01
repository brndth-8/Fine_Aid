import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import '../../core/navigation/app_navigator.dart';
import '../../core/display_formatters.dart';
import '../healing_reminder_settings.dart';
import '../notification_inbox_store.dart';
import '../../features/journal/screens/entry_detail_screen.dart';

const String _healingCheckInPayloadPrefix = 'healing_checkin:';
const String _lastSeenAnnouncementPrefsKey = 'last_seen_system_announcement_ms';
const String _askedNotificationPermissionPrefsKey =
    'asked_notification_permission';

const String healingMilestoneTitle = 'Healing Milestone Reminder';
const String healingMilestoneDefaultBody =
    'You have reached your healing time frame. Are you feeling better?';

/// The exact required notification body — the default sentence, or with
/// the wound type folded in when available. [woundTypeLabel] must already
/// be a display-ready label (see core/display_formatters.dart), never a
/// raw code.
String healingMilestoneBody(String? woundTypeLabel) {
  if (woundTypeLabel == null || woundTypeLabel.trim().isEmpty) {
    return healingMilestoneDefaultBody;
  }
  return 'Your $woundTypeLabel has reached its healing time frame. Are '
      'you feeling better?';
}

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
    // function isn't deployed yet. Timed out and swallowed so a slow or
    // absent connection at first launch can never block app startup on
    // this alone (see main() for the outer safety net too).
    try {
      await _messaging
          .subscribeToTopic('all_users')
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('NotificationService: subscribeToTopic failed/timed out: $e');
    }
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
    // Deliberately NOT requesting the Android 13+ POST_NOTIFICATIONS
    // permission here — asking for it unexplained at app startup, before
    // the user has done anything that would need it, is exactly the "bad
    // time" this permission model is meant to be requested away from. See
    // ensureHealingReminderPermission, called right before the first
    // healing reminder is actually scheduled, which asks with a rationale
    // instead.

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
  int _endReminderId(String entryId) => entryId.hashCode & 0x7fffffff;
  int _halfwayReminderId(String entryId) =>
      (entryId.hashCode ^ 0x5A5A5A5A) & 0x7fffffff;

  DateTime _atNineAm(DateTime date) =>
      DateTime(date.year, date.month, date.day, 9);

  /// Schedules the required end-of-timeframe healing reminder, plus an
  /// optional halfway-point nudge when there's a meaningful gap before it.
  /// [classification] must already be a display-ready label (eg "Burn" —
  /// assessment.category / First Aid Kit's category.title both already
  /// are), never a raw code. No-ops entirely if the user has turned
  /// healing reminders off in Settings.
  Future<void> scheduleHealingCheckIn({
    required String entryId,
    required String classification,
    required int healingDays,
  }) async {
    if (!await HealingReminderSettings.instance.isEnabled()) return;

    final now = DateTime.now();
    final endDate = _atNineAm(now.add(Duration(days: healingDays)));
    await _scheduleOneHealingReminder(
      id: _endReminderId(entryId),
      entryId: entryId,
      classification: classification,
      scheduledDate: endDate,
      isHalfway: false,
    );

    final halfwayDays = healingDays ~/ 2;
    if (halfwayDays >= 1 && halfwayDays < healingDays) {
      final halfwayDate = _atNineAm(now.add(Duration(days: halfwayDays)));
      await _scheduleOneHealingReminder(
        id: _halfwayReminderId(entryId),
        entryId: entryId,
        classification: classification,
        scheduledDate: halfwayDate,
        isHalfway: true,
      );
    }
  }

  /// Cancels and re-schedules from scratch — call this when a journal
  /// entry's healing estimate changes (eg the classification was
  /// corrected) so the reminder still lands on the right day.
  Future<void> rescheduleHealingCheckIn({
    required String entryId,
    required String classification,
    required int healingDays,
  }) async {
    await cancelHealingCheckIn(entryId);
    await scheduleHealingCheckIn(
      entryId: entryId,
      classification: classification,
      healingDays: healingDays,
    );
  }

  Future<void> _scheduleOneHealingReminder({
    required int id,
    required String entryId,
    required String classification,
    required DateTime scheduledDate,
    required bool isHalfway,
  }) async {
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
          'not_yet',
          'Not Yet',
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          'getting_worse',
          'It\'s Worse',
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

    final title = isHalfway
        ? 'Healing Progress Check-In'
        : healingMilestoneTitle;
    final body = isHalfway
        ? 'You\'re halfway through your $classification healing time '
              'frame — how is it going?'
        : healingMilestoneBody(classification);

    await _localNotifications.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tzDate,
      notificationDetails: details,
      androidScheduleMode: canScheduleExact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      payload: '$_healingCheckInPayloadPrefix$entryId',
    );

    // Logged the moment it's SCHEDULED, not delivered — flutter_local_
    // notifications has no "on displayed" hook for a scheduled local
    // notification the user never taps. scheduledFor keeps it hidden from
    // the visible inbox list until that time actually passes (see
    // AppNotification.isVisible), so in practice it still only appears
    // once it would have fired — even if the user swiped it from the
    // tray, and even offline, since this is pure local storage.
    await NotificationInboxStore.instance.add(
      AppNotification(
        id: 'healing_${entryId}_${isHalfway ? 'halfway' : 'end'}',
        type: AppNotificationType.healingMilestone,
        title: title,
        body: body,
        createdAt: DateTime.now(),
        scheduledFor: scheduledDate,
        entryId: entryId,
        woundTypeLabel: classification,
      ),
    );
  }

  Future<void> cancelHealingCheckIn(String entryId) async {
    await _localNotifications.cancel(id: _endReminderId(entryId));
    await _localNotifications.cancel(id: _halfwayReminderId(entryId));
    await NotificationInboxStore.instance.removePendingForEntry(entryId);
  }

  /// "Not yet" from either the push notification's action button or the
  /// in-app check-in dialog — the entry stays active (no milestoneResponded
  /// write) and gets one more nudge tomorrow at 9am.
  Future<void> remindHealingCheckInTomorrow({
    required String entryId,
    required String classification,
  }) => _scheduleNextDayReminder(entryId, classification);

  Future<void> _scheduleNextDayReminder(
    String entryId,
    String classification,
  ) async {
    final date = _atNineAm(DateTime.now().add(const Duration(days: 1)));
    await _scheduleOneHealingReminder(
      id: _endReminderId(entryId),
      entryId: entryId,
      classification: classification,
      scheduledDate: date,
      isHalfway: false,
    );
  }

  static Future<String> _classificationFor(String uid, String entryId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('journalEntries')
          .doc(entryId)
          .get()
          .timeout(const Duration(seconds: 10));
      final raw = doc.data()?['classification'] as String?;
      return (raw == null || raw.isEmpty) ? woundTypeDisplayLabel('none') : raw;
    } catch (_) {
      return 'this issue';
    }
  }

  /// Public entry point for recording a "Yes"/"It's getting worse"
  /// check-in answer from anywhere in the app (the journal entry screen's
  /// own dialog, or the Notifications inbox's detail view) — always
  /// cancels the entry's remaining scheduled reminders too, since both
  /// answers mean no more nudges are needed. No-ops silently if the user
  /// isn't signed in (a guest can't have a saved entry to respond about).
  Future<void> recordHealingMilestoneResponse({
    required String entryId,
    required bool feelingBetter,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await _updateMilestoneResponse(
      user.uid,
      entryId,
      responded: true,
      feelingBetter: feelingBetter,
    );
    await cancelHealingCheckIn(entryId);
  }

  static Future<void> _updateMilestoneResponse(
    String uid,
    String entryId, {
    required bool responded,
    required bool feelingBetter,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('journalEntries')
          .doc(entryId)
          .update({
            'milestoneResponded': responded,
            'feelingBetter': feelingBetter,
          })
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      // Firestore's offline cache still queues this for later sync even if
      // the call above throws for another reason; nothing else to do here.
    }
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

    const validActions = {'feeling_better', 'not_yet', 'getting_worse'};
    if (actionId == null || !validActions.contains(actionId)) {
      // A plain tap on the notification body (no action button) has no
      // check-in answer to record — just take the user to the entry so
      // they can respond in-app instead.
      await _navigateToJournalEntry(entryId);
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // This just relays the user's own answer back to them — never a
    // clinical judgment about whether the wound is actually improving or
    // worsening, since this check-in is a preliminary prompt, not a
    // diagnosis. "It's Worse" is the one case that explicitly recommends
    // professional care, per the required wording.
    String resultBody;
    switch (actionId) {
      case 'feeling_better':
        await _updateMilestoneResponse(
          user.uid,
          entryId,
          responded: true,
          feelingBetter: true,
        );
        await NotificationService().cancelHealingCheckIn(entryId);
        resultBody = 'You told us you\'re feeling better. Glad to hear it!';
        break;
      case 'getting_worse':
        await _updateMilestoneResponse(
          user.uid,
          entryId,
          responded: true,
          feelingBetter: false,
        );
        await NotificationService().cancelHealingCheckIn(entryId);
        resultBody = 'We recommend seeking professional consultation.';
        break;
      case 'not_yet':
      default:
        final classification = await _classificationFor(user.uid, entryId);
        await NotificationService()._scheduleNextDayReminder(
          entryId,
          classification,
        );
        resultBody = 'No problem — we\'ll check in again tomorrow.';
        break;
    }

    await NotificationService()._logNotification(
      title: healingMilestoneTitle,
      body: resultBody,
      entryId: entryId,
      type: AppNotificationType.healingMilestone,
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

  /// Logs a just-delivered notification to the local inbox (always, so it
  /// works offline and for guests) and, when signed in, to Firestore too
  /// (so a logged-in user's read state can sync across devices — see
  /// NotificationsScreen). [type] defaults to reminder for callers that
  /// don't set it explicitly.
  Future<void> _logNotification({
    required String title,
    required String body,
    String? entryId,
    AppNotificationType type = AppNotificationType.reminder,
    String? woundTypeLabel,
  }) async {
    final id =
        '${type.name}_${entryId ?? DateTime.now().microsecondsSinceEpoch}';
    await NotificationInboxStore.instance.add(
      AppNotification(
        id: id,
        type: type,
        title: title,
        body: body,
        createdAt: DateTime.now(),
        entryId: entryId,
        woundTypeLabel: woundTypeLabel,
      ),
    );

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
            'type': type.name,
            'read': false,
            'createdAt': FieldValue.serverTimestamp(),
          })
          .timeout(const Duration(seconds: 10));
    } catch (_) {}
  }

  /// Requests local-notification permission at the point it actually
  /// matters (right before the first healing reminder would be scheduled)
  /// rather than blindly at app startup, and explains why first — only
  /// ever asks once per install; later calls just report the current
  /// status without nagging again. Safe to call on any platform (no-op
  /// off Android, where this permission concept doesn't apply the same
  /// way). Returns true if reminders can be scheduled.
  Future<bool> ensureHealingReminderPermission(BuildContext context) async {
    if (!Platform.isAndroid) return true;

    final status = await Permission.notification.status;
    if (status.isGranted) return true;

    final prefs = await SharedPreferences.getInstance();
    final alreadyAsked =
        prefs.getBool(_askedNotificationPermissionPrefsKey) ?? false;

    if (status.isPermanentlyDenied || (alreadyAsked && status.isDenied)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Reminders are off. Enable notifications in Settings to get '
              'healing check-in reminders.',
            ),
            action: SnackBarAction(
              label: 'Open Settings',
              onPressed: openAppSettings,
            ),
          ),
        );
      }
      return false;
    }

    if (!alreadyAsked && context.mounted) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Allow reminders?'),
          content: const Text(
            'Fine Aid can remind you when a saved wound reaches its '
            'expected healing time, so you can check whether it\'s '
            'getting better.',
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Not now'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Allow'),
            ),
          ],
        ),
      );
      await prefs.setBool(_askedNotificationPermissionPrefsKey, true);
      if (proceed != true) return false;
    }

    final result = await Permission.notification.request();
    return result.isGranted;
  }
}
