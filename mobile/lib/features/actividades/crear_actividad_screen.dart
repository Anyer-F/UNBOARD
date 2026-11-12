import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_radius.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../services/actividad_service.dart';
import '../../services/comunidad_service.dart';
import '../../shared/models/actividad.dart';
import '../../shared/models/apadrinado.dart';
import '../../shared/models/comunidad.dart';
import '../../shared/models/documento.dart';
import '../../shared/models/modulo.dart';
import '../../shared/widgets/actividad_widgets.dart';
import '../../shared/widgets/confirmation_dialog.dart';
import '../../shared/widgets/states.dart';

/// Archivo elegido en el dispositivo, pendiente de subir.
class _ArchivoNuevo {
  final String nombre;
  final Uint8List bytes;

  _ArchivoNuevo(this.nombre, this.bytes);
}

/// Crear o editar una actividad (Tarea, Anuncio o Material de apoyo)
/// dentro de un módulo de una comunidad. Devuelve `true` al guardar.
class CrearActividadScreen extends StatefulWidget {
  /// Si se indica, edita esa actividad.
  final int? actividadId;
  final int? comunidadId;
  final int? moduloId;

  const CrearActividadScreen({super.key, this.actividadId, this.comunidadId, this.moduloId});

  @override
  State<CrearActividadScreen> createState() => _CrearActividadScreenState();
}

