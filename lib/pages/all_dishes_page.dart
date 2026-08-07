import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants.dart';
import '../providers/menu_providers.dart';
import '../widgets/app_image.dart';
import '_sub_page_shell.dart';

const _kSortOptions = [
  'Recommended',
  'Rating',
  'Fastest',
  'Price: Low',
  'Price: High',
];

class AllDishesPage extends StatefulWidget {
  final VoidCallback onBack;
  final void Function(String id) onViewItem;
  final void Function(Map<String, dynamic> item) onAddToCart;

  const AllDishesPage({
    super.key,
    required this.onBack,
    required this.onViewItem,
    required this.onAddToCart,
  });

  @override
  State<AllDishesPage> createState() => _AllDishesPageState();
}

const _kPageSize = 15;

class _AllDishesPageState extends State<AllDishesPage> {
  String _sort = 'Recommended';
  String _filter = 'All';
  final _searchCtrl = TextEditingController();
  String _search = '';

  int _visibleCount = _kPageSize;
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  void _loadMore() {
    // Called during scroll — guard against unnecessary setState calls.
    final provider = context.read<MenuProvider>();
    final total = _applyFilters(provider.allItems).length;
    if (_visibleCount < total) {
      setState(() => _visibleCount =
          (_visibleCount + _kPageSize).clamp(0, total));
    }
  }

