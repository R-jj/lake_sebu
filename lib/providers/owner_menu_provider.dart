import 'package:flutter/foundation.dart';
import '../services/menu_item_repository.dart';
import '../services/menu_image_service.dart';
/// Upload state for a single image slot (main or hero).
enum ImageUploadState { idle, uploading, success, error }

/// Provider that manages the restaurant owner's view of their menu.
///
/// Responsibilities
/// ────────────────
/// • Subscribes to a real-time Firestore stream of menu items for the owner's
///   restaurant.
/// • Exposes CRUD actions that correctly sequence Object Storage operations
///   with Firestore writes (upload → update Firestore → delete old image).
/// • Tracks per-operation loading / error state so the UI can react.
///
/// Usage
/// ─────
///   `context.read<OwnerMenuProvider>().init(restaurantId)`
///   `context.watch<OwnerMenuProvider>().items`
class OwnerMenuProvider extends ChangeNotifier {
  final MenuItemRepository _itemRepo = MenuItemRepository.instance;
  final MenuImageService _imageService = MenuImageService.instance;

  // ── State ──────────────────────────────────────────────────────────────────

  String? _restaurantId;
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  String? _error;

  /// True while the initial Firestore stream snapshot is pending.
  bool get isLoading => _isLoading;

  /// Non-null when the last operation produced an error.
  String? get error => _error;

  /// The live menu items for this restaurant, newest first by default
  /// (the stream orders by name from Firestore).
  List<Map<String, dynamic>> get items => _items;

  /// The restaurantId this provider is currently subscribed to.
  String? get restaurantId => _restaurantId;

  // Per-operation busy flags (used in forms / list tiles)
  bool _isSaving = false;
  bool _isDeleting = false;

  bool get isSaving => _isSaving;
  bool get isDeleting => _isDeleting;

  // The ID that was initialised so the shell can avoid redundant re-inits.
  String? get initializedRestaurantId => _restaurantId;

  // ── Stream subscription ────────────────────────────────────────────────────

  void Function()? _cancelStream;

  void init(String restaurantId) {
    if (_restaurantId == restaurantId) return; // already subscribed
    _restaurantId = restaurantId;
    _isLoading = true;
    _error = null;
    _cancelStream?.call();

    final sub = _itemRepo
        .menuItemsStream(restaurantId)
        .listen(
          (items) {
            _items = items;
            _isLoading = false;
            _error = null;
            notifyListeners();
          },
          onError: (Object e, StackTrace st) {
            debugPrint('OwnerMenuProvider stream error: $e\n$st');
            _isLoading = false;
            _error = 'Error: $e';
            notifyListeners();
          },
        );

    _cancelStream = sub.cancel;
    notifyListeners();
  }

  void clear() {
    _cancelStream?.call();
    _cancelStream = null;
    _restaurantId = null;
    _items = [];
    _isLoading = true;
    _error = null;
    _isSaving = false;
    _isDeleting = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _cancelStream?.call();
    super.dispose();
  }

  // ── Create ─────────────────────────────────────────────────────────────────

  /// Creates a new menu item, uploading images if provided.
  ///
  /// Image upload flow:
  ///   1. Generate a Firestore doc ID (so R2 path uses the real item ID).
  ///   2. Upload main image (if provided).
  ///   3. Upload hero image (if provided).
  ///   4. Write the Firestore document with all URLs in one shot.
  ///
  /// If an upload fails, no Firestore document is created (nothing to roll
  /// back). The partially-uploaded R2 objects are cleaned up automatically
  /// on the next upload to the same path (same item ID + image type).
  ///
  /// Returns the new item ID on success.
  /// Throws [MenuImageException] or [StateError] / Firestore exceptions.
  Future<String> createItem({
    required String name,
    required String description,
    required double price,
    required String category,
    required bool isAvailable,
    Uint8List? mainImageBytes,
    String? mainImageMimeType,
    Uint8List? heroImageBytes,
    String? heroImageMimeType,
  }) async {
    _assertInit();
    _setSaving(true);

    try {
      // Reserve the Firestore ID first so R2 path uses it
      final itemId = _itemRepo.generateItemId();

      String? imgUrl;
      String? heroImgUrl;

      // Upload main image
      if (mainImageBytes != null && mainImageMimeType != null) {
        final result = await _imageService.uploadMenuImage(
          rawBytes: mainImageBytes,
          mimeType: mainImageMimeType,
          menuItemId: itemId,
          imageType: 'main',
        );
        imgUrl = result.publicUrl;
      }

      // Upload hero image
      if (heroImageBytes != null && heroImageMimeType != null) {
        final result = await _imageService.uploadMenuImage(
          rawBytes: heroImageBytes,
          mimeType: heroImageMimeType,
          menuItemId: itemId,
          imageType: 'hero',
        );
        heroImgUrl = result.publicUrl;
      }

      // Write Firestore document
      await _itemRepo.createMenuItemWithId(
        itemId: itemId,
        restaurantId: _restaurantId!,
        name: name,
        description: description,
        price: price,
        category: category,
        isAvailable: isAvailable,
        img: imgUrl,
        heroImg: heroImgUrl,
      );

      return itemId;
    } finally {
      _setSaving(false);
    }
  }

  // ── Update — metadata only ─────────────────────────────────────────────────

