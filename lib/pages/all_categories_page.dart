import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants.dart';
import '../providers/menu_providers.dart';
import '_sub_page_shell.dart';

// ── Page ──────────────────────────────────────────────────────────────────────

class AllCategoriesPage extends StatefulWidget {
  final VoidCallback onBack;

  /// Called when the user taps a category tile. Passes the category label.
  final void Function(String category) onSelectCategory;

  const AllCategoriesPage({
    super.key,
    required this.onBack,
    required this.onSelectCategory,
  });

  @override
  State<AllCategoriesPage> createState() => _AllCategoriesPageState();
}

class _AllCategoriesPageState extends State<AllCategoriesPage> {
  final _searchCtrl = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Builds the category list from live Firestore data.
  /// Each entry has: label, emoji, color (int), count (real item count).
  List<Map<String, dynamic>> _buildCategories(List<Map<String, dynamic>> allItems) {
    // Count items per category.
    final counts = <String, int>{};
    for (final item in allItems) {
      final cat = item['category'] as String? ?? '';
      if (cat.isNotEmpty) {
        counts[cat] = (counts[cat] ?? 0) + 1;
      }
    }

    // Build sorted list using the lookup maps for emoji and color.
    final categories = counts.keys.toList()..sort();
    return categories.map((label) => {
      'label': label,
      'emoji': kCategoryEmojis[label] ?? '🍽️',
      'color': kCategoryColors[label] ?? 0xFFFF4D1C,
      'count': counts[label] ?? 0,
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final menuProvider = context.watch<MenuProvider>();
    final allCategories = _buildCategories(menuProvider.allItems);

    final q = _search.toLowerCase();
    final filtered = allCategories
        .where((c) => (c['label'] as String).toLowerCase().contains(q))
        .toList();

    return SubPageShell(
      title: 'All categories',
      subtitle: menuProvider.isLoading
          ? 'Loading...'
          : '${allCategories.length} categories available',
      onBack: widget.onBack,
      child: Column(
        children: [
          // Search bar
          Padding(
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
                        hintText: 'Search categories...',
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
          ),
          const SizedBox(height: 16),

          // Grid
          Expanded(
            child: menuProvider.isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: kBrand, strokeWidth: 2),
                  )
                : filtered.isEmpty
                    ? _buildEmpty()
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                        physics: const BouncingScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.55,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (context, i) => _CategoryTile(
                          data: filtered[i],
                          onTap: () {
                            widget.onSelectCategory(filtered[i]['label'] as String);
                            widget.onBack();
                          },
                        ),
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
          Icon(Icons.restaurant_menu, size: 40, color: kMuted),
          SizedBox(height: 10),
          Text('No categories found',
              style: TextStyle(color: kInk, fontWeight: FontWeight.w600, fontSize: 15)),
          SizedBox(height: 4),
          Text('Try a different search', style: TextStyle(color: kMuted, fontSize: 13)),
        ],
      ),
    );
  }
}

// ── Category tile ─────────────────────────────────────────────────────────────

class _CategoryTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;

  const _CategoryTile({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = Color(data['color'] as int);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
        decoration: BoxDecoration(
          color: kSurface,
          border: Border.all(color: kSurface2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                border: Border.all(color: color.withValues(alpha: 0.2)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  data['emoji'] as String,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    data['label'] as String,
                    style: const TextStyle(
                        color: kInk, fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${data['count']} places',
                    style: const TextStyle(color: kMuted, fontSize: 12),
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
