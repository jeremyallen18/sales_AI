import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../models/branch.dart';
import '../providers/branch_provider.dart';
import '../providers/products_provider.dart';

class BranchMapScreen extends StatefulWidget {
  const BranchMapScreen({super.key});

  @override
  State<BranchMapScreen> createState() => _BranchMapScreenState();
}

class _BranchMapScreenState extends State<BranchMapScreen> {
  final MapController _mapCtrl = MapController();
  final ScrollController _listCtrl = ScrollController();
  Branch? _selected;
  final _sheetCtrl = DraggableScrollableController();

  // GlobalKeys para hacer scroll hasta la tarjeta seleccionada
  final Map<int, GlobalKey> _cardKeys = {};

  void _selectFromMarker(Branch branch, List<Branch> branches) {
    setState(() => _selected = branch);
    // Animar mapa al marcador
    _mapCtrl.move(LatLng(branch.latitude!, branch.longitude!), 14);
    // Expandir el panel inferior si está muy colapsado
    if (_sheetCtrl.size < 0.35) {
      _sheetCtrl.animateTo(
        0.40,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
    // Scroll hasta la tarjeta en la lista
    _scrollToCard(branch, branches);
  }

  void _selectFromList(Branch branch) {
    setState(() => _selected = branch);
    if (branch.latitude != null && branch.longitude != null) {
      _mapCtrl.move(LatLng(branch.latitude!, branch.longitude!), 14);
    }
  }

  void _scrollToCard(Branch branch, List<Branch> branches) {
    final idx = branches.indexWhere((b) => b.id == branch.id);
    if (idx < 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _cardKeys[branch.id];
      if (key?.currentContext != null) {
        Scrollable.ensureVisible(
          key!.currentContext!,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
          alignment: 0.1,
        );
      }
    });
  }

  void _confirmBranch() {
    if (_selected == null) return;
    context.read<BranchProvider>().selectBranch(_selected!);
    context.read<ProductsProvider>().loadForBranch(_selected!.id);
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _mapCtrl.dispose();
    _listCtrl.dispose();
    _sheetCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final branches = context.watch<BranchProvider>().nearby;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Registrar claves para cada sucursal
    for (final b in branches) {
      _cardKeys.putIfAbsent(b.id, () => GlobalKey());
    }

    final center = _selected != null && _selected!.latitude != null
        ? LatLng(_selected!.latitude!, _selected!.longitude!)
        : branches.isNotEmpty && branches.first.latitude != null
            ? LatLng(branches.first.latitude!, branches.first.longitude!)
            : const LatLng(19.4326, -99.1332);

    final markers = branches
        .where((b) => b.latitude != null && b.longitude != null)
        .map((b) {
      final isActive = _selected?.id == b.id;
      return Marker(
        point: LatLng(b.latitude!, b.longitude!),
        width: isActive ? 52 : 38,
        height: isActive ? 52 : 38,
        child: GestureDetector(
          onTap: () => _selectFromMarker(b, branches),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isActive ? AppColors.primary : cs.surface,
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive ? AppColors.primary : AppColors.primary,
                width: isActive ? 3 : 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: isActive ? 0.45 : 0.20),
                  blurRadius: isActive ? 12 : 6,
                  spreadRadius: isActive ? 2 : 0,
                ),
              ],
            ),
            child: Icon(
              Icons.store,
              color: isActive ? Colors.white : AppColors.primary,
              size: isActive ? 26 : 20,
            ),
          ),
        ),
      );
    }).toList();

    return Scaffold(
      body: Stack(
        children: [
          // ── MAPA ────────────────────────────────────────────────────────
          FlutterMap(
            mapController: _mapCtrl,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 12,
              onTap: (_, __) => setState(() => _selected = null),
            ),
            children: [
              TileLayer(
                urlTemplate: isDark
                    ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
                    : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: isDark ? const ['a', 'b', 'c', 'd'] : const [],
                userAgentPackageName: 'com.example.sales_ai_store',
              ),
              MarkerLayer(markers: markers),
            ],
          ),

          // ── APP BAR FLOTANTE ─────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _MapButton(
                    icon: Icons.arrow_back,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 12),
                          Icon(Icons.search, color: cs.onSurfaceVariant, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Mapa de sucursales',
                            style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── PANEL DESLIZABLE DE SUCURSALES ───────────────────────────────
          DraggableScrollableSheet(
            controller: _sheetCtrl,
            initialChildSize: 0.32,
            minChildSize: 0.12,
            maxChildSize: 0.75,
            snap: true,
            snapSizes: const [0.12, 0.32, 0.75],
            builder: (ctx, scrollCtrl) => Container(
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Handle
                  Padding(
                    padding: const EdgeInsets.only(top: 10, bottom: 6),
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: cs.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                    child: Row(
                      children: [
                        const Icon(Icons.store_mall_directory,
                            color: AppColors.primary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '${branches.length} sucursal${branches.length != 1 ? 'es' : ''}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const Spacer(),
                        if (_selected != null)
                          TextButton.icon(
                            onPressed: _confirmBranch,
                            icon: const Icon(Icons.check_circle_outline,
                                size: 16, color: AppColors.primary),
                            label: const Text(
                              'Confirmar',
                              style: TextStyle(color: AppColors.primary),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Lista
                  Expanded(
                    child: branches.isEmpty
                        ? const Center(
                            child: Text(
                              'No hay sucursales disponibles',
                              style: TextStyle(color: AppColors.onSurfaceVariant),
                            ),
                          )
                        : ListView.separated(
                            controller: scrollCtrl,
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                            itemCount: branches.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (_, i) {
                              final b = branches[i];
                              return _BranchListCard(
                                key: _cardKeys[b.id],
                                branch: b,
                                isSelected: _selected?.id == b.id,
                                onTap: () => _selectFromList(b),
                                onConfirm: _confirmBranch,
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Botón circular flotante sobre el mapa ──────────────────────────────────
class _MapButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _MapButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: cs.surface,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 8,
            ),
          ],
        ),
        child: Icon(icon, color: cs.onSurface, size: 22),
      ),
    );
  }
}

// ── Tarjeta de sucursal en la lista ──────────────────────────────────────────
class _BranchListCard extends StatelessWidget {
  final Branch branch;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onConfirm;

  const _BranchListCard({
    super.key,
    required this.branch,
    required this.isSelected,
    required this.onTap,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primary.withValues(alpha: 0.06)
            : cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected ? AppColors.primary : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fila superior: ícono + nombre + distancia
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.store,
                      color: isSelected ? Colors.white : AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          branch.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: isSelected
                                ? AppColors.primary
                                : cs.onSurface,
                          ),
                        ),
                        if (branch.city.isNotEmpty || branch.state.isNotEmpty)
                          Text(
                            [branch.city, branch.state]
                                .where((s) => s.isNotEmpty)
                                .join(', '),
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (branch.distanceKm != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        branch.distanceText,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 10),

              // Dirección
              if (branch.address.isNotEmpty)
                _InfoRow(
                  icon: Icons.location_on_outlined,
                  text: branch.fullAddress,
                  color: cs.onSurfaceVariant,
                ),

              // Horario
              _InfoRow(
                icon: Icons.access_time_outlined,
                text: '${branch.openingTime} – ${branch.closingTime}',
                color: cs.onSurfaceVariant,
              ),

              // Teléfono
              if (branch.phone.isNotEmpty)
                _InfoRow(
                  icon: Icons.phone_outlined,
                  text: branch.phone,
                  color: cs.onSurfaceVariant,
                ),

              // Botón "Ir a esta sucursal" (solo cuando está seleccionada)
              if (isSelected) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onConfirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text(
                      'Ir a esta sucursal',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _InfoRow({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: color),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