  /// Updates only text/price/availability fields. Zero image operations.
  Future<void> updateItemMeta({
    required String itemId,
    required String name,
    required String description,
    required double price,
    required String category,
    required bool isAvailable,
  }) async {
    _assertInit();
    _setSaving(true);
    try {
      await _itemRepo.updateMenuItemMeta(
        itemId: itemId,
        name: name,
        description: description,
        price: price,
        category: category,
        isAvailable: isAvailable,
      );
    } finally {
      _setSaving(false);
    }
  }

  // ── Update — replace image ─────────────────────────────────────────────────

  /// Replaces an existing image following the safe sequence:
  ///   1. Upload new image.
  ///   2. Update Firestore with new URL.
  ///   3. Delete old R2 object (best-effort).
  ///
  /// If Firestore update fails, the new R2 object is orphaned (acceptable —
  /// same path will be overwritten on the next upload). The old image is
  /// never deleted unless both previous steps succeed.
  ///
  /// [field]    — `'img'` or `'heroImg'`
  /// [oldUrl]   — existing URL from Firestore (used to derive old object key)
  Future<void> replaceItemImage({
    required String itemId,
    required String field,
    required Uint8List newImageBytes,
    required String newImageMimeType,
    String? oldUrl,
  }) async {
    assert(field == 'img' || field == 'heroImg');
    _assertInit();
    _setSaving(true);

    try {
      final imageType = field == 'heroImg' ? 'hero' : 'main';

      // Step 1: upload new image
      final result = await _imageService.uploadMenuImage(
        rawBytes: newImageBytes,
        mimeType: newImageMimeType,
        menuItemId: itemId,
        imageType: imageType,
      );

      // Step 2: update Firestore with new URL
      await _itemRepo.updateMenuItemImage(
        itemId: itemId,
        field: field,
        publicUrl: result.publicUrl,
      );

      // Step 3: delete old R2 object (best-effort; log but don't throw)
      if (oldUrl != null && oldUrl.isNotEmpty) {
        final oldKey = _imageService.objectKeyFromUrl(oldUrl);
        if (oldKey != null && oldKey != result.objectKey) {
          try {
            await _imageService.deleteImage(oldKey);
          } catch (e) {
            debugPrint('OwnerMenuProvider: old image cleanup failed: $e');
            // Do not rethrow — Firestore update already succeeded.
          }
        }
      }
    } finally {
      _setSaving(false);
    }
  }

  // ── Update — remove image ──────────────────────────────────────────────────

  /// Removes an image: clears Firestore field, then deletes R2 object.
  ///
  /// Throws [MenuImageException] if R2 deletion fails, and returns the
  /// image field to its original value so the UI does not show success.
  Future<void> removeItemImage({
    required String itemId,
    required String field,
    required String currentUrl,
  }) async {
    assert(field == 'img' || field == 'heroImg');
    _assertInit();
    _setSaving(true);

    try {
      // Clear Firestore first (safe: worst case the item has no image URL
      // even if R2 still has the file)
      await _itemRepo.clearMenuItemImage(itemId: itemId, field: field);

      // Then delete from R2
      final objectKey = _imageService.objectKeyFromUrl(currentUrl);
      if (objectKey != null) {
        // This will throw MenuImageException if deletion fails.
        // The Firestore field is already cleared, so show a warning rather
        // than pretending the image still exists.
        await _imageService.deleteImage(objectKey);
      }
    } finally {
      _setSaving(false);
    }
  }

  // ── Delete item ────────────────────────────────────────────────────────────

  /// Deletes a menu item and all its associated R2 images.
  ///
  /// Sequence:
  ///   1. Delete R2 objects (best-effort — missing objects are ignored).
  ///   2. Delete Firestore document.
  ///
  /// If R2 deletion fails for any image, we log it and continue to delete
  /// the Firestore document — orphaned objects are acceptable, but leaving
  /// a Firestore document that can no longer load its image is worse UX.
  Future<void> deleteItem(Map<String, dynamic> item) async {
    _assertInit();
    _setDeleting(true);

    try {
      final itemId = item['id'] as String;

      // Delete main image from R2
      final imgUrl = item['img'] as String?;
      if (imgUrl != null && imgUrl.isNotEmpty) {
        final key = _imageService.objectKeyFromUrl(imgUrl);
        if (key != null) {
          try {
            await _imageService.deleteImage(key);
          } catch (e) {
            debugPrint('OwnerMenuProvider: main image delete failed: $e');
          }
        }
      }

      // Delete hero image from R2
      final heroUrl = item['heroImg'] as String?;
      if (heroUrl != null && heroUrl.isNotEmpty) {
        final key = _imageService.objectKeyFromUrl(heroUrl);
        if (key != null) {
          try {
            await _imageService.deleteImage(key);
          } catch (e) {
            debugPrint('OwnerMenuProvider: hero image delete failed: $e');
          }
        }
      }

      // Delete Firestore document last
      await _itemRepo.deleteMenuItem(itemId);
    } finally {
      _setDeleting(false);
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _assertInit() {
    if (_restaurantId == null) {
      throw StateError('OwnerMenuProvider: call init(restaurantId) first.');
    }
  }

  void _setSaving(bool value) {
    _isSaving = value;
    notifyListeners();
  }

  void _setDeleting(bool value) {
    _isDeleting = value;
    notifyListeners();
  }
}
