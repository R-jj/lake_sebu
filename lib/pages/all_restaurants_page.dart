import 'package:flutter/material.dart';
import '../constants.dart';
import '../widgets/app_image.dart';
import '_sub_page_shell.dart';

// ── Static data ───────────────────────────────────────────────────────────────

const _kSortOptions = ['Recommended', 'Rating', 'Fastest', 'Price: Low'];

const _kRestaurants = [
  {
    'id': 1, 'name': 'The Patty Lab', 'cuisine': 'American · Burgers',
    'rating': 4.9, 'time': '18', 'fee': 'Free', 'badge': '🔥 Trending',
    'img': 'https://images.unsplash.com/photo-1572802419224-296b0aeee0d9?w=400&h=280&fit=crop&auto=format',
    'open': true,
  },
  {
    'id': 2, 'name': 'Forno Vivo', 'cuisine': 'Italian · Pizza',
    'rating': 4.8, 'time': '24', 'fee': '\$1.49', 'badge': '⭐ Top Rated',
    'img': 'https://images.unsplash.com/photo-1715494534168-2ce3196e6d67?w=400&h=280&fit=crop&auto=format',
    'open': true,
  },
  {
    'id': 3, 'name': 'Umami House', 'cuisine': 'Japanese · Sushi',
    'rating': 4.7, 'time': '28', 'fee': '\$0.99', 'badge': '✨ Premium',
    'img': 'https://images.unsplash.com/photo-1676037150294-837ff0c29599?w=400&h=280&fit=crop&auto=format',
    'open': true,
  },
  {
    'id': 4, 'name': 'Trattoria Roma', 'cuisine': 'Italian · Pasta',
    'rating': 4.6, 'time': '32', 'fee': 'Free', 'badge': '🍝 Classic',
    'img': 'https://images.unsplash.com/photo-1516100882582-96c3a05fe590?w=400&h=280&fit=crop&auto=format',
    'open': true,
  },
  {
    'id': 5, 'name': 'El Señor Taco', 'cuisine': 'Mexican · Street Food',
    'rating': 4.5, 'time': '15', 'fee': 'Free', 'badge': '🌮 Local Fave',
    'img': 'https://images.unsplash.com/photo-1551504734-5ee1c4a1479b?w=400&h=280&fit=crop&auto=format',
    'open': true,
  },
  {
    'id': 6, 'name': 'Green Bowl', 'cuisine': 'Healthy · Vegan',
    'rating': 4.4, 'time': '20', 'fee': '\$0.99', 'badge': '🌱 Healthy',
    'img': 'https://images.unsplash.com/photo-1556040220-4096d522378d?w=400&h=280&fit=crop&auto=format',
    'open': false,
  },
  {
    'id': 7, 'name': 'Seoul Kitchen', 'cuisine': 'Korean · BBQ',
    'rating': 4.6, 'time': '30', 'fee': '\$1.99', 'badge': '🔥 Hot',
    'img': 'https://images.unsplash.com/photo-1571091718767-18b5b1457add?w=400&h=280&fit=crop&auto=format',
    'open': true,
  },
  {
    'id': 8, 'name': 'Spice Route', 'cuisine': 'Indian · Curry',
    'rating': 4.3, 'time': '35', 'fee': 'Free', 'badge': '🍛 Spicy',
    'img': 'https://images.unsplash.com/photo-1607013251379-e6eecfffe234?w=400&h=280&fit=crop&auto=format',
    'open': true,
  },
];

// ── Page ──────────────────────────────────────────────────────────────────────

class AllRestaurantsPage extends StatefulWidget {
  final VoidCallback onBack;
  final void Function(String id) onViewItem;

  const AllRestaurantsPage({
    super.key,
    required this.onBack,
    required this.onViewItem,
  });

  @override
  State<AllRestaurantsPage> createState() => _AllRestaurantsPageState();
}

class _AllRestaurantsPageState extends State<AllRestaurantsPage> {
  String _sort = 'Recommended';
  bool _openOnly = false;
  final _searchCtrl = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _search.toLowerCase();
    var list = _kRestaurants.map((r) => Map<String, dynamic>.from(r)).where((r) {
      if (_openOnly && !(r['open'] as bool)) return false;
      if (q.isNotEmpty) {
        final name = (r['name'] as String).toLowerCase();
        final cuisine = (r['cuisine'] as String).toLowerCase();
        if (!name.contains(q) && !cuisine.contains(q)) return false;
      }
      return true;
    }).toList();

