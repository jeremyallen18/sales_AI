import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../models/insight.dart';

class ApiService {
  static const _timeout = Duration(seconds: 15);

  // ── Auth ──────────────────────────────────────────────────

  static Future<Map<String, dynamic>> login(String username, String password) async {
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

  // ── Products ─────────────────────────────────────────────

  static Future<List<Product>> fetchProducts() async {
    final response =
        await http.get(Uri.parse(ApiConfig.products)).timeout(_timeout);
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data
          .map((e) => Product.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Error ${response.statusCode} al cargar productos');
  }

  static Future<List<Product>> fetchLowStock() async {
    final response =
        await http.get(Uri.parse(ApiConfig.lowStock)).timeout(_timeout);
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
            headers: {'Content-Type': 'application/json'},
            body: json.encode(data))
        .timeout(_timeout);
    if (response.statusCode == 201) {
      return Product.fromJson(json.decode(response.body));
    }
    throw Exception('Error al crear producto');
  }

  static Future<Product> updateProduct(int id, Map<String, dynamic> data) async {
    final response = await http
        .put(Uri.parse('${ApiConfig.products}/$id'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(data))
        .timeout(_timeout);
    if (response.statusCode == 200) {
      return Product.fromJson(json.decode(response.body));
    }
    throw Exception('Error al actualizar producto');
  }

  static Future<void> deleteProduct(int id) async {
    final response = await http
        .delete(Uri.parse('${ApiConfig.products}/$id'))
        .timeout(_timeout);
    if (response.statusCode != 200) {
      throw Exception('Error al eliminar producto');
    }
  }

  // ── Sales ────────────────────────────────────────────────

  static Future<Map<String, dynamic>> createSale({
    required List<Map<String, dynamic>> items,
    required String clientName,
    String paymentMethod = 'efectivo',
  }) async {
    final response = await http
        .post(
          Uri.parse(ApiConfig.sales),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'items': items,
            'client_name': clientName,
            'payment_method': paymentMethod,
          }),
        )
        .timeout(const Duration(seconds: 20));

    final body = json.decode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 201) return body;
    throw Exception(body['error'] ?? 'Error al registrar la venta');
  }

  static Future<List<Sale>> fetchSales() async {
    final response =
        await http.get(Uri.parse(ApiConfig.sales)).timeout(_timeout);
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data
          .map((e) => Sale.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Error al cargar historial de ventas');
  }

  // ── Analytics ────────────────────────────────────────────

  static Future<Map<String, dynamic>> fetchAnalytics() async {
    final response = await http
        .get(Uri.parse(ApiConfig.analyticsSummary))
        .timeout(_timeout);
    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Error al cargar analíticas');
  }

  // ── Insights (Asesor IA Proactivo) ───────────────────────

  static Future<List<Insight>> fetchInsights() async {
    final response = await http
        .get(Uri.parse(ApiConfig.insights))
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

  // ── Chat (JSON) ──────────────────────────────────────────

  static Future<String> sendChatMessage(String message) async {
    final response = await http
        .post(
          Uri.parse(ApiConfig.chatJson),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'message': message}),
        )
        .timeout(const Duration(seconds: 45));

    final body = json.decode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200) {
      return body['response'] as String? ?? '';
    }
    throw Exception(body['error'] ?? 'Error del asistente IA');
  }
}
