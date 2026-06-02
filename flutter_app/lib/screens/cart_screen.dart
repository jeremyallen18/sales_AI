import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../models/cart_item.dart';
import '../providers/cart_provider.dart';
import 'checkout_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final items = cart.items.values.toList();

    return Scaffold(
      backgroundColor: AppColors.navyBg,
      appBar: AppBar(
        title: const Text('MI CARRITO'),
        actions: [
          if (items.isNotEmpty)
            TextButton(
              onPressed: () => _confirmClear(context, cart),
              child: const Text('Vaciar',
                  style: TextStyle(color: AppColors.danger, fontSize: 13)),
            ),
        ],
      ),
      body: items.isEmpty
          ? const _EmptyCart()
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                    itemCount: items.length,
                    itemBuilder: (_, i) => _CartTile(item: items[i]),
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
        backgroundColor: AppColors.navyCard,
        title: const Text('¿Vaciar carrito?',
            style: TextStyle(color: Colors.white)),
        content: const Text('Se eliminarán todos los productos.',
            style: TextStyle(color: AppColors.textSec)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(_, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(_, true),
              child: const Text('Vaciar',
                  style: TextStyle(color: AppColors.danger))),
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
          const Icon(Icons.shopping_cart_outlined,
              size: 80, color: AppColors.navyLight),
          const SizedBox(height: 16),
          const Text('Tu carrito está vacío',
              style: TextStyle(color: AppColors.textSec, fontSize: 17)),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Ver productos'),
          ),
        ],
      ),
    );
  }
}

// ── Fila de ítem ──────────────────────────────────────────────────────────────

class _CartTile extends StatelessWidget {
  final CartItem item;
  const _CartTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final cart = context.read<CartProvider>();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.navyCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.navyLight),
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
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
                const SizedBox(height: 3),
                Text('\$${item.product.price.toStringAsFixed(2)} c/u',
                    style: const TextStyle(
                        color: AppColors.textSec, fontSize: 12)),
              ],
            ),
          ),
          // Controles de cantidad
          _QtyControl(
            quantity: item.quantity,
            onDecrement: () =>
                cart.updateQuantity(item.product.id, item.quantity - 1),
            onIncrement: () {
              if (item.quantity < item.product.stock) {
                cart.updateQuantity(item.product.id, item.quantity + 1);
              }
            },
          ),
          const SizedBox(width: 10),
          // Subtotal
          SizedBox(
            width: 68,
            child: Text(
              '\$${item.subtotal.toStringAsFixed(2)}',
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppColors.cartAmber,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QtyControl extends StatelessWidget {
  final int quantity;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  const _QtyControl({
    required this.quantity,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _btn(Icons.remove, onDecrement),
        Container(
          width: 34,
          alignment: Alignment.center,
          child: Text('$quantity',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15)),
        ),
        _btn(Icons.add, onIncrement),
      ],
    );
  }

  Widget _btn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.navyLight, width: 1.5),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(icon, color: Colors.white, size: 15),
        ),
      );
}

// ── Resumen de orden ──────────────────────────────────────────────────────────

class _OrderSummary extends StatelessWidget {
  final CartProvider cart;
  const _OrderSummary({required this.cart});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      decoration: const BoxDecoration(
        color: AppColors.navyCard,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600)),
                Text('\$${cart.total.toStringAsFixed(2)}',
                    style: const TextStyle(
                        color: AppColors.cartAmber,
                        fontSize: 22,
                        fontWeight: FontWeight.bold)),
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
                child: const Text('Proceder al pago',
                    style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}
