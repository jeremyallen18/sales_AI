import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../providers/auth_provider.dart';
import '../providers/branch_provider.dart';
import 'branch_manage_screen.dart';
import 'branch_inventory_screen.dart';
import 'dashboard_screen.dart';
import 'forecast_screen.dart';
import 'pos_screen.dart';
import 'sales_screen.dart';
import 'chat_screen.dart';
import 'settings_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth       = context.read<AuthProvider>();
      final branchProv = context.read<BranchProvider>();
      if (auth.isOwner) {
        branchProv.loadBranches();
      } else if (auth.branchIds.isNotEmpty) {
        branchProv.loadAssigned(auth.branchIds);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth       = context.watch<AuthProvider>();
    final branchProv = context.watch<BranchProvider>();
    final isOwner    = auth.isOwner;

    final titles = [
      'DASHBOARD',
      'PUNTO DE VENTA',
      'HISTORIAL',
      'INVENTARIO',
      'PREDICCIÓN IA',
      'ASISTENTE IA',
      if (isOwner) 'SUCURSALES',
    ];

    final screens = [
      const DashboardScreen(),
      const PosScreen(),
      const SalesScreen(),
      const BranchInventoryScreen(),
      const ForecastScreen(),
      const ChatScreen(),
      if (isOwner) const BranchManageScreen(),
    ];

    // Si el índice actual ya no existe (al cambiar rol), resetear.
    final safeIndex = _currentIndex < screens.length ? _currentIndex : 0;

    final activeBranch = branchProv.active;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(titles[safeIndex]),
            if (activeBranch != null)
              Text(
                activeBranch.name,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
              ),
          ],
        ),
        actions: [
          // Selector de sucursal activa (si tiene varias)
          if (branchProv.assigned.length > 1)
            PopupMenuButton<int>(
              icon: const Icon(Icons.store_outlined),
              tooltip: 'Cambiar sucursal',
              onSelected: (id) {
                final branch = branchProv.assigned.firstWhere((b) => b.id == id);
                branchProv.setActive(branch);
              },
              itemBuilder: (_) => branchProv.assigned
                  .map((b) => PopupMenuItem<int>(
                        value: b.id,
                        child: Row(
                          children: [
                            Icon(
                              b.id == activeBranch?.id
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(b.name),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => Scaffold(
                          appBar: AppBar(title: const Text('AJUSTES')),
                          body: const SettingsScreen(),
                        )),
              );
            },
          ),
        ],
      ),
      body: IndexedStack(index: safeIndex, children: screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
              top: BorderSide(
                  color: Theme.of(context).dividerTheme.color ??
                      Theme.of(context).colorScheme.outline)),
        ),
        child: BottomNavigationBar(
          currentIndex: safeIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          type: BottomNavigationBarType.fixed,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.point_of_sale_outlined),
              activeIcon: Icon(Icons.point_of_sale),
              label: 'Venta',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_outlined),
              activeIcon: Icon(Icons.receipt_long),
              label: 'Historial',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.inventory_2_outlined),
              activeIcon: Icon(Icons.inventory_2),
              label: 'Inventario',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.auto_graph_outlined),
              activeIcon: Icon(Icons.auto_graph),
              label: 'Forecast',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.smart_toy_outlined),
              activeIcon: Icon(Icons.smart_toy),
              label: 'IA',
            ),
            if (isOwner)
              const BottomNavigationBarItem(
                icon: Icon(Icons.store_mall_directory_outlined),
                activeIcon: Icon(Icons.store_mall_directory),
                label: 'Sucursales',
              ),
          ],
        ),
      ),
    );
  }
}
