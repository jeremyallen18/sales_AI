import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../providers/products_provider.dart';
import '../models/product.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  String _search = '';
  bool _onlyLowStock = false;

  @override
  void initState() {
    super.initState();
    context.read<ProductsProvider>().load();
  }

  void _showProductForm({Product? existing}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final priceCtrl =
        TextEditingController(text: existing?.price.toString() ?? '');
    final stockCtrl =
        TextEditingController(text: existing?.stock.toString() ?? '');
    final categoryCtrl =
        TextEditingController(text: existing?.category ?? 'General');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.navyCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                existing == null ? 'Nuevo Producto' : 'Editar Producto',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Nombre'),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: priceCtrl,
                      decoration: const InputDecoration(labelText: 'Precio'),
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: stockCtrl,
                      decoration: const InputDecoration(labelText: 'Stock'),
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: categoryCtrl,
                decoration: const InputDecoration(labelText: 'Categoría'),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final data = {
                      'name': nameCtrl.text.trim(),
                      'price': double.tryParse(priceCtrl.text) ?? 0,
                      'stock': int.tryParse(stockCtrl.text) ?? 0,
                      'category': categoryCtrl.text.trim(),
                    };
                    if (data['name'] == '') return;

                    final provider = context.read<ProductsProvider>();
                    try {
                      if (existing == null) {
                        await provider.addProduct(data);
                      } else {
                        await provider.editProduct(existing.id, data);
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                          content: Text(e.toString()),
                          backgroundColor: AppColors.danger,
                        ));
                      }
                    }
                  },
                  child: Text(existing == null ? 'CREAR' : 'GUARDAR'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDelete(Product product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.navyCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Eliminar producto',
            style: TextStyle(color: Colors.white)),
        content: Text('¿Eliminar "${product.name}"?',
            style: const TextStyle(color: AppColors.textSec)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await context.read<ProductsProvider>().removeProduct(product.id);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(e.toString()),
                    backgroundColor: AppColors.danger,
                  ));
                }
              }
            },
            child: const Text('Eliminar',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductsProvider>();
    final fmt = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

    List<Product> filtered = provider.allProducts;
    if (_onlyLowStock) {
      filtered = filtered.where((p) => p.isLowStock).toList();
    }
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      filtered = filtered.where((p) => p.name.toLowerCase().contains(q)).toList();
    }

    final lowCount = provider.lowStockProducts.length;

    return Column(
      children: [
        // Search + filter + add
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Buscar...',
                    prefixIcon: const Icon(Icons.search, color: AppColors.textSec),
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  style: const TextStyle(color: Colors.white),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: Text('Bajo stock ($lowCount)',
                    style: TextStyle(
                        color: _onlyLowStock
                            ? Colors.white
                            : AppColors.textSec,
                        fontSize: 12)),
                selected: _onlyLowStock,
                onSelected: (v) => setState(() => _onlyLowStock = v),
                selectedColor: AppColors.danger.withValues(alpha: 0.3),
                backgroundColor: AppColors.navyCard,
                checkmarkColor: Colors.white,
                side: BorderSide(
                    color: _onlyLowStock
                        ? AppColors.danger
                        : AppColors.divider),
              ),
            ],
          ),
        ),

        // Products list
        Expanded(
          child: provider.loading
              ? const Center(child: CircularProgressIndicator())
              : filtered.isEmpty
                  ? const Center(
                      child: Text('No hay productos',
                          style: TextStyle(color: AppColors.textSec)))
                  : RefreshIndicator(
                      onRefresh: provider.load,
                      color: AppColors.accent,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final p = filtered[i];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.navyCard,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: p.isLowStock
                                    ? AppColors.danger.withValues(alpha: 0.5)
                                    : AppColors.divider,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: AppColors.navyLight,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.inventory_2,
                                      color: AppColors.textSec, size: 22),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(p.name,
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Text(fmt.format(p.price),
                                              style: const TextStyle(
                                                  color: AppColors.accent,
                                                  fontSize: 13)),
                                          const SizedBox(width: 12),
                                          Icon(Icons.circle,
                                              size: 6,
                                              color: p.isLowStock
                                                  ? AppColors.danger
                                                  : AppColors.success),
                                          const SizedBox(width: 4),
                                          Text('Stock: ${p.stock}',
                                              style: TextStyle(
                                                  color: p.isLowStock
                                                      ? AppColors.danger
                                                      : AppColors.textSec,
                                                  fontSize: 12)),
                                          const SizedBox(width: 12),
                                          Container(
                                            padding: const EdgeInsets
                                                .symmetric(
                                                horizontal: 6,
                                                vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.navyLight,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(p.category,
                                                style: const TextStyle(
                                                    color: AppColors.textSec,
                                                    fontSize: 10)),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined,
                                      color: AppColors.textSec, size: 20),
                                  onPressed: () =>
                                      _showProductForm(existing: p),
                                  visualDensity: VisualDensity.compact,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: AppColors.danger, size: 20),
                                  onPressed: () => _confirmDelete(p),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
        ),

        // FAB replacement - bottom add bar
        Container(
          padding: const EdgeInsets.all(16),
          child: SafeArea(
            top: false,
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showProductForm(),
                icon: const Icon(Icons.add),
                label: const Text('AGREGAR PRODUCTO'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
