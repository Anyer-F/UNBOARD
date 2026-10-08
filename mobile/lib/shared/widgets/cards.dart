import 'package:flutter/material.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/actividad.dart';
import '../../shared/models/comunidad.dart';
import '../../shared/models/documento.dart';
import '../../shared/models/notificacion.dart';
import 'app_card.dart';
import 'common_widgets.dart';
import 'status_chip.dart';

/// Tarjeta de actividad (lista del Apadrinado / Coordinador).
class ActivityCard extends StatelessWidget {
  final Actividad actividad;
  final VoidCallback? onTap;
  final bool showProgress;
  final int completedItems;
  final int totalItems;
  final VoidCallback? onEditar;
  final VoidCallback? onEliminar;

  const ActivityCard({
    super.key,
    required this.actividad,
    this.onTap,
    this.showProgress = false,
    this.completedItems = 0,
    this.totalItems = 0,
    this.onEditar,
    this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.getEstadoColor(actividad.estado);

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  actividad.titulo,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.charcoal,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              StatusChip(estado: actividad.estado),
              if (onEditar != null || onEliminar != null) ...[
                const SizedBox(width: AppSpacing.xs),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'editar') {
                      onEditar?.call();
                    } else if (value == 'eliminar') {
                      onEliminar?.call();
                    }
                  },
                  itemBuilder: (_) => [
                    if (onEditar != null)
                      const PopupMenuItem(
                        value: 'editar',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined,
                                size: 18, color: AppColors.darkNavy),
                            SizedBox(width: 10),
                            Text('Editar'),
                          ],
                        ),
                      ),
                    if (onEliminar != null)
                      const PopupMenuItem(
                        value: 'eliminar',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline,
                                size: 18, color: AppColors.coralRed),
                            SizedBox(width: 10),
                            Text(
                              'Eliminar',
                              style: TextStyle(color: AppColors.coralRed),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
          if (actividad.descripcion != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              actividad.descripcion!,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 14,
                color: AppColors.textTertiary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'Fecha límite: ${actividad.fechaLimite ?? "Sin fecha"}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (actividad.apadrinadoNombre != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Icon(
                  Icons.person_outline,
                  size: 14,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    'Para: ${actividad.apadrinadoNombre!}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          if (showProgress && totalItems > 0) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: completedItems / totalItems,
                      minHeight: 6,
                      backgroundColor: AppColors.borderLight,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Text(
                  '$completedItems de $totalItems',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Tarjeta de documento (expediente / gestión documental).
class DocumentCard extends StatelessWidget {
  final Documento documento;
  final VoidCallback? onTap;
  final VoidCallback? onDownload;

  const DocumentCard({
    super.key,
    required this.documento,
    this.onTap,
    this.onDownload,
  });

  String _formatSize(int? bytes) {
    if (bytes == null) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final icon = documento.isPdf
        ? Icons.picture_as_pdf
        : documento.isImage
            ? Icons.image_outlined
            : documento.isCarta
                ? Icons.mail_outline
                : Icons.insert_drive_file_outlined;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.darkNavy.withAlpha(13),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 24,
              color: AppColors.darkNavy,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  documento.nombreOriginal,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.charcoal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    documento.tipoDocumento,
                    _formatSize(documento.tamanioBytes),
                  ].where((s) => s.isNotEmpty).join(' · '),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (onDownload != null)
            IconButton(
              icon: const Icon(Icons.download_outlined),
              tooltip: 'Descargar',
              onPressed: onDownload,
            ),
        ],
      ),
    );
  }
}

/// Tarjeta de comunidad (vista del Coordinador).
class CommunityCard extends StatelessWidget {
  final Comunidad comunidad;
  final int apadrinadosCount;
  final int actividadesPendientes;
  final VoidCallback? onTap;

  const CommunityCard({
    super.key,
    required this.comunidad,
    required this.apadrinadosCount,
    required this.actividadesPendientes,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.tealCyan.withAlpha(13),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.location_city_outlined,
                  color: AppColors.tealCyan,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comunidad.nombre,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.charcoal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (comunidad.municipio != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        comunidad.municipio!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: AppColors.textTertiary,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _Metric(
                icon: Icons.people_outline,
                label: '$apadrinadosCount apadrinados',
                color: AppColors.darkNavy,
              ),
              const SizedBox(width: AppSpacing.lg),
              _Metric(
                icon: Icons.assignment_late_outlined,
                label: '$actividadesPendientes pendientes',
                color: AppColors.mustardGold,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _Metric({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Tarjeta de persona (apadrinado / solicitante).
class PersonCard extends StatelessWidget {
  final String nombre;
  final String? subtitle;
  final String? detail;
  final VoidCallback? onTap;
  final Widget? trailing;

  const PersonCard({
    super.key,
    required this.nombre,
    this.subtitle,
    this.detail,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          InitialsAvatar(name: nombre, size: 44),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.charcoal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (detail != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    detail!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          trailing ??
              const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: AppColors.textTertiary,
              ),
        ],
      ),
    );
  }
}

/// Tarjeta de notificación (leída / no leída).
class NotificationCard extends StatelessWidget {
  final Notificacion notificacion;
  final VoidCallback? onTap;

  const NotificationCard({
    super.key,
    required this.notificacion,
    this.onTap,
  });

  IconData get _icon {
    switch (notificacion.tipo.toUpperCase()) {
      case 'ACTIVAD':
      case 'ACTIVIDAD':
        return Icons.assignment_outlined;
      case 'VENCIMIENTO':
        return Icons.schedule_outlined;
      case 'ENTREGA':
        return Icons.cloud_upload_outlined;
      case 'CORRECCION':
        return Icons.error_outline;
      case 'APROBACION':
        return Icons.check_circle_outline;
      case 'SOLICITUD':
        return Icons.person_add_outlined;
      case 'DOCUMENTO':
        return Icons.description_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color get _color {
    switch (notificacion.tipo.toUpperCase()) {
      case 'CORRECCION':
        return AppColors.coralRed;
      case 'APROBACION':
        return AppColors.sageGreen;
      case 'VENCIMIENTO':
        return AppColors.mustardGold;
      default:
        return AppColors.darkNavy;
    }
  }

  @override
  Widget build(BuildContext context) {
    final leida = notificacion.leida;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      backgroundColor: leida ? AppColors.cardBg : AppColors.darkNavy.withAlpha(8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm + 2),
            decoration: BoxDecoration(
              color: _color.withAlpha(13),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _icon,
              size: 20,
              color: _color,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        notificacion.titulo,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: leida ? FontWeight.w500 : FontWeight.w700,
                          color: AppColors.charcoal,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!leida)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(left: AppSpacing.sm),
                        decoration: const BoxDecoration(
                          color: AppColors.coralRed,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  notificacion.mensaje,
                  style: TextStyle(
                    fontSize: 13,
                    color: leida ? AppColors.textSecondary : AppColors.charcoal,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (notificacion.fechaCreacion != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    notificacion.fechaCreacion!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
