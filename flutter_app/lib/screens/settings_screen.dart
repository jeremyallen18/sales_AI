import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../main.dart';
import '../services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _ctrl;
  bool _saving = false;
  bool _testing = false;
  String? _testResult;
  bool _testOk = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: SettingsService.currentBaseUrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _normalize(String raw) {
    String url = raw.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  Future<void> _testConnection() async {
    setState(() {
      _testing = true;
      _testResult = null;
    });

    final base = _normalize(_ctrl.text);
    try {
      final uri = Uri.parse('$base/api/inventory/products');
      final resp =
          await http.get(uri).timeout(const Duration(seconds: 6));
      if (!mounted) return;
      final ok = resp.statusCode == 200;
      setState(() {
        _testOk = ok;
        _testResult = ok
            ? '✓ Conexión exitosa al servidor'
            : '✗ El servidor respondió con código ${resp.statusCode}';
      });
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().contains('TimeoutException')
          ? 'Tiempo de espera agotado'
          : e.toString().replaceFirst('Exception: ', '');
      setState(() {
        _testOk = false;
        _testResult = '✗ $msg';
      });
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _save() async {
    final url = _normalize(_ctrl.text);
    if (url.isEmpty) return;
    setState(() => _saving = true);
    await SettingsService.saveBaseUrl(url);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configuración guardada')));
    Navigator.pop(context);
  }

  Future<void> _reset() async {
    await SettingsService.resetToDefault();
    if (!mounted) return;
    setState(() {
      _ctrl.text = SettingsService.currentBaseUrl;
      _testResult = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Configuración')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Tarjeta info ──
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.outline),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline,
                    color: AppColors.primary, size: 20),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Ingresa la dirección IP o dominio del servidor donde '
                    'está corriendo la aplicación de ventas.',
                    style: TextStyle(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 12,
                        height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Campo URL ──
          Text(
            'Dirección del servidor',
            style: GoogleFonts.montserrat(
                color: AppColors.onSurface,
                fontWeight: FontWeight.w600,
                fontSize: 13),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _ctrl,
            style: const TextStyle(color: AppColors.onSurface, fontSize: 14),
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: const InputDecoration(
              hintText: 'http://192.168.1.x:5000',
              prefixIcon: Icon(Icons.dns_outlined,
                  color: AppColors.onSurfaceVariant),
            ),
            onChanged: (_) => setState(() => _testResult = null),
          ),
          const SizedBox(height: 14),

          // ── Resultado de prueba ──
          if (_testResult != null) ...[
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: (_testOk ? AppColors.success : AppColors.error)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _testOk ? AppColors.success : AppColors.error,
                ),
              ),
              child: Text(
                _testResult!,
                style: TextStyle(
                  color: _testOk ? AppColors.success : AppColors.error,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],

          // ── Botón: probar ──
          OutlinedButton.icon(
            onPressed: _testing ? null : _testConnection,
            icon: _testing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primary),
                  )
                : const Icon(Icons.wifi_find, color: AppColors.primary),
            label: Text(
              _testing ? 'Probando...' : 'Probar conexión',
              style: const TextStyle(color: AppColors.primary),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.primary),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
            ),
          ),
          const SizedBox(height: 12),

          // ── Botón: guardar ──
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : const Text('Guardar y volver'),
          ),

          const SizedBox(height: 36),
          const Divider(color: AppColors.outline),
          const SizedBox(height: 8),

          // ── Restablecer ──
          TextButton.icon(
            onPressed: _reset,
            icon: const Icon(Icons.restore, size: 18),
            label: const Text(
              'Restablecer dirección por defecto',
              style: TextStyle(fontSize: 12),
              textAlign: TextAlign.left,
            ),
          ),

          const SizedBox(height: 24),
          const _ExamplesCard(),
        ],
      ),
    );
  }
}

class _ExamplesCard extends StatelessWidget {
  const _ExamplesCard();

  @override
  Widget build(BuildContext context) {
    const examples = [
      ('Emulador Android', 'http://10.0.2.2:5000'),
      ('Red local', 'http://192.168.1.X:5000'),
      ('Dominio/ngrok', 'https://xxxx.ngrok.io'),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ejemplos de dirección',
            style: GoogleFonts.montserrat(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          ...examples.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.only(right: 8, top: 1),
                      decoration: const BoxDecoration(
                        color: AppColors.onSurfaceVariant,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Text('${e.$1}: ',
                        style: const TextStyle(
                            color: AppColors.onSurfaceVariant, fontSize: 12)),
                    Expanded(
                      child: Text(e.$2,
                          style: const TextStyle(
                              color: AppColors.onSurface,
                              fontSize: 12,
                              fontFamily: 'monospace')),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
