import 'package:flutter/foundation.dart';
import '../models/branch.dart';
import '../services/api_service.dart';

class BranchProvider with ChangeNotifier {
  List<Branch> _assigned = [];
  Branch? _active;
  bool _loading = false;
  String? _error;

  List<Branch> get assigned => _assigned;
  Branch? get active => _active;
  int? get activeBranchId => _active?.id;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> loadBranches() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _assigned = await ApiService.fetchBranches();
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadAssigned(List<int> branchIds) async {
    if (branchIds.isEmpty) {
      _assigned = [];
      notifyListeners();
      return;
    }
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final all = await ApiService.fetchBranches();
      _assigned = all.where((b) => branchIds.contains(b.id)).toList();
      if (_active == null && _assigned.isNotEmpty) {
        _active = _assigned.first;
      }
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void setActive(Branch branch) {
    _active = branch;
    notifyListeners();
  }

  Future<Branch> createBranch(Map<String, dynamic> data) async {
    final branch = await ApiService.createBranch(data);
    _assigned.add(branch);
    notifyListeners();
    return branch;
  }

  Future<Branch> updateBranch(int id, Map<String, dynamic> data) async {
    final updated = await ApiService.updateBranch(id, data);
    final idx = _assigned.indexWhere((b) => b.id == id);
    if (idx >= 0) _assigned[idx] = updated;
    if (_active?.id == id) _active = updated;
    notifyListeners();
    return updated;
  }

  Future<void> deleteBranch(int id) async {
    await ApiService.deleteBranch(id);
    _assigned.removeWhere((b) => b.id == id);
    if (_active?.id == id) _active = _assigned.isNotEmpty ? _assigned.first : null;
    notifyListeners();
  }
}
