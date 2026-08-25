import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../../constants.dart';
import '../../providers/auth_provider.dart';
import '../../services/owner_repository.dart';

/// Displays the restaurant's Firestore document for the owner.
///
/// Read-only for now — shows whatever fields exist on the document.
/// Common fields rendered with dedicated rows; any extra fields are shown
/// in a generic "Details" section so the page works regardless of the
/// exact Firestore schema.
class OwnerRestaurantPage extends StatefulWidget {
  const OwnerRestaurantPage({super.key});

  @override
  State<OwnerRestaurantPage> createState() => _OwnerRestaurantPageState();
}

class _OwnerRestaurantPageState extends State<OwnerRestaurantPage> {
  Map<String, dynamic>? _restaurant;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rid = context.read<AppAuthProvider>().restaurantId!;
      debugPrint('OwnerRestaurantPage: loading restaurantId="$rid"');
      final data = await OwnerRepository.instance.fetchRestaurant(rid);
      debugPrint('OwnerRestaurantPage: fetchRestaurant returned ${data == null ? "null" : "data with keys ${data.keys}"}');
      if (mounted) {
        setState(() {
          _restaurant = data;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('OwnerRestaurantPage: error $e');
      if (mounted) {
        setState(() {
          _error = 'Could not load restaurant information. Please try again.';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kCanvas,
      body: RefreshIndicator(
        color: kBrand,
        backgroundColor: kSurface,
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                child: Text(
                  'Restaurant',
                  style: kSerif.copyWith(
                    color: kInk,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            if (_loading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(
                      color: kBrand, strokeWidth: 2),
                ),
              )
            else if (_error != null)
              SliverFillRemaining(
                child: _ErrorView(message: _error!, onRetry: _load),
              )
            else if (_restaurant == null)
              SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Restaurant not found.',
                          style: TextStyle(color: kMuted),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Looking for ID: "${context.read<AppAuthProvider>().restaurantId}"',
                          style: const TextStyle(color: kMuted, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverToBoxAdapter(
                child: _RestaurantBody(data: _restaurant!),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Restaurant body ────────────────────────────────────────────────────────────

class _RestaurantBody extends StatelessWidget {
  final Map<String, dynamic> data;

  const _RestaurantBody({required this.data});

  @override
  Widget build(BuildContext context) {
    final name = data['name'] as String? ?? '—';
    final cuisine = data['cuisine'] as String? ?? data['category'] as String?;
    final description =
        data['description'] as String? ?? data['about'] as String?;
    final imageUrl = data['img'] as String? ??
        data['image'] as String? ??
        data['imageUrl'] as String?;
    final rating = data['rating'];
    final openTime = data['openTime'] as String? ?? data['hours'] as String?;
    final phone = data['phone'] as String? ?? data['phoneNumber'] as String?;
    final address = data['address'] as String?;

    // Fields already rendered above — exclude from the generic section.
    const knownKeys = {
      'id', 'name', 'cuisine', 'category', 'description', 'about',
      'img', 'image', 'imageUrl', 'rating', 'openTime', 'hours',
      'phone', 'phoneNumber', 'address',
    };
    final extras = Map.fromEntries(
      data.entries.where((e) => !knownKeys.contains(e.key)),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Hero image ─────────────────────────────────────────────────
          if (imageUrl != null && imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                imageUrl,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: kSurface2,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.storefront_outlined,
                      color: kMuted, size: 48),
                ),
              ),
            ),

          if (imageUrl != null && imageUrl.isNotEmpty)
            const SizedBox(height: 20),

          // ── Name + cuisine ─────────────────────────────────────────────
          Text(
            name,
            style: kSerif.copyWith(
              color: kInk,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (cuisine != null) ...[
            const SizedBox(height: 4),
            Text(cuisine,
                style: const TextStyle(color: kMuted, fontSize: 14)),
          ],
          const SizedBox(height: 20),

          // ── Info card ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kBorder),
            ),
            child: Column(
              children: [
                if (rating != null)
                  _InfoTile(
                    icon: Icons.star_rounded,
                    iconColor: kGold,
                    label: 'Rating',
                    value: '$rating',
                  ),
                if (openTime != null) ...[
                  if (rating != null) const _Divider(),
                  _InfoTile(
                    icon: Icons.access_time_rounded,
                    iconColor: kBrand,
                    label: 'Hours',
                    value: openTime,
                  ),
                ],
                if (phone != null) ...[
                  const _Divider(),
                  _InfoTile(
                    icon: Icons.phone_outlined,
                    iconColor: kMuted,
                    label: 'Phone',
                    value: phone,
                  ),
                ],
                if (address != null) ...[
                  const _Divider(),
                  _InfoTile(
                    icon: Icons.location_on_outlined,
                    iconColor: kMuted,
                    label: 'Address',
                    value: address,
                  ),
                ],
              ],
            ),
          ),

          // ── Description ────────────────────────────────────────────────
          if (description != null && description.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'About',
              style: kSerif.copyWith(
                color: kInk,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(description,
                style: const TextStyle(
                    color: kMuted, fontSize: 14, height: 1.5)),
          ],

          // ── Extra fields ───────────────────────────────────────────────
          if (extras.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Details',
              style: kSerif.copyWith(
                color: kInk,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kBorder),
              ),
              child: Column(
                children: extras.entries.map((e) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${e.key}:',
                          style: const TextStyle(
                              color: kMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${e.value}',
                            style: const TextStyle(
                                color: kInk, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Shared small widgets ───────────────────────────────────────────────────────

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style:
                      const TextStyle(color: kMuted, fontSize: 11)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      color: kInk, fontSize: 14)),
            ],
          ),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) =>
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Divider(color: kBorder, height: 1),
      );
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.storefront_outlined, color: kMuted, size: 48),
            const SizedBox(height: 12),
            Text(message,
                style: const TextStyle(color: kMuted, fontSize: 14),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kBrand,
                foregroundColor: kInk,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
