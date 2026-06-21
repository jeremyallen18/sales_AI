class ApiConfig {
  static String _baseUrl = 'http://198.168.0.3:5000';

  static void setBaseUrl(String url) => _baseUrl = url;
  static String get baseUrl => _baseUrl;

  // Auth
  static String get login => '$_baseUrl/api/auth/login';

  // Inventory
  static String get products => '$_baseUrl/api/inventory/products';
  static String get lowStock => '$_baseUrl/api/inventory/low-stock';

  // Sales
  static String get sales => '$_baseUrl/api/sales/';

  // Analytics
  static String get analyticsSummary => '$_baseUrl/api/analytics/summary';

  // Insights (Asesor IA Proactivo)
  static String get insights => '$_baseUrl/api/insights/';

  // Chat (JSON, no streaming)
  static String get chatJson => '$_baseUrl/api/chat/json';

  // Settings
  static String get settings => '$_baseUrl/api/settings/';

  // Branches
  static String get branches => '$_baseUrl/api/branches/';
  static String branch(int id) => '$_baseUrl/api/branches/$id';
  static String branchInventory(int branchId) =>
      '$_baseUrl/api/branches/$branchId/inventory';
  static String branchInventoryItem(int branchId, int productId) =>
      '$_baseUrl/api/branches/$branchId/inventory/$productId';
  static String branchAssign(int branchId) =>
      '$_baseUrl/api/branches/$branchId/assign';
  static String branchUnassign(int branchId, int sellerId) =>
      '$_baseUrl/api/branches/$branchId/assign/$sellerId';
  static String branchSellers(int branchId) =>
      '$_baseUrl/api/branches/$branchId/sellers';
  static String get sellers => '$_baseUrl/api/auth/sellers';

  // Analytics con sucursal
  static String analyticsSummaryBranch(int? branchId) => branchId != null
      ? '$_baseUrl/api/analytics/summary?branch_id=$branchId'
      : '$_baseUrl/api/analytics/summary';
  static String insightsBranch(int? branchId) => branchId != null
      ? '$_baseUrl/api/insights/?branch_id=$branchId'
      : '$_baseUrl/api/insights/';
  static String branchComparison() =>
      '$_baseUrl/api/analytics/branch-comparison';

  static String productImage(String path) {
    if (path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return '$_baseUrl$path';
  }

  static String receiptUrl(int saleId) => '$_baseUrl/api/sales/$saleId/receipt';
}
