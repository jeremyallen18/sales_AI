import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../config/api_config.dart';
import '../main.dart';
import '../models/cart_item.dart';
import '../models/product.dart';
import '../providers/cart_provider.dart';
import '../providers/products_provider.dart';
import 'checkout_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final items = cart.items.values.toList();

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Tu Carrito'),
            if (items.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${items.length}',
                  style: TextStyle(
                    color: AppColors.onSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (items.isNotEmpty)
            TextButton(
              onPressed: () => _confirmClear(context, cart),
              child: const Text('Vaciar',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
            ),
        ],
      ),
      body: items.isEmpty
          ? const _EmptyCart()
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                    children: [
                      // ── Ítems ──
                      ...items.map((item) => _CartTile(item: item)),

                      // ── ¿Olvidaste algo? ──
                      const SizedBox(height: 8),
                      const _ForgotSection(),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
                _OrderSummary(cart: cart),
              ],
            ),
    );
  }

  Future<void> _confirmClear(BuildContext ctx, CartProvider cart) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('¿Vaciar carrito?',
            style: TextStyle(color: AppColors.onSurface)),
        content: const Text('Se eliminarán todos los productos.',
            style: TextStyle(color: AppColors.onSurfaceVariant)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(_, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(_, true),
              child: const Text('Vaciar',
                  style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (ok == true) cart.clear();
  }
}

// ── Carrito vacío ─────────────────────────────────────────────────────────────

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_cart_outlined,
              size: 80, color: AppColors.outlineVariant),
          const SizedBox(height: 16),
          Text(
            'Tu carrito está vacío',
            style: GoogleFonts.montserrat(
              color: AppColors.onSurfaceVariant,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Agrega productos desde la pantalla de inicio',
            style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Ítem del carrito ──────────────────────────────────────────────────────────

class _CartTile extends StatelessWidget {
  final CartItem item;
  const _CartTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final cart = context.read<CartProvider>();
    final url = ApiConfig.productImage(item.product.imageUrl);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: AppColors.outline.withValues(alpha: 0.5), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // ── Imagen ──
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 72,
              height: 72,
              color: AppColors.surfaceContainerLow,
              child: url.isEmpty
                  ? const Icon(Icons.inventory_2_outlined,
                      color: AppColors.onSurfaceVariant)
                  : CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => const Icon(
                          Icons.inventory_2_outlined,
                          color: AppColors.onSurfaceVariant),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          // ── Info ──
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  style: const TextStyle(
                      color: AppColors.onSurface,
                      fontWeight: FontWeight.w600,
                      fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '\$${item.product.price.toStringAsFixed(2)} c/u',
                  style: const TextStyle(
                      color: AppColors.onSurfaceVariant, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _QtyPill(
                      quantity: item.quantity,
                      onDecrement: () => cart.updateQuantity(
                          item.product.id, item.quantity - 1),
                      onIncrement: () {
                        if (item.quantity < item.product.stock) {
                          cart.updateQuantity(
                              item.product.id, item.quantity + 1);
                        }
                      },
                    ),
                    const Spacer(),
                    Text(
                      '\$${item.subtotal.toStringAsFixed(2)}',
                      style: GoogleFonts.montserrat(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => cart.remove(item.product.id),
                      child: const Icon(Icons.delete_outline,
                          color: AppColors.error, size: 20),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QtyPill extends StatelessWidget {
  final int quantity;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  const _QtyPill(
      {required this.quantity,
      required this.onDecrement,
      required this.onIncrement});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _pillBtn(Icons.remove, onDecrement),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              '$quantity',
              style: const TextStyle(
                  color: AppColors.onSurface,
                  fontWeight: FontWeight.w600,
                  fontSize: 13),
            ),
          ),
          _pillBtn(Icons.add, onIncrement),
        ],
      ),
    );
  }

  Widget _pillBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Icon(icon, size: 14, color: AppColors.onSurface),
        ),
      );
}

// ── ¿Olvidaste algo? ──────────────────────────────────────────────────────────

class _ForgotSection extends StatelessWidget {
  const _ForgotSection();

  @override
  Widget build(BuildContext context) {
    final allProducts = context.watch<ProductsProvider>().allProducts;
    final cart = context.watch<CartProvider>();
    // Show products not in cart (up to 6)
    final suggestions = allProducts
        .where((p) => !cart.items.containsKey(p.id))
        .take(6)
        .toList();

    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline,
                  color: AppColors.primary, size: 16),
              const SizedBox(width: 6),
              Text(
                '¿Olvidaste algo?',
                style: GoogleFonts.montserrat(
                  color: AppColors.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 108,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: suggestions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => _SuggestionCard(product: suggestions[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  final Product product;
  const _SuggestionCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final cart = context.read<CartProvider>();
    final url = ApiConfig.productImage(product.imageUrl);

    return Container(
      width: 120,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            child: Container(
              height: 52,
              width: double.infinity,
              color: AppColors.surfaceContainerLow,
              child: url.isEmpty
                  ? const Icon(Icons.inventory_2_outlined,
                      color: AppColors.onSurfaceVariant, size: 24)
                  : CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => const Icon(
                          Icons.inventory_2_outlined,
                          color: AppColors.onSurfaceVariant,
                          size: 24),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
            child: Text(
              product.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 10,
                  fontWeight: FontWeight.w500),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 4),
            child: GestureDetector(
              onTap: () => cart.add(product),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '+ Agregar',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.onSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Resumen de orden ──────────────────────────────────────────────────────────

class _OrderSummary extends StatelessWidget {
  final CartProvider cart;
  const _OrderSummary({required this.cart});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        border: Border(top: BorderSide(color: AppColors.outline)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Subtotal',
                    style: TextStyle(
                        color: AppColors.onSurfaceVariant, fontSize: 13)),
                Text('\$${cart.total.toStringAsFixed(2)}',
                    style: const TextStyle(
                        color: AppColors.onSurface, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 4),
            const Divider(color: AppColors.outline),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total',
                  style: GoogleFonts.montserrat(
                      color: AppColors.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w700),
                ),
                Text(
                  '\$${cart.total.toStringAsFixed(2)}',
                  style: GoogleFonts.montserrat(
                      color: AppColors.primary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CheckoutScreen()),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text('Proceder al pago', style: TextStyle(fontSize: 15)),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward, size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
