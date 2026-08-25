import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'dart:convert';

// ── Configuration ─────────────────────────────────────────────────────────────
//
// Replace _workerBaseUrl with the deployed Cloudflare Worker URL after running
//   `wrangler deploy`
// from the cloudflare_worker/ directory.
//
// Example: 'https://lake-sebu-menu-images.YOUR_SUBDOMAIN.workers.dev'
//
// During local development you can use `wrangler dev` and set this to:
//   'http://localhost:8787'

const String _workerBaseUrl =
    'https://lake-sebu-menu-images.lakesebu.workers.dev';

// ── Image constraints ─────────────────────────────────────────────────────────

/// Maximum file size accepted for upload (before compression).
const int kMaxRawImageBytes = 10 * 1024 * 1024; // 10 MB

/// Target long edge after resize. Images larger than this will be downscaled.
const int kMaxImageDimension = 1200; // px

/// WebP quality for food images. 85 gives excellent visual quality at ~60–80 KB
/// for a typical 1200×900 food photo.
const int kWebpQuality = 85;

/// Allowed MIME types the picker may return.
const List<String> kAllowedMimeTypes = ['image/jpeg', 'image/png', 'image/webp'];

// ── Result types ──────────────────────────────────────────────────────────────

/// The result of a successful presign + upload operation.
class ImageUploadResult {
  /// Public URL to store in Firestore (`img` or `heroImg` field).
  final String publicUrl;

  /// The R2 object key, stored so we can delete the old image later.
  final String objectKey;

  const ImageUploadResult({required this.publicUrl, required this.objectKey});
}

/// Strongly-typed errors surfaced to the UI layer.
enum ImageServiceError {
  notAuthenticated,
  noRestaurant,
  fileTooLarge,
  invalidFileType,
  presignFailed,
  uploadFailed,
  deleteFailed,
  processingFailed,
}

class MenuImageException implements Exception {
  final ImageServiceError error;
  final String message;
  const MenuImageException(this.error, this.message);

  @override
  String toString() => 'MenuImageException(${error.name}): $message';

  /// User-friendly message safe to show in the UI.
  String get userMessage {
    switch (error) {
      case ImageServiceError.notAuthenticated:
        return 'You must be signed in to upload images.';
      case ImageServiceError.noRestaurant:
        return 'Your account is not linked to a restaurant. Please contact support.';
      case ImageServiceError.fileTooLarge:
        return 'Image is too large. Please choose an image under 10 MB.';
      case ImageServiceError.invalidFileType:
        return 'Unsupported image format. Please use JPG, PNG, or WebP.';
      case ImageServiceError.presignFailed:
        return 'Could not prepare upload: $message';
      case ImageServiceError.uploadFailed:
        return 'Image upload failed: $message';
      case ImageServiceError.deleteFailed:
        return 'Could not remove the old image: $message';
      case ImageServiceError.processingFailed:
        return 'Could not process the image. Please try a different photo.';
    }
  }
}

// ── Service ───────────────────────────────────────────────────────────────────

