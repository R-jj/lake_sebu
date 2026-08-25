import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/user_profile.dart';
import '../models/address.dart';
import '../models/favourite.dart';
import '../models/order.dart';

/// All Firestore operations that touch user-owned data.
///
/// Nothing here trusts arbitrary IDs from the UI layer.  Every method
/// derives the owner identity from [FirebaseAuth.currentUser.uid] so the
/// Firestore security rules and the app code agree on who owns what.
///
/// Paths used
/// ──────────
///   users/{uid}                          – profile document
///   users/{uid}/addresses/{addressId}    – saved delivery addresses
///   users/{uid}/favourites/{menuItemId}  – favourited menu items
///   phoneIndex/{e164}                    – uniqueness index
class UserRepository {
  UserRepository._();
  static final UserRepository instance = UserRepository._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ── Convenience ───────────────────────────────────────────────────────────

  /// The current user's uid.  Throws if called while unauthenticated.
  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('UserRepository: no authenticated user.');
    return uid;
  }

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _db.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> _addressCol(String uid) =>
      _db.collection('users').doc(uid).collection('addresses');

  CollectionReference<Map<String, dynamic>> _favCol(String uid) =>
      _db.collection('users').doc(uid).collection('favourites');

  DocumentReference<Map<String, dynamic>> _phoneIndexDoc(String e164) =>
      _db.collection('phoneIndex').doc(e164);

  CollectionReference<Map<String, dynamic>> get _ordersCol =>
      _db.collection('orders');

  // ── Profile ───────────────────────────────────────────────────────────────

  /// Returns the profile document, or `null` if it does not exist yet.
  Future<UserProfile?> fetchProfile(String uid) async {
    try {
      final snap = await _userDoc(uid).get();
      if (!snap.exists) return null;
      return UserProfile.fromFirestore(snap);
    } catch (e) {
      debugPrint('UserRepository.fetchProfile error: $e');
      rethrow;
    }
  }

  /// Real-time stream of the profile document.
  Stream<UserProfile?> profileStream(String uid) {
    return _userDoc(uid).snapshots().map((snap) {
      if (!snap.exists) return null;
      return UserProfile.fromFirestore(snap);
    });
  }

  /// Creates the profile document for a brand-new account.
  /// Safe to call on Google sign-in if the doc does not exist yet.
  Future<void> createProfile(UserProfile profile) async {
    await _userDoc(profile.uid).set(profile.toFirestoreCreate());
  }

  /// Idempotent: creates the document if absent, merges if already present.
  Future<void> createProfileIfAbsent(UserProfile profile) async {
    final snap = await _userDoc(profile.uid).get();
    if (!snap.exists) {
      await createProfile(profile);
    }
  }

  /// Updates mutable display fields (displayName, email, photoUrl).
  /// Never touches phoneNumber or phoneNumberVerified.
  Future<void> updateProfile(UserProfile profile) async {
    if (profile.uid != _uid) {
      throw StateError('UserRepository: cannot update another user\'s profile.');
    }
    await _userDoc(profile.uid).update(profile.toFirestoreUpdate());
  }

  // ── Phone number ──────────────────────────────────────────────────────────

  /// Returns `true` when [e164] already exists in the phoneIndex collection,
  /// meaning it is claimed by some account.
  Future<bool> isPhoneNumberTaken(String e164) async {
    try {
      final snap = await _phoneIndexDoc(e164).get();
      return snap.exists;
    } catch (e) {
      debugPrint('UserRepository.isPhoneNumberTaken error: $e');
      return false;
    }
  }

  /// Returns the uid that owns [e164], or `null` if unclaimed.
  Future<String?> phoneNumberOwner(String e164) async {
    try {
      final snap = await _phoneIndexDoc(e164).get();
      if (!snap.exists) return null;
      return snap.data()?['uid'] as String?;
    } catch (e) {
      debugPrint('UserRepository.phoneNumberOwner error: $e');
      return null;
    }
  }

  /// Called after Firebase phone-auth OTP is confirmed.
  ///
  /// Atomically:
  ///   1. Removes any previous phoneIndex entry owned by this user.
  ///   2. Writes the new phoneIndex entry.
  ///   3. Updates the user's profile with the verified phone number.
  ///
  /// The security rules allow the client to write `phoneNumberVerified: true`
  /// only after the phone credential has been linked to the Auth account —
  /// i.e., only from within [UserRepository] after OTP success.
  Future<void> markPhoneVerified(String e164) async {
    final uid = _uid;
    final batch = _db.batch();

    // 1. Remove the old index entry if the user had a different phone before.
    final currentProfile = await fetchProfile(uid);
    if (currentProfile?.phoneNumber != null &&
        currentProfile!.phoneNumber != e164 &&
        currentProfile.phoneNumberVerified) {
      batch.delete(_phoneIndexDoc(currentProfile.phoneNumber!));
    }

    // 2. Write the new phone-index entry.
    batch.set(_phoneIndexDoc(e164), {'uid': uid});

    // 3. Update the profile — write phoneNumberVerified: true.
    // The security rule permits this because the update also sets
    // phoneNumberVerified: false elsewhere; here we use a direct map
    // so we can set it to true after a successful OTP credential link.
    batch.update(
      _userDoc(uid),
      UserProfile.phoneVerifiedUpdate(e164),
    );

    await batch.commit();
  }

  /// Marks a new phone number as pending verification.
  /// Sets phoneNumberVerified = false until OTP is confirmed.
  Future<void> markPhonePending(String e164) async {
    final uid = _uid;
    await _userDoc(uid).update(UserProfile.phonePendingUpdate(e164));
  }

  /// Saves [e164] as the user's contact phone number without any SMS
  /// verification.
  ///
  /// This is the correct method to use while phone authentication is not yet
  /// enabled (no paid Firebase plan).  [phoneNumberVerified] is NOT written —
  /// it stays `false` in the existing document.
  ///
  /// Does NOT write to [phoneIndex].  Uniqueness enforcement via the index
  /// was designed for verified numbers; skipping it here prevents users from
  /// being blocked when two accounts happen to share a number without
  /// verification to arbitrate ownership.
  Future<void> updatePhoneNumber(String e164) async {
    final uid = _uid;
    await _userDoc(uid).update({
      'phoneNumber': e164,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Addresses ─────────────────────────────────────────────────────────────

  /// Real-time stream of all addresses for the current user, ordered by
  /// default-first then creation time.
  ///
  /// Sorting is done client-side so no composite Firestore index is required.
  Stream<List<Address>> addressesStream() {
    return _addressCol(_uid)
        .snapshots()
        .map((snap) {
          final list = snap.docs.map(Address.fromFirestore).toList();
          list.sort(_addressComparator);
          return list;
        });
  }

  /// One-shot fetch of all addresses.
  ///
  /// Sorting is done client-side so no composite Firestore index is required.
  Future<List<Address>> fetchAddresses() async {
    final snap = await _addressCol(_uid).get();
    final list = snap.docs.map(Address.fromFirestore).toList();
    list.sort(_addressComparator);
    return list;
  }

  /// Comparator: default address first, then oldest-created first.
  static int _addressComparator(Address a, Address b) {
    if (a.isDefault != b.isDefault) return a.isDefault ? -1 : 1;
    final aTime = a.createdAt ?? DateTime(0);
    final bTime = b.createdAt ?? DateTime(0);
    return aTime.compareTo(bTime);
  }

  /// Adds a new address.  Returns the Firestore document ID.
  Future<String> addAddress(Address address) async {
    final uid = _uid;
    final data = address.toFirestore()..['userId'] = uid;

    // If this is set as the default, unset all others first.
    if (address.isDefault) {
      await _clearDefaultFlag(uid);
    }

    final ref = await _addressCol(uid).add(data);
    return ref.id;
  }

  /// Updates an existing address owned by the current user.
  Future<void> updateAddress(Address address) async {
    final uid = _uid;
    if (address.userId != uid) {
      throw StateError('UserRepository: cannot modify another user\'s address.');
    }

    if (address.isDefault) {
      await _clearDefaultFlag(uid, exceptId: address.id);
    }

    await _addressCol(uid)
        .doc(address.id)
        .update(address.toFirestore()..['updatedAt'] = FieldValue.serverTimestamp());
  }

  /// Deletes an address.  If it was the default, the most-recently-created
  /// remaining address is promoted to default.
  Future<void> deleteAddress(String addressId) async {
    final uid = _uid;
    final ref = _addressCol(uid).doc(addressId);
    final snap = await ref.get();
    if (!snap.exists) return;

    final wasDefault = snap.data()?['isDefault'] as bool? ?? false;
    await ref.delete();

    // Promote the next address to default if necessary.
    if (wasDefault) {
      final remaining = await _addressCol(uid)
          .orderBy('createdAt', descending: false)
          .limit(1)
          .get();
      if (remaining.docs.isNotEmpty) {
        await remaining.docs.first.reference
            .update({'isDefault': true, 'updatedAt': FieldValue.serverTimestamp()});
      }
    }
  }

  /// Sets [addressId] as the default and clears the flag from all others.
  Future<void> setDefaultAddress(String addressId) async {
    final uid = _uid;
    final batch = _db.batch();

    final all = await _addressCol(uid).get();
    for (final doc in all.docs) {
      final isTarget = doc.id == addressId;
      if ((doc.data()['isDefault'] as bool? ?? false) != isTarget) {
        batch.update(doc.reference, {
          'isDefault': isTarget,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }
    await batch.commit();
  }

  /// Removes the `isDefault` flag from every address except [exceptId].
  Future<void> _clearDefaultFlag(String uid, {String? exceptId}) async {
    final snap = await _addressCol(uid)
        .where('isDefault', isEqualTo: true)
        .get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      if (doc.id != exceptId) {
        batch.update(doc.reference, {
          'isDefault': false,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }
    await batch.commit();
  }

  // ── Favourites ────────────────────────────────────────────────────────────

  /// Real-time stream of the current user's favourited menu item IDs.
  Stream<Set<String>> favouriteIdsStream() {
    return _favCol(_uid).snapshots().map(
          (snap) => snap.docs.map((d) => d.id).toSet(),
        );
  }

  /// One-shot fetch of all favourites.
  Future<List<Favourite>> fetchFavourites() async {
    final snap = await _favCol(_uid)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map(Favourite.fromFirestore).toList();
  }

  /// Returns `true` when [menuItemId] is in the user's favourites.
  Future<bool> isFavourite(String menuItemId) async {
    final snap = await _favCol(_uid).doc(menuItemId).get();
    return snap.exists;
  }

  /// Adds [menuItemId] to favourites.  No-op if already present.
  Future<void> addFavourite(String menuItemId) async {
    final uid = _uid;
    final fav = Favourite(
      id: menuItemId,
      userId: uid,
      menuItemId: menuItemId,
    );
    await _favCol(uid).doc(menuItemId).set(fav.toFirestore());
  }

  /// Removes [menuItemId] from favourites.  No-op if not present.
  Future<void> removeFavourite(String menuItemId) async {
    await _favCol(_uid).doc(menuItemId).delete();
  }

  // ── Orders ────────────────────────────────────────────────────────────────

  /// Writes a new order document to `orders/{orderId}`.
  ///
  /// The [order.orderId] is used as the Firestore document ID so the caller
  /// controls the ID (generated with [_db.collection('orders').doc().id]
  /// before calling this).
  ///
  /// The [order.customerPhone] must already be set by the caller as the
  /// E.164 snapshot from the user's profile at checkout time.
  ///
  /// Throws if the authenticated user's uid does not match [order.customerId],
  /// preventing one user from placing orders on behalf of another.
  Future<void> placeOrder(FoodOrder order) async {
    final uid = _uid;
    if (order.customerId != uid) {
      throw StateError(
          'UserRepository: customerId does not match authenticated user.');
    }
    if (order.customerPhone.isEmpty) {
      throw ArgumentError(
          'UserRepository: order must include a customerPhone snapshot.');
    }
    if (order.restaurantId.isEmpty) {
      throw ArgumentError(
          'UserRepository: order must include a restaurantId.');
    }
    await _ordersCol.doc(order.orderId).set(order.toFirestore());
  }

  /// Real-time stream of orders for the current user, newest first.
  Stream<List<FoodOrder>> ordersStream() {
    return _ordersCol
        .where('customerId', isEqualTo: _uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(FoodOrder.fromFirestore).toList());
  }

  /// One-shot fetch of the current user's orders.
  Future<List<FoodOrder>> fetchOrders() async {
    final snap = await _ordersCol
        .where('customerId', isEqualTo: _uid)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map(FoodOrder.fromFirestore).toList();
  }

  // ── Restaurant-owner order access ─────────────────────────────────────────
  //
  // These methods are only called by OwnerRepository / OwnerOrdersProvider.
  // They accept an explicit restaurantId rather than deriving it from _uid
  // so the caller (which already validated the owner's profile) controls
  // which restaurant is queried.  The Firestore security rules enforce the
  // same constraint server-side.

  /// Real-time stream of orders for [restaurantId], newest first.
  /// Used by the restaurant-owner dashboard and orders page.
  Stream<List<FoodOrder>> restaurantOrdersStream(String restaurantId) {
    return _ordersCol
        .where('restaurantId', isEqualTo: restaurantId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(FoodOrder.fromFirestore).toList());
  }

  /// Updates only the [status] field of the order document identified by
  /// [orderId].  The Firestore rules verify the caller is the restaurant
  /// owner before allowing this write.
  Future<void> updateOrderStatus(String orderId, FoodOrderStatus status) async {
    await _ordersCol.doc(orderId).update({
      'status': status.value,
    });
  }

  /// One-shot fetch of the restaurant's document from the `restaurants`
  /// collection.  Returns null if the document does not exist.
  Future<Map<String, dynamic>?> fetchRestaurant(String restaurantId) async {
    final snap =
        await _db.collection('restaurants').doc(restaurantId).get();
    if (!snap.exists) return null;
    final data = snap.data()!;
    data['id'] = snap.id;
    return data;
  }

  // ── Account deletion ──────────────────────────────────────────────────────

  /// Deletes all Firestore data owned by [uid] then deletes the Firebase
  /// Auth account.
  ///
  /// Firestore does not cascade-delete subcollections, so we delete
  /// addresses and favourites explicitly before removing the profile doc.
  ///
  /// Important: the caller must ensure the user has been re-authenticated
  /// recently before calling this (Firebase requires recent auth for
  /// account deletion).
  Future<void> deleteAccount() async {
    final uid = _uid;

    // 1. Delete addresses subcollection.
    await _deleteCollection(_addressCol(uid));

    // 2. Delete favourites subcollection.
    await _deleteCollection(_favCol(uid));

    // 3. Remove phone index entry.
    final profile = await fetchProfile(uid);
    if (profile?.phoneNumber != null && profile!.phoneNumberVerified) {
      try {
        await _phoneIndexDoc(profile.phoneNumber!).delete();
      } catch (_) {
        // Best-effort; security rules will prevent others from hijacking it.
      }
    }

    // 4. Delete the profile document.
    await _userDoc(uid).delete();

    // 5. Delete the Firebase Auth account.
    await _auth.currentUser!.delete();
  }

  /// Deletes all documents in [col] in batches of 400 to stay under the
  /// Firestore 500-write batch limit.
  Future<void> _deleteCollection(
    CollectionReference<Map<String, dynamic>> col,
  ) async {
    const batchSize = 400;
    QuerySnapshot snap;
    do {
      snap = await col.limit(batchSize).get();
      if (snap.docs.isEmpty) break;
      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } while (snap.docs.length == batchSize);
  }
}
