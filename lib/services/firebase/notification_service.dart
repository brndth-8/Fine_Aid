import 'dart:async';
import 'dart:io';
import 'dart:ui' show DartPluginRegistrant;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import '../../core/navigation/app_navigator.dart';
import '../../data/healing_durations.dart';
import '../../firebase_options.dart';
import '../../i18n/notification_strings.dart';
import '../notification_inbox_store.dart';
import '../../features/journal/screens/entry_detail_screen.dart';
import '../../features/journal/screens/journal_list_screen.dart';

const String _healingCheckInPayloadPrefix = 'healing_checkin:';
const String _lastSeenAnnouncementPrefsKey = 'last_seen_system_announcement_ms';
const String _askedNotificationPermissionPrefsKey =
    'asked_notification_permission';
// The account the device's scheduled notifications currently belong to.
const String _activeUidPrefsKey = 'notif_active_uid';
// Set once the one-time cleanup of reminders scheduled by older app versions
// (which weren't tied to an account) has run.
const String _accountScopedPrefsKey = 'notif_account_scoped_v1';

/// The three quick-action buttons on the check-in notification.
const String kActionFeelingBetter = 'feeling_better';
const String kActionNotYet = 'not_yet';
const String kActionWorse = 'getting_worse';

/// A check-in notification's payload: which account it belongs to and which
/// journal entry it is about — `healing_checkin:<uid>:<entryId>`.
class HealingPayload {
  final String uid;
  final String entryId;
  const HealingPayload(this.uid, this.entryId);
}

String buildHealingPayload(String uid, String entryId) =>
    '$_healingCheckInPayloadPrefix$uid:$entryId';

/// Reads a check-in payload. Returns null for anything else — including the
/// older `healing_checkin:<entryId>` format that had no account in it, which
/// can't be tied to a user and is therefore ignored.
HealingPayload? parseHealingPayload(String? payload) {
  if (payload == null || !payload.startsWith(_healingCheckInPayloadPrefix)) {
    return null;
  }
  final rest = payload.substring(_healingCheckInPayloadPrefix.length);
  final split = rest.indexOf(':');
  if (split <= 0 || split == rest.length - 1) return null;
  return HealingPayload(rest.substring(0, split), rest.substring(split + 1));
}

/// Runs when a notification action button that doesn't open the app (Yes /
/// No) is tapped — possibly while the app is closed, in its own background
/// process, so it has to start Firebase itself.
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  unawaited(_handleBackgroundResponse(response));
}

