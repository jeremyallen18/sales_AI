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

  // ── Sucursales ────────────────────────────────────────────
  static String get branches => '$_baseUrl/api/branches/';
  static String nearbyBranches(double lat, double lng, {double radius = 20}) =>
      '$_baseUrl/api/branches/nearby?lat=$lat&lng=$lng&radius=$radius';
  static String branchInventory(int branchId) =>
      '$_baseUrl/api/branches/$branchId/inventory';
  static String branchReviews(int branchId) =>
      '$_baseUrl/api/branches/$branchId/reviews';
  static String myBranchReview(int branchId) =>
      '$_baseUrl/api/branches/$branchId/my-review';

  // ── Reseñas de productos ──────────────────────────────────
  static String get productRatings => '$_baseUrl/api/products/ratings';
  static String productReviews(int productId) =>
      '$_baseUrl/api/products/$productId/reviews';
  static String myProductReview(int productId) =>
      '$_baseUrl/api/products/$productId/my-review';

  // ── Helpers ───────────────────────────────────────────────
  static String productImage(String path) {
    if (path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return '$_baseUrl$path';
  }
}
