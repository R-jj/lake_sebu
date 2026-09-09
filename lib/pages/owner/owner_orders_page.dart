import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants.dart';
import '../../models/order.dart';
import '../../providers/owner_orders_provider.dart';
import 'owner_order_detail_page.dart';
import '../order_map_page.dart';

/// Displays all orders for the restaurant, grouped by a filter tab:
///   All  │  Pending  │  Active  │  Completed
///
/// Orders update in real time via [OwnerOrdersProvider].
class OwnerOrdersPage extends StatefulWidget {
  const OwnerOrdersPage({super.key});

  @override
  State<OwnerOrdersPage> createState() => _OwnerOrdersPageState();
}

class _OwnerOrdersPageState extends State<OwnerOrdersPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OwnerOrdersProvider>();
    final all = provider.orders;
    final pending = provider.pendingOrders;
    final active = provider.activeOrders;
    final completed = provider.completedOrders;

    return Scaffold(
      backgroundColor: kCanvas,
      body: NestedScrollView(
        headerSliverBuilder: (ctx, _) => [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Text(
                'Orders',
                style: kSerif.copyWith(
                  color: kInk,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _buildTabBar(
                pending: pending.length, active: active.length),
          ),
        ],
        body: provider.isLoading
            ? const Center(
                child: CircularProgressIndicator(
                    color: kBrand, strokeWidth: 2))
            : provider.error != null
                ? _ErrorView(message: provider.error!)
                : TabBarView(
                    controller: _tabCtrl,
                    children: [
                      _OrderList(orders: all),
                      _OrderList(orders: pending),
                      _OrderList(orders: active),
                      _OrderList(orders: completed),
                    ],
                  ),
      ),
    );
  }

  Widget _buildTabBar({required int pending, required int active}) {
    const labelStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
    );

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: TabBar(
        controller: _tabCtrl,
        padding: const EdgeInsets.all(4),
        indicator: BoxDecoration(
          color: kBrand,
          borderRadius: BorderRadius.circular(8),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: kInk,
        unselectedLabelColor: kMuted,
        labelStyle: labelStyle,
        unselectedLabelStyle: labelStyle,
        dividerColor: Colors.transparent,
        tabs: [
          const Tab(text: 'All'),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Pending'),
                if (pending > 0) ...[
                  const SizedBox(width: 4),
                  _Badge(count: pending),
                ],
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Active'),
                if (active > 0) ...[
                  const SizedBox(width: 4),
                  _Badge(count: active),
                ],
              ],
            ),
          ),
          const Tab(text: 'Done'),
        ],
      ),
    );
  }
}

// ── Small tab badge ────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final int count;
  const _Badge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: kInk.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ── Order list ─────────────────────────────────────────────────────────────────

class _OrderList extends StatelessWidget {
  final List<FoodOrder> orders;
  const _OrderList({required this.orders});

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, color: kMuted, size: 48),
            SizedBox(height: 12),
            Text('No orders here',
                style: TextStyle(color: kInk, fontSize: 15,
                    fontWeight: FontWeight.w600)),
            SizedBox(height: 6),
            Text('Nothing to show in this category.',
                style: TextStyle(color: kMuted, fontSize: 13)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      itemCount: orders.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) => _OrderCard(order: orders[i]),
    );
  }
}

// ── Order card ─────────────────────────────────────────────────────────────────

class _OrderCard extends StatelessWidget {
  final FoodOrder order;
  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final createdAt = order.createdAt;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OwnerOrderDetailPage(order: order),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top row: order id + status chip ─────────────────────────
            Row(
              children: [
                Expanded(
                  child: Text(
                    '#${order.orderId.substring(0, 8).toUpperCase()}',
                    style: const TextStyle(
                        color: kMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5),
                  ),
                ),
                _StatusChip(status: order.status),
              ],
            ),
            const SizedBox(height: 10),

            // ── Customer name ────────────────────────────────────────────
            Text(
              order.customerName,
              style: const TextStyle(
                  color: kInk, fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),

            // ── Items summary ────────────────────────────────────────────
            Text(
              order.items
                  .map((it) =>
                      '${it['qty']}× ${it['name']}')
                  .join(', '),
              style: const TextStyle(color: kMuted, fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),

            // ── Footer: total + date ─────────────────────────────────────
            Row(
              children: [
                Text(
                  formatPeso(order.total),
                  style: const TextStyle(
                      color: kInk,
                      fontSize: 14,
                      fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                if (order.hasDeliveryCoordinates) ...[
                  // Location pin — inner GestureDetector wins over the
                  // card tap, so this opens the map, not the detail page.
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OrderMapPage(
                          lat: order.deliveryLat!,
                          lng: order.deliveryLng!,
                          address: order.deliveryAddress,
                        ),
                      ),
                    ),
                    child: const Icon(Icons.location_on_outlined,
                        color: kBrand, size: 18),
                  ),
                  const SizedBox(width: 8),
                ],
                if (createdAt != null)
                  Text(
                    _formatDate(createdAt),
                    style: const TextStyle(color: kMuted, fontSize: 11),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// ── Status chip (shared) ───────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final FoodOrderStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (status) {
      FoodOrderStatus.pending =>
        ('Pending', kGold.withValues(alpha: 0.15), kGold),
      FoodOrderStatus.confirmed =>
        ('Confirmed', kBrand.withValues(alpha: 0.15), kBrand),
      FoodOrderStatus.preparing =>
        ('Preparing', kBrand.withValues(alpha: 0.15), kBrand),
      FoodOrderStatus.onTheWay =>
        ('On the way', kBrand.withValues(alpha: 0.15), kBrand),
      FoodOrderStatus.delivered =>
        ('Delivered', kGreen.withValues(alpha: 0.15), kGreen),
      FoodOrderStatus.cancelled =>
        ('Cancelled', kRed.withValues(alpha: 0.15), kRed),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: TextStyle(
              color: fg, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}

// ── Error view ─────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, color: kMuted, size: 48),
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(color: kMuted, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
