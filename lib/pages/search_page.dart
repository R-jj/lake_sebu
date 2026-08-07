import 'package:flutter/material.dart';
import '../constants.dart';
import 'package:provider/provider.dart';
import '../providers/menu_providers.dart';
import '../widgets/app_image.dart';

const _kPageSize = 10;

class SearchPage extends StatefulWidget {
  final void Function(String id) onViewItem;

  const SearchPage({super.key, required this.onViewItem});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  String _query = '';

  /// How many items are currently visible in the active list
  /// (trending when query is empty, results when query is set).
  int _visibleCount = _kPageSize;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  void _loadMore() {
    final provider = context.read<MenuProvider>();
    final total = _query.trim().isEmpty
        ? provider.allItems.length
        : _buildResults(provider.allItems, _query.trim()).length;
    if (_visibleCount < total) {
      setState(
          () => _visibleCount = (_visibleCount + _kPageSize).clamp(0, total));
    }
  }

  void _setQuery(String value) {
    setState(() {
      _query = value;
      _controller.text = value;
      _controller.selection =
          TextSelection.collapsed(offset: value.length);
      _visibleCount = _kPageSize; // reset page on every query change
    });
  }

  List<Map<String, dynamic>> _buildResults(
      List<Map<String, dynamic>> all, String trimmed) {
    final q = trimmed.toLowerCase();
    return all.where((item) {
      final name = (item['name'] as String? ?? '').toLowerCase();
      final restaurant =
          (item['restaurantName'] as String? ?? '').toLowerCase();
      final category = (item['category'] as String? ?? '').toLowerCase();
      return name.contains(q) ||
          restaurant.contains(q) ||
          category.contains(q);
    }).toList();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final menuProvider = context.watch<MenuProvider>();
    final allItems = menuProvider.allItems;
    final trimmed = _query.trim();

    if (menuProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Find your next meal',
              style: kSerif.copyWith(
                  color: kInk, fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: kSurface,
              border: Border.all(color: kBorder),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, size: 18, color: kMuted),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onChanged: _setQuery,
                    style: const TextStyle(color: kInk, fontSize: 14),
                    cursorColor: kBrand,
                    decoration: const InputDecoration(
                      hintText: 'Dishes, restaurants, cuisines...',
                      hintStyle:
                          TextStyle(color: kMuted, fontSize: 14),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                if (_query.isNotEmpty)
                  GestureDetector(
                    onTap: () => _setQuery(''),
                    child: const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Text('×',
                          style:
                              TextStyle(color: kMuted, fontSize: 20)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    // ── No query: trending list ──────────────────────────────────────────────
    if (trimmed.isEmpty) {
      final visible = allItems.take(_visibleCount).toList();
      final hasMore = _visibleCount < allItems.length;

      return Column(
        children: [
          header,
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              physics: const BouncingScrollPhysics(),
              itemCount: _trendingHeaderCount + visible.length + (hasMore ? 1 : 0),
              itemBuilder: (context, i) {
                // ── Static header section ────────────────────────────────
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('POPULAR SEARCHES',
                            style: TextStyle(
                                color: kMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1)),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: kSearchSuggestions.map((s) {
                            final label = s['label'] as String;
                            return GestureDetector(
                              onTap: () => _setQuery(label),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: kSurface,
                                  border: Border.all(color: kBorder),
                                  borderRadius:
                                      BorderRadius.circular(100),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(s['icon'] as IconData,
                                        size: 16, color: kInk),
                                    const SizedBox(width: 6),
                                    Text(label,
                                        style: const TextStyle(
                                            color: kInk,
                                            fontSize: 13,
                                            fontWeight:
                                                FontWeight.w600)),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 24),
                        const Row(
                          children: [
                            Text('TRENDING NOW',
                                style: TextStyle(
                                    color: kMuted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1)),
                            SizedBox(width: 6),
                            Icon(Icons.local_fire_department,
                                size: 14, color: kGold),
                          ],
                        ),
                        const SizedBox(height: 14),
                      ],
                    ),
                  );
                }

                // ── Spinner footer ───────────────────────────────────────
                if (hasMore && i == _trendingHeaderCount + visible.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                // ── Item rows ────────────────────────────────────────────
                final item = visible[i - _trendingHeaderCount];
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: _ResultRow(
                      item: item,
                      onTap: () =>
                          widget.onViewItem('${item['id']}')),
                );
              },
            ),
          ),
        ],
      );
    }

    // ── Results: no matches ──────────────────────────────────────────────────
    final results = _buildResults(allItems, trimmed);

    if (results.isEmpty) {
      return Column(
        children: [
          header,
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.restaurant, size: 44, color: kMuted),
                    const SizedBox(height: 12),
                    const Text('Nothing found',
                        style: TextStyle(
                            color: kInk,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    const Text(
                        'Try a different dish or restaurant name',
                        style:
                            TextStyle(color: kMuted, fontSize: 13)),
                    const SizedBox(height: 16),
                    Text('No results for "$trimmed"',
                        style: const TextStyle(
                            color: kMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1),
                        textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    // ── Results: matches ─────────────────────────────────────────────────────
    final visible = results.take(_visibleCount).toList();
    final hasMore = _visibleCount < results.length;

    return Column(
      children: [
        header,
        Expanded(
          child: ListView.builder(
            controller: _scrollCtrl,
            physics: const BouncingScrollPhysics(),
            itemCount: 1 + visible.length + (hasMore ? 1 : 0),
            itemBuilder: (context, i) {
              // Count label header
              if (i == 0) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
                  child: Text(
                    '${results.length} result${results.length != 1 ? 's' : ''} for "$trimmed"',
                    style: const TextStyle(
                        color: kMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1),
                  ),
                );
              }
              // Spinner footer
              if (hasMore && i == 1 + visible.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final item = visible[i - 1];
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: _ResultRow(
                    item: item,
                    onTap: () =>
                        widget.onViewItem('${item['id']}')),
              );
            },
          ),
        ),
      ],
    );
  }
}

// One static header item (popular searches + trending label)
const int _trendingHeaderCount = 1;

// ── Result row ────────────────────────────────────────────────────────────────

class _ResultRow extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;

  const _ResultRow({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: kSurface,
          border: Border.all(color: kSurface2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                  color: kSurface2,
                  borderRadius: BorderRadius.circular(12)),
              clipBehavior: Clip.hardEdge,
              child: AppImage.thumb(
                url: item['img'] as String? ?? '',
                width: 56,
                height: 56,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item['name'] as String? ?? '',
                      style: const TextStyle(
                          color: kInk,
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
                  Text(
                    '${item['restaurantName'] ?? item['restaurant'] ?? ''} · ${item['category'] ?? 'Food'}',
                    style:
                        const TextStyle(color: kMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(formatPeso(item['price'] as num?),
                    style: const TextStyle(
                        color: kInk, fontWeight: FontWeight.w800)),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, size: 13, color: kGold),
                    const SizedBox(width: 2),
                    Text('${item['rating'] ?? '—'}',
                        style: const TextStyle(
                            color: kGold, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
