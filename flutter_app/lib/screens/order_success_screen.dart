import 'package:flutter/material.dart';
import '../main.dart';

class OrderSuccessScreen extends StatelessWidget {
  final Map<String, dynamic> sale;
  const OrderSuccessScreen({super.key, required this.sale});

  @override
  Widget build(BuildContext context) {
    final saleId = sale['id'] as int?;
    final total = (sale['total_amount'] as num?)?.toDouble() ?? 0.0;
    final items = (sale['items'] as List?) ?? [];
    final clientName = (sale['client_name'] as String?) ?? '';

    return Scaffold(
      backgroundColor: AppColors.navyBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),

              // ── Ícono de éxito ──
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.4),
                      width: 2),
                ),
                child: const Icon(Icons.check_circle_outline,
                    color: AppColors.success, size: 65),
              ),
              const SizedBox(height: 22),

              const Text('¡Compra exitosa!',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold)),

              if (clientName.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('Gracias, $clientName',
                    style: const TextStyle(
                        color: AppColors.textSec, fontSize: 14)),
              ],

              const SizedBox(height: 6),
              Text(
                'Pedido #${saleId?.toString().padLeft(4, '0') ?? '----'}',
                style: const TextStyle(
                    color: AppColors.cartAmber,
                    fontWeight: FontWeight.w700,
                    fontSize: 15),
              ),
              const SizedBox(height: 24),

              // ── Desglose ──
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.navyCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.navyLight),
                ),
                child: Column(
                  children: [
                    ...items.map((item) {
                      final name =
                          (item['product_name'] as String?) ?? 'Producto';
                      final qty = (item['quantity'] as int?) ?? 1;
                      final subtotal =
                          (item['subtotal'] as num?)?.toDouble() ?? 0.0;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 7),
                        child: Row(
                          children: [
                            const Text('○ ',
                                style: TextStyle(
                                    color: AppColors.textSec, fontSize: 13)),
                            Expanded(
                              child: Text('$name × $qty',
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 13)),
                            ),
                            Text('\$${subtotal.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    color: AppColors.textSec, fontSize: 13)),
                          ],
                        ),
                      );
                    }),
                    const Divider(color: AppColors.divider),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                        Text('\$${total.toStringAsFixed(2)}',
                            style: const TextStyle(
                                color: AppColors.cartAmber,
                                fontWeight: FontWeight.bold,
                                fontSize: 20)),
                      ],
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // ── Volver ──
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () =>
                      Navigator.of(context).popUntil((r) => r.isFirst),
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: const Text('Seguir comprando',
                      style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
