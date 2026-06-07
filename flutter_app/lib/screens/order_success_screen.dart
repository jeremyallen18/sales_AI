import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';

class OrderSuccessScreen extends StatelessWidget {
  final Map<String, dynamic> sale;
  final double? cashReceived;
  const OrderSuccessScreen(
      {super.key, required this.sale, this.cashReceived});

  @override
  Widget build(BuildContext context) {
    final saleId = sale['id'] as int?;
    final total = (sale['total_amount'] as num?)?.toDouble() ?? 0.0;
    final items = (sale['items'] as List?) ?? [];
    final clientName = (sale['client_name'] as String?) ?? '';
    final paymentMethod =
        (sale['payment_method'] as String?) ?? 'efectivo';
    final change = cashReceived != null
        ? (cashReceived! - total).clamp(0.0, double.infinity)
        : null;

    const methodIcons = {
      'efectivo': Icons.payments_outlined,
      'tarjeta': Icons.credit_card_outlined,
      'transferencia': Icons.account_balance_outlined,
    };
    const methodLabels = {
      'efectivo': 'Efectivo',
      'tarjeta': 'Tarjeta',
      'transferencia': 'Transferencia',
    };

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Compra exitosa')),
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
                  color: AppColors.success.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.5),
                      width: 2),
                ),
                child: const Icon(Icons.check_circle_outline,
                    color: AppColors.success, size: 65),
              ),
              const SizedBox(height: 20),

              Text(
                '¡Compra exitosa!',
                style: GoogleFonts.montserrat(
                    color: AppColors.onSurface,
                    fontSize: 24,
                    fontWeight: FontWeight.w700),
              ),

              if (clientName.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Gracias, $clientName',
                  style: const TextStyle(
                      color: AppColors.onSurfaceVariant, fontSize: 14),
                ),
              ],

              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Pedido #${saleId?.toString().padLeft(4, '0') ?? '----'}',
                  style: GoogleFonts.montserrat(
                      color: AppColors.onSecondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13),
                ),
              ),
              const SizedBox(height: 24),

              // ── Desglose ──
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.outline),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
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
                            Container(
                              width: 6,
                              height: 6,
                              margin: const EdgeInsets.only(right: 8, top: 1),
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            Expanded(
                              child: Text('$name × $qty',
                                  style: const TextStyle(
                                      color: AppColors.onSurface,
                                      fontSize: 13)),
                            ),
                            Text('\$${subtotal.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    color: AppColors.onSurfaceVariant,
                                    fontSize: 13)),
                          ],
                        ),
                      );
                    }),
                    const Divider(color: AppColors.outline),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total',
                          style: GoogleFonts.montserrat(
                              color: AppColors.onSurface,
                              fontWeight: FontWeight.w700,
                              fontSize: 15),
                        ),
                        Text(
                          '\$${total.toStringAsFixed(2)}',
                          style: GoogleFonts.montserrat(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(
                            methodIcons[paymentMethod] ??
                                Icons.payments_outlined,
                            color: AppColors.onSurfaceVariant,
                            size: 16),
                        const SizedBox(width: 6),
                        Text(
                          methodLabels[paymentMethod] ?? paymentMethod,
                          style: const TextStyle(
                              color: AppColors.onSurfaceVariant, fontSize: 13),
                        ),
                        const Spacer(),
                        const Icon(Icons.check_circle,
                            color: AppColors.success, size: 16),
                        const SizedBox(width: 4),
                        const Text('Aprobado',
                            style: TextStyle(
                                color: AppColors.success, fontSize: 13)),
                      ],
                    ),
                    if (change != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Cambio',
                              style: TextStyle(
                                  color: AppColors.onSurfaceVariant,
                                  fontSize: 13)),
                          Text(
                            '\$${change.toStringAsFixed(2)}',
                            style: const TextStyle(
                                color: AppColors.success,
                                fontWeight: FontWeight.bold,
                                fontSize: 15),
                          ),
                        ],
                      ),
                    ],
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
