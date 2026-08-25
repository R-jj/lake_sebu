import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants.dart';
import '../../providers/owner_menu_provider.dart';
import '../../services/menu_image_service.dart';
import '../../widgets/app_image.dart';
import 'owner_add_edit_menu_item_page.dart';

/// The owner's menu management page — lists all menu items for their
/// restaurant with add / edit / delete actions.
class OwnerMenuPage extends StatelessWidget {
  const OwnerMenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OwnerMenuProvider>();

    return Scaffold(
      backgroundColor: kCanvas,
      body: RefreshIndicator(
        color: kBrand,
        backgroundColor: kSurface,
        onRefresh: () async {
          // The stream auto-refreshes; this pull-to-refresh just gives
          // the user a satisfying gesture. We re-init to force a reconnect
          // if the stream had an error.
          if (provider.error != null && provider.restaurantId != null) {
            provider.init(provider.restaurantId!);
          }
        },
        child: CustomScrollView(
          slivers: [
            // ── Header ──────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Menu',
                        style: kSerif.copyWith(
                          color: kInk,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    // Add button
                    _AddButton(
                      onTap: () => _openAdd(context),
                    ),
                  ],
                ),
              ),
            ),

            // ── Body ─────────────────────────────────────────────────────────
            if (provider.isLoading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(
                      color: kBrand, strokeWidth: 2),
                ),
              )
            else if (provider.error != null)
              SliverFillRemaining(
                child: _ErrorView(
                  message: provider.error!,
                  onRetry: () => provider.init(provider.restaurantId!),
                ),
              )
            else if (provider.items.isEmpty)
              SliverFillRemaining(
                child: _EmptyView(onAdd: () => _openAdd(context)),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = provider.items[index];
                      return _MenuItemTile(
                        item: item,
                        onEdit: () => _openEdit(context, item),
                        onDelete: () => _confirmDelete(context, item),
                      );
                    },
                    childCount: provider.items.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  void _openAdd(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const OwnerAddEditMenuItemPage(),
    ));
  }

  void _openEdit(BuildContext context, Map<String, dynamic> item) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => OwnerAddEditMenuItemPage(existingItem: item),
    ));
  }

  // ── Delete confirmation ────────────────────────────────────────────────────

  Future<void> _confirmDelete(
      BuildContext context, Map<String, dynamic> item) async {
    final name = item['name'] as String? ?? 'this item';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete menu item?',
            style: TextStyle(
                color: kInk, fontSize: 18, fontWeight: FontWeight.w700)),
        content: Text(
          'Are you sure you want to delete "$name"? '
          'This will also remove the item\'s images from storage.',
          style: const TextStyle(color: kMuted, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                const Text('Cancel', style: TextStyle(color: kMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(
                    color: kRed, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final provider = context.read<OwnerMenuProvider>();
    try {
      await provider.deleteItem(item);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"$name" deleted.'),
            backgroundColor: kSurface2,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } on MenuImageException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.userMessage),
            backgroundColor: kRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete item. Please try again.'),
            backgroundColor: kRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

// ── Menu item tile ─────────────────────────────────────────────────────────────

class _MenuItemTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MenuItemTile({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final name = item['name'] as String? ?? '—';
    final description = item['description'] as String? ?? '';
    final price = item['price'] as num? ?? 0;
    final category = item['category'] as String? ?? '';
    final isAvailable = item['isAvailable'] as bool? ?? true;
    final imgUrl = item['img'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(16)),
            child: SizedBox(
              width: 90,
              height: 90,
              child: imgUrl.isNotEmpty
                  ? AppImage(url: imgUrl, fit: BoxFit.cover)
                  : Container(
                      color: kSurface2,
                      child: const Icon(Icons.restaurant_menu,
                          color: kMuted, size: 28),
                    ),
            ),
          ),

          // Info
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + availability badge
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                              color: kInk,
                              fontSize: 14,
                              fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      _AvailabilityBadge(isAvailable: isAvailable),
                    ],
                  ),
                  if (category.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(category,
                        style: const TextStyle(
                            color: kBrand,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ],
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: kMuted, fontSize: 12, height: 1.4)),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    formatPeso(price),
                    style: const TextStyle(
                        color: kInk,
                        fontSize: 14,
                        fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ),

          // Actions column
          Column(
            children: [
              _TileAction(
                icon: Icons.edit_outlined,
                tooltip: 'Edit',
                onTap: onEdit,
              ),
              _TileAction(
                icon: Icons.delete_outline_rounded,
                tooltip: 'Delete',
                onTap: onDelete,
                color: kRed,
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _AvailabilityBadge extends StatelessWidget {
  final bool isAvailable;
  const _AvailabilityBadge({required this.isAvailable});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isAvailable
            ? kGreen.withAlpha(30)
            : kRed.withAlpha(30),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        isAvailable ? 'Available' : 'Unavailable',
        style: TextStyle(
          color: isAvailable ? kGreen : kRed,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TileAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color color;

  const _TileAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color = kMuted,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: color, size: 19),
        ),
      ),
    );
  }
}

// ── Add button ─────────────────────────────────────────────────────────────────

class _AddButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: kBrand,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(
          children: [
            Icon(Icons.add, color: Colors.white, size: 18),
            SizedBox(width: 4),
            Text('Add item',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyView({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: kSurface2,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.restaurant_menu,
                  color: kMuted, size: 36),
            ),
            const SizedBox(height: 16),
            Text('No menu items yet',
                style: kSerif.copyWith(
                    color: kInk,
                    fontSize: 20,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text(
              'Add your first item to start\nbuilding your menu.',
              style: TextStyle(color: kMuted, fontSize: 14, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: onAdd,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: kBrand,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('Add menu item',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error state ────────────────────────────────────────────────────────────────

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
            const Icon(Icons.error_outline, color: kMuted, size: 48),
            const SizedBox(height: 12),
            Text(message,
                style: const TextStyle(color: kMuted, fontSize: 14),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kBrand,
                foregroundColor: Colors.white,
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
