import 'package:flutter/material.dart';
import 'constants.dart';
import 'models/cart_item.dart';
import 'pages/home_page.dart';
import 'pages/search_page.dart';
import 'pages/orders_page.dart';
import 'pages/profile_page.dart';
import 'pages/menu_detail_page.dart';
import 'pages/cart_page.dart';
import 'pages/address_page.dart';

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  // ── Navigation state ────────────────────────────────────────────────────────
  String _page = 'home';
  String? _viewingItemId;
  bool _showAddressPage = false;

  // ── Delivery address ────────────────────────────────────────────────────────
  String _deliveryAddress = '123 Main Street';

  // ── Cart state ──────────────────────────────────────────────────────────────
  final List<CartItem> _cartItems = [];

  int get _cartCount => _cartItems.fold(0, (sum, i) => sum + i.qty);

  // ── Navigation helpers ───────────────────────────────────────────────────────

  void _goTo(String page) => setState(() {
        _page = page;
        _viewingItemId = null;
        _showAddressPage = false;
      });

  void _openItem(String id) => setState(() => _viewingItemId = id);

  void _closeItem() => setState(() => _viewingItemId = null);

  void _openAddress() => setState(() => _showAddressPage = true);

  void _closeAddress() => setState(() => _showAddressPage = false);

  void _selectAddress(String addr) => setState(() => _deliveryAddress = addr);

  // ── Cart helpers ─────────────────────────────────────────────────────────────

  void _addToCart(Map<String, dynamic> item, {double? price}) {
    final basePrice = price ?? (item['price'] as num?)?.toDouble() ?? 0;
    setState(() {
      final idx = _cartItems.indexWhere((i) => i.id == '${item['id']}');
      if (idx != -1) {
        _cartItems[idx] =
            _cartItems[idx].copyWith(qty: _cartItems[idx].qty + 1);
      } else {
        _cartItems.add(CartItem(
          id: '${item['id']}',
          name: item['name'] as String? ?? 'Item',
          restaurant: item['restaurantName'] as String? ??
              item['restaurant'] as String? ??
              'Restaurant',
          price: basePrice,
          img: item['img'] as String? ?? '',
        ));
      }
    });
  }

  void _addFromDetail(Map<String, dynamic> item, double price) =>
      _addToCart(item, price: price);

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

  @override
  Widget build(BuildContext context) {
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
              deliveryAddress: _deliveryAddress,
            ),
            SearchPage(onViewItem: _openItem),
            const OrdersPage(),
            ProfilePage(onViewItem: _openItem),
            CartPage(
              items: _cartItems,
              onUpdate: _updateCartItem,
              onNav: _goTo,
              deliveryAddress: _deliveryAddress,
              onChangeAddress: _openAddress,
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
