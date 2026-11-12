import 'package:flutter/material.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/responsive.dart';
import '../../services/comunidad_service.dart';
import '../../shared/models/solicitud_incorporacion.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../shared/widgets/confirmation_dialog.dart';
import '../../shared/widgets/states.dart';

/// Solicitudes de incorporación pendientes (de una comunidad o de todas
/// las comunidades del coordinador). Antes de decidir se puede consultar
/// el perfil del solicitante.
class SolicitudesScreen extends StatefulWidget {
  final int? comunidadId;

  const SolicitudesScreen({super.key, this.comunidadId});

  @override
  State<SolicitudesScreen> createState() => _SolicitudesScreenState();
}

class _SolicitudesScreenState extends State<SolicitudesScreen> {
  final _servicio = ComunidadService();

  List<SolicitudIncorporacion> _solicitudes = [];
  bool _isLoading = true;
  String? _error;
  final Set<int> _procesando = {};

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _isLoading = _solicitudes.isEmpty;
      _error = null;
    });
    try {
      final lista = await _servicio.solicitudesPendientes(comunidadId: widget.comunidadId);
      if (mounted) {
        setState(() {
          _solicitudes = lista;
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

  void _aviso(String texto, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(texto), backgroundColor: error ? AppColors.coralRed : AppColors.sageGreen),
    );
  }

  Future<void> _aceptar(SolicitudIncorporacion s) async {
    final ok = await showConfirmationDialog(
      context,
      title: 'Aceptar solicitud',
      message: '${s.nombreCompleto} se incorporará a ${s.comunidadNombre ?? 'la comunidad'} y recibirá las '
          'actividades asignadas a toda la comunidad.',
      confirmLabel: 'Aceptar',
      icon: Icons.check_circle_outline,
    );
    if (!ok || !mounted) return;
    setState(() => _procesando.add(s.id));
    try {
      await _servicio.aprobarSolicitud(s.id);
      if (mounted) {
        _aviso('${s.nombreCompleto} fue incorporado(a)');
        _cargar();
      }
    } catch (e) {
      if (mounted) _aviso(mensajeDeError(e), error: true);
    } finally {
      if (mounted) setState(() => _procesando.remove(s.id));
    }
  }

  Future<void> _rechazar(SolicitudIncorporacion s) async {
    final motivo = await showDialog<String>(
      context: context,
      builder: (_) => _RechazoDialog(nombre: s.nombreCompleto),
    );
    if (motivo == null || !mounted) return;
    setState(() => _procesando.add(s.id));
    try {
      await _servicio.rechazarSolicitud(s.id, motivo: motivo);
      if (mounted) {
        _aviso('Solicitud rechazada');
        _cargar();
      }
    } catch (e) {
      if (mounted) _aviso(mensajeDeError(e), error: true);
    } finally {
      if (mounted) setState(() => _procesando.remove(s.id));
    }
  }

  Future<void> _verPerfil(SolicitudIncorporacion resumen) async {
    SolicitudIncorporacion s = resumen;
    try {
      s = await _servicio.solicitud(resumen.id);
    } catch (_) {
      // Se muestra lo que ya se tiene
    }
    if (!mounted) return;
    final accion = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (_) => _PerfilSolicitante(solicitud: s),
    );
    if (accion == 'aceptar') _aceptar(s);
    if (accion == 'rechazar') _rechazar(s);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Solicitudes de incorporación')),
      body: _isLoading
          ? const LoadingState(message: 'Cargando solicitudes...')
          : _error != null && _solicitudes.isEmpty
              ? ErrorState(title: 'No se pudieron cargar las solicitudes', message: _error, onRetry: _cargar)
              : RefreshIndicator(
                  onRefresh: _cargar,
                  child: _solicitudes.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            SizedBox(height: 80),
                            EmptyState(
                              icon: Icons.how_to_reg_outlined,
                              title: 'Sin solicitudes pendientes',
                              description: 'Las personas que usen el código de acceso aparecerán aquí',
                            ),
                          ],
                        )
                      : ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                          children: [
                            ResponsiveContent(
                              maxWidth: 760,
                              padding: EdgeInsets.zero,
                              child: Column(
                                children: [
                                  for (final s in _solicitudes)
                                    _SolicitudCard(
                                      solicitud: s,
                                      procesando: _procesando.contains(s.id),
                                      onPerfil: () => _verPerfil(s),
                                      onAceptar: () => _aceptar(s),
                                      onRechazar: () => _rechazar(s),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                ),
    );
  }
}

class _SolicitudCard extends StatelessWidget {
  final SolicitudIncorporacion solicitud;
  final bool procesando;
  final VoidCallback onPerfil;
  final VoidCallback onAceptar;
  final VoidCallback onRechazar;

  const _SolicitudCard({
    required this.solicitud,
    required this.procesando,
    required this.onPerfil,
    required this.onAceptar,
    required this.onRechazar,
  });

  @override
  Widget build(BuildContext context) {
    final s = solicitud;
    return AppCard(
      onTap: onPerfil,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InitialsAvatar(name: s.nombreCompleto, size: 44),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.nombreCompleto,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.charcoal)),
                    Text(s.correo ?? '', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    Text(
                      '${s.comunidadNombre ?? ''} · ${AppDateUtils.formatDateTime(s.fechaSolicitud)}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (procesando)
            const LinearProgressIndicator()
          else
            Wrap(
              alignment: WrapAlignment.end,
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                TextButton.icon(onPressed: onPerfil, icon: const Icon(Icons.person_search_outlined), label: const Text('Ver perfil')),
                OutlinedButton.icon(
                  onPressed: onRechazar,
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.coralRed),
                  icon: const Icon(Icons.close),
                  label: const Text('Rechazar'),
                ),
                ElevatedButton.icon(onPressed: onAceptar, icon: const Icon(Icons.check), label: const Text('Aceptar')),
              ],
            ),
        ],
      ),
    );
  }
}

