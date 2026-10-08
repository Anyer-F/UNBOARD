import 'package:flutter/material.dart';
import '../../shared/models/comunidad.dart';
import '../../services/admin_service.dart';
import '../../../core/theme/app_theme.dart';

class GestionarComunidadesScreen extends StatefulWidget {
  const GestionarComunidadesScreen({super.key});

  @override
  State<GestionarComunidadesScreen> createState() => _GestionarComunidadesScreenState();
}

class _GestionarComunidadesScreenState extends State<GestionarComunidadesScreen> {
  final _adminService = AdminService();
  final _searchController = TextEditingController();

  List<Comunidad> _comunidades = [];
  List<Comunidad> _comunidadesFiltradas = [];
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _cargarComunidades();
    _searchController.addListener(_filtrarComunidades);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _cargarComunidades() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final response = await _adminService.listarComunidades();
      final comunidades = response.map((c) => Comunidad.fromJson(c)).toList();

      setState(() {
        _comunidades = comunidades;
        _comunidadesFiltradas = comunidades;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  void _filtrarComunidades() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _comunidadesFiltradas = _comunidades;
      } else {
        _comunidadesFiltradas = _comunidades.where((c) {
          return c.nombre.toLowerCase().contains(query) ||
              (c.municipio?.toLowerCase().contains(query) ?? false) ||
              (c.departamento?.toLowerCase().contains(query) ?? false);
        }).toList();
      }
    });
  }

  void _mostrarFormularioComunidad({Comunidad? comunidad}) {
    final nombreController = TextEditingController(text: comunidad?.nombre ?? '');
    final municipioController = TextEditingController(text: comunidad?.municipio ?? '');
    final departamentoController = TextEditingController(text: comunidad?.departamento ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(comunidad == null ? 'Nueva Comunidad' : 'Editar Comunidad'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreController,
                decoration: const InputDecoration(
                  labelText: 'Nombre de la comunidad *',
                  prefixIcon: Icon(Icons.location_city, color: AppColors.darkNavy),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: municipioController,
                decoration: const InputDecoration(
                  labelText: 'Municipio',
                  prefixIcon: Icon(Icons.map, color: AppColors.darkNavy),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: departamentoController,
                decoration: const InputDecoration(
                  labelText: 'Departamento',
                  prefixIcon: Icon(Icons.flag, color: AppColors.darkNavy),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nombreController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('El nombre de la comunidad es obligatorio'),
                    backgroundColor: AppColors.coralRed,
                  ),
                );
                return;
              }

              Navigator.pop(ctx);
              await _guardarComunidad(
                comunidadId: comunidad?.id,
                nombre: nombreController.text.trim(),
                municipio: municipioController.text.trim(),
                departamento: departamentoController.text.trim(),
              );
            },
            child: Text(comunidad == null ? 'Crear' : 'Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _guardarComunidad({
    int? comunidadId,
    required String nombre,
    required String municipio,
    required String departamento,
  }) async {
    try {
      if (comunidadId == null) {
        await _adminService.crearComunidad(
          nombre: nombre,
          municipio: municipio,
          departamento: departamento,
        );
      } else {
        await _adminService.actualizarComunidad(
          comunidadId: comunidadId,
          nombre: nombre,
          municipio: municipio,
          departamento: departamento,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(comunidadId == null ? 'Comunidad creada correctamente' : 'Comunidad actualizada correctamente'),
            backgroundColor: AppColors.sageGreen,
          ),
        );
      }
      _cargarComunidades();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: AppColors.coralRed,
          ),
        );
      }
    }
  }

  Future<void> _eliminarComunidad(Comunidad comunidad) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Comunidad'),
        content: Text('¿Estás seguro de eliminar la comunidad "${comunidad.nombre}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.coralRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await _adminService.eliminarComunidad(comunidad.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Comunidad eliminada correctamente'),
              backgroundColor: AppColors.sageGreen,
            ),
          );
        }
        _cargarComunidades();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al eliminar: ${e.toString().replaceAll('Exception: ', '')}'),
              backgroundColor: AppColors.coralRed,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Comunidades'),
      ),
      body: Column(
        children: [
          // Buscador
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre, municipio o departamento...',
                prefixIcon: const Icon(Icons.search, color: AppColors.darkNavy),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),

          // Lista de comunidades
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _hasError
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, size: 60, color: AppColors.coralRed),
                            const SizedBox(height: 12),
                            const Text('Error al cargar las comunidades'),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _cargarComunidades,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      )
                    : _comunidadesFiltradas.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.location_city, size: 60, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                const Text('No hay comunidades registradas'),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.tealCyan),
                                  icon: const Icon(Icons.add),
                                  label: const Text('Crear Primera Comunidad'),
                                  onPressed: () => _mostrarFormularioComunidad(),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            itemCount: _comunidadesFiltradas.length,
                            itemBuilder: (context, index) {
                              final comunidad = _comunidadesFiltradas[index];

                              return Card(
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: AppColors.tealCyan.withAlpha(30),
                                    child: const Icon(Icons.location_city, color: AppColors.tealCyan),
                                  ),
                                  title: Text(
                                    comunidad.nombre,
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  subtitle: Text(
                                    [
                                      if (comunidad.municipio != null && comunidad.municipio!.isNotEmpty)
                                        comunidad.municipio!,
                                      if (comunidad.departamento != null && comunidad.departamento!.isNotEmpty)
                                        comunidad.departamento!,
                                    ].join(' • '),
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit, color: AppColors.tealCyan),
                                        tooltip: 'Editar',
                                        onPressed: () => _mostrarFormularioComunidad(comunidad: comunidad),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: AppColors.coralRed),
                                        tooltip: 'Eliminar',
                                        onPressed: () => _eliminarComunidad(comunidad),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.tealCyan,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nueva Comunidad', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => _mostrarFormularioComunidad(),
      ),
    );
  }
}
