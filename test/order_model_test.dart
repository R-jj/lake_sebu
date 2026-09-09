import 'package:flutter_test/flutter_test.dart';
import 'package:lake_sebu/models/order.dart';

void main() {
  // ── Fixture helper ─────────────────────────────────────────────────────────

  /// A minimal valid order document map, with optional delivery coords.
  Map<String, dynamic> baseMap({Object? deliveryLat, Object? deliveryLng}) {
    return {
      'customerId': 'cus-1',
      'customerName': 'Juan Dela Cruz',
      'customerPhone': '+639171234567',
      'restaurantId': 'rest-1',
      'restaurantName': 'Lake Sebu Grill',
      'items': [
        {'id': 'i1', 'name': 'Tilapia', 'price': 150.0, 'qty': 2, 'img': ''},
      ],
      'deliveryAddress': 'Poblacion, Lake Sebu',
      'deliveryLat': ?deliveryLat,
      'deliveryLng': ?deliveryLng,
      'subtotal': 300.0,
      'deliveryFee': 99.0,
      'discount': 0.0,
      'total': 399.0,
      'status': 'pending',
    };
  }

  group('FoodOrder.fromMap delivery coordinates', () {
    test('parses lat/lng doubles when present', () {
      final order = FoodOrder.fromMap(
        'order-1',
        baseMap(deliveryLat: 6.2278, deliveryLng: 124.8247),
      );
      expect(order.deliveryLat, 6.2278);
      expect(order.deliveryLng, 124.8247);
      expect(order.hasDeliveryCoordinates, isTrue);
    });

    test('coerces integer coords to double', () {
      final order = FoodOrder.fromMap(
        'order-1',
        baseMap(deliveryLat: 6, deliveryLng: 124),
      );
      expect(order.deliveryLat, 6.0);
      expect(order.deliveryLng, 124.0);
      expect(order.hasDeliveryCoordinates, isTrue);
    });

    test('coords default to null for legacy orders', () {
      final order = FoodOrder.fromMap('order-1', baseMap());
      expect(order.deliveryLat, isNull);
      expect(order.deliveryLng, isNull);
      expect(order.hasDeliveryCoordinates, isFalse);
    });
  });

  group('FoodOrder.toFirestore delivery coordinates', () {
    test('omits null coords entirely', () {
      final order = FoodOrder.fromMap('order-1', baseMap());
      final data = order.toFirestore();
      expect(data.containsKey('deliveryLat'), isFalse);
      expect(data.containsKey('deliveryLng'), isFalse);
    });

    test('includes coords when set', () {
      final order = FoodOrder.fromMap(
        'order-1',
        baseMap(deliveryLat: 6.2278, deliveryLng: 124.8247),
      );
      final data = order.toFirestore();
      expect(data['deliveryLat'], 6.2278);
      expect(data['deliveryLng'], 124.8247);
    });

    test('round-trips through fromMap', () {
      final original = FoodOrder.fromMap(
        'order-1',
        baseMap(deliveryLat: 6.2278, deliveryLng: 124.8247),
      );
      // serverTimestamp is a FieldValue, not a Timestamp — drop it before
      // feeding the map back into fromMap.
      final restored = FoodOrder.fromMap(
        original.orderId,
        Map<String, dynamic>.from(original.toFirestore())..remove('createdAt'),
      );
      expect(restored.deliveryLat, original.deliveryLat);
      expect(restored.deliveryLng, original.deliveryLng);
      expect(restored.hasDeliveryCoordinates, isTrue);
      expect(restored.status, original.status);
    });
  });

  group('FoodOrder.copyWith', () {
    test('preserves coordinates when only status changes', () {
      final order = FoodOrder.fromMap(
        'order-1',
        baseMap(deliveryLat: 6.2278, deliveryLng: 124.8247),
      );
      final advanced = order.copyWith(status: FoodOrderStatus.confirmed);
      expect(advanced.status, FoodOrderStatus.confirmed);
      expect(advanced.deliveryLat, 6.2278);
      expect(advanced.deliveryLng, 124.8247);
      expect(advanced.hasDeliveryCoordinates, isTrue);
    });
  });
}