/// Handles all Object Storage operations for menu item images.
///
/// Upload flow
/// ───────────
///   1. [processImage]   — resize + convert to WebP in memory.
///   2. [_presign]       — call Worker to get a signed PUT URL.
///   3. [_putToR2]       — PUT bytes directly to R2.
///   4. Returns [ImageUploadResult] with the public URL.
///
/// The Firestore update is performed by the caller (e.g. [OwnerMenuProvider])
/// so that the caller controls the transaction order:
///   upload → verify → update Firestore → delete old image.
///
/// No R2 credentials are present in this file.
class MenuImageService {
  MenuImageService._();
  static final MenuImageService instance = MenuImageService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Processes, uploads an image and returns the public URL + object key.
  ///
  /// [rawBytes]     — raw bytes of the selected file (from image_picker).
  /// [mimeType]     — MIME type reported by the picker (used for validation).
  /// [menuItemId]   — Firestore document ID for the menu item.
  /// [imageType]    — `'main'` or `'hero'`.
  ///
  /// Throws [MenuImageException] on any failure.
  Future<ImageUploadResult> uploadMenuImage({
    required Uint8List rawBytes,
    required String mimeType,
    required String menuItemId,
    required String imageType,
  }) async {
    assert(imageType == 'main' || imageType == 'hero');

    // 1. Validate raw input
    _validateFileType(mimeType);
    _validateFileSize(rawBytes.length);

    // 2. Compress / resize / convert to WebP
    final processedBytes = await _processImage(rawBytes);

    // 3. Get Firebase ID token (includes auth check)
    final idToken = await _getIdToken();

    // 4. Request presigned PUT URL from Worker
    final presignResult = await _presign(
      idToken: idToken,
      menuItemId: menuItemId,
      imageType: imageType,
    );

    // 5. PUT bytes directly to R2
    await _putToR2(
      uploadUrl: presignResult['uploadUrl'] as String,
      bytes: processedBytes,
    );

    return ImageUploadResult(
      publicUrl: presignResult['publicUrl'] as String,
      objectKey: presignResult['objectKey'] as String,
    );
  }

