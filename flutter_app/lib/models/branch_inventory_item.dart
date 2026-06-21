import 'product.dart';

class BranchInventoryItem {
  final int id;
  final int branchId;
  final int productId;
  final int stock;
  final double price;
  final double discountPct;
  final String name;
  final String category;
  final String imageUrl;

  const BranchInventoryItem({
    required this.id,
    required this.branchId,
    required this.productId,
    required this.stock,
    required this.price,
    this.discountPct = 0.0,
    required this.name,
    this.category = 'General',
    this.imageUrl = '',
  });

  factory BranchInventoryItem.fromJson(Map<String, dynamic> json) {
    return BranchInventoryItem(
      id: json['id'] as int,
      branchId: json['branch_id'] as int,
      productId: json['product_id'] as int,
      stock: json['stock'] as int? ?? 0,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      discountPct: (json['discount_pct'] as num?)?.toDouble() ?? 0.0,
      name: json['name'] as String? ?? '',
      category: json['category'] as String? ?? 'General',
      imageUrl: json['image_url'] as String? ?? '',
    );
  }

  /// Convierte a Product para compatibilidad con el carrito existente.
  Product toProduct() {
    return Product(
      id: productId,
      name: name,
      price: price,
      stock: stock,
      category: category,
      imageUrl: imageUrl,
      discountPct: discountPct,
    );
  }
}
