import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// All Firestore CRUD operations for the `menu_items` collection that are
/// performed by a restaurant owner.
///
/// Security model
/// ──────────────
/// • Every write derives [restaurantId] from the caller-supplied value that
///   was originally loaded from [users/{uid}.restaurantId] — the client never
///   supplies it from free text.
/// • Firestore security rules enforce the same constraint server-side, so
///   a tampered request is rejected even if this class is bypassed.
/// • [restaurantId] is always written into created documents and is
///   immutable after creation (enforced via Firestore rules).
///
/// Paths used
/// ──────────
///   menu_items/{itemId}   – public menu-item documents
class MenuItemRepository {
  MenuItemRepository._();
  static final MenuItemRepository instance = MenuItemRepository._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('menu_items');

  // ── Convenience ────────────────────────────────────────────────────────────

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('MenuItemRepository: no authenticated user.');
    return uid;
  }

  // ── Read ───────────────────────────────────────────────────────────────────

  /// Real-time stream of all menu items for [restaurantId], ordered by name.
  Stream<List<Map<String, dynamic>>> menuItemsStream(String restaurantId) {
    return _col
        .where('restaurantId', isEqualTo: restaurantId)
        .orderBy('name')
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList());
  }

  /// One-shot fetch of a single menu item by [itemId].
  /// Returns null if the document does not exist.
  Future<Map<String, dynamic>?> fetchItem(String itemId) async {
    try {
      final snap = await _col.doc(itemId).get();
      if (!snap.exists) return null;
      final data = snap.data()!;
      data['id'] = snap.id;
      return data;
    } catch (e) {
      debugPrint('MenuItemRepository.fetchItem error: $e');
      rethrow;
    }
  }

  // ── Create ─────────────────────────────────────────────────────────────────

  /// Creates a new menu item and returns the generated Firestore document ID.
  ///
  /// [restaurantId] must come from the authenticated owner's cached profile —
  /// never from user-supplied text.
  ///
  /// Pass [img] and/or [heroImg] as the publicly accessible Object Storage
  /// URLs returned after a successful upload. Leave null if no image was
  /// uploaded yet.
  Future<String> createMenuItem({
    required String restaurantId,
    required String name,
    required String description,
    required double price,
    required String category,
    required bool isAvailable,
    String? img,
    String? heroImg,
  }) async {
    // Guard: confirm authenticated
    _uid;

    final data = _buildData(
      restaurantId: restaurantId,
      name: name,
      description: description,
      price: price,
      category: category,
      isAvailable: isAvailable,
      img: img,
      heroImg: heroImg,
    );
    data['createdAt'] = FieldValue.serverTimestamp();
    data['updatedAt'] = FieldValue.serverTimestamp();

    try {
      final ref = await _col.add(data);
      return ref.id;
    } catch (e) {
      debugPrint('MenuItemRepository.createMenuItem error: $e');
      rethrow;
    }
  }

  /// Reserves a document ID before uploading the image.
  ///
  /// Use this when you need the Firestore ID to construct the R2 object key
  /// (e.g. `restaurants/{rid}/menu/{itemId}/main.webp`) before the item
  /// has been saved. Call [createMenuItemWithId] afterwards.
  String generateItemId() => _col.doc().id;

  /// Creates a menu item document at a pre-known [itemId].
  Future<void> createMenuItemWithId({
    required String itemId,
    required String restaurantId,
    required String name,
    required String description,
    required double price,
    required String category,
    required bool isAvailable,
    String? img,
    String? heroImg,
  }) async {
    _uid;

    final data = _buildData(
      restaurantId: restaurantId,
      name: name,
      description: description,
      price: price,
      category: category,
      isAvailable: isAvailable,
      img: img,
      heroImg: heroImg,
    );
    data['createdAt'] = FieldValue.serverTimestamp();
    data['updatedAt'] = FieldValue.serverTimestamp();

    try {
      await _col.doc(itemId).set(data);
    } catch (e) {
      debugPrint('MenuItemRepository.createMenuItemWithId error: $e');
      rethrow;
    }
  }

  // ── Update ─────────────────────────────────────────────────────────────────

  /// Updates mutable metadata fields on an existing menu item.
  ///
  /// Only the fields present in this call are updated — images are NOT
  /// touched unless [img] or [heroImg] are explicitly provided.
  ///
  /// To update only non-image fields (e.g. price change), call
  /// [updateMenuItemMeta]. To also update an image URL after a successful
  /// upload, call [updateMenuItemImage] separately, which follows the
  /// upload-first, then-update-Firestore sequence.
  Future<void> updateMenuItemMeta({
    required String itemId,
    required String name,
    required String description,
    required double price,
    required String category,
    required bool isAvailable,
  }) async {
    _uid;
    try {
      await _col.doc(itemId).update({
        'name': name,
        'description': description,
        'price': price,
        'category': category,
        'isAvailable': isAvailable,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('MenuItemRepository.updateMenuItemMeta error: $e');
      rethrow;
    }
  }

  /// Updates a specific image URL on a menu item.
  ///
  /// [field] must be `'img'` or `'heroImg'`.
  ///
  /// Called AFTER a successful Object Storage upload to atomically record
  /// the new public URL.
  Future<void> updateMenuItemImage({
    required String itemId,
    required String field,
    required String publicUrl,
  }) async {
    assert(field == 'img' || field == 'heroImg',
        'field must be "img" or "heroImg"');
    _uid;
    try {
      await _col.doc(itemId).update({
        field: publicUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('MenuItemRepository.updateMenuItemImage error: $e');
      rethrow;
    }
  }

  /// Clears a specific image field (sets it to null / deletes the field).
  Future<void> clearMenuItemImage({
    required String itemId,
    required String field,
  }) async {
    assert(field == 'img' || field == 'heroImg',
        'field must be "img" or "heroImg"');
    _uid;
    try {
      await _col.doc(itemId).update({
        field: FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('MenuItemRepository.clearMenuItemImage error: $e');
      rethrow;
    }
  }

  // ── Delete ─────────────────────────────────────────────────────────────────

  /// Deletes the Firestore document for [itemId].
  ///
  /// Object Storage cleanup must be performed BEFORE calling this — call
  /// [MenuImageService.deleteImage] for each image first.
  Future<void> deleteMenuItem(String itemId) async {
    _uid;
    try {
      await _col.doc(itemId).delete();
    } catch (e) {
      debugPrint('MenuItemRepository.deleteMenuItem error: $e');
      rethrow;
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Map<String, dynamic> _buildData({
    required String restaurantId,
    required String name,
    required String description,
    required double price,
    required String category,
    required bool isAvailable,
    String? img,
    String? heroImg,
  }) =>
      {
        'restaurantId': restaurantId,
        'name': name.trim(),
        'description': description.trim(),
        'price': price,
        'category': category.trim(),
        'isAvailable': isAvailable,
        if (img != null) 'img': img,
        if (heroImg != null) 'heroImg': heroImg,
      };
}
