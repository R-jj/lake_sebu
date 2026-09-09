import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'owner_notification_service.dart';

/// Registers restaurant owners with Firebase Cloud Messaging so a new
/// pending order wakes the device even when the app has been killed.
///
/// How it fits together
/// ────────────────────
/// • An owner's FCM token(s) are stored under
///     users/{uid}/devices/{token}   { platform, updatedAt }
///   so multiple devices per owner are supported.
/// • A Cloud Functions Firestore trigger (`functions/` folder) fires on
///   `orders` writes, counts the restaurant's pending orders, and sends a
///   high-priority push to every device token of that restaurant's owner.
/// • On the device:
///     - foreground  → the push is routed to [OwnerNotificationService] and
///       joins the existing looping alarm;
///     - background/killed → FCM delivers the *notification* payload with the
///       `owner_orders_alarm` Android channel + sound.  Because the message
///       is sent with high priority, it is delivered even when the process
///       is dead.  The looping sound cannot survive process death (Android
///       forbids endless background audio), but the notification re-fires on
///       every new order so the owner is alerted.
class OwnerMessagingService {
  OwnerMessagingService._();
  static final OwnerMessagingService instance = OwnerMessagingService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  StreamSubscription<String?>? _tokenSub;
  String? _registeredUid;

  /// Requests permissions and registers the current owner's device token.
  ///
  /// Call after the owner's profile has been loaded (i.e. when we know the
  /// user is a restaurant owner with a restaurantId).
  Future<void> registerOwner() async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Notifications permission (Android 13+ / iOS). Idempotent.
    await _messaging.requestPermission(provisional: false);

    // Register the current token.
    final token = await _messaging.getToken();
    if (token != null) await _saveToken(token, user.uid);

    // Re-save whenever the token rotates.
    _tokenSub ??= _messaging.onTokenRefresh.listen((token) {
      final uid = _auth.currentUser?.uid;
      if (uid != null) _saveToken(token, uid);
    });

    _registeredUid = user.uid;

    // Foreground pushes → run the in-app alarm machinery.
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('FCM onMessage: ${message.notification?.title}');
      final count = (message.data['pendingCount'] as num?)?.toInt() ?? 1;
      OwnerNotificationService.instance.onPendingCountChanged(count);
    });

    // Tapping a terminated-state notification opens the app; nothing extra
    // is needed here because the Firestore stream in OwnerOrdersProvider
    // picks up the pending orders and starts the alarm.
    FirebaseMessaging.onMessageOpenedApp.listen((_) {});
  }

  /// Removes this device's token (sign-out or account deletion).
  Future<void> unregister() async {
    final uid = _registeredUid;
    if (uid == null) return;
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await _db
            .collection('users')
            .doc(uid)
            .collection('devices')
            .doc(token)
            .delete();
      }
      await _messaging.deleteToken();
    } catch (e) {
      debugPrint('OwnerMessagingService.unregister error: $e');
    }
    _registeredUid = null;
  }

  Future<void> _saveToken(String token, String uid) async {
    try {
      await _db
          .collection('users')
          .doc(uid)
          .collection('devices')
          .doc(token)
          .set({
            'platform': defaultTargetPlatform.name,
            'updatedAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      debugPrint('OwnerMessagingService._saveToken error: $e');
    }
  }
}
