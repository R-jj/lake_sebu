import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants.dart';
import '../providers/menu_providers.dart';
import '../widgets/app_image.dart';
import '../widgets/floating_cart_bar.dart';

class RestaurantPage extends StatefulWidget {
  final String restaurantId;
  final VoidCallback onBack;
  final void Function(String id) onViewItem;
  final void Function(Map<String, dynamic> item, {double? price})? onAddToCart;
  final int cartCount;
  final double cartTotal;
  final VoidCallback? onOpenCart;

  const RestaurantPage({
    super.key,
    required this.restaurantId,
    required this.onBack,
    required this.onViewItem,
    this.onAddToCart,
    this.cartCount = 0,
    this.cartTotal = 0,
    this.onOpenCart,
  });

  @override
  State<RestaurantPage> createState() => _RestaurantPageState();
}

class _RestaurantPageState extends State<RestaurantPage> {
  String _selectedCategory = 'All';
  final _scrollController = ScrollController();
  bool _heroVisible = true; // true while hero back button is on screen

  // The hero is 260px tall; the collapsed toolbar is ~56px.
  // Once scroll offset > (260 - 56) the hero back btn is gone.
  static const double _collapseThreshold = 204;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      final collapsed =
          _scrollController.offset >= _collapseThreshold;
      if (collapsed == _heroVisible) {
        setState(() => _heroVisible = !collapsed);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MenuProvider>();

    if (provider.isLoading) {
      return Scaffold(
        backgroundColor: kCanvas,
        body: const Center(
          child: CircularProgressIndicator(color: kBrand),
        ),
      );
    }

    // Find the restaurant by its Firestore document ID.
    final Map<String, dynamic>? restaurant = provider.restaurants
        .cast<Map<String, dynamic>?>()
        .firstWhere(
          (r) => '${r!['id']}' == widget.restaurantId,
          orElse: () => null,
        );

    if (restaurant == null) {
      return Scaffold(
        backgroundColor: kCanvas,
        body: SafeArea(
          child: Column(
            children: [
              _buildBackButton(),
              const Expanded(
                child: Center(
                  child: Text(
                    'Restaurant not found',
                    style: TextStyle(color: kMuted, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // All menu items belonging to this restaurant, matched by restaurantId.
    final restaurantName = restaurant['name'] as String? ?? '';
    final allMenu = provider.allItems
        .where((item) =>
            (item['restaurantId'] as String? ?? '') == widget.restaurantId)
        .toList();

    // Build dynamic category list from menu items.
    final categories = <String>['All'];
    for (final item in allMenu) {
      final cat = item['category'] as String?;
      if (cat != null && !categories.contains(cat)) {
        categories.add(cat);
      }
    }

    // Filter by selected category.
    final filteredMenu = _selectedCategory == 'All'
        ? allMenu
        : allMenu
            .where((item) => item['category'] == _selectedCategory)
            .toList();

    final isOpen = restaurant['open'] as bool? ?? true;
    final fee = restaurant['fee'] as String? ?? '';
    final rating = restaurant['rating'];
    final time = restaurant['time'];

    return Scaffold(
      backgroundColor: kCanvas,
      body: Stack(
        children: [
          CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              slivers: [
                // ── Sticky hero ─────────────────────────────────────────────
                SliverAppBar(
                  expandedHeight: 260,
                  pinned: true,
                  backgroundColor: kCanvas,
                  automaticallyImplyLeading: false,
                  leading: null,
                  flexibleSpace: FlexibleSpaceBar(
                    collapseMode: CollapseMode.parallax,
                    background: _buildHero(restaurant, isOpen),
                  ),
                  title: _heroVisible
                      ? null
                      : Text(
                          restaurantName,
                          style: const TextStyle(
                            color: kInk,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                  titleSpacing: 56,
                ),

                // ── Info section ────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (restaurant['cuisine'] != null)
                          Text(
                            restaurant['cuisine'] as String,
                            style:
                                const TextStyle(color: kMuted, fontSize: 13),
                          ),
                        const SizedBox(height: 14),
                        _buildInfoPills(rating, time, fee, isOpen),
                        if (restaurant['description'] != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            restaurant['description'] as String,
                            style: const TextStyle(
                                color: kMuted, fontSize: 13, height: 1.6),
                          ),
                        ],
                        const SizedBox(height: 24),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'Menu',
                              style: kSerif.copyWith(
                                color: kInk,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${allMenu.length} items',
                              style: const TextStyle(
                                  color: kMuted, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Category filter tabs ────────────────────────────────────
                if (categories.length > 1)
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _CategoryTabDelegate(
                      categories: categories,
                      selected: _selectedCategory,
                      onSelect: (cat) =>
                          setState(() => _selectedCategory = cat),
                    ),
                  ),

                // ── Menu list ───────────────────────────────────────────────
                filteredMenu.isEmpty
                    ? SliverFillRemaining(
                        hasScrollBody: false,
                        child: _buildEmptyMenu(),
                      )
                    : SliverPadding(
                        padding: EdgeInsets.fromLTRB(20, 14, 20, widget.cartCount > 0 ? 100 : 32),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: _MenuItemCard(
                                item: filteredMenu[index],
                                onTap: () => widget
                                    .onViewItem('${filteredMenu[index]['id']}'),
                                onAdd: widget.onAddToCart != null
                                    ? () => widget.onAddToCart!(
                                        filteredMenu[index])
                                    : null,
                              ),
                            ),
                            childCount: filteredMenu.length,
                          ),
                        ),
                      ),
              ],
            ),

          // ── Floating back button — always on top ──────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            child: _BackButton(onTap: widget.onBack),
          ),

          // ── Floating cart bar ─────────────────────────────────────────────
          if (widget.cartCount > 0)
            Positioned(
              left: 0,
              right: 0,
              bottom: MediaQuery.of(context).padding.bottom,
              child: FloatingCartBar(
                cartCount: widget.cartCount,
                cartTotal: widget.cartTotal,
                onTap: widget.onOpenCart ?? () {},
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBackButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 0, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: _BackButton(onTap: widget.onBack),
      ),
    );
  }

  Widget _buildHero(Map<String, dynamic> restaurant, bool isOpen) {
    final img = restaurant['img'] as String? ?? '';
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
          // Bottom-to-top gradient so text is readable
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Color(0x330F0D0C),
                  Color(0xE60F0D0C),
                ],
                stops: [0.3, 0.65, 1.0],
              ),
            ),
          ),
          // Closed overlay
          if (!isOpen)
            Container(
              color: Colors.black.withValues(alpha: 0.55),
              alignment: Alignment.center,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  color: kSurface2,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: const Text(
                  'Closed now',
                  style: TextStyle(
                      color: kMuted,
                      fontWeight: FontWeight.w700,
                      fontSize: 14),
                ),
              ),
            ),
          // Restaurant name + badge at bottom of hero
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (restaurant['badge'] != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      restaurant['badge'] as String,
                      style: const TextStyle(
                          color: kInk,
                          fontSize: 11,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                Text(
                  restaurant['name'] as String? ?? '',
                  style: kSerif.copyWith(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.1,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoPills(
      dynamic rating, dynamic time, String fee, bool isOpen) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          if (rating != null) ...[
            _InfoPill(
              icon: Icons.star_rounded,
              iconColor: kGold,
              label: '$rating',
              labelColor: kGold,
            ),
            const SizedBox(width: 10),
          ],
          if (time != null) ...[
            _InfoPill(
              icon: Icons.access_time_rounded,
              iconColor: kMuted,
              label: '$time min',
              labelColor: kMuted,
            ),
            const SizedBox(width: 10),
          ],
          if (fee.isNotEmpty)
            _InfoPill(
              icon: fee == 'Free'
                  ? Icons.check_circle_rounded
                  : Icons.delivery_dining_rounded,
              iconColor: fee == 'Free' ? kGreen : kMuted,
              label:
                  fee == 'Free' ? 'Free delivery' : '$fee delivery',
              labelColor: fee == 'Free' ? kGreen : kMuted,
            ),
          const SizedBox(width: 10),
          _InfoPill(
            icon: Icons.circle,
            iconColor: isOpen ? kGreen : kRed,
            label: isOpen ? 'Open now' : 'Closed',
            labelColor: isOpen ? kGreen : kRed,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyMenu() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: kSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: kBorder),
              ),
              child: const Center(
                child: Text('🍽️', style: TextStyle(fontSize: 32)),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No items in this category',
              style: TextStyle(
                  color: kInk,
                  fontSize: 15,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'Try selecting a different category',
              style: TextStyle(color: kMuted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Back button — floats above everything ─────────────────────────────────────

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xCC0F0D0C),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.chevron_left, color: kInk, size: 24),
        ),
      ),
    );
  }
}

// ── Sticky category tab delegate ──────────────────────────────────────────────

class _CategoryTabDelegate extends SliverPersistentHeaderDelegate {
  final List<String> categories;
  final String selected;
  final void Function(String) onSelect;

  const _CategoryTabDelegate({
    required this.categories,
    required this.selected,
    required this.onSelect,
  });

  @override
  double get minExtent => 52;
  @override
  double get maxExtent => 52;

  @override
  bool shouldRebuild(_CategoryTabDelegate old) =>
      old.selected != selected || old.categories != categories;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: kCanvas,
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        physics: const BouncingScrollPhysics(),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final cat = categories[i];
          final active = selected == cat;
          return GestureDetector(
            onTap: () => onSelect(cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: active
                    ? kBrand.withValues(alpha: 0.15)
                    : Colors.transparent,
                border: Border.all(
                    color: active ? kBrand : kBorder),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                cat,
                style: TextStyle(
                  color: active ? kBrand : kMuted,
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
}

// ── Info pill ─────────────────────────────────────────────────────────────────

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final Color labelColor;

  const _InfoPill({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: kSurface,
        border: Border.all(color: kBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: labelColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// ── Menu item card ────────────────────────────────────────────────────────────

class _MenuItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;
  final VoidCallback? onAdd;

  const _MenuItemCard({
    required this.item,
    required this.onTap,
    this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final name = item['name'] as String? ?? 'Item';
    final description = item['description'] as String?;
    final price = item['price'] as num?;
    final img = item['img'] as String? ?? '';
    final rating = item['rating'] as num?;
    final tag = item['tag'] as String?;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: kSurface,
          border: Border.all(color: kSurface2),
          borderRadius: BorderRadius.circular(20),
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            // ── Image ──────────────────────────────────────────────────────
            SizedBox(
              width: 122,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AppImage(
                    url: img,
                    fit: BoxFit.cover,
                    width: 122,
                    height: 122,
                  ),
                  if (tag != null)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: kBrand,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          tag,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // ── Info ───────────────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Name + description
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                              color: kInk,
                              fontWeight: FontWeight.w800,
                              fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (description != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            description,
                            style: const TextStyle(
                                color: kMuted, fontSize: 12, height: 1.4),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                    // Price + rating + add button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              formatPeso(price),
                              style: const TextStyle(
                                  color: kBrand,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15),
                            ),
                            if (rating != null) ...[
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(Icons.star_rounded,
                                      size: 12, color: kGold),
                                  const SizedBox(width: 3),
                                  Text(
                                    '$rating',
                                    style: const TextStyle(
                                        color: kGold,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                        GestureDetector(
                          onTap: onAdd ?? onTap,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: kBrand,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(Icons.add,
                                color: Colors.white, size: 18),
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
        ),
      ),
    );
  }
}
