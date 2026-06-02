import 'package:flutter/material.dart';
import '../main.dart';

/// Recomendación accionable generada por el Asesor IA Proactivo.
class Insight {
  final String tipo; // reabastecer | tendencia | promocion | alerta
  final String titulo;
  final String descripcion;
  final String prioridad; // alta | media | baja
  final String? producto;

  Insight({
    required this.tipo,
    required this.titulo,
    required this.descripcion,
    required this.prioridad,
    this.producto,
  });

  factory Insight.fromJson(Map<String, dynamic> json) {
    final producto = json['producto'];
    return Insight(
      tipo: (json['tipo'] as String?) ?? 'tendencia',
      titulo: (json['titulo'] as String?) ?? '',
      descripcion: (json['descripcion'] as String?) ?? '',
      prioridad: (json['prioridad'] as String?) ?? 'media',
      producto: (producto is String && producto.isNotEmpty) ? producto : null,
    );
  }

  /// Icono según el tipo de recomendación.
  IconData get icon {
    switch (tipo) {
      case 'reabastecer':
        return Icons.inventory_2_outlined;
      case 'tendencia':
        return Icons.trending_up;
      case 'promocion':
        return Icons.local_offer_outlined;
      case 'alerta':
        return Icons.warning_amber_rounded;
      default:
        return Icons.lightbulb_outline;
    }
  }

  /// Color según la prioridad.
  Color get priorityColor {
    switch (prioridad) {
      case 'alta':
        return AppColors.danger;
      case 'media':
        return AppColors.cartAmber;
      case 'baja':
        return AppColors.success;
      default:
        return AppColors.accent;
    }
  }

  /// Etiqueta legible de la prioridad.
  String get priorityLabel => prioridad.toUpperCase();
}
