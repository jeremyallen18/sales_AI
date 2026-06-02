import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../services/api_service.dart';
import '../models/insight.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  // Asesor IA Proactivo — carga independiente para no bloquear los KPIs.
  List<Insight> _insights = [];
  bool _insightsLoading = true;
  String? _insightsError;

  @override
  void initState() {
    super.initState();
    _load();
    _loadInsights();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _data = await ApiService.fetchAnalytics();
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadInsights() async {
    setState(() {
      _insightsLoading = true;
      _insightsError = null;
    });
    try {
      _insights = await ApiService.fetchInsights();
    } catch (e) {
      _insightsError = e.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) setState(() => _insightsLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 48, color: AppColors.textSec),
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.textSec)),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    final totalRevenue = (_data!['ingresos_totales'] as num).toDouble();
    final recentSales =
        (_data!['ventas_recientes'] as List<dynamic>?) ?? [];
    final topProducts =
        (_data!['top_productos'] as List<dynamic>?) ?? [];

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([_load(), _loadInsights()]);
      },
      color: AppColors.accent,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Resumen del Negocio',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          _buildInsightsSection(),
          const SizedBox(height: 24),
          _buildKpiRow(totalRevenue, recentSales.length, topProducts.length),
          const SizedBox(height: 24),
          _buildRevenueChart(recentSales),
          const SizedBox(height: 24),
          _buildTopProductsList(topProducts),
        ],
      ),
    );
  }

  Widget _buildInsightsSection() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.navyCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encabezado con título + botón regenerar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, color: AppColors.accent, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Asesor IA',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15),
                  ),
                ),
                IconButton(
                  tooltip: 'Regenerar recomendaciones',
                  onPressed: _insightsLoading ? null : _loadInsights,
                  icon: Icon(
                    Icons.refresh,
                    size: 20,
                    color: _insightsLoading
                        ? AppColors.textSec
                        : AppColors.accent,
                  ),
                ),
              ],
            ),
          ),
          _buildInsightsBody(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildInsightsBody() {
    if (_insightsLoading) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.accent),
            ),
            SizedBox(width: 12),
            Text('Generando recomendaciones…',
                style: TextStyle(color: AppColors.textSec, fontSize: 13)),
          ],
        ),
      );
    }
    if (_insightsError != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Text(_insightsError!,
            style: const TextStyle(color: AppColors.textSec, fontSize: 13)),
      );
    }
    if (_insights.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Text('Sin recomendaciones por ahora.',
            style: TextStyle(color: AppColors.textSec, fontSize: 13)),
      );
    }
    return Column(
      children: _insights.map((i) => _InsightCard(insight: i)).toList(),
    );
  }

  Widget _buildKpiRow(double revenue, int salesDays, int topCount) {
    final fmt = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
    return Row(
      children: [
        Expanded(
          child: _KpiCard(
            icon: Icons.attach_money,
            label: 'Ingresos Totales',
            value: fmt.format(revenue),
            color: AppColors.success,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _KpiCard(
            icon: Icons.trending_up,
            label: 'Días con Ventas',
            value: '$salesDays',
            color: AppColors.accent,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _KpiCard(
            icon: Icons.star,
            label: 'Top Productos',
            value: '$topCount',
            color: AppColors.cartAmber,
          ),
        ),
      ],
    );
  }

  Widget _buildRevenueChart(List<dynamic> recentSales) {
    if (recentSales.isEmpty) {
      return _SectionCard(
        title: 'Tendencia de Ingresos',
        child: const SizedBox(
          height: 120,
          child: Center(
            child: Text('Sin datos de ventas aún',
                style: TextStyle(color: AppColors.textSec)),
          ),
        ),
      );
    }

    final spots = <FlSpot>[];
    for (int i = 0; i < recentSales.length; i++) {
      final entry = recentSales[i] as Map<String, dynamic>;
      spots.add(FlSpot(i.toDouble(), (entry['total'] as num).toDouble()));
    }

    return _SectionCard(
      title: 'Tendencia de Ingresos (30 días)',
      child: SizedBox(
        height: 200,
        child: LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) =>
                  FlLine(color: AppColors.divider, strokeWidth: 0.5),
            ),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 50,
                  getTitlesWidget: (value, _) => Text(
                    '\$${value.toInt()}',
                    style: const TextStyle(
                        color: AppColors.textSec, fontSize: 10),
                  ),
                ),
              ),
              bottomTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: AppColors.accent,
                barWidth: 3,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: AppColors.accent.withValues(alpha: 0.15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopProductsList(List<dynamic> topProducts) {
    final fmt = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

    return _SectionCard(
      title: 'Productos Más Vendidos',
      child: topProducts.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Sin datos aún',
                  style: TextStyle(color: AppColors.textSec)),
            )
          : Column(
              children: topProducts.map((p) {
                final item = p as Map<String, dynamic>;
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    backgroundColor: AppColors.accent.withValues(alpha: 0.2),
                    child: Text(
                      '${topProducts.indexOf(p) + 1}',
                      style: const TextStyle(
                          color: AppColors.accent,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(item['name'] as String,
                      style: const TextStyle(color: Colors.white)),
                  subtitle: Text(
                    '${item['total_qty']} unidades vendidas',
                    style: const TextStyle(color: AppColors.textSec, fontSize: 12),
                  ),
                  trailing: Text(
                    fmt.format((item['revenue'] as num).toDouble()),
                    style: const TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.bold),
                  ),
                );
              }).toList(),
            ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _KpiCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.navyCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          FittedBox(
            child: Text(
              value,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSec, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final Insight insight;
  const _InsightCard({required this.insight});

  @override
  Widget build(BuildContext context) {
    final color = insight.priorityColor;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      decoration: BoxDecoration(
        color: AppColors.navyLight.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(insight.icon, color: color, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          insight.titulo,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          insight.priorityLabel,
                          style: TextStyle(
                              color: color,
                              fontSize: 10,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    insight.descripcion,
                    style: const TextStyle(
                        color: AppColors.textSec, fontSize: 13, height: 1.35),
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

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.navyCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
          ),
          child,
        ],
      ),
    );
  }
}
