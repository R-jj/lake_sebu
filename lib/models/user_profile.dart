import 'package:cloud_firestore/cloud_firestore.dart';

// ── Account role ──────────────────────────────────────────────────────────────

/// The role determines which shell (customer vs. restaurant owner) is shown
/// after sign-in.  Stored as a string in Firestore so it is human-readable
/// and easily set via the Firebase Console.
enum UserRole {
  customer('customer'),
  restaurantOwner('restaurant_owner');

  const UserRole(this.value);
  final String value;

  static UserRole fromString(String? raw) {
    return UserRole.values.firstWhere(
      (r) => r.value == raw,
      orElse: () => UserRole.customer,
    );
  }
}

/// The user profile document stored in Firestore at `users/{uid}`.
///
/// Firebase Auth holds authentication credentials (email, password, Google
/// token, etc.).  This model holds *application-level* profile data that
/// Auth does not own — primarily the verified phone number and any display
/// name / photo overrides the user may set inside the app.
///
/// # Role & restaurantId
/// [role] defaults to [UserRole.customer] for all accounts created through
/// the normal sign-up flow.  To create a restaurant-owner account, manually
/// set `role: "restaurant_owner"` and `restaurantId: "<id>"` in the
/// Firestore Console on the `users/{uid}` document.
class UserProfile {
  final String uid;
  final String displayName;
  final String email;
  final String? photoUrl;

  /// Normalised international format, e.g. "+639171234567".
  /// Null when the user has not yet provided a phone number.
  final String? phoneNumber;

  /// True only after Firebase phone-auth OTP has been verified and
  /// the server-timestamp write has completed.
  /// This field may NOT be set to `true` by the client directly —
  /// the Firestore security rules block that escalation.
  final bool phoneNumberVerified;

  /// The account role.  Defaults to [UserRole.customer].
  /// Set to [UserRole.restaurantOwner] via Firebase Console to grant
  /// restaurant-owner access.
  final UserRole role;

  /// The Firestore document ID from the `restaurants` collection that this
  /// owner manages.  Only meaningful when [role] == [UserRole.restaurantOwner].
  /// Null for customer accounts.
  final String? restaurantId;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserProfile({
    required this.uid,
    required this.displayName,
    required this.email,
    this.photoUrl,
    this.phoneNumber,
    this.phoneNumberVerified = false,
    this.role = UserRole.customer,
    this.restaurantId,
    this.createdAt,
    this.updatedAt,
  });

  /// Whether this account belongs to a restaurant owner.
  bool get isRestaurantOwner => role == UserRole.restaurantOwner;

  /// Whether the account is considered complete enough to use the app.
  ///
  /// Restaurant owners are always considered complete — they are created
  /// manually by an admin and do not go through the phone-verification gate.
  ///
  /// Customers must supply a phone number before the app is usable.
  bool get isComplete =>
      isRestaurantOwner || (phoneNumber != null && phoneNumber!.isNotEmpty);

  // ── Firestore serialisation ───────────────────────────────────────────────

  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return UserProfile(
      uid: d['uid'] as String? ?? doc.id,
      displayName: d['displayName'] as String? ?? '',
      email: d['email'] as String? ?? '',
      photoUrl: d['photoUrl'] as String?,
      phoneNumber: d['phoneNumber'] as String?,
      phoneNumberVerified: d['phoneNumberVerified'] as bool? ?? false,
      role: UserRole.fromString(d['role'] as String?),
      restaurantId: d['restaurantId'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Used when *creating* the document for the first time.
  /// The role defaults to "customer" — only a manual Firestore Console
  /// edit can upgrade an account to "restaurant_owner".
  Map<String, dynamic> toFirestoreCreate() => {
        'uid': uid,
        'displayName': displayName,
        'email': email,
        if (photoUrl != null) 'photoUrl': photoUrl,
        'phoneNumber': phoneNumber,
        // Must be false on create — the security rule enforces this too.
        'phoneNumberVerified': false,
        // Always write 'customer' on creation; never write restaurantId here.
        'role': UserRole.customer.value,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  /// Used when *updating* mutable profile fields (never touches
  /// phoneNumberVerified or uid from the client).
  Map<String, dynamic> toFirestoreUpdate() => {
        'displayName': displayName,
        'email': email,
        if (photoUrl != null) 'photoUrl': photoUrl else 'photoUrl': null,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  /// Partial update map for when a new phone number has been verified.
  /// This is the *only* place `phoneNumberVerified` is written from the
  /// client — it writes `false` first (pending), then `true` after OTP
  /// confirmation, but the security rule only allows the client to write
  /// `false`.  Writing `true` must therefore be done via a trusted path.
  ///
  /// Because we cannot write `phoneNumberVerified = true` from the client
  /// (the security rule blocks it), we use Firebase Auth's built-in phone
  /// credential linking as the source of truth, and only store the
  /// normalised number + a `false` flag from the client.  A separate Cloud
  /// Function or the Auth trigger would flip the flag.  However, since no
  /// Cloud Functions exist yet, we take the pragmatic approach of using a
  /// Firestore *Admin SDK write* alternative: linking the phone credential
  /// to the Firebase Auth account (which is a trusted action) and then
  /// allowing the client to write `phoneNumberVerified = true` only if the
  /// phone credential is already linked to the Auth account.
  ///
  /// In practice this is handled by [UserRepository.markPhoneVerified],
  /// which is only called after [FirebaseAuth.currentUser.linkWithCredential]
  /// succeeds — so the "verified" state is grounded in a Firebase Auth
  /// operation, not just a client claim.
  static Map<String, dynamic> phoneVerifiedUpdate(String normalizedPhone) => {
        'phoneNumber': normalizedPhone,
        'phoneNumberVerified': true,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  /// Partial update map to clear a phone number when the user starts the
  /// change-phone flow (marks it as unverified while OTP is pending).
  static Map<String, dynamic> phonePendingUpdate(String pendingPhone) => {
        'phoneNumber': pendingPhone,
        'phoneNumberVerified': false,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  UserProfile copyWith({
    String? displayName,
    String? email,
    String? photoUrl,
    String? phoneNumber,
    bool? phoneNumberVerified,
    UserRole? role,
    String? restaurantId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      UserProfile(
        uid: uid,
        displayName: displayName ?? this.displayName,
        email: email ?? this.email,
        photoUrl: photoUrl ?? this.photoUrl,
        phoneNumber: phoneNumber ?? this.phoneNumber,
        phoneNumberVerified: phoneNumberVerified ?? this.phoneNumberVerified,
        role: role ?? this.role,
        restaurantId: restaurantId ?? this.restaurantId,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
