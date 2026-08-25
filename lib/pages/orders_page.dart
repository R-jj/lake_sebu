import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants.dart';
import '../models/order.dart';
import '../providers/orders_provider.dart';
import 'order_detail_page.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  bool _showActive = true;

  // ── Status helpers ────────────────────────────────────────────────────────

  Color _statusColor(FoodOrderStatus s) {
    switch (s) {
      case FoodOrderStatus.delivered:
        return kGreen;
      case FoodOrderStatus.cancelled:
        return kRed;
      default:
        return kGold;
    }
  }

  Color _statusBg(FoodOrderStatus s) {
    switch (s) {
      case FoodOrderStatus.delivered:
        return kGreen.withValues(alpha: 0.12);
      case FoodOrderStatus.cancelled:
        return kRed.withValues(alpha: 0.12);
      default:
        return kGold.withValues(alpha: 0.12);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final ordersProvider = context.watch<OrdersProvider>();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your orders',
                  style: kSerif.copyWith(
                    color: kInk,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: kSurface,
                    border: Border.all(color: kBorder),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _tabButton(
                          'Active',
                          _showActive,
                          () => setState(() => _showActive = true),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: _tabButton(
                          'Past orders',
                          !_showActive,
                          () => setState(() => _showActive = false),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            child: _buildBody(ordersProvider),
          ),
        ],
      ),
    );
  }

  // ── Body dispatcher ───────────────────────────────────────────────────────

  Widget _buildBody(OrdersProvider provider) {
    // Show a full-area loading indicator while the first batch is in flight.
    if (provider.isLoading) {
      return const _LoadingState();
    }

    // Show a friendly error card with retry info.
    if (provider.state == OrdersLoadState.error) {
      return _ErrorState(message: provider.error);
    }

    final list = _showActive ? provider.activeOrders : provider.pastOrders;

    if (list.isEmpty) {
      return _EmptyState(isActive: _showActive);
    }

    return _showActive ? _buildActiveOrders(list) : _buildPastOrders(list);
  }

  // ── Active orders ─────────────────────────────────────────────────────────

  Widget _buildActiveOrders(List<FoodOrder> orders) {
    return Column(
      children: orders
          .map((order) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _ActiveOrderCard(order: order),
              ))
          .toList(),
    );
  }

  // ── Past orders ───────────────────────────────────────────────────────────

  Widget _buildPastOrders(List<FoodOrder> orders) {
    return Column(
      children: orders.map((order) {
        final status = order.status;
        final itemSummary = order.items
            .map((i) =>
                '${i['name'] ?? 'Item'} ×${i['qty'] ?? 1}')
            .join(' · ');
        final dateLabel = order.createdAt != null
            ? _formatDate(order.createdAt!)
            : '';

        return GestureDetector(
          onTap: () => _openDetail(order),
          child: Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kSurface,
              border: Border.all(color: kSurface2),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Restaurant image placeholder (no per-restaurant image
                    // stored on the order; use a food icon instead).
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: kSurface2,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.storefront_outlined,
                        color: kMuted,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.restaurantName,
                            style: const TextStyle(
                              color: kInk,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${order.orderId.substring(0, 8).toUpperCase()} · $dateLabel',
                            style: const TextStyle(
                              color: kMuted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _statusBg(status),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        status.displayLabel,
                        style: TextStyle(
                          color: _statusColor(status),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.only(top: 10),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: kSurface2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        itemSummary,
                        style: const TextStyle(color: kMuted, fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            formatPeso(order.total),
                            style: const TextStyle(
                              color: kInk,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                          // "View details" chevron — tap anywhere on card also works.
                          const Icon(
                            Icons.chevron_right,
                            color: kMuted,
                            size: 18,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  void _openDetail(FoodOrder order) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OrderDetailPage(order: order),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  // ── Tab button ────────────────────────────────────────────────────────────

  Widget _tabButton(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? kBrand : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : kMuted,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ── Active order card ─────────────────────────────────────────────────────────

/// Displays a single in-progress order with a status stepper.
/// No "Track live" button — live tracking has been removed.
class _ActiveOrderCard extends StatelessWidget {
  final FoodOrder order;
  const _ActiveOrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final steps = _buildSteps(order.status);

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => OrderDetailPage(order: order)),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: kSurface,
          border: Border.all(color: kBorder),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ORDER ${order.orderId.substring(0, 8).toUpperCase()}',
                        style: const TextStyle(
                          color: kMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        order.restaurantName,
                        style: const TextStyle(
                          color: kInk,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _StatusPill(status: order.status),
              ],
            ),
            const SizedBox(height: 16),
            // ── Stepper ──────────────────────────────────────────────────────
            ...List.generate(steps.length, (i) {
              final step = steps[i];
              final isDone = step['done'] as bool;
              final isLast = i == steps.length - 1;
              return Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: isDone ? kBrand : kSurface2,
                            border: Border.all(
                              color: isDone ? kBrand : kBorder,
                              width: 2,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Icon(
                              step['icon'] as IconData,
                              size: 14,
                              color: isDone ? Colors.white : kMuted,
                            ),
                          ),
                        ),
                        if (!isLast)
                          Container(
                            width: 2,
                            height: 16,
                            margin: const EdgeInsets.only(top: 2),
                            color: isDone ? kBrand : kBorder,
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(
                        step['label'] as String,
                        style: TextStyle(
                          color: isDone ? kInk : kMuted,
                          fontSize: 14,
                          fontWeight:
                              isDone ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),
            // ── Footer: tap for details ──────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: kSurface2,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Order total',
                        style: TextStyle(color: kMuted, fontSize: 11),
                      ),
                      Text(
                        formatPeso(order.total),
                        style: const TextStyle(
                          color: kInk,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const Row(
                    children: [
                      Text(
                        'View details',
                        style: TextStyle(
                          color: kBrand,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.chevron_right, color: kBrand, size: 16),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds stepper step data based on the current order status.
  /// Each step is marked `done: true` if the order has reached or passed it.
  List<Map<String, Object>> _buildSteps(FoodOrderStatus status) {
    // Map status → how many steps are "done".
    final doneCount = _doneCountFor(status);
    return [
      {
        'label': 'Order placed',
        'icon': Icons.receipt_long_outlined,
        'done': doneCount >= 1,
      },
      {
        'label': 'Confirmed',
        'icon': Icons.check,
        'done': doneCount >= 2,
      },
      {
        'label': 'Being prepared',
        'icon': Icons.soup_kitchen_outlined,
        'done': doneCount >= 3,
      },
      {
        'label': 'Out for delivery',
        'icon': Icons.delivery_dining,
        'done': doneCount >= 4,
      },
    ];
  }

  int _doneCountFor(FoodOrderStatus status) {
    switch (status) {
      case FoodOrderStatus.pending:
        return 1;
      case FoodOrderStatus.confirmed:
        return 2;
      case FoodOrderStatus.preparing:
        return 3;
      case FoodOrderStatus.onTheWay:
        return 4;
      default:
        return 1;
    }
  }
}

// ── Status pill ───────────────────────────────────────────────────────────────

class _StatusPill extends StatelessWidget {
  final FoodOrderStatus status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _color();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        '● ${status.displayLabel}',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Color _color() {
    switch (status) {
      case FoodOrderStatus.delivered:
        return kGreen;
      case FoodOrderStatus.cancelled:
        return kRed;
      default:
        return kGold;
    }
  }
}

// ── Loading state ─────────────────────────────────────────────────────────────

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 200,
      child: Center(
        child: CircularProgressIndicator(color: kBrand, strokeWidth: 2),
      ),
    );
  }
}

// ── Error state ───────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final String? message;
  const _ErrorState({this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kRed.withValues(alpha: 0.08),
        border: Border.all(color: kRed.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: kRed, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message ?? 'Could not load orders. Please try again.',
              style: const TextStyle(color: kInk, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool isActive;
  const _EmptyState({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: kSurface,
        border: Border.all(color: kBorder),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: kSurface2,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              isActive ? Icons.hourglass_empty_outlined : Icons.receipt_long_outlined,
              color: kMuted,
              size: 28,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isActive ? 'No active orders' : 'No past orders yet',
            style: const TextStyle(
              color: kInk,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isActive
                ? 'Orders you place will appear here while they\'re being prepared.'
                : 'Your order history will show up here once you\'ve placed orders.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: kMuted, fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }
}
