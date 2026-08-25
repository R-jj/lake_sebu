import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/user_profile.dart';
import '../models/address.dart';
import '../models/favourite.dart';
import '../services/user_repository.dart';
import 'auth_provider.dart';

enum ProfileLoadState { idle, loading, loaded, error }

/// State management for the authenticated user's Firestore profile,
/// saved addresses, and favourited menu items.
///
/// Lifecycle
/// ─────────
/// • Call [init(uid)] as soon as the user is authenticated.
/// • Call [clear()] on sign-out so no stale data leaks to the next session.
/// • Streams are used for addresses and favourites so the UI reacts to
///   Firestore changes in real time.
class UserProfileProvider extends ChangeNotifier {
  final UserRepository _repo = UserRepository.instance;
  final AppAuthProvider _authProvider;

  UserProfileProvider(this._authProvider);

  // ── State ─────────────────────────────────────────────────────────────────

  UserProfile? _profile;
  List<Address> _addresses = [];
  Set<String> _favouriteIds = {};
  ProfileLoadState _profileState = ProfileLoadState.idle;
  String? _errorMessage;
  bool _addressesLoading = false;
  bool _favouritesLoading = false;

  StreamSubscription<UserProfile?>? _profileSub;
  StreamSubscription<List<Address>>? _addressSub;
  StreamSubscription<Set<String>>? _favSub;

  /// The uid that [init] was last called with.  Used by the
  /// [ChangeNotifierProxyProvider] guard to avoid tearing down live
  /// subscriptions on every [AppAuthProvider.notifyListeners] call.
  String? _initializedUid;

  // ── Getters ───────────────────────────────────────────────────────────────

  UserProfile? get profile => _profile;
  List<Address> get addresses => List.unmodifiable(_addresses);
  Set<String> get favouriteIds => Set.unmodifiable(_favouriteIds);
  ProfileLoadState get profileState => _profileState;
  bool get isProfileLoading => _profileState == ProfileLoadState.loading;
  bool get addressesLoading => _addressesLoading;
  bool get favouritesLoading => _favouritesLoading;
  String? get errorMessage => _errorMessage;

  /// The uid whose streams are currently active.  `null` means no streams
  /// have been started yet (or [clear] was called after sign-out).
  String? get initializedUid => _initializedUid;

  Address? get defaultAddress {
    try {
      return _addresses.firstWhere((a) => a.isDefault);
    } catch (_) {
      return _addresses.isNotEmpty ? _addresses.first : null;
    }
  }

  bool isFavourited(String menuItemId) => _favouriteIds.contains(menuItemId);

  // ── Initialisation ────────────────────────────────────────────────────────

  /// Starts real-time streams for the given [uid].
  /// Safe to call multiple times — cancels any existing subscriptions first.
  Future<void> init(String uid) async {
    await _cancelSubscriptions();

    _initializedUid = uid;
    _profileState = ProfileLoadState.loading;
    _errorMessage = null;
    notifyListeners();

    // ── Profile stream ────────────────────────────────────────────────────
    _profileSub = _repo.profileStream(uid).listen(
      (profile) {
        _profile = profile;
        _profileState = ProfileLoadState.loaded;

        // Keep AppAuthProvider's completion flag in sync.
        final complete = profile?.isComplete ?? false;
        if (complete) {
          _authProvider.markProfileComplete();
        } else {
          _authProvider.markProfileIncomplete();
        }
        notifyListeners();
      },
      onError: (e) {
        debugPrint('UserProfileProvider profile stream error: $e');
        _profileState = ProfileLoadState.error;
        _errorMessage = 'Failed to load profile. Please try again.';
        notifyListeners();
      },
    );

    // ── Addresses stream ──────────────────────────────────────────────────
    _addressesLoading = true;
    _addressSub = _repo.addressesStream().listen(
      (addresses) {
        _addresses = addresses;
        _addressesLoading = false;
        notifyListeners();
      },
      onError: (e) {
        debugPrint('UserProfileProvider addresses stream error: $e');
        _addressesLoading = false;
        notifyListeners();
      },
    );

    // ── Favourites stream ─────────────────────────────────────────────────
    _favouritesLoading = true;
    _favSub = _repo.favouriteIdsStream().listen(
      (ids) {
        _favouriteIds = ids;
        _favouritesLoading = false;
        notifyListeners();
      },
      onError: (e) {
        debugPrint('UserProfileProvider favourites stream error: $e');
        _favouritesLoading = false;
        notifyListeners();
      },
    );
  }

