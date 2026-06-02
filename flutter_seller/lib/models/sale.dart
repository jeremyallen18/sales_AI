import 'sale_item.dart';

class Sale {
  final int id;
  final String clientName;
  final double totalAmount;
  final DateTime createdAt;
  final List<SaleItem> items;

  const Sale({
    required this.id,
    required this.clientName,
    required this.totalAmount,
    required this.createdAt,
    required this.items,
  });

  factory Sale.fromJson(Map<String, dynamic> json) {
    return Sale(
      id: json['id'] as int,
      clientName: (json['client_name'] as String?) ?? '',
      totalAmount: (json['total_amount'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => SaleItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
