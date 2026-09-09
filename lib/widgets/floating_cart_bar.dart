import 'package:flutter/material.dart';
import '../constants.dart';

/// A pill-shaped floating cart bar that sits at the bottom of food-browsing
/// pages.  Visible only when the cart has at least one item.
class FloatingCartBar extends StatelessWidget {
  final int cartCount;
  final double cartTotal;
  final VoidCallback onTap;

  const FloatingCartBar({
    super.key,
    required this.cartCount,
    required this.cartTotal,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (cartCount == 0) return const SizedBox.shrink();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: kBrand,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: kBrand.withValues(alpha: 0.45),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            // Item count badge with pulse animation
            _PulsingBadge(
              count: cartCount,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$cartCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'View cart',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Flexible(
              child: Text(
                formatPeso(cartTotal),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }
}

// ── Pulsing badge ─────────────────────────────────────────────────────────────

/// Wraps [child] and plays a quick scale-bounce + wobble whenever [count]
/// changes.
class _PulsingBadge extends StatefulWidget {
  final int count;
  final Widget child;

  const _PulsingBadge({required this.count, required this.child});

  @override
  State<_PulsingBadge> createState() => _PulsingBadgeState();
}

class _PulsingBadgeState extends State<_PulsingBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _rotate;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    // Scale: 1 → 1.35 → 0.9 → 1.1 → 1.0  (zoom in then settle)
    _scale = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 1.35)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 30),
      TweenSequenceItem(
          tween: Tween(begin: 1.35, end: 0.9)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 25),
      TweenSequenceItem(
          tween: Tween(begin: 0.9, end: 1.08)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 25),
      TweenSequenceItem(
          tween: Tween(begin: 1.08, end: 1.0)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 20),
    ]).animate(_ctrl);

    // Wobble: slight left-right rotation during the pulse
    _rotate = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween(begin: 0.0, end: -0.08)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 20),
      TweenSequenceItem(
          tween: Tween(begin: -0.08, end: 0.08)
              .chain(CurveTween(curve: Curves.easeInOut)),
          weight: 40),
      TweenSequenceItem(
          tween: Tween(begin: 0.08, end: -0.04)
              .chain(CurveTween(curve: Curves.easeInOut)),
          weight: 25),
      TweenSequenceItem(
          tween: Tween(begin: -0.04, end: 0.0)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 15),
    ]).animate(_ctrl);
  }

  @override
  void didUpdateWidget(_PulsingBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.count != oldWidget.count) {
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) => Transform.rotate(
        angle: _rotate.value,
        child: Transform.scale(
          scale: _scale.value,
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

/// Public re-export so home_page.dart can use the same widget for the
/// top-bar cart icon badge without duplicating logic.
class CartCountBadge extends StatelessWidget {
  final int count;

  const CartCountBadge({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();
    return _PulsingBadge(
      count: count,
      child: Container(
        width: 18,
        height: 18,
        decoration: const BoxDecoration(color: kBrand, shape: BoxShape.circle),
        child: Center(
          child: Text(
            '$count',
            style: const TextStyle(
                color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
}
