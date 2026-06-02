import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../providers/auth_provider.dart';
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

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // User info
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.navyCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.accent,
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
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                    ),
                    const Text('Vendedor',
                        style:
                            TextStyle(color: AppColors.textSec, fontSize: 14)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.logout, color: AppColors.danger),
                onPressed: () => auth.logout(),
                tooltip: 'Cerrar sesión',
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Server URL
        const Text('Servidor',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16)),
        const SizedBox(height: 8),
        TextField(
          controller: _urlCtrl,
          decoration: const InputDecoration(
            labelText: 'URL del servidor',
            prefixIcon: Icon(Icons.dns_outlined, color: AppColors.textSec),
          ),
          style: const TextStyle(color: Colors.white),
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
                side: const BorderSide(color: AppColors.divider),
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
            color: AppColors.navyCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Sales AI — Seller',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('Versión 1.0.0',
                  style: TextStyle(color: AppColors.textSec, fontSize: 13)),
              SizedBox(height: 4),
              Text('App móvil para vendedores',
                  style: TextStyle(color: AppColors.textSec, fontSize: 13)),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Logout button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => auth.logout(),
            icon: const Icon(Icons.logout, color: AppColors.danger),
            label: const Text('CERRAR SESIÓN',
                style: TextStyle(color: AppColors.danger)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.danger),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }
}
