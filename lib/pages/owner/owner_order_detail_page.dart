import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants.dart';
import '../../models/order.dart';
import '../../providers/owner_orders_provider.dart';

/// Full-screen detail view for a single order.
///
/// Shows all order information and lets the restaurant owner advance (or
/// cancel) the order status.  Uses the same underlying Firestore document
/// as the customer's Orders page — no data duplication.
///
/// Status transitions allowed by the owner:
///   pending → confirmed → preparing → on_the_way → delivered
///   any     → cancelled
class OwnerOrderDetailPage extends StatefulWidget {
  final FoodOrder order;

  const OwnerOrderDetailPage({super.key, required this.order});

  @override
  State<OwnerOrderDetailPage> createState() =>
      _OwnerOrderDetailPageState();
}

class _OwnerOrderDetailPageState extends State<OwnerOrderDetailPage> {
  bool _updating = false;

  // ── Status transition logic ───────────────────────────────────────────────

  /// The next logical status the owner can advance to, or null if the
  /// order is already in a terminal state.
  FoodOrderStatus? _nextStatus(FoodOrderStatus current) {
    switch (current) {
      case FoodOrderStatus.pending:
        return FoodOrderStatus.confirmed;
      case FoodOrderStatus.confirmed:
        return FoodOrderStatus.preparing;
      case FoodOrderStatus.preparing:
        return FoodOrderStatus.onTheWay;
      case FoodOrderStatus.onTheWay:
        return FoodOrderStatus.delivered;
      case FoodOrderStatus.delivered:
      case FoodOrderStatus.cancelled:
        return null;
    }
  }

  String _nextLabel(FoodOrderStatus next) {
    switch (next) {
      case FoodOrderStatus.confirmed:
        return 'Confirm Order';
      case FoodOrderStatus.preparing:
        return 'Start Preparing';
      case FoodOrderStatus.onTheWay:
        return 'Mark as On the Way';
      case FoodOrderStatus.delivered:
        return 'Mark as Delivered';
      default:
        return 'Advance';
    }
  }

