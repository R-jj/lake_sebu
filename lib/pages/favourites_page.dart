import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants.dart';
import '../providers/menu_providers.dart';
import '../widgets/app_image.dart';
import '_sub_page_shell.dart';

class FavouritesPage extends StatefulWidget {
  final VoidCallback onBack;
  final void Function(String id) onViewItem;

  const FavouritesPage({super.key, required this.onBack, required this.onViewItem});

  @override
  State<FavouritesPage> createState() => _FavouritesPageState();
}

class _FavouritesPageState extends State<FavouritesPage> {
  // Favourite item IDs — seeded with all catalogue items on first build.
  Set<String>? _favIds;

  Set<String> _initFavs(List<Map<String, dynamic>> items) =>
      items.map((i) => '${i['id']}').toSet();

  void _remove(String id) => setState(() => _favIds!.remove(id));

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MenuProvider>();
    final allItems = provider.allItems;

    // Seed favourites once items are loaded.
    if (_favIds == null && allItems.isNotEmpty) {
      _favIds = _initFavs(allItems);
    }

    final saved = allItems.where((i) => _favIds?.contains('${i['id']}') == true).toList();

    return SubPageShell(
      title: 'Favourites',
      subtitle: '${saved.length} saved item${saved.length != 1 ? 's' : ''}',
      onBack: widget.onBack,
      child: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : saved.isEmpty
              ? _buildEmpty()
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                  itemCount: saved.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) => _FavTile(
                    item: saved[i],
                    onViewItem: widget.onViewItem,
                    onRemove: () => _remove('${saved[i]['id']}'),
                  ),
                ),
    );
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
                style: TextStyle(color: kInk, fontWeight: FontWeight.w700, fontSize: 16)),
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

  const _FavTile({required this.item, required this.onViewItem, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final img = item['heroImg'] as String? ?? item['img'] as String? ?? '';
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
          // Image
          GestureDetector(
            onTap: () => onViewItem('${item['id']}'),
            child: SizedBox(
              width: 90,
              height: 110,
              child: AppImage.thumb(
                url: img,
                width: 90,
                height: 110,
              ),
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
                          color: kInk, fontWeight: FontWeight.w800, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(item['restaurantName'] as String? ?? item['restaurant'] as String? ?? '',
                      style: const TextStyle(color: kMuted, fontSize: 12)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.star, size: 13, color: kGold),
                      const SizedBox(width: 3),
                      Text('${item['rating'] ?? '—'}',
                          style: const TextStyle(
                              color: kGold, fontSize: 12, fontWeight: FontWeight.w700)),
                      const SizedBox(width: 8),
                      const Icon(Icons.access_time, size: 12, color: kMuted),
                      const SizedBox(width: 3),
                      Text(time, style: const TextStyle(color: kMuted, fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(formatPeso(item['price'] as num?),
                          style: const TextStyle(
                              color: kBrand, fontWeight: FontWeight.w900, fontSize: 15)),
                      GestureDetector(
                        onTap: onRemove,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            border: Border.all(color: kRed.withValues(alpha: 0.25)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text('Remove',
                              style: TextStyle(
                                  color: kRed, fontSize: 12, fontWeight: FontWeight.w600)),
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
