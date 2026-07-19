import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _urlCtrl = TextEditingController();
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _urlCtrl.text = SettingsService.currentBaseUrl;
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final cs = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // User info
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cs.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).dividerTheme.color ?? cs.outline),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: cs.primary,
                child: Text(
                  auth.user.isNotEmpty ? auth.user[0].toUpperCase() : 'V',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      auth.user,
                      style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                    ),
                    Text('Vendedor',
                        style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.6),
                            fontSize: 14)),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.logout, color: AppColors.danger),
                onPressed: () => auth.logout(),
                tooltip: 'Cerrar sesión',
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // ── Toggle de tema ──
        Consumer<ThemeProvider>(
          builder: (context, theme, _) => Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: cs.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: Theme.of(context).dividerTheme.color ?? cs.outline),
            ),
            child: Row(
              children: [
                Icon(
                  theme.isDark ? Icons.dark_mode : Icons.light_mode,
                  color: cs.primary,
                  size: 22,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    theme.isDark ? 'Modo oscuro' : 'Modo claro',
                    style: TextStyle(
                      color: cs.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                Switch.adaptive(
                  value: theme.isDark,
                  activeColor: cs.primary,
                  onChanged: (_) => theme.toggle(),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Server URL
        Text('Servidor',
            style: TextStyle(
                color: cs.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 16)),
        const SizedBox(height: 8),
        TextField(
          controller: _urlCtrl,
          decoration: const InputDecoration(
            labelText: 'URL del servidor',
            prefixIcon: Icon(Icons.dns_outlined),
          ),
          style: TextStyle(color: cs.onSurface),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () async {
                  await SettingsService.saveBaseUrl(_urlCtrl.text.trim());
                  setState(() => _saved = true);
                  Future.delayed(const Duration(seconds: 2),
                      () => mounted ? setState(() => _saved = false) : null);
                },
                child: Text(_saved ? 'GUARDADO' : 'GUARDAR URL'),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: () async {
                await SettingsService.resetToDefault();
                _urlCtrl.text = SettingsService.defaultBaseUrl;
                setState(() {});
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                    color: Theme.of(context).dividerTheme.color ?? cs.outline),
              ),
              child: const Text('RESET'),
            ),
          ],
        ),

        const SizedBox(height: 32),

        // App info
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: Theme.of(context).dividerTheme.color ?? cs.outline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Sales AI — Seller',
                  style: TextStyle(
                      color: cs.onSurface, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Versión 1.0.0',
                  style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.6),
                      fontSize: 13)),
              const SizedBox(height: 4),
              Text('App móvil para vendedores',
                  style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.6),
                      fontSize: 13)),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Logout button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => auth.logout(),
            icon: Icon(Icons.logout, color: AppColors.danger),
            label: Text('CERRAR SESIÓN',
                style: TextStyle(color: AppColors.danger)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppColors.danger),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }
}
