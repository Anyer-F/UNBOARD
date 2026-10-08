import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../shared/models/actividad.dart';
import '../../shared/models/apadrinado.dart';
import '../../shared/models/comunidad.dart';
import '../../services/actividad_service.dart';
import '../../services/auth_service.dart';
import '../../services/documento_service.dart';
import '../../services/expediente_service.dart';
import '../../../core/theme/app_theme.dart';

class CrearActividadScreen extends StatefulWidget {
  final Actividad? actividadParaEditar;
  final Comunidad? comunidad;

  const CrearActividadScreen({
    super.key,
    this.actividadParaEditar,
    this.comunidad,
  });

  @override
  State<CrearActividadScreen> createState() => _CrearActividadScreenState();
}

class _CrearActividadScreenState extends State<CrearActividadScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tituloController = TextEditingController();
  final _descripcionController = TextEditingController();
  DateTime? _fechaLimite;
  bool _requiereFotografia = false;
  bool _requiereDocumento = true;

  final _actividadService = ActividadService();
  final _expedienteService = ExpedienteService();
  final _documentoService = DocumentoService();

  List<Comunidad> _comunidades = [];
  int? _comunidadSeleccionadaId;
  List<Apadrinado> _apadrinadosComunidad = [];
  final Set<int> _apadrinadosSeleccionados = {};

  bool _isLoading = false;
  bool _cargandoApadrinados = true;
  bool _subiendoArchivo = false;
  Uint8List? _archivoBytes;
  String? _archivoNombre;

  @override
  void initState() {
    super.initState();
    if (widget.actividadParaEditar != null) {
      final act = widget.actividadParaEditar!;
      _tituloController.text = act.titulo;
      _descripcionController.text = act.descripcion ?? '';
      _requiereFotografia = act.requiereFotografia;
      _requiereDocumento = act.requiereDocumento;
      if (act.fechaLimite != null) {
        try {
          _fechaLimite = DateTime.parse(act.fechaLimite!);
        } catch (_) {}
      }
      _cargandoApadrinados = false;
    } else {
      _cargarComunidades();
    }
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _descripcionController.dispose();
    super.dispose();
  }

  Future<void> _cargarComunidades() async {
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    if (user?.coordinadorId == null) {
      setState(() => _cargandoApadrinados = false);
      return;
    }
    try {
      final lista = await _expedienteService.listarMisComunidades();
      final preseleccionada =
          widget.comunidad ?? (lista.isNotEmpty ? lista.first : null);
      setState(() {
        _comunidades = lista;
        _comunidadSeleccionadaId = preseleccionada?.id;
        _cargandoApadrinados = false;
      });
      if (preseleccionada != null) {
        await _cargarApadrinadosDeComunidad(preseleccionada.id);
      }
    } catch (_) {
      setState(() => _cargandoApadrinados = false);
    }
  }

  Future<void> _cargarApadrinadosDeComunidad(int comunidadId) async {
    final user =
        Provider.of<AuthService>(context, listen: false).currentUser;
    if (user?.coordinadorId == null) return;
    try {
      final todos = await _expedienteService
          .listarApadrinadosPorCoordinador(user!.coordinadorId!);
      final filtrados =
          todos.where((a) => a.comunidadId == comunidadId).toList();
      setState(() {
        _apadrinadosComunidad = filtrados;
        _apadrinadosSeleccionados
          ..clear()
          ..addAll(filtrados.map((a) => a.id));
      });
    } catch (_) {}
  }

  Future<void> _seleccionarArchivo() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.any,
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          _archivoBytes = file.bytes;
          _archivoNombre = file.name;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al seleccionar archivo: $e'),
            backgroundColor: AppColors.coralRed,
          ),
        );
      }
    }
  }

  Future<void> _subirArchivo(int actividadId) async {
    if (_archivoBytes == null || _archivoNombre == null) return;

    setState(() => _subiendoArchivo = true);
    try {
      final user = Provider.of<AuthService>(context, listen: false).currentUser;
      await _documentoService.subirDocumento(
        fileBytes: _archivoBytes!,
        filename: _archivoNombre!,
        actividadId: actividadId,
        tipoDocumento: 'OTRO',
        descripcion: 'Material de apoyo para la actividad',
        usuarioId: user?.usuarioId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Archivo de apoyo subido exitosamente'),
            backgroundColor: AppColors.sageGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al subir archivo: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: AppColors.coralRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _subiendoArchivo = false);
    }
  }

  Future<void> _seleccionarFecha() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 15)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.darkNavy,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _fechaLimite = picked;
      });
    }
  }

  Future<void> _guardarActividad() async {
    if (!_formKey.currentState!.validate()) return;
    if (_fechaLimite == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor selecciona una fecha límite.'),
          backgroundColor: AppColors.coralRed,
        ),
      );
      return;
    }

    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    final coordId = user?.coordinadorId;
    final esEdicion = widget.actividadParaEditar != null;

    setState(() => _isLoading = true);

    try {
      final fechaStr = DateFormat('yyyy-MM-dd').format(_fechaLimite!);

      int? actividadId;

      if (esEdicion) {
        await _actividadService.actualizar(widget.actividadParaEditar!.id, {
          'titulo': _tituloController.text.trim(),
          'descripcion': _descripcionController.text.trim(),
          'fechaLimite': fechaStr,
          'requiereFotografia': _requiereFotografia,
          'requiereDocumento': _requiereDocumento,
        });
        actividadId = widget.actividadParaEditar!.id;
      } else {
        final seleccionados = _apadrinadosSeleccionados.toList();
        if (seleccionados.isEmpty) {
          setState(() => _isLoading = false);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Selecciona al menos un apadrinado.'),
              backgroundColor: AppColors.coralRed,
            ),
          );
          return;
        }

        final payload = {
          'titulo': _tituloController.text.trim(),
          'descripcion': _descripcionController.text.trim(),
          'fechaLimite': fechaStr,
          'requiereFotografia': _requiereFotografia,
          'requiereDocumento': _requiereDocumento,
          'coordinadorId': coordId,
        };

        if (seleccionados.length == 1) {
          final actividad = await _actividadService.crear({
            ...payload,
            'apadrinadoId': seleccionados.first,
          });
          actividadId = actividad.id;
        } else {
          final actividades = await _actividadService.crearMasiva({
            ...payload,
            'apadrinadoIds': seleccionados,
          });
          if (actividades.isNotEmpty) {
            actividadId = actividades.first.id;
          }
        }
      }

      // Subir archivo de apoyo si se seleccionó
      if (actividadId != null && _archivoBytes != null) {
        await _subirArchivo(actividadId);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(esEdicion
              ? '¡Actividad actualizada exitosamente!'
              : '¡Actividad creada y notificada exitosamente!'),
          backgroundColor: AppColors.sageGreen,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: AppColors.coralRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final esEdicion = widget.actividadParaEditar != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(esEdicion ? 'Editar Actividad' : 'Nueva Actividad'),
      ),
      body: _cargandoApadrinados
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Información de la Actividad',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkNavy,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _tituloController,
                      decoration: const InputDecoration(
                        labelText: 'Título de la actividad *',
                        hintText: 'Ej: Carta anual para el padrino',
                        prefixIcon: Icon(Icons.assignment, color: AppColors.darkNavy),
                      ),
                      validator: (val) =>
                          (val == null || val.trim().isEmpty) ? 'El título es obligatorio' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _descripcionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Instrucciones para el apadrinado',
                        hintText: 'Indica detalladamente qué debe redactar o adjuntar...',
                        alignLabelWithHint: true,
                        prefixIcon: Icon(Icons.description, color: AppColors.darkNavy),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Selector de Fecha Límite
                    InkWell(
                      onTap: _seleccionarFecha,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.borderLight),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, color: AppColors.tealCyan),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Fecha límite de entrega *',
                                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                  ),
                                  Text(
                                    _fechaLimite == null
                                        ? 'Selecciona una fecha'
                                        : DateFormat('dd/MM/yyyy').format(_fechaLimite!),
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: _fechaLimite == null ? Colors.grey : AppColors.charcoal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Requisitos documentales
                    const Text(
                      'Requisitos solicitados:',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.darkNavy),
                    ),
                    const SizedBox(height: 6),
                    Card(
                      child: Column(
                        children: [
                          CheckboxListTile(
                            activeColor: AppColors.darkNavy,
                            secondary: const Icon(Icons.camera_alt, color: AppColors.coralRed),
                            title: const Text('Requiere Fotografía'),
                            subtitle: const Text('El apadrinado deberá subir al menos una foto de evidencia.'),
                            value: _requiereFotografia,
                            onChanged: (val) => setState(() => _requiereFotografia = val ?? false),
                          ),
                          const Divider(height: 1),
                          CheckboxListTile(
                            activeColor: AppColors.darkNavy,
                            secondary: const Icon(Icons.description, color: AppColors.tealCyan),
                            title: const Text('Requiere Carta o Documento'),
                            subtitle: const Text('El apadrinado deberá redactar o adjuntar un PDF/archivo.'),
                            value: _requiereDocumento,
                            onChanged: (val) => setState(() => _requiereDocumento = val ?? false),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Material de apoyo (archivo adjunto)
                    const Text(
                      'Material de apoyo para el apadrinado:',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.darkNavy),
                    ),
                    const SizedBox(height: 6),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Adjunta un archivo (PDF, imagen, etc.) que el apadrinado necesite para completar la actividad.',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.darkNavy,
                                      side: const BorderSide(color: AppColors.darkNavy),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                    onPressed: _subiendoArchivo ? null : _seleccionarArchivo,
                                    icon: const Icon(Icons.attach_file, size: 18),
                                    label: const Text('Seleccionar archivo'),
                                  ),
                                ),
                                if (_archivoNombre != null) ...[
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Chip(
                                      avatar: const Icon(Icons.insert_drive_file, size: 16, color: AppColors.darkNavy),
                                      label: Text(
                                        _archivoNombre!,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      deleteIcon: const Icon(Icons.close, size: 16),
                                      onDeleted: () => setState(() {
                                        _archivoBytes = null;
                                        _archivoNombre = null;
                                      }),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (_subiendoArchivo) ...[
                              const SizedBox(height: 8),
                              const LinearProgressIndicator(),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Asignación (solo en creación nueva)
                    if (!esEdicion) ...[
                      const Text(
                        'Asignar a una comunidad:',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.darkNavy),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<int>(
                        value: _comunidadSeleccionadaId,
                        hint: const Text('Selecciona una comunidad'),
                        decoration: const InputDecoration(
                          labelText: 'Comunidad',
                          prefixIcon: Icon(Icons.groups, color: AppColors.darkNavy),
                        ),
                        items: _comunidades.map((c) {
                          return DropdownMenuItem<int>(
                            value: c.id,
                            child: Text(c.nombre),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() => _comunidadSeleccionadaId = val);
                          if (val != null) {
                            _cargarApadrinadosDeComunidad(val);
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      if (_apadrinadosComunidad.isNotEmpty) ...[
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            child: Column(
                              children: [
                                CheckboxListTile(
                                  activeColor: AppColors.darkNavy,
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                  title: const Text(
                                      'Seleccionar a todos los apadrinados'),
                                  value: _apadrinadosSeleccionados.length ==
                                      _apadrinadosComunidad.length,
                                  onChanged: (val) {
                                    setState(() {
                                      if (val == true) {
                                        _apadrinadosSeleccionados.addAll(
                                            _apadrinadosComunidad
                                                .map((a) => a.id));
                                      } else {
                                        _apadrinadosSeleccionados.clear();
                                      }
                                    });
                                  },
                                ),
                                const Divider(height: 1),
                                ..._apadrinadosComunidad.map(
                                  (ap) => CheckboxListTile(
                                    activeColor: AppColors.darkNavy,
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                    title: Text(ap.nombre ?? 'Apadrinado'),
                                    subtitle:
                                        Text(ap.correo ?? ''),
                                    value: _apadrinadosSeleccionados
                                        .contains(ap.id),
                                    onChanged: (val) {
                                      setState(() {
                                        if (val == true) {
                                          _apadrinadosSeleccionados
                                              .add(ap.id);
                                        } else {
                                          _apadrinadosSeleccionados
                                              .remove(ap.id);
                                        }
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ] else
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'No hay apadrinados en esta comunidad',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                    ],

                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: esEdicion ? AppColors.tealCyan : AppColors.darkNavy,
                        ),
                        onPressed: _isLoading ? null : _guardarActividad,
                        icon: _isLoading
                            ? const SizedBox.shrink()
                            : Icon(esEdicion ? Icons.save : Icons.send_rounded),
                        label: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text(esEdicion ? 'Guardar Cambios' : 'Crear y Notificar Actividad'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
