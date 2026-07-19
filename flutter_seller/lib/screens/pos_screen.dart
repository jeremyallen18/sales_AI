import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../providers/products_provider.dart';
import '../providers/branch_provider.dart';
import '../providers/cart_provider.dart';
import '../models/product.dart';
import '../models/combo.dart';
import '../services/api_service.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final branchId = context.read<BranchProvider>().activeBranchId;
      if (branchId != null) {
        context.read<ProductsProvider>().loadForBranch(branchId);
      } else {
        context.read<ProductsProvider>().load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final products = context.watch<ProductsProvider>();
    final cart = context.watch<CartProvider>();
    final fmt = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
    final cs = Theme.of(context).colorScheme;

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
                    prefixIcon: Icon(Icons.search, color: cs.onSurface.withValues(alpha: 0.5)),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    isDense: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  style: TextStyle(color: cs.onSurface),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String?>(
                icon: Icon(Icons.filter_list, color: cs.onSurface.withValues(alpha: 0.6)),
                color: cs.surfaceContainer,
                onSelected: (v) => setState(() => _selectedCategory = v),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: null,
                    child: Text('Todas', style: TextStyle(color: cs.onSurface)),
                  ),
                  ...products.categories.map((c) => PopupMenuItem(
                        value: c,
                        child: Text(c, style: TextStyle(color: cs.onSurface)),
                      )),
                ],
              ),
              const SizedBox(width: 4),
              FilledButton.tonalIcon(
                onPressed: () => _openCombosSheet(context),
                icon: const Icon(Icons.dining_outlined, size: 18),
                label: const Text('Combos'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.purple.shade50,
                  foregroundColor: Colors.purple.shade700,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
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
                      style: TextStyle(color: cs.primary, fontSize: 12)),
                  backgroundColor: cs.primary.withValues(alpha: 0.15),
                  deleteIcon:
                      Icon(Icons.close, size: 16, color: cs.primary),
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
                  ? Center(
                      child: Text('No hay productos disponibles',
                          style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6))))
                  : RefreshIndicator(
                      onRefresh: products.load,
                      color: cs.primary,
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
            decoration: BoxDecoration(
              color: cs.surfaceContainer,
              border: Border(top: BorderSide(color: cs.outline)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: cs.primary,
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
                      style: TextStyle(
                          color: cs.onSurface,
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

  void _openCombosSheet(BuildContext context) {
    final branchId = context.read<BranchProvider>().activeBranchId;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CombosSheet(branchId: branchId),
    );
  }
}

class _CombosSheet extends StatefulWidget {
  final int? branchId;
  const _CombosSheet({this.branchId});

  @override
  State<_CombosSheet> createState() => _CombosSheetState();
}

class _CombosSheetState extends State<_CombosSheet> {
  List<Combo> _combos = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final combos = await ApiService.fetchCombos(branchId: widget.branchId);
      if (mounted) setState(() { _combos = combos; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs  = Theme.of(context).colorScheme;
    final fmt = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (_, ctrl) => Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerLowest,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  Icon(Icons.dining_outlined, color: Colors.purple.shade400),
                  const SizedBox(width: 10),
                  Text('Combos disponibles',
                      style: TextStyle(
                          color: cs.onSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 17)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text(_error!, style: TextStyle(color: cs.error)))
                      : _combos.isEmpty
                          ? Center(
                              child: Text('Sin combos disponibles',
                                  style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6))))
                          : ListView.separated(
                              controller: ctrl,
                              padding: const EdgeInsets.all(16),
                              itemCount: _combos.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (_, i) => _ComboTile(combo: _combos[i], fmt: fmt),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComboTile extends StatelessWidget {
  final Combo combo;
  final NumberFormat fmt;
  const _ComboTile({required this.combo, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final cs   = Theme.of(context).colorScheme;
    final cart = context.read<CartProvider>();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.purple.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.purple.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.dining, color: Colors.purple.shade400),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade600,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('COMBO',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(combo.name,
                          style: TextStyle(
                              color: cs.onSurface,
                              fontWeight: FontWeight.w600,
                              fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
                if (combo.description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(combo.description,
                        style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6), fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(combo.itemsSummary,
                      style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5), fontSize: 11),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(fmt.format(combo.price),
                        style: TextStyle(
                            color: cs.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 18)),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: () {
                        // Añadir cada producto del combo al carrito
                        for (final item in combo.items) {
                          final p = Product(
                            id: item.productId,
                            name: item.productName,
                            price: item.productPrice,
                            stock: 999,
                            category: 'Combo',
                            imageUrl: item.productImage,
                          );
                          for (var q = 0; q < item.quantity; q++) {
                            cart.add(p);
                          }
                        }
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Combo "${combo.name}" agregado'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Agregar', style: TextStyle(fontSize: 13)),
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

class _ProductTile extends StatelessWidget {
  final Product product;
  const _ProductTile({required this.product});

  @override
  Widget build(BuildContext context) {
    final cart = context.read<CartProvider>();
    final fmt = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
    final cs = Theme.of(context).colorScheme;

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
          color: cs.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Icon(Icons.inventory_2,
                    size: 40, color: cs.onSurface.withValues(alpha: 0.4)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
              child: Text(
                product.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: cs.onSurface, fontWeight: FontWeight.w600),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 4),
              child: Text(
                fmt.format(product.price),
                style: TextStyle(
                    color: cs.primary,
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
                          : cs.onSurface.withValues(alpha: 0.6),
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
