import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What kind of notification this is — drives the type label/icon shown
/// in the inbox list and which detail-view actions are offered.
enum AppNotificationType { healingMilestone, update, reminder, system }

AppNotificationType _typeFromString(String? raw) {
  switch (raw) {
    case 'healingMilestone':
      return AppNotificationType.healingMilestone;
    case 'update':
      return AppNotificationType.update;
    case 'system':
      return AppNotificationType.system;
    default:
      return AppNotificationType.reminder;
  }
}

/// One entry in the on-device notification inbox — the local mirror every
/// notification (healing milestones, reminders, app updates) is saved to
/// the moment it's scheduled or received, so the inbox still shows it even
/// after the user swipes it out of the system tray, works fully offline,
/// and stays visible for guests (who have no Firestore doc to read from).
class AppNotification {
  final String id;
  final AppNotificationType type;
  final String title;
  final String body;
  final DateTime createdAt;
  // Null for something already delivered (eg a system announcement); set
  // for a scheduled local reminder — the inbox hides it from the visible
  // list until this time has passed, since flutter_local_notifications has
  // no "on delivered" hook to log the moment it actually appears.
  final DateTime? scheduledFor;
  final bool isRead;
  final DateTime? readAt;
  final String? entryId;
  // Already a display-ready label (eg "Burn"), never a raw code — see
  // core/display_formatters.dart.
  final String? woundTypeLabel;
  // For an "update" notification with an action (eg "Update now").
  final String? actionUrl;
  final String? actionLabel;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.scheduledFor,
    this.isRead = false,
    this.readAt,
    this.entryId,
    this.woundTypeLabel,
    this.actionUrl,
    this.actionLabel,
  });

  bool get isVisible =>
      scheduledFor == null || !scheduledFor!.isAfter(DateTime.now());

  AppNotification copyWith({bool? isRead, DateTime? readAt}) => AppNotification(
    id: id,
    type: type,
    title: title,
    body: body,
    createdAt: createdAt,
    scheduledFor: scheduledFor,
    isRead: isRead ?? this.isRead,
    readAt: readAt ?? this.readAt,
    entryId: entryId,
    woundTypeLabel: woundTypeLabel,
    actionUrl: actionUrl,
    actionLabel: actionLabel,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'title': title,
    'body': body,
    'createdAt': createdAt.toIso8601String(),
    'scheduledFor': scheduledFor?.toIso8601String(),
    'isRead': isRead,
    'readAt': readAt?.toIso8601String(),
    'entryId': entryId,
    'woundTypeLabel': woundTypeLabel,
    'actionUrl': actionUrl,
    'actionLabel': actionLabel,
  };

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id']?.toString() ?? '',
      type: _typeFromString(json['type'] as String?),
      title: json['title']?.toString() ?? 'Notification',
      body: json['body']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      scheduledFor: json['scheduledFor'] != null
          ? DateTime.tryParse(json['scheduledFor'].toString())
          : null,
      isRead: json['isRead'] == true,
      readAt: json['readAt'] != null
          ? DateTime.tryParse(json['readAt'].toString())
          : null,
      entryId: json['entryId']?.toString(),
      woundTypeLabel: json['woundTypeLabel']?.toString(),
      actionUrl: json['actionUrl']?.toString(),
      actionLabel: json['actionLabel']?.toString(),
    );
  }
}

/// On-device notification inbox, entirely local (SharedPreferences, JSON-
/// encoded) — works for guests (no account needed) and offline (no
/// network involved at all), and is the source the Notifications screen
/// merges with Firestore data for a signed-in user. A ChangeNotifier so
/// the unread-count badge updates immediately anywhere it's shown.
class NotificationInboxStore extends ChangeNotifier {
  NotificationInboxStore._();
  static final NotificationInboxStore instance = NotificationInboxStore._();

  static const String _prefsKey = 'notification_inbox_v1';
  static const int _maxItems = 100;
  static const Duration _autoClearReadAfter = Duration(days: 30);
  static const String _dismissedPrefsKey = 'notification_inbox_dismissed_v1';

  List<AppNotification> _items = [];
  Set<String> _dismissedIds = {};
  bool _loaded = false;

  List<AppNotification> get items => List.unmodifiable(_items);

