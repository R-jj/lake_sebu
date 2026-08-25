import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants.dart';
import '../../providers/owner_orders_provider.dart';
import 'owner_dashboard_page.dart';
import 'owner_orders_page.dart';
import 'owner_menu_page.dart';
import 'owner_restaurant_page.dart';
import 'owner_account_page.dart';

/// The root shell for restaurant-owner accounts.
///
/// Completely separate from [RootShell] (customer shell) — owners never
/// see customer pages and customers never see owner pages.
///
/// Navigation tabs:
///   Dashboard  │  Orders  │  Restaurant  │  Account
class OwnerRootShell extends StatefulWidget {
  const OwnerRootShell({super.key});

  @override
  State<OwnerRootShell> createState() => _OwnerRootShellState();
}

class _OwnerRootShellState extends State<OwnerRootShell> {
  int _tab = 0;

  static const _tabs = [
    _TabItem(
      id: 'dashboard',
      label: 'Dashboard',
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard,
    ),
    _TabItem(
      id: 'orders',
      label: 'Orders',
      icon: Icons.receipt_long_outlined,
      activeIcon: Icons.receipt_long,
    ),
    _TabItem(
      id: 'menu',
      label: 'Menu',
      icon: Icons.restaurant_menu_outlined,
      activeIcon: Icons.restaurant_menu,
    ),
    _TabItem(
      id: 'restaurant',
      label: 'Restaurant',
      icon: Icons.storefront_outlined,
      activeIcon: Icons.storefront,
    ),
    _TabItem(
      id: 'account',
      label: 'Account',
      icon: Icons.person_outline,
      activeIcon: Icons.person,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final pendingCount =
        context.watch<OwnerOrdersProvider>().pendingCount;

    return Scaffold(
      backgroundColor: kCanvas,
      body: SafeArea(
        child: IndexedStack(
          index: _tab,
          children: const [
            OwnerDashboardPage(),
            OwnerOrdersPage(),
            OwnerMenuPage(),
            OwnerRestaurantPage(),
            OwnerAccountPage(),
          ],
        ),
      ),
      bottomNavigationBar: _OwnerBottomNav(
        activeIndex: _tab,
        tabs: _tabs,
        pendingCount: pendingCount,
        onTap: (i) => setState(() => _tab = i),
      ),
    );
  }
}

// ── Tab descriptor ─────────────────────────────────────────────────────────────

class _TabItem {
  final String id;
  final String label;
  final IconData icon;
  final IconData activeIcon;

  const _TabItem({
    required this.id,
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
}

// ── Bottom nav ─────────────────────────────────────────────────────────────────

class _OwnerBottomNav extends StatelessWidget {
  final int activeIndex;
  final List<_TabItem> tabs;
  final int pendingCount;
  final ValueChanged<int> onTap;

  const _OwnerBottomNav({
    required this.activeIndex,
    required this.tabs,
    required this.pendingCount,
    required this.onTap,
  });

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
            children: List.generate(tabs.length, (i) {
              final tab = tabs[i];
              final isActive = activeIndex == i;
              // Show badge on Orders tab when there are pending orders.
              final showBadge = tab.id == 'orders' && pendingCount > 0;

              return GestureDetector(
                onTap: () => onTap(i),
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
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(
                            isActive ? tab.activeIcon : tab.icon,
                            size: 22,
                            color: isActive ? kBrand : kMuted,
                          ),
                          if (showBadge)
                            Positioned(
                              top: -4,
                              right: -6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: kBrand,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  pendingCount > 99
                                      ? '99+'
                                      : '$pendingCount',
                                  style: const TextStyle(
                                    color: kInk,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tab.label,
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
