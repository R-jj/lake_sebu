import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants.dart';
import '../providers/menu_providers.dart';
import '../providers/user_profile_provider.dart';
import '../widgets/app_image.dart';
import '_sub_page_shell.dart';

class FavouritesPage extends StatelessWidget {
  final VoidCallback onBack;
  final void Function(String id) onViewItem;

  const FavouritesPage(
      {super.key, required this.onBack, required this.onViewItem});

  @override
  Widget build(BuildContext context) {
    final menuProvider = context.watch<MenuProvider>();
    final profileProvider = context.watch<UserProfileProvider>();

    final allItems = menuProvider.allItems;
    final favIds = profileProvider.favouriteIds;
    final isLoading =
        menuProvider.isLoading || profileProvider.favouritesLoading;

    // Filter to items that are in the user's favourites set.
    final saved = allItems
        .where((item) => favIds.contains('${item['id']}'))
        .toList();

    return SubPageShell(
      title: 'Favourites',
      subtitle:
          '${saved.length} saved item${saved.length != 1 ? 's' : ''}',
      onBack: onBack,
      child: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: kBrand))
          : saved.isEmpty
              ? _buildEmpty()
              : ListView.separated(
                  padding:
                      const EdgeInsets.fromLTRB(20, 16, 20, 28),
                  itemCount: saved.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, i) => _FavTile(
                    item: saved[i],
                    onViewItem: onViewItem,
                    onRemove: () => _removeFavourite(
                        context, '${saved[i]['id']}'),
                  ),
                ),
    );
  }

  Future<void> _removeFavourite(
      BuildContext context, String itemId) async {
    final err = await context
        .read<UserProfileProvider>()
        .removeFavourite(itemId);
    if (err != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err),
        backgroundColor: kRed,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Text('💔', style: TextStyle(fontSize: 52)),
            SizedBox(height: 12),
            Text('No favourites yet',
                style: TextStyle(
                    color: kInk,
                    fontWeight: FontWeight.w700,
                    fontSize: 16)),
            SizedBox(height: 6),
            Text('Tap ❤️ on any dish to save it here',
                style: TextStyle(color: kMuted, fontSize: 13),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ── Favourite tile ────────────────────────────────────────────────────────────

class _FavTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final void Function(String id) onViewItem;
  final VoidCallback onRemove;

  const _FavTile(
      {required this.item,
      required this.onViewItem,
      required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final img =
        item['heroImg'] as String? ?? item['img'] as String? ?? '';
    final time = item['time'] as String? ?? '—';

    return Container(
      decoration: BoxDecoration(
        color: kSurface,
        border: Border.all(color: kSurface2),
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.hardEdge,
      child: Row(
        children: [
          GestureDetector(
            onTap: () => onViewItem('${item['id']}'),
            child: SizedBox(
              width: 90,
              height: 110,
              child: AppImage.thumb(url: img, width: 90, height: 110),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item['name'] as String? ?? '',
                      style: const TextStyle(
                          color: kInk,
                          fontWeight: FontWeight.w800,
                          fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(
                      item['restaurantName'] as String? ??
                          item['restaurant'] as String? ??
                          '',
                      style: const TextStyle(
                          color: kMuted, fontSize: 12)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.star,
                          size: 13, color: kGold),
                      const SizedBox(width: 3),
                      Text('${item['rating'] ?? '—'}',
                          style: const TextStyle(
                              color: kGold,
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(width: 8),
                      const Icon(Icons.access_time,
                          size: 12, color: kMuted),
                      const SizedBox(width: 3),
                      Text(time,
                          style: const TextStyle(
                              color: kMuted, fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                          formatPeso(
                              item['price'] as num?),
                          style: const TextStyle(
                              color: kBrand,
                              fontWeight: FontWeight.w900,
                              fontSize: 15)),
                      GestureDetector(
                        onTap: onRemove,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: kRed
                                    .withValues(alpha: 0.25)),
                            borderRadius:
                                BorderRadius.circular(10),
                          ),
                          child: const Text('Remove',
                              style: TextStyle(
                                  color: kRed,
                                  fontSize: 12,
                                  fontWeight:
                                      FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
