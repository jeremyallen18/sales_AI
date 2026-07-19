import 'package:flutter/foundation.dart';
import '../models/branch.dart';
import '../services/api_service.dart';

class BranchProvider with ChangeNotifier {
  List<Branch> _nearby = [];
  Branch? _selectedBranch;
  bool _loading = false;
  String? _error;

  List<Branch> get nearby => _nearby;
  Branch? get selectedBranch => _selectedBranch;
  int? get selectedBranchId => _selectedBranch?.id;
  bool get loading => _loading;
  String? get error => _error;
  bool get hasBranchSelected => _selectedBranch != null;

  Future<void> loadNearby(double lat, double lng, {double radiusKm = 20}) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _nearby = await ApiService.fetchNearbyBranches(lat, lng, radiusKm: radiusKm);
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadAll() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _nearby = await ApiService.fetchAllBranches();
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void selectBranch(Branch branch) {
    _selectedBranch = branch;
    notifyListeners();
  }

  void clearSelection() {
    _selectedBranch = null;
    notifyListeners();
  }
}
