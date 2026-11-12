import 'package:flutter/material.dart';

import '../../core/constants/app_radius.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';
import '../models/actividad.dart';
import '../models/asignacion.dart';
import 'app_card.dart';
import 'status_chip.dart';

/// Ícono y color de cada tipo de actividad.
class TipoActividadEstilo {
  static IconData icono(String? tipo) {
    switch (tipo) {
      case TipoActividad.anuncio:
        return Icons.campaign_outlined;
      case TipoActividad.material:
        return Icons.menu_book_outlined;
      default:
        return Icons.assignment_outlined;
    }
  }

  static Color color(String? tipo) {
    switch (tipo) {
      case TipoActividad.anuncio:
        return AppColors.mustardGold;
      case TipoActividad.material:
        return AppColors.sageGreen;
      default:
        return AppColors.darkNavy;
    }
  }

  TipoActividadEstilo._();
}

/// Etiqueta con el tipo de actividad (Tarea, Anuncio, Material de apoyo).
class TipoActividadChip extends StatelessWidget {
  final String? tipo;

  const TipoActividadChip({super.key, required this.tipo});

  @override
  Widget build(BuildContext context) {
    final color = TipoActividadEstilo.color(tipo);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(TipoActividadEstilo.icono(tipo), size: 13, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              TipoActividad.etiqueta(tipo),
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Línea pequeña con ícono y texto (fecha, módulo, comunidad...).
class DatoLinea extends StatelessWidget {
  final IconData icon;
  final String texto;
  final Color? color;

  const DatoLinea({super.key, required this.icon, required this.texto, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textTertiary;
    return Row(
      children: [
        Icon(icon, size: 14, color: c),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            texto,
            style: TextStyle(fontSize: 12, color: c),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Avance de una tarea: barra de aprobados y conteo por estado.
class ResumenAvanceWidget extends StatelessWidget {
  final ResumenAvance resumen;
  final bool esTarea;

  const ResumenAvanceWidget({super.key, required this.resumen, this.esTarea = true});

  @override
  Widget build(BuildContext context) {
    final total = resumen.asignados;
    if (!esTarea) {
      return Text(
        '${resumen.vistos} de $total lo han visto',
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      );
    }
    final valor = total == 0 ? 0.0 : resumen.aprobados / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.full),
                child: LinearProgressIndicator(
                  value: valor,
                  minHeight: 6,
                  backgroundColor: AppColors.borderLight,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.sageGreen),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(
              '${resumen.aprobados} de $total aprobados',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.sageGreen),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            _Conteo('Asignados', total, AppColors.textSecondary),
            _Conteo('Pendientes', resumen.pendientes + resumen.enProgreso, AppColors.mustardGold),
            _Conteo('Por revisar', resumen.porRevisar, AppColors.darkNavy),
            _Conteo('Corrección', resumen.correcciones, AppColors.coralRed),
            if (resumen.vencidos > 0) _Conteo('Vencidos', resumen.vencidos, AppColors.brownCocoa),
          ],
        ),
      ],
    );
  }
}

class _Conteo extends StatelessWidget {
  final String etiqueta;
  final int valor;
  final Color color;

  const _Conteo(this.etiqueta, this.valor, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        '$etiqueta: $valor',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

/// Título de tarjeta con su etiqueta (tipo o estado). Si la tarjeta es
/// angosta la etiqueta pasa debajo del título para no aplastarlo.
class _Encabezado extends StatelessWidget {
  final Widget? leading;
  final Widget titulo;
  final Widget etiqueta;
  final Widget? trailing;

  const _Encabezado({this.leading, required this.titulo, required this.etiqueta, this.trailing});

  static const double _anchoMinimo = 320;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final angosta = constraints.maxWidth < _anchoMinimo;
      final fila = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: AppSpacing.sm)],
          Expanded(child: titulo),
          if (!angosta) ...[const SizedBox(width: AppSpacing.sm), etiqueta],
          if (trailing != null) trailing!,
        ],
      );
      if (!angosta) return fila;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [fila, const SizedBox(height: AppSpacing.xs), etiqueta],
      );
    });
  }
}

/// Tarjeta del tablero de actividades del coordinador.
class ActividadTableroCard extends StatelessWidget {
  final Actividad actividad;
  final VoidCallback? onTap;
  final Widget? trailing;

