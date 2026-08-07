import 'package:flutter/material.dart';
import '../constants.dart';
import 'app_image.dart';

// ── Shared: Featured Card ───────────────────────────────────────────────────

class FeaturedCard extends StatelessWidget {
  final Map<String, dynamic> dish;
  final VoidCallback onAdd;

  const FeaturedCard({super.key, required this.dish, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    // 1. Safely extract variables with null-coalescing (??) operators
    final String? tag = dish['tag'] as String?;
    final int? tagColorValue = dish['tagColor'] as int?;
    
    // Provide a fallback color (kBrand) if tagColor is missing
    final Color tagColor = tagColorValue != null ? Color(tagColorValue) : kBrand;
    final bool isGoldTag = tagColorValue == 0xFFF5C842;
    
    // Fallback for time if it's missing from the database
    final String time = dish['time'] as String? ?? '15–20 min';

    return Container(
      width: 200,
      decoration: BoxDecoration(
        color: kSurface,
        border: Border.all(color: kSurface2),
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 130,
            child: Stack(
              fit: StackFit.expand,
              children: [
                AppImage(
                  url: dish['img'] as String? ?? '',
                  fit: BoxFit.cover,
                ),
                
                // 2. Conditionally render the Tag UI ONLY if 'tag' is not null
                if (tag != null)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(color: tagColor, borderRadius: BorderRadius.circular(100)),
                      child: Text(
                        tag,
                        style: TextStyle(
                          color: isGoldTag ? kCanvas : Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  
                Positioned(
                  bottom: 10,
                  right: 10,
                  child: GestureDetector(
                    onTap: onAdd,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(color: kBrand, borderRadius: BorderRadius.circular(10)),
                      child: const Center(
                        child: Text('+',
                            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700, height: 1)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dish['name'] as String? ?? 'Unknown Item',
                  style: const TextStyle(color: kInk, fontSize: 14, fontWeight: FontWeight.w800),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  dish['restaurantName'] as String? ?? 'Unknown Restaurant',
                  style: const TextStyle(color: kMuted, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      formatPeso(dish['price'] as num?),
                      style: const TextStyle(color: kInk, fontSize: 16, fontWeight: FontWeight.w900),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, size: 13, color: kGold),
                        const SizedBox(width: 2),
                        Text('${dish['rating'] ?? 0.0}', style: const TextStyle(color: kGold, fontSize: 12, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 11, color: kMuted),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        time, // Uses our safe fallback variable
                        style: const TextStyle(color: kMuted, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared: Restaurant Card ─────────────────────────────────────────────────

class RestaurantCard extends StatelessWidget {
  final Map<String, dynamic> restaurant;

  const RestaurantCard({super.key, required this.restaurant});

  @override
  Widget build(BuildContext context) {
    final isFree = restaurant['fee'] == 'Free';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kSurface,
        border: Border.all(color: kSurface2),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: kSurface2, borderRadius: BorderRadius.circular(14)),
            clipBehavior: Clip.hardEdge,
            child: Image.network(
              restaurant['img'] as String,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) =>
                  progress == null ? child : Container(color: kSurface2),
              errorBuilder: (context, error, stack) => Container(color: kSurface2),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(restaurant['name'] as String, style: const TextStyle(color: kInk, fontSize: 14, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(restaurant['cuisine'] as String, style: const TextStyle(color: kMuted, fontSize: 12)),
                const SizedBox(height: 6),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Icon(Icons.star, size: 13, color: kGold),
                    const SizedBox(width: 2),
                    Text('${restaurant['rating']}', style: const TextStyle(color: kGold, fontSize: 12, fontWeight: FontWeight.w700)),
                    const Text(' · ', style: TextStyle(color: kMuted, fontSize: 11)),
                    const Icon(Icons.access_time, size: 12, color: kMuted),
                    const SizedBox(width: 2),
                    Text('${restaurant['time']}', style: const TextStyle(color: kMuted, fontSize: 12)),
                    const Text(' · ', style: TextStyle(color: kMuted, fontSize: 11)),
                    if (isFree) ...[
                      const Icon(Icons.check_circle, size: 12, color: kGreen),
                      const SizedBox(width: 2),
                    ],
                    Text(
                      isFree ? 'Free delivery' : '${restaurant['fee']} delivery',
                      style: TextStyle(color: isFree ? kGreen : kMuted, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: kBorder, size: 22),
        ],
      ),
    );
  }
}
