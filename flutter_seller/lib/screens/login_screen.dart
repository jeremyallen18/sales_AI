import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/settings_service.dart';
import '../main.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final auth = context.read<AuthProvider>();
    final user = _userCtrl.text.trim();
    final pass = _passCtrl.text.trim();
    if (user.isEmpty || pass.isEmpty) return;

    final ok = await auth.login(user, pass);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.error ?? 'Error de autenticación'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  void _showServerConfig() {
    final urlCtrl = TextEditingController(text: SettingsService.currentBaseUrl);

    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final innerCs = Theme.of(ctx).colorScheme;
        return Padding(
          padding: EdgeInsets.fromLTRB(
              24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.dns_outlined, color: innerCs.primary, size: 24),
                  const SizedBox(width: 10),
                  Text(
                    'Configurar Servidor',
                    style: TextStyle(
                        color: innerCs.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 18),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Ingresa la dirección IP y puerto del servidor.',
                style: TextStyle(color: innerCs.onSurface.withValues(alpha: 0.6), fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: urlCtrl,
                decoration: InputDecoration(
                  labelText: 'URL del servidor',
                  hintText: 'http://192.168.0.10:5000',
                  prefixIcon: Icon(Icons.link, color: innerCs.onSurface.withValues(alpha: 0.5)),
                ),
                style: TextStyle(color: innerCs.onSurface),
                keyboardType: TextInputType.url,
                autofocus: true,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        await SettingsService.resetToDefault();
                        urlCtrl.text = SettingsService.defaultBaseUrl;
                        if (ctx.mounted) {
                          setState(() {});
                          Navigator.pop(ctx);
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: innerCs.outline),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('RESET'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final url = urlCtrl.text.trim();
                        if (url.isEmpty) return;
                        await SettingsService.saveBaseUrl(url);
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        setState(() {});
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text('Servidor actualizado'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.save, size: 18),
                      label: const Text('GUARDAR'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.storefront, size: 48, color: Colors.white),
              ),
              const SizedBox(height: 24),
              Text(
                'Sales AI',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Panel de Vendedor',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: cs.onSurface.withValues(alpha: 0.6)),
              ),
              const SizedBox(height: 12),
              // Server URL indicator + config button + QR scan
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: GestureDetector(
                      onTap: _showServerConfig,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainer,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: cs.outline),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.dns_outlined,
                                color: cs.onSurface.withValues(alpha: 0.5),
                                size: 16),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                SettingsService.currentBaseUrl,
                                style: TextStyle(
                                    color:
                                        cs.onSurface.withValues(alpha: 0.6),
                                    fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(Icons.edit_outlined,
                                color: cs.primary, size: 14),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Botón escanear QR del servidor
                  Tooltip(
                    message: 'Escanear QR del servidor',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: _scanServerQr,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: cs.primary.withValues(alpha: 0.4)),
                        ),
                        child: Icon(Icons.qr_code_scanner,
                            color: cs.primary, size: 18),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _userCtrl,
                decoration: InputDecoration(
                  labelText: 'Usuario',
                  prefixIcon: Icon(Icons.person_outline, color: cs.onSurface.withValues(alpha: 0.5)),
                ),
                style: TextStyle(color: cs.onSurface),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passCtrl,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  prefixIcon:
                      Icon(Icons.lock_outline, color: cs.onSurface.withValues(alpha: 0.5)),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_off : Icons.visibility,
                      color: cs.onSurface.withValues(alpha: 0.5),
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                style: TextStyle(color: cs.onSurface),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: auth.loading ? null : _submit,
                  child: auth.loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('INGRESAR',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: Divider(color: cs.outline.withValues(alpha: 0.6))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('o', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.4), fontSize: 12)),
                  ),
                  Expanded(child: Divider(color: cs.outline.withValues(alpha: 0.6))),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: auth.loading ? null : _submitGoogle,
                  icon: _GoogleIcon(),
                  label: const Text('Continuar con Google'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: cs.outline),
                    foregroundColor: cs.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _scanServerQr() async {
    final url = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const _QrScannerScreen()),
    );
    if (url != null && url.startsWith('http') && mounted) {
      await SettingsService.saveBaseUrl(url);
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Servidor: $url')),
      );
    }
  }

  Future<void> _submitGoogle() async {
    final auth = context.read<AuthProvider>();
    final ok   = await auth.loginWithGoogle();
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.error ?? 'Error con Google'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }
}

class _GoogleIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 18,
      child: CustomPaint(painter: _GooglePainter()),
    );
  }
}

class _GooglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final r = Rect.fromLTWH(0, 0, size.width, size.height);
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(r, -2.4, 1.6, true, paint);
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(r, -0.8, 1.6, true, paint);
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(r, 0.8, 1.6, true, paint);
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(r, 2.4, 1.6, true, paint);
    paint.color = Colors.white;
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.width * 0.3, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Pantalla de escaneo QR para configurar el servidor ───────────────────────

class _QrScannerScreen extends StatefulWidget {
  const _QrScannerScreen();

  @override
  State<_QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<_QrScannerScreen> {
  bool _detected = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('ESCANEAR QR SERVIDOR'),
        leading: const BackButton(),
      ),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: (capture) {
              if (_detected) return;
              final barcode = capture.barcodes.firstOrNull;
              final url = barcode?.rawValue;
              if (url != null && url.startsWith('http')) {
                _detected = true;
                Navigator.of(context).pop(url);
              }
            },
          ),
          // Marco guía
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: cs.primary, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Text(
              'Apunta al QR que aparece en la\nterminal al iniciar el servidor',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                shadows: [Shadow(color: Colors.black87, blurRadius: 4)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
