import 'product.dart';

class CartItem {
  final Product product;
  int quantity;

  CartItem({required this.product, this.quantity = 1});

  double get unitPrice => product.price * (1 - product.discountPct / 100);
  double get subtotal => unitPrice * quantity;
}
