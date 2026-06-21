class ComboItem {
  final int productId;
  final String productName;
  final String productImage;
  final double productPrice;
  final int quantity;

  const ComboItem({
    required this.productId,
    required this.productName,
    required this.productImage,
    required this.productPrice,
    required this.quantity,
  });

  factory ComboItem.fromJson(Map<String, dynamic> json) => ComboItem(
        productId: json['product_id'] as int,
        productName: json['product_name'] as String? ?? '',
        productImage: json['product_image'] as String? ?? '',
        productPrice: (json['product_price'] as num?)?.toDouble() ?? 0.0,
        quantity: json['quantity'] as int? ?? 1,
      );
}

class Combo {
  final int id;
  final String name;
  final String description;
  final double price;
  final String imageUrl;
  final bool isActive;
  final int? branchId;
  final List<ComboItem> items;

  const Combo({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.isActive,
    this.branchId,
    required this.items,
  });

  factory Combo.fromJson(Map<String, dynamic> json) => Combo(
        id: json['id'] as int,
        name: json['name'] as String,
        description: json['description'] as String? ?? '',
        price: (json['price'] as num).toDouble(),
        imageUrl: json['image_url'] as String? ?? '',
        isActive: json['is_active'] as bool? ?? true,
        branchId: json['branch_id'] as int?,
        items: ((json['items'] as List<dynamic>?) ?? [])
            .map((e) => ComboItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  String get itemsSummary =>
      items.map((i) => '${i.productName} x${i.quantity}').join(' + ');
}
