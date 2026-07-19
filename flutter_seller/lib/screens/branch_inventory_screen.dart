import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../providers/branch_provider.dart';
import '../services/api_service.dart';

class BranchInventoryScreen extends StatefulWidget {
  const BranchInventoryScreen({super.key});

  @override
  State<BranchInventoryScreen> createState() =>
      _BranchInventoryScreenState();
}

class _BranchInventoryScreenState extends State<BranchInventoryScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = false;
  String? _error;
  int? _lastBranchId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final id = context.read<BranchProvider>().activeBranchId;
    if (id != _lastBranchId) {
      _lastBranchId = id;
      _loadInventory();
    }
  }

  Future<void> _loadInventory() async {
    final branchId = context.read<BranchProvider>().activeBranchId;
    if (branchId == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await ApiService.fetchBranchInventoryRaw(branchId);
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openEditDialog(Map<String, dynamic> item) {
    final productId = item['product_id'] as int;
    final name = item['name'] as String? ?? '';
    final stock = (item['stock'] as num?)?.toInt() ?? 0;
    final price = (item['price'] as num?)?.toDouble() ?? 0.0;
    final disc = (item['discount_pct'] as num?)?.toDouble() ?? 0.0;
    final badge = item['offer_badge'] as String? ?? '';

    final stockCtrl = TextEditingController(text: stock.toString());
    final priceCtrl = TextEditingController(text: price.toStringAsFixed(2));
    final discCtrl = TextEditingController(text: disc.toStringAsFixed(0));
    final badgeCtrl = TextEditingController(text: badge);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: stockCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Stock',
                    prefixIcon: Icon(Icons.inventory)),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: priceCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Precio (\$)',
                    prefixIcon: Icon(Icons.attach_money)),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: discCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Descuento (%)',
                    prefixIcon: Icon(Icons.percent)),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: badgeCtrl,
                maxLength: 40,
                decoration: const InputDecoration(
                  labelText: 'Etiqueta oferta (ej: 2x1, Flash)',
                  prefixIcon: Icon(Icons.local_offer_outlined),
                  helperText: 'Deja vacío para quitar la etiqueta',
                  counterText: '',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final branchId =
                  context.read<BranchProvider>().activeBranchId;
              if (branchId == null) return;
              try {
                await ApiService.updateBranchInventoryItem(
                  branchId,
                  productId,
                  {
                    'stock': int.tryParse(stockCtrl.text.trim()) ?? stock,
                    'price': double.tryParse(priceCtrl.text.trim()),
                    'discount_pct':
                        double.tryParse(discCtrl.text.trim()),
                    'offer_badge': badgeCtrl.text.trim(),
                  },
                );
                await _loadInventory();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.toString())));
                }
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final branchName =
        context.watch<BranchProvider>().active?.name ?? 'Sucursal';

    return Scaffold(
      appBar: AppBar(
        title: Text('INVENTARIO — $branchName'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadInventory,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!,
                          style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 12),
                      ElevatedButton(
                          onPressed: _loadInventory,
                          child: const Text('Reintentar')),
                    ],
                  ),
                )
              : _items.isEmpty
                  ? const Center(
                      child: Text('Sin productos en esta sucursal.'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final item = _items[i];
                        final stockVal = (item['stock'] as num?)?.toInt() ?? 0;
                        final price =
                            (item['price'] as num?)?.toDouble() ?? 0.0;
                        final disc =
                            (item['discount_pct'] as num?)?.toDouble() ?? 0.0;
                        final badge = item['offer_badge'] as String?;
                        final name = item['name'] as String? ?? '';

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: stockVal == 0
                                ? Colors.red[50]
                                : Colors.green[50],
                            child: Text(
                              '$stockVal',
                              style: TextStyle(
                                color: stockVal == 0
                                    ? Colors.red
                                    : Colors.green[700],
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w500)),
                              ),
                              if (badge != null && badge.isNotEmpty)
                                Container(
                                  margin: const EdgeInsets.only(left: 6),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.cartAmber,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    badge,
                                    style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.black87),
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Text(
                              '\$${price.toStringAsFixed(2)}'
                              '${disc > 0 ? ' · ${disc.round()}% dto' : ''}',
                              style: const TextStyle(fontSize: 12)),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _openEditDialog(item),
                          ),
                        );
                      },
                    ),
    );
  }
}
