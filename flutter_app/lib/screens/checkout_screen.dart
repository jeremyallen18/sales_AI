import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../providers/cart_provider.dart';
import '../providers/customer_auth_provider.dart';
import '../providers/branch_provider.dart';
import 'order_success_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _nameCtrl = TextEditingController();
  final _cashCtrl = TextEditingController();
  final _cardNumberCtrl = TextEditingController();
  final _cardHolderCtrl = TextEditingController();
  final _expiryCtrl = TextEditingController();
  final _cvvCtrl = TextEditingController();
  String _selectedMethod = 'efectivo';
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<CustomerAuthProvider>();
      if (auth.isLoggedIn && _nameCtrl.text.isEmpty) {
        _nameCtrl.text = auth.displayName;
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cashCtrl.dispose();
    _cardNumberCtrl.dispose();
    _cardHolderCtrl.dispose();
    _expiryCtrl.dispose();
    _cvvCtrl.dispose();
    super.dispose();
  }

  double get _cashReceived => double.tryParse(_cashCtrl.text) ?? 0.0;
  double _change(double total) =>
      (_cashReceived - total).clamp(0.0, double.infinity);

  Future<void> _submit() async {
    final cart = context.read<CartProvider>();
    if (_selectedMethod == 'efectivo' && _cashCtrl.text.isNotEmpty) {
      if (_cashReceived < cart.total) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('El monto recibido es menor al total'),
          backgroundColor: AppColors.error,
        ));
        return;
      }
    }
    if (_selectedMethod == 'tarjeta') {
      if (_cardNumberCtrl.text.replaceAll(' ', '').length < 16 ||
          _cardHolderCtrl.text.trim().isEmpty ||
          _expiryCtrl.text.length < 5 ||
          _cvvCtrl.text.length < 3) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Completa todos los datos de la tarjeta'),
          backgroundColor: AppColors.error,
        ));
        return;
      }
    }

    setState(() => _processing = true);
    try {
      final authProv = context.read<CustomerAuthProvider>();
      final branchProv = context.read<BranchProvider>();
      final result = await cart.checkout(
        _nameCtrl.text.trim(),
        _selectedMethod,
        appToken: authProv.appToken,
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OrderSuccessScreen(
            sale: result,
            cashReceived:
                _selectedMethod == 'efectivo' && _cashCtrl.text.isNotEmpty
                    ? _cashReceived
                    : null,
            branchId: branchProv.selectedBranchId,
            branchName: branchProv.selectedBranch?.name,
            appToken: authProv.isLoggedIn ? authProv.appToken : null,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final items = cart.items.values.toList();

    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Finalizar compra')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Resumen ──
          _SectionTitle('Resumen del pedido'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cs.surfaceContainer,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.outline),
            ),
            child: Column(
              children: [
                ...items.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${item.product.name} × ${item.quantity}',
                              style: TextStyle(
                                  color: cs.onSurface, fontSize: 13),
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (item.product.discountPct > 0)
                                Text(
                                  '\$${(item.product.price * item.quantity).toStringAsFixed(2)}',
                                  style: TextStyle(
                                      color: cs.onSurfaceVariant,
                                      fontSize: 11,
                                      decoration: TextDecoration.lineThrough),
                                ),
                              Text(
                                '\$${item.subtotal.toStringAsFixed(2)}',
                                style: TextStyle(
                                    color: item.product.discountPct > 0
                                        ? AppColors.success
                                        : AppColors.onSurfaceVariant,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ],
                      ),
                    )),
                if (cart.discountAmount > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Descuento',
                            style: TextStyle(
                                color: AppColors.success,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                        Text(
                          '-\$${cart.discountAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                              color: AppColors.success,
                              fontSize: 13,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                Divider(color: cs.outline),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total',
                      style: GoogleFonts.montserrat(
                          color: cs.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '\$${cart.total.toStringAsFixed(2)}',
                      style: GoogleFonts.montserrat(
                          color: cs.primary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('IVA incluido (16%)',
                        style: TextStyle(
                            color: cs.onSurfaceVariant, fontSize: 11)),
                    Text(
                      '\$${cart.taxAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                          color: cs.onSurfaceVariant, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Datos del cliente ──
          _SectionTitle('Tus datos'),
          const SizedBox(height: 10),
          TextField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            style: TextStyle(color: cs.onSurface),
            decoration: InputDecoration(
              labelText: 'Tu nombre (opcional)',
              hintText: 'Ej: María García',
              prefixIcon:
                  Icon(Icons.person_outline, color: cs.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 24),

          // ── Método de pago ──
          _SectionTitle('Método de pago'),
          const SizedBox(height: 10),
          _PaymentMethodSelector(
            selected: _selectedMethod,
            onChanged: (m) => setState(() {
              _selectedMethod = m;
              _cashCtrl.clear();
              _cardNumberCtrl.clear();
              _cardHolderCtrl.clear();
              _expiryCtrl.clear();
              _cvvCtrl.clear();
            }),
          ),

          // ── Campos de tarjeta ──
          if (_selectedMethod == 'tarjeta') ...[
            const SizedBox(height: 14),
            _CardForm(
              cardNumberCtrl: _cardNumberCtrl,
              cardHolderCtrl: _cardHolderCtrl,
              expiryCtrl: _expiryCtrl,
              cvvCtrl: _cvvCtrl,
            ),
          ],

          // ── Campo de efectivo ──
          if (_selectedMethod == 'efectivo') ...[
            const SizedBox(height: 14),
            TextField(
              controller: _cashCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))
              ],
              style: TextStyle(color: cs.onSurface),
              decoration: InputDecoration(
                labelText: 'Monto recibido (opcional)',
                hintText: 'Ej: 100.00',
                prefixIcon: Icon(Icons.payments_outlined,
                    color: cs.onSurfaceVariant),
              ),
              onChanged: (_) => setState(() {}),
            ),
            if (_cashCtrl.text.isNotEmpty && _cashReceived >= cart.total) ...[
              const SizedBox(height: 10),
              _StatusBox(
                color: AppColors.success,
                label: 'Cambio',
                value: '\$${_change(cart.total).toStringAsFixed(2)}',
              ),
            ],
            if (_cashCtrl.text.isNotEmpty && _cashReceived < cart.total) ...[
              const SizedBox(height: 10),
              _StatusBox(
                color: AppColors.error,
                label: 'Falta',
                value: '\$${(cart.total - _cashReceived).toStringAsFixed(2)}',
              ),
            ],
          ],

          const SizedBox(height: 32),

          // ── Confirmar ──
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _processing ? null : _submit,
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16)),
              child: _processing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Confirmar compra',
                      style: TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ── Caja de estado (cambio / falta) ──────────────────────────────────────────

class _StatusBox extends StatelessWidget {
  final Color color;
  final String label;
  final String value;
  const _StatusBox(
      {required this.color, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 18)),
        ],
      ),
    );
  }
}

