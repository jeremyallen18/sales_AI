import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../providers/sales_provider.dart';
import '../models/sale.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  @override
  void initState() {
    super.initState();
    context.read<SalesProvider>().load();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SalesProvider>();
    final fmt = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
    final dateFmt = DateFormat('dd/MM/yyyy HH:mm');
    final cs = Theme.of(context).colorScheme;

    if (provider.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 48, color: cs.onSurface.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text(provider.error!,
                style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6))),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: provider.load,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (provider.sales.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long, size: 64, color: cs.onSurface.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text('No hay ventas registradas',
                style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6), fontSize: 16)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: provider.load,
      color: cs.primary,
      child: Column(
        children: [
          // Summary bar
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cs.surfaceContainer,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.outline),
            ),
            child: Row(
              children: [
                _MiniStat(
                  label: 'Ventas Hoy',
                  value: '${provider.todaySalesCount}',
                  icon: Icons.receipt,
                  color: cs.primary,
                ),
                Container(
                    width: 1,
                    height: 36,
                    color: cs.outline,
                    margin: const EdgeInsets.symmetric(horizontal: 16)),
                _MiniStat(
                  label: 'Ingresos Hoy',
                  value: fmt.format(provider.todayRevenue),
                  icon: Icons.attach_money,
                  color: AppColors.success,
                ),
              ],
            ),
          ),

          // Sales list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: provider.sales.length,
              itemBuilder: (_, i) {
                final sale = provider.sales[i];
                return _SaleTile(sale: sale, fmt: fmt, dateFmt: dateFmt);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 11)),
                FittedBox(
                  child: Text(value,
                      style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SaleTile extends StatelessWidget {
  final Sale sale;
  final NumberFormat fmt;
  final DateFormat dateFmt;

  const _SaleTile(
      {required this.sale, required this.fmt, required this.dateFmt});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outline),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        iconColor: cs.onSurface.withValues(alpha: 0.5),
        collapsedIconColor: cs.onSurface.withValues(alpha: 0.5),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '#${sale.id.toString().padLeft(4, '0')}',
                style: TextStyle(
                    color: cs.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                sale.clientName.isNotEmpty ? sale.clientName : 'Sin nombre',
                style: TextStyle(color: cs.onSurface, fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              fmt.format(sale.totalAmount),
              style: const TextStyle(
                  color: AppColors.success,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
        subtitle: Text(
          dateFmt.format(sale.createdAt.toLocal()),
          style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6), fontSize: 11),
        ),
        children: sale.items.map((item) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Icon(Icons.circle, size: 6, color: cs.onSurface.withValues(alpha: 0.4)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(item.productName,
                      style: TextStyle(color: cs.onSurface, fontSize: 13)),
                ),
                Text('x${item.quantity}',
                    style:
                        TextStyle(color: cs.onSurface.withValues(alpha: 0.6), fontSize: 13)),
                const SizedBox(width: 12),
                Text(fmt.format(item.subtotal),
                    style: TextStyle(
                        color: cs.primary, fontSize: 13)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
