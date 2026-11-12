import 'package:flutter/material.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../services/actividad_service.dart';
import '../../services/comunidad_service.dart';
import '../../shared/models/actividad.dart';
import '../../shared/models/comunidad.dart';
import '../../shared/models/modulo.dart';
import '../../shared/widgets/actividad_widgets.dart';
import '../../shared/widgets/states.dart';
import '../comunidades/modulos_screen.dart';
import 'actividad_detalle_screen.dart';
import 'crear_actividad_screen.dart';

/// Tablero de actividades del coordinador: todas las actividades que ha
/// creado, filtrables por comunidad, módulo y tipo, con el avance de
/// cada tarea. Se usa como pestaña del shell (sin Scaffold).
class TableroActividadesContent extends StatefulWidget {
  final int? comunidadId;

  const TableroActividadesContent({super.key, this.comunidadId});

  @override
  State<TableroActividadesContent> createState() => _TableroActividadesContentState();
}

class _TableroActividadesContentState extends State<TableroActividadesContent> {
  final _actividadService = ActividadService();
  final _comunidadService = ComunidadService();

  List<Comunidad> _comunidades = [];
  List<Modulo> _modulos = [];
  List<Actividad> _actividades = [];
  int? _comunidadId;
  int? _moduloId;
  String? _tipo;
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _comunidadId = widget.comunidadId;
    _inicializar();
  }

  Future<void> _inicializar() async {
    try {
      _comunidades = await _comunidadService.listar();
      if (_comunidadId != null) {
        _modulos = await _comunidadService.modulos(_comunidadId!);
      }
    } catch (_) {
      // Los filtros son opcionales: el tablero se carga igual
    }
    await _cargar();
  }

  Future<void> _cargar() async {
    if (mounted) {
      setState(() {
        _cargando = _actividades.isEmpty;
        _error = null;
      });
    }
    try {
      final lista = await _actividadService.tablero(
        comunidadId: _comunidadId,
        moduloId: _moduloId,
        tipo: _tipo,
      );
      if (!mounted) return;
      setState(() {
        _actividades = lista;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = mensajeDeError(e);
        _cargando = false;
      });
    }
  }

  Future<void> _cambiarComunidad(int? id) async {
    setState(() {
      _comunidadId = id;
      _moduloId = null;
      _modulos = [];
    });
    if (id != null) {
      try {
        final modulos = await _comunidadService.modulos(id);
        if (mounted) setState(() => _modulos = modulos);
      } catch (_) {}
    }
    await _cargar();
  }

  Future<void> _nuevaActividad() async {
    final creada = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CrearActividadScreen(comunidadId: _comunidadId, moduloId: _moduloId),
      ),
    );
    if (creada == true) await _cargar();
  }

  Future<void> _abrirModulos() async {
    final comunidad = _comunidades.where((c) => c.id == _comunidadId).firstOrNull;
    if (comunidad == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ModulosScreen(comunidadId: comunidad.id, comunidadNombre: comunidad.nombre),
      ),
    );
    await _cambiarComunidad(_comunidadId);
  }

  Future<void> _abrirDetalle(Actividad a) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ActividadDetalleScreen(actividadId: a.id)),
    );
    await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final ancho = constraints.maxWidth;
        final padding = ancho >= 600 ? 24.0 : 16.0;
        final contenido = (ancho - padding * 2).clamp(0.0, 1100.0);
        final columnas = contenido >= 900 ? 2 : 1;

        return RefreshIndicator(
          onRefresh: _cargar,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: contenido,
                    child: Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.lg),
                      child: _filtros(contenido),
                    ),
                  ),
                ),
              ),
              ..._lista(contenido, columnas, padding),
              const SliverToBoxAdapter(child: SizedBox(height: 96)),
            ],
          ),
        );
      },
    );
  }

  Widget _filtros(double ancho) {
    final angosto = ancho < 560;
    final comunidad = DropdownButtonFormField<int?>(
      key: ValueKey('comunidad-$_comunidadId-${_comunidades.length}'),
      value: _comunidadId,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Comunidad',
        prefixIcon: Icon(Icons.location_city_outlined),
      ),
      items: [
        const DropdownMenuItem<int?>(value: null, child: Text('Todas mis comunidades')),
        ..._comunidades.map((c) => DropdownMenuItem<int?>(value: c.id, child: Text(c.nombre))),
      ],
      onChanged: _cambiarComunidad,
    );
    final modulo = DropdownButtonFormField<int?>(
      key: ValueKey('modulo-$_comunidadId-$_moduloId-${_modulos.length}'),
      value: _moduloId,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Módulo',
        prefixIcon: Icon(Icons.folder_outlined),
      ),
      items: [
        const DropdownMenuItem<int?>(value: null, child: Text('Todos los módulos')),
        ..._modulos.map((m) => DropdownMenuItem<int?>(value: m.id, child: Text(m.nombre))),
      ],
      onChanged: _comunidadId == null
          ? null
          : (v) {
              setState(() => _moduloId = v);
              _cargar();
            },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Tablero de actividades',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.charcoal),
              ),
            ),
            TextButton.icon(
              onPressed: _comunidadId == null ? null : _abrirModulos,
              icon: const Icon(Icons.view_module_outlined),
              label: const Text('Módulos'),
            ),
            const SizedBox(width: AppSpacing.sm),
            ElevatedButton.icon(
              onPressed: _nuevaActividad,
              icon: const Icon(Icons.add),
              label: Text(angosto ? 'Nueva' : 'Nueva actividad'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (angosto) ...[
          comunidad,
          const SizedBox(height: AppSpacing.md),
          modulo,
        ] else
          Row(
            children: [
              Expanded(child: comunidad),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: modulo),
            ],
          ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            _chipTipo(null, 'Todas'),
            for (final t in TipoActividad.todos) _chipTipo(t, TipoActividad.etiqueta(t)),
          ],
        ),
        if (_comunidadId == null && _comunidades.isNotEmpty)
          const Padding(
            padding: EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              'Seleccione una comunidad para filtrar por módulo y administrar sus módulos.',
              style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }

  Widget _chipTipo(String? tipo, String etiqueta) {
    final seleccionado = _tipo == tipo;
    return ChoiceChip(
      label: Text(etiqueta),
      avatar: tipo == null ? null : Icon(TipoActividadEstilo.icono(tipo), size: 16),
      selected: seleccionado,
      onSelected: (_) {
        setState(() => _tipo = tipo);
        _cargar();
      },
    );
  }

  List<Widget> _lista(double ancho, int columnas, double padding) {
    Widget centrado(Widget w) => SliverToBoxAdapter(
          child: Align(alignment: Alignment.topCenter, child: SizedBox(width: ancho, child: w)),
        );

    if (_cargando) {
      return [centrado(const Padding(padding: EdgeInsets.only(top: 48), child: LoadingState()))];
    }
    if (_error != null) {
      return [
        centrado(ErrorState(title: 'No se pudo cargar el tablero', message: _error, onRetry: _cargar)),
      ];
    }
    if (_actividades.isEmpty) {
      return [
        centrado(EmptyState(
          icon: Icons.assignment_outlined,
          title: 'Sin actividades',
          description: 'Cree una tarea, un anuncio o material de apoyo para sus apadrinados.',
          action: ElevatedButton.icon(
            onPressed: _nuevaActividad,
            icon: const Icon(Icons.add),
            label: const Text('Nueva actividad'),
          ),
        )),
      ];
    }

    // Las tarjetas traen su propio margen horizontal: se compensa para
    // que queden alineadas con los filtros.
    final tarjetas = [
      for (final a in _actividades)
        ActividadTableroCard(actividad: a, onTap: () => _abrirDetalle(a)),
    ];
    if (columnas == 1) {
      return [
        SliverList.list(
          children: [
            for (final t in tarjetas)
              Align(
                alignment: Alignment.topCenter,
                child: SizedBox(width: ancho + 32, child: t),
              ),
          ],
        ),
      ];
    }
    final filas = <Widget>[];
    for (var i = 0; i < tarjetas.length; i += 2) {
      filas.add(Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: ancho + 32,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: tarjetas[i]),
              Expanded(child: i + 1 < tarjetas.length ? tarjetas[i + 1] : const SizedBox()),
            ],
          ),
        ),
      ));
    }
    return [SliverList.list(children: filas)];
  }
}

/// Tablero como pantalla independiente (ej. desde una comunidad).
class TableroActividadesScreen extends StatelessWidget {
  final int? comunidadId;
  final String? titulo;

  const TableroActividadesScreen({super.key, this.comunidadId, this.titulo});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(titulo ?? 'Actividades')),
      body: TableroActividadesContent(comunidadId: comunidadId),
    );
  }
}
