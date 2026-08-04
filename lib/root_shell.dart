import 'package:flutter/material.dart';
import 'constants.dart';
import 'models/cart_item.dart';
import 'pages/home_page.dart';
import 'pages/search_page.dart';
import 'pages/orders_page.dart';
import 'pages/profile_page.dart';
import 'pages/menu_detail_page.dart';
import 'pages/cart_page.dart';

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  // Which stack is shown in the bottom nav: home / search / orders / profile / cart
  String _page = 'home';
  // Non-null when the menu detail page is open
  String? _viewingItemId;

  final List<CartItem> _cartItems = [];

  int get _cartCount => _cartItems.fold(0, (sum, i) => sum + i.qty);

  void _goTo(String page) => setState(() {
        _page = page;
        _viewingItemId = null;
      });

  void _openItem(String id) => setState(() => _viewingItemId = id);

  void _closeItem() => setState(() => _viewingItemId = null);

  void _addToCart(Map<String, dynamic> item, {double? price}) {
    final basePrice = price ?? (item['price'] as num?)?.toDouble() ?? 0;
    setState(() {
      final existing = _cartItems.indexWhere((i) => i.id == '${item['id']}');
      if (existing != -1) {
        _cartItems[existing] = _cartItems[existing].copyWith(qty: _cartItems[existing].qty + 1);
      } else {
        _cartItems.add(CartItem(
          id: '${item['id']}',
          name: item['name'] as String? ?? 'Item',
          restaurant: item['restaurantName'] as String? ?? item['restaurant'] as String? ?? 'Restaurant',
          price: basePrice,
          img: item['img'] as String? ?? '',
        ));
      }
    });
  }

  void _addFromDetail(Map<String, dynamic> item, double price) => _addToCart(item, price: price);

  void _updateCartItem(String id, int qty) {
    setState(() {
      _cartItems.removeWhere((i) => i.id == id && qty <= 0);
      for (var i = 0; i < _cartItems.length; i++) {
        if (_cartItems[i].id == id) {
          _cartItems[i] = _cartItems[i].copyWith(qty: qty.clamp(1, 99));
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kCanvas,
      body: SafeArea(
        child: _viewingItemId != null
            ? MenuDetailPage(
                itemId: _viewingItemId!,
                onBack: _closeItem,
                onAddToCart: _addFromDetail,
                onViewItem: _openItem,
              )
            : IndexedStack(
                index: _pageIndex(_page),
                children: [
                  HomePage(
                    cartCount: _cartCount,
                    onAddToCart: _addToCart,
                    onOpenCart: () => _goTo('cart'),
                    onViewItem: _openItem,
                    onSearchTap: () => _goTo('search'),
                  ),
                  SearchPage(onViewItem: _openItem),
                  const OrdersPage(),
                  const ProfilePage(),
                  CartPage(items: _cartItems, onUpdate: _updateCartItem, onNav: _goTo),
                ],
              ),
      ),
      bottomNavigationBar: _viewingItemId == null
          ? BottomNav(active: _page, onNav: _goTo)
          : null,
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

// ── Bottom Nav ───────────────────────────────────────────────────────────────

class BottomNav extends StatelessWidget {
  final String active;
  final ValueChanged<String> onNav;

  const BottomNav({super.key, required this.active, required this.onNav});

  static const _items = [
    {'id': 'home', 'icon': Icons.home_outlined, 'activeIcon': Icons.home, 'label': 'Home'},
    {'id': 'search', 'icon': Icons.search, 'activeIcon': Icons.search, 'label': 'Search'},
    {'id': 'orders', 'icon': Icons.receipt_long_outlined, 'activeIcon': Icons.receipt_long, 'label': 'Orders'},
    {'id': 'profile', 'icon': Icons.person_outline, 'activeIcon': Icons.person, 'label': 'Profile'},
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
                        isActive ? item['activeIcon'] as IconData : item['icon'] as IconData,
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
