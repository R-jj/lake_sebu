import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Manages the pending-order alarm for restaurant owners.
///
/// Behaviour:
/// - When one or more orders are pending, plays a looping alarm sound +
///   fires a heads-up notification showing the number of pending orders.
/// - Sound and vibration stop ONLY when pending count drops to zero
///   (i.e. all orders have been confirmed or cancelled).
/// - Singleton — call [OwnerNotificationService.instance].
class OwnerNotificationService {
  OwnerNotificationService._();
  static final OwnerNotificationService instance =
      OwnerNotificationService._();

  static const _channelId = 'owner_orders_alarm';
  static const _channelName = 'New Order Alarm';
  static const _notificationId = 1001;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final AudioPlayer _player = AudioPlayer();

  bool _initialized = false;
  bool _alarmActive = false;

  // ── Init ─────────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Request notification permission on Android 13+
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: android);
    await _plugin.initialize(initSettings);

    // Create the high-priority alarm channel
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'Alerts when a new order needs attention.',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      // System default sound on the channel; actual alarm sound from audioplayers
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Configure audioplayer for looping
    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.setVolume(1.0);
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Call whenever the pending order count changes.
  /// Starts the alarm when [pendingCount] > 0, stops it when 0.
  Future<void> onPendingCountChanged(int pendingCount) async {
    if (!_initialized) await init();

    if (pendingCount > 0 && !_alarmActive) {
      await _startAlarm(pendingCount);
    } else if (pendingCount > 0 && _alarmActive) {
      // Update the notification text but keep alarm going
      await _updateNotification(pendingCount);
    } else if (pendingCount == 0 && _alarmActive) {
      await _stopAlarm();
    }
  }

  // ── Private ───────────────────────────────────────────────────────────────

  Future<void> _startAlarm(int pendingCount) async {
    _alarmActive = true;

    // Start looping sound — silently ignore if asset not yet added
    try {
      await _player.play(AssetSource('sounds/order_alarm.mp3'));
    } catch (e) {
      debugPrint('OwnerNotificationService: could not play alarm sound: $e');
      // Vibration + notification still work even without the audio asset
    }

    await _showNotification(pendingCount);
  }

  Future<void> _stopAlarm() async {
    _alarmActive = false;
    await _player.stop();
    await _plugin.cancel(_notificationId);
  }

  Future<void> _updateNotification(int pendingCount) async {
    await _showNotification(pendingCount);
  }

  Future<void> _showNotification(int pendingCount) async {
    final body = pendingCount == 1
        ? '1 new order is waiting for your response.'
        : '$pendingCount new orders are waiting for your response.';

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Alerts when a new order needs attention.',
      importance: Importance.max,
      priority: Priority.max,
      ongoing: true, // persistent — cannot be swiped away by the owner
      autoCancel: false,
      playSound: false, // sound managed by audioplayers loop
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 500, 200, 500]),
      icon: '@mipmap/ic_launcher',
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      styleInformation: BigTextStyleInformation(body),
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true,
      ticker: 'New order!',
    );

    await _plugin.show(
      _notificationId,
      '🔔 New Order${pendingCount > 1 ? 's' : ''}',
      body,
      NotificationDetails(android: androidDetails),
    );
  }

  /// Call this when the app is closing or the owner signs out.
  Future<void> dispose() async {
    await _stopAlarm();
    await _player.dispose();
  }
}
