class Product {
  final int id;
  final String name;
  final double price;
  final int stock;
  final String category;
  final String imageUrl;

  const Product({
    required this.id,
    required this.name,
    required this.price,
    required this.stock,
    required this.category,
    required this.imageUrl,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as int,
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      stock: json['stock'] as int,
      category: (json['category'] as String?) ?? 'General',
      imageUrl: (json['image_url'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'price': price,
        'stock': stock,
        'category': category,
        'image_url': imageUrl,
      };

  bool get isLowStock => stock <= 10;
}