  Future<void> _updateStatus(FoodOrderStatus newStatus) async {
    setState(() => _updating = true);
    final error = await context
        .read<OwnerOrdersProvider>()
        .updateOrderStatus(widget.order.orderId, newStatus);
    if (!mounted) return;
    setState(() => _updating = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: kRed,
        ),
      );
    } else {
      // Stay on this page — the live stream already updates liveOrder,
      // so the status chip and action buttons refresh automatically.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order status updated.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _confirmCancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kSurface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancel Order',
            style: TextStyle(color: kInk, fontWeight: FontWeight.w700)),
        content: const Text(
          'Are you sure you want to cancel this order?\nThis cannot be undone.',
          style: TextStyle(color: kMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep', style: TextStyle(color: kMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel Order',
                style: TextStyle(color: kRed)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _updateStatus(FoodOrderStatus.cancelled);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch the live list so this page reflects status changes made
    // elsewhere (e.g. another device).
    final liveOrder = context
            .watch<OwnerOrdersProvider>()
            .orders
            .where((o) => o.orderId == widget.order.orderId)
            .firstOrNull ??
        widget.order;

    final next = _nextStatus(liveOrder.status);
    final isTerminal = liveOrder.status == FoodOrderStatus.delivered ||
        liveOrder.status == FoodOrderStatus.cancelled;

    return Scaffold(
      backgroundColor: kCanvas,
      appBar: AppBar(
        backgroundColor: kCanvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: kInk, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '#${liveOrder.orderId.substring(0, 8).toUpperCase()}',
          style: const TextStyle(
              color: kInk, fontSize: 16, fontWeight: FontWeight.w700),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _StatusChip(status: liveOrder.status),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Customer info ────────────────────────────────────────────
            _Section(
              title: 'Customer',
              child: Column(
                children: [
                  _InfoRow(
                      icon: Icons.person_outline,
                      label: 'Name',
                      value: liveOrder.customerName),
                  const SizedBox(height: 10),
                  _InfoRow(
                      icon: Icons.phone_outlined,
                      label: 'Phone',
                      value: liveOrder.customerPhone),
                  const SizedBox(height: 10),
                  _InfoRow(
                      icon: Icons.location_on_outlined,
                      label: 'Address',
                      value: liveOrder.deliveryAddress),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Order items ──────────────────────────────────────────────
            _Section(
              title: 'Items',
              child: Column(
                children: liveOrder.items.map((item) {
                  final name = item['name'] as String? ?? 'Item';
                  final qty = item['qty'] as int? ??
                      (item['qty'] as num?)?.toInt() ?? 1;
                  final price =
                      (item['price'] as num?)?.toDouble() ?? 0.0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: kSurface2,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$qty×',
                            style: const TextStyle(
                                color: kMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(name,
                              style: const TextStyle(
                                  color: kInk, fontSize: 14)),
                        ),
                        Text(
                          formatPeso(price * qty),
                          style: const TextStyle(
                              color: kInk,
                              fontSize: 13,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // ── Financial summary ────────────────────────────────────────
            _Section(
              title: 'Summary',
              child: Column(
                children: [
                  _SummaryRow('Subtotal', liveOrder.subtotal),
                  const SizedBox(height: 8),
                  _SummaryRow('Delivery Fee', liveOrder.deliveryFee),
                  if (liveOrder.discount > 0) ...[
                    const SizedBox(height: 8),
                    _SummaryRow('Discount', -liveOrder.discount,
                        valueColor: kGreen),
                  ],
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Divider(color: kBorder),
                  ),
                  Row(
                    children: [
                      const Text('Total',
                          style: TextStyle(
                              color: kInk,
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                      const Spacer(),
                      Text(
                        formatPeso(liveOrder.total),
                        style: const TextStyle(
                            color: kBrand,
                            fontSize: 16,
                            fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Order date ───────────────────────────────────────────────
            if (liveOrder.createdAt != null)
              _Section(
                title: 'Date & Time',
                child: _InfoRow(
                  icon: Icons.access_time_rounded,
                  label: 'Placed',
                  value: _formatDateTime(liveOrder.createdAt!),
                ),
              ),
          ],
        ),
      ),

      // ── Action buttons ─────────────────────────────────────────────────────
      bottomNavigationBar: isTerminal
          ? null
          : Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              decoration: const BoxDecoration(
                color: kSurface,
                border: Border(top: BorderSide(color: kBorder)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (next != null)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kBrand,
                            foregroundColor: kInk,
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed:
                              _updating ? null : () => _updateStatus(next),
                          child: _updating
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      color: kInk, strokeWidth: 2))
                              : Text(_nextLabel(next),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15)),
                        ),
                      ),
                    if (next != null) const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: kRed,
                          side: const BorderSide(color: kRed),
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed:
                            _updating ? null : _confirmCancel,
                        child: const Text('Cancel Order',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  String _formatDateTime(DateTime dt) {
    String pad(int n) => n.toString().padLeft(2, '0');
    final hour = dt.hour > 12 ? dt.hour - 12 : dt.hour == 0 ? 12 : dt.hour;
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '${dt.day}/${dt.month}/${dt.year} '
        '${pad(hour)}:${pad(dt.minute)} $ampm';
  }
}

// ── Reusable sub-widgets ───────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
                color: kMuted, fontSize: 11, fontWeight: FontWeight.w600,
                letterSpacing: 0.5),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

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
        Icon(icon, color: kMuted, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style:
                      const TextStyle(color: kMuted, fontSize: 11)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(color: kInk, fontSize: 14)),
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final double amount;
  final Color? valueColor;

  const _SummaryRow(this.label, this.amount, {this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label,
            style: const TextStyle(color: kMuted, fontSize: 13)),
        const Spacer(),
        Text(
          formatPeso(amount.abs()),
          style: TextStyle(
              color: valueColor ?? kInk,
              fontSize: 13,
              fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: TextStyle(
              color: fg, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
