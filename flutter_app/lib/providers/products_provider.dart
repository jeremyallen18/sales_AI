import 'package:flutter/foundation.dart';
import '../models/product.dart';
import '../services/api_service.dart';

class ProductsProvider with ChangeNotifier {
  List<Product> _all = [];
  bool _loading = false;
  String? _error;

  bool get loading => _loading;
  String? get error => _error;

  /// Todos los productos con stock > 0
  List<Product> get allProducts => _all.where((p) => p.stock > 0).toList();

  /// Mapa categoría → lista de productos (con stock > 0, ordenados por nombre)
  Map<String, List<Product>> get byCategory {
    final Map<String, List<Product>> map = {};
    for (final p in allProducts) {
      map.putIfAbsent(p.category, () => []).add(p);
    }
    for (final list in map.values) {
      list.sort((a, b) => a.name.compareTo(b.name));
    }
    return map;
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
}
