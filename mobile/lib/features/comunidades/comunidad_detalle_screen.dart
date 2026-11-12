import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_radius.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/responsive.dart';
import '../../services/comunidad_service.dart';
import '../../shared/models/apadrinado.dart';
import '../../shared/models/comunidad.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/cards.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../shared/widgets/confirmation_dialog.dart';
import '../../shared/widgets/states.dart';
import '../actividades/tablero_actividades_screen.dart';
import '../expediente/expediente_detalle_screen.dart';
import '../historial/historial_screen.dart';
import 'comunidad_form_dialog.dart';
import 'modulos_screen.dart';
import 'solicitudes_screen.dart';

/// Detalle de una comunidad del Coordinador: datos, modo de
/// incorporación, códigos de acceso, solicitudes, módulos, actividades,
/// apadrinados e historial.
class ComunidadDetalleScreen extends StatefulWidget {
  final int comunidadId;

  const ComunidadDetalleScreen({super.key, required this.comunidadId});

  @override
  State<ComunidadDetalleScreen> createState() => _ComunidadDetalleScreenState();
}

class _ComunidadDetalleScreenState extends State<ComunidadDetalleScreen> {
  final _servicio = ComunidadService();

  Comunidad? _comunidad;
  List<CodigoAcceso> _codigos = [];
  List<Apadrinado> _apadrinados = [];
  int _solicitudes = 0;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _isLoading = _comunidad == null;
      _error = null;
    });
    try {
      final id = widget.comunidadId;
      final r = await Future.wait([
        _servicio.obtener(id),
        _servicio.codigos(id),
        _servicio.apadrinados(id),
        _servicio.solicitudesPendientes(comunidadId: id),
      ]);
      if (!mounted) return;
      setState(() {
        _comunidad = r[0] as Comunidad;
        _codigos = (r[1] as List<CodigoAcceso>)..sort((a, b) => (b.activo ? 1 : 0) - (a.activo ? 1 : 0));
        _apadrinados = r[2] as List<Apadrinado>;
        _solicitudes = (r[3] as List).length;
        _isLoading = false;
      });
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
      SnackBar(content: Text(texto), backgroundColor: error ? AppColors.coralRed : null),
    );
  }

  Future<void> _abrir(Widget pantalla) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => pantalla));
    if (mounted) _cargar();
  }

  Future<void> _editar() async {
    final editada = await mostrarFormularioComunidad(context, comunidad: _comunidad);
    if (editada != null && mounted) {
      _aviso('Comunidad actualizada');
      _cargar();
    }
  }

  Future<void> _cambiarModo(String modo) async {
    try {
      final c = await _servicio.actualizar(widget.comunidadId, {'modoIncorporacion': modo});
      if (mounted) {
        setState(() => _comunidad = c);
        _aviso(modo == 'DIRECTO'
            ? 'Ahora el código incorpora a los apadrinados de inmediato'
            : 'Ahora las incorporaciones requieren su aprobación');
      }
    } catch (e) {
      if (mounted) _aviso(mensajeDeError(e), error: true);
    }
  }

  Future<void> _eliminar() async {
    final ok = await showConfirmationDialog(
      context,
      title: 'Eliminar comunidad',
      message: 'Solo se puede eliminar una comunidad sin apadrinados ni actividades. ¿Desea continuar?',
      confirmLabel: 'Eliminar',
      isDanger: true,
      icon: Icons.delete_outline,
    );
    if (!ok || !mounted) return;
    try {
      await _servicio.eliminar(widget.comunidadId);
      if (mounted) {
        _aviso('Comunidad eliminada');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) _aviso(mensajeDeError(e), error: true);
    }
  }

  // ==================== CÓDIGOS ====================

  Future<void> _generarCodigo() async {
    final datos = await showDialog<_DatosCodigo>(context: context, builder: (_) => const _GenerarCodigoDialog());
    if (datos == null || !mounted) return;
    try {
      final c = await _servicio.generarCodigo(widget.comunidadId,
          maxUsos: datos.maxUsos, expira: datos.expira, descripcion: datos.descripcion);
      if (mounted) {
        _aviso('Código ${c.codigo} generado');
        _cargar();
      }
    } catch (e) {
      if (mounted) _aviso(mensajeDeError(e), error: true);
    }
  }

  Future<void> _copiar(CodigoAcceso c) async {
    await Clipboard.setData(ClipboardData(text: c.codigo));
    if (mounted) _aviso('Código ${c.codigo} copiado. Compártelo con los apadrinados.');
  }

  Future<void> _desactivar(CodigoAcceso c) async {
    final ok = await showConfirmationDialog(
      context,
      title: 'Desactivar código',
      message: 'El código ${c.codigo} dejará de funcionar para nuevas incorporaciones.',
      confirmLabel: 'Desactivar',
      isDanger: true,
      icon: Icons.block,
    );
    if (!ok || !mounted) return;
    try {
      await _servicio.desactivarCodigo(c.id);
      if (mounted) _cargar();
    } catch (e) {
      if (mounted) _aviso(mensajeDeError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _comunidad;
    return Scaffold(
      appBar: AppBar(
        title: Text(c?.nombre ?? 'Comunidad'),
        actions: [
          if (c != null)
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'editar') _editar();
                if (v == 'historial') {
                  _abrir(HistorialScreen(comunidadId: c.id, titulo: 'Historial · ${c.nombre}'));
                }
                if (v == 'eliminar') _eliminar();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'editar', child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Editar datos'))),
                PopupMenuItem(value: 'historial', child: ListTile(leading: Icon(Icons.history), title: Text('Historial'))),
                PopupMenuItem(
                  value: 'eliminar',
                  child: ListTile(
                    leading: Icon(Icons.delete_outline, color: AppColors.coralRed),
                    title: Text('Eliminar', style: TextStyle(color: AppColors.coralRed)),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: _isLoading
          ? const LoadingState(message: 'Cargando comunidad...')
          : (c == null)
              ? ErrorState(title: 'No se pudo cargar la comunidad', message: _error, onRetry: _cargar)
              : DashboardLayout(
                  onRefresh: _cargar,
                  principal: [
                    _encabezado(c),
                    const SizedBox(height: AppSpacing.xl),
                    const SectionHeader(title: 'Incorporación', subtitle: 'Cómo ingresan los apadrinados con el código'),
                    const SizedBox(height: AppSpacing.sm),
                    SelectorModoIncorporacion(valor: c.modoIncorporacion, onChanged: _cambiarModo),
                    const SizedBox(height: AppSpacing.xl),
                    SectionHeader(
                      title: 'Códigos de acceso',
                      subtitle: 'Compártelos con los apadrinados de la comunidad',
                      action: TextButton.icon(
                        onPressed: _generarCodigo,
                        icon: const Icon(Icons.add),
                        label: const Text('Generar'),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (_codigos.isEmpty)
                      const EmptyState(
                        icon: Icons.key_outlined,
                        title: 'Sin códigos',
                        description: 'Genera un código para que los apadrinados se incorporen',
                      )
                    else
                      for (final codigo in _codigos)
                        _CodigoTile(
                          codigo: codigo,
                          onCopiar: () => _copiar(codigo),
                          onDesactivar: codigo.activo ? () => _desactivar(codigo) : null,
                        ),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                  secundario: [
                    const SectionHeader(title: 'Gestión', subtitle: 'Solicitudes, módulos y actividades'),
                    const SizedBox(height: AppSpacing.sm),
                    _Acceso(
                      icon: Icons.person_add_alt_1_outlined,
                      titulo: 'Solicitudes de incorporación',
                      detalle: _solicitudes == 0 ? 'Sin solicitudes pendientes' : '$_solicitudes pendiente(s)',
                      destacado: _solicitudes > 0,
                      onTap: () => _abrir(SolicitudesScreen(comunidadId: c.id)),
                    ),
                    _Acceso(
                      icon: Icons.view_module_outlined,
                      titulo: 'Módulos',
                      detalle: '${c.totalModulos ?? 0} módulo(s) · crear, renombrar y ordenar',
                      onTap: () => _abrir(ModulosScreen(comunidadId: c.id, comunidadNombre: c.nombre)),
                    ),
                    _Acceso(
                      icon: Icons.assignment_outlined,
                      titulo: 'Actividades',
                      detalle: 'Tablero de actividades de la comunidad',
                      onTap: () => _abrir(TableroActividadesScreen(comunidadId: c.id, titulo: 'Actividades · ${c.nombre}')),
                    ),
                    _Acceso(
                      icon: Icons.history,
                      titulo: 'Historial de cambios',
                      detalle: 'Quién hizo qué y cuándo',
                      onTap: () => _abrir(HistorialScreen(comunidadId: c.id, titulo: 'Historial · ${c.nombre}')),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    SectionHeader(title: 'Apadrinados', subtitle: '${_apadrinados.length} en la comunidad'),
                    const SizedBox(height: AppSpacing.sm),
                    if (_apadrinados.isEmpty)
                      const EmptyState(
                        icon: Icons.people_outline,
                        title: 'Sin apadrinados',
                        description: 'Se incorporan con el código de acceso',
                      )
                    else
                      for (final a in _apadrinados)
                        PersonCard(
                          nombre: a.nombreCompleto.isNotEmpty ? a.nombreCompleto : 'Apadrinado',
                          subtitle: a.correo ?? '',
                          detail: a.telefono,
                          onTap: () => _abrir(ExpedienteDetalleScreen(apadrinadoId: a.id)),
                        ),
                  ],
                ),
    );
  }

  Widget _encabezado(Comunidad c) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(color: AppColors.darkNavy, borderRadius: BorderRadius.circular(AppRadius.xl)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(c.nombre, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
          if (c.ubicacion.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(c.ubicacion, style: TextStyle(color: Colors.white.withAlpha(204))),
          ],
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.xl,
            runSpacing: AppSpacing.sm,
            children: [
              _Dato(valor: '${_apadrinados.length}', etiqueta: 'Apadrinados'),
              _Dato(valor: '${c.totalModulos ?? 0}', etiqueta: 'Módulos'),
              _Dato(valor: '${_codigos.where((x) => x.activo).length}', etiqueta: 'Códigos activos'),
              _Dato(valor: '$_solicitudes', etiqueta: 'Solicitudes'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  final String valor;
  final String etiqueta;

  const _Dato({required this.valor, required this.etiqueta});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(valor, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
        Text(etiqueta, style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 12)),
      ],
    );
  }
}

class _Acceso extends StatelessWidget {
  final IconData icon;
  final String titulo;
  final String detalle;
  final bool destacado;
  final VoidCallback onTap;

  const _Acceso({
    required this.icon,
    required this.titulo,
    required this.detalle,
    required this.onTap,
    this.destacado = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = destacado ? AppColors.coralRed : AppColors.darkNavy;
    return AppCard(
      onTap: onTap,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.charcoal)),
                Text(detalle, style: TextStyle(fontSize: 12, color: destacado ? color : AppColors.textSecondary)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textTertiary),
        ],
      ),
    );
  }
}

class _CodigoTile extends StatelessWidget {
  final CodigoAcceso codigo;
  final VoidCallback onCopiar;
  final VoidCallback? onDesactivar;

  const _CodigoTile({required this.codigo, required this.onCopiar, this.onDesactivar});

  @override
  Widget build(BuildContext context) {
    final c = codigo;
    final color = c.activo ? AppColors.sageGreen : AppColors.textTertiary;
    final detalles = <String>[
      c.maxUsos != null ? '${c.usos} de ${c.maxUsos} usos' : '${c.usos} usos',
      if (c.fechaExpiracion != null) 'vence ${AppDateUtils.formatDate(c.fechaExpiracion)}',
      if (c.descripcion != null && c.descripcion!.isNotEmpty) c.descripcion!,
    ];
    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Icon(Icons.key, color: color),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: SelectableText(
                        c.codigo,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                          color: c.activo ? AppColors.charcoal : AppColors.textTertiary,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withAlpha(26),
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: Text(c.activo ? 'Activo' : 'Inactivo',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
                    ),
                  ],
                ),
                Text(detalles.join(' · '), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          if (c.activo)
            IconButton(tooltip: 'Copiar', icon: const Icon(Icons.copy), onPressed: onCopiar),
          if (onDesactivar != null)
            IconButton(
              tooltip: 'Desactivar',
              icon: const Icon(Icons.block, color: AppColors.coralRed),
              onPressed: onDesactivar,
            ),
        ],
      ),
    );
  }
}

class _DatosCodigo {
  final int? maxUsos;
  final DateTime? expira;
  final String? descripcion;

  _DatosCodigo(this.maxUsos, this.expira, this.descripcion);
}

class _GenerarCodigoDialog extends StatefulWidget {
  const _GenerarCodigoDialog();

  @override
  State<_GenerarCodigoDialog> createState() => _GenerarCodigoDialogState();
}

class _GenerarCodigoDialogState extends State<_GenerarCodigoDialog> {
  final _usos = TextEditingController();
  final _descripcion = TextEditingController();
  DateTime? _expira;

  @override
  void dispose() {
    _usos.dispose();
    _descripcion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Generar código de acceso'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _usos,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Máximo de usos (opcional)',
                hintText: 'Sin límite',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _descripcion,
              decoration: const InputDecoration(labelText: 'Descripción (opcional)'),
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              icon: const Icon(Icons.event),
              label: Text(_expira == null ? 'Sin fecha de vencimiento' : 'Vence: ${AppDateUtils.formatShort(_expira!.toIso8601String())}'),
              onPressed: () async {
                final hoy = DateTime.now();
                final f = await showDatePicker(
                  context: context,
                  initialDate: hoy.add(const Duration(days: 90)),
                  firstDate: hoy,
                  lastDate: hoy.add(const Duration(days: 730)),
                );
                if (f != null) setState(() => _expira = DateTime(f.year, f.month, f.day, 23, 59));
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: () => Navigator.pop(
            context,
            _DatosCodigo(int.tryParse(_usos.text), _expira, _descripcion.text.trim().isEmpty ? null : _descripcion.text.trim()),
          ),
          child: const Text('Generar'),
        ),
      ],
    );
  }
}
