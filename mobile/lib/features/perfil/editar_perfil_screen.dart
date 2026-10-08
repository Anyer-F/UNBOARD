import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';

class EditarPerfilScreen extends StatefulWidget {
  const EditarPerfilScreen({super.key});

  @override
  State<EditarPerfilScreen> createState() => _EditarPerfilScreenState();
}

class _EditarPerfilScreenState extends State<EditarPerfilScreen> {
  final _api = ApiService();
  final _nombreController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _direccionController = TextEditingController();
  final _fechaNacimientoController = TextEditingController();

  bool _isLoading = false;
  bool _isLoadingData = true;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _telefonoController.dispose();
    _direccionController.dispose();
    _fechaNacimientoController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoadingData = true);

    try {
      final user = Provider.of<AuthService>(context, listen: false).currentUser;
      if (user != null) {
        _nombreController.text = user.nombre;
        final response = await _api.get('/api/apadrinados/${user.apadrinadoId}');
        if (response is Map<String, dynamic>) {
          _telefonoController.text = response['telefono'] ?? '';
          _direccionController.text = response['direccion'] ?? '';
          _fechaNacimientoController.text = response['fechaNacimiento'] ?? '';
        }
      }
      setState(() => _isLoadingData = false);
    } catch (e) {
      setState(() => _isLoadingData = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar datos: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: AppColors.coralRed,
          ),
        );
      }
    }
  }

  Future<void> _guardarPerfil() async {
    final nombre = _nombreController.text.trim();
    final telefono = _telefonoController.text.trim();
    final direccion = _direccionController.text.trim();
    final fechaNacimiento = _fechaNacimientoController.text.trim();

    if (nombre.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El nombre es obligatorio'),
          backgroundColor: AppColors.coralRed,
        ),
      );
      return;
    }

    if (telefono.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El teléfono es obligatorio'),
          backgroundColor: AppColors.coralRed,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = Provider.of<AuthService>(context, listen: false).currentUser;
      if (user != null) {
        await _api.put('/api/apadrinados/${user.apadrinadoId}', {
          'nombre': nombre,
          'telefono': telefono,
          'direccion': direccion,
          'fechaNacimiento': fechaNacimiento,
        });

        setState(() => _isLoading = false);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Perfil actualizado correctamente'),
              backgroundColor: AppColors.sageGreen,
            ),
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: AppColors.coralRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthService>(context).currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Perfil'),
      ),
      body: _isLoadingData
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar y nombre
                  Center(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 45,
                          backgroundColor: AppColors.tealCyan,
                          child: Text(
                            _nombreController.text.isNotEmpty
                                ? _nombreController.text[0].toUpperCase()
                                : user?.nombre.isNotEmpty == true
                                    ? user!.nombre[0].toUpperCase()
                                    : 'A',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          user?.nombre ?? 'Apadrinado',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.darkNavy,
                          ),
                        ),
                        Text(
                          user?.correo ?? '',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Formulario
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Información Personal',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.darkNavy,
                            ),
                          ),
                          const SizedBox(height: 16),

                          TextField(
                            controller: _nombreController,
                            decoration: const InputDecoration(
                              labelText: 'Nombre completo *',
                              prefixIcon: Icon(Icons.person, color: AppColors.darkNavy),
                              hintText: 'Ingresa tu nombre completo',
                            ),
                          ),
                          const SizedBox(height: 16),

                          TextField(
                            controller: _telefonoController,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Teléfono *',
                              prefixIcon: Icon(Icons.phone, color: AppColors.darkNavy),
                              hintText: 'Ej: 5555-5555',
                            ),
                          ),
                          const SizedBox(height: 16),

                          TextField(
                            controller: _direccionController,
                            decoration: const InputDecoration(
                              labelText: 'Dirección',
                              prefixIcon: Icon(Icons.home, color: AppColors.darkNavy),
                              hintText: 'Tu dirección de residencia',
                            ),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 16),

                          TextField(
                            controller: _fechaNacimientoController,
                            decoration: InputDecoration(
                              labelText: 'Fecha de nacimiento',
                              hintText: 'Ej: 2005-01-15',
                              prefixIcon: const Icon(Icons.calendar_today, color: AppColors.darkNavy),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.edit_calendar, color: AppColors.darkNavy),
                                onPressed: () async {
                                  final date = await showDatePicker(
                                    context: context,
                                    initialDate: DateTime.now().subtract(const Duration(days: 365 * 10)),
                                    firstDate: DateTime(1900),
                                    lastDate: DateTime.now(),
                                  );
                                  if (date != null) {
                                    _fechaNacimientoController.text =
                                        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                                  }
                                },
                              ),
                            ),
                            readOnly: true,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Botón guardar
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _guardarPerfil,
                      child: _isLoading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Text('Guardar Cambios'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
