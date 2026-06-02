import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../providers/cart_provider.dart';
import '../providers/products_provider.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _clientCtrl = TextEditingController();
  bool _processing = false;

  @override
  void dispose() {
    _clientCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final cart = context.read<CartProvider>();
    if (cart.isEmpty) return;

    setState(() => _processing = true);
    try {
      final result = await cart.checkout(_clientCtrl.text.trim());
      if (!mounted) return;

      // Reload products to update stock
      context.read<ProductsProvider>().load();

      final saleId = result['id'];
      final total = (result['total_amount'] as num).toDouble();
      final fmt = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          backgroundColor: AppColors.navyCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: AppColors.success, size: 28),
              SizedBox(width: 10),
              Text('Venta Registrada', style: TextStyle(color: Colors.white)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Folio: #${saleId.toString().padLeft(4, '0')}',
                  style: const TextStyle(color: AppColors.textSec)),
              const SizedBox(height: 4),
              Text('Total: ${fmt.format(total)}',
                  style: const TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.bold,
                      fontSize: 20)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // close dialog
                Navigator.of(context).pop(); // back to POS
              },
              child: const Text('ACEPTAR'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final fmt = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

    return Scaffold(
      appBar: AppBar(title: const Text('COBRAR')),
      body: Column(
        children: [
          // Client name
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _clientCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre del cliente (opcional)',
                prefixIcon: Icon(Icons.person_outline, color: AppColors.textSec),
              ),
              style: const TextStyle(color: Colors.white),
            ),
          ),

          // Items list
          Expanded(
            child: cart.isEmpty
                ? const Center(
                    child: Text('Carrito vacío',
                        style: TextStyle(color: AppColors.textSec)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: cart.items.length,
                    itemBuilder: (_, i) {
                      final item = cart.items.values.elementAt(i);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.navyCard,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.product.name,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600)),
                                  Text(
                                    '${fmt.format(item.product.price)} x ${item.quantity}',
                                    style: const TextStyle(
                                        color: AppColors.textSec, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            // Quantity controls
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline,
                                      color: AppColors.textSec, size: 22),
                                  onPressed: () => cart.updateQuantity(
                                      item.product.id, item.quantity - 1),
                                  visualDensity: VisualDensity.compact,
                                ),
                                Text('${item.quantity}',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold)),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline,
                                      color: AppColors.accent, size: 22),
                                  onPressed: item.quantity < item.product.stock
                                      ? () => cart.updateQuantity(
                                          item.product.id, item.quantity + 1)
                                      : null,
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            Text(
                              fmt.format(item.subtotal),
                              style: const TextStyle(
                                  color: AppColors.accent,
                                  fontWeight: FontWeight.bold),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: AppColors.danger, size: 20),
                              onPressed: () => cart.remove(item.product.id),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Total + confirm
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppColors.navyCard,
              border: Border(top: BorderSide(color: AppColors.divider)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('TOTAL',
                          style: TextStyle(
                              color: AppColors.textSec,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                      Text(
                        fmt.format(cart.total),
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 24),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed:
                          (cart.isEmpty || _processing) ? null : _confirm,
                      icon: _processing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check),
                      label: Text(_processing
                          ? 'Procesando...'
                          : 'CONFIRMAR VENTA'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
