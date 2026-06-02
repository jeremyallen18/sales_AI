class SaleItem {
  final int id;
  final int productId;
  final String productName;
  final int quantity;
  final double price;
  final double subtotal;

  const SaleItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.price,
    required this.subtotal,
  });

  factory SaleItem.fromJson(Map<String, dynamic> json) {
    return SaleItem(
      id: json['id'] as int,
      productId: json['product_id'] as int,
      productName: (json['product_name'] as String?) ?? '',
      quantity: json['quantity'] as int,
      price: (json['price'] as num).toDouble(),
      subtotal: (json['subtotal'] as num).toDouble(),
    );
  }
}
