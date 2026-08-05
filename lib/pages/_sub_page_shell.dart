import 'package:flutter/material.dart';
import '../constants.dart';

/// Reusable shell for profile sub-pages: header with back button + scrollable body.
class SubPageShell extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback onBack;
  final Widget child;

  const SubPageShell({
    super.key,
    required this.title,
    this.subtitle,
    required this.onBack,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: kSurface2)),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: onBack,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: kSurface,
                    border: Border.all(color: kBorder),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.chevron_left, color: kInk, size: 22),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: kSerif.copyWith(
                            color: kInk, fontSize: 17, fontWeight: FontWeight.w900)),
                    if (subtitle != null)
                      Text(subtitle!,
                          style: const TextStyle(color: kMuted, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Scrollable body
        Expanded(child: child),
      ],
    );
  }
}
