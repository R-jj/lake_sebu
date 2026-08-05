import 'package:flutter/material.dart';
import '../constants.dart';
import '_sub_page_shell.dart';

class RewardsPage extends StatelessWidget {
  final VoidCallback onBack;

  const RewardsPage({super.key, required this.onBack});

  static const int _pts = 1240;
  static const int _nextTier = 2000;

  static const _history = [
    {'label': 'Double Smash Burger order', 'pts': 120, 'date': 'Jul 28'},
    {'label': 'Referred a friend', 'pts': 300, 'date': 'Jul 20'},
    {'label': 'Redeemed reward', 'pts': -200, 'date': 'Jul 15'},
    {'label': 'Pizza order', 'pts': 185, 'date': 'Jul 3'},
  ];

  @override
  Widget build(BuildContext context) {
    return SubPageShell(
      title: 'Rewards & points',
      subtitle: 'Gold Member tier',
      onBack: onBack,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPointsCard(),
            const SizedBox(height: 24),
            _buildRedeemSection(),
            const SizedBox(height: 24),
            _buildHistorySection(),
          ],
        ),
      ),
    );
  }

  Widget _buildPointsCard() {
    final progress = _pts / _nextTier;
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8B1F00), kBrandDark, kBrand],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Your balance',
              style: TextStyle(color: Color(0xB3FFFFFF), fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            _pts.toString(),
            style: kSerif.copyWith(
                color: Colors.white, fontSize: 48, fontWeight: FontWeight.w900, height: 1),
          ),
          const Text('points',
              style: TextStyle(color: Color(0xB3FFFFFF), fontSize: 13)),
          const SizedBox(height: 20),
          Text(
            'Progress to Platinum · ${_nextTier - _pts} pts to go',
            style: const TextStyle(color: Color(0xB3FFFFFF), fontSize: 12),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(kGold),
            ),
          ),
          const SizedBox(height: 6),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('🥇 Gold', style: TextStyle(color: Color(0x99FFFFFF), fontSize: 11)),
              Text('🏆 Platinum', style: TextStyle(color: Color(0x99FFFFFF), fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRedeemSection() {
    const redeemList = [
      {'label': 'Free delivery', 'pts': 300, 'icon': '🛵'},
      {'label': '10% off order', 'pts': 500, 'icon': '🏷️'},
      {'label': 'Free dessert', 'pts': 750, 'icon': '🍰'},
      {'label': '₱580 voucher', 'pts': 1000, 'icon': '💵'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('REDEEM REWARDS',
            style: TextStyle(
                color: kMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.15,
          children: redeemList.map((r) {
            final pts = r['pts'] as int;
            final canRedeem = _pts >= pts;
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: kSurface,
                border: Border.all(color: canRedeem ? kBorder : kSurface2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r['icon'] as String, style: const TextStyle(fontSize: 28)),
                  const SizedBox(height: 8),
                  Text(r['label'] as String,
                      style: const TextStyle(
                          color: kInk, fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('$pts pts',
                      style: TextStyle(
                          color: canRedeem ? kGold : kMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: canRedeem ? kBrand : kSurface2,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      canRedeem ? 'Redeem' : 'Not enough pts',
                      style: TextStyle(
                        color: canRedeem ? Colors.white : kMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('POINTS HISTORY',
            style: TextStyle(
                color: kMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: kSurface,
            border: Border.all(color: kSurface2),
            borderRadius: BorderRadius.circular(18),
          ),
          clipBehavior: Clip.hardEdge,
          child: Column(
            children: List.generate(_history.length, (i) {
              final h = _history[i];
              final pts = h['pts'] as int;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(h['label'] as String,
                                  style: const TextStyle(
                                      color: kInk, fontSize: 14, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text(h['date'] as String,
                                  style: const TextStyle(color: kMuted, fontSize: 12)),
                            ],
                          ),
                        ),
                        Text(
                          pts > 0 ? '+$pts' : '$pts',
                          style: TextStyle(
                              color: pts > 0 ? kGreen : kRed,
                              fontSize: 15,
                              fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                  if (i < _history.length - 1)
                    const Divider(height: 1, color: kSurface2, indent: 16, endIndent: 16),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }
}