// ── Selector de método de pago ────────────────────────────────────────────────

class _PaymentMethodSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const _PaymentMethodSelector(
      {required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const methods = [
      ('efectivo', Icons.payments_outlined, 'Efectivo'),
      ('tarjeta', Icons.credit_card_outlined, 'Tarjeta'),
      ('transferencia', Icons.account_balance_outlined, 'Transferencia'),
    ];

    final cs = Theme.of(context).colorScheme;
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
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? cs.primaryContainer
                      : cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? cs.primary : cs.outline,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(m.$2,
                        color: isSelected
                            ? cs.primary
                            : cs.onSurfaceVariant,
                        size: 22),
                    const SizedBox(height: 4),
                    Text(
                      m.$3,
                      style: TextStyle(
                        color: isSelected
                            ? cs.primary
                            : cs.onSurfaceVariant,
                        fontSize: 11,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
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

// ── Formatter: número de tarjeta XXXX XXXX XXXX XXXX ──
class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final limited = digits.length > 16 ? digits.substring(0, 16) : digits;
    final buffer = StringBuffer();
    for (int i = 0; i < limited.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(limited[i]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

// ── Formatter: fecha MM/YY ──
class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final limited = digits.length > 4 ? digits.substring(0, 4) : digits;
    final buffer = StringBuffer();
    for (int i = 0; i < limited.length; i++) {
      if (i == 2) buffer.write('/');
      buffer.write(limited[i]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

// ── Formulario de tarjeta ──────────────────────────────────────────────────────
class _CardForm extends StatelessWidget {
  final TextEditingController cardNumberCtrl;
  final TextEditingController cardHolderCtrl;
  final TextEditingController expiryCtrl;
  final TextEditingController cvvCtrl;

  const _CardForm({
    required this.cardNumberCtrl,
    required this.cardHolderCtrl,
    required this.expiryCtrl,
    required this.cvvCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: cardNumberCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [_CardNumberFormatter()],
          style: const TextStyle(color: AppColors.onSurface, letterSpacing: 2),
          decoration: const InputDecoration(
            labelText: 'Número de tarjeta',
            hintText: '4242 4242 4242 4242',
            prefixIcon: Icon(Icons.credit_card_outlined,
                color: AppColors.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: cardHolderCtrl,
          textCapitalization: TextCapitalization.words,
          style: const TextStyle(color: AppColors.onSurface),
          decoration: const InputDecoration(
            labelText: 'Nombre del titular',
            hintText: 'Ej: Juan Pérez',
            prefixIcon: Icon(Icons.person_outline,
                color: AppColors.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: expiryCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [_ExpiryFormatter()],
                style: const TextStyle(color: AppColors.onSurface),
                decoration: const InputDecoration(
                  labelText: 'Vencimiento',
                  hintText: 'MM/YY',
                  prefixIcon: Icon(Icons.calendar_today_outlined,
                      color: AppColors.onSurfaceVariant),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: cvvCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(3),
                ],
                obscureText: true,
                style: const TextStyle(color: AppColors.onSurface),
                decoration: const InputDecoration(
                  labelText: 'CVV',
                  hintText: '123',
                  prefixIcon: Icon(Icons.lock_outline,
                      color: AppColors.onSurfaceVariant),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: GoogleFonts.montserrat(
          color: AppColors.onSurface,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      );
}
