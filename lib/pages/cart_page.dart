import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../constants.dart';
import '../models/cart_item.dart';
import '../models/order.dart';
import '../providers/auth_provider.dart';
import '../providers/user_profile_provider.dart';
import '../services/phone_validator.dart';
import '../services/user_repository.dart';
import '../widgets/app_image.dart';

/// Cart page — line items, promo code, order summary, and checkout.
///
/// Checkout flow:
///   1. Validate cart is not empty.
///   2. Ensure the user is authenticated.
///   3. Check profile.phoneNumber — if missing, show phone-entry bottom sheet.
///   4. Build the [Order] with customerPhone snapshot from the profile.
///   5. Write to Firestore via [UserRepository.placeOrder].
///   6. Clear cart only after a successful write.
///   7. Show the success screen.
///
/// The cart is never cleared before step 5 succeeds.
class CartPage extends StatefulWidget {
  final List<CartItem> items;
  final void Function(String id, int qty) onUpdate;
  final void Function(String page) onNav;
  final String deliveryAddress;
  final VoidCallback onChangeAddress;

  /// Called by [CartPage] ONLY after a successful Firestore order write.
  /// [RootShell] uses this to clear the in-memory cart.
  final VoidCallback onClearCart;

  const CartPage({
    super.key,
    required this.items,
    required this.onUpdate,
    required this.onNav,
    required this.deliveryAddress,
    required this.onChangeAddress,
    required this.onClearCart,
  });

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final TextEditingController _promoController = TextEditingController();
  bool _promoApplied = false;
  bool _promoError = false;
  bool _checkoutDone = false;
  bool _isPlacingOrder = false;
  String? _checkoutError;

  static const double _kPromoRate = 0.5;
  static const double _kDeliveryFee = 99.0;

  double get _subtotal =>
      widget.items.fold(0.0, (acc, i) => acc + i.price * i.qty);
  double get _deliveryFee => _subtotal > 0 ? _kDeliveryFee : 0;
  double get _discount => _promoApplied ? _subtotal * _kPromoRate : 0;
  double get _total => _subtotal + _deliveryFee - _discount;

  int get _itemCount => widget.items.fold(0, (acc, i) => acc + i.qty);

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

  // ── Checkout ──────────────────────────────────────────────────────────────

  Future<void> _handleCheckout() async {
    if (_isPlacingOrder) return;

    setState(() {
      _checkoutError = null;
    });

    // 1. Verify cart is not empty.
    if (widget.items.isEmpty) return;

    // 2. Verify the user is authenticated.
    final auth = context.read<AppAuthProvider>();
    final profileProvider = context.read<UserProfileProvider>();

    if (!auth.isAuthenticated || auth.user == null) {
      setState(() => _checkoutError = 'Please sign in to place an order.');
      return;
    }

    // 3. Check for a contact number — show entry sheet if missing.
    String? phoneNumber = profileProvider.profile?.phoneNumber;
    if (phoneNumber == null || phoneNumber.isEmpty) {
      final saved = await _showPhoneEntrySheet();
      if (!mounted) return;
      if (!saved) {
        // User dismissed without saving — cannot proceed.
        return;
      }
      // Re-read the profile; the stream should have updated it.
      phoneNumber = profileProvider.profile?.phoneNumber;
      if (phoneNumber == null || phoneNumber.isEmpty) {
        setState(() =>
            _checkoutError = 'A contact number is required to place an order.');
        return;
      }
    }

    // 4. Build the order.
    setState(() => _isPlacingOrder = true);

    try {
      final uid = auth.user!.uid;
      final customerName =
          profileProvider.profile?.displayName ?? auth.user!.name;

      // Derive restaurantId and restaurantName from the first cart item.
      // All items in one cart should be from the same restaurant.
      final firstItem = widget.items.first;
      final restaurantId = firstItem.restaurantId;
      final restaurantName = firstItem.restaurant;

      // Generate a stable document ID before writing.
      final orderId =
          FirebaseFirestore.instance.collection('orders').doc().id;

      final order = FoodOrder(
        orderId: orderId,
        customerId: uid,
        customerName: customerName,
        // Snapshot the phone number at this exact moment.
        customerPhone: phoneNumber,
        restaurantId: restaurantId.isNotEmpty ? restaurantId : 'unknown',
        restaurantName: restaurantName,
        items: widget.items
            .map((i) => {
                  'id': i.id,
                  'name': i.name,
                  'price': i.price,
                  'qty': i.qty,
                  'img': i.img,
                })
            .toList(),
        deliveryAddress: widget.deliveryAddress,
        subtotal: _subtotal,
        deliveryFee: _deliveryFee,
        discount: _discount,
        total: _total,
        promoCode: _promoApplied ? 'SWIFT50' : null,
        status: FoodOrderStatus.pending,
      );

      // 5. Write to Firestore.
      await UserRepository.instance.placeOrder(order);

      // 6. Clear cart only after successful write.
      widget.onClearCart();

      if (!mounted) return;

      // 7. Show success screen.
      setState(() {
        _isPlacingOrder = false;
        _checkoutDone = true;
      });
    } catch (e, stack) {
      debugPrint('CartPage._handleCheckout error: $e\n$stack');
      if (!mounted) return;
      setState(() {
        _isPlacingOrder = false;
        // In debug mode surface the real error so it can be diagnosed.
        // In release mode fall back to a friendly message.
        assert(() {
          _checkoutError = 'Order failed: $e';
          return true;
        }());
        _checkoutError ??=
            'Could not place your order. Please check your connection and try again.';
      });
    }
  }