  /// Deletes an object from R2 via the Worker DELETE endpoint.
  ///
  /// [objectKey] — the R2 key returned by a previous [uploadMenuImage] call,
  /// or derived from the `img`/`heroImg` Firestore URL.
  ///
  /// Throws [MenuImageException] on failure. Callers should decide whether to
  /// surface or log this — a failed delete should NOT block the user's primary
  /// action (e.g. deleting the Firestore document).
  Future<void> deleteImage(String objectKey) async {
    if (objectKey.isEmpty) return;

    final idToken = await _getIdToken();

    try {
      final response = await http.delete(
        Uri.parse('$_workerBaseUrl/api/menu-images/delete'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'objectKey': objectKey}),
      );

      if (response.statusCode == 404) {
        // Object already gone — treat as success.
        return;
      }

      if (response.statusCode != 200) {
        final body = _tryDecodeJson(response.body);
        final msg = body?['error'] as String? ?? 'HTTP ${response.statusCode}';
        throw MenuImageException(ImageServiceError.deleteFailed, msg);
      }
    } on MenuImageException {
      rethrow;
    } catch (e) {
      throw MenuImageException(
          ImageServiceError.deleteFailed, 'Delete request failed: $e');
    }
  }

  /// Derives the R2 object key from a public URL produced by [uploadMenuImage].
  ///
  /// Returns null if the URL does not appear to be an R2-hosted image
  /// (e.g. it is a legacy URL from before Object Storage was introduced).
  /// Callers should skip deletion attempts when this returns null.
  String? objectKeyFromUrl(String publicUrl) {
    final uri = Uri.tryParse(publicUrl);
    if (uri == null) return null;
    final path = uri.path.startsWith('/') ? uri.path.substring(1) : uri.path;
    // Worker-served format: /img/restaurants/...
    if (path.startsWith('img/restaurants/')) {
      return path.substring('img/'.length);
    }
    // Legacy r2.dev format: /restaurants/...
    if (path.startsWith('restaurants/')) return path;
    return null;
  }

  // ── Image processing ───────────────────────────────────────────────────────

  /// Resizes and converts [rawBytes] to WebP.
  ///
  /// Runs in a Dart isolate via [compute] to avoid blocking the UI thread.
  Future<Uint8List> processImage(Uint8List rawBytes) => _processImage(rawBytes);

  static Future<Uint8List> _processImage(Uint8List rawBytes) async {
    try {
      // Offload CPU-heavy work off the main isolate
      final result = await compute(_encodeToWebP, rawBytes);
      if (result == null) {
        throw MenuImageException(
            ImageServiceError.processingFailed, 'Image encoding returned null');
      }
      return result;
    } on MenuImageException {
      rethrow;
    } catch (e) {
      throw MenuImageException(
          ImageServiceError.processingFailed, 'Image processing error: $e');
    }
  }

  /// Top-level function required by [compute] (must not be a closure).
  static Uint8List? _encodeToWebP(Uint8List rawBytes) {
    // Decode whatever format the picker returned
    final decoded = img.decodeImage(rawBytes);
    if (decoded == null) return null;

    // Resize if either dimension exceeds the limit
    final image = _resize(decoded);

    // Encode as WebP
    final encoded = img.encodeNamedImage('output.webp', image);
    return encoded == null ? null : Uint8List.fromList(encoded);
  }

  static img.Image _resize(img.Image source) {
    final w = source.width;
    final h = source.height;
    final longEdge = w > h ? w : h;

    if (longEdge <= kMaxImageDimension) return source;

    if (w >= h) {
      return img.copyResize(source, width: kMaxImageDimension,
          interpolation: img.Interpolation.linear);
    } else {
      return img.copyResize(source, height: kMaxImageDimension,
          interpolation: img.Interpolation.linear);
    }
  }

  // ── Validation ─────────────────────────────────────────────────────────────

  void _validateFileType(String mimeType) {
    final normalised = mimeType.toLowerCase().trim();
    if (!kAllowedMimeTypes.contains(normalised)) {
      throw MenuImageException(
        ImageServiceError.invalidFileType,
        'Unsupported MIME type: $mimeType',
      );
    }
  }

  void _validateFileSize(int byteCount) {
    if (byteCount > kMaxRawImageBytes) {
      throw MenuImageException(
        ImageServiceError.fileTooLarge,
        'File is ${(byteCount / (1024 * 1024)).toStringAsFixed(1)} MB; '
        'max is ${kMaxRawImageBytes ~/ (1024 * 1024)} MB.',
      );
    }
  }

  // ── Worker communication ───────────────────────────────────────────────────

  Future<Map<String, dynamic>> _presign({
    required String idToken,
    required String menuItemId,
    required String imageType,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_workerBaseUrl/api/menu-images/presign'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'menuItemId': menuItemId,
          'imageType': imageType,
        }),
      );

      if (response.statusCode != 200) {
        final body = _tryDecodeJson(response.body);
        final msg = body?['error'] as String? ?? 'HTTP ${response.statusCode}';
        throw MenuImageException(ImageServiceError.presignFailed, msg);
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return body;
    } on MenuImageException {
      rethrow;
    } catch (e) {
      throw MenuImageException(
          ImageServiceError.presignFailed, 'Presign request failed: $e');
    }
  }

  Future<void> _putToR2({
    required String uploadUrl,
    required Uint8List bytes,
  }) async {
    try {
      final response = await http.put(
        Uri.parse(uploadUrl),
        headers: {'Content-Type': 'image/webp'},
        body: bytes,
      );

      // R2 presigned PUT returns 200 on success
      if (response.statusCode != 200 && response.statusCode != 204) {
        final body = response.body.length > 300
            ? response.body.substring(0, 300)
            : response.body;
        throw MenuImageException(
          ImageServiceError.uploadFailed,
          'R2 PUT returned HTTP ${response.statusCode}: $body',
        );
      }
    } on MenuImageException {
      rethrow;
    } catch (e) {
      throw MenuImageException(
          ImageServiceError.uploadFailed, 'PUT to R2 failed: $e');
    }
  }

  // ── Auth helper ────────────────────────────────────────────────────────────

  Future<String> _getIdToken() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const MenuImageException(
          ImageServiceError.notAuthenticated, 'No authenticated user.');
    }
    try {
      // Force-refresh=false: reuse cached token unless it expires within 5 min.
      final token = await user.getIdToken(false);
      if (token == null || token.isEmpty) {
        throw const MenuImageException(
            ImageServiceError.notAuthenticated, 'Could not retrieve ID token.');
      }
      return token;
    } on MenuImageException {
      rethrow;
    } catch (e) {
      throw MenuImageException(
          ImageServiceError.notAuthenticated, 'Token retrieval failed: $e');
    }
  }

  // ── Utility ────────────────────────────────────────────────────────────────

  Map<String, dynamic>? _tryDecodeJson(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }
}