class _PerfilSolicitante extends StatelessWidget {
  final SolicitudIncorporacion solicitud;

  const _PerfilSolicitante({required this.solicitud});

  @override
  Widget build(BuildContext context) {
    final s = solicitud;
    String valor(String? v) => v == null || v.isEmpty ? 'No indicado' : v;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: InitialsAvatar(name: s.nombreCompleto, size: 64)),
            const SizedBox(height: AppSpacing.md),
            Text(s.nombreCompleto,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.charcoal)),
            const SizedBox(height: AppSpacing.lg),
            InfoTile(icon: Icons.email_outlined, label: 'Correo', value: valor(s.correo)),
            InfoTile(icon: Icons.phone_outlined, label: 'Teléfono', value: valor(s.telefono)),
            InfoTile(icon: Icons.home_outlined, label: 'Dirección', value: valor(s.direccion)),
            InfoTile(
              icon: Icons.cake_outlined,
              label: 'Fecha de nacimiento',
              value: s.fechaNacimiento == null ? 'No indicada' : AppDateUtils.formatDate(s.fechaNacimiento),
            ),
            InfoTile(icon: Icons.location_city_outlined, label: 'Comunidad', value: valor(s.comunidadNombre)),
            InfoTile(icon: Icons.key_outlined, label: 'Código utilizado', value: valor(s.codigo)),
            InfoTile(icon: Icons.schedule, label: 'Fecha de solicitud', value: AppDateUtils.formatDateTime(s.fechaSolicitud)),
            const SizedBox(height: AppSpacing.lg),
            if (s.pendiente)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.coralRed),
                      onPressed: () => Navigator.pop(context, 'rechazar'),
                      child: const Text('Rechazar'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, 'aceptar'),
                      child: const Text('Aceptar'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _RechazoDialog extends StatefulWidget {
  final String nombre;

  const _RechazoDialog({required this.nombre});

  @override
  State<_RechazoDialog> createState() => _RechazoDialogState();
}

class _RechazoDialogState extends State<_RechazoDialog> {
  final _motivo = TextEditingController();

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rechazar solicitud'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Se notificará a ${widget.nombre}.'),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _motivo,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Motivo (opcional)'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.coralRed, foregroundColor: Colors.white),
          onPressed: () => Navigator.pop(context, _motivo.text.trim()),
          child: const Text('Rechazar'),
        ),
      ],
    );
  }
}
