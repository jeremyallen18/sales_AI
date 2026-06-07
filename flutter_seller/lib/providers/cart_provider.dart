import 'package:flutter/foundation.dart';
import '../models/cart_item.dart';
import '../models/product.dart';
import '../services/api_service.dart';

class CartProvider with ChangeNotifier {
  final Map<int, CartItem> _items = {};

  Map<int, CartItem> get items => Map.unmodifiable(_items);
  int get count => _items.values.fold(0, (sum, i) => sum + i.quantity);
  double get total => _items.values.fold(0.0, (sum, i) => sum + i.subtotal);
  bool get isEmpty => _items.isEmpty;

  void add(Product product) {
    if (_items.containsKey(product.id)) {
      if (_items[product.id]!.quantity < product.stock) {
        _items[product.id]!.quantity++;
      }
    } else {
      _items[product.id] = CartItem(product: product);
    }
    notifyListeners();
  }

  void remove(int productId) {
    _items.remove(productId);
    notifyListeners();
  }

  void updateQuantity(int productId, int qty) {
    if (!_items.containsKey(productId)) return;
    if (qty <= 0) {
      _items.remove(productId);
    } else {
      _items[productId]!.quantity = qty;
    }
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }

  Future<Map<String, dynamic>> checkout(String clientName, String paymentMethod) async {
    final saleItems = _items.values
        .map((i) => {'product_id': i.product.id, 'quantity': i.quantity})
        .toList();
    final result = await ApiService.createSale(
        items: saleItems, clientName: clientName, paymentMethod: paymentMethod);
    clear();
    return result;
  }
}
