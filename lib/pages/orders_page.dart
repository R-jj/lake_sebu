import 'package:flutter/material.dart';
import '../constants.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  bool _showActive = true;

  Color _statusColor(String s) => s == 'Delivered' ? kGreen : (s == 'Cancelled' ? kRed : kGold);
  Color _statusBg(String s) => s == 'Delivered'
      ? kGreen.withValues(alpha: 0.12)
      : (s == 'Cancelled' ? kRed.withValues(alpha: 0.12) : kGold.withValues(alpha: 0.12));

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your orders', style: kSerif.copyWith(color: kInk, fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: kSurface,
                    border: Border.all(color: kBorder),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: _tabButton('Active', _showActive, () => setState(() => _showActive = true))),
                      const SizedBox(width: 4),
                      Expanded(child: _tabButton('Past orders', !_showActive, () => setState(() => _showActive = false))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            child: _showActive ? _buildActiveTracker() : _buildPastOrders(),
          ),
        ],
      ),
    );
  }

  Widget _tabButton(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? kBrand : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(color: active ? Colors.white : kMuted, fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildActiveTracker() {
    final steps = [
      {'label': 'Order confirmed', 'done': true, 'icon': Icons.check},
      {'label': 'Being prepared', 'done': true, 'icon': Icons.check},
      {'label': 'Out for delivery', 'done': true, 'icon': Icons.delivery_dining},
      {'label': 'Delivered', 'done': false, 'icon': Icons.home},
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kSurface,
        border: Border.all(color: kBorder),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('ORDER #SW-4835',
                      style: TextStyle(color: kMuted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1)),
                  SizedBox(height: 2),
                  Text('The Patty Lab', style: TextStyle(color: kInk, fontWeight: FontWeight.w800, fontSize: 16)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(color: kGold.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(100)),
                child: const Text('● On the way', style: TextStyle(color: kGold, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (int i = 0; i < steps.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i < steps.length - 1 ? 16 : 0),
              child: Row(
                children: [
                  Column(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: (steps[i]['done'] as bool) ? kBrand : kSurface2,
                          border: Border.all(color: (steps[i]['done'] as bool) ? kBrand : kBorder, width: 2),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(steps[i]['icon'] as IconData, size: 14, color: Colors.white),
                        ),
                      ),
                      if (i < steps.length - 1)
                        Container(
                          width: 2,
                          height: 16,
                          margin: const EdgeInsets.only(top: 2),
                          color: (steps[i]['done'] as bool) ? kBrand : kBorder,
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Text(
                    steps[i]['label'] as String,
                    style: TextStyle(
                      color: (steps[i]['done'] as bool) ? kInk : kMuted,
                      fontSize: 14,
                      fontWeight: (steps[i]['done'] as bool) ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: kSurface2, borderRadius: BorderRadius.circular(12)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Estimated arrival', style: TextStyle(color: kMuted, fontSize: 11)),
                    Text('8 minutes', style: TextStyle(color: kGreen, fontWeight: FontWeight.w800, fontSize: 16)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(color: kBrand, borderRadius: BorderRadius.circular(12)),
                  child: const Text('Track live', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPastOrders() {
    return Column(
      children: kOrders.map((order) {
        final status = order['status'] as String;
        final items = order['items'] as List<String>;
        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: kSurface,
            border: Border.all(color: kSurface2),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(color: kSurface2, borderRadius: BorderRadius.circular(12)),
                    clipBehavior: Clip.hardEdge,
                    child: Image.network(
                      order['img'] as String,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) => Container(color: kSurface2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(order['restaurant'] as String, style: const TextStyle(color: kInk, fontWeight: FontWeight.w800, fontSize: 14)),
                        const SizedBox(height: 2),
                        Text('${order['id']} · ${order['date']}', style: const TextStyle(color: kMuted, fontSize: 11)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: _statusBg(status), borderRadius: BorderRadius.circular(100)),
                    child: Text(status, style: TextStyle(color: _statusColor(status), fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.only(top: 10),
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: kSurface2))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(items.join(' · '), style: const TextStyle(color: kMuted, fontSize: 12)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(formatPeso(order['total'] as num?),
                            style: const TextStyle(color: kInk, fontWeight: FontWeight.w800, fontSize: 15)),
                        if (status == 'Delivered')
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(border: Border.all(color: kBorder), borderRadius: BorderRadius.circular(10)),
                            child: const Text('Reorder', style: TextStyle(color: kInk, fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
