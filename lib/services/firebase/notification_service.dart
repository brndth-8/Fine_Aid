import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initSettings = InitializationSettings(android: androidSettings);
    await _localNotifications.initialize(settings: initSettings);

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

  Future<void> showTestMilestoneNotification({
    required String classification,
    String? entryId,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'fine_aid_reminders',
      'Fine Aid Reminders',
      channelDescription: 'Healing milestone and journal reminders',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);

    const title = 'Healing Milestone Reminder';
    const body =
        'You have reached your healing time frame. Are you feeling better?';

    await _localNotifications.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: details,
    );

    await _logNotification(title: title, body: body, entryId: entryId);
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
