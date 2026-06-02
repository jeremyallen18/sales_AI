import 'package:flutter/foundation.dart';
import '../models/sale.dart';
import '../services/api_service.dart';

class SalesProvider with ChangeNotifier {
  List<Sale> _sales = [];
  bool _loading = false;
  String? _error;

  List<Sale> get sales => List.unmodifiable(_sales);
  bool get loading => _loading;
  String? get error => _error;

  double get todayRevenue {
    final now = DateTime.now();
    return _sales
        .where((s) =>
            s.createdAt.year == now.year &&
            s.createdAt.month == now.month &&
            s.createdAt.day == now.day)
        .fold(0.0, (sum, s) => sum + s.totalAmount);
  }

  int get todaySalesCount {
    final now = DateTime.now();
    return _sales
        .where((s) =>
            s.createdAt.year == now.year &&
            s.createdAt.month == now.month &&
            s.createdAt.day == now.day)
        .length;
  }

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _sales = await ApiService.fetchSales();
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
