import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../constants.dart';
import '../models/address.dart';
import 'map_picker_page.dart';

// ── Static seed data ──────────────────────────────────────────────────────────

final List<Address> _kSavedAddresses = [
  Address(id: 1, label: 'Home', line1: '123 Main Street', line2: 'Apt 4B, New York, NY 10001', icon: '🏠', isDefault: true),
  Address(id: 2, label: 'Work', line1: '350 Fifth Avenue', line2: 'Floor 12, New York, NY 10118', icon: '💼'),
  Address(id: 3, label: 'Gym', line1: '30 Rockefeller Plaza', line2: 'New York, NY 10112', icon: '💪'),
];

const _kNearbyPlaces = [
  {'id': 'n1', 'icon': '🏪', 'name': 'Central Park South', 'sub': '59th St & 5th Ave, New York'},
  {'id': 'n2', 'icon': '🏨', 'name': 'The Plaza Hotel', 'sub': '768 5th Ave, New York, NY 10019'},
  {'id': 'n3', 'icon': '🏬', 'name': 'Grand Central Terminal', 'sub': '89 E 42nd St, New York, NY 10017'},
  {'id': 'n4', 'icon': '🎭', 'name': 'Times Square', 'sub': 'Manhattan, New York, NY 10036'},
];

// ── Page ──────────────────────────────────────────────────────────────────────

class AddressPage extends StatefulWidget {
  /// The currently selected delivery address (line1).
  final String current;

  /// Called when the user confirms a selection.
  final ValueChanged<String> onSelect;

  /// Called when the back / "Deliver here" button is tapped.
  final VoidCallback onBack;

  const AddressPage({
    super.key,
    required this.current,
    required this.onSelect,
    required this.onBack,
  });

  @override
  State<AddressPage> createState() => _AddressPageState();
}

class _AddressPageState extends State<AddressPage> {
  late List<Address> _addresses;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  bool _showAddForm = false;

  // Add-new form fields
  final TextEditingController _labelCtrl = TextEditingController();
  final TextEditingController _line1Ctrl = TextEditingController();
  final TextEditingController _line2Ctrl = TextEditingController();

  // Coordinates picked from the map for the new address
  double? _newLat;
  double? _newLng;

  // Which id is currently selected (int for saved, String for nearby)
  late Object _selectedId;