  // ── Phone entry bottom sheet ──────────────────────────────────────────────

  /// Shows a bottom sheet asking for a contact number.
  /// Returns `true` if the number was successfully saved.
  Future<bool> _showPhoneEntrySheet() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: kCanvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const _PhoneEntrySheet(),
    );
    return result == true;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_checkoutDone) return _buildCheckoutDone();
    if (widget.items.isEmpty) return _buildEmptyCart();

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
                          style: kSerif.copyWith(
                              color: kInk,
                              fontSize: 20,
                              fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text(
                        '$_itemCount item${_itemCount != 1 ? 's' : ''} · ${widget.items.first.restaurant}',
                        style:
                            const TextStyle(color: kMuted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                // Items
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Column(
                    children:
                        List.generate(widget.items.length, (i) {
                      final item = widget.items[i];
                      return Padding(
                        padding: EdgeInsets.only(
                            bottom:
                                i < widget.items.length - 1 ? 12 : 0),
                        child: _CartRow(
                            item: item, onUpdate: widget.onUpdate),
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
                      padding:
                          const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: kBorder,
                            style: BorderStyle.solid),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Text('+ Add more items',
                            style: TextStyle(
                                color: kMuted,
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
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
                          style: TextStyle(
                              color: kMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _promoController,
                              enabled: !_isPlacingOrder,
                              onChanged: (_) => setState(
                                  () => _promoError = false),
                              style: const TextStyle(
                                  color: kInk, fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'Enter code (try SWIFT50)',
                                hintStyle: const TextStyle(
                                    color: kMuted, fontSize: 14),
                                filled: true,
                                fillColor: kSurface,
                                border: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: _promoError
                                        ? kRed
                                        : (_promoApplied
                                            ? kGreen
                                            : kBorder),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: _promoError
                                        ? kRed
                                        : (_promoApplied
                                            ? kGreen
                                            : kBorder),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                      color: kBrand, width: 1.5),
                                ),
                                contentPadding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 12),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: (_promoApplied || _isPlacingOrder)
                                ? null
                                : _applyPromo,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 13),
                              decoration: BoxDecoration(
                                color: _promoApplied
                                    ? kGreen
                                    : kBrand,
                                borderRadius:
                                    BorderRadius.circular(14),
                              ),
                              child: Text(
                                _promoApplied
                                    ? '✓ Applied'
                                    : 'Apply',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_promoError)
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Text('Invalid code. Try SWIFT50.',
                              style: TextStyle(
                                  color: kRed, fontSize: 12)),
                        )
                      else if (_promoApplied)
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Text('🎉 50% discount applied!',
                              style: TextStyle(
                                  color: kGreen, fontSize: 12)),
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
                          style: TextStyle(
                              color: kMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1)),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 16),
                        decoration: BoxDecoration(
                            color: kSurface,
                            border: Border.all(color: kSurface2),
                            borderRadius: BorderRadius.circular(18)),
                        child: Column(
                          children: [
                            _summaryRow('Subtotal',
                                formatPeso(_subtotal), kInk),
                            const SizedBox(height: 10),
                            _summaryRow('Delivery fee',
                                formatPeso(_deliveryFee), kInk),
                            if (_promoApplied) ...[
                              const SizedBox(height: 10),
                              _summaryRow('Promo (SWIFT50)',
                                  '-${formatPeso(_discount)}', kGreen),
                            ],
                            const Padding(
                              padding:
                                  EdgeInsets.symmetric(vertical: 12),
                              child: Divider(
                                  height: 1, color: kBorder),
                            ),
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Total',
                                    style: TextStyle(
                                        color: kInk,
                                        fontSize: 16,
                                        fontWeight:
                                            FontWeight.w800)),
                                Text(formatPeso(_total),
                                    style: const TextStyle(
                                        color: kBrand,
                                        fontSize: 18,
                                        fontWeight:
                                            FontWeight.w900)),
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
                  padding:
                      const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                        color: kSurface,
                        border: Border.all(color: kSurface2),
                        borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on,
                            size: 20, color: kMuted),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              const Text('Delivering to',
                                  style: TextStyle(
                                      color: kMuted, fontSize: 11)),
                              const SizedBox(height: 1),
                              Text(
                                widget.deliveryAddress,
                                style: const TextStyle(
                                    color: kInk,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14),
                              ),
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
        // Error banner
        if (_checkoutError != null)
          Padding(
            padding:
                const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: kRed.withValues(alpha: 0.08),
                border:
                    Border.all(color: kRed.withValues(alpha: 0.25)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: kRed, size: 16),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _checkoutError!,
                      style: const TextStyle(
                          color: kRed, fontSize: 13, height: 1.4),
                    ),
                  ),
                  GestureDetector(
                    onTap: () =>
                        setState(() => _checkoutError = null),
                    child: const Icon(Icons.close,
                        color: kRed, size: 14),
                  ),
                ],
              ),
            ),
          ),
        // Checkout bar
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          decoration: const BoxDecoration(
              color: kCanvas,
              border:
                  Border(top: BorderSide(color: kSurface2))),
          child: GestureDetector(
            onTap: _isPlacingOrder ? null : _handleCheckout,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: _isPlacingOrder
                    ? null
                    : const LinearGradient(
                        colors: [kBrand, kBrandDark]),
                color: _isPlacingOrder ? kSurface2 : null,
                borderRadius: BorderRadius.circular(18),
              ),
              child: _isPlacingOrder
                  ? const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(
                                    kMuted)),
                      ),
                    )
                  : Row(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        const Text('Place order',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white
                                .withValues(alpha: 0.2),
                            borderRadius:
                                BorderRadius.circular(8),
                          ),
                          child: Text(
                            formatPeso(_total),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _summaryRow(
      String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style:
                const TextStyle(color: kMuted, fontSize: 14)),
        Text(value,
            style: TextStyle(
                color: valueColor,
                fontSize: 14,
                fontWeight: FontWeight.w600)),
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
            const Icon(Icons.shopping_cart_outlined,
                size: 64, color: kMuted),
            const SizedBox(height: 16),
            Text('Your cart is empty',
                style: kSerif.copyWith(
                    color: kInk,
                    fontSize: 22,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            const Text(
              'Add some delicious food to get started.',
              style: TextStyle(
                  color: kMuted, fontSize: 14, height: 1.7),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: () => widget.onNav('home'),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 36, vertical: 14),
                decoration: BoxDecoration(
                    color: kBrand,
                    borderRadius: BorderRadius.circular(16)),
                child: const Text('Browse food',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
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
                style: kSerif.copyWith(
                    color: kInk,
                    fontSize: 26,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            const Text(
              'Your food is being prepared.\nTrack it live in the Orders tab.',
              style: TextStyle(
                  color: kMuted, fontSize: 14, height: 1.7),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            _checkoutBtn('Track my order', filled: true,
                onTap: () {
              setState(() => _checkoutDone = false);
              widget.onNav('orders');
            }),
            const SizedBox(height: 12),
            _checkoutBtn('Back to home', filled: false,
                onTap: () {
              setState(() => _checkoutDone = false);
              widget.onNav('home');
            }),
          ],
        ),
      ),
    );
  }

  Widget _checkoutBtn(String label,
      {required bool filled, required VoidCallback onTap}) {
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
          child: Text(
            label,
            style: TextStyle(
              color: filled ? Colors.white : kInk,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Phone entry bottom sheet ──────────────────────────────────────────────────

/// Shown as a bottom sheet at checkout when the user has no contact number.
///
/// Returns `true` via `Navigator.pop` after a successful save, or
/// `false`/`null` if the user dismisses without saving.
class _PhoneEntrySheet extends StatefulWidget {
  const _PhoneEntrySheet();

  @override
  State<_PhoneEntrySheet> createState() => _PhoneEntrySheetState();
}

class _PhoneEntrySheetState extends State<_PhoneEntrySheet> {
  final _phoneCtrl = TextEditingController();
  final _phoneFocus = FocusNode();

  String? _phoneError;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();

    final raw = _phoneCtrl.text.trim();
    final validationError = PhoneValidator.errorMessage(raw);
    if (validationError != null) {
      setState(() => _phoneError = validationError);
      return;
    }

    final e164 = PhoneValidator.normalize(raw)!;

    setState(() {
      _isLoading = true;
      _phoneError = null;
      _errorMessage = null;
    });

    try {
      await UserRepository.instance.updatePhoneNumber(e164);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Could not save your number. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Shift the sheet up when the keyboard appears.
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding:
              const EdgeInsets.fromLTRB(24, 24, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: kBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: kBrand.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: kBrand.withValues(alpha: 0.25)),
                    ),
                    child: const Icon(Icons.phone_outlined,
                        color: kBrand, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add contact number',
                          style: kSerif.copyWith(
                              color: kInk,
                              fontSize: 18,
                              fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Required so the restaurant can reach you',
                          style: TextStyle(
                              color: kMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Error banner
              if (_errorMessage != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: kRed.withValues(alpha: 0.08),
                    border: Border.all(
                        color: kRed.withValues(alpha: 0.25)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(_errorMessage!,
                      style: const TextStyle(
                          color: kRed,
                          fontSize: 12,
                          height: 1.4)),
                ),
                const SizedBox(height: 12),
              ],

              // Phone field
              const Text(
                'Contact number',
                style: TextStyle(
                    color: kInk,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              _buildPhoneField(),
              const SizedBox(height: 6),
              const Text(
                'Format: 0917 123 4567 or +63 917 123 4567',
                style: TextStyle(color: kMuted, fontSize: 11),
              ),
              const SizedBox(height: 20),

              // Save button
              GestureDetector(
                onTap: _isLoading ? null : _save,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: double.infinity,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: _isLoading
                        ? null
                        : const LinearGradient(
                            colors: [kBrand, kBrandDark],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight),
                    color: _isLoading ? kSurface2 : null,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: _isLoading
                        ? null
                        : [
                            BoxShadow(
                                color:
                                    kBrand.withValues(alpha: 0.30),
                                blurRadius: 16,
                                offset: const Offset(0, 6))
                          ],
                  ),
                  alignment: Alignment.center,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(
                                      kMuted)))
                      : const Text(
                          'Save and continue',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneField() {
    final hasError = _phoneError != null;
    final borderColor = hasError ? kRed : kBorder;
    final focusBorderColor = hasError ? kRed : kBrand;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: kSurface2,
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  border:
                      Border(right: BorderSide(color: borderColor)),
                ),
                child: const Text(
                  '🇵🇭 +63',
                  style: TextStyle(
                      color: kInk,
                      fontSize: 15,
                      fontWeight: FontWeight.w600),
                ),
              ),
              Expanded(
                child: Focus(
                  onFocusChange: (hasFocus) {
                    if (hasFocus && _phoneError != null) {
                      setState(() => _phoneError = null);
                    }
                  },
                  child: TextField(
                    controller: _phoneCtrl,
                    focusNode: _phoneFocus,
                    enabled: !_isLoading,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                    autofocus: true,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'[\d\s\-]')),
                    ],
                    onChanged: (_) {
                      if (_phoneError != null) {
                        setState(() => _phoneError = null);
                      }
                      if (_errorMessage != null) {
                        setState(() => _errorMessage = null);
                      }
                    },
                    onSubmitted: (_) => _save(),
                    style: const TextStyle(
                        color: kInk, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: '917 123 4567',
                      hintStyle: const TextStyle(
                          color: kMuted, fontSize: 15),
                      border: InputBorder.none,
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                            color: focusBorderColor, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      isDense: true,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 6),
          Text(_phoneError!,
              style:
                  const TextStyle(color: kRed, fontSize: 12)),
        ],
      ],
    );
  }
}

// ── Cart row ──────────────────────────────────────────────────────────────────

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
            decoration: BoxDecoration(
                color: kSurface2,
                borderRadius: BorderRadius.circular(12)),
            clipBehavior: Clip.hardEdge,
            child: AppImage.thumb(
              url: item.img,
              width: 60,
              height: 60,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                      color: kInk,
                      fontSize: 14,
                      fontWeight: FontWeight.w800),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  formatPeso(item.price * item.qty),
                  style: const TextStyle(
                      color: kBrand,
                      fontSize: 15,
                      fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
                color: kSurface2,
                borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                _stepBtn(
                  icon: isRemove
                      ? Icons.delete_outline
                      : Icons.remove,
                  bg: isRemove
                      ? kRed.withValues(alpha: 0.15)
                      : kBorder,
                  fg: isRemove ? kRed : kInk,
                  onTap: () => onUpdate(item.id, item.qty - 1),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10),
                  child: Text(
                    '${item.qty}',
                    style: const TextStyle(
                        color: kInk,
                        fontSize: 15,
                        fontWeight: FontWeight.w800),
                  ),
                ),
                _stepBtn(
                  icon: Icons.add,
                  bg: kBrand,
                  fg: Colors.white,
                  onTap: () => onUpdate(item.id, item.qty + 1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepBtn({
    required IconData icon,
    required Color bg,
    required Color fg,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
            color: bg, borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 15, color: fg),
      ),
    );
  }
}
