import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../models/insight.dart';
import '../models/branch.dart';
import '../models/combo.dart';

class ApiService {
  static const _timeout = Duration(seconds: 15);

  static String? _authToken;
  static void setAuthToken(String? token) => _authToken = token;

  static Map<String, String> get _authHeaders => {
        'Content-Type': 'application/json',
        if (_authToken != null) 'Authorization': 'Bearer $_authToken',
      };

  // ── Auth ──────────────────────────────────────────────────

  static Future<Map<String, dynamic>> login(
      String username, String password) async {
    final response = await http
        .post(
          Uri.parse(ApiConfig.login),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'username': username, 'password': password}),
        )
        .timeout(_timeout);

    final body = json.decode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200) return body;
    throw Exception(body['error'] ?? 'Error de autenticación');
  }

  static Future<Map<String, dynamic>> loginWithGoogleSeller(
      String idToken) async {
    final response = await http
        .post(
          Uri.parse('${ApiConfig.baseUrl}/api/auth/google/seller'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'id_token': idToken}),
        )
        .timeout(_timeout);
    final body = json.decode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200) return body;
    throw Exception(body['error'] ?? 'Error de autenticación con Google');
  }

  // ── Productos ─────────────────────────────────────────────

  static Future<List<Product>> fetchProducts() async {
    final response = await http
        .get(Uri.parse(ApiConfig.products), headers: _authHeaders)
        .timeout(_timeout);
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data
          .map((e) => Product.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Error ${response.statusCode} al cargar productos');
  }

  static Future<List<Product>> fetchBranchInventory(int branchId) async {
    final response = await http
        .get(Uri.parse(ApiConfig.branchInventory(branchId)),
            headers: _authHeaders)
        .timeout(_timeout);
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((e) {
        final map = e as Map<String, dynamic>;
        return Product(
          id: map['product_id'] as int,
          name: map['name'] as String? ?? '',
          price: (map['price'] as num?)?.toDouble() ?? 0.0,
          stock: map['stock'] as int? ?? 0,
          category: map['category'] as String? ?? 'General',
          imageUrl: map['image_url'] as String? ?? '',
          discountPct: (map['discount_pct'] as num?)?.toDouble() ?? 0.0,
        );
      }).toList();
    }
    throw Exception(
        'Error ${response.statusCode} al cargar inventario de sucursal');
  }

  static Future<Map<String, dynamic>> updateBranchInventoryItem(
      int branchId, int productId, Map<String, dynamic> data) async {
    final response = await http
        .put(
          Uri.parse(ApiConfig.branchInventoryItem(branchId, productId)),
          headers: _authHeaders,
          body: json.encode(data),
        )
        .timeout(_timeout);
    final body = json.decode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200) return body;
    throw Exception(body['error'] ?? 'Error al actualizar inventario');
  }

  static Future<List<Product>> fetchLowStock() async {
    final response = await http
        .get(Uri.parse(ApiConfig.lowStock), headers: _authHeaders)
        .timeout(_timeout);
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data
          .map((e) => Product.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Error al cargar productos bajo stock');
  }

  static Future<Product> createProduct(Map<String, dynamic> data) async {
    final response = await http
        .post(Uri.parse(ApiConfig.products),
            headers: _authHeaders, body: json.encode(data))
        .timeout(_timeout);
    if (response.statusCode == 201) {
      return Product.fromJson(json.decode(response.body));
    }
    throw Exception('Error al crear producto');
  }

  static Future<Product> updateProduct(int id, Map<String, dynamic> data) async {
    final response = await http
        .put(Uri.parse('${ApiConfig.products}/$id'),
            headers: _authHeaders, body: json.encode(data))
        .timeout(_timeout);
    if (response.statusCode == 200) {
      return Product.fromJson(json.decode(response.body));
    }
    throw Exception('Error al actualizar producto');
  }

  static Future<void> deleteProduct(int id) async {
    final response = await http
        .delete(Uri.parse('${ApiConfig.products}/$id'), headers: _authHeaders)
        .timeout(_timeout);
    if (response.statusCode != 200) {
      throw Exception('Error al eliminar producto');
    }
  }

  // ── Ventas ────────────────────────────────────────────────

  static Future<Map<String, dynamic>> createSale({
    required List<Map<String, dynamic>> items,
    required String clientName,
    String paymentMethod = 'efectivo',
    int? branchId,
  }) async {
    final body = <String, dynamic>{
      'items': items,
      'client_name': clientName,
      'payment_method': paymentMethod,
    };
    if (branchId != null) body['branch_id'] = branchId;

    final response = await http
        .post(
          Uri.parse(ApiConfig.sales),
          headers: _authHeaders,
          body: json.encode(body),
        )
        .timeout(const Duration(seconds: 20));

    final respBody = json.decode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 201) return respBody;
    throw Exception(respBody['error'] ?? 'Error al registrar la venta');
  }

  static Future<List<Sale>> fetchSales({int? branchId}) async {
    final url = branchId != null
        ? '${ApiConfig.sales}?branch_id=$branchId'
        : ApiConfig.sales;
    final response = await http
        .get(Uri.parse(url), headers: _authHeaders)
        .timeout(_timeout);
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data
          .map((e) => Sale.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Error al cargar historial de ventas');
  }

  // ── Analytics ────────────────────────────────────────────

  static Future<Map<String, dynamic>> fetchAnalytics({int? branchId}) async {
    final response = await http
        .get(
          Uri.parse(ApiConfig.analyticsSummaryBranch(branchId)),
          headers: _authHeaders,
        )
        .timeout(_timeout);
    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Error al cargar analíticas');
  }

  static Future<List<Map<String, dynamic>>> fetchBranchComparison() async {
    final response = await http
        .get(Uri.parse(ApiConfig.branchComparison()), headers: _authHeaders)
        .timeout(_timeout);
    if (response.statusCode == 200) {
      return (json.decode(response.body) as List<dynamic>)
          .map((e) => e as Map<String, dynamic>)
          .toList();
    }
    throw Exception('Error al cargar comparativa de sucursales');
  }

  // ── Forecast ─────────────────────────────────────────────

  static Future<Map<String, dynamic>> fetchForecast({int? branchId}) async {
    final url = branchId != null
        ? '${ApiConfig.baseUrl}/api/insights/forecast?branch_id=$branchId'
        : '${ApiConfig.baseUrl}/api/insights/forecast';
    final response = await http
        .get(Uri.parse(url), headers: _authHeaders)
        .timeout(const Duration(seconds: 45));
    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Error ${response.statusCode} al cargar predicción de demanda');
  }

  // ── Combos ───────────────────────────────────────────────

  static Future<List<Combo>> fetchCombos({int? branchId}) async {
    final q = branchId != null ? '?branch_id=$branchId' : '';
    final response = await http
        .get(Uri.parse('${ApiConfig.baseUrl}/api/combos/$q'), headers: _authHeaders)
        .timeout(_timeout);
    if (response.statusCode == 200) {
      return (json.decode(response.body) as List<dynamic>)
          .map((e) => Combo.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Error ${response.statusCode} al cargar combos');
  }

  // ── Inventario raw (incluye offer_badge) ─────────────────

  static Future<List<Map<String, dynamic>>> fetchBranchInventoryRaw(
      int branchId) async {
    final response = await http
        .get(Uri.parse(ApiConfig.branchInventory(branchId)),
            headers: _authHeaders)
        .timeout(_timeout);
    if (response.statusCode == 200) {
      return (json.decode(response.body) as List<dynamic>)
          .map((e) => e as Map<String, dynamic>)
          .toList();
    }
    throw Exception(
        'Error ${response.statusCode} al cargar inventario de sucursal');
  }

  // ── Insights ─────────────────────────────────────────────

  static Future<List<Insight>> fetchInsights({int? branchId}) async {
    final response = await http
        .get(
          Uri.parse(ApiConfig.insightsBranch(branchId)),
          headers: _authHeaders,
        )
        .timeout(const Duration(seconds: 45));
    if (response.statusCode == 200) {
      final body = json.decode(response.body) as Map<String, dynamic>;
      final List<dynamic> data = (body['insights'] as List<dynamic>?) ?? [];
      return data
          .map((e) => Insight.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Error al cargar recomendaciones del Asesor IA');
  }

  // ── Chat ─────────────────────────────────────────────────

  static Future<String> sendChatMessage(String message,
      {int? branchId}) async {
    final body = <String, dynamic>{'message': message};
    if (branchId != null) body['branch_id'] = branchId;

    final response = await http
        .post(
          Uri.parse(ApiConfig.chatJson),
          headers: _authHeaders,
          body: json.encode(body),
        )
        .timeout(const Duration(seconds: 45));

    final respBody = json.decode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200) {
      return respBody['response'] as String? ?? '';
    }
    throw Exception(respBody['error'] ?? 'Error del asistente IA');
  }

  // ── Sucursales ────────────────────────────────────────────

  static Future<List<Branch>> fetchBranches() async {
    final response = await http
        .get(Uri.parse('${ApiConfig.branches}?active_only=false'),
            headers: _authHeaders)
        .timeout(_timeout);
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data
          .map((e) => Branch.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Error al cargar sucursales');
  }

  static Future<Branch> createBranch(Map<String, dynamic> data) async {
    final response = await http
        .post(Uri.parse(ApiConfig.branches),
            headers: _authHeaders, body: json.encode(data))
        .timeout(_timeout);
    final body = json.decode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 201) return Branch.fromJson(body);
    throw Exception(body['error'] ?? 'Error al crear sucursal');
  }

  static Future<Branch> updateBranch(int id, Map<String, dynamic> data) async {
    final response = await http
        .put(Uri.parse(ApiConfig.branch(id)),
            headers: _authHeaders, body: json.encode(data))
        .timeout(_timeout);
    final body = json.decode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200) return Branch.fromJson(body);
    throw Exception(body['error'] ?? 'Error al actualizar sucursal');
  }

  static Future<void> deleteBranch(int id) async {
    final response = await http
        .delete(Uri.parse(ApiConfig.branch(id)), headers: _authHeaders)
        .timeout(_timeout);
    if (response.statusCode != 200) {
      throw Exception('Error al eliminar sucursal');
    }
  }

  static Future<void> assignSeller(int branchId, int sellerId) async {
    final response = await http
        .post(Uri.parse(ApiConfig.branchAssign(branchId)),
            headers: _authHeaders,
            body: json.encode({'seller_id': sellerId}))
        .timeout(_timeout);
    if (response.statusCode != 201) {
      throw Exception('Error al asignar vendedor');
    }
  }

  static Future<void> unassignSeller(int branchId, int sellerId) async {
    final response = await http
        .delete(Uri.parse(ApiConfig.branchUnassign(branchId, sellerId)),
            headers: _authHeaders)
        .timeout(_timeout);
    if (response.statusCode != 200) {
      throw Exception('Error al desasignar vendedor');
    }
  }

  static Future<List<Map<String, dynamic>>> fetchBranchSellers(
      int branchId) async {
    final response = await http
        .get(Uri.parse(ApiConfig.branchSellers(branchId)),
            headers: _authHeaders)
        .timeout(_timeout);
    if (response.statusCode == 200) {
      return (json.decode(response.body) as List<dynamic>)
          .map((e) => e as Map<String, dynamic>)
          .toList();
    }
    throw Exception('Error al cargar vendedores de la sucursal');
  }

  static Future<List<Map<String, dynamic>>> fetchAllSellers() async {
    final response = await http
        .get(Uri.parse('${ApiConfig.baseUrl}/api/auth/sellers'),
            headers: _authHeaders)
        .timeout(_timeout);
    if (response.statusCode == 200) {
      return (json.decode(response.body) as List<dynamic>)
          .map((e) => e as Map<String, dynamic>)
          .toList();
    }
    throw Exception('Error al cargar vendedores');
  }
}
