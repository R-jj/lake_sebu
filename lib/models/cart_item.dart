/// A single line item in the shopping cart.
class CartItem {
  final String id;
  final String name;
  final String restaurant;
  final double price;
  final String img;
  final int qty;

  const CartItem({
    required this.id,
    required this.name,
    required this.restaurant,
    required this.price,
    required this.img,
    this.qty = 1,
  });

  CartItem copyWith({int? qty}) => CartItem(
        id: id,
        name: name,
        restaurant: restaurant,
        price: price,
        img: img,
        qty: qty ?? this.qty,
      );
}
