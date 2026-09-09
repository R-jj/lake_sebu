import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants.dart';
import '../providers/menu_providers.dart';
import '../widgets/app_image.dart';
import '_sub_page_shell.dart';

// ── Sort options ──────────────────────────────────────────────────────────────

const _kSortOptions = ['Recommended', 'Rating', 'Fastest', 'Price: Low'];

// ── Page ──────────────────────────────────────────────────────────────────────

class AllRestaurantsPage extends StatefulWidget {
  final VoidCallback onBack;
  final void Function(String id) onViewItem;
  final void Function(String id) onViewRestaurant;

  const AllRestaurantsPage({
    super.key,
    required this.onBack,
    required this.onViewItem,
    required this.onViewRestaurant,
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

  List<Map<String, dynamic>> _filtered(List<Map<String, dynamic>> source) {
    final q = _search.toLowerCase();

    var list = source.where((r) {
      if (_openOnly && !(r['open'] as bool? ?? true)) return false;
      if (q.isNotEmpty) {
        final name = (r['name'] as String? ?? '').toLowerCase();
        final cuisine = (r['cuisine'] as String? ?? '').toLowerCase();
        if (!name.contains(q) && !cuisine.contains(q)) return false;
      }
      return true;
    }).toList();

    list.sort((a, b) {
      switch (_sort) {
        case 'Rating':
          final ra = (a['rating'] as num?) ?? 0;
          final rb = (b['rating'] as num?) ?? 0;
          return rb.compareTo(ra);
        case 'Fastest':
          int toMin(dynamic v) =>
              int.tryParse(v?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '') ?? 99;
          return toMin(a['time']).compareTo(toMin(b['time']));
        case 'Price: Low':
          double feeVal(dynamic f) {
            final s = f?.toString() ?? '';
            if (s == 'Free') return 0;
            return double.tryParse(s.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 99;
          }
          return feeVal(a['fee']).compareTo(feeVal(b['fee']));
        default:
          return 0;
      }
    });

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MenuProvider>();

    if (provider.isLoading) {
      return SubPageShell(
        title: 'All restaurants',
        onBack: widget.onBack,
        child: const Center(child: CircularProgressIndicator(color: kBrand)),
      );
    }

    final items = _filtered(provider.restaurants);

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
                    separatorBuilder: (_, _) => const SizedBox(height: 14),
                    itemBuilder: (context, i) => _RestaurantCard(
                      data: items[i],
                      onTap: () => widget.onViewRestaurant('${items[i]['id']}'),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: active
                        ? kBrand.withValues(alpha: 0.12)
                        : Colors.transparent,
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: _openOnly
                    ? kGreen.withValues(alpha: 0.15)
                    : Colors.transparent,
                border:
                    Border.all(color: _openOnly ? kGreen : kBorder),
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
              style: TextStyle(
                  color: kInk, fontWeight: FontWeight.w600, fontSize: 15)),
          SizedBox(height: 4),
          Text('Try different filters',
              style: TextStyle(color: kMuted, fontSize: 13)),
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
    final isOpen = data['open'] as bool? ?? true;
    final fee = data['fee'] as String? ?? '';
    final badge = data['badge'] as String?;
    final rating = data['rating'];
    final time = data['time'];

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
            // ── Cover image ───────────────────────────────────────────────
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
                if (badge != null)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        badge,
                        style: const TextStyle(
                            color: kInk,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                if (!isOpen)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.55),
                      alignment: Alignment.center,
                      child: const Text('Closed now',
                          style: TextStyle(
                              color: kMuted,
                              fontWeight: FontWeight.w700,
                              fontSize: 14)),
                    ),
                  ),
              ],
            ),
            // ── Info ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          data['name'] as String? ?? '',
                          style: const TextStyle(
                              color: kInk,
                              fontWeight: FontWeight.w800,
                              fontSize: 15),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (rating != null)
                        Row(
                          children: [
                            const Icon(Icons.star, size: 14, color: kGold),
                            const SizedBox(width: 3),
                            Text('$rating',
                                style: const TextStyle(
                                    color: kGold,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800)),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (data['cuisine'] != null)
                    Text(data['cuisine'] as String,
                        style: const TextStyle(color: kMuted, fontSize: 12)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (time != null) ...[
                        const Icon(Icons.access_time, size: 13, color: kMuted),
                        const SizedBox(width: 4),
                        Text('$time min',
                            style:
                                const TextStyle(color: kMuted, fontSize: 12)),
                        const SizedBox(width: 12),
                      ],
                      if (fee.isNotEmpty)
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
