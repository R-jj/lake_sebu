import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants.dart';
import '../../models/order.dart';
import '../../providers/auth_provider.dart';
import '../../providers/owner_orders_provider.dart';
import '../../services/owner_repository.dart';

/// Dashboard shown to restaurant owners on first entry.
///
/// Displays:
///   • Restaurant name (loaded from Firestore)
///   • Live order stat cards (pending / active / completed) sourced from
///     [OwnerOrdersProvider] — updates in real time via the Firestore stream.
///   • Recent 5 orders list.
class OwnerDashboardPage extends StatefulWidget {
  const OwnerDashboardPage({super.key});

  @override
  State<OwnerDashboardPage> createState() => _OwnerDashboardPageState();
}

class _OwnerDashboardPageState extends State<OwnerDashboardPage> {
  String? _restaurantName;
  bool _restaurantLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRestaurant();
  }

  Future<void> _loadRestaurant() async {
    final rid =
        context.read<AppAuthProvider>().restaurantId;
    if (rid == null) {
      setState(() => _restaurantLoading = false);
      return;
    }
    try {
      final data =
          await OwnerRepository.instance.fetchRestaurant(rid);
      if (mounted) {
        setState(() {
          _restaurantName = data?['name'] as String? ?? 'Your Restaurant';
          _restaurantLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _restaurantLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orders = context.watch<OwnerOrdersProvider>();

    return Scaffold(
      backgroundColor: kCanvas,
      body: RefreshIndicator(
        color: kBrand,
        backgroundColor: kSurface,
        onRefresh: _loadRestaurant,
        child: CustomScrollView(
          slivers: [
            // ── Header ──────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dashboard',
                      style: kSerif.copyWith(
                        color: kInk,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _restaurantLoading
                        ? Container(
                            width: 160,
                            height: 14,
                            decoration: BoxDecoration(
                              color: kSurface2,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          )
                        : Text(
                            _restaurantName ?? 'Your Restaurant',
                            style: const TextStyle(
                                color: kMuted, fontSize: 14),
                          ),
                  ],
                ),
              ),
            ),

            // ── Stat cards ───────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: orders.isLoading
                    ? _StatsShimmer()
                    : Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              label: 'Pending',
                              value: orders.pendingCount,
                              color: kGold,
                              icon: Icons.hourglass_top_rounded,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              label: 'Active',
                              value: orders.activeCount,
                              color: kBrand,
                              icon: Icons.local_fire_department_rounded,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              label: 'Completed',
                              value: orders.completedCount,
                              color: kGreen,
                              icon: Icons.check_circle_outline_rounded,
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            // ── Recent orders header ─────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
                child: Text(
                  'Recent Orders',
                  style: kSerif.copyWith(
                    color: kInk,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),

            // ── Recent orders list ───────────────────────────────────────────
            if (orders.isLoading)
              const SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: CircularProgressIndicator(
                        color: kBrand, strokeWidth: 2),
                  ),
                ),
              )
            else if (orders.error != null)
              SliverToBoxAdapter(child: _ErrorBanner(message: orders.error!))
            else if (orders.orders.isEmpty)
              const SliverToBoxAdapter(child: _EmptyOrders())
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final recent = orders.orders.take(5).toList();
                    if (i >= recent.length) return null;
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                      child: _RecentOrderCard(order: recent[i]),
                    );
                  },
                  childCount: orders.orders.take(5).length,
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}

// ── Stat card ──────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 10),
          Text(
            '$value',
            style: kSerif.copyWith(
              color: kInk,
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: kMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ── Recent order card ──────────────────────────────────────────────────────────

class _RecentOrderCard extends StatelessWidget {
  final FoodOrder order;
  const _RecentOrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        children: [
          // Status dot
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _statusColor(order.status),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.customerName,
                  style: const TextStyle(
                      color: kInk,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '${order.items.length} item${order.items.length == 1 ? '' : 's'}'
                  ' · ${formatPeso(order.total)}',
                  style:
                      const TextStyle(color: kMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          _StatusChip(status: order.status),
        ],
      ),
    );
  }

  Color _statusColor(FoodOrderStatus s) {
    switch (s) {
      case FoodOrderStatus.pending:
        return kGold;
      case FoodOrderStatus.confirmed:
      case FoodOrderStatus.preparing:
      case FoodOrderStatus.onTheWay:
        return kBrand;
      case FoodOrderStatus.delivered:
        return kGreen;
      case FoodOrderStatus.cancelled:
        return kRed;
    }
  }
}

// ── Status chip ────────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final FoodOrderStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (status) {
      FoodOrderStatus.pending => ('Pending', kGold.withValues(alpha: 0.15), kGold),
      FoodOrderStatus.confirmed => ('Confirmed', kBrand.withValues(alpha: 0.15), kBrand),
      FoodOrderStatus.preparing => ('Preparing', kBrand.withValues(alpha: 0.15), kBrand),
      FoodOrderStatus.onTheWay => ('On the way', kBrand.withValues(alpha: 0.15), kBrand),
      FoodOrderStatus.delivered => ('Delivered', kGreen.withValues(alpha: 0.15), kGreen),
      FoodOrderStatus.cancelled => ('Cancelled', kRed.withValues(alpha: 0.15), kRed),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: fg, fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ── Stats shimmer ──────────────────────────────────────────────────────────────

class _StatsShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(3, (i) {
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(left: i == 0 ? 0 : 12),
            height: 90,
            decoration: BoxDecoration(
              color: kSurface2,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      }),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────────

class _EmptyOrders extends StatelessWidget {
  const _EmptyOrders();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48, horizontal: 32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, color: kMuted, size: 48),
            SizedBox(height: 12),
            Text(
              'No orders yet',
              style: TextStyle(
                  color: kInk, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 6),
            Text(
              'New orders from customers will appear here.',
              style: TextStyle(color: kMuted, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error banner ───────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: kRed.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kRed.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: kRed, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message,
                  style: const TextStyle(color: kRed, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }
}
