import 'package:flutter/material.dart';
import '../constants.dart';
import '../models/cart_item.dart';

/// Cart page — line items, promo code, order summary, and checkout.
class CartPage extends StatefulWidget {
  final List<CartItem> items;
  final void Function(String id, int qty) onUpdate;
  final void Function(String page) onNav;
  final String deliveryAddress;
  final VoidCallback onChangeAddress;

  const CartPage({
    super.key,
    required this.items,
    required this.onUpdate,
    required this.onNav,
    required this.deliveryAddress,
    required this.onChangeAddress,
  });

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final TextEditingController _promoController = TextEditingController();
  bool _promoApplied = false;
  bool _promoError = false;
  bool _checkoutDone = false;

  static const double _kPromoRate = 0.5;
  static const double _kDeliveryFee = 99.0;

  double get _subtotal => widget.items.fold(0, (sum, i) => sum + i.price * i.qty);
  double get _deliveryFee => _subtotal > 0 ? _kDeliveryFee : 0;
  double get _discount => _promoApplied ? _subtotal * _kPromoRate : 0;
  double get _total => _subtotal + _deliveryFee - _discount;

  int get _itemCount => widget.items.fold(0, (sum, i) => sum + i.qty);

  @override
  void dispose() {
    _promoController.dispose();
    super.dispose();
  }

