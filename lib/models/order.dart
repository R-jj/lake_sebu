import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a food-delivery order stored in Firestore at `orders/{orderId}`.
///
/// Named [FoodOrder] (not `Order`) to avoid a name collision with the
/// `Order` class exported by `cloud_firestore` / `cloud_firestore_platform_interface`.
///
/// # customerPhone snapshot
/// [customerPhone] is captured from the customer's profile at the moment the
/// order is placed.  It is an immutable snapshot: if the customer later
/// changes their profile phone number, this field is NOT updated.  The
/// restaurant always has the number that was valid when the order was created.
///
/// # restaurantId
/// Stored on every order so the restaurant side can query:
///   `orders where restaurantId == <id>`
/// No restaurant dashboard exists yet, but the data is ready for it.
class FoodOrder {
  final String orderId;

  // ── Customer snapshot fields ───────────────────────────────────────────────
  final String customerId;
  final String customerName;

  /// E.164 phone number snapshot, e.g. "+639171234567".
  /// Captured at order-creation time — never updated after that.
  final String customerPhone;

  // ── Restaurant ────────────────────────────────────────────────────────────
  final String restaurantId;
  final String restaurantName;

  // ── Items ─────────────────────────────────────────────────────────────────
  /// Each entry mirrors [CartItem] fields serialised to a plain map:
  ///   { id, name, price, qty, img }
  final List<Map<String, dynamic>> items;

  // ── Delivery ──────────────────────────────────────────────────────────────
  final String deliveryAddress;

  // ── Financials ────────────────────────────────────────────────────────────
  final double subtotal;
  final double deliveryFee;
  final double discount;
  final double total;

  /// The promo code that was applied, or null if none.
  final String? promoCode;

  // ── Meta ──────────────────────────────────────────────────────────────────
  final FoodOrderStatus status;
  final DateTime? createdAt;

  const FoodOrder({
    required this.orderId,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.restaurantId,
    required this.restaurantName,
    required this.items,
    required this.deliveryAddress,
    required this.subtotal,
    required this.deliveryFee,
    required this.discount,
    required this.total,
    this.promoCode,
    this.status = FoodOrderStatus.pending,
    this.createdAt,
  });

  // ── Firestore serialisation ───────────────────────────────────────────────

  factory FoodOrder.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return FoodOrder(
      orderId: doc.id,
      customerId: d['customerId'] as String? ?? '',
      customerName: d['customerName'] as String? ?? '',
      customerPhone: d['customerPhone'] as String? ?? '',
      restaurantId: d['restaurantId'] as String? ?? '',
      restaurantName: d['restaurantName'] as String? ?? '',
      items: List<Map<String, dynamic>>.from(
        (d['items'] as List<dynamic>? ?? []).map(
          (e) => Map<String, dynamic>.from(e as Map),
        ),
      ),
      deliveryAddress: d['deliveryAddress'] as String? ?? '',
      subtotal: (d['subtotal'] as num?)?.toDouble() ?? 0.0,
      deliveryFee: (d['deliveryFee'] as num?)?.toDouble() ?? 0.0,
      discount: (d['discount'] as num?)?.toDouble() ?? 0.0,
      total: (d['total'] as num?)?.toDouble() ?? 0.0,
      promoCode: d['promoCode'] as String?,
      status: FoodOrderStatus.fromString(d['status'] as String? ?? ''),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Serialises the order for a Firestore *create* write.
  /// [orderId] is not stored inside the document — it lives as the doc ID.
  Map<String, dynamic> toFirestore() => {
        'customerId': customerId,
        'customerName': customerName,
        // customerPhone is the immutable snapshot — written once on create.
        'customerPhone': customerPhone,
        'restaurantId': restaurantId,
        'restaurantName': restaurantName,
        'items': items,
        'deliveryAddress': deliveryAddress,
        'subtotal': subtotal,
        'deliveryFee': deliveryFee,
        'discount': discount,
        'total': total,
        if (promoCode != null) 'promoCode': promoCode,
        'status': status.value,
        'createdAt': FieldValue.serverTimestamp(),
      };

  FoodOrder copyWith({FoodOrderStatus? status}) => FoodOrder(
        orderId: orderId,
        customerId: customerId,
        customerName: customerName,
        customerPhone: customerPhone,
        restaurantId: restaurantId,
        restaurantName: restaurantName,
        items: items,
        deliveryAddress: deliveryAddress,
        subtotal: subtotal,
        deliveryFee: deliveryFee,
        discount: discount,
        total: total,
        promoCode: promoCode,
        status: status ?? this.status,
        createdAt: createdAt,
      );
}

// ── Order status ──────────────────────────────────────────────────────────────

enum FoodOrderStatus {
  pending('pending'),
  confirmed('confirmed'),
  preparing('preparing'),
  onTheWay('on_the_way'),
  delivered('delivered'),
  cancelled('cancelled');

  const FoodOrderStatus(this.value);
  final String value;

  static FoodOrderStatus fromString(String raw) {
    return FoodOrderStatus.values.firstWhere(
      (s) => s.value == raw,
      orElse: () => FoodOrderStatus.pending,
    );
  }

  String get displayLabel {
    switch (this) {
      case FoodOrderStatus.pending:
        return 'Pending';
      case FoodOrderStatus.confirmed:
        return 'Confirmed';
      case FoodOrderStatus.preparing:
        return 'Preparing';
      case FoodOrderStatus.onTheWay:
        return 'On the way';
      case FoodOrderStatus.delivered:
        return 'Delivered';
      case FoodOrderStatus.cancelled:
        return 'Cancelled';
    }
  }
}
