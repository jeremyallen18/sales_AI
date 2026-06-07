class Product {
  final int id;
  final String name;
  final double price;
  final int stock;
  final String category;
  final String imageUrl;
  final double discountPct;

  const Product({
    required this.id,
    required this.name,
    required this.price,
    required this.stock,
    required this.category,
    required this.imageUrl,
    this.discountPct = 0.0,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as int,
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      stock: json['stock'] as int,
      category: (json['category'] as String?) ?? 'General',
      imageUrl: (json['image_url'] as String?) ?? '',
      discountPct: (json['discount_pct'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'price': price,
        'stock': stock,
        'category': category,
        'image_url': imageUrl,
        'discount_pct': discountPct,
      };

  bool get isLowStock => stock <= 10;
}
