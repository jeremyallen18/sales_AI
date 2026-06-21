import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/api_service.dart';
import '../models/insight.dart';

const String _kPowerBiUrl =
    'https://app.powerbi.com/reportEmbed'
    '?reportId=bed502f6-efba-40bf-95e2-5525ee678cae'
    '&autoAuth=true'
    '&ctid=317936f4-343d-40e8-8b27-08d0f63c2c92'
    '&filterPaneEnabled=false';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final WebViewController _webController;
  bool _webLoading = true;
  bool _webError = false;

  List<Insight> _insights = [];
  bool _insightsLoading = true;
  String? _insightsError;

  // Controla si el panel de IA está expandido
  bool _insightsExpanded = true;

  @override
  void initState() {
    super.initState();
    _initWebView();
    _loadInsights();
  }

  void _initWebView() {
    _webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      )
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() {
          _webLoading = true;
          _webError = false;
        }),
        onPageFinished: (_) => setState(() => _webLoading = false),
        onWebResourceError: (_) => setState(() {
          _webLoading = false;
          _webError = true;
        }),
      ))
      ..loadRequest(Uri.parse(_kPowerBiUrl));
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
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Asesor IA (colapsable) ──
        _buildInsightsPanel(cs),

        // ── Power BI WebView ──
        Expanded(
          child: _webError
              ? _buildWebError(cs)
              : Stack(
                  children: [
                    WebViewWidget(controller: _webController),
                    if (_webLoading)
                      Container(
                        color: cs.surface,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(color: cs.primary),
                              const SizedBox(height: 12),
                              Text(
                                'Cargando reporte Power BI…',
                                style: TextStyle(
                                    color: cs.onSurface.withValues(alpha: 0.6),
                                    fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildWebError(ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 48, color: cs.onSurface.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text(
              'No se pudo cargar el reporte',
              style: TextStyle(
                  color: cs.onSurface, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Verifica tu conexión a internet e inicia sesión en tu cuenta Microsoft.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.6), fontSize: 13),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                setState(() => _webError = false);
                _webController.reload();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightsPanel(ColorScheme cs) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.primary.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          // Encabezado siempre visible
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _insightsExpanded = !_insightsExpanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, color: cs.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Asesor IA',
                        style: TextStyle(
                            color: cs.onSurface,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                  ),
                  if (!_insightsLoading)
                    IconButton(
                      tooltip: 'Regenerar recomendaciones',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: _loadInsights,
                      icon: Icon(Icons.refresh, size: 18, color: cs.primary),
                    ),
                  const SizedBox(width: 4),
                  Icon(
                    _insightsExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 20,
                    color: cs.onSurface.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ),
          ),
          // Cuerpo colapsable
          if (_insightsExpanded) ...[
            _buildInsightsBody(cs),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildInsightsBody(ColorScheme cs) {
    if (_insightsLoading) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Row(children: [
          SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary)),
          const SizedBox(width: 10),
          Text('Generando recomendaciones…',
              style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.6), fontSize: 13)),
        ]),
      );
    }
    if (_insightsError != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Text(_insightsError!,
            style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.6), fontSize: 13)),
      );
    }
    if (_insights.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Text('Sin recomendaciones por ahora.',
            style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.6), fontSize: 13)),
      );
    }
    return Column(
        children: _insights.map((i) => _InsightCard(insight: i)).toList());
  }
}

// ─── Insight Card ────────────────────────────────────────────────────────────

class _InsightCard extends StatelessWidget {
  final Insight insight;
  const _InsightCard({required this.insight});

  @override
  Widget build(BuildContext context) {
    final color = insight.priorityColor;
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
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
                          style: TextStyle(
                              color: cs.onSurface,
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
                    style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.7),
                        fontSize: 13,
                        height: 1.35),
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
