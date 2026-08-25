import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../constants.dart';
import '../services/menu_image_service.dart';

/// The current state of one image slot in the form.
class ImageSlotState {
  /// Bytes selected from gallery/camera (not yet uploaded). Non-null while
  /// the user has picked an image that has not been saved yet.
  final Uint8List? pendingBytes;

  /// MIME type reported by the picker for [pendingBytes].
  final String? pendingMimeType;

  /// The URL already saved in Firestore (existing image).
  /// Null for a brand-new item with no image.
  final String? existingUrl;

  /// Whether the user has explicitly requested removal of the existing image.
  final bool markedForRemoval;

  const ImageSlotState({
    this.pendingBytes,
    this.pendingMimeType,
    this.existingUrl,
    this.markedForRemoval = false,
  });

  /// True when there is something to display (existing image or pending pick).
  bool get hasImage =>
      (existingUrl != null && existingUrl!.isNotEmpty && !markedForRemoval) ||
      pendingBytes != null;

  /// True when a new image has been picked and needs to be uploaded on save.
  bool get hasPendingUpload => pendingBytes != null;

  ImageSlotState copyWith({
    Uint8List? pendingBytes,
    String? pendingMimeType,
    String? existingUrl,
    bool? markedForRemoval,
    bool clearPending = false,
  }) =>
      ImageSlotState(
        pendingBytes: clearPending ? null : (pendingBytes ?? this.pendingBytes),
        pendingMimeType:
            clearPending ? null : (pendingMimeType ?? this.pendingMimeType),
        existingUrl: existingUrl ?? this.existingUrl,
        markedForRemoval: markedForRemoval ?? this.markedForRemoval,
      );
}

/// A self-contained image picker widget for a single menu-item image slot.
///
/// Renders:
///   • An empty dashed placeholder when no image is present.
///   • A local preview (from [ImageSlotState.pendingBytes]) after picking.
///   • The existing remote image (via [ImageSlotState.existingUrl]) for edits.
///   • Overlay action buttons: replace / remove.
///   • An upload progress indicator while [isUploading] is true.
///
/// State is managed externally — the parent passes [state] and receives
/// changes via [onChanged]. The widget never initiates uploads itself;
/// it only picks files and previews them.
class MenuImagePicker extends StatelessWidget {
  final String label;
  final ImageSlotState state;
  final bool isUploading;
  final ValueChanged<ImageSlotState> onChanged;

  /// Optional hint shown below the empty placeholder.
  final String? hint;

  const MenuImagePicker({
    super.key,
    required this.label,
    required this.state,
    required this.isUploading,
    required this.onChanged,
  }) : hint = null;

