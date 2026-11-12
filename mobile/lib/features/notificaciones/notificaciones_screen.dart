import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_radius.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/responsive.dart';
import '../../services/auth_service.dart';
import '../../services/notificacion_service.dart';
import '../../shared/models/notificacion.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/states.dart';
import '../actividades/asignacion_screen.dart';
import '../actividades/revisar_entrega_screen.dart';
import '../comunidades/solicitudes_screen.dart';

/// Notificaciones del usuario (coordinador o apadrinado).
///
/// Puede usarse como pestaña embebida ([embedded]) del shell o como
/// pantalla independiente. Al tocar una notificación se marca como
/// leída y se abre lo que la originó.
class NotificacionesScreen extends StatefulWidget {
  final bool embedded;

  const NotificacionesScreen({super.key, this.embedded = false});

  @override
  State<NotificacionesScreen> createState() => _NotificacionesScreenState();
}

class _NotificacionesScreenState extends State<NotificacionesScreen> {
  final _servicio = NotificacionService();
  List<Notificacion> _notificaciones = [];
  bool _isLoading = true;
  String? _error;

  int get _noLeidas => _notificaciones.where((n) => !n.leida).length;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    if (user == null) return;
    setState(() {
      _isLoading = _notificaciones.isEmpty;
      _error = null;
    });
    try {
      final lista = await _servicio.listarPorUsuario(user.usuarioId);
      if (mounted) {
        setState(() {
          _notificaciones = lista;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = mensajeDeError(e);
        });
      }
    }
  }

  Future<void> _marcarTodas() async {
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    if (user == null) return;
    try {
      await _servicio.marcarTodasComoLeidas(user.usuarioId);
      _cargar();
    } catch (_) {}
  }

  Future<void> _abrir(Notificacion n) async {
    if (!n.leida) {
      try {
        await _servicio.marcarComoLeida(n.id);
      } catch (_) {}
    }
    if (!mounted) return;
    final auth = Provider.of<AuthService>(context, listen: false);
    final user = auth.currentUser;
    final id = n.idReferencia;

    if (n.tipoReferencia == 'ASIGNACION' && id != null) {
      final pantalla = user?.isCoordinador == true
          ? RevisarEntregaScreen(asignacionId: id)
          : AsignacionScreen(asignacionId: id) as Widget;
      await Navigator.push(context, MaterialPageRoute(builder: (_) => pantalla));
    } else if (n.tipoReferencia == 'SOLICITUD') {
      if (user?.isCoordinador == true) {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => const SolicitudesScreen()));
      } else {
        try {
          final actualizado = await auth.refrescarPerfil();
          if (mounted && actualizado?.apadrinadoId != null) {
            Navigator.pushNamedAndRemoveUntil(context, '/apadrinado/home', (_) => false);
            return;
          }
        } catch (_) {}
      }
    }
    if (mounted) _cargar();
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_isLoading) {
      body = const LoadingState(message: 'Cargando notificaciones...');
    } else if (_error != null && _notificaciones.isEmpty) {
      body = ErrorState(title: 'No se pudieron cargar las notificaciones', message: _error, onRetry: _cargar);
    } else {
      body = RefreshIndicator(
        onRefresh: _cargar,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          children: [
            ResponsiveContent(
              maxWidth: 760,
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_notificaciones.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 60),
                      child: EmptyState(
                        icon: Icons.notifications_none_outlined,
                        title: 'Sin notificaciones',
                        description: 'Cuando tengas novedades aparecerán aquí',
                      ),
                    )
                  else ...[
                    if (widget.embedded && _noLeidas > 0)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text('$_noLeidas sin leer',
                                  style: const TextStyle(color: AppColors.textSecondary)),
                            ),
                            TextButton.icon(
                              onPressed: _marcarTodas,
                              icon: const Icon(Icons.done_all, size: 18),
                              label: const Text('Marcar todas como leídas'),
                            ),
                          ],
                        ),
                      ),
                    for (final n in _notificaciones) _NotificacionTile(notificacion: n, onTap: () => _abrir(n)),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        actions: [
          if (_noLeidas > 0)
            IconButton(
              icon: const Icon(Icons.done_all),
              tooltip: 'Marcar todas como leídas',
              onPressed: _marcarTodas,
            ),
        ],
      ),
      body: body,
    );
  }
}

