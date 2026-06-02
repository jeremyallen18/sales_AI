import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../providers/products_provider.dart';
import '../providers/cart_provider.dart';
import '../models/product.dart';
import 'checkout_screen.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  String _search = '';
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    context.read<ProductsProvider>().load();
  }

  @override
  Widget build(BuildContext context) {
    final products = context.watch<ProductsProvider>();
    final cart = context.watch<CartProvider>();
    final fmt = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

    List<Product> filtered = products.inStockProducts;
    if (_selectedCategory != null) {
      filtered = filtered.where((p) => p.category == _selectedCategory).toList();
    }
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      filtered = filtered.where((p) => p.name.toLowerCase().contains(q)).toList();
    }

    return Column(
      children: [
        // Search bar + category filter
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Buscar producto...',
                    prefixIcon: const Icon(Icons.search, color: AppColors.textSec),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    isDense: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  style: const TextStyle(color: Colors.white),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String?>(
                icon: const Icon(Icons.filter_list, color: AppColors.textSec),
                color: AppColors.navyCard,
                onSelected: (v) => setState(() => _selectedCategory = v),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: null,
                    child: Text('Todas', style: TextStyle(color: Colors.white)),
                  ),
                  ...products.categories.map((c) => PopupMenuItem(
                        value: c,
                        child: Text(c, style: const TextStyle(color: Colors.white)),
                      )),
                ],
              ),
            ],
          ),
        ),
        if (_selectedCategory != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Chip(
                  label: Text(_selectedCategory!,
                      style: const TextStyle(color: Colors.white, fontSize: 12)),
                  backgroundColor: AppColors.accent.withValues(alpha: 0.3),
                  deleteIcon:
                      const Icon(Icons.close, size: 16, color: Colors.white),
                  onDeleted: () => setState(() => _selectedCategory = null),
                ),
              ],
            ),
          ),

        // Product grid
        Expanded(
          child: products.loading
              ? const Center(child: CircularProgressIndicator())
              : filtered.isEmpty
                  ? const Center(
                      child: Text('No hay productos disponibles',
                          style: TextStyle(color: AppColors.textSec)))
                  : RefreshIndicator(
                      onRefresh: products.load,
                      color: AppColors.accent,
                      child: GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.78,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) =>
                            _ProductTile(product: filtered[i]),
                      ),
                    ),
        ),

        // Cart summary bar
        if (cart.count > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: AppColors.navyCard,
              border: Border(top: BorderSide(color: AppColors.divider)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('${cart.count}',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      fmt.format(cart.total),
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const CheckoutScreen()),
                      );
                    },
                    icon: const Icon(Icons.shopping_cart_checkout, size: 18),
                    label: const Text('Cobrar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ProductTile extends StatelessWidget {
  final Product product;
  const _ProductTile({required this.product});

  @override
  Widget build(BuildContext context) {
    final cart = context.read<CartProvider>();
    final fmt = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

    return GestureDetector(
      onTap: () {
        cart.add(product);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${product.name} agregado'),
            duration: const Duration(milliseconds: 800),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.navyCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.navyLight,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: const Icon(Icons.inventory_2,
                    size: 40, color: AppColors.textSec),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
              child: Text(
                product.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 4),
              child: Text(
                fmt.format(product.price),
                style: const TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Row(
                children: [
                  Icon(
                    Icons.circle,
                    size: 8,
                    color: product.isLowStock
                        ? AppColors.danger
                        : AppColors.success,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Stock: ${product.stock}',
                    style: TextStyle(
                      color: product.isLowStock
                          ? AppColors.danger
                          : AppColors.textSec,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
