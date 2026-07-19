import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../models/branch.dart';
import '../providers/branch_provider.dart';

/// Gestión de sucursales — solo para owner.
/// CRUD completo: crear, editar, eliminar, asignar vendedores.
class BranchManageScreen extends StatefulWidget {
  const BranchManageScreen({super.key});

  @override
  State<BranchManageScreen> createState() => _BranchManageScreenState();
}

class _BranchManageScreenState extends State<BranchManageScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BranchProvider>().loadBranches();
    });
  }

  void _openForm({Branch? branch}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _BranchForm(
        existing: branch,
        onSave: (data) async {
          final prov = context.read<BranchProvider>();
          if (branch == null) {
            await prov.createBranch(data);
          } else {
            await prov.updateBranch(branch.id, data);
          }
          if (mounted) Navigator.of(context).pop();
        },
      ),
    );
  }

  Future<void> _confirmDelete(Branch branch) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar sucursal'),
        content:
            Text('¿Eliminar "${branch.name}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok == true && mounted) {
      await context.read<BranchProvider>().deleteBranch(branch.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<BranchProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('SUCURSALES')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Nueva'),
      ),
      body: prov.loading
          ? const Center(child: CircularProgressIndicator())
          : prov.assigned.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.store_mall_directory_outlined,
                          size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('Sin sucursales registradas'),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  itemCount: prov.assigned.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final b = prov.assigned[i];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              b.isActive ? Colors.green[50] : Colors.grey[100],
                          child: Icon(
                            Icons.store,
                            color: b.isActive ? Colors.green : Colors.grey,
                          ),
                        ),
                        title: Text(b.name,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(b.fullAddress,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              onPressed: () => _openForm(branch: b),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  size: 20, color: Colors.red),
                              onPressed: () => _confirmDelete(b),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

// ── Formulario de crear/editar sucursal ───────────────────────────────────────

class _BranchForm extends StatefulWidget {
  final Branch? existing;
  final Future<void> Function(Map<String, dynamic>) onSave;

  const _BranchForm({this.existing, required this.onSave});

  @override
  State<_BranchForm> createState() => _BranchFormState();
}

class _BranchFormState extends State<_BranchForm> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  late final TextEditingController _name;
  late final TextEditingController _address;
  late final TextEditingController _city;
  late final TextEditingController _state;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _opening;
  late final TextEditingController _closing;
  bool _isActive = true;

  double? _pickedLat;
  double? _pickedLng;

  @override
  void initState() {
    super.initState();
    final b = widget.existing;
    _name    = TextEditingController(text: b?.name ?? '');
    _address = TextEditingController(text: b?.address ?? '');
    _city    = TextEditingController(text: b?.city ?? '');
    _state   = TextEditingController(text: b?.state ?? '');
    _phone   = TextEditingController(text: b?.phone ?? '');
    _email   = TextEditingController(text: b?.email ?? '');
    _opening = TextEditingController(text: b?.openingTime ?? '08:00');
    _closing = TextEditingController(text: b?.closingTime ?? '22:00');
    _pickedLat = b?.latitude;
    _pickedLng = b?.longitude;
    _isActive = b?.isActive ?? true;
  }

  @override
  void dispose() {
    for (final c in [_name, _address, _city, _state, _phone, _email,
                     _opening, _closing]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _openMapPicker() async {
    final result = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (_) => _LocationPickerScreen(
          initial: (_pickedLat != null && _pickedLng != null)
              ? LatLng(_pickedLat!, _pickedLng!)
              : null,
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _pickedLat = result.latitude;
        _pickedLng = result.longitude;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.onSave({
        'name': _name.text.trim(),
        'address': _address.text.trim(),
        'city': _city.text.trim(),
        'state': _state.text.trim(),
        'phone': _phone.text.trim(),
        'email': _email.text.trim(),
        'opening_time': _opening.text.trim(),
        'closing_time': _closing.text.trim(),
        'latitude': _pickedLat,
        'longitude': _pickedLng,
        'is_active': _isActive,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasLocation = _pickedLat != null && _pickedLng != null;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.existing == null ? 'Nueva sucursal' : 'Editar sucursal',
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
              ),
              const SizedBox(height: 16),
              _field('Nombre*', _name,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Requerido' : null),
              _field('Dirección', _address),
              Row(
                children: [
                  Expanded(child: _field('Ciudad', _city)),
                  const SizedBox(width: 8),
                  Expanded(child: _field('Estado', _state)),
                ],
              ),
              Row(
                children: [
                  Expanded(child: _field('Teléfono', _phone)),
                  const SizedBox(width: 8),
                  Expanded(child: _field('Email', _email)),
                ],
              ),
              Row(
                children: [
                  Expanded(child: _field('Apertura', _opening)),
                  const SizedBox(width: 8),
                  Expanded(child: _field('Cierre', _closing)),
                ],
              ),
              // ── Selector de ubicación en mapa ────────────────────────────
              const SizedBox(height: 4),
              OutlinedButton.icon(
                onPressed: _openMapPicker,
                icon: Icon(
                  hasLocation ? Icons.location_on : Icons.add_location_alt_outlined,
                  color: hasLocation ? Colors.green : null,
                ),
                label: Text(
                  hasLocation
                      ? '${_pickedLat!.toStringAsFixed(5)}, ${_pickedLng!.toStringAsFixed(5)}'
                      : 'Ubicar en el mapa',
                  style: TextStyle(
                    color: hasLocation ? Colors.green : null,
                    fontSize: 13,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: hasLocation ? Colors.green : Colors.grey,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 4),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Activa'),
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Guardar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController ctrl, {
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: ctrl,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}

// ── Pantalla de selector de ubicación ────────────────────────────────────────

class _LocationPickerScreen extends StatefulWidget {
  final LatLng? initial;
  const _LocationPickerScreen({this.initial});

  @override
  State<_LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<_LocationPickerScreen> {
  final MapController _mapCtrl = MapController();
  LatLng? _picked;
  bool _locating = false;

  static const _defaultCenter = LatLng(19.4326, -99.1332); // CDMX

  @override
  void initState() {
    super.initState();
    _picked = widget.initial;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initial == null) _goToCurrentLocation();
    });
  }

  @override
  void dispose() {
    _mapCtrl.dispose();
    super.dispose();
  }

  Future<void> _goToCurrentLocation() async {
    setState(() => _locating = true);
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever ||
          perm == LocationPermission.denied) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final here = LatLng(pos.latitude, pos.longitude);
      _mapCtrl.move(here, 15);
      setState(() => _picked = here);
    } catch (_) {
      // ignore — stays on default center
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final center = _picked ?? widget.initial ?? _defaultCenter;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ubicar sucursal'),
        actions: [
          TextButton(
            onPressed: _picked == null
                ? null
                : () => Navigator.of(context).pop(_picked),
            child: const Text('Confirmar',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapCtrl,
            options: MapOptions(
              initialCenter: center,
              initialZoom: _picked != null ? 15.0 : 12.0,
              onTap: (_, latlng) => setState(() => _picked = latlng),
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.ventaia.seller',
              ),
              if (_picked != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _picked!,
                      width: 48,
                      height: 48,
                      child: const Icon(
                        Icons.location_pin,
                        color: Colors.red,
                        size: 48,
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // Instrucción flotante
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: cs.surface.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.touch_app_outlined, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _picked == null
                          ? 'Toca el mapa para colocar la sucursal'
                          : 'Toca para mover la ubicación',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Coordenadas actuales
          if (_picked != null)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: cs.surface.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.red, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      '${_picked!.latitude.toStringAsFixed(6)}, '
                      '${_picked!.longitude.toStringAsFixed(6)}',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),

          // Botón de ubicación actual
          Positioned(
            bottom: _picked != null ? 74 : 16,
            right: 16,
            child: FloatingActionButton.small(
              heroTag: 'loc',
              onPressed: _locating ? null : _goToCurrentLocation,
              tooltip: 'Mi ubicación',
              child: _locating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.my_location),
            ),
          ),
        ],
      ),
    );
  }
}