  const MenuImagePicker.withHint({
    super.key,
    required this.label,
    required this.state,
    required this.isUploading,
    required this.onChanged,
    required this.hint,
  });

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label row
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                color: kInk,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (state.hasPendingUpload) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: kBrand.withAlpha(30),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: const Text(
                  'New image selected',
                  style: TextStyle(
                      color: kBrand,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),

        // Image area
        _buildImageArea(context),

        if (hint != null && !state.hasImage) ...[
          const SizedBox(height: 6),
          Text(hint!,
              style: const TextStyle(color: kMuted, fontSize: 12)),
        ],
      ],
    );
  }

  Widget _buildImageArea(BuildContext context) {
    return Stack(
      children: [
        // Main image container
        GestureDetector(
          onTap: isUploading ? null : () => _pickImage(context),
          child: Container(
            width: double.infinity,
            height: 180,
            decoration: BoxDecoration(
              color: kSurface2,
              borderRadius: BorderRadius.circular(16),
              border: state.hasImage
                  ? null
                  : Border.all(
                      color: kBorder,
                      width: 1.5,
                      strokeAlign: BorderSide.strokeAlignInside,
                    ),
            ),
            clipBehavior: Clip.hardEdge,
            child: _buildImageContent(),
          ),
        ),

        // Upload progress overlay
        if (isUploading)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xCC0F0D0C),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                        color: kBrand, strokeWidth: 2.5),
                  ),
                  SizedBox(height: 10),
                  Text('Uploading image...',
                      style: TextStyle(color: kInk, fontSize: 13)),
                ],
              ),
            ),
          ),

        // Action buttons overlay (top-right) — only when not uploading
        if (!isUploading && state.hasImage)
          Positioned(
            top: 10,
            right: 10,
            child: Row(
              children: [
                _ActionButton(
                  icon: Icons.swap_horiz_rounded,
                  tooltip: 'Replace image',
                  onTap: () => _pickImage(context),
                ),
                const SizedBox(width: 8),
                _ActionButton(
                  icon: Icons.delete_outline_rounded,
                  tooltip: 'Remove image',
                  onTap: () => _requestRemoval(),
                  destructive: true,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildImageContent() {
    // Priority: pending pick > existing remote image > empty placeholder
    if (state.pendingBytes != null) {
      return Image.memory(
        state.pendingBytes!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: 180,
      );
    }

    if (state.existingUrl != null &&
        state.existingUrl!.isNotEmpty &&
        !state.markedForRemoval) {
      return Image.network(
        state.existingUrl!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: 180,
        errorBuilder: (_, __, ___) => _emptyPlaceholder(),
      );
    }

    return _emptyPlaceholder();
  }

  Widget _emptyPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.add_photo_alternate_outlined,
              color: kMuted, size: 24),
        ),
        const SizedBox(height: 10),
        const Text('Tap to add image',
            style: TextStyle(color: kMuted, fontSize: 13)),
      ],
    );
  }

  // ── Picking ────────────────────────────────────────────────────────────────

  Future<void> _pickImage(BuildContext context) async {
    // Show source sheet
    final source = await _showSourceSheet(context);
    if (source == null) return;

    final picker = ImagePicker();
    XFile? file;
    try {
      file = await picker.pickImage(
        source: source,
        // imageQuality is NOT set here — we do our own WebP compression
        // in MenuImageService._processImage so we have full control.
        maxWidth: 2400,
        maxHeight: 2400,
      );
    } catch (_) {
      // User denied permissions or picker failed — silently ignore.
      return;
    }

    if (file == null) return;

    // Read bytes
    final bytes = await file.readAsBytes();

    // Validate size before even showing a preview
    if (bytes.length > kMaxRawImageBytes) {
      if (context.mounted) {
        _showError(context,
            'Image is too large (${(bytes.length / (1024 * 1024)).toStringAsFixed(1)} MB). '
            'Please choose an image under 10 MB.');
      }
      return;
    }

    // Derive MIME type — image_picker provides extension-based type
    final mimeType = _mimeFromPath(file.path);
    if (!kAllowedMimeTypes.contains(mimeType)) {
      if (context.mounted) {
        _showError(context,
            'Unsupported format. Please use a JPG, PNG, or WebP image.');
      }
      return;
    }

    onChanged(state.copyWith(
      pendingBytes: bytes,
      pendingMimeType: mimeType,
      markedForRemoval: false,
    ));
  }

  Future<ImageSource?> _showSourceSheet(BuildContext context) {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: kSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: kBorder,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
              const Text(
                'Choose image source',
                style: TextStyle(
                    color: kInk, fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              _SourceTile(
                icon: Icons.photo_library_outlined,
                label: 'Photo Library',
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              const SizedBox(height: 8),
              _SourceTile(
                icon: Icons.camera_alt_outlined,
                label: 'Camera',
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

  void _requestRemoval() {
    onChanged(state.copyWith(
      markedForRemoval: true,
      clearPending: true,
    ));
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static String _mimeFromPath(String path) {
    final ext = path.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg'; // fallback; validation will reject if truly bad
    }
  }

  static void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: kRed,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }
}

// ── Private sub-widgets ────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool destructive;

  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xCC0F0D0C),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0x33FFFFFF)),
          ),
          child: Icon(
            icon,
            size: 17,
            color: destructive ? kRed : kInk,
          ),
        ),
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SourceTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: kSurface2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBorder),
        ),
        child: Row(
          children: [
            Icon(icon, color: kMuted, size: 20),
            const SizedBox(width: 12),
            Text(label,
                style: const TextStyle(
                    color: kInk, fontSize: 15, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
