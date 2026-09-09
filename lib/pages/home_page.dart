import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants.dart';
import '../widgets/shared_cards.dart';
import '../widgets/floating_cart_bar.dart';
import '../providers/menu_providers.dart';

class HomePage extends StatefulWidget {
  final int cartCount;
  final void Function(Map<String, dynamic> item) onAddToCart;
  final VoidCallback onOpenCart;
  final void Function(String id) onViewItem;
  final void Function(String id) onViewRestaurant;
  final VoidCallback onSearchTap;
  final VoidCallback onOpenAddress;
  final String deliveryAddress;
  final VoidCallback onSeeAllCategories;
  final VoidCallback onSeeAllDishes;
  final VoidCallback onSeeAllRestaurants;
  /// When non-null, the home page will jump to this category filter.
  final String? initialCategory;

  const HomePage({
    super.key,
    required this.cartCount,
    required this.onAddToCart,
    required this.onOpenCart,
    required this.onViewItem,
    required this.onSearchTap,
    required this.onOpenAddress,
    required this.deliveryAddress,
    required this.onSeeAllCategories,
    required this.onSeeAllDishes,
    required this.onSeeAllRestaurants,
    required this.onViewRestaurant,
    this.initialCategory,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _activeCategory = 'All';

  @override
  void didUpdateWidget(HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialCategory != null &&
        widget.initialCategory != oldWidget.initialCategory) {
      setState(() => _activeCategory = widget.initialCategory!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final menuProvider = context.watch<MenuProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Pinned header (address + cart) ──────────────────────────────────
        const SizedBox(height: 4),
        _buildHeader(),
        const SizedBox(height: 14),
        // ── Scrollable body ─────────────────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSearchBar(),
                const SizedBox(height: 16),
                _buildHeroBanner(),
                const SizedBox(height: 20),
                _buildCategories(),
                const SizedBox(height: 20),
                _buildFeatured(menuProvider),
                const SizedBox(height: 20),
                _buildNearby(menuProvider),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: GestureDetector(
              onTap: widget.onOpenAddress,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.location_on, size: 13, color: kMuted),
                      SizedBox(width: 4),
                      Text(
                        'Delivering to',
                        style: TextStyle(color: kMuted, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          widget.deliveryAddress,
                          style: const TextStyle(color: kInk, fontSize: 15, fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.keyboard_arrow_down, size: 18, color: kBrand),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: widget.onOpenCart,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: kSurface,
                    border: Border.all(color: kBorder),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(child: Icon(Icons.shopping_cart_outlined, color: kInk, size: 20)),
                ),
                if (widget.cartCount > 0)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: CartCountBadge(count: widget.cartCount),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: widget.onSearchTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: kSurface,
            border: Border.all(color: kBorder),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            children: [
              Icon(Icons.search, size: 18, color: kMuted),
              SizedBox(width: 10),
              Text('Search dishes, restaurants...', style: TextStyle(color: kMuted, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [kBrand, kBrandDark, Color(0xFF8B1F00)],
          ),
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          children: [
            Positioned(
              right: -16,
              bottom: -16,
              child: Transform.rotate(
                angle: 0.26,
                child: const Opacity(
                  opacity: 0.2,
                  child: Icon(Icons.lunch_dining, size: 130, color: Colors.white),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'LIMITED OFFER',
                    style: TextStyle(
                      color: Color(0xBFFFFFFF),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '50% off your\nfirst order',
                    style: kSerif.copyWith(
                      color: Colors.white,
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                      height: 1.12,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(100)),
                    child: const Text(
                      'Use code SWIFT50',
                      style: TextStyle(color: kBrand, fontSize: 12, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategories() {
    final menuProvider = context.read<MenuProvider>();
    // Build category list dynamically: 'All' first, then unique values from
    // Firestore menu_items sorted alphabetically.
    final dynamic = menuProvider.allItems
        .map((item) => item['category'] as String? ?? '')
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final categories = ['All', ...dynamic];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Categories', style: TextStyle(color: kInk, fontSize: 17, fontWeight: FontWeight.w800)),
              GestureDetector(
                onTap: widget.onSeeAllCategories,
                child: const Text('See all', style: TextStyle(color: kBrand, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 44,
          child: menuProvider.isLoading
              ? const SizedBox.shrink()
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  physics: const BouncingScrollPhysics(),
                  itemCount: categories.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, i) {
                    final label = categories[i];
                    final isActive = _activeCategory == label;
                    final icon = kCategoryIcons[label] ?? Icons.restaurant;
                    return GestureDetector(
                      onTap: () => setState(() => _activeCategory = label),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isActive ? kBrand : kSurface,
                          border: Border.all(color: isActive ? kBrand : kBorder),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Row(
                          children: [
                            Icon(icon, size: 16, color: isActive ? Colors.white : kMuted),
                            const SizedBox(width: 6),
                            Text(
                              label,
                              style: TextStyle(
                                color: isActive ? Colors.white : kMuted,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFeatured(MenuProvider menuProvider) {
    final displayItems = _activeCategory == 'All'
        ? menuProvider.featuredItems
        : menuProvider.featuredItems.where((item) => item['category'] == _activeCategory).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Featured', style: TextStyle(color: kInk, fontSize: 17, fontWeight: FontWeight.w800)),
              GestureDetector(
                onTap: widget.onSeeAllDishes,
                child: const Text('See all', style: TextStyle(color: kBrand, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 252,
          child: menuProvider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : displayItems.isEmpty
                  ? const Center(child: Text('No featured items found.'))
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      physics: const BouncingScrollPhysics(),
                      itemCount: displayItems.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 14),
                      itemBuilder: (context, i) {
                        final dish = displayItems[i];
                        return GestureDetector(
                          onTap: () => widget.onViewItem('${dish['id']}'),
                          child: FeaturedCard(dish: dish, onAdd: () => widget.onAddToCart(dish)),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildNearby(MenuProvider menuProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Nearby restaurants', style: TextStyle(color: kInk, fontSize: 17, fontWeight: FontWeight.w800)),
              GestureDetector(
                onTap: widget.onSeeAllRestaurants,
                child: const Text('View all', style: TextStyle(color: kBrand, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (menuProvider.isLoading)
          const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
        else if (menuProvider.restaurants.isEmpty)
          const Center(child: Text('No restaurants found.'))
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: menuProvider.restaurants.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final restaurant = menuProvider.restaurants[i];
              return GestureDetector(
                onTap: () => widget.onViewRestaurant('${restaurant['id']}'),
                child: RestaurantCard(restaurant: restaurant),
              );
            }
          ),
      ],
    );
  }
}
