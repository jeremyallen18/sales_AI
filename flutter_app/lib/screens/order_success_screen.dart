import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import '../widgets/branch_rating_sheet.dart';

class OrderSuccessScreen extends StatefulWidget {
  final Map<String, dynamic> sale;
  final double? cashReceived;
  final int? branchId;
  final String? branchName;
  final String? appToken;
  const OrderSuccessScreen({
    super.key,
    required this.sale,
    this.cashReceived,
    this.branchId,
    this.branchName,
    this.appToken,
  });

  @override
  State<OrderSuccessScreen> createState() => _OrderSuccessScreenState();
}

class _OrderSuccessScreenState extends State<OrderSuccessScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  // Fase 1 (0.00–0.40): el carrito entra desde la izquierda hasta el centro.
  // Fase 2 (0.42–0.60): el carrito sale por la derecha "dejando" el pedido.
  // Fase 3 (0.50–0.85): la palomita aparece con rebote y el anillo pulsa.
  // Fase 4 (0.65–1.00): el resto del contenido aparece deslizándose.
  late final Animation<double> _cartIn;
  late final Animation<double> _cartOut;
  late final Animation<double> _check;
  late final Animation<double> _ring;
  late final Animation<double> _content;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2200));
    _cartIn = CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.40, curve: Curves.easeOutCubic));
    _cartOut = CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.42, 0.60, curve: Curves.easeInCubic));
    _check = CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.50, 0.85, curve: Curves.elasticOut));
    _ring = CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.50, 0.95, curve: Curves.easeOut));
    _content = CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.65, 1.0, curve: Curves.easeOutCubic));
    _ctrl.forward().then((_) => _maybeShowRatingPrompt());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _maybeShowRatingPrompt() {
    final branchId = widget.branchId;
    final token = widget.appToken;
    if (branchId == null || token == null || token.isEmpty) return;
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => BranchRatingSheet(
          branchId: branchId,
          branchName: widget.branchName ?? 'la tienda',
          appToken: token,
        ),
      );
    });
  }

  Map<String, dynamic> get sale => widget.sale;
  double? get cashReceived => widget.cashReceived;

  @override
  Widget build(BuildContext context) {
    final saleId = sale['id'] as int?;
    final total = (sale['total_amount'] as num?)?.toDouble() ?? 0.0;
    final items = (sale['items'] as List?) ?? [];
    final clientName = (sale['client_name'] as String?) ?? '';
    final paymentMethod = (sale['payment_method'] as String?) ?? 'efectivo';
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

    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Compra exitosa')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),

              // ── Animación: carrito que entrega el pedido ──
              SizedBox(
                height: 110,
                child: AnimatedBuilder(
                  animation: _ctrl,
                  builder: (context, _) {
                    final width = MediaQuery.of(context).size.width;
                    final travel = width / 2 + 80;
                    // Posición horizontal: entra (-travel → 0), sale (0 → travel).
                    final dx =
                        -travel * (1 - _cartIn.value) + travel * _cartOut.value;
                    // Pequeño rebote vertical mientras rueda.
                    final bob = _cartOut.value == 0
                        ? math.sin(_cartIn.value * math.pi * 5) * 3
                        : 0.0;
                    final cartVisible = _cartOut.value < 1;
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        // Anillo de éxito que crece y se asienta
                        Transform.scale(
                          scale: 0.6 + 0.4 * _ring.value,
                          child: Opacity(
                            opacity: _ring.value,
                            child: Container(
                              width: 110,
                              height: 110,
                              decoration: BoxDecoration(
                                color:
                                    AppColors.success.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: AppColors.success
                                        .withValues(alpha: 0.5),
                                    width: 2),
                              ),
                            ),
                          ),
                        ),
                        // Palomita con rebote elástico
                        Transform.scale(
                          scale: _check.value,
                          child: const Icon(Icons.check_circle_outline,
                              color: AppColors.success, size: 65),
                        ),
                        // Carrito que cruza la pantalla
                        if (cartVisible)
                          Transform.translate(
                            offset: Offset(dx, bob),
                            child: Opacity(
                              opacity: (1 - _cartOut.value).clamp(0.0, 1.0),
                              child: const Icon(Icons.shopping_cart,
                                  color: AppColors.primary, size: 56),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),

              FadeTransition(
                opacity: _content,
                child: SlideTransition(
                    position: Tween<Offset>(
                            begin: const Offset(0, 0.06), end: Offset.zero)
                        .animate(_content),
                    child: Column(children: [
                      Text(
                        '¡Compra exitosa!',
                        style: GoogleFonts.montserrat(
                            color: cs.onSurface,
                            fontSize: 24,
                            fontWeight: FontWeight.w700),
                      ),

                      if (clientName.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Gracias, $clientName',
                          style: TextStyle(
                              color: cs.onSurfaceVariant, fontSize: 14),
                        ),
                      ],

                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
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
                          color: cs.surfaceContainer,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: cs.outline),
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
                              final name = (item['product_name'] as String?) ??
                                  'Producto';
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
                                      margin: const EdgeInsets.only(
                                          right: 8, top: 1),
                                      decoration: const BoxDecoration(
                                        color: AppColors.primary,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text('$name × $qty',
                                          style: TextStyle(
                                              color: cs.onSurface,
                                              fontSize: 13)),
                                    ),
                                    Text('\$${subtotal.toStringAsFixed(2)}',
                                        style: TextStyle(
                                            color: cs.onSurfaceVariant,
                                            fontSize: 13)),
                                  ],
                                ),
                              );
                            }),
                            Divider(color: cs.outline),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Total',
                                  style: GoogleFonts.montserrat(
                                      color: cs.onSurface,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15),
                                ),
                                Text(
                                  '\$${total.toStringAsFixed(2)}',
                                  style: GoogleFonts.montserrat(
                                      color: cs.primary,
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
                                    color: cs.onSurfaceVariant,
                                    size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  methodLabels[paymentMethod] ?? paymentMethod,
                                  style: TextStyle(
                                      color: cs.onSurfaceVariant, fontSize: 13),
                                ),
                                const Spacer(),
                                const Icon(Icons.check_circle,
                                    color: AppColors.success, size: 16),
                                const SizedBox(width: 4),
                                const Text('Aprobado',
                                    style: TextStyle(
                                        color: AppColors.success,
                                        fontSize: 13)),
                              ],
                            ),
                            if (change != null) ...[
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Cambio',
                                      style: TextStyle(
                                          color: cs.onSurfaceVariant,
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
                    ])),
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
