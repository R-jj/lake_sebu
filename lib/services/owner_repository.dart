import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/order.dart';
import 'user_repository.dart';

/// All Firestore operations that a restaurant owner needs.
///
/// This class delegates to [UserRepository] for the two shared operations
/// (restaurant-order stream and order-status update) rather than
/// duplicating Firestore calls.  It adds owner-specific guards:
///
///   • Every write verifies that the authenticated user's uid matches the
///     `users/{uid}` document that owns [restaurantId].  This is a
///     client-side sanity check; the Firestore security rules enforce the
///     same constraint server-side.
///
/// Paths used
/// ──────────
///   restaurants/{restaurantId}   – public restaurant document (read only)
///   orders/{orderId}             – order documents (read + status update)
///   users/{uid}                  – profile (read only, via UserRepository)
class OwnerRepository {
  OwnerRepository._();
  static final OwnerRepository instance = OwnerRepository._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserRepository _userRepo = UserRepository.instance;

  // ── Convenience ───────────────────────────────────────────────────────────

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('OwnerRepository: no authenticated user.');
    return uid;
  }

  // ── Restaurant ────────────────────────────────────────────────────────────

  /// Fetches the restaurant document for [restaurantId].
  /// Returns null if the document does not exist.
  Future<Map<String, dynamic>?> fetchRestaurant(String restaurantId) =>
      _userRepo.fetchRestaurant(restaurantId);

  /// Real-time stream of the restaurant document.
  /// Emits null if the document does not exist.
  Stream<Map<String, dynamic>?> restaurantStream(String restaurantId) {
    return _db
        .collection('restaurants')
        .doc(restaurantId)
        .snapshots()
        .map((snap) {
      if (!snap.exists) return null;
      final data = snap.data()!;
      data['id'] = snap.id;
      return data;
    });
  }

  // ── Orders ────────────────────────────────────────────────────────────────

  /// Real-time stream of all orders for [restaurantId], newest first.
  Stream<List<FoodOrder>> ordersStream(String restaurantId) =>
      _userRepo.restaurantOrdersStream(restaurantId);

  /// Updates the status of [orderId] to [status].
  ///
  /// Throws [StateError] if no user is authenticated.
  /// The Firestore security rules additionally enforce that the authenticated
  /// uid is the owner of the restaurant referenced on the order document.
  Future<void> updateOrderStatus(
    String orderId,
    FoodOrderStatus status,
  ) async {
    // Client-side guard — rule enforcement happens in Firestore too.
    final uid = _uid;
    debugPrint('OwnerRepository.updateOrderStatus: uid=$uid '
        'orderId=$orderId status=${status.value}');
    await _userRepo.updateOrderStatus(orderId, status);
  }

  // ── Restaurant writes ─────────────────────────────────────────────────────

  /// Creates a new restaurant document and returns the auto-generated ID.
  ///
  /// Adds `createdAt: FieldValue.serverTimestamp()` to [fields] before writing.
  /// Throws [StateError] when no user is authenticated.
  /// Propagates any Firestore exception to the caller.
  Future<String> createRestaurant(Map<String, dynamic> fields) async {
    final _ = _uid; // throws StateError if unauthenticated
    final data = {
      ...fields,
      'createdAt': FieldValue.serverTimestamp(),
    };
    final ref = await _db.collection('restaurants').add(data);
    return ref.id;
  }

  /// Updates [changedFields] on the existing restaurant document.
  ///
  /// Adds `updatedAt: FieldValue.serverTimestamp()` to the payload.
  /// Throws [StateError] when no user is authenticated.
  /// Throws [Exception] when no document exists for [restaurantId].
  /// Propagates any other Firestore exception to the caller.
  Future<void> updateRestaurant(
    String restaurantId,
    Map<String, dynamic> changedFields,
  ) async {
    final _ = _uid;
    final ref = _db.collection('restaurants').doc(restaurantId);
    final snap = await ref.get();
    if (!snap.exists) {
      throw Exception(
          'OwnerRepository.updateRestaurant: document $restaurantId not found.');
    }
    await ref.update({
      ...changedFields,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Writes [restaurantId] to the `restaurantId` field on the owner's
  /// profile document (`users/{uid}`).
  ///
  /// Throws [StateError] when no user is authenticated.
  /// Propagates any Firestore exception to the caller.
  Future<void> linkRestaurantToOwner(String restaurantId) async {
    final uid = _uid;
    await _db.collection('users').doc(uid).update({
      'restaurantId': restaurantId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Dashboard stats ───────────────────────────────────────────────────────

  /// One-shot fetch of order counts for [restaurantId].
  ///
  /// Returns a map with keys: pending, active, completed.
  ///   • pending   – FoodOrderStatus.pending
  ///   • active    – confirmed | preparing | on_the_way
  ///   • completed – delivered | cancelled
  Future<Map<String, int>> fetchOrderCounts(String restaurantId) async {
    try {
      final snap = await _db
          .collection('orders')
          .where('restaurantId', isEqualTo: restaurantId)
          .get();

      int pending = 0, active = 0, completed = 0;
      for (final doc in snap.docs) {
        final raw = doc.data()['status'] as String? ?? '';
        final status = FoodOrderStatus.fromString(raw);
        switch (status) {
          case FoodOrderStatus.pending:
            pending++;
          case FoodOrderStatus.confirmed:
          case FoodOrderStatus.preparing:
          case FoodOrderStatus.onTheWay:
            active++;
          case FoodOrderStatus.delivered:
          case FoodOrderStatus.cancelled:
            completed++;
        }
      }
      return {'pending': pending, 'active': active, 'completed': completed};
    } catch (e) {
      debugPrint('OwnerRepository.fetchOrderCounts error: $e');
      rethrow;
    }
  }
}
