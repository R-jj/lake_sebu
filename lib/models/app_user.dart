import 'package:firebase_auth/firebase_auth.dart';

/// Lightweight wrapper around [User] so the rest of the app never
/// depends directly on firebase_auth types.
class AppUser {
  final String uid;
  final String? displayName;
  final String? email;
  final String? photoUrl;

  const AppUser({
    required this.uid,
    this.displayName,
    this.email,
    this.photoUrl,
  });

  /// Create from a Firebase [User] object.
  factory AppUser.fromFirebase(User user) => AppUser(
        uid: user.uid,
        displayName: user.displayName,
        email: user.email,
        photoUrl: user.photoURL,
      );

  /// Fallback display name — uses the part of the email before '@' when
  /// no display name has been set (e.g. for email/password accounts).
  String get name {
    if (displayName != null && displayName!.isNotEmpty) return displayName!;
    if (email != null) return email!.split('@').first;
    return 'User';
  }

  /// Single-letter initial for avatar placeholders.
  String get initial => name.isNotEmpty ? name[0].toUpperCase() : 'U';
}
