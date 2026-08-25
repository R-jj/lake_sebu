import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../constants.dart';
import '../../providers/owner_menu_provider.dart';
import '../../services/menu_image_service.dart';
import '../../widgets/menu_image_picker.dart';

/// Unified Add / Edit screen for a menu item.
///
/// Add mode:   [existingItem] == null
/// Edit mode:  [existingItem] is the raw Firestore map for the item.
///
/// Upload logic
/// ────────────
/// • Picking an image sets [ImageSlotState.pendingBytes]; no upload happens.
/// • On Save, [OwnerMenuProvider] handles the upload sequence:
///     - Add:  upload image(s) → createMenuItemWithId
///     - Edit: if image changed → replaceItemImage (upload → Firestore → delete old)
///             if image removed → removeItemImage
///             if image unchanged → updateMenuItemMeta only (0 uploads)
class OwnerAddEditMenuItemPage extends StatefulWidget {
  final Map<String, dynamic>? existingItem;

  const OwnerAddEditMenuItemPage({super.key, this.existingItem});

  bool get isEditing => existingItem != null;

  @override
  State<OwnerAddEditMenuItemPage> createState() =>
      _OwnerAddEditMenuItemPageState();
}

class _OwnerAddEditMenuItemPageState extends State<OwnerAddEditMenuItemPage> {
  // ── Form ───────────────────────────────────────────────────────────────────

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _categoryCtrl;
  bool _isAvailable = true;

  // ── Image slots ────────────────────────────────────────────────────────────

  late ImageSlotState _mainImage;
  late ImageSlotState _heroImage;

  // Separate upload-in-progress flags per slot for the UI
  bool _mainUploading = false;
  bool _heroUploading = false;

  // ── General saving state ───────────────────────────────────────────────────

  bool _isSaving = false;
  String? _errorMessage;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    final item = widget.existingItem;

    _nameCtrl = TextEditingController(text: item?['name'] as String? ?? '');
    _descCtrl =
        TextEditingController(text: item?['description'] as String? ?? '');
    _priceCtrl = TextEditingController(
      text: item != null
          ? (item['price'] as num?)?.toStringAsFixed(2) ?? ''
          : '',
    );
    _categoryCtrl =
        TextEditingController(text: item?['category'] as String? ?? '');
    _isAvailable = item?['isAvailable'] as bool? ?? true;

