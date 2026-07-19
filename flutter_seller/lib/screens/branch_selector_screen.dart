import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/branch.dart';
import '../providers/branch_provider.dart';
import '../screens/home_shell.dart';

/// Pantalla mostrada al login si el seller tiene múltiples sucursales asignadas.
/// Permite elegir la sucursal activa de trabajo.
class BranchSelectorScreen extends StatelessWidget {
  const BranchSelectorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final branchProv = context.watch<BranchProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('SELECCIONAR SUCURSAL')),
      body: branchProv.loading
          ? const Center(child: CircularProgressIndicator())
          : branchProv.assigned.isEmpty
              ? const Center(
                  child: Text(
                    'No tienes sucursales asignadas.\nContacta al administrador.',
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: branchProv.assigned.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) {
                    final branch = branchProv.assigned[i];
                    return _BranchTile(
                      branch: branch,
                      onSelect: () {
                        branchProv.setActive(branch);
                        Navigator.of(ctx).pushReplacement(
                          MaterialPageRoute(builder: (_) => const HomeShell()),
                        );
                      },
                    );
                  },
                ),
    );
  }
}

class _BranchTile extends StatelessWidget {
  final Branch branch;
  final VoidCallback onSelect;

  const _BranchTile({required this.branch, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: cs.primaryContainer,
          child: Icon(Icons.store, color: cs.primary),
        ),
        title: Text(branch.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(branch.fullAddress,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.chevron_right),
        onTap: onSelect,
      ),
    );
  }
}