  void _applyPromo() {
    setState(() {
      if (_promoController.text.trim().toUpperCase() == 'SWIFT50') {
        _promoApplied = true;
        _promoError = false;
      } else {
        _promoError = true;
        _promoApplied = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checkoutDone) return _buildCheckoutDone();

    if (widget.items.isEmpty) {
      return _buildEmptyCart();
    }

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Your cart',
                          style: kSerif.copyWith(color: kInk, fontSize: 20, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text(
                        '$_itemCount item${_itemCount != 1 ? 's' : ''} · ${widget.items.first.restaurant}',
                        style: const TextStyle(color: kMuted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                // Items
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Column(
                    children: List.generate(widget.items.length, (i) {
                      final item = widget.items[i];
                      return Padding(
                        padding: EdgeInsets.only(bottom: i < widget.items.length - 1 ? 12 : 0),
                        child: _CartRow(item: item, onUpdate: widget.onUpdate),
                      );
                    }),
                  ),
                ),
                // Add more
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: GestureDetector(
                    onTap: () => widget.onNav('home'),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: kBorder, style: BorderStyle.solid),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Text('+ Add more items', style: TextStyle(color: kMuted, fontSize: 14, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                ),
                // Promo
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('PROMO CODE',
                          style: TextStyle(color: kMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _promoController,
                              onChanged: (_) => setState(() => _promoError = false),
                              style: const TextStyle(color: kInk, fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'Enter code (try SWIFT50)',
                                hintStyle: const TextStyle(color: kMuted, fontSize: 14),
                                filled: true,
                                fillColor: kSurface,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: _promoError ? kRed : (_promoApplied ? kGreen : kBorder),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: _promoError ? kRed : (_promoApplied ? kGreen : kBorder),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: kBrand, width: 1.5),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: _promoApplied ? null : _applyPromo,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                              decoration: BoxDecoration(
                                color: _promoApplied ? kGreen : kBrand,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                _promoApplied ? '✓ Applied' : 'Apply',
                                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_promoError)
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Text('Invalid code. Try SWIFT50.', style: TextStyle(color: kRed, fontSize: 12)),
                        )
                      else if (_promoApplied)
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Text('🎉 50% discount applied!', style: TextStyle(color: kGreen, fontSize: 12)),
                        ),
                    ],
                  ),
                ),
                // Summary
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('ORDER SUMMARY',
                          style: TextStyle(color: kMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                        decoration: BoxDecoration(color: kSurface, border: Border.all(color: kSurface2), borderRadius: BorderRadius.circular(18)),
                        child: Column(
                          children: [
                            _summaryRow('Subtotal', formatPeso(_subtotal), kInk),
                            const SizedBox(height: 10),
                            _summaryRow('Delivery fee', formatPeso(_deliveryFee), kInk),
                            if (_promoApplied) ...[
                              const SizedBox(height: 10),
                              _summaryRow('Promo (SWIFT50)', '-${formatPeso(_discount)}', kGreen),
                            ],
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Divider(height: 1, color: kBorder),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Total', style: TextStyle(color: kInk, fontSize: 16, fontWeight: FontWeight.w800)),
                                Text(formatPeso(_total),
                                    style: const TextStyle(color: kBrand, fontSize: 18, fontWeight: FontWeight.w900)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Delivery address
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(color: kSurface, border: Border.all(color: kSurface2), borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on, size: 20, color: kMuted),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Delivering to', style: TextStyle(color: kMuted, fontSize: 11)),
                              const SizedBox(height: 1),
                              Text(widget.deliveryAddress,
                                  style: const TextStyle(
                                      color: kInk,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14)),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: widget.onChangeAddress,
                          child: const Text('Change',
                              style: TextStyle(
                                  color: kBrand,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Checkout bar
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          decoration: const BoxDecoration(color: kCanvas, border: Border(top: BorderSide(color: kSurface2))),
          child: GestureDetector(
            onTap: () => setState(() => _checkoutDone = true),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [kBrand, kBrandDark]),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Place order', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(formatPeso(_total), style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _summaryRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: kMuted, fontSize: 14)),
        Text(value, style: TextStyle(color: valueColor, fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.shopping_cart_outlined, size: 64, color: kMuted),
            const SizedBox(height: 16),
            Text('Your cart is empty',
                style: kSerif.copyWith(color: kInk, fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            const Text('Add some delicious food to get started.',
                style: TextStyle(color: kMuted, fontSize: 14, height: 1.7), textAlign: TextAlign.center),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: () => widget.onNav('home'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
                decoration: BoxDecoration(color: kBrand, borderRadius: BorderRadius.circular(16)),
                child: const Text('Browse food', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckoutDone() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 72)),
            const SizedBox(height: 20),
            Text('Order placed!',
                style: kSerif.copyWith(color: kInk, fontSize: 26, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            const Text('Your food is being prepared.\nTrack it live in the Orders tab.',
                style: TextStyle(color: kMuted, fontSize: 14, height: 1.7), textAlign: TextAlign.center),
            const SizedBox(height: 32),
            _checkoutBtn('Track my order', filled: true, onTap: () {
              setState(() => _checkoutDone = false);
              widget.onNav('orders');
            }),
            const SizedBox(height: 12),
            _checkoutBtn('Back to home', filled: false, onTap: () {
              setState(() => _checkoutDone = false);
              widget.onNav('home');
            }),
          ],
        ),
      ),
    );
  }

  Widget _checkoutBtn(String label, {required bool filled, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: filled ? kBrand : Colors.transparent,
          border: filled ? null : Border.all(color: kBorder),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(label,
              style: TextStyle(
                color: filled ? Colors.white : kInk,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              )),
        ),
      ),
    );
  }
}

/// Single cart line item with quantity stepper.
class _CartRow extends StatelessWidget {
  final CartItem item;
  final void Function(String id, int qty) onUpdate;

  const _CartRow({required this.item, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    final isRemove = item.qty == 1;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kSurface,
        border: Border.all(color: kSurface2),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(color: kSurface2, borderRadius: BorderRadius.circular(12)),
            clipBehavior: Clip.hardEdge,
            child: Image.network(
              item.img,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) => Container(color: kSurface2),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name,
                    style: const TextStyle(color: kInk, fontSize: 14, fontWeight: FontWeight.w800),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(formatPeso(item.price * item.qty),
                    style: const TextStyle(color: kBrand, fontSize: 15, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: kSurface2, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                _stepBtn(
                  icon: isRemove ? Icons.delete_outline : Icons.remove,
                  bg: isRemove ? kRed.withValues(alpha: 0.15) : kBorder,
                  fg: isRemove ? kRed : kInk,
                  onTap: () => onUpdate(item.id, item.qty - 1),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text('${item.qty}',
                      style: const TextStyle(color: kInk, fontSize: 15, fontWeight: FontWeight.w800)),
                ),
                _stepBtn(icon: Icons.add, bg: kBrand, fg: Colors.white, onTap: () => onUpdate(item.id, item.qty + 1)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepBtn({required IconData icon, required Color bg, required Color fg, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 15, color: fg),
      ),
    );
  }
}
