import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/app_user.dart';
import '../models/user_profile.dart';
import '../services/user_repository.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

/// Wraps Firebase Auth and exposes auth state + sign-in / sign-up /
/// sign-out methods to the widget tree via [ChangeNotifier].
///
/// Responsibilities
/// ────────────────
/// • Listens to [FirebaseAuth.authStateChanges] and maintains [status].
/// • Creates or bootstraps the Firestore [UserProfile] document on
///   first sign-in (email/password registration or Google Sign-In).
/// • Exposes [isProfileComplete] so the auth gate can redirect to the
///   profile-completion flow when required information is missing.
class AppAuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final UserRepository _repo = UserRepository.instance;

  AppUser? _user;
  AuthStatus _status = AuthStatus.unknown;
  String? _errorMessage;
  bool _isLoading = false;

  /// Whether the Firestore profile has been loaded yet after sign-in.
  bool _profileLoaded = false;

  /// Cached profile-completeness flag loaded from Firestore.
  bool _profileComplete = false;

  /// Cached role loaded from Firestore.  Defaults to customer until the
  /// profile document has been read.
  UserRole _userRole = UserRole.customer;

  /// The restaurantId from the profile document.  Non-null only for owners.
  String? _restaurantId;

  AppUser? get user => _user;
  AuthStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  /// True once [_checkProfileComplete] has finished after sign-in.
  bool get profileLoaded => _profileLoaded;

  /// True when the authenticated user's Firestore profile has all
  /// mandatory fields (phone verified).
  bool get isProfileComplete => _profileComplete;

  /// The role of the currently authenticated user.
  UserRole get userRole => _userRole;

  /// Convenience: true when the signed-in user is a restaurant owner.
  bool get isRestaurantOwner => _userRole == UserRole.restaurantOwner;

  /// The restaurantId linked to the owner's account.  Null for customers.
  String? get restaurantId => _restaurantId;

  AppAuthProvider() {
    _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  Future<void> _onAuthStateChanged(User? firebaseUser) async {
    if (firebaseUser == null) {
      _user = null;
      _status = AuthStatus.unauthenticated;
      _profileLoaded = false;
      _profileComplete = false;
      _userRole = UserRole.customer;
      _restaurantId = null;
    } else {
      _user = AppUser.fromFirebase(firebaseUser);
      _status = AuthStatus.authenticated;
      // Load profile completeness in the background; the auth gate waits
      // for profileLoaded before deciding which screen to show.
      _profileLoaded = false;
      notifyListeners(); // Let gate show splash while we load.
      await _checkProfileComplete(firebaseUser.uid);
    }
    notifyListeners();
  }

  /// Fetches the Firestore profile and caches whether it is complete,
  /// the user's role, and the restaurantId (for owners).
  Future<void> _checkProfileComplete(String uid) async {
    try {
      final profile = await _repo.fetchProfile(uid);
      _profileComplete = profile?.isComplete ?? false;
      _userRole = profile?.role ?? UserRole.customer;
      _restaurantId = profile?.restaurantId;
    } catch (e) {
      debugPrint('AppAuthProvider._checkProfileComplete error: $e');
      _profileComplete = false;
      _userRole = UserRole.customer;
      _restaurantId = null;
    } finally {
      _profileLoaded = true;
      notifyListeners();
    }
  }

  /// Called by [UserProfileProvider] after the user completes profile setup
  /// (phone verified) so the gate refreshes without a full sign-out/in cycle.
  void markProfileComplete() {
    _profileComplete = true;
    notifyListeners();
  }

  /// Called by [UserProfileProvider] when the phone number is de-verified
  /// (e.g. user starts a phone change flow).
  void markProfileIncomplete() {
    _profileComplete = false;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? message) {
    _errorMessage = message;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ── Email / Password Sign-In ──────────────────────────────────────────────

  /// Returns `true` on success.
  Future<bool> signInWithEmail(String email, String password) async {
    _setError(null);
    _setLoading(true);
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return true;
    } on FirebaseAuthException catch (e) {
      _setError(_friendlyError(e.code));
      return false;
    } catch (_) {
      _setError('An unexpected error occurred. Please try again.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ── Email / Password Sign-Up ──────────────────────────────────────────────

  /// Creates a new Firebase Auth account, then creates the Firestore profile
  /// document.  Returns `true` on success.
  ///
  /// The profile is created with [phoneNumberVerified] = false — the user
  /// must complete the phone verification flow before [isProfileComplete]
  /// becomes true.
  Future<bool> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    _setError(null);
    _setLoading(true);
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final fbUser = credential.user!;

      // Update the Auth display name so AppUser.name works immediately.
      await fbUser.updateDisplayName(displayName);
      await fbUser.reload();

      // Create the Firestore profile document.
      final profile = UserProfile(
        uid: fbUser.uid,
        displayName: displayName,
        email: email,
        photoUrl: fbUser.photoURL,
        phoneNumber: null,
        phoneNumberVerified: false,
      );
      await _repo.createProfile(profile);

      return true;
    } on FirebaseAuthException catch (e) {
      _setError(_friendlySignUpError(e.code));
      return false;
    } catch (_) {
      _setError('An unexpected error occurred. Please try again.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ── Google Sign-In ────────────────────────────────────────────────────────

  /// Signs in with Google.  If this is the first sign-in, creates the
  /// Firestore profile document automatically (without a verified phone —
  /// the completion gate will redirect the user to add/verify their number).
  ///
  /// Returns `true` on success.
  Future<bool> signInWithGoogle() async {
    _setError(null);
    _setLoading(true);
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        _setLoading(false);
        return false;
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final result = await _auth.signInWithCredential(credential);
      final fbUser = result.user!;

      // Bootstrap Firestore profile for first-time Google users.
      await _repo.createProfileIfAbsent(
        UserProfile(
          uid: fbUser.uid,
          displayName: fbUser.displayName ?? googleUser.displayName ?? '',
          email: fbUser.email ?? googleUser.email,
          photoUrl: fbUser.photoURL ?? googleUser.photoUrl,
          phoneNumber: null,
          phoneNumberVerified: false,
        ),
      );

      return true;
    } on FirebaseAuthException catch (e) {
      _setError(_friendlyError(e.code));
      return false;
    } catch (_) {
      _setError('Google sign-in failed. Please try again.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ── Change Password ───────────────────────────────────────────────────────

  /// Re-authenticates with [currentPassword] then updates to [newPassword].
  /// Returns `true` on success.
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    _setError(null);
    _setLoading(true);
    try {
      final fbUser = _auth.currentUser;
      if (fbUser == null) throw StateError('No authenticated user.');

      // Re-authenticate first — Firebase requires recent auth for
      // sensitive operations.
      final credential = EmailAuthProvider.credential(
        email: fbUser.email!,
        password: currentPassword,
      );
      await fbUser.reauthenticateWithCredential(credential);
      await fbUser.updatePassword(newPassword);
      return true;
    } on FirebaseAuthException catch (e) {
      _setError(_friendlyPasswordError(e.code));
      return false;
    } catch (_) {
      _setError('Password change failed. Please try again.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ── Sign Out ──────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
      if (_googleSignIn.currentUser != null) _googleSignIn.signOut(),
    ]);
  }

  // ── Sign Out All Devices ──────────────────────────────────────────────────

  /// Revokes the current session token.  Firebase does not have a single
  /// "sign out all devices" endpoint from the client SDK, but revoking
  /// tokens via [User.getIdToken(true)] + signing out forces all existing
  /// tokens to be invalidated server-side on the next request.
  ///
  /// The most reliable client-side approach is to sign out locally; any
  /// other active sessions will be invalidated when their ID token next
  /// refreshes (within 1 hour by default).  For stronger immediate
  /// revocation a Cloud Function with Admin SDK `revokeRefreshTokens`
  /// would be needed — we note this limitation in the UI.
  Future<bool> signOutAllDevices() async {
    _setError(null);
    _setLoading(true);
    try {
      // Force a token refresh so the old token is no longer usable.
      await _auth.currentUser?.getIdToken(true);
      await signOut();
      return true;
    } catch (_) {
      _setError('Sign out failed. Please try again.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ── Re-authentication helper ──────────────────────────────────────────────

  /// Re-authenticates the current user.  Required before sensitive operations
  /// like account deletion or password change.
  ///
  /// For email/password accounts, pass [password].
  /// For Google accounts, triggers the Google re-auth flow (password ignored).
  ///
  /// Returns `true` on success.
  Future<bool> reauthenticate({String? password}) async {
    _setError(null);
    _setLoading(true);
    try {
      final fbUser = _auth.currentUser;
      if (fbUser == null) throw StateError('No authenticated user.');

      final isGoogle = fbUser.providerData
          .any((p) => p.providerId == 'google.com');

      if (isGoogle) {
        final googleUser = await _googleSignIn.signIn();
        if (googleUser == null) return false;
        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        await fbUser.reauthenticateWithCredential(credential);
      } else {
        if (password == null || password.isEmpty) {
          _setError('Password is required.');
          return false;
        }
        final credential = EmailAuthProvider.credential(
          email: fbUser.email!,
          password: password,
        );
        await fbUser.reauthenticateWithCredential(credential);
      }
      return true;
    } on FirebaseAuthException catch (e) {
      _setError(_friendlyError(e.code));
      return false;
    } catch (_) {
      _setError('Re-authentication failed. Please try again.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// True when the current user signed in with Google.
  bool get isGoogleUser =>
      _auth.currentUser?.providerData
          .any((p) => p.providerId == 'google.com') ??
      false;

  // ── Error mapping ─────────────────────────────────────────────────────────

  String _friendlyError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found for this email address.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'No internet connection. Check your network and try again.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with this email using a different sign-in method.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled. Please contact support.';
      case 'requires-recent-login':
        return 'Please sign in again before making this change.';
      default:
        return 'Sign in failed. Please try again.';
    }
  }

  String _friendlySignUpError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'An account already exists with this email address.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password must be at least 6 characters long.';
      case 'operation-not-allowed':
        return 'Email/password sign-up is not enabled. Please contact support.';
      case 'network-request-failed':
        return 'No internet connection. Check your network and try again.';
      default:
        return 'Sign up failed. Please try again.';
    }
  }

  String _friendlyPasswordError(String code) {
    switch (code) {
      case 'wrong-password':
      case 'invalid-credential':
        return 'Current password is incorrect.';
      case 'weak-password':
        return 'New password must be at least 6 characters long.';
      case 'requires-recent-login':
        return 'Please sign in again before changing your password.';
      case 'network-request-failed':
        return 'No internet connection. Check your network and try again.';
      default:
        return 'Password change failed. Please try again.';
    }
  }
}
