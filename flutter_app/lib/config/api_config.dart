/// ApiConfig — URL base dinámica del servidor Flask.
/// Se inicializa en SettingsService.init() al arrancar la app.
class ApiConfig {
  static String _baseUrl = 'http://128.4.1.148:5000';

  static void setBaseUrl(String url) => _baseUrl = url;

  static String get baseUrl => _baseUrl;

  // ── Endpoints ────────────────────────────────────────────
  static String get products => '$_baseUrl/api/inventory/products';
  static String get sales => '$_baseUrl/api/sales/';
  static String get storeChat => '$_baseUrl/tienda/chat';

  // ── Helpers ───────────────────────────────────────────────
  static String productImage(String path) {
    if (path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return '$_baseUrl$path';
  }
}
