/// A single line item in the shopping cart.
class CartItem {
  final String id;
  final String name;
  final String restaurant;

  /// Firestore document ID of the restaurant this item belongs to.
  /// Used at checkout to snapshot the restaurantId on the order.
  /// May be empty for items added from static/mock data.
  final String restaurantId;

  final double price;
  final String img;
  final int qty;

  const CartItem({
    required this.id,
    required this.name,
    required this.restaurant,
    this.restaurantId = '',
    required this.price,
    required this.img,
    this.qty = 1,
  });

  CartItem copyWith({int? qty}) => CartItem(
        id: id,
        name: name,
        restaurant: restaurant,
        restaurantId: restaurantId,
        price: price,
        img: img,
        qty: qty ?? this.qty,
      );
}