  List<AppNotification> get visibleItems =>
      _items.where((n) => n.isVisible).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  int get unreadCount => visibleItems.where((n) => !n.isRead).length;

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_prefsKey) ?? const [];
      _items = raw
          .map((s) {
            try {
              return AppNotification.fromJson(
                jsonDecode(s) as Map<String, dynamic>,
              );
            } catch (_) {
              return null;
            }
          })
          .whereType<AppNotification>()
          .toList();
      _dismissedIds = (prefs.getStringList(_dismissedPrefsKey) ?? const [])
          .toSet();
    } catch (e) {
      debugPrint('NotificationInboxStore load error: $e');
      _items = [];
      _dismissedIds = {};
    } finally {
      _loaded = true;
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _prefsKey,
        _items.map((n) => jsonEncode(n.toJson())).toList(),
      );
    } catch (e) {
      debugPrint('NotificationInboxStore persist error: $e');
    }
  }

  Future<void> load() async {
    await _ensureLoaded();
    notifyListeners();
  }

  Future<void> add(AppNotification notification) async {
    await _ensureLoaded();
    _items.removeWhere((n) => n.id == notification.id);
    _items.add(notification);
    _pruneLocked();
    await _persist();
    notifyListeners();
  }

  void _pruneLocked() {
    final cutoff = DateTime.now().subtract(_autoClearReadAfter);
    _items.removeWhere((n) => n.isRead && n.createdAt.isBefore(cutoff));
    if (_items.length > _maxItems) {
      _items.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      _items = _items.sublist(_items.length - _maxItems);
    }
  }

  Future<void> markRead(String id) async {
    await _ensureLoaded();
    final index = _items.indexWhere((n) => n.id == id);
    if (index == -1 || _items[index].isRead) return;
    _items[index] = _items[index].copyWith(
      isRead: true,
      readAt: DateTime.now(),
    );
    await _persist();
    notifyListeners();
  }

  Future<void> markAllRead() async {
    await _ensureLoaded();
    var changed = false;
    for (var i = 0; i < _items.length; i++) {
      if (!_items[i].isRead) {
        _items[i] = _items[i].copyWith(isRead: true, readAt: DateTime.now());
        changed = true;
      }
    }
    if (!changed) return;
    await _persist();
    notifyListeners();
  }

  Future<void> delete(String id) async {
    await _ensureLoaded();
    final before = _items.length;
    _items.removeWhere((n) => n.id == id);
    _dismissedIds.add(id);
    if (_items.length == before) {
      await _persistDismissed();
      return;
    }
    await _persist();
    await _persistDismissed();
    notifyListeners();
  }

  Future<void> _persistDismissed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_dismissedPrefsKey, _dismissedIds.toList());
    } catch (e) {
      debugPrint('NotificationInboxStore persistDismissed error: $e');
    }
  }

  /// Merges a notification fetched from a remote source (Firestore
  /// personal/system notifications) into the local store, which is what
  /// the Notifications screen actually renders from — Firestore streams
  /// exist only to keep this local mirror in sync, never rendered
  /// directly, so read state and list membership always come from one
  /// place. Preserves the LOCAL read state if this item was already seen
  /// (avoids a stale remote snapshot flipping something back to unread),
  /// and never re-adds an item the user explicitly deleted locally.
  Future<void> upsertFromRemote(AppNotification remote) async {
    await _ensureLoaded();
    if (_dismissedIds.contains(remote.id)) return;

    final index = _items.indexWhere((n) => n.id == remote.id);
    if (index == -1) {
      _items.add(remote);
    } else if (!_items[index].isRead) {
      // Not yet read locally — remote's read flag (eg from another
      // device) is the more current source of truth for isRead here.
      _items[index] = remote.copyWith(
        isRead: remote.isRead,
        readAt: remote.readAt,
      );
    }
    // else: already read locally — keep it read, don't overwrite.
    _pruneLocked();
    await _persist();
    notifyListeners();
  }

  /// Removes any not-yet-visible (still scheduled) entry for [entryId] —
  /// used when a journal entry is deleted so its pending reminder never
  /// shows up once it would otherwise have fired.
  Future<void> removePendingForEntry(String entryId) async {
    await _ensureLoaded();
    final before = _items.length;
    _items.removeWhere((n) => n.entryId == entryId && !n.isVisible);
    if (_items.length == before) return;
    await _persist();
    notifyListeners();
  }
}
