import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../constants.dart';

/// Sizes used to cap the decoded bitmap in memory.
/// Keeping these tight prevents Jetsam OOM kills on iOS.
class _MemCap {
  static const int thumb = 200;   // 60–100 px slots
  static const int card  = 400;   // 130–252 px cards
  static const int hero  = 800;   // full-width hero images
}

/// Drop-in replacement for [Image.network] with:
/// - Disk + memory caching via [CachedNetworkImage]
/// - [memCacheWidth] / [memCacheHeight] bounds to cap RAM usage
/// - Shimmer-free neutral placeholder that matches [kSurface2]
/// - Silent error fallback (same neutral box)
class AppImage extends StatelessWidget {
  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;

  /// Pixel cap for the in-memory bitmap. Defaults to [_MemCap.card].
  /// Pass a [_MemCap] constant or any positive integer.
  final int memCacheWidth;
  final int memCacheHeight;

  const AppImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.memCacheWidth  = _MemCap.card,
    this.memCacheHeight = _MemCap.card,
  });

  /// Thumbnail variant — tight memory cap for small slots (≤ 100 px).
  const AppImage.thumb({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  })  : memCacheWidth  = _MemCap.thumb,
        memCacheHeight = _MemCap.thumb;

  /// Hero variant — wider cap for full-width banner images.
  const AppImage.hero({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  })  : memCacheWidth  = _MemCap.hero,
        memCacheHeight = _MemCap.hero;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return _placeholder();

    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      width: width,
      height: height,
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
      placeholder: (_, __) => _placeholder(),
      errorWidget: (_, __, ___) => _placeholder(),
    );
  }

  Widget _placeholder() => Container(
        width: width,
        height: height,
        color: kSurface2,
      );
}
