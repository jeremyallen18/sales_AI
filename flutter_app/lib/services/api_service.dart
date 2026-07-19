import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/product.dart';
import '../models/branch.dart';
import '../models/branch_inventory_item.dart';

class ApiService {
  // ── Auth ──────────────────────────────────────────────────

  static Future<Map<String, dynamic>> loginWithGoogle(String idToken) async {
    final response = await http
        .post(
          Uri.parse('${ApiConfig.baseUrl}/api/auth/google/customer'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'id_token': idToken}),
        )
        .timeout(const Duration(seconds: 15));
    final body = json.decode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200) return body;
    throw Exception(body['error'] ?? 'Error de autenticación');
  }

  // ── Productos (catálogo global) ───────────────────────────

  static Future<List<Product>> fetchProducts() async {
    final response = await http
        .get(Uri.parse(ApiConfig.products))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data
          .map((e) => Product.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Error ${response.statusCode} al cargar productos');
  }

  // ── Sucursales ────────────────────────────────────────────

  static Future<List<Branch>> fetchNearbyBranches(
    double lat,
    double lng, {
    double radiusKm = 20,
  }) async {
    final response = await http
        .get(Uri.parse(ApiConfig.nearbyBranches(lat, lng, radius: radiusKm)))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data
          .map((e) => Branch.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Error ${response.statusCode} al cargar sucursales');
  }

  static Future<List<Branch>> fetchAllBranches() async {
    final response = await http
        .get(Uri.parse(ApiConfig.branches))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data
          .map((e) => Branch.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Error ${response.statusCode} al cargar sucursales');
  }

  static Future<List<BranchInventoryItem>> fetchBranchInventory(
      int branchId) async {
    final response = await http
        .get(Uri.parse(ApiConfig.branchInventory(branchId)))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data
          .map((e) => BranchInventoryItem.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception(
        'Error ${response.statusCode} al cargar inventario de sucursal');
  }

  static Future<Map<String, dynamic>> postBranchReview(
    int branchId,
    int rating,
    String comment,
    String appToken,
  ) async {
    final response = await http
        .post(
          Uri.parse(ApiConfig.branchReviews(branchId)),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $appToken',
          },
          body: json.encode({'rating': rating, 'comment': comment}),
        )
        .timeout(const Duration(seconds: 10));

    final body = json.decode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200 || response.statusCode == 201) return body;
    throw Exception(body['error'] ?? 'Error al enviar reseña');
  }

  static Future<Map<String, dynamic>> fetchMyBranchReview(
    int branchId,
    String appToken,
  ) async {
    final response = await http
        .get(
          Uri.parse(ApiConfig.myBranchReview(branchId)),
          headers: {'Authorization': 'Bearer $appToken'},
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Error ${response.statusCode} al cargar tu reseña');
  }

  static Future<Map<String, dynamic>> fetchMyProductReview(
    int productId,
    String appToken,
  ) async {
    final response = await http
        .get(
          Uri.parse(ApiConfig.myProductReview(productId)),
          headers: {'Authorization': 'Bearer $appToken'},
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Error ${response.statusCode} al cargar tu reseña');
  }

  // ── Ventas ────────────────────────────────────────────────

  static Future<Map<String, dynamic>> createSale({
    required List<Map<String, dynamic>> items,
    required String clientName,
    String paymentMethod = 'efectivo',
    String? appToken,
    int? branchId,
  }) async {
    final headers = {'Content-Type': 'application/json'};
    if (appToken != null) headers['Authorization'] = 'Bearer $appToken';
    final body = <String, dynamic>{
      'items': items,
      'client_name': clientName,
      'payment_method': paymentMethod,
    };
    if (branchId != null) body['branch_id'] = branchId;

    final response = await http
        .post(
          Uri.parse(ApiConfig.sales),
          headers: headers,
          body: json.encode(body),
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode == 201) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    final respBody = json.decode(response.body) as Map<String, dynamic>;
    throw Exception(respBody['error'] ?? 'Error al registrar la venta');
  }

  // ── Reseñas de productos ──────────────────────────────────

  static Future<Map<String, dynamic>> fetchProductRatings() async {
    final response = await http
        .get(Uri.parse(ApiConfig.productRatings))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Error ${response.statusCode} al cargar ratings');
  }

  static Future<Map<String, dynamic>> fetchProductReviews(int productId) async {
    final response = await http
        .get(Uri.parse(ApiConfig.productReviews(productId)))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Error ${response.statusCode} al cargar reseñas');
  }

  static Future<Map<String, dynamic>> postProductReview(
    int productId,
    int rating,
    String comment,
    String appToken,
  ) async {
    final response = await http
        .post(
          Uri.parse(ApiConfig.productReviews(productId)),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $appToken',
          },
          body: json.encode({'rating': rating, 'comment': comment}),
        )
        .timeout(const Duration(seconds: 10));
    final body = json.decode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200 || response.statusCode == 201) return body;
    throw Exception(body['error'] ?? 'Error al enviar reseña');
  }

  static Future<Map<String, dynamic>> fetchBranchReviews(int branchId) async {
    final response = await http
        .get(Uri.parse(ApiConfig.branchReviews(branchId)))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Error ${response.statusCode} al cargar reseñas');
  }

  // ── Chatbot de tienda ─────────────────────────────────────

  static Future<String> sendChatMessage(String message,
      {int? branchId}) async {
    final body = <String, dynamic>{'message': message};
    if (branchId != null) body['branch_id'] = branchId;

    final response = await http
        .post(
          Uri.parse(ApiConfig.storeChat),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(body),
        )
        .timeout(const Duration(seconds: 30));

    final respBody = json.decode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200) {
      return respBody['response'] as String? ?? '';
    }
    throw Exception(respBody['error'] ?? 'Error del asistente IA');
  }
}
