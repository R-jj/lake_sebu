import 'package:flutter/material.dart';
import '../constants.dart';
import '_sub_page_shell.dart';

class _CardData {
  final int id;
  final String brand;
  final String last4;
  final String expiry;
  final bool isDefault;

  const _CardData({
    required this.id,
    required this.brand,
    required this.last4,
    required this.expiry,
    this.isDefault = false,
  });

  _CardData copyWith({bool? isDefault}) => _CardData(
        id: id,
        brand: brand,
        last4: last4,
        expiry: expiry,
        isDefault: isDefault ?? this.isDefault,
      );
}

class PaymentMethodsPage extends StatefulWidget {
  final VoidCallback onBack;

  const PaymentMethodsPage({super.key, required this.onBack});

  @override
  State<PaymentMethodsPage> createState() => _PaymentMethodsPageState();
}

class _PaymentMethodsPageState extends State<PaymentMethodsPage> {
  List<_CardData> _cards = const [
    _CardData(id: 1, brand: 'Visa', last4: '4821', expiry: '08/27', isDefault: true),
    _CardData(id: 2, brand: 'Mastercard', last4: '3390', expiry: '11/26'),
  ];

  bool _showForm = false;
  final _numCtrl = TextEditingController();
  final _expCtrl = TextEditingController();
  final _cvvCtrl = TextEditingController();

  @override
  void dispose() {
    _numCtrl.dispose();
    _expCtrl.dispose();
    _cvvCtrl.dispose();
    super.dispose();
  }

  void _setDefault(int id) =>
      setState(() => _cards = _cards.map((c) => c.copyWith(isDefault: c.id == id)).toList());

  void _remove(int id) => setState(() => _cards = _cards.where((c) => c.id != id).toList());

  @override
  Widget build(BuildContext context) {
    return SubPageShell(
      title: 'Payment methods',
      subtitle: 'Manage your cards & wallets',
      onBack: widget.onBack,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          // Wallets section
          const Text('DIGITAL WALLETS',
              style: TextStyle(
                  color: kMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
          const SizedBox(height: 10),
          _WalletTile(icon: Icons.apple, label: 'Apple Pay', sub: 'Ready to use'),
          const SizedBox(height: 8),
          _WalletTile(icon: Icons.android, label: 'Google Pay', sub: 'Ready to use'),

          // Cards section
          const SizedBox(height: 20),
          const Text('CARDS',
              style: TextStyle(
                  color: kMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
          const SizedBox(height: 10),
          ..._cards.map((card) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _CardTile(
                  card: card,
                  onSetDefault: () => _setDefault(card.id),
                  onRemove: () => _remove(card.id),
                ),
              )),

          // Add new card
          GestureDetector(
            onTap: () => setState(() => _showForm = !_showForm),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: kBorder, style: BorderStyle.solid),
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: Text(
                _showForm ? 'Cancel' : '+ Add new card',
                style: const TextStyle(color: kMuted, fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ),

          if (_showForm) ...[
            const SizedBox(height: 12),
            _buildCardForm(),
          ],
        ],
      ),
    );
  }

  Widget _buildCardForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurface,
        border: Border.all(color: kBorder),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          _field(_numCtrl, 'Card number', TextInputType.number),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _field(_expCtrl, 'MM/YY', TextInputType.datetime)),
              const SizedBox(width: 8),
              Expanded(child: _field(_cvvCtrl, 'CVV', TextInputType.number)),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => setState(() => _showForm = false),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: kBrand,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: const Text('Save card',
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String hint, TextInputType kb) {
    return TextField(
      controller: ctrl,
      keyboardType: kb,
      style: const TextStyle(color: kInk, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: kMuted),
        filled: true,
        fillColor: kSurface2,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kBorder)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kBorder)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kBrand, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        isDense: true,
      ),
    );
  }
}

// ── Wallet tile ───────────────────────────────────────────────────────────────

class _WalletTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;

  const _WalletTile({required this.icon, required this.label, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: kSurface,
        border: Border.all(color: kSurface2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: kSurface2, borderRadius: BorderRadius.circular(12)),
            child: Center(child: Icon(icon, size: 20, color: kInk)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: kInk, fontWeight: FontWeight.w700, fontSize: 14)),
                Text(sub, style: const TextStyle(color: kGreen, fontSize: 12)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: kBorder, size: 18),
        ],
      ),
    );
  }
}

// ── Card tile ─────────────────────────────────────────────────────────────────

class _CardTile extends StatelessWidget {
  final _CardData card;
  final VoidCallback onSetDefault;
  final VoidCallback onRemove;

  const _CardTile(
      {required this.card, required this.onSetDefault, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kSurface,
        border: Border.all(color: kSurface2),
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          // Card visual
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [kSurface2, kBorder],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(card.brand,
                        style: const TextStyle(color: kMuted, fontSize: 11)),
                    const SizedBox(height: 4),
                    Text('•••• •••• •••• ${card.last4}',
                        style: const TextStyle(
                            color: kInk,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            letterSpacing: 2)),
                    const SizedBox(height: 4),
                    Text('Expires ${card.expiry}',
                        style: const TextStyle(color: kMuted, fontSize: 12)),
                  ],
                ),
                const Icon(Icons.credit_card, size: 32, color: kMuted),
              ],
            ),
          ),
          // Action row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                if (card.isDefault)
                  const Expanded(
                    child: Text('✓ Default card',
                        style: TextStyle(
                            color: kGreen, fontSize: 12, fontWeight: FontWeight.w700)),
                  )
                else
                  Expanded(
                    child: GestureDetector(
                      onTap: onSetDefault,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        decoration: BoxDecoration(
                          border: Border.all(color: kBorder),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: const Text('Set as default',
                            style: TextStyle(
                                color: kMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: onRemove,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      decoration: BoxDecoration(
                        border: Border.all(color: kRed.withValues(alpha: 0.25)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: const Text('Remove',
                          style: TextStyle(
                              color: kRed, fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
