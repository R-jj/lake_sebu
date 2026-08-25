import 'package:cloud_firestore/cloud_firestore.dart';

/// A single favourited menu item belonging to a specific authenticated user.
///
/// Firestore path: `users/{uid}/favourites/{menuItemId}`
///
/// The document ID is the menu item's Firestore ID so that a simple
/// `doc(itemId).get()` is sufficient to check if an item is favourited —
/// no query needed.
class Favourite {
  /// The Firestore document ID — same as [menuItemId].
  final String id;

  /// Must match the owning user's uid.
  final String userId;

  /// The ID of the favourited menu item in the `menu_items` collection.
  final String menuItemId;

  final DateTime? createdAt;

  const Favourite({
    required this.id,
    required this.userId,
    required this.menuItemId,
    this.createdAt,
  });

  factory Favourite.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Favourite(
      id: doc.id,
      userId: d['userId'] as String? ?? '',
      menuItemId: d['menuItemId'] as String? ?? doc.id,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'userId': userId,
        'menuItemId': menuItemId,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
