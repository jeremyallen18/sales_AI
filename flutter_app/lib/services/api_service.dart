import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/product.dart';

class ApiService {
  // ── Productos ─────────────────────────────────────────────

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

  // ── Ventas ────────────────────────────────────────────────

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

    if (response.statusCode == 201) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    final body = json.decode(response.body) as Map<String, dynamic>;
    throw Exception(body['error'] ?? 'Error al registrar la venta');
  }

  // ── Chatbot de tienda ─────────────────────────────────────

  static Future<String> sendChatMessage(String message) async {
    final response = await http
        .post(
          Uri.parse(ApiConfig.storeChat),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'message': message}),
        )
        .timeout(const Duration(seconds: 30));

    final body = json.decode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200) {
      return body['response'] as String? ?? '';
    }
    throw Exception(body['error'] ?? 'Error del asistente IA');
  }
}
