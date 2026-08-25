import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_profile_provider.dart';

/// Account / profile page for restaurant owners.
///
/// Shows:
///   • Owner's display name and email
///   • Linked restaurant ID (for transparency / debugging)
///   • Sign-out button
///
/// Intentionally minimal — owners do not need address books, payment
/// methods, rewards, or the other customer-specific settings.
class OwnerAccountPage extends StatelessWidget {
  const OwnerAccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AppAuthProvider>();
    final profile = context.watch<UserProfileProvider>().profile;

    final displayName = profile?.displayName.isNotEmpty == true
        ? profile!.displayName
        : auth.user?.name ?? 'Owner';
    final email = profile?.email ?? auth.user?.email ?? '';
    final restaurantId = auth.restaurantId ?? '—';
    final initial = displayName.isNotEmpty
        ? displayName[0].toUpperCase()
        : 'O';

    return Scaffold(
      backgroundColor: kCanvas,
      body: CustomScrollView(
        slivers: [
          // ── Header ───────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Text(
                'Account',
                style: kSerif.copyWith(
                  color: kInk,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),

          // ── Avatar + name ─────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: kBrand.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: kBrand.withValues(alpha: 0.3), width: 1.5),
                    ),
                    child: Center(
                      child: Text(
                        initial,
                        style: kSerif.copyWith(
                          color: kBrand,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(
                            color: kInk,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          email,
                          style: const TextStyle(
                              color: kMuted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  // Role badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: kBrand.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: kBrand.withValues(alpha: 0.25)),
                    ),
                    child: const Text(
                      'Owner',
                      style: TextStyle(
                          color: kBrand,
                          fontSize: 11,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Restaurant info ───────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: kSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: kBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.storefront_outlined,
                        color: kMuted, size: 18),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Restaurant ID',
                            style: TextStyle(color: kMuted, fontSize: 11),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            restaurantId,
                            style: const TextStyle(
                                color: kInk,
                                fontSize: 13,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Sign out ──────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: _SignOutTile(),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}

// ── Sign-out tile ──────────────────────────────────────────────────────────────

class _SignOutTile extends StatefulWidget {
  @override
  State<_SignOutTile> createState() => _SignOutTileState();
}

class _SignOutTileState extends State<_SignOutTile> {
  bool _signingOut = false;

  Future<void> _signOut() async {
    setState(() => _signingOut = true);
    await context.read<AppAuthProvider>().signOut();
    // _AuthGate will rebuild automatically — no navigation needed.
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _signingOut ? null : _signOut,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: kRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.logout_rounded,
                  color: kRed, size: 18),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Text(
                'Sign Out',
                style: TextStyle(
                    color: kRed,
                    fontSize: 15,
                    fontWeight: FontWeight.w600),
              ),
            ),
            if (_signingOut)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    color: kRed, strokeWidth: 2),
              )
            else
              const Icon(Icons.chevron_right_rounded,
                  color: kMuted, size: 20),
          ],
        ),
      ),
    );
  }
}