class _CrearActividadScreenState extends State<CrearActividadScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titulo = TextEditingController();
  final _descripcion = TextEditingController();
  final _instrucciones = TextEditingController();
  final _otrosRequisitos = TextEditingController();

  final _actividadService = ActividadService();
  final _comunidadService = ComunidadService();

  bool get _esEdicion => widget.actividadId != null;

  Actividad? _original;
  String _tipo = TipoActividad.tarea;
  List<Comunidad> _comunidades = [];
  int? _comunidadId;
  List<Modulo> _modulos = [];
  int? _moduloId;
  DateTime? _fechaLimite;
  bool _requiereDocumento = false;
  bool _requiereFotografia = false;
  bool _requiereCarta = false;
  bool _toda = true;
  List<Apadrinado> _apadrinados = [];
  final Set<int> _seleccionados = {};
  List<Documento> _adjuntos = [];
  final List<_ArchivoNuevo> _nuevos = [];

  bool _cargando = true;
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _titulo.dispose();
    _descripcion.dispose();
    _instrucciones.dispose();
    _otrosRequisitos.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      if (_esEdicion) {
        final detalle = await _actividadService.detalle(widget.actividadId!);
        final a = detalle.actividad;
        _original = a;
        _tipo = a.tipo;
        _titulo.text = a.titulo;
        _descripcion.text = a.descripcion ?? '';
        _instrucciones.text = a.instrucciones ?? '';
        _otrosRequisitos.text = a.otrosRequisitos ?? '';
        _fechaLimite = a.fechaLimite != null ? DateTime.tryParse(a.fechaLimite!) : null;
        _requiereDocumento = a.requiereDocumento;
        _requiereFotografia = a.requiereFotografia;
        _requiereCarta = a.requiereCarta;
        _toda = a.asignadaAComunidad;
        _adjuntos = List.of(a.adjuntos);
        _seleccionados
          ..clear()
          ..addAll(detalle.asignaciones.map((s) => s.apadrinadoId).whereType<int>());
        _comunidadId = a.comunidadId;
        _moduloId = a.moduloId;
      } else {
        _comunidades = await _comunidadService.listar();
        _comunidadId = widget.comunidadId ??
            (_comunidades.isNotEmpty ? _comunidades.first.id : null);
        _moduloId = widget.moduloId;
      }
      if (_comunidadId != null) await _cargarComunidad(_comunidadId!, conservarSeleccion: _esEdicion);
      if (mounted) setState(() => _cargando = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = mensajeDeError(e);
          _cargando = false;
        });
      }
    }
  }

  /// Módulos y apadrinados de la comunidad seleccionada.
  Future<void> _cargarComunidad(int comunidadId, {bool conservarSeleccion = false}) async {
    final resultados = await Future.wait([
      _comunidadService.modulos(comunidadId),
      _comunidadService.apadrinados(comunidadId),
    ]);
    final modulos = resultados[0] as List<Modulo>;
    final apadrinados = resultados[1] as List<Apadrinado>;
    if (!mounted) return;
    setState(() {
      _modulos = modulos;
      _apadrinados = apadrinados;
      if (_moduloId != null && !modulos.any((m) => m.id == _moduloId)) _moduloId = null;
      if (_moduloId == null && modulos.length == 1) _moduloId = modulos.first.id;
      if (!conservarSeleccion) {
        _seleccionados
          ..clear()
          ..addAll(apadrinados.map((a) => a.id));
      }
    });
  }

  Future<void> _cambiarComunidad(int? id) async {
    if (id == null || id == _comunidadId) return;
    setState(() {
      _comunidadId = id;
      _moduloId = null;
      _modulos = [];
      _apadrinados = [];
    });
    try {
      await _cargarComunidad(id);
    } catch (e) {
      _mostrar(mensajeDeError(e), error: true);
    }
  }

  void _mostrar(String mensaje, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(mensaje),
      backgroundColor: error ? AppColors.coralRed : AppColors.sageGreen,
    ));
  }

  // ==================== ARCHIVOS ====================

  Future<void> _elegirArchivos() async {
    try {
      final result = await FilePicker.pickFiles(allowMultiple: true, withData: true, type: FileType.any);
      if (result == null) return;
      setState(() {
        for (final f in result.files) {
          if (f.bytes != null) _nuevos.add(_ArchivoNuevo(f.name, f.bytes!));
        }
      });
    } catch (e) {
      _mostrar('No se pudo seleccionar el archivo: ${mensajeDeError(e)}', error: true);
    }
  }

  Future<void> _elegirFoto(ImageSource fuente) async {
    try {
      final foto = await ImagePicker().pickImage(source: fuente, imageQuality: 85, maxWidth: 2048);
      if (foto == null) return;
      final bytes = await foto.readAsBytes();
      setState(() => _nuevos.add(_ArchivoNuevo(foto.name, bytes)));
    } catch (e) {
      _mostrar('No se pudo obtener la fotografía: ${mensajeDeError(e)}', error: true);
    }
  }

  Future<void> _quitarAdjunto(Documento doc) async {
    final ok = await showConfirmationDialog(
      context,
      title: 'Quitar archivo',
      message: '¿Quitar "${doc.nombreOriginal}" de la actividad?',
      confirmLabel: 'Quitar',
      isDanger: true,
    );
    if (!ok) return;
    try {
      await _actividadService.eliminarAdjunto(widget.actividadId!, doc.id);
      setState(() => _adjuntos.removeWhere((d) => d.id == doc.id));
    } catch (e) {
      _mostrar(mensajeDeError(e), error: true);
    }
  }

  // ==================== GUARDAR ====================

  Future<void> _seleccionarFecha() async {
    final hoy = DateTime.now();
    final inicial = _fechaLimite ?? hoy.add(const Duration(days: 7));
    final elegida = await showDatePicker(
      context: context,
      initialDate: inicial.isBefore(hoy) ? hoy : inicial,
      firstDate: DateTime(hoy.year, hoy.month, hoy.day),
      lastDate: hoy.add(const Duration(days: 730)),
    );
    if (elegida != null) setState(() => _fechaLimite = elegida);
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_comunidadId == null) {
      _mostrar('Seleccione la comunidad de la actividad.', error: true);
      return;
    }
    if (_modulos.length > 1 && _moduloId == null) {
      _mostrar('Seleccione el módulo de la actividad.', error: true);
      return;
    }
    final esTarea = _tipo == TipoActividad.tarea;
    if (esTarea && _fechaLimite == null) {
      _mostrar('Las tareas requieren una fecha límite.', error: true);
      return;
    }
    if (!_toda && _seleccionados.isEmpty) {
      _mostrar('Seleccione al menos un apadrinado o asigne la actividad a toda la comunidad.', error: true);
      return;
    }

    final datos = <String, dynamic>{
      'tipo': _tipo,
      'titulo': _titulo.text.trim(),
      'descripcion': _descripcion.text.trim(),
      'instrucciones': _instrucciones.text.trim(),
      'comunidadId': _comunidadId,
      if (_moduloId != null) 'moduloId': _moduloId,
      'asignarAComunidad': _toda,
      'apadrinadoIds': _toda ? <int>[] : _seleccionados.toList(),
      if (esTarea) ...{
        'fechaLimite': AppDateUtils.toApiDate(_fechaLimite!),
        'requiereDocumento': _requiereDocumento,
        'requiereFotografia': _requiereFotografia,
        'requiereCarta': _requiereCarta,
        'otrosRequisitos': _otrosRequisitos.text.trim(),
      },
    };

    setState(() => _guardando = true);
    try {
      final Actividad actividad = _esEdicion
          ? await _actividadService.actualizar(widget.actividadId!, datos)
          : await _actividadService.crear(datos);

      final fallidos = <String>[];
      for (final archivo in _nuevos) {
        try {
          await _actividadService.subirAdjunto(actividad.id, archivo.bytes, archivo.nombre);
        } catch (_) {
          fallidos.add(archivo.nombre);
        }
      }
      if (!mounted) return;
      if (fallidos.isNotEmpty) {
        _mostrar('La actividad se guardó, pero no se subieron: ${fallidos.join(', ')}', error: true);
      } else {
        _mostrar(_esEdicion ? 'Actividad actualizada' : 'Actividad creada y asignada');
      }
      Navigator.pop(context, true);
    } catch (e) {
      _mostrar(mensajeDeError(e), error: true);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  // ==================== INTERFAZ ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_esEdicion ? 'Editar actividad' : 'Nueva actividad')),
      body: _cargando
          ? const LoadingState(message: 'Cargando...')
          : _error != null
              ? ErrorState(title: 'No se pudo cargar el formulario', message: _error, onRetry: () {
                  setState(() {
                    _cargando = true;
                    _error = null;
                  });
                  _cargar();
                })
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                    children: [
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 760),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _seccionTipo(),
                                _seccionUbicacion(),
                                _seccionDatos(),
                                if (_tipo == TipoActividad.tarea) _seccionEntrega(),
                                _seccionArchivos(),
                                _seccionAsignacion(),
                                const SizedBox(height: AppSpacing.lg),
                                SizedBox(
                                  height: 50,
                                  child: ElevatedButton.icon(
                                    onPressed: _guardando ? null : _guardar,
                                    icon: _guardando
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                          )
                                        : const Icon(Icons.check),
                                    label: Text(_esEdicion ? 'Guardar cambios' : 'Crear y asignar'),
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xl),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _seccion(String titulo, List<Widget> hijos, {String? ayuda}) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(titulo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.charcoal)),
          if (ayuda != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(ayuda, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
          const SizedBox(height: AppSpacing.md),
          ...hijos,
        ],
      ),
    );
  }

  Widget _seccionTipo() {
    return _seccion(
      'Tipo de actividad',
      [
        SegmentedButton<String>(
          segments: [
            for (final t in TipoActividad.todos)
              ButtonSegment(
                value: t,
                label: Text(TipoActividad.etiqueta(t), overflow: TextOverflow.ellipsis),
                icon: Icon(TipoActividadEstilo.icono(t)),
              ),
          ],
          selected: {_tipo},
          showSelectedIcon: false,
          onSelectionChanged: _esEdicion ? null : (s) => setState(() => _tipo = s.first),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          switch (_tipo) {
            TipoActividad.anuncio => 'Información para los apadrinados. No requiere entrega ni aprobación.',
            TipoActividad.material => 'Archivos de apoyo que los apadrinados pueden consultar y descargar.',
            _ => 'Requiere una entrega del apadrinado que usted revisará y aprobará.',
          },
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        if (_esEdicion)
          const Padding(
            padding: EdgeInsets.only(top: AppSpacing.xs),
            child: Text('El tipo no se puede cambiar después de crear la actividad.',
                style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
          ),
      ],
    );
  }

  Widget _seccionUbicacion() {
    return _seccion(
      'Comunidad y módulo',
      [
        if (_esEdicion)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.location_city_outlined),
            title: Text(_original?.comunidadNombre ?? 'Comunidad'),
            subtitle: const Text('La comunidad no se puede cambiar'),
          )
        else
          DropdownButtonFormField<int>(
            value: _comunidadId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Comunidad', prefixIcon: Icon(Icons.location_city_outlined)),
            items: _comunidades.map((c) => DropdownMenuItem(value: c.id, child: Text(c.nombre))).toList(),
            onChanged: _cambiarComunidad,
            validator: (v) => v == null ? 'Seleccione la comunidad' : null,
          ),
        if (_modulos.length > 1) ...[
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<int>(
            key: ValueKey('modulo-$_comunidadId'),
            value: _moduloId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Módulo', prefixIcon: Icon(Icons.folder_outlined)),
            items: _modulos.map((m) => DropdownMenuItem(value: m.id, child: Text(m.nombre))).toList(),
            onChanged: (v) => setState(() => _moduloId = v),
            validator: (v) => v == null ? 'Seleccione el módulo' : null,
          ),
        ] else if (_modulos.length == 1)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text('Se guardará en ${_modulos.first.nombre} (único módulo de la comunidad).',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ),
      ],
    );
  }

  Widget _seccionDatos() {
    return _seccion('Información', [
      TextFormField(
        controller: _titulo,
        maxLength: 150,
        decoration: const InputDecoration(labelText: 'Nombre', prefixIcon: Icon(Icons.title)),
        validator: (v) => v == null || v.trim().isEmpty ? 'Ingrese el nombre de la actividad' : null,
      ),
      const SizedBox(height: AppSpacing.sm),
      TextFormField(
        controller: _descripcion,
        maxLines: 3,
        decoration: const InputDecoration(labelText: 'Descripción', alignLabelWithHint: true),
      ),
      const SizedBox(height: AppSpacing.md),
      TextFormField(
        controller: _instrucciones,
        maxLines: 4,
        decoration: const InputDecoration(labelText: 'Instrucciones', alignLabelWithHint: true),
      ),
    ]);
  }

  Widget _seccionEntrega() {
    return _seccion(
      'Entrega',
      [
        InkWell(
          onTap: _seleccionarFecha,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: InputDecorator(
            decoration: const InputDecoration(labelText: 'Fecha límite', prefixIcon: Icon(Icons.event_outlined)),
            child: Text(
              _fechaLimite != null ? AppDateUtils.formatDate(AppDateUtils.toApiDate(_fechaLimite!)) : 'Seleccionar fecha',
              style: TextStyle(color: _fechaLimite != null ? AppColors.charcoal : AppColors.textTertiary),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const Text('Requisitos de entrega', style: TextStyle(fontWeight: FontWeight.w600)),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _requiereDocumento,
          onChanged: (v) => setState(() => _requiereDocumento = v ?? false),
          title: const Text('Documentos'),
          secondary: const Icon(Icons.description_outlined),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _requiereFotografia,
          onChanged: (v) => setState(() => _requiereFotografia = v ?? false),
          title: const Text('Fotografías'),
          secondary: const Icon(Icons.photo_camera_outlined),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _requiereCarta,
          onChanged: (v) => setState(() => _requiereCarta = v ?? false),
          title: const Text('Carta'),
          secondary: const Icon(Icons.mail_outline),
        ),
        TextFormField(
          controller: _otrosRequisitos,
          decoration: const InputDecoration(
            labelText: 'Otros contenidos requeridos (opcional)',
            hintText: 'Ej. Evidencia de asistencia firmada',
          ),
        ),
      ],
    );
  }

  Widget _seccionArchivos() {
    return _seccion(
      _tipo == TipoActividad.material ? 'Material de apoyo' : 'Contenido de la actividad',
      [
        for (final d in _adjuntos)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(d.isImage ? Icons.image_outlined : Icons.insert_drive_file_outlined),
            title: Text(d.nombreOriginal, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(d.tamanioTexto),
            trailing: IconButton(
              tooltip: 'Quitar',
              icon: const Icon(Icons.delete_outline, color: AppColors.coralRed),
              onPressed: () => _quitarAdjunto(d),
            ),
          ),
        for (final n in _nuevos)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.upload_file_outlined, color: AppColors.tealCyan),
            title: Text(n.nombre, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: const Text('Se subirá al guardar'),
            trailing: IconButton(
              tooltip: 'Quitar',
              icon: const Icon(Icons.close),
              onPressed: () => setState(() => _nuevos.remove(n)),
            ),
          ),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            OutlinedButton.icon(
              onPressed: _elegirArchivos,
              icon: const Icon(Icons.attach_file),
              label: const Text('Documentos'),
            ),
            OutlinedButton.icon(
              onPressed: () => _elegirFoto(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Galería'),
            ),
            OutlinedButton.icon(
              onPressed: () => _elegirFoto(ImageSource.camera),
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Cámara'),
            ),
          ],
        ),
      ],
      ayuda: 'Documentos, formularios, imágenes o material educativo que los apadrinados podrán consultar.',
    );
  }

  Widget _seccionAsignacion() {
    return _seccion(
      'Asignación',
      [
        RadioListTile<bool>(
          contentPadding: EdgeInsets.zero,
          value: true,
          groupValue: _toda,
          onChanged: (v) => setState(() => _toda = v ?? true),
          title: const Text('Toda la comunidad'),
          subtitle: Text('${_apadrinados.length} apadrinado(s); también la recibirán quienes se incorporen después.'),
        ),
        RadioListTile<bool>(
          contentPadding: EdgeInsets.zero,
          value: false,
          groupValue: _toda,
          onChanged: (v) => setState(() => _toda = v ?? false),
          title: const Text('Apadrinados seleccionados'),
        ),
        if (!_toda) ...[
          if (_apadrinados.isEmpty)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.sm),
              child: Text('La comunidad aún no tiene apadrinados.', style: TextStyle(color: AppColors.textSecondary)),
            )
          else ...[
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _seleccionados.length == _apadrinados.length,
              tristate: false,
              onChanged: (v) => setState(() {
                _seleccionados.clear();
                if (v == true) _seleccionados.addAll(_apadrinados.map((a) => a.id));
              }),
              title: Text('Seleccionar todos (${_seleccionados.length} de ${_apadrinados.length})',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            const Divider(height: 1),
            for (final a in _apadrinados)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _seleccionados.contains(a.id),
                onChanged: (v) => setState(() {
                  if (v == true) {
                    _seleccionados.add(a.id);
                  } else {
                    _seleccionados.remove(a.id);
                  }
                }),
                title: Text(a.nombreCompleto.isNotEmpty ? a.nombreCompleto : (a.nombre ?? 'Apadrinado')),
                subtitle: a.correo != null ? Text(a.correo!) : null,
              ),
          ],
        ],
        if (_esEdicion)
          const Padding(
            padding: EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              'Los apadrinados asignados serán notificados de los cambios. No se puede quitar '
              'a quien ya realizó una entrega.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
      ],
    );
  }
}