  const ActividadTableroCard({super.key, required this.actividad, this.onTap, this.trailing});

  @override
  Widget build(BuildContext context) {
    final a = actividad;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Encabezado(
            titulo: Text(
              a.titulo,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.charcoal),
            ),
            etiqueta: TipoActividadChip(tipo: a.tipo),
            trailing: trailing,
          ),
          const SizedBox(height: AppSpacing.sm),
          DatoLinea(
            icon: Icons.folder_outlined,
            texto: [a.comunidadNombre, a.moduloNombre].whereType<String>().join(' · '),
          ),
          if (a.esTarea) ...[
            const SizedBox(height: AppSpacing.xs),
            DatoLinea(
              icon: Icons.event_outlined,
              texto: 'Fecha límite: ${AppDateUtils.formatDate(a.fechaLimite)}',
              color: AppDateUtils.isOverdue(a.fechaLimite) ? AppColors.coralRed : null,
            ),
          ],
          if (a.resumen != null) ...[
            const SizedBox(height: AppSpacing.md),
            ResumenAvanceWidget(resumen: a.resumen!, esTarea: a.esTarea),
          ],
        ],
      ),
    );
  }
}

/// Tarjeta de una actividad asignada (vista del apadrinado o lista de
/// apadrinados de una actividad para el coordinador).
class AsignacionCard extends StatelessWidget {
  final Asignacion asignacion;
  final VoidCallback? onTap;

  /// Muestra el nombre del apadrinado en lugar del de la actividad.
  final bool porApadrinado;

  /// Margen exterior (por defecto el de [AppCard]).
  final EdgeInsetsGeometry? margin;

  const AsignacionCard({
    super.key,
    required this.asignacion,
    this.onTap,
    this.porApadrinado = false,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final s = asignacion;
    final a = s.actividad;
    final nombreActividad = (a?.titulo ?? 'Actividad') + (a?.eliminada == true ? ' (eliminada)' : '');
    final titulo = porApadrinado ? (s.apadrinadoNombre ?? 'Apadrinado') : nombreActividad;
    final destacar = s.enCorreccion || s.proximaAVencer;
    final colorBorde = s.enCorreccion ? AppColors.coralRed : AppColors.mustardGold;

    return AppCard(
      onTap: onTap,
      margin: margin,
      padding: const EdgeInsets.all(AppSpacing.lg),
      border: destacar ? Border.all(color: colorBorde, width: 1.5) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Encabezado(
            leading: !porApadrinado && a != null
                ? Icon(TipoActividadEstilo.icono(a.tipo), size: 20, color: TipoActividadEstilo.color(a.tipo))
                : null,
            titulo: Text(
              titulo,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.charcoal),
            ),
            etiqueta: StatusChip(estado: s.estado),
          ),
          if (!porApadrinado && a?.descripcion != null && a!.descripcion!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              a.descripcion!,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (a != null && a.esTarea && a.fechaLimite != null) ...[
            const SizedBox(height: AppSpacing.sm),
            DatoLinea(
              icon: Icons.event_outlined,
              texto: _textoFecha(a.fechaLimite),
              color: s.proximaAVencer ? AppColors.mustardGold : null,
            ),
          ],
          if (porApadrinado && s.fechaEnvio != null) ...[
            const SizedBox(height: AppSpacing.xs),
            DatoLinea(icon: Icons.upload_outlined, texto: 'Enviado: ${AppDateUtils.formatDateTime(s.fechaEnvio)}'),
          ],
          if (s.enCorreccion && s.ultimaSugerencia != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.coralRed.withAlpha(20),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                'Sugerencias: ${s.ultimaSugerencia}',
                style: const TextStyle(fontSize: 12, color: AppColors.coralRed),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _textoFecha(String? fecha) {
    final dias = AppDateUtils.daysUntil(fecha);
    final base = 'Fecha límite: ${AppDateUtils.formatDate(fecha)}';
    if (dias < 0) return '$base (vencida)';
    if (dias == 0) return '$base (vence hoy)';
    if (dias == 1) return '$base (vence mañana)';
    if (dias <= 3) return '$base (en $dias días)';
    return base;
  }
}
