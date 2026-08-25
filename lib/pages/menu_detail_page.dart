import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants.dart';
import '../providers/menu_providers.dart';
import '../widgets/app_image.dart';
import '../widgets/floating_cart_bar.dart';

/// Full-screen menu item detail — sizes, add-ons, quantity, and related items.
class MenuDetailPage extends StatefulWidget {
  final String itemId;
  final VoidCallback onBack;
  final void Function(Map<String, dynamic> item, double price, {int qty}) onAddToCart;
  final void Function(String id) onViewItem;
  final void Function(String id)? onViewRestaurant;
  final int cartCount;
  final double cartTotal;
  final VoidCallback? onOpenCart;

  const MenuDetailPage({
    super.key,
    required this.itemId,
    required this.onBack,
    required this.onAddToCart,
    required this.onViewItem,
    this.onViewRestaurant,
    this.cartCount = 0,
    this.cartTotal = 0,
    this.onOpenCart,
  });

  @override
  State<MenuDetailPage> createState() => _MenuDetailPageState();
}

class _MenuDetailPageState extends State<MenuDetailPage> {
  int _selectedSize = 0;
  final Set<int> _selectedExtras = {};
  int _qty = 1;
  bool _wishlist = false;
  bool _addedFlash = false;

  double get _sizeExtra {
    final sizes = sizesOf(_item);
    if (sizes.isEmpty) return 0;
    return (sizes[_selectedSize.clamp(0, sizes.length - 1)]['extra'] as num?)?.toDouble() ?? 0;
  }

  double get _extrasTotal {
    final extras = extrasOf(_item);
    double sum = 0;
    for (final i in _selectedExtras) {
      sum += (extras[i]['price'] as num?)?.toDouble() ?? 0;
    }
    return sum;
  }

  double get _unitPrice => (itemPrice(_item) + _sizeExtra + _extrasTotal);
  double get _total => _unitPrice * _qty;

  Map<String, dynamic> get _item =>
      context.read<MenuProvider>().itemById(widget.itemId) ?? const {};

  void _toggleExtra(int i) {
    setState(() {
      if (_selectedExtras.contains(i)) {
        _selectedExtras.remove(i);
      } else {
        _selectedExtras.add(i);
      }
    });
  }