  @override
  void initState() {
    super.initState();
    _addresses = List<Address>.from(_kSavedAddresses);
    final match = _addresses.where((a) => a.line1 == widget.current);
    _selectedId = match.isNotEmpty ? match.first.id : _addresses.first.id;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _labelCtrl.dispose();
    _line1Ctrl.dispose();
    _line2Ctrl.dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  void _handleSelect(Object id, String line1) {
    setState(() => _selectedId = id);
    widget.onSelect(line1);
  }

  void _setDefault(int id) =>
      setState(() => _addresses = _addresses.map((a) => a.copyWith(isDefault: a.id == id)).toList());

  void _delete(int id) {
    setState(() {
      _addresses = _addresses.where((a) => a.id != id).toList();
      if (_selectedId == id && _addresses.isNotEmpty) {
        _selectedId = _addresses.first.id;
        widget.onSelect(_addresses.first.line1);
      }
    });
  }

  void _handleAddNew() {
    if (_line1Ctrl.text.trim().isEmpty) return;
    final next = Address(
      id: DateTime.now().millisecondsSinceEpoch,
      label: _labelCtrl.text.trim().isEmpty ? 'Custom' : _labelCtrl.text.trim(),
      line1: _line1Ctrl.text.trim(),
      line2: _line2Ctrl.text.trim(),
      icon: '📍',
      lat: _newLat,
      lng: _newLng,
    );
    setState(() {
      _addresses = [..._addresses, next];
      _showAddForm = false;
      _labelCtrl.clear();
      _line1Ctrl.clear();
      _line2Ctrl.clear();
      _newLat = null;
      _newLng = null;
    });
    _handleSelect(next.id, next.line1);
  }

  /// Opens MapPickerPage. If [initialLatLng] is provided the map starts there.
  Future<void> _openMapPicker({LatLng? initialLatLng}) async {
    final result = await Navigator.of(context).push<MapPickerResult>(
      MaterialPageRoute(
        builder: (_) => MapPickerPage(initialPosition: initialLatLng),
        fullscreenDialog: true,
      ),
    );
    if (result == null || !mounted) return;

    setState(() {
      _newLat = result.lat;
      _newLng = result.lng;
      _line1Ctrl.text = result.address;
      _line2Ctrl.clear();
      _showAddForm = true;
    });
  }

  /// "Use my current location" tapped — open the map (no initial position,
  /// the map will auto-locate via its own FAB logic).
  Future<void> _useCurrentLocation() async {
    final result = await Navigator.of(context).push<MapPickerResult>(
      MaterialPageRoute(
        builder: (_) => const MapPickerPage(),
        fullscreenDialog: true,
      ),
    );
    if (result == null || !mounted) return;

    // Build an address from the result and select it immediately.
    final next = Address(
      id: DateTime.now().millisecondsSinceEpoch,
      label: 'Current Location',
      line1: result.address,
      line2: '${result.lat.toStringAsFixed(5)}, ${result.lng.toStringAsFixed(5)}',
      icon: '📍',
      lat: result.lat,
      lng: result.lng,
    );
    setState(() => _addresses = [..._addresses, next]);
    _handleSelect(next.id, next.line1);
  }

  List<Map<String, dynamic>> get _filteredNearby {
    final q = _searchQuery.toLowerCase();
    return _kNearbyPlaces
        .where((p) =>
            q.isEmpty ||
            (p['name'] as String).toLowerCase().contains(q) ||
            (p['sub'] as String).toLowerCase().contains(q))
        .toList();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCurrentLocationBtn(),
                const SizedBox(height: 20),
                if (_searchQuery.isEmpty) ...[
                  _buildSavedSection(),
                  const SizedBox(height: 24),
                ],
                _buildNearbySection(),
              ],
            ),
          ),
        ),
        _buildConfirmBar(),
      ],
    );
  }

  // ── Header (back + search) ────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: widget.onBack,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: kSurface,
                    border: Border.all(color: kBorder),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.chevron_left, color: kInk, size: 22),
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Delivery address',
                      style: TextStyle(color: kInk, fontSize: 18, fontWeight: FontWeight.w900)),
                  Text('Choose where to deliver your order',
                      style: TextStyle(color: kMuted, fontSize: 12)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: kSurface,
              border: Border.all(color: kBorder),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, size: 18, color: kMuted),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    style: const TextStyle(color: kInk, fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'Search for a street or area...',
                      hintStyle: TextStyle(color: kMuted, fontSize: 14),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchCtrl.clear();
                      setState(() => _searchQuery = '');
                    },
                    child: const Icon(Icons.close, size: 18, color: kMuted),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Current location button ───────────────────────────────────────────────

  Widget _buildCurrentLocationBtn() {
    return GestureDetector(
      onTap: _useCurrentLocation,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: kBrand.withValues(alpha: 0.08),
          border: Border.all(color: kBrand.withValues(alpha: 0.2)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: kBrand.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(child: Icon(Icons.my_location, size: 20, color: kBrand)),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Use my current location',
                      style: TextStyle(color: kBrand, fontSize: 14, fontWeight: FontWeight.w800)),
                  SizedBox(height: 2),
                  Text('Opens map · Pin your exact spot',
                      style: TextStyle(color: kMuted, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: kBrand, size: 20),
          ],
        ),
      ),
    );
  }

  // ── Saved addresses ───────────────────────────────────────────────────────

  Widget _buildSavedSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('SAVED ADDRESSES',
                style: TextStyle(color: kMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
            GestureDetector(
              onTap: () => setState(() => _showAddForm = !_showAddForm),
              child: Text(
                _showAddForm ? 'Cancel' : '+ Add new',
                style: const TextStyle(color: kBrand, fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        if (_showAddForm) ...[
          const SizedBox(height: 12),
          _buildAddForm(),
        ],
        const SizedBox(height: 12),
        ..._addresses.map((addr) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _AddressCard(
                addr: addr,
                isSelected: _selectedId == addr.id,
                onTap: () => _handleSelect(addr.id, addr.line1),
                onSetDefault: () => _setDefault(addr.id),
                onDelete: () => _delete(addr.id),
              ),
            )),
      ],
    );
  }

  Widget _buildAddForm() {
    final hasPinnedLocation = _newLat != null && _newLng != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurface,
        border: Border.all(color: kBorder),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('New address',
              style: TextStyle(color: kInk, fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),

          // ── Pin on map button ───────────────────────────────────────────
          GestureDetector(
            onTap: () => _openMapPicker(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: hasPinnedLocation
                    ? kBrand.withValues(alpha: 0.08)
                    : kSurface2,
                border: Border.all(
                  color: hasPinnedLocation ? kBrand.withValues(alpha: 0.4) : kBorder,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    hasPinnedLocation ? Icons.location_on : Icons.add_location_alt_outlined,
                    size: 18,
                    color: hasPinnedLocation ? kBrand : kMuted,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      hasPinnedLocation
                          ? '📍 ${_newLat!.toStringAsFixed(5)}, ${_newLng!.toStringAsFixed(5)}'
                          : 'Pin location on map',
                      style: TextStyle(
                        color: hasPinnedLocation ? kBrand : kMuted,
                        fontSize: 13,
                        fontWeight: hasPinnedLocation ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: hasPinnedLocation ? kBrand : kMuted,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          _formField(_labelCtrl, 'Label (e.g. Home, Office)'),
          const SizedBox(height: 8),
          _formField(_line1Ctrl, 'Street address *'),
          const SizedBox(height: 8),
          _formField(_line2Ctrl, 'Apt, floor, city, ZIP'),
          const SizedBox(height: 12),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _line1Ctrl,
            builder: (context, value, _) {
              final enabled = value.text.trim().isNotEmpty;
              return GestureDetector(
                onTap: enabled ? _handleAddNew : null,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: enabled ? kBrand : kBorder,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: const Text('Save address',
                      style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _formField(TextEditingController ctrl, String hint) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: kInk, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: kMuted, fontSize: 14),
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        isDense: true,
      ),
    );
  }

  // ── Nearby places ─────────────────────────────────────────────────────────

  Widget _buildNearbySection() {
    final places = _filteredNearby;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _searchQuery.isNotEmpty ? 'Results for "$_searchQuery"' : 'NEARBY PLACES',
          style: const TextStyle(
              color: kMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1),
        ),
        const SizedBox(height: 12),
        if (places.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: const [
                  Icon(Icons.map_outlined, size: 40, color: kMuted),
                  SizedBox(height: 10),
                  Text('No places found',
                      style: TextStyle(color: kInk, fontSize: 14, fontWeight: FontWeight.w600)),
                  SizedBox(height: 4),
                  Text('Try a different search term',
                      style: TextStyle(color: kMuted, fontSize: 13)),
                ],
              ),
            ),
          )
        else
          ...places.map((place) {
            final isSelected = _selectedId == place['id'];
            return GestureDetector(
              onTap: () => _handleSelect(place['id'] as String, place['name'] as String),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(bottom: 2),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                decoration: BoxDecoration(
                  color: isSelected ? kBrand.withValues(alpha: 0.08) : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? kBrand : Colors.transparent,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: kSurface,
                        border: Border.all(color: kSurface2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(place['icon'] as String, style: const TextStyle(fontSize: 18)),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(place['name'] as String,
                              style: const TextStyle(color: kInk, fontWeight: FontWeight.w700, fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 1),
                          Text(place['sub'] as String,
                              style: const TextStyle(color: kMuted, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Container(
                        width: 9,
                        height: 9,
                        decoration: const BoxDecoration(color: kBrand, shape: BoxShape.circle),
                      ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  // ── Confirm bar ───────────────────────────────────────────────────────────

  Widget _buildConfirmBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: const BoxDecoration(
        color: kCanvas,
        border: Border(top: BorderSide(color: kSurface2)),
      ),
      child: GestureDetector(
        onTap: widget.onBack,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [kBrand, kBrandDark]),
            borderRadius: BorderRadius.circular(18),
          ),
          alignment: Alignment.center,
          child: const Text('Deliver here ›',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
        ),
      ),
    );
  }
}

// ── Address card widget ───────────────────────────────────────────────────────

class _AddressCard extends StatelessWidget {
  final Address addr;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onSetDefault;
  final VoidCallback onDelete;

  const _AddressCard({
    required this.addr,
    required this.isSelected,
    required this.onTap,
    required this.onSetDefault,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? kBrand.withValues(alpha: 0.08) : kSurface,
          border: Border.all(
            color: isSelected ? kBrand : kSurface2,
            width: isSelected ? 1.5 : 1,
          ),
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
                    color: isSelected ? kBrand.withValues(alpha: 0.15) : kSurface2,
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
                          Text(addr.label,
                              style: const TextStyle(
                                  color: kInk, fontWeight: FontWeight.w800, fontSize: 14)),
                          if (addr.isDefault) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: kGreen.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: const Text('Default',
                                  style: TextStyle(
                                      color: kGreen, fontSize: 10, fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 1),
                      Text(addr.line1,
                          style: const TextStyle(
                              color: kInk, fontSize: 13, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Text(addr.line2,
                          style: const TextStyle(color: kMuted, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: isSelected ? kBrand : kBorder, width: 2),
                  ),
                  child: isSelected
                      ? Center(
                          child: Container(
                            width: 9,
                            height: 9,
                            decoration:
                                const BoxDecoration(color: kBrand, shape: BoxShape.circle),
                          ),
                        )
                      : null,
                ),
              ],
            ),
            if (isSelected) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.only(top: 10),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: kBrand.withValues(alpha: 0.15)),
                  ),
                ),
                child: Row(
                  children: [
                    if (!addr.isDefault)
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
                    if (!addr.isDefault) const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: onDelete,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          decoration: BoxDecoration(
                            border: Border.all(color: kRed.withValues(alpha: 0.25)),
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
              ),
            ],
          ],
        ),
      ),
    );
  }
}
