import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../constants.dart';
import '../../providers/auth_provider.dart';
import '../../services/owner_repository.dart';
import '../../utils/restaurant_form_helpers.dart';
import '../map_picker_page.dart';

// ── Page mode ──────────────────────────────────────────────────────────────────

enum _PageMode { loading, setup, readView, editing, saving }

// ── Main page ──────────────────────────────────────────────────────────────────

/// Displays the restaurant's Firestore document for the owner.
///
/// Supports three modes:
/// - **setup** — when the owner has no linked restaurant (restaurantId is null).
/// - **readView** — displays loaded restaurant data with an Edit button.
/// - **editing** — inline edit form pre-populated with current data.
///
/// The `_PageMode` state machine and full sub-views (setup, edit, saving
/// overlay) are wired in task 8.x. This stub keeps the existing fetch/display
/// logic working in the meantime.
class OwnerRestaurantPage extends StatefulWidget {
  const OwnerRestaurantPage({super.key});

  @override
  State<OwnerRestaurantPage> createState() => _OwnerRestaurantPageState();
}

class _OwnerRestaurantPageState extends State<OwnerRestaurantPage> {
  _PageMode _mode = _PageMode.loading;
  Map<String, dynamic>? _restaurantData;
  String? _fetchError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _mode = _PageMode.loading;
      _fetchError = null;
    });
    try {
      final rid = context.read<AppAuthProvider>().restaurantId;
      if (rid == null || rid.isEmpty) {
        if (mounted) setState(() => _mode = _PageMode.setup);
        return;
      }
      debugPrint('OwnerRestaurantPage: loading restaurantId="$rid"');
      final data = await OwnerRepository.instance
          .fetchRestaurant(rid)
          .timeout(const Duration(seconds: 30));
      debugPrint(
        'OwnerRestaurantPage: fetchRestaurant returned '
        '${data == null ? "null" : "data with keys ${data.keys}"}',
      );
      if (mounted) {
        if (data == null) {
          setState(() {
            _fetchError = 'Restaurant data could not be found.';
            _mode = _PageMode.loading; // stays in error sub-state
          });
        } else {
          setState(() {
            _restaurantData = data;
            _mode = _PageMode.readView;
          });
        }
      }
    } on TimeoutException {
      debugPrint('OwnerRestaurantPage: timeout');
      if (mounted) {
        setState(() {
          _fetchError = 'The request timed out. Please try again.';
        });
      }
    } catch (e) {
      debugPrint('OwnerRestaurantPage: error $e');
      if (mounted) {
        setState(() {
          _fetchError =
              'Could not load restaurant information. Please try again.';
        });
      }
    }
  }

  void _onSetupComplete(Map<String, dynamic> newData) {
    setState(() {
      _restaurantData = newData;
      _mode = _PageMode.readView;
    });
  }

  void _enterEditing() {
    setState(() => _mode = _PageMode.editing);
  }

  void _cancelEditing() {
    setState(() => _mode = _PageMode.readView);
  }

  void _onEditComplete(Map<String, dynamic> updated) {
    setState(() {
      _restaurantData = updated;
      _mode = _PageMode.readView;
    });
  }

  Widget _buildBody() {
    // Error sub-state (fetch failed / null doc / timeout)
    if (_fetchError != null) {
      return _ErrorView(message: _fetchError!, onRetry: _load);
    }

    switch (_mode) {
      case _PageMode.loading:
        return const Center(
          child: CircularProgressIndicator(color: kBrand, strokeWidth: 2),
        );
      case _PageMode.setup:
        return _SetupView(onCreated: _onSetupComplete);
      case _PageMode.readView:
        return _ReadView(
          data: _restaurantData!,
          onEditTapped: _enterEditing,
        );
      case _PageMode.editing:
        return _EditView(
          initialData: _restaurantData!,
          onCancel: _cancelEditing,
          onSaved: _onEditComplete,
        );
      case _PageMode.saving:
        return Stack(
          children: [
            _ReadView(
              data: _restaurantData!,
              onEditTapped: _enterEditing,
            ),
            // Pointer-absorbing loading scrim used during async saves (8.x)
            const AbsorbPointer(
              child: ColoredBox(
                color: Color(0x80000000),
                child: Center(
                  child:
                      CircularProgressIndicator(color: kBrand, strokeWidth: 2),
                ),
              ),
            ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _mode != _PageMode.saving,
      child: Scaffold(
        backgroundColor: kCanvas,
        body: RefreshIndicator(
          color: kBrand,
          backgroundColor: kSurface,
          onRefresh: _load,
          child: CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildBody(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── _ReadView ──────────────────────────────────────────────────────────────────

/// Read-only view of the restaurant document, with an Edit button in the header.
class _ReadView extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onEditTapped;

  const _ReadView({required this.data, required this.onEditTapped});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // ── Header row with title + Edit button ───────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Restaurant',
                    style: kSerif.copyWith(
                      color: kInk,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: onEditTapped,
                  style: TextButton.styleFrom(
                    foregroundColor: kBrand,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text(
                    'Edit',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
        // ── Body content ──────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: _RestaurantBody(data: data),
        ),
      ],
    );
  }
}

// ── Restaurant body ────────────────────────────────────────────────────────────

class _RestaurantBody extends StatelessWidget {
  final Map<String, dynamic> data;

  const _RestaurantBody({required this.data});

  @override
  Widget build(BuildContext context) {
    final name = data['name'] as String? ?? '—';
    final cuisine = data['cuisine'] as String? ?? data['category'] as String?;
    final description =
        data['description'] as String? ?? data['about'] as String?;
    final imageUrl = data['img'] as String? ??
        data['image'] as String? ??
        data['imageUrl'] as String?;
    final rating = data['rating'];
    final openTime = data['openTime'] as String? ?? data['hours'] as String?;
    final phone = data['phone'] as String? ?? data['phoneNumber'] as String?;
    final address = data['address'] as String?;
    final lat = (data['lat'] as num?)?.toDouble();
    final lng = (data['lng'] as num?)?.toDouble();

    // Fields already rendered above — exclude from the generic section.
    const knownKeys = {
      'id', 'name', 'cuisine', 'category', 'description', 'about',
      'img', 'image', 'imageUrl', 'rating', 'openTime', 'hours',
      'phone', 'phoneNumber', 'address', 'lat', 'lng',
    };
    final extras = Map.fromEntries(
      data.entries.where((e) => !knownKeys.contains(e.key)),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Hero image ─────────────────────────────────────────────────
          if (imageUrl != null && imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                imageUrl,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: kSurface2,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.storefront_outlined,
                      color: kMuted, size: 48),
                ),
              ),
            ),

          if (imageUrl != null && imageUrl.isNotEmpty)
            const SizedBox(height: 20),

          // ── Name + cuisine ─────────────────────────────────────────────
          Text(
            name,
            style: kSerif.copyWith(
              color: kInk,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (cuisine != null) ...[
            const SizedBox(height: 4),
            Text(cuisine,
                style: const TextStyle(color: kMuted, fontSize: 14)),
          ],
          const SizedBox(height: 20),

          // ── Info card ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kBorder),
            ),
            child: Column(
              children: [
                if (rating != null)
                  _InfoTile(
                    icon: Icons.star_rounded,
                    iconColor: kGold,
                    label: 'Rating',
                    value: '$rating',
                  ),
                if (openTime != null) ...[
                  if (rating != null) const _Divider(),
                  _InfoTile(
                    icon: Icons.access_time_rounded,
                    iconColor: kBrand,
                    label: 'Hours',
                    value: openTime,
                  ),
                ],
                if (phone != null) ...[
                  const _Divider(),
                  _InfoTile(
                    icon: Icons.phone_outlined,
                    iconColor: kMuted,
                    label: 'Phone',
                    value: phone,
                  ),
                ],
                if (address != null) ...[
                  const _Divider(),
                  _InfoTile(
                    icon: Icons.location_on_outlined,
                    iconColor: kMuted,
                    label: 'Address',
                    value: address,
                  ),
                ],
                if (lat != null && lng != null) ...[
                  const _Divider(),
                  _MapThumbnail(lat: lat, lng: lng),
                ],
              ],
            ),
          ),

          // ── Description ────────────────────────────────────────────────
          if (description != null && description.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'About',
              style: kSerif.copyWith(
                color: kInk,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(description,
                style: const TextStyle(
                    color: kMuted, fontSize: 14, height: 1.5)),
          ],

          // ── Extra fields ───────────────────────────────────────────────
          if (extras.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Details',
              style: kSerif.copyWith(
                color: kInk,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kBorder),
              ),
              child: Column(
                children: extras.entries.map((e) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${e.key}:',
                          style: const TextStyle(
                              color: kMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${e.value}',
                            style: const TextStyle(
                                color: kInk, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Task 4.1: _RestaurantFormField ────────────────────────────────────────────

/// Styled `TextFormField` wrapper matching the dark design system.
///
/// Renders a label above the field in `kInk` at 14 sp weight 600.
/// Decoration: `fillColor: kSurface`, enabled border `kBorder`, focused border
/// `kBrand`, error border `kRed`, disabled border faded, radius 12.
class _RestaurantFormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final int maxLines;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final bool enabled;
  final String? Function(String?)? validator;
  final VoidCallback? onEditingComplete;
  final int? maxLength;

  const _RestaurantFormField({
    required this.controller,
    required this.label,
    required this.textInputAction,
    this.hint,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
    this.enabled = true,
    this.validator,
    this.onEditingComplete, // ignore: unused_element_parameter
    this.maxLength,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: kInk,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          enabled: enabled,
          validator: validator,
          onEditingComplete: onEditingComplete,
          maxLength: maxLength,
          style: const TextStyle(color: kInk, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: kMuted, fontSize: 14),
            filled: true,
            fillColor: kSurface,
            counterStyle: const TextStyle(color: kMuted, fontSize: 11),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
              borderSide: const BorderSide(color: kBrand),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kRed),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kRed),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: kBorder.withAlpha(100)),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Task 4.2: _CuisineSelector ────────────────────────────────────────────────

/// `DropdownButtonFormField<String>` built from `kCategoryIcons` keys.
///
/// Styled for the dark theme: `dropdownColor: kSurface2`, icon `kMuted`,
/// selected value text `kInk`. Container decoration mirrors `_RestaurantFormField`.
/// Requires a selection — validator returns an error when value is null/empty.
class _CuisineSelector extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;
  final bool enabled;

  const _CuisineSelector({
    required this.onChanged,
    this.value,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final cuisines = kCategoryIcons.keys.where((k) => k != 'All').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Cuisine / Category',
          style: TextStyle(
            color: kInk,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: value,
          onChanged: enabled ? onChanged : null,
          dropdownColor: kSurface2,
          iconEnabledColor: kMuted,
          iconDisabledColor: kMuted,
          isExpanded: true,
          style: const TextStyle(color: kInk, fontSize: 14),
          validator: (v) =>
              (v == null || v.isEmpty) ? 'Please select a cuisine' : null,
          decoration: InputDecoration(
            hintText: 'Select cuisine',
            hintStyle: const TextStyle(color: kMuted, fontSize: 14),
            filled: true,
            fillColor: kSurface,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
              borderSide: const BorderSide(color: kBrand),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kRed),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kRed),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: kBorder.withAlpha(100)),
            ),
          ),
          items: cuisines
              .map(
                (c) => DropdownMenuItem(
                  value: c,
                  child: Text(c,
                      style:
                          const TextStyle(color: kInk, fontSize: 14)),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

// ── Task 4.3: _ImagePreviewField ──────────────────────────────────────────────

/// Text field for an image URL with a debounced live preview below.
///
/// Owns a 600 ms debounce timer. When the user pauses typing, `_previewUrl` is
/// updated and a `Image.network` preview (max 200 px height, full width) is
/// shown. An `errorBuilder` displays `Icons.broken_image_outlined` at the same
/// dimensions when the network image fails to load. Nothing is shown when the
/// URL field is empty.
///
/// Validation: rejects non-empty strings that fail `isValidImageUrl`; empty
/// strings are accepted (image is optional).
class _ImagePreviewField extends StatefulWidget {
  final TextEditingController controller;
  final bool enabled;
  final String? Function(String?)? validator;
  final TextInputAction textInputAction;

  const _ImagePreviewField({
    required this.controller,
    required this.textInputAction,
    this.enabled = true,
    this.validator, // ignore: unused_element_parameter
  });

  @override
  State<_ImagePreviewField> createState() => _ImagePreviewFieldState();
}

class _ImagePreviewFieldState extends State<_ImagePreviewField> {
  Timer? _debounce;
  String? _previewUrl;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      final text = widget.controller.text.trim();
      if (mounted) {
        setState(() => _previewUrl = text.isNotEmpty ? text : null);
      }
    });
  }

  String? _defaultValidator(String? value) {
    if (value == null || value.trim().isEmpty) return null; // optional field
    if (!isValidImageUrl(value.trim())) return 'Enter a valid http/https URL';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RestaurantFormField(
          controller: widget.controller,
          label: 'Image URL',
          hint: 'https://example.com/image.jpg',
          textInputAction: widget.textInputAction,
          enabled: widget.enabled,
          keyboardType: TextInputType.url,
          validator: widget.validator ?? _defaultValidator,
        ),
        if (_previewUrl != null) ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              _previewUrl!,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: kSurface2,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.broken_image_outlined,
                  color: kMuted,
                  size: 40,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Task 4.3b: _LocationPickerField ──────────────────────────────────────────

/// Tappable card that opens [MapPickerPage] and displays the pinned location.
///
/// Shows "Pin on map" placeholder when no location is set.
/// When a location is pinned, shows the resolved address and lat/lng subtitle,
/// with an optional clear (×) button on the right.
class _LocationPickerField extends StatelessWidget {
  final double? lat;
  final double? lng;
  final String? resolvedAddress;
  final bool enabled;
  final void Function(double lat, double lng, String address) onPicked;
  final VoidCallback? onClear;

  const _LocationPickerField({
    required this.onPicked,
    this.lat,
    this.lng,
    this.resolvedAddress,
    this.enabled = true,
    this.onClear,
  });

  Future<void> _openPicker(BuildContext context) async {
    final LatLng? initial =
        lat != null ? LatLng(lat!, lng!) : null;

    final result = await Navigator.of(context).push<MapPickerResult>(
      MaterialPageRoute(
        builder: (_) => MapPickerPage(initialPosition: initial),
      ),
    );

    if (result != null) {
      onPicked(result.lat, result.lng, result.address);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasPinned = lat != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Location',
          style: TextStyle(
            color: kInk,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: enabled ? () => _openPicker(context) : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: enabled ? kBorder : kBorder.withAlpha(100),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  hasPinned
                      ? Icons.location_on
                      : Icons.location_on_outlined,
                  color: hasPinned ? kBrand : kMuted,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: hasPinned
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              resolvedAddress?.isNotEmpty == true
                                  ? resolvedAddress!
                                  : 'Location pinned',
                              style: const TextStyle(
                                color: kInk,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${lat!.toStringAsFixed(6)}, '
                              '${lng!.toStringAsFixed(6)}',
                              style: const TextStyle(
                                color: kMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        )
                      : const Text(
                          'Pin on map',
                          style: TextStyle(color: kMuted, fontSize: 14),
                        ),
                ),
                if (hasPinned && onClear != null && enabled)
                  IconButton(
                    icon: const Icon(Icons.close, size: 16, color: kMuted),
                    onPressed: onClear,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    splashRadius: 16,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Task 4.4: _FormActionButton ───────────────────────────────────────────────

/// Full-width action button for Create Restaurant / Save.
///
/// Mirrors the large variant of `_SaveButton` from
/// `owner_add_edit_menu_item_page.dart`:
/// - Background `kBrand`; `kBrand.withAlpha(120)` when `onTap == null`.
/// - Text `kInk` 15 sp w700.
/// - Shows a 20×20 `CircularProgressIndicator(color: kInk)` when `isLoading`.
class _FormActionButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback? onTap;

  const _FormActionButton({
    required this.label,
    required this.isLoading,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 50,
        decoration: BoxDecoration(
          color: onTap != null ? kBrand : kBrand.withAlpha(120),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: kInk, strokeWidth: 2),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    color: kInk,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }
}

// ── Task 4.5: _ErrorBanner ────────────────────────────────────────────────────

/// Dismissible error banner.
///
/// Background `kRed.withAlpha(25)`, border `kRed.withAlpha(80)`, radius 12.
/// Row: error icon (kRed 18), message text (kRed 13), dismiss X on the right.
/// Matches the `_ErrorBanner` pattern in `owner_add_edit_menu_item_page.dart`.
class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;

  const _ErrorBanner({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: kRed.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kRed.withAlpha(80)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: kRed, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: kRed, fontSize: 13),
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: const Icon(Icons.close, color: kRed, size: 18),
          ),
        ],
      ),
    );
  }
}

// ── Shared small display widgets ───────────────────────────────────────────────

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(color: kMuted, fontSize: 11)),
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

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Divider(color: kBorder, height: 1),
      );
}

// ── _MapThumbnail ─────────────────────────────────────────────────────────────

/// Static map thumbnail. Tap to open a full-screen interactive map.
class _MapThumbnail extends StatelessWidget {
  final double lat;
  final double lng;

  const _MapThumbnail({required this.lat, required this.lng});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _FullMapPage(lat: lat, lng: lng),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 160,
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(lat, lng),
                    zoom: 15,
                  ),
                  markers: {
                    Marker(
                      markerId: const MarkerId('restaurant'),
                      position: LatLng(lat, lng),
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueOrange,
                      ),
                    ),
                  },
                  zoomControlsEnabled: false,
                  myLocationButtonEnabled: false,
                  mapToolbarEnabled: false,
                  liteModeEnabled: true,
                ),
                // Overlay hint
                Positioned(
                  bottom: 8,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.open_in_full, color: Colors.white, size: 11),
                        SizedBox(width: 4),
                        Text(
                          'Tap to expand',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── _FullMapPage ──────────────────────────────────────────────────────────────

/// Full-screen interactive map showing the restaurant's pinned location.
///
/// Opened when the owner taps the map thumbnail in the read view.
/// Supports full zoom, pan, and tilt gestures. Zoom controls are shown.
class _FullMapPage extends StatefulWidget {
  final double lat;
  final double lng;

  const _FullMapPage({required this.lat, required this.lng});

  @override
  State<_FullMapPage> createState() => _FullMapPageState();
}

class _FullMapPageState extends State<_FullMapPage> {
  GoogleMapController? _controller;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final position = LatLng(widget.lat, widget.lng);

    return Scaffold(
      backgroundColor: kCanvas,
      appBar: AppBar(
        backgroundColor: kSurface,
        foregroundColor: kInk,
        elevation: 0,
        title: Text(
          'Restaurant Location',
          style: kSerif.copyWith(
            color: kInk,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          // Recenter button
          IconButton(
            icon: const Icon(Icons.my_location, size: 20),
            tooltip: 'Recenter',
            onPressed: () => _controller?.animateCamera(
              CameraUpdate.newCameraPosition(
                CameraPosition(target: position, zoom: 16),
              ),
            ),
          ),
        ],
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: position,
          zoom: 16,
        ),
        onMapCreated: (c) => _controller = c,
        markers: {
          Marker(
            markerId: const MarkerId('restaurant'),
            position: position,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueOrange,
            ),
          ),
        },
        zoomControlsEnabled: true,
        myLocationButtonEnabled: false,
        mapToolbarEnabled: true,
        zoomGesturesEnabled: true,
        scrollGesturesEnabled: true,
        rotateGesturesEnabled: true,
        tiltGesturesEnabled: true,
        liteModeEnabled: false,
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.storefront_outlined, color: kMuted, size: 48),
            const SizedBox(height: 12),
            Text(message,
                style: const TextStyle(color: kMuted, fontSize: 14),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kBrand,
                foregroundColor: kInk,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Task 6: _SetupView ────────────────────────────────────────────────────────

/// Guided form for creating a restaurant document for the first time.
///
/// Handles partial-write retry: if `createRestaurant` succeeds but
/// `linkRestaurantToOwner` fails, `_pendingRestaurantId` is retained so the
/// next submit attempt skips the creation step and retries only the link.
class _SetupView extends StatefulWidget {
  final void Function(Map<String, dynamic> newData) onCreated;

  const _SetupView({required this.onCreated});

  @override
  State<_SetupView> createState() => _SetupViewState();
}

class _SetupViewState extends State<_SetupView> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _imageUrlCtrl = TextEditingController();
  final _openTimeCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  String? _selectedCuisine;
  bool _isSaving = false;
  String? _errorMessage;

  // Location state
  double? _lat;
  double? _lng;
  String? _locationAddress;

  /// Retained after a successful `createRestaurant` call so a failed
  /// `linkRestaurantToOwner` can be retried without creating a duplicate.
  String? _pendingRestaurantId;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _imageUrlCtrl.dispose();
    _openTimeCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      // Step 1: Create restaurant (skip if already created in a previous attempt)
      if (_pendingRestaurantId == null) {
        final fields = {
          'name': _nameCtrl.text.trim(),
          'cuisine': _selectedCuisine!,
          if (_descCtrl.text.trim().isNotEmpty)
            'description': _descCtrl.text.trim(),
          if (_imageUrlCtrl.text.trim().isNotEmpty)
            'img': _imageUrlCtrl.text.trim(),
          if (_openTimeCtrl.text.trim().isNotEmpty)
            'openTime': _openTimeCtrl.text.trim(),
          if (_phoneCtrl.text.trim().isNotEmpty)
            'phone': _phoneCtrl.text.trim(),
          if (_addressCtrl.text.trim().isNotEmpty)
            'address': _addressCtrl.text.trim(),
          if (_lat != null) ...{'lat': _lat, 'lng': _lng},
        };
        try {
          _pendingRestaurantId =
              await OwnerRepository.instance.createRestaurant(fields);
        } catch (_) {
          if (mounted) {
            setState(() {
              _isSaving = false;
              _errorMessage =
                  'Your restaurant could not be created. Please try again.';
            });
          }
          return;
        }
      }

      // Step 2: Link to owner profile
      try {
        await OwnerRepository.instance
            .linkRestaurantToOwner(_pendingRestaurantId!);
      } catch (_) {
        if (mounted) {
          setState(() {
            _isSaving = false;
            _errorMessage =
                'Setup could not be completed. Please try again.';
          });
        }
        return;
      }

      // Step 3: Update auth provider in-memory state
      if (mounted) {
        context.read<AppAuthProvider>().updateRestaurantId(_pendingRestaurantId!);
      }

      // Build the data map to pass to onCreated
      final newData = {
        'name': _nameCtrl.text.trim(),
        'cuisine': _selectedCuisine!,
        if (_descCtrl.text.trim().isNotEmpty)
          'description': _descCtrl.text.trim(),
        if (_imageUrlCtrl.text.trim().isNotEmpty)
          'img': _imageUrlCtrl.text.trim(),
        if (_openTimeCtrl.text.trim().isNotEmpty)
          'openTime': _openTimeCtrl.text.trim(),
        if (_phoneCtrl.text.trim().isNotEmpty)
          'phone': _phoneCtrl.text.trim(),
        if (_addressCtrl.text.trim().isNotEmpty)
          'address': _addressCtrl.text.trim(),
        if (_lat != null) ...{'lat': _lat, 'lng': _lng},
        'id': _pendingRestaurantId!,
      };

      _pendingRestaurantId = null; // clear only on full success
      widget.onCreated(newData); // triggers parent state transition
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Heading
          Text(
            'Set Up Your Restaurant',
            style: kSerif.copyWith(
              color: kInk,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "Enter your restaurant's details to get started.",
            style: TextStyle(color: kMuted, fontSize: 14),
          ),
          const SizedBox(height: 24),

          // Error banner
          if (_errorMessage != null)
            _ErrorBanner(
              message: _errorMessage!,
              onDismiss: () => setState(() => _errorMessage = null),
            ),

          // Form
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _RestaurantFormField(
                  controller: _nameCtrl,
                  label: 'Restaurant Name',
                  hint: 'e.g. Sunset Grill',
                  maxLength: 100,
                  textInputAction: TextInputAction.next,
                  enabled: !_isSaving,
                  validator: (v) {
                    final s = v?.trim() ?? '';
                    if (s.isEmpty) return 'Restaurant name is required';
                    if (s.length > 100) return 'Name must be 100 characters or fewer';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _CuisineSelector(
                  value: _selectedCuisine,
                  onChanged: (v) => setState(() => _selectedCuisine = v),
                  enabled: !_isSaving,
                ),
                const SizedBox(height: 16),
                _RestaurantFormField(
                  controller: _descCtrl,
                  label: 'Description',
                  hint: 'Tell customers about your restaurant...',
                  maxLines: 3,
                  textInputAction: TextInputAction.next,
                  enabled: !_isSaving,
                ),
                const SizedBox(height: 16),
                _ImagePreviewField(
                  controller: _imageUrlCtrl,
                  enabled: !_isSaving,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                _RestaurantFormField(
                  controller: _openTimeCtrl,
                  label: 'Opening Hours',
                  hint: 'e.g. 9am – 9pm, Mon–Sat',
                  textInputAction: TextInputAction.next,
                  enabled: !_isSaving,
                ),
                const SizedBox(height: 16),
                _RestaurantFormField(
                  controller: _phoneCtrl,
                  label: 'Phone Number',
                  hint: 'e.g. +63 917 123 4567',
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  enabled: !_isSaving,
                ),
                const SizedBox(height: 16),
                _RestaurantFormField(
                  controller: _addressCtrl,
                  label: 'Address',
                  hint: 'Street, City',
                  maxLines: 2,
                  textInputAction: TextInputAction.next,
                  enabled: !_isSaving,
                ),
                const SizedBox(height: 16),
                _LocationPickerField(
                  lat: _lat,
                  lng: _lng,
                  resolvedAddress: _locationAddress,
                  enabled: !_isSaving,
                  onPicked: (lat, lng, addr) => setState(() {
                    _lat = lat;
                    _lng = lng;
                    _locationAddress = addr;
                    // Auto-fill address text field if empty
                    if (_addressCtrl.text.trim().isEmpty) {
                      _addressCtrl.text = addr;
                    }
                  }),
                  onClear: () => setState(() {
                    _lat = null;
                    _lng = null;
                    _locationAddress = null;
                  }),
                ),
                const SizedBox(height: 28),
                _FormActionButton(
                  label: 'Create Restaurant',
                  isLoading: _isSaving,
                  onTap: _isSaving ? null : _submit,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Task 7: _EditView ─────────────────────────────────────────────────────────

/// Edit form pre-populated from [initialData].
///
/// On save, computes a diff against the original values.  If nothing changed,
/// calls [onSaved] without making a Firestore write.
class _EditView extends StatefulWidget {
  final Map<String, dynamic> initialData;
  final VoidCallback onCancel;
  final void Function(Map<String, dynamic> updated) onSaved;

  const _EditView({
    required this.initialData,
    required this.onCancel,
    required this.onSaved,
  });

  @override
  State<_EditView> createState() => _EditViewState();
}

class _EditViewState extends State<_EditView> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _imageUrlCtrl;
  late final TextEditingController _openTimeCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _addressCtrl;

  String? _selectedCuisine;
  bool _isSaving = false;
  String? _errorMessage;

  // Location state
  double? _lat;
  double? _lng;
  String? _locationAddress;

  @override
  void initState() {
    super.initState();
    final d = widget.initialData;
    _nameCtrl = TextEditingController(text: d['name'] as String? ?? '');
    _descCtrl = TextEditingController(text: d['description'] as String? ?? '');
    _imageUrlCtrl = TextEditingController(text: d['img'] as String? ?? '');
    _openTimeCtrl = TextEditingController(text: d['openTime'] as String? ?? '');
    _phoneCtrl = TextEditingController(text: d['phone'] as String? ?? '');
    _addressCtrl = TextEditingController(text: d['address'] as String? ?? '');
    _selectedCuisine = d['cuisine'] as String?;
    _lat = (d['lat'] as num?)?.toDouble();
    _lng = (d['lng'] as num?)?.toDouble();
    // Use stored address as display label; a re-pin will update it
    _locationAddress = d['address'] as String?;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _imageUrlCtrl.dispose();
    _openTimeCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final restaurantId = widget.initialData['id'] as String? ?? '';

    final updatedFields = {
      'name': _nameCtrl.text.trim(),
      'cuisine': _selectedCuisine ?? '',
      'description': _descCtrl.text.trim(),
      'img': _imageUrlCtrl.text.trim(),
      'openTime': _openTimeCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'address': _addressCtrl.text.trim(),
      'lat': _lat,
      'lng': _lng,
    };

    // Normalise original values to empty string for direct comparison
    final originalNormalised = {
      'name': widget.initialData['name'] as String? ?? '',
      'cuisine': widget.initialData['cuisine'] as String? ?? '',
      'description': widget.initialData['description'] as String? ?? '',
      'img': widget.initialData['img'] as String? ?? '',
      'openTime': widget.initialData['openTime'] as String? ?? '',
      'phone': widget.initialData['phone'] as String? ?? '',
      'address': widget.initialData['address'] as String? ?? '',
      'lat': (widget.initialData['lat'] as num?)?.toDouble(),
      'lng': (widget.initialData['lng'] as num?)?.toDouble(),
    };

    final diff = computeDiff(originalNormalised, updatedFields);

    if (diff.isEmpty) {
      // No changes — skip Firestore write
      widget.onSaved({...widget.initialData, ...updatedFields});
      return;
    }

    try {
      await OwnerRepository.instance.updateRestaurant(restaurantId, diff);
      if (mounted) {
        widget.onSaved({...widget.initialData, ...updatedFields});
      }
    } catch (e) {
      debugPrint('_EditView._save error: $e');
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'Could not save changes. Please try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: title + Cancel button
          Row(
            children: [
              Expanded(
                child: Text(
                  'Edit Restaurant',
                  style: kSerif.copyWith(
                    color: kInk,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              TextButton(
                onPressed: _isSaving ? null : widget.onCancel,
                style: TextButton.styleFrom(foregroundColor: kMuted),
                child: const Text('Cancel'),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Error banner
          if (_errorMessage != null)
            _ErrorBanner(
              message: _errorMessage!,
              onDismiss: () => setState(() => _errorMessage = null),
            ),

          // Form
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _RestaurantFormField(
                  controller: _nameCtrl,
                  label: 'Restaurant Name',
                  hint: 'e.g. Sunset Grill',
                  maxLength: 100,
                  textInputAction: TextInputAction.next,
                  enabled: !_isSaving,
                  validator: (v) {
                    final s = v?.trim() ?? '';
                    if (s.isEmpty) return 'Restaurant name is required';
                    if (s.length > 100) return 'Name must be 100 characters or fewer';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _CuisineSelector(
                  value: _selectedCuisine,
                  onChanged: (v) => setState(() => _selectedCuisine = v),
                  enabled: !_isSaving,
                ),
                const SizedBox(height: 16),
                _RestaurantFormField(
                  controller: _descCtrl,
                  label: 'Description',
                  hint: 'Tell customers about your restaurant...',
                  maxLines: 3,
                  textInputAction: TextInputAction.next,
                  enabled: !_isSaving,
                ),
                const SizedBox(height: 16),
                _ImagePreviewField(
                  controller: _imageUrlCtrl,
                  enabled: !_isSaving,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                _RestaurantFormField(
                  controller: _openTimeCtrl,
                  label: 'Opening Hours',
                  hint: 'e.g. 9am – 9pm, Mon–Sat',
                  textInputAction: TextInputAction.next,
                  enabled: !_isSaving,
                ),
                const SizedBox(height: 16),
                _RestaurantFormField(
                  controller: _phoneCtrl,
                  label: 'Phone Number',
                  hint: 'e.g. +63 917 123 4567',
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  enabled: !_isSaving,
                ),
                const SizedBox(height: 16),
                _RestaurantFormField(
                  controller: _addressCtrl,
                  label: 'Address',
                  hint: 'Street, City',
                  maxLines: 2,
                  textInputAction: TextInputAction.next,
                  enabled: !_isSaving,
                ),
                const SizedBox(height: 16),
                _LocationPickerField(
                  lat: _lat,
                  lng: _lng,
                  resolvedAddress: _locationAddress,
                  enabled: !_isSaving,
                  onPicked: (lat, lng, addr) => setState(() {
                    _lat = lat;
                    _lng = lng;
                    _locationAddress = addr;
                    // Auto-fill address text field if empty
                    if (_addressCtrl.text.trim().isEmpty) {
                      _addressCtrl.text = addr;
                    }
                  }),
                  onClear: () => setState(() {
                    _lat = null;
                    _lng = null;
                    _locationAddress = null;
                  }),
                ),
                const SizedBox(height: 28),
                _FormActionButton(
                  label: 'Save Changes',
                  isLoading: _isSaving,
                  onTap: _isSaving ? null : _save,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
