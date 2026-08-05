import 'package:flutter/material.dart';
import '../constants.dart';
import 'saved_addresses_page.dart';
import 'favourites_page.dart';
import 'payment_methods_page.dart';
import 'rewards_page.dart';
import 'help_page.dart';
import 'account_settings_page.dart';

// ── Profile sub-page enum ─────────────────────────────────────────────────────

enum _SubPage { addresses, payment, rewards, favourites, help, settings }

// ── Profile page ──────────────────────────────────────────────────────────────

class ProfilePage extends StatefulWidget {
  final void Function(String id) onViewItem;

  const ProfilePage({super.key, required this.onViewItem});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  _SubPage? _subPage;

  @override
  Widget build(BuildContext context) {
    // Render active sub-page full-screen inside the profile slot.
    if (_subPage != null) {
      return _buildSubPage(_subPage!);
    }
    return _buildMain();
  }

  Widget _buildSubPage(_SubPage page) {
    void back() => setState(() => _subPage = null);
    switch (page) {
      case _SubPage.addresses:
        return SavedAddressesPage(onBack: back);
      case _SubPage.payment:
        return PaymentMethodsPage(onBack: back);
      case _SubPage.rewards:
        return RewardsPage(onBack: back);
      case _SubPage.favourites:
        return FavouritesPage(onBack: back, onViewItem: (id) {
          setState(() => _subPage = null);
          widget.onViewItem(id);
        });
      case _SubPage.help:
        return HelpPage(onBack: back);
      case _SubPage.settings:
        return AccountSettingsPage(onBack: back);
    }
  }

  // ── Main profile view ───────────────────────────────────────────────────────

  Widget _buildMain() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHero(),
          _buildStats(),
          _buildMenuSection(),
          const SizedBox(height: 20),
          _buildPreferencesSection(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: kRed.withValues(alpha: 0.08),
                border: Border.all(color: kRed.withValues(alpha: 0.2)),
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: const Text('Sign out',
                  style: TextStyle(
                      color: kRed, fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [kSurface, kCanvas],
        ),
      ),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [kBrand, Color(0xFF8B1F00)],
                  ),
                ),
                child: const Center(
                    child: Icon(Icons.person, size: 40, color: Colors.white)),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () => setState(() => _subPage = _SubPage.settings),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: kBrand,
                      shape: BoxShape.circle,
                      border: Border.all(color: kCanvas, width: 2),
                    ),
                    child: const Center(
                        child: Icon(Icons.edit, size: 12, color: Colors.white)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Alex Rivera',
              style: kSerif.copyWith(
                  color: kInk, fontWeight: FontWeight.w900, fontSize: 20)),
          const SizedBox(height: 4),
          const Text('alex.rivera@email.com',
              style: TextStyle(color: kMuted, fontSize: 13)),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => setState(() => _subPage = _SubPage.rewards),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: kGold.withValues(alpha: 0.12),
                border: Border.all(color: kGold.withValues(alpha: 0.25)),
                borderRadius: BorderRadius.circular(100),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.emoji_events, size: 15, color: kGold),
                  SizedBox(width: 6),
                  Text('Gold Member · 1,240 pts',
                      style: TextStyle(
                          color: kGold,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    final stats = [
      {'value': '34', 'label': 'Orders', 'showStar': false},
      {'value': '4.9', 'label': 'Rating', 'showStar': true},
      {'value': '₱12,480', 'label': 'Spent', 'showStar': false},
    ];
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      decoration:
          BoxDecoration(color: kBorder, borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.hardEdge,
      child: Row(
        children: stats.map((s) {
          final showStar = s['showStar'] as bool;
          return Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              margin: const EdgeInsets.all(0.5),
              color: kSurface,
              child: Column(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(s['value'] as String,
                          style: kSerif.copyWith(
                              color: kBrand,
                              fontWeight: FontWeight.w900,
                              fontSize: 18)),
                      if (showStar) ...[
                        const SizedBox(width: 2),
                        const Icon(Icons.star, size: 15, color: kBrand),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(s['label'] as String,
                      style: const TextStyle(color: kMuted, fontSize: 11)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMenuSection() {
    final items = <Map<String, dynamic>>[
      {
        'icon': Icons.location_on_outlined,
        'label': 'Saved addresses',
        'sub': '3 saved locations',
        'page': _SubPage.addresses,
      },
      {
        'icon': Icons.credit_card,
        'label': 'Payment methods',
        'sub': 'Visa ••••4821',
        'page': _SubPage.payment,
      },
      {
        'icon': Icons.card_giftcard,
        'label': 'Rewards & points',
        'sub': '1,240 pts · Gold member',
        'page': _SubPage.rewards,
      },
      {
        'icon': Icons.favorite_border,
        'label': 'Favourites',
        'sub': '4 saved items',
        'page': _SubPage.favourites,
      },
      {
        'icon': Icons.support_agent,
        'label': 'Help & support',
        'sub': 'FAQs, live chat',
        'page': _SubPage.help,
      },
      {
        'icon': Icons.settings_outlined,
        'label': 'Account settings',
        'sub': 'Privacy, security',
        'page': _SubPage.settings,
      },
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ACCOUNT',
              style: TextStyle(
                  color: kMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1)),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: kSurface,
              border: Border.all(color: kSurface2),
              borderRadius: BorderRadius.circular(18),
            ),
            clipBehavior: Clip.hardEdge,
            child: Column(
              children: List.generate(items.length, (i) {
                final item = items[i];
                return Column(
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () =>
                          setState(() => _subPage = item['page'] as _SubPage),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                  color: kSurface2,
                                  borderRadius: BorderRadius.circular(12)),
                              child: Center(
                                  child: Icon(item['icon'] as IconData,
                                      size: 19, color: kInk)),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item['label'] as String,
                                      style: const TextStyle(
                                          color: kInk,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 1),
                                  Text(item['sub'] as String,
                                      style: const TextStyle(
                                          color: kMuted, fontSize: 11)),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right,
                                color: kBorder, size: 18),
                          ],
                        ),
                      ),
                    ),
                    if (i < items.length - 1)
                      const Divider(
                          height: 1,
                          color: kSurface2,
                          indent: 16,
                          endIndent: 16),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferencesSection() {
    // Kept as a lightweight preferences block (full toggles live in AccountSettingsPage).
    return const SizedBox.shrink();
  }
}