    // Pre-fill image slots with existing URLs
    _mainImage = ImageSlotState(existingUrl: item?['img'] as String?);
    _heroImage = ImageSlotState(existingUrl: item?['heroImg'] as String?);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _categoryCtrl.dispose();
    super.dispose();
  }

  // ── Save ───────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    // Validate form fields
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // Disable save button and clear previous error
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final provider = context.read<OwnerMenuProvider>();
    final name = _nameCtrl.text.trim();
    final description = _descCtrl.text.trim();
    final price = double.tryParse(_priceCtrl.text.trim()) ?? 0.0;
    final category = _categoryCtrl.text.trim();

    try {
      if (!widget.isEditing) {
        // ── ADD ─────────────────────────────────────────────────────────────
        setState(() {
          _mainUploading = _mainImage.hasPendingUpload;
          _heroUploading = _heroImage.hasPendingUpload;
        });

        await provider.createItem(
          name: name,
          description: description,
          price: price,
          category: category,
          isAvailable: _isAvailable,
          mainImageBytes: _mainImage.pendingBytes,
          mainImageMimeType: _mainImage.pendingMimeType,
          heroImageBytes: _heroImage.pendingBytes,
          heroImageMimeType: _heroImage.pendingMimeType,
        );

        if (mounted) Navigator.of(context).pop();
      } else {
        // ── EDIT ────────────────────────────────────────────────────────────
        final itemId = widget.existingItem!['id'] as String;

        // Determine what actually changed
        final metaChanged = _metaChanged();
        final mainChanged = _mainImage.hasPendingUpload;
        final heroChanged = _heroImage.hasPendingUpload;
        final mainRemoved = _mainImage.markedForRemoval &&
            (widget.existingItem!['img'] as String? ?? '').isNotEmpty;
        final heroRemoved = _heroImage.markedForRemoval &&
            (widget.existingItem!['heroImg'] as String? ?? '').isNotEmpty;

        // Update metadata (if anything changed)
        if (metaChanged) {
          await provider.updateItemMeta(
            itemId: itemId,
            name: name,
            description: description,
            price: price,
            category: category,
            isAvailable: _isAvailable,
          );
        }

        // Replace / upload main image
        if (mainChanged) {
          setState(() => _mainUploading = true);
          await provider.replaceItemImage(
            itemId: itemId,
            field: 'img',
            newImageBytes: _mainImage.pendingBytes!,
            newImageMimeType: _mainImage.pendingMimeType!,
            oldUrl: widget.existingItem!['img'] as String?,
          );
          setState(() => _mainUploading = false);
        }

        // Replace / upload hero image
        if (heroChanged) {
          setState(() => _heroUploading = true);
          await provider.replaceItemImage(
            itemId: itemId,
            field: 'heroImg',
            newImageBytes: _heroImage.pendingBytes!,
            newImageMimeType: _heroImage.pendingMimeType!,
            oldUrl: widget.existingItem!['heroImg'] as String?,
          );
          setState(() => _heroUploading = false);
        }

        // Remove main image
        if (mainRemoved && !mainChanged) {
          final oldUrl = widget.existingItem!['img'] as String;
          await provider.removeItemImage(
            itemId: itemId,
            field: 'img',
            currentUrl: oldUrl,
          );
        }

        // Remove hero image
        if (heroRemoved && !heroChanged) {
          final oldUrl = widget.existingItem!['heroImg'] as String;
          await provider.removeItemImage(
            itemId: itemId,
            field: 'heroImg',
            currentUrl: oldUrl,
          );
        }

        if (mounted) Navigator.of(context).pop();
      }
    } on MenuImageException catch (e) {
      setState(() {
        _isSaving = false;
        _mainUploading = false;
        _heroUploading = false;
        _errorMessage = e.userMessage;
      });
    } catch (e) {
      setState(() {
        _isSaving = false;
        _mainUploading = false;
        _heroUploading = false;
        _errorMessage = 'Something went wrong. Please try again.';
      });
    }
  }

  /// Returns true if any text/price/availability field differs from the
  /// original. Used to skip unnecessary Firestore writes.
  bool _metaChanged() {
    if (!widget.isEditing) return true;
    final item = widget.existingItem!;
    final priceVal = double.tryParse(_priceCtrl.text.trim()) ?? 0.0;
    return _nameCtrl.text.trim() != (item['name'] as String? ?? '') ||
        _descCtrl.text.trim() != (item['description'] as String? ?? '') ||
        priceVal != (item['price'] as num?)?.toDouble() ||
        _categoryCtrl.text.trim() != (item['category'] as String? ?? '') ||
        _isAvailable != (item['isAvailable'] as bool? ?? true);
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isUploading = _mainUploading || _heroUploading || _isSaving;

    return Scaffold(
      backgroundColor: kCanvas,
      appBar: AppBar(
        backgroundColor: kCanvas,
        elevation: 0,
        leading: GestureDetector(
          onTap: isUploading ? null : () => Navigator.of(context).pop(),
          child: const Icon(Icons.chevron_left, color: kInk, size: 26),
        ),
        title: Text(
          widget.isEditing ? 'Edit Menu Item' : 'Add Menu Item',
          style: kSerif.copyWith(
            color: kInk,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          // Save button in app bar
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _SaveButton(
              isLoading: isUploading,
              onTap: isUploading ? null : _save,
            ),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Error banner ───────────────────────────────────────────
                if (_errorMessage != null)
                  _ErrorBanner(
                    message: _errorMessage!,
                    onDismiss: () => setState(() => _errorMessage = null),
                  ),

                // ── Main Image ─────────────────────────────────────────────
                MenuImagePicker.withHint(
                  label: 'Main Image',
                  state: _mainImage,
                  isUploading: _mainUploading,
                  onChanged: (s) => setState(() => _mainImage = s),
                  hint: 'Used in menu cards and search results.',
                ),
                const SizedBox(height: 20),

                // ── Hero Image ─────────────────────────────────────────────
                MenuImagePicker.withHint(
                  label: 'Hero Image  (optional)',
                  state: _heroImage,
                  isUploading: _heroUploading,
                  onChanged: (s) => setState(() => _heroImage = s),
                  hint:
                      'Full-screen banner shown on the item detail page. Falls back to Main Image if absent.',
                ),
                const SizedBox(height: 28),

                // ── Text fields ────────────────────────────────────────────
                _SectionLabel('Item details'),
                const SizedBox(height: 12),

                _Field(
                  controller: _nameCtrl,
                  label: 'Name',
                  hint: 'e.g. Crispy Chicken Burger',
                  enabled: !isUploading,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Name is required'
                      : null,
                ),
                const SizedBox(height: 12),

                _Field(
                  controller: _descCtrl,
                  label: 'Description',
                  hint: 'Short description of the dish...',
                  maxLines: 3,
                  enabled: !isUploading,
                ),
                const SizedBox(height: 12),

                _Field(
                  controller: _priceCtrl,
                  label: 'Price (₱)',
                  hint: '0.00',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                  enabled: !isUploading,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Price is required';
                    }
                    final parsed = double.tryParse(v.trim());
                    if (parsed == null || parsed < 0) {
                      return 'Enter a valid price';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                _CategoryField(
                  controller: _categoryCtrl,
                  enabled: !isUploading,
                ),
                const SizedBox(height: 20),

                // ── Availability toggle ────────────────────────────────────
                _AvailabilityToggle(
                  value: _isAvailable,
                  enabled: !isUploading,
                  onChanged: (v) => setState(() => _isAvailable = v),
                ),
                const SizedBox(height: 32),

                // ── Bottom save button ─────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: _SaveButton(
                    isLoading: isUploading,
                    onTap: isUploading ? null : _save,
                    large: true,
                    label: widget.isEditing ? 'Save changes' : 'Add to menu',
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

// ── Form field widgets ─────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: kSerif.copyWith(
            color: kInk, fontSize: 16, fontWeight: FontWeight.w700),
      );
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final int maxLines;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final bool enabled;
  final String? Function(String?)? validator;

  const _Field({
    required this.controller,
    required this.label,
    this.hint,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.enabled = true,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: kInk, fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          enabled: enabled,
          validator: validator,
          style: const TextStyle(color: kInk, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
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
        ),
      ],
    );
  }
}

class _CategoryField extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;

  const _CategoryField({required this.controller, required this.enabled});

  @override
  Widget build(BuildContext context) {
    // Show existing categories from constants as quick-picks
    final categories = kCategoryIcons.keys
        .where((k) => k != 'All')
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Category',
            style: TextStyle(
                color: kInk, fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          enabled: enabled,
          style: const TextStyle(color: kInk, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'e.g. Burgers, Pizza, Mains...',
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
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: kBorder.withAlpha(100)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Quick-pick chips
        SizedBox(
          height: 32,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (_, i) {
              final cat = categories[i];
              final selected = controller.text.trim() == cat;
              return GestureDetector(
                onTap: enabled
                    ? () {
                        controller.text = cat;
                        // Move cursor to end
                        controller.selection = TextSelection.fromPosition(
                          TextPosition(offset: cat.length),
                        );
                      }
                    : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: selected ? kBrand : kSurface2,
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                      color: selected ? kBrand : kBorder,
                    ),
                  ),
                  child: Text(
                    cat,
                    style: TextStyle(
                      color: selected ? Colors.white : kMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AvailabilityToggle extends StatelessWidget {
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _AvailabilityToggle({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Available',
                  style: TextStyle(
                      color: kInk,
                      fontSize: 14,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  value
                      ? 'Item is visible and orderable.'
                      : 'Item is hidden from customers.',
                  style:
                      const TextStyle(color: kMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: enabled ? onChanged : null,
            activeThumbColor: kBrand,
            activeTrackColor: kBrand.withAlpha(80),
            inactiveThumbColor: kMuted,
            inactiveTrackColor: kSurface2,
          ),
        ],
      ),
    );
  }
}

// ── Save button ────────────────────────────────────────────────────────────────

class _SaveButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onTap;
  final bool large;
  final String label;

  const _SaveButton({
    required this.isLoading,
    required this.onTap,
    this.large = false,
    this.label = 'Save',
  });

  @override
  Widget build(BuildContext context) {
    if (large) {
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
                        color: Colors.white, strokeWidth: 2),
                  )
                : Text(label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
          ),
        ),
      );
    }

    // Compact version for AppBar
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: onTap != null ? kBrand : kBrand.withAlpha(120),
          borderRadius: BorderRadius.circular(8),
        ),
        child: isLoading
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              )
            : Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
      ),
    );
  }
}

// ── Error banner ───────────────────────────────────────────────────────────────

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
            child: Text(message,
                style: const TextStyle(color: kRed, fontSize: 13)),
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
