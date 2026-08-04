import 'package:flutter/material.dart';
import '../constants.dart';
import 'package:provider/provider.dart';
import '../providers/menu_providers.dart';

class SearchPage extends StatefulWidget {
  final void Function(String id) onViewItem;

  const SearchPage({super.key, required this.onViewItem});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setQuery(String value) {
    setState(() {
      _query = value;
      _controller.text = value;
      _controller.selection = TextSelection.collapsed(offset: value.length);
    });
  }

  @override
  Widget build(BuildContext context) {
    final menuProvider = context.watch<MenuProvider>();
    final allItems = menuProvider.allItems;
    final trimmed = _query.trim();

    List<Map<String, dynamic>> results = [];
    if (trimmed.isNotEmpty) {
      final q = trimmed.toLowerCase();
      results = allItems.where((item) {
        // Safely extract strings with fallbacks
        final name = (item['name'] as String? ?? '').toLowerCase();
        final restaurant = (item['restaurantName'] as String? ?? '').toLowerCase();
        final category = (item['category'] as String? ?? '').toLowerCase();

        // Return true if the query matches the name, restaurant, OR category
        return name.contains(q) || restaurant.contains(q) || category.contains(q);
      }).toList();
    }

    if (menuProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Find your next meal',
              style: kSerif.copyWith(color: kInk, fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                    onChanged: (v) => setState(() => _query = v),
                    style: const TextStyle(color: kInk, fontSize: 14),
                    cursorColor: kBrand,
                    decoration: const InputDecoration(
                      hintText: 'Dishes, restaurants, cuisines...',
                      hintStyle: TextStyle(color: kMuted, fontSize: 14),
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
                      child: Text('×', style: TextStyle(color: kMuted, fontSize: 20)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    // No query yet — popular searches + trending
    if (trimmed.isEmpty) {
      return Column(
        children: [
          header,
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('POPULAR SEARCHES',
                            style: TextStyle(color: kMuted, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: kSearchSuggestions.map((s) {
                            final label = s['label'] as String;
                            return GestureDetector(
                              onTap: () => _setQuery(label),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: kSurface,
                                  border: Border.all(color: kBorder),
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(s['icon'] as IconData, size: 16, color: kInk),
                                    const SizedBox(width: 6),
                                    Text(label, style: const TextStyle(color: kInk, fontSize: 13, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Text('TRENDING NOW',
                                style: TextStyle(color: kMuted, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
                            SizedBox(width: 6),
                            Icon(Icons.local_fire_department, size: 14, color: kGold),
                          ],
                        ),
                        const SizedBox(height: 14),
                        ...allItems.map((item) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _ResultRow(item: item, onTap: () => widget.onViewItem('${item['id']}')),
                            )),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // No matches — centered empty state
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
                    const Text('Nothing found', style: TextStyle(color: kInk, fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    const Text('Try a different dish or restaurant name', style: TextStyle(color: kMuted, fontSize: 13)),
                    const SizedBox(height: 16),
                    Text('No results for "$trimmed"',
                        style: const TextStyle(color: kMuted, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1),
                        textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Matches found
    return Column(
      children: [
        header,
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${results.length} result${results.length != 1 ? 's' : ''} for "$trimmed"',
                    style: const TextStyle(color: kMuted, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1),
                  ),
                  const SizedBox(height: 14),
                  ...results.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ResultRow(item: item, onTap: () => widget.onViewItem('${item['id']}')),
                      )),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

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
              decoration: BoxDecoration(color: kSurface2, borderRadius: BorderRadius.circular(12)),
              clipBehavior: Clip.hardEdge,
              child: Image.network(
                item['img'] as String,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => Container(color: kSurface2),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item['name'] as String, style: const TextStyle(color: kInk, fontWeight: FontWeight.w700, fontSize: 14)),
                  Text(
                    '${item['restaurantName']} · ${item['category'] ?? 'Food'}',
                    style: const TextStyle(color: kMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(formatPeso(item['price'] as num?),
                    style: const TextStyle(color: kInk, fontWeight: FontWeight.w800)),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, size: 13, color: kGold),
                    const SizedBox(width: 2),
                    Text('${item['rating']}', style: const TextStyle(color: kGold, fontSize: 12)),
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