  /// Resets pagination whenever filters/sort/search change.
  void _resetPage() => setState(() => _visibleCount = _kPageSize);

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> items) {
    var list = items.where((d) {
      // 1. Category Tab Filter
      if (_filter != 'All') {
        final name = (d['name'] as String? ?? '').toLowerCase();
        final rest = (d['restaurant'] as String? ??
                d['restaurantName'] as String? ??
                '')
            .toLowerCase();
        // Extract the category field
        final category = (d['category'] as String? ?? '').toLowerCase();
        
        final filterLower = _filter.toLowerCase();
        
        // Check if the filter matches the category, name, or restaurant
        if (!category.contains(filterLower) && 
            !name.contains(filterLower) && 
            !rest.contains(filterLower)) {
          return false;
        }
      }

      // 2. Search Text Filter
      if (_search.isNotEmpty) {
        final q = _search.toLowerCase();
        final name = (d['name'] as String? ?? '').toLowerCase();
        final rest = (d['restaurant'] as String? ??
                d['restaurantName'] as String? ??
                '')
            .toLowerCase();
        // You can optionally allow users to search by category text too
        final category = (d['category'] as String? ?? '').toLowerCase();
        
        if (!name.contains(q) && !rest.contains(q) && !category.contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();

    // 3. Sorting
    list.sort((a, b) {
      switch (_sort) {
        case 'Rating':
          return ((b['rating'] as num?) ?? 0)
              .compareTo((a['rating'] as num?) ?? 0);
        case 'Price: Low':
          return ((a['price'] as num?) ?? 0)
              .compareTo((b['price'] as num?) ?? 0);
        case 'Price: High':
          return ((b['price'] as num?) ?? 0)
              .compareTo((a['price'] as num?) ?? 0);
        default:
          return 0;
      }
    });

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MenuProvider>();

    // Rebuild the dynamic category tabs.
    final Set<String> uniqueCategories = {};
    for (var item in provider.allItems) {
      final category = item['category'] as String?;
      if (category != null && category.trim().isNotEmpty) {
        uniqueCategories.add(category.trim());
      }
    }
    final dynamicFilterTabs = ['All', ...uniqueCategories.toList()..sort()];

    // Apply filters then page-slice.
    final allFiltered = _applyFilters(provider.allItems);
    final visibleItems = allFiltered.take(_visibleCount).toList();
    final hasMore = _visibleCount < allFiltered.length;

    return SubPageShell(
      title: 'All dishes',
      subtitle: '${allFiltered.length} item${allFiltered.length != 1 ? 's' : ''}',
      onBack: widget.onBack,
      child: Column(
        children: [
          _buildSearchBar(),
          const SizedBox(height: 10),
          _buildFilterTabs(dynamicFilterTabs),
          const SizedBox(height: 8),
          _buildSortRow(),
          const SizedBox(height: 12),
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : allFiltered.isEmpty
                    ? _buildEmpty()
                    : ListView.separated(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                        physics: const BouncingScrollPhysics(),
                        itemCount: visibleItems.length + (hasMore ? 1 : 0),
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, i) {
                          if (i == visibleItems.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          return _DishTile(
                            item: visibleItems[i],
                            onViewItem: widget.onViewItem,
                            onAddToCart: widget.onAddToCart,
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: kSurface,
          border: Border.all(color: kBorder),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(Icons.search, size: 16, color: kMuted),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) {
                  setState(() => _search = v);
                  _resetPage();
                },
                style: const TextStyle(color: kInk, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Search dishes...',
                  hintStyle: TextStyle(color: kMuted, fontSize: 14),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            if (_search.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _searchCtrl.clear();
                  setState(() => _search = '');
                  _resetPage();
                },
                child: const Icon(Icons.close, size: 16, color: kMuted),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTabs(List<String> tabs) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        physics: const BouncingScrollPhysics(),
        itemCount: tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final tab = tabs[i]; // Use the passed-in list
          final active = _filter == tab;
          return GestureDetector(
            onTap: () {
                _resetPage();
                setState(() => _filter = tab);
              },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: BoxDecoration(
                color: active ? kBrand : kSurface,
                border: Border.all(color: active ? kBrand : kBorder),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                tab,
                style: TextStyle(
                  color: active ? Colors.white : kMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSortRow() {
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        physics: const BouncingScrollPhysics(),
        itemCount: _kSortOptions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final opt = _kSortOptions[i];
          final active = _sort == opt;
          return GestureDetector(
            onTap: () {
                _resetPage();
                setState(() => _sort = opt);
              },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: active ? kBrand.withValues(alpha: 0.12) : Colors.transparent,
                border: Border.all(color: active ? kBrand : kBorder),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                opt,
                style: TextStyle(
                  color: active ? kBrand : kMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.restaurant_menu, size: 40, color: kMuted),
          SizedBox(height: 10),
          Text('No dishes found',
              style: TextStyle(color: kInk, fontWeight: FontWeight.w600, fontSize: 15)),
          SizedBox(height: 4),
          Text('Try adjusting your filters',
              style: TextStyle(color: kMuted, fontSize: 13)),
        ],
      ),
    );
  }
}

// ── Dish tile ─────────────────────────────────────────────────────────────────

class _DishTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final void Function(String id) onViewItem;
  final void Function(Map<String, dynamic> item) onAddToCart;

  const _DishTile(
      {required this.item, required this.onViewItem, required this.onAddToCart});

  @override
  Widget build(BuildContext context) {
    final heroImg = '${item['heroImg'] ?? item['img'] ?? ''}';
    final tag = '${item['tag'] ?? ''}';
    final tagColorHex = item['tagColor'];
    final tagColor = tagColorHex is String
        ? Color(int.parse(tagColorHex.replaceFirst('#', '0xFF')))
        : kBrand;
    final time = item['time'] != null ? '${item['time']}' : '—';
    final calories = item['calories'];

    return Container(
      decoration: BoxDecoration(
        color: kSurface,
        border: Border.all(color: kSurface2),
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.hardEdge,
      child: Row(
        children: [
          // Thumbnail
          GestureDetector(
            onTap: () => onViewItem('${item['id']}'),
            child: Stack(
              children: [
                SizedBox(
                  width: 100,
                  height: 110,
                  child: AppImage.thumb(
                    url: heroImg,
                    width: 100,
                    height: 110,
                  ),
                ),
                if (tag.isNotEmpty)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: tagColor,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(
                          color: tagColor == kGold ? kCanvas : Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Info
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => onViewItem('${item['id']}'),
                    child: Text(
                      '${item['name'] ?? ''}',
                      style: const TextStyle(
                          color: kInk,
                          fontWeight: FontWeight.w800,
                          fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item['restaurant'] != null
                        ? '${item['restaurant']}'
                        : item['restaurantName'] != null
                            ? '${item['restaurantName']}'
                            : '',
                    style: const TextStyle(color: kMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.star, size: 12, color: kGold),
                      const SizedBox(width: 3),
                      Text('${item['rating'] ?? '—'}',
                          style: const TextStyle(
                              color: kGold,
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(width: 8),
                      const Icon(Icons.access_time, size: 11, color: kMuted),
                      const SizedBox(width: 3),
                      Text(time,
                          style: const TextStyle(
                              color: kMuted, fontSize: 11)),
                      if (calories != null) ...[
                        const SizedBox(width: 8),
                        Text('🔥 $calories cal',
                            style: const TextStyle(
                                color: kMuted, fontSize: 11)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        formatPeso(item['price'] as num?),
                        style: const TextStyle(
                            color: kBrand,
                            fontWeight: FontWeight.w900,
                            fontSize: 16),
                      ),
                      GestureDetector(
                        onTap: () => onAddToCart(item),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: kBrand,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Center(
                            child: Icon(Icons.add,
                                color: Colors.white, size: 18),
                          ),
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