Future<void> _handleBackgroundResponse(NotificationResponse response) async {
  try {
    DartPluginRegistrant.ensureInitialized();
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    await NotificationService.processNotificationResponse(
      response,
      inBackground: true,
    );
  } catch (e) {
    debugPrint('Background notification response failed: $e');
  }
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

  static const AndroidInitializationSettings _androidInit =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  static const InitializationSettings _initSettings = InitializationSettings(
    android: _androidInit,
  );

  Future<void> initialize() async {
    await _messaging.requestPermission(alert: true, badge: true, sound: true);
    // The "all_users" announcement topic is joined only while someone is
    // signed in (see handleAuthChange) — a guest gets no announcements.
    tz_data.initializeTimeZones();

    await _localNotifications.initialize(
      settings: _initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
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
    // user tapped it while the app was fully closed) once the handler above
    // is wired up, instead of it being silently dropped.
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
      // Announcements are for signed-in users only.
      if (FirebaseAuth.instance.currentUser == null) return;
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

  // Account isolation

  Future<void> _authChain = Future.value();

  /// Call whenever the signed-in account changes (including at startup).
  /// Notifications belong to the account that created them, so when the
  /// account changes — sign out, or a different user signs in — every
  /// scheduled and displayed notification of the previous account is
  /// cancelled and the inbox is switched to the new account's own. A guest
  /// (user == null) has no notifications at all. On sign-in, only that
  /// account's own reminders are scheduled again, from its journal.
  Future<void> handleAuthChange(User? user) {
    _authChain = _authChain
        .then((_) => _applyAuthChange(user))
        .catchError((Object e) => debugPrint('handleAuthChange failed: $e'));
    return _authChain;
  }

  Future<void> _applyAuthChange(User? user) async {
    final prefs = await SharedPreferences.getInstance();
    final previous = prefs.getString(_activeUidPrefsKey);
    final current = user?.uid;
    final firstRunOfThisVersion =
        !(prefs.getBool(_accountScopedPrefsKey) ?? false);

    if (previous != current || firstRunOfThisVersion) {
      // Also covers reminders scheduled by older versions, which carried no
      // account — they are cancelled once; the signed-in user's own are
      // re-created below from their journal.
      await _localNotifications.cancelAll();
    }
    await NotificationInboxStore.instance.bindToUser(current);

    // Admin announcements (FCM topic) are for signed-in users only.
    try {
      if (current != null) {
        await _messaging
            .subscribeToTopic('all_users')
            .timeout(const Duration(seconds: 5));
      } else if (previous != null || firstRunOfThisVersion) {
        await _messaging
            .unsubscribeFromTopic('all_users')
            .timeout(const Duration(seconds: 5));
      }
    } catch (e) {
      debugPrint('NotificationService: topic change failed/timed out: $e');
    }

    if (current == null) {
      await prefs.remove(_activeUidPrefsKey);
    } else {
      await prefs.setString(_activeUidPrefsKey, current);
    }
    await prefs.setBool(_accountScopedPrefsKey, true);

    if (current != null && (previous != current || firstRunOfThisVersion)) {
      unawaited(resyncRemindersForUser(current));
    }
  }

  /// Re-creates the check-in reminders of [uid]'s own journal entries that
  /// asked for one ("Remind me") and haven't been answered. An entry whose
  /// time has already passed gets its check-in at the next 9am.
  Future<void> resyncRemindersForUser(String uid) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('journalEntries')
          .where('remindMe', isEqualTo: true)
          .get()
          .timeout(const Duration(seconds: 20));
      for (final doc in snapshot.docs) {
        // The account changed again while this was running — stop.
        if (FirebaseAuth.instance.currentUser?.uid != uid) return;
        final data = doc.data();
        if (data['milestoneResponded'] == true) continue;
        final classification = data['classification'] as String?;
        final days = classification == null
            ? null
            : healingDurationDays[classification];
        if (classification == null || days == null) continue;
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        await _scheduleCheckInSeries(
          uid: uid,
          entryId: doc.id,
          classification: classification,
          healingDays: days,
          from: createdAt ?? DateTime.now(),
          nextMorningIfOverdue: true,
        );
      }
    } catch (e) {
      debugPrint('resyncRemindersForUser failed: $e');
    }
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

  // Scheduling

  // Schedules a local, on-device reminder for the moment a journal entry's
  // typical healing timeframe elapses. This is entirely local (no network
  // call), so it fires and can be responded to even while offline; the
  // resulting Firestore write when the user answers queues via the app's
  // existing offline persistence and syncs once connectivity returns.
  int _endReminderId(String entryId) => entryId.hashCode & 0x7fffffff;
  int _halfwayReminderId(String entryId) =>
      (entryId.hashCode ^ 0x5A5A5A5A) & 0x7fffffff;
  int _resultReminderId(String entryId) =>
      (entryId.hashCode ^ 0x3C3C3C3C) & 0x7fffffff;

  DateTime _atNineAm(DateTime date) =>
      DateTime(date.year, date.month, date.day, 9);

  DateTime _nextNineAm() {
    final now = DateTime.now();
    final today = _atNineAm(now);
    return today.isAfter(now) ? today : today.add(const Duration(days: 1));
  }

  /// Schedules the end-of-timeframe check-in for the signed-in user's entry,
  /// plus a halfway-point nudge when there's a meaningful gap before it.
  /// Does nothing for a guest — guests get no notifications. The caller
  /// decides whether the user asked for it ("Remind me").
  Future<void> scheduleHealingCheckIn({
    required String entryId,
    required String classification,
    required int healingDays,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await _scheduleCheckInSeries(
      uid: user.uid,
      entryId: entryId,
      classification: classification,
      healingDays: healingDays,
      from: DateTime.now(),
    );
  }

  Future<void> _scheduleCheckInSeries({
    required String uid,
    required String entryId,
    required String classification,
    required int healingDays,
    required DateTime from,
    bool nextMorningIfOverdue = false,
  }) async {
    final now = DateTime.now();
    final endDate = _atNineAm(from.add(Duration(days: healingDays)));
    if (endDate.isAfter(now)) {
      await _scheduleOneHealingReminder(
        id: _endReminderId(entryId),
        uid: uid,
        entryId: entryId,
        classification: classification,
        scheduledDate: endDate,
        isHalfway: false,
      );
    } else if (nextMorningIfOverdue) {
      await _scheduleOneHealingReminder(
        id: _endReminderId(entryId),
        uid: uid,
        entryId: entryId,
        classification: classification,
        scheduledDate: _nextNineAm(),
        isHalfway: false,
      );
    }

    final halfwayDays = healingDays ~/ 2;
    if (halfwayDays >= 1 && halfwayDays < healingDays) {
      final halfwayDate = _atNineAm(from.add(Duration(days: halfwayDays)));
      if (halfwayDate.isAfter(now)) {
        await _scheduleOneHealingReminder(
          id: _halfwayReminderId(entryId),
          uid: uid,
          entryId: entryId,
          classification: classification,
          scheduledDate: halfwayDate,
          isHalfway: true,
        );
      }
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
    required String uid,
    required String entryId,
    required String classification,
    required DateTime scheduledDate,
    required bool isHalfway,
  }) async {
    final tzDate = tz.TZDateTime.from(scheduledDate, tz.UTC);
    final text = await NotificationStrings.load();

    // Three quick answers, tapped straight from the notification. They don't
    // open the app (showsUserInterface: false) — the answer is saved in the
    // background.
    final androidDetails = AndroidNotificationDetails(
      'fine_aid_reminders',
      'Fine Aid Reminders',
      channelDescription: 'Healing milestone and journal reminders',
      importance: Importance.high,
      priority: Priority.high,
      actions: [
        AndroidNotificationAction(
          kActionFeelingBetter,
          text.actionBetter,
          showsUserInterface: false,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          kActionNotYet,
          text.actionNotYet,
          showsUserInterface: false,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          kActionWorse,
          text.actionWorse,
          showsUserInterface: false,
          cancelNotification: true,
        ),
      ],
    );
    final details = NotificationDetails(android: androidDetails);

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

    // Neutral wording on purpose: a check-in question only, never a claim
    // about the wound.
    await _localNotifications.zonedSchedule(
      id: id,
      title: text.checkInTitle,
      body: text.checkInBody,
      scheduledDate: tzDate,
      notificationDetails: details,
      androidScheduleMode: canScheduleExact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      payload: buildHealingPayload(uid, entryId),
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
        title: text.checkInTitle,
        body: text.checkInBody,
        createdAt: DateTime.now(),
        scheduledFor: scheduledDate,
        entryId: entryId,
        woundTypeLabel: classification,
      ),
    );
  }

  /// Cancels the entry's scheduled check-ins (and drops their not-yet-due
  /// inbox rows).
  Future<void> cancelHealingCheckIn(String entryId) async {
    await _cancelScheduled(entryId);
    await NotificationInboxStore.instance.removePendingForEntry(entryId);
  }

  Future<void> _cancelScheduled(String entryId) async {
    await _localNotifications.cancel(id: _endReminderId(entryId));
    await _localNotifications.cancel(id: _halfwayReminderId(entryId));
  }

  // Answers and taps

  /// Public entry point for recording a "Yes" / "No" check-in answer from
  /// inside the app (the journal entry's own dialog, or the Notifications
  /// inbox's detail view). Both answers stop the entry's remaining
  /// reminders. No-ops silently if the user isn't signed in.
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
  static Future<void> _onNotificationResponse(NotificationResponse response) =>
      processNotificationResponse(response, inBackground: false);

  /// Handles a tap on a check-in notification or one of its buttons.
  ///
  /// - **Feeling Better / Not Yet / It's Worse button:** saved to the
  ///   notification's own account only (ignored if a different account is
  ///   signed in now). "Not Yet" nudges again tomorrow; the other two stop
  ///   further reminders, and "It's Worse" also shows a recommendation to
  ///   get checked by a professional.
  /// - **Tap on the notification:** opens that journal entry, or the journal
  ///   list with a short message if the entry no longer exists / isn't this
  ///   account's.
  static Future<void> processNotificationResponse(
    NotificationResponse response, {
    required bool inBackground,
  }) async {
    final payload = parseHealingPayload(response.payload);
    if (payload == null) return;
    final actionId = response.actionId;
    final user = await _currentUserWhenReady();

    if (actionId == kActionFeelingBetter ||
        actionId == kActionNotYet ||
        actionId == kActionWorse) {
      if (user == null || user.uid != payload.uid) return;
      await NotificationService()._answerCheckIn(
        uid: user.uid,
        entryId: payload.entryId,
        action: actionId!,
        inBackground: inBackground,
      );
      return;
    }

    // A plain tap: take the user to the entry (needs the app's UI).
    if (inBackground) return;
    await _openEntryFromTap(payload, user);
  }

  Future<void> _answerCheckIn({
    required String uid,
    required String entryId,
    required String action,
    required bool inBackground,
  }) async {
    if (inBackground) {
      // A separate background process: set up the plugin and timezones here.
      await _localNotifications.initialize(settings: _initSettings);
      tz_data.initializeTimeZones();
    }

    // "Not yet": the entry stays active (nothing is saved) and gets one more
    // check-in tomorrow at 9am.
    if (action == kActionNotYet) {
      await _scheduleTomorrow(
        uid: uid,
        entryId: entryId,
        classification: await _classificationFor(uid, entryId),
      );
      return;
    }

    final feelingBetter = action == kActionFeelingBetter;
    await _updateMilestoneResponse(
      uid,
      entryId,
      responded: true,
      feelingBetter: feelingBetter,
    );

    if (inBackground) {
      // Cancel the OS-level reminders directly, and leave a note for the app
      // to clear the matching inbox rows next time it opens (see
      // NotificationInboxStore.applyAnswered).
      await _cancelScheduled(entryId);
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.reload();
        final ids = prefs.getStringList(kAnsweredEntriesPrefsKey) ?? <String>[];
        if (!ids.contains(entryId)) ids.add(entryId);
        await prefs.setStringList(kAnsweredEntriesPrefsKey, ids);
      } catch (_) {}
    } else {
      await cancelHealingCheckIn(entryId);
    }

    if (feelingBetter) return;

    // "It's Worse": a recommendation (not a diagnosis). Tapping it opens the
    // entry.
    final text = await NotificationStrings.load();
    const androidDetails = AndroidNotificationDetails(
      'fine_aid_reminders',
      'Fine Aid Reminders',
      channelDescription: 'Healing milestone and journal reminders',
      importance: Importance.high,
      priority: Priority.high,
    );
    await _localNotifications.show(
      id: _resultReminderId(entryId),
      title: text.checkInTitle,
      body: text.seeProfessional,
      notificationDetails: const NotificationDetails(android: androidDetails),
      payload: buildHealingPayload(uid, entryId),
    );
    await _logNotification(
      uid: uid,
      title: text.checkInTitle,
      body: text.seeProfessional,
      entryId: entryId,
      type: AppNotificationType.healingMilestone,
      toLocalInbox: !inBackground,
    );
  }

  Future<void> _scheduleTomorrow({
    required String uid,
    required String entryId,
    required String classification,
  }) {
    final date = _atNineAm(DateTime.now().add(const Duration(days: 1)));
    return _scheduleOneHealingReminder(
      id: _endReminderId(entryId),
      uid: uid,
      entryId: entryId,
      classification: classification,
      scheduledDate: date,
      isHalfway: false,
    );
  }

  /// "Not yet" from the in-app check-in or the Notifications inbox: the entry
  /// stays active (no response is saved) and gets one more nudge tomorrow at
  /// 9am. No-ops for a guest.
  Future<void> remindHealingCheckInTomorrow({
    required String entryId,
    required String classification,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await _scheduleTomorrow(
      uid: user.uid,
      entryId: entryId,
      classification: classification,
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
      return (raw == null || raw.isEmpty) ? 'this issue' : raw;
    } catch (_) {
      return 'this issue';
    }
  }

  /// The signed-in user, waiting briefly for Firebase to restore the
  /// session when the app has only just started (eg launched by a tap).
  static Future<User?> _currentUserWhenReady() async {
    final current = FirebaseAuth.instance.currentUser;
    if (current != null) return current;
    try {
      return await FirebaseAuth.instance.authStateChanges().first.timeout(
        const Duration(seconds: 5),
      );
    } catch (_) {
      return FirebaseAuth.instance.currentUser;
    }
  }

  static Future<NavigatorState?> _waitForNavigator() async {
    // A cold start (app was fully closed, this tap is what launched it)
    // runs this before runApp() has built the widget tree, so the navigator
    // isn't attached yet — briefly poll for it rather than giving up
    // immediately, since this only runs once at startup.
    NavigatorState? state = navigatorKey.currentState;
    var attempts = 0;
    while (state == null && attempts < 25) {
      await Future.delayed(const Duration(milliseconds: 200));
      state = navigatorKey.currentState;
      attempts++;
    }
    return state;
  }

  /// Opens the specific journal entry a notification was about, fetching
  /// its current data first since EntryDetailScreen needs it up front. If
  /// the entry is gone, or the notification belongs to another account,
  /// opens the journal list with a short message instead. Best-effort: if
  /// nothing can be shown it does nothing rather than crash.
  static Future<void> _openEntryFromTap(
    HealingPayload payload,
    User? user,
  ) async {
    if (user == null) return; // signed out: nothing of this account to show
    final text = await NotificationStrings.load();

    if (user.uid != payload.uid) {
      await _openJournalListWithMessage(text.entryUnavailable);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('journalEntries')
          .doc(payload.entryId)
          .get()
          .timeout(const Duration(seconds: 10));
      if (!doc.exists) {
        await _openJournalListWithMessage(text.entryUnavailable);
        return;
      }
      final state = await _waitForNavigator();
      if (state == null) return;
      state.push(
        MaterialPageRoute(
          builder: (context) =>
              EntryDetailScreen(entryId: payload.entryId, data: doc.data()!),
        ),
      );
    } catch (_) {
      await _openJournalListWithMessage(text.entryUnavailable);
    }
  }

  static Future<void> _openJournalListWithMessage(String message) async {
    final state = await _waitForNavigator();
    if (state == null) return;
    state.push(
      MaterialPageRoute(builder: (context) => const JournalListScreen()),
    );
    await Future.delayed(const Duration(milliseconds: 400));
    final context = navigatorKey.currentContext;
    if (context != null && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  /// Logs a notification to the signed-in user's Firestore notifications
  /// (so read state can sync across their devices — see NotificationsScreen)
  /// and, when [toLocalInbox] is true, to the on-device inbox too. A guest
  /// never gets either. [type] defaults to reminder.
  Future<void> _logNotification({
    required String uid,
    required String title,
    required String body,
    String? entryId,
    AppNotificationType type = AppNotificationType.reminder,
    String? woundTypeLabel,
    bool toLocalInbox = true,
  }) async {
    if (toLocalInbox) {
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
    }

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
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
