import 'package:flutter/material.dart';
import '../../shared/models/auth_user.dart';
import '../../services/admin_service.dart';
import '../../../core/theme/app_theme.dart';

class GestionarUsuariosScreen extends StatefulWidget {
  const GestionarUsuariosScreen({super.key});

  @override
  State<GestionarUsuariosScreen> createState() => _GestionarUsuariosScreenState();
}

class _GestionarUsuariosScreenState extends State<GestionarUsuariosScreen> {
  final _adminService = AdminService();
  final _searchController = TextEditingController();

  List<AuthUser> _usuarios = [];
  List<AuthUser> _usuariosFiltrados = [];
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _cargarUsuarios();
    _searchController.addListener(_filtrarUsuarios);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _cargarUsuarios() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final response = await _adminService.listarUsuarios();
      final usuarios = response.map((u) {
        return AuthUser(
          token: '',
          tokenType: 'Bearer',
          usuarioId: u['id'] is int ? u['id'] : int.tryParse(u['id'].toString()) ?? 0,
          nombre: u['nombre'] ?? '',
          correo: u['correo'] ?? '',
          rol: u['rol'] ?? '',
          coordinadorId: u['coordinadorId'] != null ? int.tryParse(u['coordinadorId'].toString()) : null,
          apadrinadoId: u['apadrinadoId'] != null ? int.tryParse(u['apadrinadoId'].toString()) : null,
        );
      }).toList();

      setState(() {
        _usuarios = usuarios;
        _usuariosFiltrados = usuarios;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  void _filtrarUsuarios() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _usuariosFiltrados = _usuarios;
      } else {
        _usuariosFiltrados = _usuarios.where((u) {
          return u.nombre.toLowerCase().contains(query) ||
              u.correo.toLowerCase().contains(query) ||
              u.rol.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  void _mostrarFormularioUsuario({AuthUser? usuario}) {
    final nombreController = TextEditingController(text: usuario?.nombre ?? '');
    final correoController = TextEditingController(text: usuario?.correo ?? '');
    final passwordController = TextEditingController();
    String rolSeleccionado = usuario?.rol ?? 'APADRINADO';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(usuario == null ? 'Nuevo Usuario' : 'Editar Usuario'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nombreController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre completo',
                    prefixIcon: Icon(Icons.person, color: AppColors.darkNavy),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: correoController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Correo electrónico',
                    prefixIcon: Icon(Icons.email, color: AppColors.darkNavy),
                  ),
                ),
                if (usuario == null) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: Icon(Icons.lock, color: AppColors.darkNavy),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: rolSeleccionado,
                  decoration: const InputDecoration(
                    labelText: 'Rol',
                    prefixIcon: Icon(Icons.badge, color: AppColors.darkNavy),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'ADMIN', child: Text('Administrador')),
                    DropdownMenuItem(value: 'COORDINADOR', child: Text('Coordinador')),
                    DropdownMenuItem(value: 'APADRINADO', child: Text('Apadrinado')),
                  ],
                  onChanged: (val) {
                    setDialogState(() => rolSeleccionado = val ?? 'APADRINADO');
                  },
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
                if (nombreController.text.trim().isEmpty ||
                    correoController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Completa todos los campos obligatorios'),
                      backgroundColor: AppColors.coralRed,
                    ),
                  );
                  return;
                }

                if (usuario == null && passwordController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('La contraseña es obligatoria para nuevos usuarios'),
                      backgroundColor: AppColors.coralRed,
                    ),
                  );
                  return;
                }

                Navigator.pop(ctx);
                await _guardarUsuario(
                  usuarioId: usuario?.usuarioId,
                  nombre: nombreController.text.trim(),
                  correo: correoController.text.trim(),
                  password: usuario == null ? passwordController.text.trim() : null,
                  rol: rolSeleccionado,
                );
              },
              child: Text(usuario == null ? 'Crear' : 'Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _guardarUsuario({
    int? usuarioId,
    required String nombre,
    required String correo,
    String? password,
    required String rol,
  }) async {
    try {
      if (usuarioId == null) {
        await _adminService.crearUsuario(
          nombre: nombre,
          correo: correo,
          password: password!,
          rol: rol,
        );
      } else {
        await _adminService.actualizarUsuario(
          usuarioId: usuarioId,
          nombre: nombre,
          correo: correo,
          rol: rol,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(usuarioId == null ? 'Usuario creado correctamente' : 'Usuario actualizado correctamente'),
            backgroundColor: AppColors.sageGreen,
          ),
        );
      }
      _cargarUsuarios();
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

  Future<void> _eliminarUsuario(AuthUser usuario) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Usuario'),
        content: Text('¿Estás seguro de eliminar a ${usuario.nombre}? Esta acción no se puede deshacer.'),
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
        await _adminService.eliminarUsuario(usuario.usuarioId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Usuario eliminado correctamente'),
              backgroundColor: AppColors.sageGreen,
            ),
          );
        }
        _cargarUsuarios();
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

  Color _getRolColor(String rol) {
    switch (rol.toUpperCase()) {
      case 'ADMIN':
        return AppColors.coralRed;
      case 'COORDINADOR':
        return AppColors.tealCyan;
      case 'APADRINADO':
        return AppColors.mustardGold;
      default:
        return Colors.grey;
    }
  }

  String _getRolTexto(String rol) {
    switch (rol.toUpperCase()) {
      case 'ADMIN':
        return 'Administrador';
      case 'COORDINADOR':
        return 'Coordinador';
      case 'APADRINADO':
        return 'Apadrinado';
      default:
        return rol;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Usuarios'),
      ),
      body: Column(
        children: [
          // Buscador
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre, correo o rol...',
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

          // Lista de usuarios
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
                            const Text('Error al cargar los usuarios'),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _cargarUsuarios,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      )
                    : _usuariosFiltrados.isEmpty
                        ? const Center(
                            child: Text('No se encontraron usuarios'),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            itemCount: _usuariosFiltrados.length,
                            itemBuilder: (context, index) {
                              final usuario = _usuariosFiltrados[index];
                              final rolColor = _getRolColor(usuario.rol);

                              return Card(
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: rolColor.withAlpha(30),
                                    child: Text(
                                      usuario.nombre.isNotEmpty ? usuario.nombre[0].toUpperCase() : 'U',
                                      style: TextStyle(color: rolColor, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  title: Text(
                                    usuario.nombre,
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(usuario.correo),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: rolColor.withAlpha(20),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          _getRolTexto(usuario.rol),
                                          style: TextStyle(color: rolColor, fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit, color: AppColors.tealCyan),
                                        tooltip: 'Editar',
                                        onPressed: () => _mostrarFormularioUsuario(usuario: usuario),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: AppColors.coralRed),
                                        tooltip: 'Eliminar',
                                        onPressed: () => _eliminarUsuario(usuario),
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
        backgroundColor: AppColors.darkNavy,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text('Nuevo Usuario', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => _mostrarFormularioUsuario(),
      ),
    );
  }
}