  /// Clears all state and cancels subscriptions.  Call on sign-out.
  Future<void> clear() async {
    await _cancelSubscriptions();
    _initializedUid = null;
    _profile = null;
    _addresses = [];
    _favouriteIds = {};
    _profileState = ProfileLoadState.idle;
    _errorMessage = null;
    _addressesLoading = false;
    _favouritesLoading = false;
    notifyListeners();
  }

  Future<void> _cancelSubscriptions() async {
    await _profileSub?.cancel();
    await _addressSub?.cancel();
    await _favSub?.cancel();
    _profileSub = null;
    _addressSub = null;
    _favSub = null;
  }

  @override
  void dispose() {
    _cancelSubscriptions();
    super.dispose();
  }

  // ── Profile actions ───────────────────────────────────────────────────────

  /// Updates display name and/or photo URL.
  /// Returns an error string on failure, or `null` on success.
  Future<String?> updateProfile({
    required String displayName,
    String? photoUrl,
  }) async {
    if (_profile == null) return 'Profile not loaded.';
    try {
      final updated = _profile!.copyWith(
        displayName: displayName,
        photoUrl: photoUrl,
      );
      await _repo.updateProfile(updated);
      return null;
    } catch (e) {
      debugPrint('UserProfileProvider.updateProfile error: $e');
      return 'Failed to update profile. Please try again.';
    }
  }

  // ── Address actions ───────────────────────────────────────────────────────

  /// Adds a new address for the current user.
  /// Returns an error string on failure, or `null` on success.
  Future<String?> addAddress(Address address) async {
    try {
      await _repo.addAddress(address);
      return null;
    } catch (e) {
      debugPrint('UserProfileProvider.addAddress error: $e');
      return 'Failed to save address. Please try again.';
    }
  }

  /// Updates an existing address.
  Future<String?> updateAddress(Address address) async {
    try {
      await _repo.updateAddress(address);
      return null;
    } catch (e) {
      debugPrint('UserProfileProvider.updateAddress error: $e');
      return 'Failed to update address. Please try again.';
    }
  }

  /// Deletes an address by its Firestore document ID.
  Future<String?> deleteAddress(String addressId) async {
    try {
      await _repo.deleteAddress(addressId);
      return null;
    } catch (e) {
      debugPrint('UserProfileProvider.deleteAddress error: $e');
      return 'Failed to remove address. Please try again.';
    }
  }

  /// Sets the address with [addressId] as the default delivery address.
  Future<String?> setDefaultAddress(String addressId) async {
    try {
      await _repo.setDefaultAddress(addressId);
      return null;
    } catch (e) {
      debugPrint('UserProfileProvider.setDefaultAddress error: $e');
      return 'Failed to update default address. Please try again.';
    }
  }

  // ── Favourite actions ─────────────────────────────────────────────────────

  /// Toggles the favourite state for [menuItemId].
  /// Returns an error string on failure, or `null` on success.
  Future<String?> toggleFavourite(String menuItemId) async {
    try {
      if (_favouriteIds.contains(menuItemId)) {
        await _repo.removeFavourite(menuItemId);
      } else {
        await _repo.addFavourite(menuItemId);
      }
      return null;
    } catch (e) {
      debugPrint('UserProfileProvider.toggleFavourite error: $e');
      return 'Failed to update favourites. Please try again.';
    }
  }

  Future<String?> addFavourite(String menuItemId) async {
    try {
      await _repo.addFavourite(menuItemId);
      return null;
    } catch (e) {
      debugPrint('UserProfileProvider.addFavourite error: $e');
      return 'Failed to add favourite. Please try again.';
    }
  }

  Future<String?> removeFavourite(String menuItemId) async {
    try {
      await _repo.removeFavourite(menuItemId);
      return null;
    } catch (e) {
      debugPrint('UserProfileProvider.removeFavourite error: $e');
      return 'Failed to remove favourite. Please try again.';
    }
  }

  // ── Fetch favourites with full item data ───────────────────────────────────

  /// Returns the full list of [Favourite] documents.
  Future<List<Favourite>> fetchFavouritesList() async {
    return _repo.fetchFavourites();
  }
}