/// Ícono y color de cada tipo de notificación.
class EstiloNotificacion {
  static IconData icono(String tipo) {
    switch (tipo) {
      case 'NUEVA_ACTIVIDAD':
        return Icons.assignment_outlined;
      case 'NUEVO_ANUNCIO':
        return Icons.campaign_outlined;
      case 'NUEVO_MATERIAL':
        return Icons.menu_book_outlined;
      case 'ACTIVIDAD_MODIFICADA':
        return Icons.edit_note;
      case 'PROXIMA_FECHA_LIMITE':
      case 'RECORDATORIO':
        return Icons.alarm;
      case 'ENTREGA_ACTIVIDAD':
      case 'DOCUMENTO_SUBIDO':
        return Icons.upload_file_outlined;
      case 'ACTIVIDAD_EN_REVISION':
        return Icons.rate_review_outlined;
      case 'CORRECCION_SOLICITADA':
        return Icons.report_gmailerrorred_outlined;
      case 'ACTIVIDAD_APROBADA':
        return Icons.verified_outlined;
      case 'ACTIVIDAD_VENCIDA':
        return Icons.event_busy_outlined;
      case 'NUEVA_SOLICITUD':
        return Icons.person_add_alt_1_outlined;
      case 'SOLICITUD_ACEPTADA':
        return Icons.how_to_reg_outlined;
      case 'SOLICITUD_RECHAZADA':
        return Icons.person_off_outlined;
      case 'EVENTO_COMUNIDAD':
        return Icons.location_city_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  static Color color(String tipo) {
    switch (tipo) {
      case 'CORRECCION_SOLICITADA':
      case 'SOLICITUD_RECHAZADA':
        return AppColors.coralRed;
      case 'ACTIVIDAD_APROBADA':
      case 'SOLICITUD_ACEPTADA':
      case 'NUEVO_MATERIAL':
        return AppColors.sageGreen;
      case 'PROXIMA_FECHA_LIMITE':
      case 'RECORDATORIO':
      case 'NUEVO_ANUNCIO':
        return AppColors.mustardGold;
      case 'ACTIVIDAD_VENCIDA':
        return AppColors.brownCocoa;
      case 'ENTREGA_ACTIVIDAD':
      case 'NUEVA_SOLICITUD':
      case 'ACTIVIDAD_EN_REVISION':
        return AppColors.darkNavy;
      default:
        return AppColors.tealCyan;
    }
  }

  /// Fecha relativa: "hace 5 min", "ayer", o la fecha.
  static String fechaRelativa(String? iso) {
    final fecha = iso != null ? DateTime.tryParse(iso) : null;
    if (fecha == null) return '';
    final d = DateTime.now().difference(fecha.toLocal());
    if (d.inMinutes < 1) return 'ahora';
    if (d.inMinutes < 60) return 'hace ${d.inMinutes} min';
    if (d.inHours < 24) return 'hace ${d.inHours} h';
    if (d.inDays == 1) return 'ayer';
    if (d.inDays < 7) return 'hace ${d.inDays} días';
    return AppDateUtils.formatDate(iso);
  }

  EstiloNotificacion._();
}

class _NotificacionTile extends StatelessWidget {
  final Notificacion notificacion;
  final VoidCallback onTap;

  const _NotificacionTile({required this.notificacion, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final n = notificacion;
    final color = EstiloNotificacion.color(n.tipo);
    return AppCard(
      onTap: onTap,
      backgroundColor: n.leida ? null : color.withAlpha(12),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(color: color.withAlpha(30), borderRadius: BorderRadius.circular(AppRadius.md)),
            child: Icon(EstiloNotificacion.icono(n.tipo), color: color, size: 22),
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
                        n.titulo,
                        style: TextStyle(
                          fontWeight: n.leida ? FontWeight.w500 : FontWeight.w700,
                          color: AppColors.charcoal,
                        ),
                      ),
                    ),
                    if (!n.leida)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(n.mensaje, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(height: AppSpacing.xs),
                Text(EstiloNotificacion.fechaRelativa(n.fechaCreacion),
                    style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
