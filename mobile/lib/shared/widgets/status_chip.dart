import 'package:flutter/material.dart';

import '../../core/constants/app_radius.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_theme.dart';

/// Chip que representa el estado de una actividad, entrega o carta.
///
/// Utiliza los colores de acento UNBOUND para diferenciar estados:
/// Pendiente (dorado), En progreso (turquesa), Enviado/En revisión
/// (azul oscuro), Aprobado (verde), Corrección (coral), Vencido (café).
class StatusChip extends StatelessWidget {
  final String estado;
  final String? customText;
  final double fontSize;
  final EdgeInsetsGeometry? padding;
  final Color? color;

  const StatusChip({
    super.key,
    required this.estado,
    this.customText,
    this.fontSize = 12,
    this.padding,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? AppTheme.getEstadoColor(estado);
    final text = customText ?? AppTheme.getEstadoTexto(estado);

    return Container(
      padding: padding ??
          const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs + 2,
          ),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(
          color: color.withAlpha(77),
          width: 1,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          color: color,
          letterSpacing: 0.25,
        ),
      ),
    );
  }
}

/// Compatibilidad con pantallas que usaban el nombre anterior.
/// Preferir [StatusChip].
class StatusBadge extends StatelessWidget {
  final String estado;
  final String? customText;
  final double fontSize;
  final EdgeInsetsGeometry? padding;

  const StatusBadge({
    super.key,
    required this.estado,
    this.customText,
    this.fontSize = 12,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return StatusChip(
      estado: estado,
      customText: customText,
      fontSize: fontSize,
      padding: padding,
    );
  }
}
