import 'package:flutter/material.dart';
import '../constants.dart';
import '../models/address.dart';
import '_sub_page_shell.dart';

final List<Address> _kDefault = [
  Address(id: 1, label: 'Home', line1: '123 Main Street', line2: 'Apt 4B, New York, NY 10001', icon: '🏠', isDefault: true),
  Address(id: 2, label: 'Work', line1: '350 Fifth Avenue', line2: 'Floor 12, New York, NY 10118', icon: '💼'),
  Address(id: 3, label: 'Gym', line1: '30 Rockefeller Plaza', line2: 'New York, NY 10112', icon: '💪'),
];

class SavedAddressesPage extends StatefulWidget {
  final VoidCallback onBack;

  const SavedAddressesPage({super.key, required this.onBack});

  @override
  State<SavedAddressesPage> createState() => _SavedAddressesPageState();
}

class _SavedAddressesPageState extends State<SavedAddressesPage> {
  List<Address> _addresses = List.from(_kDefault);
  bool _showForm = false;

  final _labelCtrl = TextEditingController();
  final _line1Ctrl = TextEditingController();
  final _line2Ctrl = TextEditingController();

  @override
  void dispose() {
    _labelCtrl.dispose();
    _line1Ctrl.dispose();
    _line2Ctrl.dispose();
    super.dispose();
  }

  void _setDefault(int id) =>
      setState(() => _addresses = _addresses.map((a) => a.copyWith(isDefault: a.id == id)).toList());

  void _remove(int id) =>
      setState(() => _addresses = _addresses.where((a) => a.id != id).toList());

  void _addNew() {
    if (_line1Ctrl.text.trim().isEmpty) return;
    setState(() {
      _addresses = [
        ..._addresses,
        Address(
          id: DateTime.now().millisecondsSinceEpoch,
          label: _labelCtrl.text.trim().isEmpty ? 'Custom' : _labelCtrl.text.trim(),
          line1: _line1Ctrl.text.trim(),
          line2: _line2Ctrl.text.trim(),
          icon: '📍',
        ),
      ];
      _showForm = false;
      _labelCtrl.clear();
      _line1Ctrl.clear();
      _line2Ctrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SubPageShell(
      title: 'Saved addresses',
      subtitle: '${_addresses.length} location${_addresses.length != 1 ? 's' : ''} saved',
      onBack: widget.onBack,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          ..._addresses.map((addr) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _AddressTile(
                  addr: addr,
                  onSetDefault: () => _setDefault(addr.id),
                  onRemove: () => _remove(addr.id),
                ),
              )),
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
                _showForm ? 'Cancel' : '+ Add new address',
                style: const TextStyle(color: kMuted, fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          if (_showForm) ...[
            const SizedBox(height: 12),
            _buildForm(),
          ],
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurface,
        border: Border.all(color: kBorder),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          _field(_labelCtrl, 'Label (Home, Office…)'),
          const SizedBox(height: 8),
          _field(_line1Ctrl, 'Street address *'),
          const SizedBox(height: 8),
          _field(_line2Ctrl, 'City, ZIP'),
          const SizedBox(height: 12),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _line1Ctrl,
            builder: (context, val, _) {
              final ok = val.text.trim().isNotEmpty;
              return GestureDetector(
                onTap: ok ? _addNew : null,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: ok ? kBrand : kBorder,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: const Text('Save address',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String hint) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: kInk, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: kMuted),
        filled: true,
        fillColor: kSurface2,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kBorder)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kBorder)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kBrand, width: 1.5)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        isDense: true,
      ),
    );
  }
}

// ── Address tile ──────────────────────────────────────────────────────────────

class _AddressTile extends StatelessWidget {
  final Address addr;
  final VoidCallback onSetDefault;
  final VoidCallback onRemove;

  const _AddressTile(
      {required this.addr, required this.onSetDefault, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kSurface,
        border: Border.all(color: kSurface2),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                    color: kSurface2, borderRadius: BorderRadius.circular(12)),
                child: Center(
                    child: Text(addr.icon,
                        style: const TextStyle(fontSize: 20))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(addr.label,
                            style: const TextStyle(
                                color: kInk,
                                fontWeight: FontWeight.w800,
                                fontSize: 14)),
                        if (addr.isDefault) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: kGreen.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: const Text('Default',
                                style: TextStyle(
                                    color: kGreen,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(addr.line1,
                        style: const TextStyle(
                            color: kInk,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    Text(addr.line2,
                        style: const TextStyle(color: kMuted, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (!addr.isDefault)
                Expanded(
                  child: GestureDetector(
                    onTap: onSetDefault,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
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
              if (!addr.isDefault) const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      border:
                          Border.all(color: kRed.withValues(alpha: 0.25)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: const Text('Remove',
                        style: TextStyle(
                            color: kRed,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
