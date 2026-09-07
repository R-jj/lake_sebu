import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/order.dart';
import '../services/owner_repository.dart';
import '../services/owner_notification_service.dart';

enum OwnerOrdersLoadState { idle, loading, loaded, error }

/// Provides real-time order data for a restaurant owner.
///
/// Lifecycle mirrors [OrdersProvider]:
///   • Call [init(restaurantId)] when the owner authenticates.
///   • Call [clear()] on sign-out so no stale data leaks.
///
/// The stream is filtered by [restaurantId] on the Firestore side, so an
/// owner can never see another restaurant's orders through this provider
/// (and the security rules enforce the same constraint server-side).
class OwnerOrdersProvider extends ChangeNotifier {
  final OwnerRepository _repo = OwnerRepository.instance;

  // ── State ─────────────────────────────────────────────────────────────────

  List<FoodOrder> _orders = [];
  OwnerOrdersLoadState _state = OwnerOrdersLoadState.idle;
  String? _error;
  String? _initializedRestaurantId;

  StreamSubscription<List<FoodOrder>>? _ordersSub;

  // ── Getters ───────────────────────────────────────────────────────────────

  List<FoodOrder> get orders => List.unmodifiable(_orders);
  OwnerOrdersLoadState get state => _state;
  bool get isLoading => _state == OwnerOrdersLoadState.loading;
  String? get error => _error;

  /// The restaurantId whose stream is currently active.
  String? get initializedRestaurantId => _initializedRestaurantId;

  // ── Derived order lists ───────────────────────────────────────────────────

  /// New orders waiting for the owner to acknowledge.
  List<FoodOrder> get pendingOrders =>
      _orders.where((o) => o.status == FoodOrderStatus.pending).toList();

  /// Orders in progress (confirmed, preparing, on the way).
  List<FoodOrder> get activeOrders => _orders
      .where((o) =>
          o.status == FoodOrderStatus.confirmed ||
          o.status == FoodOrderStatus.preparing ||
          o.status == FoodOrderStatus.onTheWay)
      .toList();

  /// Completed or cancelled orders.
  List<FoodOrder> get completedOrders => _orders
      .where((o) =>
          o.status == FoodOrderStatus.delivered ||
          o.status == FoodOrderStatus.cancelled)
      .toList();

  int get pendingCount => pendingOrders.length;
  int get activeCount => activeOrders.length;
  int get completedCount => completedOrders.length;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  /// Starts listening to the Firestore orders stream for [restaurantId].
  /// Safe to call multiple times — skips re-init if [restaurantId] is unchanged.
  Future<void> init(String restaurantId) async {
    if (_initializedRestaurantId == restaurantId) return;

    await _ordersSub?.cancel();
    _ordersSub = null;

    _initializedRestaurantId = restaurantId;
    _state = OwnerOrdersLoadState.loading;
    _error = null;
    notifyListeners();

    try {
      _ordersSub = _repo.ordersStream(restaurantId).listen(
        (orders) {
          _orders = orders;
          _state = OwnerOrdersLoadState.loaded;
          _error = null;
          notifyListeners();
          // Trigger or silence the alarm based on current pending count
          OwnerNotificationService.instance
              .onPendingCountChanged(pendingCount);
        },
        onError: (Object e) {
          debugPrint('OwnerOrdersProvider stream error: $e');
          _state = OwnerOrdersLoadState.error;
          _error = _friendlyError(e);
          notifyListeners();
        },
      );
    } catch (e) {
      debugPrint('OwnerOrdersProvider.init error: $e');
      _state = OwnerOrdersLoadState.error;
      _error = _friendlyError(e);
      notifyListeners();
    }
  }

  /// Tears down the subscription and resets all state (called on sign-out).
  Future<void> clear() async {
    await _ordersSub?.cancel();
    _ordersSub = null;
    _initializedRestaurantId = null;
    _orders = [];
    _state = OwnerOrdersLoadState.idle;
    _error = null;
    notifyListeners();
    // Silence the alarm when the owner signs out
    OwnerNotificationService.instance.onPendingCountChanged(0);
  }

  // ── Order status update ───────────────────────────────────────────────────

  /// Updates the status of [orderId].  Returns an error string on failure,
  /// or null on success.
  Future<String?> updateOrderStatus(
    String orderId,
    FoodOrderStatus status,
  ) async {
    try {
      await _repo.updateOrderStatus(orderId, status);
      return null;
    } catch (e) {
      debugPrint('OwnerOrdersProvider.updateOrderStatus error: $e');
      return _friendlyError(e);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _friendlyError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('permission') || msg.contains('denied')) {
      return 'Permission denied. You may not have access to this restaurant\'s orders.';
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
