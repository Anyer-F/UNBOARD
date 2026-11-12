import 'package:flutter/material.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../services/expediente_service.dart';
import '../../shared/models/apadrinado.dart';
import '../../shared/widgets/cards.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../shared/widgets/states.dart';
import '../expediente/expediente_detalle_screen.dart';

/// Apadrinados de las comunidades del Coordinador. Cada uno abre su
/// expediente digital.
class ApadrinadosListScreen extends StatefulWidget {
  final bool embedded;

  const ApadrinadosListScreen({super.key, this.embedded = false});

  @override
  State<ApadrinadosListScreen> createState() => _ApadrinadosListScreenState();
}

class _ApadrinadosListScreenState extends State<ApadrinadosListScreen> {
  final _servicio = ExpedienteService();
  final _busqueda = TextEditingController();

  List<Apadrinado> _apadrinados = [];
  bool _isLoading = true;
  String? _error;
  String? _comunidad;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _isLoading = _apadrinados.isEmpty;
      _error = null;
    });
    try {
      final lista = await _servicio.apadrinados();
      lista.sort((a, b) => a.nombreCompleto.toLowerCase().compareTo(b.nombreCompleto.toLowerCase()));
      if (mounted) {
        setState(() {
          _apadrinados = lista;
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

  List<String> get _comunidades =>
      _apadrinados.map((a) => a.comunidadNombre).whereType<String>().toSet().toList()..sort();

  List<Apadrinado> get _filtrados {
    final q = _busqueda.text.trim().toLowerCase();
    return _apadrinados.where((a) {
      final coincide = q.isEmpty ||
          a.nombreCompleto.toLowerCase().contains(q) ||
          (a.correo ?? '').toLowerCase().contains(q) ||
          (a.comunidadNombre ?? '').toLowerCase().contains(q);
      return coincide && (_comunidad == null || a.comunidadNombre == _comunidad);
    }).toList();
  }

  Future<void> _abrir(Apadrinado a) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ExpedienteDetalleScreen(apadrinadoId: a.id)),
    );
  }

  Widget _contenido() {
    if (_isLoading) return const LoadingState(message: 'Cargando apadrinados...');
    if (_error != null && _apadrinados.isEmpty) {
      return ErrorState(title: 'No se pudieron cargar los apadrinados', message: _error, onRetry: _cargar);
    }
    final lista = _filtrados;
    return RefreshIndicator(
      onRefresh: _cargar,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final horizontal = constraints.maxWidth >= 600 ? 24.0 : 16.0;
          final ancho = (constraints.maxWidth - horizontal * 2).clamp(0.0, 1100.0);
          final columnas = ancho >= 900 ? 3 : (ancho >= 560 ? 2 : 1);
          final anchoTarjeta = ((ancho - AppSpacing.md * (columnas - 1)) / columnas).floorToDouble();
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(horizontal, 16, horizontal, 32),
            child: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: ancho,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${_apadrinados.length} apadrinados en tus comunidades',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: _busqueda,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Buscar por nombre, correo o comunidad...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _busqueda.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () => setState(_busqueda.clear),
                              )
                            : null,
                      ),
                    ),
                    if (_comunidades.length > 1) ...[
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          FilterChipWidget(
                            label: 'Todas',
                            selected: _comunidad == null,
                            onSelected: () => setState(() => _comunidad = null),
                          ),
                          for (final c in _comunidades)
                            FilterChipWidget(
                              label: c,
                              selected: _comunidad == c,
                              onSelected: () => setState(() => _comunidad = c),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    if (lista.isEmpty)
                      EmptyState(
                        icon: Icons.people_outline,
                        title: _apadrinados.isEmpty ? 'Sin apadrinados' : 'Sin resultados',
                        description: _apadrinados.isEmpty
                            ? 'Se incorporan a tus comunidades con el código de acceso'
                            : 'Prueba con otra búsqueda',
                      )
                    else
                      Wrap(
                        spacing: AppSpacing.md,
                        children: [
                          for (final a in lista)
                            SizedBox(
                              width: anchoTarjeta,
                              child: PersonCard(
                                nombre: a.nombreCompleto.isNotEmpty ? a.nombreCompleto : 'Apadrinado',
                                subtitle: a.comunidadNombre ?? 'Sin comunidad',
                                detail: a.correo,
                                trailing: const Icon(Icons.folder_shared_outlined, color: AppColors.tealCyan),
                                onTap: () => _abrir(a),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) return _contenido();
    return Scaffold(appBar: AppBar(title: const Text('Mis apadrinados')), body: _contenido());
  }
}