    list.sort((a, b) {
      switch (_sort) {
        case 'Rating':
          return ((b['rating'] as num)).compareTo(a['rating'] as num);
        case 'Fastest':
          return (int.tryParse(a['time'] as String) ?? 99)
              .compareTo(int.tryParse(b['time'] as String) ?? 99);
        case 'Price: Low':
          double feeVal(String f) =>
              f == 'Free' ? 0 : double.tryParse(f.replaceAll('\$', '')) ?? 99;
          return feeVal(a['fee'] as String).compareTo(feeVal(b['fee'] as String));
        default:
          return 0;
      }
    });

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;

    return SubPageShell(
      title: 'All restaurants',
      subtitle: '${items.length} nearby',
      onBack: widget.onBack,
      child: Column(
        children: [
          _buildSearchBar(),
          const SizedBox(height: 10),
          _buildSortAndToggleRow(),
          const SizedBox(height: 12),
          Expanded(
            child: items.isEmpty
                ? _buildEmpty()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                    physics: const BouncingScrollPhysics(),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, i) => _RestaurantCard(
                      data: items[i],
                      onTap: () => widget.onViewItem('${items[i]['id']}'),
                    ),
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
                onChanged: (v) => setState(() => _search = v),
                style: const TextStyle(color: kInk, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Search restaurants...',
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
                },
                child: const Icon(Icons.close, size: 16, color: kMuted),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSortAndToggleRow() {
    return SizedBox(
      height: 32,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        physics: const BouncingScrollPhysics(),
        children: [
          ..._kSortOptions.map((opt) {
            final active = _sort == opt;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _sort = opt),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: active ? kBrand.withValues(alpha: 0.12) : Colors.transparent,
                    border: Border.all(color: active ? kBrand : kBorder),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(opt,
                      style: TextStyle(
                          color: active ? kBrand : kMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            );
          }),
          // Open-only toggle chip
          GestureDetector(
            onTap: () => setState(() => _openOnly = !_openOnly),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: _openOnly ? kGreen.withValues(alpha: 0.15) : Colors.transparent,
                border: Border.all(color: _openOnly ? kGreen : kBorder),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text('Open now',
                  style: TextStyle(
                      color: _openOnly ? kGreen : kMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.store_outlined, size: 40, color: kMuted),
          SizedBox(height: 10),
          Text('No restaurants found',
              style: TextStyle(color: kInk, fontWeight: FontWeight.w600, fontSize: 15)),
          SizedBox(height: 4),
          Text('Try different filters', style: TextStyle(color: kMuted, fontSize: 13)),
        ],
      ),
    );
  }
}

// ── Restaurant card ───────────────────────────────────────────────────────────

class _RestaurantCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;

  const _RestaurantCard({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isOpen = data['open'] as bool;
    final fee = data['fee'] as String;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: kSurface,
          border: Border.all(color: kSurface2),
          borderRadius: BorderRadius.circular(20),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image
            Stack(
              children: [
                SizedBox(
                  height: 130,
                  width: double.infinity,
                  child: AppImage(
                    url: data['img'] as String? ?? '',
                    fit: BoxFit.cover,
                    height: 130,
                    width: double.infinity,
                  ),
                ),
                // Badge
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      data['badge'] as String,
                      style: const TextStyle(color: kInk, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                // Closed overlay
                if (!isOpen)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.55),
                      alignment: Alignment.center,
                      child: const Text('Closed now',
                          style: TextStyle(
                              color: kMuted, fontWeight: FontWeight.w700, fontSize: 14)),
                    ),
                  ),
              ],
            ),
            // Info row
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(data['name'] as String,
                          style: const TextStyle(
                              color: kInk, fontWeight: FontWeight.w800, fontSize: 15)),
                      Row(
                        children: [
                          const Icon(Icons.star, size: 14, color: kGold),
                          const SizedBox(width: 3),
                          Text('${data['rating']}',
                              style: const TextStyle(
                                  color: kGold, fontSize: 13, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(data['cuisine'] as String,
                      style: const TextStyle(color: kMuted, fontSize: 12)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 13, color: kMuted),
                      const SizedBox(width: 4),
                      Text('${data['time']} min',
                          style: const TextStyle(color: kMuted, fontSize: 12)),
                      const SizedBox(width: 12),
                      Text(
                        fee == 'Free' ? '✓ Free delivery' : '$fee delivery',
                        style: TextStyle(
                            color: fee == 'Free' ? kGreen : kMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: isOpen ? kGreen : kRed,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isOpen ? 'Open' : 'Closed',
                        style: TextStyle(
                            color: isOpen ? kGreen : kRed,
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
