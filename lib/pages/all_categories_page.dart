import 'package:flutter/material.dart';
import '../constants.dart';
import '_sub_page_shell.dart';

// ── Static data ───────────────────────────────────────────────────────────────

const _kAllCategories = [
  {'label': 'Burgers', 'emoji': '🍔', 'count': 48, 'color': 0xFFFF6B35},
  {'label': 'Pizza', 'emoji': '🍕', 'count': 63, 'color': 0xFFE63946},
  {'label': 'Sushi', 'emoji': '🍣', 'count': 29, 'color': 0xFF2D6A4F},
  {'label': 'Pasta', 'emoji': '🍝', 'count': 34, 'color': 0xFFF4A261},
  {'label': 'Tacos', 'emoji': '🌮', 'count': 22, 'color': 0xFFE9C46A},
  {'label': 'Salads', 'emoji': '🥗', 'count': 41, 'color': 0xFF52B788},
  {'label': 'Desserts', 'emoji': '🍰', 'count': 55, 'color': 0xFFC77DFF},
  {'label': 'Drinks', 'emoji': '🧃', 'count': 17, 'color': 0xFF4CC9F0},
  {'label': 'Breakfast', 'emoji': '🍳', 'count': 38, 'color': 0xFFF3722C},
  {'label': 'Sandwiches', 'emoji': '🥪', 'count': 26, 'color': 0xFF90BE6D},
  {'label': 'Noodles', 'emoji': '🍜', 'count': 19, 'color': 0xFFF8961E},
  {'label': 'Chicken', 'emoji': '🍗', 'count': 45, 'color': 0xFFFF4D1C},
  {'label': 'Seafood', 'emoji': '🦞', 'count': 14, 'color': 0xFF277DA1},
  {'label': 'Vegan', 'emoji': '🌱', 'count': 31, 'color': 0xFF4CAF82},
  {'label': 'BBQ', 'emoji': '🍖', 'count': 20, 'color': 0xFFBC4749},
  {'label': 'Indian', 'emoji': '🍛', 'count': 24, 'color': 0xFFF9844A},
];

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

  List<Map<String, dynamic>> get _filtered {
    final q = _search.toLowerCase();
    return _kAllCategories
        .where((c) => (c['label'] as String).toLowerCase().contains(q))
        .map((c) => Map<String, dynamic>.from(c))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return SubPageShell(
      title: 'All categories',
      subtitle: '${_kAllCategories.length} categories available',
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
            child: filtered.isEmpty
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