  void _handleAdd() {
    widget.onAddToCart(_item, _unitPrice, qty: _qty);
    setState(() => _addedFlash = true);
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _addedFlash = false);
    });
  }

  /// Resolves "You might also like" items.
  ///
  /// If the item has an explicit `related` list, those doc IDs are used.
  /// Otherwise we auto-suggest: items from the same category first, then
  /// items from the same restaurant, excluding the current item (max 2).
  List<Map<String, dynamic>> _relatedItems(Map<String, dynamic> item) {
    final provider = context.read<MenuProvider>();
    final all = provider.allItems.where((i) => '${i['id']}' != widget.itemId);

    // 1. Explicit related list (manual override)
    final manual = relatedOf(item)
        .map((id) => provider.itemById(id))
        .whereType<Map<String, dynamic>>()
        .toList();
    if (manual.isNotEmpty) return manual;

    // 2. Auto-suggest from the same category
    final category = item['category'] as String?;
    final byCategory = category == null
        ? <Map<String, dynamic>>[]
        : all.where((i) => i['category'] == category).toList();

    // 3. Fall back / top up with same-restaurant items
    final rid = item['restaurantId'] as String?;
    final result = List<Map<String, dynamic>>.from(byCategory);
    if (rid != null) {
      for (final candidate in all) {
        if (result.length >= 2) break;
        if (candidate['restaurantId'] == rid && !result.contains(candidate)) {
          result.add(candidate);
        }
      }
    }

    return result.take(2).toList();
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;
    if (item.isEmpty) {
      return const Scaffold(
        backgroundColor: kCanvas,
        body: Center(child: Text('Item not found', style: TextStyle(color: kMuted))),
      );
    }

    final sizes = sizesOf(item);
    final extras = extrasOf(item);
    final related = _relatedItems(item);

    return Scaffold(
      backgroundColor: kCanvas,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHero(item),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTitleRow(item),
                          const SizedBox(height: 16),
                          _buildStatsPills(item),
                          const SizedBox(height: 20),
                          _buildRestaurantRow(item),
                          const SizedBox(height: 24),
                          _buildSectionTitle('About this dish'),
                          const SizedBox(height: 8),
                          Text(
                            item['description'] as String? ?? 'No description available.',
                            style: const TextStyle(color: kMuted, fontSize: 14, height: 1.7),
                          ),
                          const SizedBox(height: 24),
                          if (sizes.isNotEmpty) ...[
                            _buildSectionTitle('Size'),
                            const SizedBox(height: 12),
                            _buildSizeSelector(sizes),
                            const SizedBox(height: 24),
                          ],
                          if (extras.isNotEmpty) ...[
                            _buildSectionTitle('Add-ons'),
                            const SizedBox(height: 4),
                            const Text('Optional extras to customise your order',
                                style: TextStyle(color: kMuted, fontSize: 12)),
                            const SizedBox(height: 12),
                            _buildExtras(extras),
                            const SizedBox(height: 24),
                          ],
                          if (related.isNotEmpty) ...[
                            _buildSectionTitle('You might also like'),
                            const SizedBox(height: 12),
                            _buildRelated(related),
                            const SizedBox(height: 28),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // ── Cart bar — sits between scroll area and add-to-cart bar ────
            if (widget.cartCount > 0)
              FloatingCartBar(
                cartCount: widget.cartCount,
                cartTotal: widget.cartTotal,
                onTap: widget.onOpenCart ?? () {},
              ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  // ── Hero ────────────────────────────────────────────────────────────────────

  Widget _buildHero(Map<String, dynamic> item) {
    final img = item['heroImg'] as String? ?? item['img'] as String? ?? '';
    return SizedBox(
      height: 260,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AppImage.hero(
            url: img,
            fit: BoxFit.cover,
            width: double.infinity,
            height: 260,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0x1A0F0D0C), Color(0xCC0F0D0C)],
              ),
            ),
          ),
          // Back button
          Positioned(
            top: 16,
            left: 16,
            child: GestureDetector(
              onTap: widget.onBack,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0x990F0D0C),
                  border: Border.all(color: const Color(0x1AFFFFFF)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.chevron_left, color: kInk, size: 20),
              ),
            ),
          ),
          // Wishlist
          Positioned(
            top: 16,
            right: 16,
            child: GestureDetector(
              onTap: () => setState(() => _wishlist = !_wishlist),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0x990F0D0C),
                  border: Border.all(color: const Color(0x1AFFFFFF)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_wishlist ? Icons.favorite : Icons.favorite_border,
                    color: _wishlist ? kRed : kInk, size: 19),
              ),
            ),
          ),
          // Tag
          if (item['tag'] != null)
            Positioned(
              bottom: 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: tagColorOf(item),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  item['tag'] as String,
                  style: TextStyle(
                    color: isGoldTag(item) ? kCanvas : Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTitleRow(Map<String, dynamic> item) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item['name'] as String? ?? 'Unknown item',
                style: kSerif.copyWith(color: kInk, fontSize: 24, fontWeight: FontWeight.w900, height: 1.2, letterSpacing: -0.5),
              ),
              const SizedBox(height: 4),
              Text(item['restaurantName'] as String? ?? item['restaurant'] as String? ?? '',
                  style: const TextStyle(color: kMuted, fontSize: 13)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          formatPeso(item['price'] as num?),
          style: kSerif.copyWith(color: kBrand, fontSize: 22, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }

  Widget _buildStatsPills(Map<String, dynamic> item) {
    final reviews = item['reviews'] as num?;
    final stats = [
      {'icon': Icons.star, 'val': '${item['rating'] ?? '—'}', 'sub': reviews != null ? '(${_compactNum(reviews)})' : '', 'color': kGold},
      {'icon': Icons.access_time, 'val': item['time'] as String? ?? '—', 'sub': '', 'color': kMuted},
      {'icon': Icons.local_fire_department, 'val': '${item['calories'] ?? '—'}', 'sub': 'cal', 'color': kMuted},
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: stats.map((s) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(color: kSurface, border: Border.all(color: kSurface2), borderRadius: BorderRadius.circular(10)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(s['icon'] as IconData, size: 13, color: s['color'] as Color),
              const SizedBox(width: 5),
              Text(s['val'] as String, style: TextStyle(color: s['color'] as Color, fontSize: 13, fontWeight: FontWeight.w700)),
              if ((s['sub'] as String).isNotEmpty) ...[
                const SizedBox(width: 2),
                Text(s['sub'] as String, style: const TextStyle(color: kMuted, fontSize: 12)),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  /// Resolves the restaurant's own image/logo for the restaurant row.
  ///
  /// Priority: explicit `restaurantImg` on the menu doc → the restaurant's
  /// `img` from the `restaurants` collection → empty (dark placeholder).
  String _restaurantImg(Map<String, dynamic> item) {
    final explicit = item['restaurantImg'] as String?;
    if (explicit != null && explicit.isNotEmpty) return explicit;
    final rid = item['restaurantId'] as String?;
    final restaurant = context.read<MenuProvider>().restaurantById(rid);
    final restImg = restaurant?['img'] as String?;
    if (restImg != null && restImg.isNotEmpty) return restImg;
    return '';
  }

  Widget _buildRestaurantRow(Map<String, dynamic> item) {
    final rid = item['restaurantId'] as String?;
    final restaurant = context.read<MenuProvider>().restaurantById(rid);
    final restaurantId = rid ?? restaurant?['id'] as String?;

    final row = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: kSurface, border: Border.all(color: kSurface2), borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              _restaurantImg(item),
              width: 40,
              height: 40,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) => Container(width: 40, height: 40, color: kSurface2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(restaurant?['name'] as String? ?? item['restaurantName'] as String? ?? 'Restaurant',
                    style: const TextStyle(color: kInk, fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 2),
                const Text('Open now · Free delivery', style: TextStyle(color: kGreen, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const Text('View menu ›', style: TextStyle(color: kBrand, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );

    if (widget.onViewRestaurant != null && restaurantId != null) {
      return GestureDetector(
        onTap: () => widget.onViewRestaurant!(restaurantId),
        child: row,
      );
    }
    return row;
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(color: kInk, fontSize: 15, fontWeight: FontWeight.w800));
  }

  Widget _buildSizeSelector(List<Map<String, dynamic>> sizes) {
    return Column(
      children: List.generate(sizes.length, (i) {
        final size = sizes[i];
        final extra = (size['extra'] as num?)?.toDouble() ?? 0;
        final selected = _selectedSize == i;
        return Padding(
          padding: EdgeInsets.only(bottom: i < sizes.length - 1 ? 8 : 0),
          child: GestureDetector(
            onTap: () => setState(() => _selectedSize = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: selected ? kBrand.withValues(alpha: 0.1) : kSurface,
                border: Border.all(color: selected ? kBrand : kSurface2, width: 1.5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: selected ? kBrand : kBorder, width: 2),
                    ),
                    child: selected
                        ? Center(child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: kBrand, shape: BoxShape.circle)))
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(size['label'] as String? ?? 'Size',
                        style: const TextStyle(color: kInk, fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                  Text(
                    extra == 0
                        ? 'Included'
                        : extra > 0
                            ? '+${formatPeso(extra)}'
                            : '-${formatPeso(extra.abs())}',
                    style: TextStyle(
                      color: extra == 0 ? kMuted : kBrand,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildExtras(List<Map<String, dynamic>> extras) {
    return Column(
      children: List.generate(extras.length, (i) {
        final extra = extras[i];
        final checked = _selectedExtras.contains(i);
        final price = (extra['price'] as num?)?.toDouble() ?? 0;
        return Padding(
          padding: EdgeInsets.only(bottom: i < extras.length - 1 ? 8 : 0),
          child: GestureDetector(
            onTap: () => _toggleExtra(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: checked ? kBrand.withValues(alpha: 0.1) : kSurface,
                border: Border.all(color: checked ? kBrand : kSurface2, width: 1.5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: checked ? kBrand : Colors.transparent,
                      border: Border.all(color: checked ? kBrand : kBorder, width: 2),
                    ),
                    child: checked
                        ? const Center(
                            child: Icon(Icons.check, size: 12, color: Colors.white, weight: 900),
                          )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(extra['label'] as String? ?? 'Extra',
                        style: const TextStyle(color: kInk, fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                  Text('+${formatPeso(price)}',
                      style: const TextStyle(color: kBrand, fontSize: 14, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildRelated(List<Map<String, dynamic>> related) {
    return Row(
      children: List.generate(related.length, (i) {
        final rel = related[i];
        final img = rel['heroImg'] as String? ?? rel['img'] as String? ?? '';
        return Expanded(
          child: GestureDetector(
            onTap: () => widget.onViewItem('${rel['id']}'),
            child: Container(
              margin: EdgeInsets.only(right: i < related.length - 1 ? 12 : 0),
              decoration: BoxDecoration(
                color: kSurface,
                border: Border.all(color: kSurface2),
                borderRadius: BorderRadius.circular(16),
              ),
              clipBehavior: Clip.hardEdge,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 90,
                    child: Image.network(
                      img,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) => Container(color: kSurface2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rel['name'] as String? ?? '',
                          style: const TextStyle(color: kInk, fontSize: 13, fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(formatPeso(rel['price'] as num?),
                            style: const TextStyle(color: kBrand, fontSize: 13, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: const BoxDecoration(color: kCanvas, border: Border(top: BorderSide(color: kSurface2))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    _MiniBtn(
                      icon: Icons.remove,
                      bg: kSurface2,
                      fg: kInk,
                      onTap: () => setState(() => _qty = _qty > 1 ? _qty - 1 : 1),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('$_qty',
                          style: const TextStyle(color: kInk, fontSize: 16, fontWeight: FontWeight.w800)),
                    ),
                    _MiniBtn(
                      icon: Icons.add,
                      bg: kBrand,
                      fg: Colors.white,
                      onTap: () => setState(() => _qty++),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Total', style: TextStyle(color: kMuted, fontSize: 11)),
                  Text(formatPeso(_total),
                      style: kSerif.copyWith(color: kInk, fontSize: 20, fontWeight: FontWeight.w900)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _handleAdd,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                color: _addedFlash ? kGreen : kBrand,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Center(
                child: Text(
                  _addedFlash ? '✓ Added to cart' : 'Add to cart · ${formatPeso(_total)}',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Small helpers ─────────────────────────────────────────────────────────────

Color tagColorOf(Map<String, dynamic> item) {
  final value = item['tagColor'];
  if (value is int) return Color(value);
  return kBrand;
}

bool isGoldTag(Map<String, dynamic> item) => item['tagColor'] == 0xFFF5C842;

double itemPrice(Map<String, dynamic> item) =>
    (item['price'] as num?)?.toDouble() ?? 0;

String _compactNum(num n) {
  if (n >= 1000) {
    final k = n / 1000;
    return '${k.toStringAsFixed(k % 1 == 0 ? 0 : 1)}k';
  }
  return n.toStringAsFixed(0);
}

class _MiniBtn extends StatelessWidget {
  final IconData icon;
  final Color bg;
  final Color fg;
  final VoidCallback onTap;

  const _MiniBtn({required this.icon, required this.bg, required this.fg, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 16, color: fg),
      ),
    );
  }
}
