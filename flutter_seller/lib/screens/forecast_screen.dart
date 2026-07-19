import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../providers/branch_provider.dart';
import '../services/api_service.dart';

// Alias para el color de acento del seller
const _kAccent = AppColors.accent;

class ForecastScreen extends StatefulWidget {
  const ForecastScreen({super.key});

  @override
  State<ForecastScreen> createState() => _ForecastScreenState();
}

class _ForecastScreenState extends State<ForecastScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final branchId =
          context.read<BranchProvider>().activeBranchId;
      final result = await ApiService.fetchForecast(branchId: branchId);
      if (mounted) setState(() => _data = result);
    } catch (e) {
      if (mounted) {
        setState(
            () => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fuente = _data?['fuente'] as String?;
    final preds = (_data?['predicciones'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final resumen = _data?['resumen'] as String? ?? '';

    return Scaffold(
      backgroundColor: cs.surfaceContainerLow,
      body: RefreshIndicator(
        onRefresh: _load,
        color: _kAccent,
        child: CustomScrollView(
          slivers: [
            // ── AppBar ──────────────────────────────────────
            SliverAppBar(
              pinned: true,
              expandedHeight: 130,
              backgroundColor: _kAccent,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding:
                    const EdgeInsets.fromLTRB(16, 0, 16, 14),
                title: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Predicción de Demanda',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 18),
                    ),
                    const Text(
                      'Próximos 7 días · IA',
                      style: TextStyle(
                          color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF0B1D3A), Color(0xFF2979FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Align(
                    alignment: Alignment(0.85, 0.5),
                    child: Icon(Icons.auto_graph,
                        size: 80, color: Colors.white10),
                  ),
                ),
              ),
            ),

            // ── Cuerpo ──────────────────────────────────────
            if (_loading)
              const SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Analizando ventas con IA…',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              )
            else if (_error != null)
              SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 56, color: Colors.grey),
                        const SizedBox(height: 12),
                        Text(_error!,
                            textAlign: TextAlign.center,
                            style:
                                const TextStyle(color: Colors.grey)),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else ...[
              // Resumen IA
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Container(
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: cs.outlineVariant.withValues(alpha: 0.4)),
                    ),
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: fuente == 'ia'
                                ? _kAccent
                                : Colors.orange[700]!,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            fuente == 'ia'
                                ? Icons.smart_toy
                                : Icons.rule,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fuente == 'ia'
                                    ? 'Análisis generado por IA'
                                    : 'Estimación por reglas',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: fuente == 'ia'
                                      ? _kAccent
                                      : Colors.orange[700],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(resumen,
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: cs.onSurfaceVariant)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              if (preds.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.inventory_2_outlined,
                            size: 56, color: Colors.grey),
                        const SizedBox(height: 12),
                        const Text('Sin datos de ventas suficientes',
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                )
              else ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      '${preds.length} productos analizados',
                      style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ForecastCard(pred: preds[i]),
                      ),
                      childCount: preds.length,
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

// ── Tarjeta de predicción ─────────────────────────────────────────────────────

class _ForecastCard extends StatelessWidget {
  final Map<String, dynamic> pred;
  const _ForecastCard({required this.pred});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final nombre = pred['producto'] as String? ?? '';
    final ventas30 = (pred['ventas_30d'] as num?)?.toInt() ?? 0;
    final demanda7 = (pred['demanda_7d'] as num?)?.toInt() ?? 0;
    final stockActual = (pred['stock_actual'] as num?)?.toInt() ?? 0;
    final reabastecer = (pred['reabastecer'] as num?)?.toInt() ?? 0;
    final confianza = pred['confianza'] as String? ?? 'media';
    final nota = pred['nota'] as String?;

    final urgente = reabastecer > 0 && stockActual < demanda7;
    final confianzaColor = confianza == 'alta'
        ? Colors.green[600]!
        : confianza == 'media'
            ? Colors.orange[600]!
            : Colors.grey[500]!;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: urgente
            ? BorderSide(color: Colors.orange[400]!, width: 1.5)
            : BorderSide(
                color: cs.outlineVariant.withValues(alpha: 0.3)),
      ),
      color: urgente
          ? Colors.orange[50]?.withValues(alpha: 0.5)
          : cs.surface,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: nombre + confianza
            Row(
              children: [
                Expanded(
                  child: Text(nombre,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: confianzaColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    confianza,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: confianzaColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Métricas en fila
            Row(
              children: [
                _Metric(
                  label: 'Vendidos\n30 días',
                  value: '$ventas30',
                  icon: Icons.bar_chart,
                  color: cs.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                _Metric(
                  label: 'Demanda\n7 días',
                  value: '$demanda7',
                  icon: Icons.trending_up,
                  color: Colors.blue[600]!,
                ),
                const SizedBox(width: 8),
                _Metric(
                  label: 'Stock\nactual',
                  value: '$stockActual',
                  icon: Icons.inventory,
                  color: stockActual < demanda7
                      ? Colors.orange[700]!
                      : Colors.green[600]!,
                ),
                const SizedBox(width: 8),
                _Metric(
                  label: 'Reabastecer',
                  value: reabastecer > 0 ? '+$reabastecer' : '✓',
                  icon: reabastecer > 0
                      ? Icons.add_shopping_cart
                      : Icons.check_circle,
                  color: reabastecer > 0
                      ? AppColors.danger
                      : Colors.green[600]!,
                  highlight: reabastecer > 0,
                ),
              ],
            ),
            if (nota != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.lightbulb_outline,
                      size: 14, color: cs.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(nota,
                        style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                            fontStyle: FontStyle.italic)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool highlight;

  const _Metric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: highlight
              ? color.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: color)),
            const SizedBox(height: 2),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 9,
                    color: Colors.grey,
                    height: 1.3)),
          ],
        ),
      ),
    );
  }
}
