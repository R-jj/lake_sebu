import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants.dart';
import '../models/order.dart';
import '../providers/orders_provider.dart';
import 'order_map_page.dart';

/// Full-detail view for a single [FoodOrder].
///
/// Watches [OrdersProvider] so the status, stepper, and all order fields
/// update in real time whenever the restaurant owner advances the order.
/// The [order] parameter provides the initial snapshot used to identify
/// the document by [FoodOrder.orderId].
class OrderDetailPage extends StatefulWidget {
  final FoodOrder order;

  const OrderDetailPage({super.key, required this.order});

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {

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
    // Resolve the live order from the provider stream.  Falls back to the
    // initial snapshot if the provider hasn't loaded yet or the order has
    // scrolled out of the provider's in-memory list (e.g. very old orders).
    final liveOrder = context
            .watch<OrdersProvider>()
            .orders
            .where((o) => o.orderId == widget.order.orderId)
            .firstOrNull ??
        widget.order;

    return Scaffold(
      backgroundColor: kCanvas,
      appBar: AppBar(
        backgroundColor: kCanvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: kInk, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Order details',
          style: kSerif.copyWith(
            color: kInk,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOrderHeader(liveOrder),
            const SizedBox(height: 20),
            _buildStatusCard(liveOrder),
            const SizedBox(height: 20),
            _buildItemsCard(liveOrder),
            const SizedBox(height: 20),
            _buildPricingCard(liveOrder),
            const SizedBox(height: 20),
            _buildDeliveryCard(liveOrder),
            const SizedBox(height: 20),
            _buildCustomerCard(liveOrder),
          ],
        ),
      ),
    );
  }

  // ── Order header ──────────────────────────────────────────────────────────

  Widget _buildOrderHeader(FoodOrder order) {
    final dateLabel = order.createdAt != null
        ? _formatDateTime(order.createdAt!)
        : 'Date unavailable';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.restaurantName,
                    style: const TextStyle(
                      color: kInk,
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateLabel,
                    style: const TextStyle(color: kMuted, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _statusBg(order.status),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                order.status.displayLabel,
                style: TextStyle(
                  color: _statusColor(order.status),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Order ID: ${order.orderId}',
          style: const TextStyle(
            color: kMuted,
            fontSize: 11,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  // ── Status card ───────────────────────────────────────────────────────────

  Widget _buildStatusCard(FoodOrder order) {
    // Cancelled orders: show a clear cancelled notice instead of nothing.
    if (order.status == FoodOrderStatus.cancelled) {
      return _SectionCard(
        title: 'Order status',
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: kRed.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.cancel_outlined, color: kRed, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order cancelled',
                    style: TextStyle(
                      color: kRed,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'This order was cancelled by the restaurant.',
                    style: TextStyle(color: kMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Delivered orders: show a completed notice.
    if (order.status == FoodOrderStatus.delivered) {
      return _SectionCard(
        title: 'Order status',
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: kGreen.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.check_circle_outline, color: kGreen, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Delivered',
                    style: TextStyle(
                      color: kGreen,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Your order has been delivered.',
                    style: TextStyle(color: kMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Active orders: show the progress stepper.
    final steps = _buildSteps(order.status);

    return _SectionCard(
      title: 'Order status',
      child: Column(
        children: List.generate(steps.length, (i) {
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
      ),
    );
  }

  List<Map<String, Object>> _buildSteps(FoodOrderStatus status) {
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

  // ── Items card ────────────────────────────────────────────────────────────

  Widget _buildItemsCard(FoodOrder order) {
    return _SectionCard(
      title: 'Items ordered',
      child: Column(
        children: List.generate(order.items.length, (i) {
          final item = order.items[i];
          final name = item['name'] as String? ?? 'Item';
          final price = (item['price'] as num?)?.toDouble() ?? 0.0;
          final qty = (item['qty'] as num?)?.toInt() ?? 1;
          final isLast = i == order.items.length - 1;

          return Column(
            children: [
              Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Quantity badge
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: kBrand.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '×$qty',
                        style: const TextStyle(
                          color: kBrand,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          color: kInk,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      formatPeso(price * qty),
                      style: const TextStyle(
                        color: kInk,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLast) ...[
                const SizedBox(height: 12),
                const Divider(color: kSurface2, height: 1),
              ],
            ],
          );
        }),
      ),
    );
  }

  // ── Pricing card ──────────────────────────────────────────────────────────

  Widget _buildPricingCard(FoodOrder order) {
    return _SectionCard(
      title: 'Payment summary',
      child: Column(
        children: [
          _PriceRow(label: 'Subtotal', amount: order.subtotal),
          const SizedBox(height: 10),
          _PriceRow(label: 'Delivery fee', amount: order.deliveryFee),
          if (order.discount > 0) ...[
            const SizedBox(height: 10),
            _PriceRow(
              label: order.promoCode != null
                  ? 'Discount (${order.promoCode})'
                  : 'Discount',
              amount: -order.discount,
              isDiscount: true,
            ),
          ],
          const SizedBox(height: 12),
          const Divider(color: kBorder, height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total',
                style: TextStyle(
                  color: kInk,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                formatPeso(order.total),
                style: const TextStyle(
                  color: kInk,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Delivery card ─────────────────────────────────────────────────────────

  Widget _buildDeliveryCard(FoodOrder order) {
    return _SectionCard(
      title: 'Delivery address',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: kBrand.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.location_on_outlined,
                    color: kBrand, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  order.deliveryAddress.isNotEmpty
                      ? order.deliveryAddress
                      : 'No address provided',
                  style: const TextStyle(
                    color: kInk,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
          if (order.hasDeliveryCoordinates) ...[
            const SizedBox(height: 14),
            OrderMapThumbnail(
              lat: order.deliveryLat!,
              lng: order.deliveryLng!,
              address: order.deliveryAddress,
            ),
          ],
        ],
      ),
    );
  }

  // ── Customer card ─────────────────────────────────────────────────────────

  Widget _buildCustomerCard(FoodOrder order) {
    return _SectionCard(
      title: 'Contact information',
      child: Column(
        children: [
          _InfoRow(
            icon: Icons.person_outline,
            label: 'Name',
            value: order.customerName.isNotEmpty
                ? order.customerName
                : 'Not provided',
          ),
          const SizedBox(height: 12),
          _InfoRow(
            icon: Icons.phone_outlined,
            label: 'Phone',
            value: order.customerPhone.isNotEmpty
                ? order.customerPhone
                : 'Not provided',
          ),
        ],
      ),
    );
  }

  // ── Date formatter ────────────────────────────────────────────────────────

  String _formatDateTime(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour < 12 ? 'AM' : 'PM';
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} · $hour:$minute $period';
  }
}

// ── Reusable section card ─────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kSurface,
        border: Border.all(color: kBorder),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: kMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

// ── Price row ─────────────────────────────────────────────────────────────────

class _PriceRow extends StatelessWidget {
  final String label;
  final double amount;
  final bool isDiscount;

  const _PriceRow({
    required this.label,
    required this.amount,
    this.isDiscount = false,
  });

  @override
  Widget build(BuildContext context) {
    final display = isDiscount
        ? '-${formatPeso(amount.abs())}'
        : formatPeso(amount);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: kMuted, fontSize: 13)),
        Text(
          display,
          style: TextStyle(
            color: isDiscount ? kGreen : kInk,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ── Info row ──────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: kMuted, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: kMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: kInk,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
