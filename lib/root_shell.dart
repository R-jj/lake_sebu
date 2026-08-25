import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'constants.dart';
import 'models/cart_item.dart';
import 'pages/home_page.dart';
import 'pages/search_page.dart';
import 'pages/orders_page.dart';
import 'pages/profile_page.dart';
import 'pages/menu_detail_page.dart';
import 'pages/cart_page.dart';
import 'pages/address_page.dart';
import 'pages/all_categories_page.dart';
import 'pages/all_dishes_page.dart';
import 'pages/restaurant_page.dart';
import 'pages/all_restaurants_page.dart';
import 'providers/user_profile_provider.dart';

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  // ── Navigation state ────────────────────────────────────────────────────────
  String _page = 'home';
  String? _viewingItemId;
  String? _viewingRestaurantId;
  bool _showAddressPage = false;

  // ── See-all overlays ─────────────────────────────────────────────────────────
  // null | 'categories' | 'dishes' | 'restaurants'
  String? _seeAllPage;

  // ── Delivery address ────────────────────────────────────────────────────────
  // Starts empty; populated from the user's saved default address once
  // UserProfileProvider loads. Falls back to a prompt if no address is saved.
  String _deliveryAddress = '';

  // ── Cart state ──────────────────────────────────────────────────────────────
  final List<CartItem> _cartItems = [];

  int get _cartCount => _cartItems.fold(0, (sum, i) => sum + i.qty);
  double get _cartTotal => _cartItems.fold(0.0, (sum, i) => sum + i.price * i.qty);

  // ── Navigation helpers ───────────────────────────────────────────────────────

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Keep _deliveryAddress in sync with the user's saved default address.
    // Only update when the user hasn't manually picked a different address
    // this session (i.e. _deliveryAddress is still empty = first load).
    if (_deliveryAddress.isEmpty) {
      final defaultAddr =
          context.read<UserProfileProvider>().defaultAddress?.label;
      if (defaultAddr != null && defaultAddr.isNotEmpty) {
        _deliveryAddress = defaultAddr;
      }
    }
  }

  void _goTo(String page) => setState(() {
        _page = page;
        _viewingItemId = null;
        _viewingRestaurantId = null;
        _showAddressPage = false;
        _seeAllPage = null;
      });

  void _openItem(String id) => setState(() => _viewingItemId = id);

  void _closeItem() => setState(() => _viewingItemId = null);

  void _openAddress() => setState(() => _showAddressPage = true);

  void _closeAddress() => setState(() => _showAddressPage = false);

  void _selectAddress(String addr) => setState(() => _deliveryAddress = addr);

  void _openSeeAll(String page) => setState(() => _seeAllPage = page);

  void _closeSeeAll() => setState(() => _seeAllPage = null);

  void _openRestaurant(String id) => setState(() => _viewingRestaurantId = id);

  void _closeRestaurant() => setState(() => _viewingRestaurantId = null);

  // ── Cart helpers ─────────────────────────────────────────────────────────────

  void _addToCart(Map<String, dynamic> item, {double? price, int qty = 1}) {
    final basePrice = price ?? (item['price'] as num?)?.toDouble() ?? 0;
    final addQty = qty.clamp(1, 99);
    setState(() {
      final idx = _cartItems.indexWhere((i) => i.id == '${item['id']}');
      if (idx != -1) {
        _cartItems[idx] =
            _cartItems[idx].copyWith(qty: _cartItems[idx].qty + addQty);
      } else {
        _cartItems.add(CartItem(
          id: '${item['id']}',
          name: item['name'] as String? ?? 'Item',
          restaurant: item['restaurantName'] as String? ??
              item['restaurant'] as String? ??
              'Restaurant',
          restaurantId: item['restaurantId'] as String? ?? '',
          price: basePrice,
          img: item['img'] as String? ?? '',
          qty: addQty,
        ));
      }
    });
  }

  void _addFromDetail(Map<String, dynamic> item, double price, {int qty = 1}) =>
      _addToCart(item, price: price, qty: qty);

  void _updateCartItem(String id, int qty) {
    setState(() {
      if (qty <= 0) {
        _cartItems.removeWhere((i) => i.id == id);
      } else {
        for (var i = 0; i < _cartItems.length; i++) {
          if (_cartItems[i].id == id) {
            _cartItems[i] = _cartItems[i].copyWith(qty: qty.clamp(1, 99));
          }
        }
      }
    });
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  /// Returns true when there is an overlay layer that the back button can close.
  bool get _canPop =>
      _showAddressPage ||
      _seeAllPage != null ||
      _viewingItemId != null ||
      _viewingRestaurantId != null ||
      _page == 'cart';

  void _handlePop() {
    if (_showAddressPage) {
      _closeAddress();
    } else if (_viewingItemId != null) {
      _closeItem();
    } else if (_viewingRestaurantId != null) {
      _closeRestaurant();
    } else if (_seeAllPage != null) {
      _closeSeeAll();
    } else if (_page == 'cart') {
      _goTo('home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _canPop) _handlePop();
      },
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    // Keep delivery address in sync with the user's default saved address
    // whenever the provider updates (e.g. after the Firestore stream delivers
    // addresses for the first time, or the user changes their default).
    // Only auto-fill when the user hasn't manually chosen an address yet.
    final profileProvider = context.watch<UserProfileProvider>();
    if (_deliveryAddress.isEmpty) {
      final defaultAddr = profileProvider.defaultAddress?.label;
      if (defaultAddr != null && defaultAddr.isNotEmpty) {
        // Schedule after build to avoid setState-during-build.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _deliveryAddress.isEmpty) {
            setState(() => _deliveryAddress = defaultAddr);
          }
        });
      }
    }

    // Address picker overlays everything (including the menu detail page).
    if (_showAddressPage) {
      return Scaffold(
        backgroundColor: kCanvas,
        body: SafeArea(
          child: AddressPage(
            current: _deliveryAddress,
            onSelect: _selectAddress,
            onBack: _closeAddress,
          ),
        ),
      );
    }

    // See-all overlays — full-screen, hide bottom nav.
    if (_seeAllPage == 'categories') {
      return Scaffold(
        backgroundColor: kCanvas,
        body: SafeArea(
          child: AllCategoriesPage(
            onBack: _closeSeeAll,
            onSelectCategory: (_) => _closeSeeAll(),
          ),
        ),
      );
    }
    if (_seeAllPage == 'dishes') {
      return Scaffold(
        backgroundColor: kCanvas,
        body: SafeArea(
          child: AllDishesPage(
            onBack: _closeSeeAll,
            onViewItem: (id) {
              _closeSeeAll();
              _openItem(id);
            },
            onAddToCart: _addToCart,
            cartCount: _cartCount,
            cartTotal: _cartTotal,
            onOpenCart: () => _goTo('cart'),
          ),
        ),
      );
    }
    if (_seeAllPage == 'restaurants') {
      return Scaffold(
        backgroundColor: kCanvas,
        body: SafeArea(
          child: AllRestaurantsPage(
            onBack: _closeSeeAll,
            onViewItem: (id) {
              _closeSeeAll();
              _openItem(id);
            },

            onViewRestaurant: (id) {
              _closeSeeAll();
              _openRestaurant(id);
            },
          ),
        ),
      );
    }

    // Menu detail page — full-screen overlay, hides bottom nav.
    if (_viewingItemId != null) {
      return Scaffold(
        backgroundColor: kCanvas,
        body: SafeArea(
          child: MenuDetailPage(
            itemId: _viewingItemId!,
            onBack: _closeItem,
            onAddToCart: _addFromDetail,
            onViewItem: _openItem,
            onViewRestaurant: (id) {
              _closeItem();
              _openRestaurant(id);
            },
            cartCount: _cartCount,
            cartTotal: _cartTotal,
            onOpenCart: () => _goTo('cart'),
          ),
        ),
      );
    }

    if (_viewingRestaurantId != null) {
      return Scaffold(
        backgroundColor: kCanvas,
        body: SafeArea(
          child: RestaurantPage(
            restaurantId: _viewingRestaurantId!,
            onBack: _closeRestaurant,
            onViewItem: _openItem,
            onAddToCart: _addToCart,
            cartCount: _cartCount,
            cartTotal: _cartTotal,
            onOpenCart: () => _goTo('cart'),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: kCanvas,
      body: SafeArea(
        child: IndexedStack(
          index: _pageIndex(_page),
          children: [
            HomePage(
              cartCount: _cartCount,
              onAddToCart: _addToCart,
              onOpenCart: () => _goTo('cart'),
              onViewItem: _openItem,
              onSearchTap: () => _goTo('search'),
              onOpenAddress: _openAddress,
              deliveryAddress: _deliveryAddress.isEmpty
                  ? 'Set delivery address'
                  : _deliveryAddress,
              onSeeAllCategories: () => _openSeeAll('categories'),
              onSeeAllDishes: () => _openSeeAll('dishes'),
              onSeeAllRestaurants: () => _openSeeAll('restaurants'),
              onViewRestaurant: _openRestaurant
            ),
            SearchPage(onViewItem: _openItem),
            const OrdersPage(),
            ProfilePage(onViewItem: _openItem),
            CartPage(
              items: _cartItems,
              onUpdate: _updateCartItem,
              onNav: _goTo,
              deliveryAddress: _deliveryAddress.isEmpty
                  ? 'Set delivery address'
                  : _deliveryAddress,
              onChangeAddress: _openAddress,
              onClearCart: () => setState(() => _cartItems.clear()),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNav(active: _page, onNav: _goTo),
    );
  }

  int _pageIndex(String page) {
    switch (page) {
      case 'search':
        return 1;
      case 'orders':
        return 2;
      case 'profile':
        return 3;
      case 'cart':
        return 4;
      default:
        return 0;
    }
  }
}

// ── Bottom Nav ────────────────────────────────────────────────────────────────

class BottomNav extends StatelessWidget {
  final String active;
  final ValueChanged<String> onNav;

  const BottomNav({super.key, required this.active, required this.onNav});

  static const _items = [
    {
      'id': 'home',
      'icon': Icons.home_outlined,
      'activeIcon': Icons.home,
      'label': 'Home',
    },
    {
      'id': 'search',
      'icon': Icons.search,
      'activeIcon': Icons.search,
      'label': 'Search',
    },
    {
      'id': 'orders',
      'icon': Icons.receipt_long_outlined,
      'activeIcon': Icons.receipt_long,
      'label': 'Orders',
    },
    {
      'id': 'profile',
      'icon': Icons.person_outline,
      'activeIcon': Icons.person,
      'label': 'Profile',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: kSurface,
        border: Border(top: BorderSide(color: kBorder)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 66,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_items.length, (i) {
              final item = _items[i];
              final id = item['id'] as String;
              final isActive = active == id;
              return GestureDetector(
                onTap: () => onNav(id),
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: 72,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isActive)
                        Container(
                          width: 32,
                          height: 3,
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            color: kBrand,
                            borderRadius: BorderRadius.circular(100),
                          ),
                        )
                      else
                        const SizedBox(height: 9),
                      Icon(
                        isActive
                            ? item['activeIcon'] as IconData
                            : item['icon'] as IconData,
                        size: 22,
                        color: isActive ? kBrand : kMuted,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item['label'] as String,
                        style: TextStyle(
                          color: isActive ? kBrand : kMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
