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

  static String productImage(String path) {
    if (path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return '$_baseUrl$path';
  }

  static String receiptUrl(int saleId) => '$_baseUrl/api/sales/$saleId/receipt';
}
