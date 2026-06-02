import 'package:flutter/foundation.dart';
import '../models/product.dart';
import '../services/api_service.dart';

class ProductsProvider with ChangeNotifier {
  List<Product> _all = [];
  bool _loading = false;
  String? _error;

  bool get loading => _loading;
  String? get error => _error;
  List<Product> get allProducts => List.unmodifiable(_all);
  List<Product> get inStockProducts => _all.where((p) => p.stock > 0).toList();
  List<Product> get lowStockProducts => _all.where((p) => p.isLowStock).toList();

  Map<String, List<Product>> get byCategory {
    final Map<String, List<Product>> map = {};
    for (final p in inStockProducts) {
      map.putIfAbsent(p.category, () => []).add(p);
    }
    for (final list in map.values) {
      list.sort((a, b) => a.name.compareTo(b.name));
    }
    return map;
  }

  List<String> get categories {
    final cats = _all.map((p) => p.category).toSet().toList();
    cats.sort();
    return cats;
  }

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _all = await ApiService.fetchProducts();
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> addProduct(Map<String, dynamic> data) async {
    await ApiService.createProduct(data);
    await load();
  }

  Future<void> editProduct(int id, Map<String, dynamic> data) async {
    await ApiService.updateProduct(id, data);
    await load();
  }

  Future<void> removeProduct(int id) async {
    await ApiService.deleteProduct(id);
    await load();
  }
}
