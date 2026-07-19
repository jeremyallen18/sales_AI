import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../main.dart';
import '../models/branch.dart';
import '../providers/branch_provider.dart';
import '../providers/products_provider.dart';
import '../services/settings_service.dart';

class BranchPickerScreen extends StatefulWidget {
  const BranchPickerScreen({super.key});

  @override
  State<BranchPickerScreen> createState() => _BranchPickerScreenState();
}

class _BranchPickerScreenState extends State<BranchPickerScreen> {
  final MapController _mapCtrl = MapController();
  final DraggableScrollableController _sheetCtrl =
      DraggableScrollableController();
  final Map<int, GlobalKey> _cardKeys = {};

  bool _locating = false;
  String? _locError;
  Branch? _highlighted; // marcador activo en el mapa

  @override
  void initState() {
    super.initState();
    _tryLocate();
  }

  @override
  void dispose() {
    _mapCtrl.dispose();
    _sheetCtrl.dispose();
    super.dispose();
  }

  // ── Geolocalización ──────────────────────────────────────────────────────
  Future<void> _tryLocate() async {
    setState(() {
      _locating = true;
      _locError = null;
    });
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        throw Exception('Permiso de ubicación denegado permanentemente');
      }
      if (perm == LocationPermission.denied) {
        throw Exception('Se necesita el permiso de ubicación');
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      if (!mounted) return;
      await context
          .read<BranchProvider>()
          .loadNearby(pos.latitude, pos.longitude);
    } catch (e) {
      if (!mounted) return;
      setState(
          () => _locError = e.toString().replaceFirst('Exception: ', ''));
      await context.read<BranchProvider>().loadAll();
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  // ── Selección de sucursal ────────────────────────────────────────────────
  void _selectBranch(Branch branch) {
    context.read<BranchProvider>().selectBranch(branch);
    context.read<ProductsProvider>().loadForBranch(branch.id);
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  // ── Interacción mapa → lista ─────────────────────────────────────────────
  void _tapMarker(Branch branch) {
    setState(() => _highlighted = branch);
    _mapCtrl.move(LatLng(branch.latitude!, branch.longitude!), 14);
    if (_sheetCtrl.size < 0.38) {
      _sheetCtrl.animateTo(0.42,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut);
    }
    _scrollToCard(branch);
  }

  // ── Interacción lista → mapa ─────────────────────────────────────────────
  void _tapCard(Branch branch) {
    setState(() => _highlighted = branch);
    if (branch.latitude != null && branch.longitude != null) {
      _mapCtrl.move(LatLng(branch.latitude!, branch.longitude!), 14);
    }
  }

  void _scrollToCard(Branch branch) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _cardKeys[branch.id]?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOut,
            alignment: 0.1);
      }
    });
  }

  // ── Config servidor ──────────────────────────────────────────────────────
  void _showServerConfig(BuildContext context) {
    final ctrl = TextEditingController(text: SettingsService.currentBaseUrl);
    bool saving = false;
    bool testing = false;
    String? result;
    bool resultOk = false;

    String normalize(String raw) {
      String url = raw.trim();
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        url = 'http://$url';
      }
      return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                const Icon(Icons.settings_ethernet, size: 22),
                const SizedBox(width: 10),
                const Text('Dirección del servidor',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
              ]),
              const SizedBox(height: 4),
              Text('Ingresa la IP o URL donde corre el servidor Flask.',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600])),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: 'URL del servidor',
                  hintText: 'http://192.168.x.x:5000',
                  prefixIcon: const Icon(Icons.dns_outlined),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () => ctrl.clear(),
                  ),
                ),
              ),
              if (result != null) ...[
                const SizedBox(height: 8),
                Row(children: [
                  Icon(resultOk ? Icons.check_circle : Icons.error,
                      color: resultOk ? Colors.green : Colors.red,
                      size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                      child: Text(result!,
                          style: TextStyle(
                              fontSize: 12,
                              color: resultOk ? Colors.green : Colors.red))),
                ]),
              ],
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: testing
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.wifi_tethering, size: 16),
                    label: const Text('Probar'),
                    onPressed: (testing || saving)
                        ? null
                        : () async {
                            setS(() {
                              testing = true;
                              result = null;
                            });
                            final url = normalize(ctrl.text);
                            try {
                              final res = await http
                                  .get(Uri.parse('$url/api/health'))
                                  .timeout(const Duration(seconds: 5));
                              setS(() {
                                testing = false;
                                resultOk = res.statusCode == 200;
                                result = resultOk
                                    ? 'Conexión exitosa ✓'
                                    : 'Error HTTP ${res.statusCode}';
                              });
                            } catch (e) {
                              setS(() {
                                testing = false;
                                resultOk = false;
                                result =
                                    'Sin respuesta: ${e.toString().split(':').first}';
                              });
                            }
                          },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: saving
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save_outlined, size: 16),
                    label: const Text('Guardar'),
                    onPressed: (saving || testing)
                        ? null
                        : () async {
                            setS(() => saving = true);
                            await SettingsService.saveBaseUrl(
                                normalize(ctrl.text));
                            if (ctx.mounted) Navigator.pop(ctx);
                            _tryLocate();
                          },
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final branchProv = context.watch<BranchProvider>();
    final branches = branchProv.nearby;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Registrar claves de tarjeta
    for (final b in branches) {
      _cardKeys.putIfAbsent(b.id, () => GlobalKey());
    }

    final center = _highlighted != null && _highlighted!.latitude != null
        ? LatLng(_highlighted!.latitude!, _highlighted!.longitude!)
        : branches.isNotEmpty && branches.first.latitude != null
            ? LatLng(branches.first.latitude!, branches.first.longitude!)
            : const LatLng(19.4326, -99.1332);

    final markers = branches
        .where((b) => b.latitude != null && b.longitude != null)
        .map((b) {
      final isActive = _highlighted?.id == b.id;
      return Marker(
        point: LatLng(b.latitude!, b.longitude!),
        width: isActive ? 50 : 38,
        height: isActive ? 50 : 38,
        child: GestureDetector(
          onTap: () => _tapMarker(b),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isActive ? AppColors.primary : cs.surface,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary, width: isActive ? 3 : 2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary
                      .withValues(alpha: isActive ? 0.45 : 0.20),
                  blurRadius: isActive ? 14 : 6,
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
          // ── MAPA ──────────────────────────────────────────────────────────
          (_locating || branchProv.loading)
              ? Container(
                  color: cs.surfaceContainerLow,
                  child: const Center(child: CircularProgressIndicator()),
                )
              : branches.isEmpty
                  ? _EmptyState(
                      onRetry: _tryLocate,
                      onConfigServer: () => _showServerConfig(context),
                    )
                  : FlutterMap(
                      mapController: _mapCtrl,
                      options: MapOptions(
                        initialCenter: center,
                        initialZoom: 12,
                        onTap: (_, __) =>
                            setState(() => _highlighted = null),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: isDark
                              ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
                              : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          subdomains: isDark
                              ? const ['a', 'b', 'c', 'd']
                              : const [],
                          userAgentPackageName:
                              'com.example.sales_ai_store',
                        ),
                        MarkerLayer(markers: markers),
                      ],
                    ),

          // ── BARRA SUPERIOR FLOTANTE ────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  if (Navigator.of(context).canPop())
                    _FloatButton(
                      icon: Icons.arrow_back,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  if (Navigator.of(context).canPop())
                    const SizedBox(width: 10),
                  Expanded(
                    child: _SearchBar(
                      label: 'Selecciona tu sucursal',
                    ),
                  ),
                  const SizedBox(width: 10),
                  _FloatButton(
                    icon: Icons.my_location,
                    onTap: _locating ? null : _tryLocate,
                  ),
                  const SizedBox(width: 8),
                  _FloatButton(
                    icon: Icons.settings_ethernet,
                    onTap: () => _showServerConfig(context),
                  ),
                ],
              ),
            ),
          ),

          // ── BANNER ERROR UBICACIÓN ─────────────────────────────────────
          if (_locError != null)
            Positioned(
              top: 80,
              left: 16,
              right: 16,
              child: Material(
                borderRadius: BorderRadius.circular(12),
                color: cs.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.location_off, color: cs.error, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_locError!,
                            style:
                                TextStyle(color: cs.error, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── PANEL DESLIZABLE ───────────────────────────────────────────
          if (branches.isNotEmpty)
            DraggableScrollableSheet(
              controller: _sheetCtrl,
              initialChildSize: 0.30,
              minChildSize: 0.10,
              maxChildSize: 0.78,
              snap: true,
              snapSizes: const [0.10, 0.30, 0.78],
              builder: (ctx, scrollCtrl) => Container(
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.14),
                      blurRadius: 12,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Handle
                    Padding(
                      padding:
                          const EdgeInsets.only(top: 10, bottom: 6),
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: cs.outlineVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    // Header del panel
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
                      child: Row(
                        children: [
                          const Icon(Icons.store_mall_directory,
                              color: AppColors.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            '${branches.length} sucursal${branches.length != 1 ? 'es' : ''} cercanas',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15),
                          ),
                          const Spacer(),
                          if (_highlighted != null)
                            TextButton(
                              onPressed: () =>
                                  _selectBranch(_highlighted!),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle_outline,
                                      size: 16),
                                  SizedBox(width: 4),
                                  Text('Confirmar',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Lista de sucursales
                    Expanded(
                      child: ListView.separated(
                        controller: scrollCtrl,
                        padding:
                            const EdgeInsets.fromLTRB(12, 0, 12, 24),
                        itemCount: branches.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final b = branches[i];
                          return _BranchCard(
                            key: _cardKeys[b.id],
                            branch: b,
                            isSelected: _highlighted?.id == b.id,
                            onTap: () => _tapCard(b),
                            onConfirm: () => _selectBranch(b),
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

// ── Botón flotante circular ───────────────────────────────────────────────────
class _FloatButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _FloatButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: onTap == null
              ? cs.surface.withValues(alpha: 0.6)
              : cs.surface,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 8,
            ),
          ],
        ),
        child: Icon(icon,
            color: onTap == null
                ? cs.onSurface.withValues(alpha: 0.4)
                : cs.onSurface,
            size: 22),
      ),
    );
  }
}

// ── Barra de búsqueda decorativa ─────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  final String label;
  const _SearchBar({required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
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
          Expanded(
            child: Text(label,
                style: TextStyle(
                    color: cs.onSurfaceVariant, fontSize: 14),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

// ── Tarjeta de sucursal ───────────────────────────────────────────────────────
class _BranchCard extends StatelessWidget {
  final Branch branch;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onConfirm;

  const _BranchCard({
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
                        if (branch.city.isNotEmpty ||
                            branch.state.isNotEmpty)
                          Text(
                            [branch.city, branch.state]
                                .where((s) => s.isNotEmpty)
                                .join(', '),
                            style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurfaceVariant),
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

              if (branch.address.isNotEmpty)
                _InfoRow(
                  icon: Icons.location_on_outlined,
                  text: branch.fullAddress,
                  color: cs.onSurfaceVariant,
                ),
              _InfoRow(
                icon: Icons.access_time_outlined,
                text: '${branch.openingTime} – ${branch.closingTime}',
                color: cs.onSurfaceVariant,
              ),
              if (branch.phone.isNotEmpty)
                _InfoRow(
                  icon: Icons.phone_outlined,
                  text: branch.phone,
                  color: cs.onSurfaceVariant,
                ),

              if (isSelected) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onConfirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding:
                          const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.check_circle_outline,
                        size: 18),
                    label: const Text('Ir a esta sucursal',
                        style: TextStyle(fontWeight: FontWeight.w700)),
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
  const _InfoRow(
      {required this.icon, required this.text, required this.color});

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
            child: Text(text,
                style: TextStyle(fontSize: 12, color: color),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

// ── Estado vacío ──────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final VoidCallback onRetry;
  final VoidCallback onConfigServer;
  const _EmptyState(
      {required this.onRetry, required this.onConfigServer});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.store_mall_directory_outlined,
                size: 72, color: AppColors.outlineVariant),
            const SizedBox(height: 16),
            const Text(
              'No se encontraron sucursales',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 6),
            Text(
              'Verifica que el servidor esté encendido\ny que la IP esté configurada correctamente.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: onConfigServer,
              icon: const Icon(Icons.settings_ethernet, size: 18),
              label: const Text('Configurar servidor'),
            ),
          ],
        ),
      ),
    );
  }
}
