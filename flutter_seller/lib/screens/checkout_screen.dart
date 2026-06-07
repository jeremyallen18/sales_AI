import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final _cashCtrl = TextEditingController();
  String _selectedMethod = 'efectivo';
  bool _processing = false;

  @override
  void dispose() {
    _clientCtrl.dispose();
    _cashCtrl.dispose();
    super.dispose();
  }

  double get _cashReceived => double.tryParse(_cashCtrl.text) ?? 0.0;

  Future<void> _confirm() async {
    final cart = context.read<CartProvider>();
    if (cart.isEmpty) return;

    if (_selectedMethod == 'efectivo' && _cashCtrl.text.isNotEmpty) {
      if (_cashReceived < cart.total) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('El monto recibido es menor al total'),
          backgroundColor: AppColors.danger,
        ));
        return;
      }
    }

    setState(() => _processing = true);
    try {
      final result = await cart.checkout(_clientCtrl.text.trim(), _selectedMethod);
      if (!mounted) return;

      context.read<ProductsProvider>().load();

      final saleId = result['id'];
      final total = (result['total_amount'] as num).toDouble();
      final paymentMethod = (result['payment_method'] as String?) ?? _selectedMethod;
      final fmt = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
      final change = (_selectedMethod == 'efectivo' && _cashCtrl.text.isNotEmpty)
          ? (_cashReceived - total).clamp(0.0, double.infinity)
          : null;

      const methodLabels = {
        'efectivo': 'Efectivo',
        'tarjeta': 'Tarjeta',
        'transferencia': 'Transferencia',
      };
      const methodIcons = {
        'efectivo': Icons.payments_outlined,
        'tarjeta': Icons.credit_card_outlined,
        'transferencia': Icons.account_balance_outlined,
      };

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
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(methodIcons[paymentMethod] ?? Icons.payments_outlined,
                      color: AppColors.textSec, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    methodLabels[paymentMethod] ?? paymentMethod,
                    style: const TextStyle(color: AppColors.textSec, fontSize: 13),
                  ),
                ],
              ),
              if (change != null) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Cambio:',
                        style: TextStyle(color: AppColors.textSec, fontSize: 14)),
                    Text(
                      fmt.format(change),
                      style: const TextStyle(
                          color: AppColors.success,
                          fontWeight: FontWeight.bold,
                          fontSize: 16),
                    ),
                  ],
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: TextField(
              controller: _clientCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre del cliente (opcional)',
                prefixIcon: Icon(Icons.person_outline, color: AppColors.textSec),
              ),
              style: const TextStyle(color: Colors.white),
            ),
          ),

          // Payment method selector
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('MÉTODO DE PAGO',
                    style: TextStyle(
                        color: AppColors.textSec,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8)),
                const SizedBox(height: 8),
                _PaymentMethodSelector(
                  selected: _selectedMethod,
                  onChanged: (m) => setState(() {
                    _selectedMethod = m;
                    _cashCtrl.clear();
                  }),
                ),
              ],
            ),
          ),

          // Cash received field
          if (_selectedMethod == 'efectivo')
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                children: [
                  TextField(
                    controller: _cashCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))
                    ],
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Monto recibido (opcional)',
                      prefixIcon:
                          Icon(Icons.payments_outlined, color: AppColors.textSec),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  if (_cashCtrl.text.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _CashFeedback(
                      cashReceived: _cashReceived,
                      total: cart.total,
                      fmt: fmt,
                    ),
                  ],
                ],
              ),
            ),

          // Items list
          Expanded(
            child: cart.isEmpty
                ? const Center(
                    child: Text('Carrito vacío',
                        style: TextStyle(color: AppColors.textSec)))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
                                    item.product.discountPct > 0
                                        ? '${fmt.format(item.unitPrice)} x ${item.quantity}  (-${item.product.discountPct.toStringAsFixed(0)}%)'
                                        : '${fmt.format(item.product.price)} x ${item.quantity}',
                                    style: TextStyle(
                                        color: item.product.discountPct > 0
                                            ? AppColors.success
                                            : AppColors.textSec,
                                        fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
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
                      const Text('Subtotal',
                          style: TextStyle(
                              color: AppColors.textSec, fontSize: 13)),
                      Text(fmt.format(cart.subtotalBruto),
                          style: const TextStyle(
                              color: AppColors.textSec, fontSize: 13)),
                    ],
                  ),
                  if (cart.discountAmount > 0) ...[
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Descuento',
                            style: TextStyle(
                                color: AppColors.success, fontSize: 13)),
                        Text('-${fmt.format(cart.discountAmount)}',
                            style: const TextStyle(
                                color: AppColors.success, fontSize: 13)),
                      ],
                    ),
                  ],
                  const Divider(color: AppColors.divider, height: 12),
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
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('IVA incluido (16%)',
                          style: TextStyle(
                              color: AppColors.textSec, fontSize: 11)),
                      Text(fmt.format(cart.taxAmount),
                          style: const TextStyle(
                              color: AppColors.textSec, fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: (cart.isEmpty || _processing) ? null : _confirm,
                      icon: _processing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check),
                      label: Text(_processing ? 'Procesando...' : 'CONFIRMAR VENTA'),
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

class _PaymentMethodSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _PaymentMethodSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const methods = [
      ('efectivo', Icons.payments_outlined, 'Efectivo'),
      ('tarjeta', Icons.credit_card_outlined, 'Tarjeta'),
      ('transferencia', Icons.account_balance_outlined, 'Transferencia'),
    ];

    return Row(
      children: methods.map((m) {
        final isSelected = selected == m.$1;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onChanged(m.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.accent.withValues(alpha: 0.15)
                      : AppColors.navyBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? AppColors.accent : AppColors.divider,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(m.$2,
                        color: isSelected ? AppColors.accent : AppColors.textSec,
                        size: 20),
                    const SizedBox(height: 4),
                    Text(m.$3,
                        style: TextStyle(
                          color: isSelected ? AppColors.accent : AppColors.textSec,
                          fontSize: 10,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        )),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _CashFeedback extends StatelessWidget {
  final double cashReceived;
  final double total;
  final NumberFormat fmt;

  const _CashFeedback({
    required this.cashReceived,
    required this.total,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final sufficient = cashReceived >= total;
    final amount = sufficient ? cashReceived - total : total - cashReceived;
    final label = sufficient ? 'Cambio' : 'Falta';
    final color = sufficient ? AppColors.success : AppColors.danger;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          Text(fmt.format(amount),
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }
}
