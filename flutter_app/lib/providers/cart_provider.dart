import 'package:flutter/foundation.dart';
import '../models/cart_item.dart';
import '../models/product.dart';
import '../services/api_service.dart';

class CartProvider with ChangeNotifier {
  final Map<int, CartItem> _items = {};

  Map<int, CartItem> get items => Map.unmodifiable(_items);

  static const double _taxFactor = 0.16 / 1.16;

  int get count => _items.values.fold(0, (sum, i) => sum + i.quantity);

  double get subtotalBruto =>
      _items.values.fold(0.0, (sum, i) => sum + i.product.price * i.quantity);

  double get total =>
      _items.values.fold(0.0, (sum, i) => sum + i.subtotal);

  double get discountAmount => subtotalBruto - total;

  double get taxAmount => total * _taxFactor;

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

  int? _activeBranchId;
  int? get activeBranchId => _activeBranchId;

  void setBranch(int? branchId) {
    _activeBranchId = branchId;
  }

  Future<Map<String, dynamic>> checkout(
    String clientName,
    String paymentMethod, {
    String? appToken,
  }) async {
    final saleItems = _items.values
        .map((i) => {'product_id': i.product.id, 'quantity': i.quantity})
        .toList();

    final result = await ApiService.createSale(
      items: saleItems,
      clientName: clientName,
      paymentMethod: paymentMethod,
      appToken: appToken,
      branchId: _activeBranchId,
    );
    clear();
    return result;
  }
}
