import 'package:flutter/material.dart';
import '../constants.dart';
import '_sub_page_shell.dart';

class HelpPage extends StatefulWidget {
  final VoidCallback onBack;

  const HelpPage({super.key, required this.onBack});

  @override
  State<HelpPage> createState() => _HelpPageState();
}

class _HelpPageState extends State<HelpPage> {
  int? _openFaq;

  static const _faqs = [
    {
      'q': 'How do I track my order?',
      'a': "Open the Orders tab to see the current status of your active order. The status updates automatically as your order is confirmed, prepared, and on its way.",
    },
    {
      'q': 'Can I change my order after placing it?',
      'a': "Orders can be modified within 2 minutes of placement. After that, the restaurant starts preparing your food and changes aren't possible.",
    },
    {
      'q': 'What if my order is wrong or missing items?',
      'a': "Tap 'Help' on the order in your history and select 'Issue with my order'. Our team will resolve it within 24 hours.",
    },
    {
      'q': 'How do I get a refund?',
      'a': 'Refunds are issued automatically for cancelled orders. For other issues, raise a ticket via Help & Support and expect resolution in 2–5 business days.',
    },
  ];

  static const _contacts = [
    {'icon': Icons.chat_bubble_outline, 'label': 'Live chat', 'sub': 'Avg. 2 min response', 'color': kBrand},
    {'icon': Icons.phone_outlined, 'label': 'Call us', 'sub': '24/7 support line', 'color': kGreen},
    {'icon': Icons.email_outlined, 'label': 'Email us', 'sub': 'Reply within 24h', 'color': Color(0xFF9B6FE8)},
    {'icon': Icons.bug_report_outlined, 'label': 'Report a bug', 'sub': 'Help us improve', 'color': kGold},
  ];

  @override
  Widget build(BuildContext context) {
    return SubPageShell(
      title: 'Help & support',
      subtitle: "We're here for you",
      onBack: widget.onBack,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildContactGrid(),
            const SizedBox(height: 24),
            _buildFaqSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildContactGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.3,
      children: _contacts.map((c) {
        final color = c['color'] as Color;
        return Container(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
          decoration: BoxDecoration(
            color: kSurface,
            border: Border.all(color: kSurface2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(child: Icon(c['icon'] as IconData, size: 20, color: color)),
              ),
              const SizedBox(height: 10),
              Text(c['label'] as String,
                  style: const TextStyle(
                      color: kInk, fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 2),
              Text(c['sub'] as String,
                  style: const TextStyle(color: kMuted, fontSize: 11)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFaqSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('FAQs',
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
            children: List.generate(_faqs.length, (i) {
              final faq = _faqs[i];
              final isOpen = _openFaq == i;
              return Column(
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _openFaq = isOpen ? null : i),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(faq['q'] as String,
                                style: const TextStyle(
                                    color: kInk, fontSize: 14, fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(width: 12),
                          AnimatedRotation(
                            duration: const Duration(milliseconds: 200),
                            turns: isOpen ? 0.125 : 0,
                            child: const Icon(Icons.add, color: kMuted, size: 20),
                          ),
                        ],
                      ),
                    ),
                  ),
                  AnimatedCrossFade(
                    duration: const Duration(milliseconds: 200),
                    crossFadeState:
                        isOpen ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                    firstChild: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      child: Text(faq['a'] as String,
                          style: const TextStyle(color: kMuted, fontSize: 13, height: 1.7)),
                    ),
                    secondChild: const SizedBox.shrink(),
                  ),
                  if (i < _faqs.length - 1)
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
