import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../constants.dart';
import '../models/address.dart';
import '../providers/auth_provider.dart';
import '../providers/user_profile_provider.dart';
import '_sub_page_shell.dart';
import 'map_picker_page.dart';

class SavedAddressesPage extends StatefulWidget {
  final VoidCallback onBack;
  const SavedAddressesPage({super.key, required this.onBack});

  @override
  State<SavedAddressesPage> createState() => _SavedAddressesPageState();
}

class _SavedAddressesPageState extends State<SavedAddressesPage> {
  bool _showForm = false;
  Address? _editingAddress; // non-null when editing existing
  String? _formError;

  // ── Form controllers ──────────────────────────────────────────────────────
  final _labelCtrl = TextEditingController();
  final _line1Ctrl = TextEditingController();
  final _line2Ctrl = TextEditingController();
  final _barangayCtrl = TextEditingController();
  final _municipalityCtrl = TextEditingController();
  final _provinceCtrl = TextEditingController();
  final _postalCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _selectedIcon = '📍';
  double? _formLat;
  double? _formLng;

  @override
  void dispose() {
    _labelCtrl.dispose();
    _line1Ctrl.dispose();
    _line2Ctrl.dispose();
    _barangayCtrl.dispose();
    _municipalityCtrl.dispose();
    _provinceCtrl.dispose();
    _postalCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  // ── Form helpers ──────────────────────────────────────────────────────────

  void _openAddForm() {
    _editingAddress = null;
    _labelCtrl.clear();
    _line1Ctrl.clear();
    _line2Ctrl.clear();
    _barangayCtrl.clear();
    _municipalityCtrl.clear();
    _provinceCtrl.clear();
    _postalCtrl.clear();
    _notesCtrl.clear();
    _selectedIcon = '📍';
    _formLat = null;
    _formLng = null;
    setState(() {
      _showForm = true;
      _formError = null;
    });
  }

  void _openEditForm(Address addr) {
    _editingAddress = addr;
    _labelCtrl.text = addr.label;
    _line1Ctrl.text = addr.line1;
    _line2Ctrl.text = addr.line2;
    _barangayCtrl.text = addr.barangay;
    _municipalityCtrl.text = addr.municipality;
    _provinceCtrl.text = addr.province;
    _postalCtrl.text = addr.postalCode;
    _notesCtrl.text = addr.notes ?? '';
    _selectedIcon = addr.icon;
    _formLat = addr.lat;
    _formLng = addr.lng;
    setState(() {
      _showForm = true;
      _formError = null;
    });
  }

  void _closeForm() {
    setState(() {
      _showForm = false;
      _editingAddress = null;
      _formError = null;
    });
  }

  Future<void> _saveForm() async {
    if (_line1Ctrl.text.trim().isEmpty) {
      setState(() => _formError = 'Street address is required.');
      return;
    }

    final uid = context.read<AppAuthProvider>().user!.uid;
    final provider = context.read<UserProfileProvider>();

    setState(() => _formError = null);

    String? err;
    if (_editingAddress == null) {
      // Add new
      final addr = Address(
        id: '', // Firestore will assign
        userId: uid,
        label: _labelCtrl.text.trim().isEmpty
            ? 'Custom'
            : _labelCtrl.text.trim(),
        icon: _selectedIcon,
        line1: _line1Ctrl.text.trim(),
        line2: _line2Ctrl.text.trim(),
        barangay: _barangayCtrl.text.trim(),
        municipality: _municipalityCtrl.text.trim(),
        province: _provinceCtrl.text.trim(),
        postalCode: _postalCtrl.text.trim(),
        country: 'Philippines',
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        isDefault: provider.addresses.isEmpty, // first address = default
        lat: _formLat,
        lng: _formLng,
      );
      err = await provider.addAddress(addr);
    } else {
      // Update existing
      final updated = _editingAddress!.copyWith(
        label: _labelCtrl.text.trim().isEmpty
            ? 'Custom'
            : _labelCtrl.text.trim(),
        icon: _selectedIcon,
        line1: _line1Ctrl.text.trim(),
        line2: _line2Ctrl.text.trim(),
        barangay: _barangayCtrl.text.trim(),
        municipality: _municipalityCtrl.text.trim(),
        province: _provinceCtrl.text.trim(),
        postalCode: _postalCtrl.text.trim(),
        country: 'Philippines',
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        lat: _formLat,
        lng: _formLng,
      );
      err = await provider.updateAddress(updated);
    }

    if (err != null) {
      setState(() => _formError = err);
    } else {
      _closeForm();
    }
  }

  Future<void> _delete(Address addr) async {
    final confirmed = await _confirm(
      context,
      title: 'Remove address?',
      body: 'This address will be permanently removed.',
    );
    if (confirmed != true || !mounted) return;
    final err = await context.read<UserProfileProvider>().deleteAddress(
      addr.id,
    );
    if (err != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err),
          backgroundColor: kRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _setDefault(Address addr) async {
    final err = await context.read<UserProfileProvider>().setDefaultAddress(
      addr.id,
    );
    if (err != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err),
          backgroundColor: kRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openMapPicker() async {
    final result = await Navigator.of(context).push<MapPickerResult>(
      MaterialPageRoute(
        builder: (_) => const MapPickerPage(),
        fullscreenDialog: true,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _formLat = result.lat;
      _formLng = result.lng;
      // Autofill structured fields — only into empty ones, so anything the
      // user already typed is never clobbered.
      if (_line1Ctrl.text.isEmpty) {
        _line1Ctrl.text = result.street.isNotEmpty
            ? result.street
            : result.address;
      }
      if (_barangayCtrl.text.isEmpty && result.barangay.isNotEmpty) {
        _barangayCtrl.text = result.barangay;
      }
      if (_municipalityCtrl.text.isEmpty && result.municipality.isNotEmpty) {
        _municipalityCtrl.text = result.municipality;
      }
      if (_provinceCtrl.text.isEmpty && result.province.isNotEmpty) {
        _provinceCtrl.text = result.province;
      }
      if (_postalCtrl.text.isEmpty && result.postalCode.isNotEmpty) {
        _postalCtrl.text = result.postalCode;
      }
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<UserProfileProvider>();
    final addresses = provider.addresses;

    return SubPageShell(
      title: 'Saved addresses',
      subtitle: _showForm
          ? (_editingAddress == null ? 'Add new address' : 'Edit address')
          : '${addresses.length} location${addresses.length != 1 ? 's' : ''} saved',
      onBack: _showForm ? _closeForm : widget.onBack,
      child: provider.addressesLoading
          ? const Center(child: CircularProgressIndicator(color: kBrand))
          : _showForm
          ? _buildForm()
          : _buildList(addresses),
    );
  }

  Widget _buildList(List<Address> addresses) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        if (addresses.isEmpty) _buildEmpty(),
        ...addresses.map(
          (addr) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _AddressTile(
              addr: addr,
              onEdit: () => _openEditForm(addr),
              onSetDefault: () => _setDefault(addr),
              onRemove: () => _delete(addr),
            ),
          ),
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: _openAddForm,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: kBorder),
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: const Text(
              '+ Add new address',
              style: TextStyle(
                color: kMuted,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: kSurface,
          border: Border.all(color: kSurface2),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Column(
          children: [
            Text('📍', style: TextStyle(fontSize: 36)),
            SizedBox(height: 10),
            Text(
              'No saved addresses',
              style: TextStyle(
                color: kInk,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Add an address to speed up checkout',
              style: TextStyle(color: kMuted, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ── Address form ──────────────────────────────────────────────────────────

  Widget _buildForm() {
    final hasPinned = _formLat != null && _formLng != null;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_formError != null) ...[
            _errorBanner(_formError!),
            const SizedBox(height: 12),
          ],

          // Icon picker
          _sectionLabel('ADDRESS ICON'),
          const SizedBox(height: 8),
          _IconPicker(
            selected: _selectedIcon,
            onSelect: (icon) => setState(() => _selectedIcon = icon),
          ),
          const SizedBox(height: 16),

          // Map pin
          GestureDetector(
            onTap: _openMapPicker,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: hasPinned ? kBrand.withValues(alpha: 0.08) : kSurface2,
                border: Border.all(
                  color: hasPinned ? kBrand.withValues(alpha: 0.4) : kBorder,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    hasPinned
                        ? Icons.location_on
                        : Icons.add_location_alt_outlined,
                    size: 18,
                    color: hasPinned ? kBrand : kMuted,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      hasPinned
                          ? '📍 ${_formLat!.toStringAsFixed(5)}, ${_formLng!.toStringAsFixed(5)}'
                          : 'Pin location on map (optional)',
                      style: TextStyle(
                        color: hasPinned ? kBrand : kMuted,
                        fontSize: 13,
                        fontWeight: hasPinned
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: hasPinned ? kBrand : kMuted,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          _sectionLabel('ADDRESS DETAILS'),
          const SizedBox(height: 8),
          _field(_labelCtrl, 'Label (e.g. Home, Office)'),
          const SizedBox(height: 8),
          _field(_line1Ctrl, 'Street / building / unit *', required: true),
          const SizedBox(height: 8),
          _field(_line2Ctrl, 'Floor / block / lot (optional)'),
          const SizedBox(height: 8),
          _field(_barangayCtrl, 'Barangay'),
          const SizedBox(height: 8),
          _field(_municipalityCtrl, 'City / municipality'),
          const SizedBox(height: 8),
          _field(_provinceCtrl, 'Province'),
          const SizedBox(height: 8),
          _field(
            _postalCtrl,
            'Postal code',
            inputType: TextInputType.number,
            formatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: 8),
          _field(
            _notesCtrl,
            'Delivery notes / landmark (optional)',
            maxLines: 2,
          ),
          const SizedBox(height: 20),

          // Save button
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _line1Ctrl,
            builder: (_, val, __) {
              final enabled = val.text.trim().isNotEmpty;
              return GestureDetector(
                onTap: enabled ? _saveForm : null,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: enabled
                        ? const LinearGradient(
                            colors: [kBrand, kBrandDark],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: enabled ? null : kBorder,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: enabled
                        ? [
                            BoxShadow(
                              color: kBrand.withValues(alpha: 0.28),
                              blurRadius: 14,
                              offset: const Offset(0, 5),
                            ),
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _editingAddress == null ? 'Save address' : 'Update address',
                    style: TextStyle(
                      color: enabled
                          ? Colors.white
                          : kMuted.withValues(alpha: 0.5),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) => Text(
    label,
    style: const TextStyle(
      color: kMuted,
      fontSize: 10,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.2,
    ),
  );

  Widget _field(
    TextEditingController ctrl,
    String hint, {
    bool required = false,
    TextInputType inputType = TextInputType.text,
    List<TextInputFormatter>? formatters,
    int maxLines = 1,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: inputType,
      inputFormatters: formatters,
      maxLines: maxLines,
      style: const TextStyle(color: kInk, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: kMuted, fontSize: 13),
        filled: true,
        fillColor: kSurface2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kBrand, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 11,
        ),
        isDense: true,
      ),
    );
  }

  Widget _errorBanner(String msg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: kRed.withValues(alpha: 0.08),
        border: Border.all(color: kRed.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: kRed, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              msg,
              style: const TextStyle(color: kRed, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirm(
    BuildContext context, {
    required String title,
    required String body,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          title,
          style: kSerif.copyWith(
            color: kInk,
            fontWeight: FontWeight.w900,
            fontSize: 17,
          ),
        ),
        content: Text(
          body,
          style: const TextStyle(color: kMuted, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: kMuted, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Remove',
              style: TextStyle(color: kRed, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Icon picker ───────────────────────────────────────────────────────────────

class _IconPicker extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;

  static const _icons = ['🏠', '💼', '🏫', '🏪', '🏨', '💪', '📍'];

  const _IconPicker({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _icons.map((icon) {
        final isSelected = icon == selected;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () => onSelect(icon),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected ? kBrand.withValues(alpha: 0.15) : kSurface2,
                border: Border.all(
                  color: isSelected ? kBrand : kBorder,
                  width: isSelected ? 1.5 : 1,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(icon, style: const TextStyle(fontSize: 18)),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Address tile ──────────────────────────────────────────────────────────────

class _AddressTile extends StatelessWidget {
  final Address addr;
  final VoidCallback onEdit;
  final VoidCallback onSetDefault;
  final VoidCallback onRemove;

  const _AddressTile({
    required this.addr,
    required this.onEdit,
    required this.onSetDefault,
    required this.onRemove,
  });

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: kSurface2,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(addr.icon, style: const TextStyle(fontSize: 20)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          addr.label,
                          style: const TextStyle(
                            color: kInk,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        if (addr.isDefault) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: kGreen.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: const Text(
                              'Default',
                              style: TextStyle(
                                color: kGreen,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      addr.line1,
                      style: const TextStyle(
                        color: kInk,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      addr.shortLine,
                      style: const TextStyle(color: kMuted, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (addr.hasCoordinates) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            size: 11,
                            color: kBrand,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${addr.lat!.toStringAsFixed(4)}, ${addr.lng!.toStringAsFixed(4)}',
                            style: const TextStyle(color: kBrand, fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (!addr.isDefault) ...[
                Expanded(
                  child: _ActionBtn(
                    label: 'Set default',
                    color: kMuted,
                    onTap: onSetDefault,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: _ActionBtn(label: 'Edit', color: kBrand, onTap: onEdit),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionBtn(
                  label: 'Remove',
                  color: kRed,
                  onTap: onRemove,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
