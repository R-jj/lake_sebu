import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/order.dart';
import '../services/user_repository.dart';

enum OrdersLoadState { idle, loading, loaded, error }

/// Provides the current user's orders via a real-time Firestore stream.
///
/// Lifecycle mirrors [UserProfileProvider]:
///   • Call [init(uid)] when the user authenticates.
///   • Call [clear()] on sign-out so no stale data leaks to the next session.
class OrdersProvider extends ChangeNotifier {
  final UserRepository _repo = UserRepository.instance;

  // ── State ─────────────────────────────────────────────────────────────────

  List<FoodOrder> _orders = [];
  OrdersLoadState _state = OrdersLoadState.idle;
  String? _error;
  String? _initializedUid;

  StreamSubscription<List<FoodOrder>>? _ordersSub;

  // ── Getters ───────────────────────────────────────────────────────────────

  List<FoodOrder> get orders => List.unmodifiable(_orders);
  OrdersLoadState get state => _state;
  bool get isLoading => _state == OrdersLoadState.loading;
  String? get error => _error;

  /// UID whose stream is currently active.  Null if [clear] has been called.
  String? get initializedUid => _initializedUid;

  /// Orders that are not yet delivered or cancelled (active / in-progress).
  List<FoodOrder> get activeOrders => _orders
      .where((o) =>
          o.status != FoodOrderStatus.delivered &&
          o.status != FoodOrderStatus.cancelled)
      .toList();

  /// Orders that are completed (delivered or cancelled).
  List<FoodOrder> get pastOrders => _orders
      .where((o) =>
          o.status == FoodOrderStatus.delivered ||
          o.status == FoodOrderStatus.cancelled)
      .toList();

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  /// Starts listening to the Firestore orders stream for [uid].
  /// Safe to call multiple times — skips re-init if [uid] is unchanged.
  Future<void> init(String uid) async {
    if (_initializedUid == uid) return;

    // Cancel any existing subscription first.
    await _ordersSub?.cancel();
    _ordersSub = null;

    _initializedUid = uid;
    _state = OrdersLoadState.loading;
    _error = null;
    notifyListeners();

    try {
      _ordersSub = _repo.ordersStream().listen(
        (orders) {
          _orders = orders;
          _state = OrdersLoadState.loaded;
          _error = null;
          notifyListeners();
        },
        onError: (Object e) {
          debugPrint('OrdersProvider stream error: $e');
          _state = OrdersLoadState.error;
          _error = _friendlyError(e);
          notifyListeners();
        },
      );
    } catch (e) {
      debugPrint('OrdersProvider.init error: $e');
      _state = OrdersLoadState.error;
      _error = _friendlyError(e);
      notifyListeners();
    }
  }

  /// Tears down the subscription and resets all state (called on sign-out).
  Future<void> clear() async {
    await _ordersSub?.cancel();
    _ordersSub = null;
    _initializedUid = null;
    _orders = [];
    _state = OrdersLoadState.idle;
    _error = null;
    notifyListeners();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _friendlyError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('permission') || msg.contains('denied')) {
      return 'Permission denied. Please sign in again.';
    }
    if (msg.contains('network') ||
        msg.contains('unavailable') ||
        msg.contains('offline')) {
      return 'No internet connection. Please try again.';
    }
    return 'Could not load orders. Please try again.';
  }

  @override
  void dispose() {
    _ordersSub?.cancel();
    super.dispose();
  }
}
