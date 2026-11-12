import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/responsive.dart';
import '../../services/auth_service.dart';
import '../../services/usuario_service.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../shared/widgets/states.dart';
import '../../../core/theme/app_theme.dart';

/// Edición de la información permitida del perfil (ambos roles):
/// nombre, apellido, teléfono, dirección y fecha de nacimiento.
/// El correo y el rol no se modifican aquí.
class EditarPerfilScreen extends StatefulWidget {
  const EditarPerfilScreen({super.key});

  @override
  State<EditarPerfilScreen> createState() => _EditarPerfilScreenState();
}

class _EditarPerfilScreenState extends State<EditarPerfilScreen> {
  final _service = UsuarioService();
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _apellidoController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _direccionController = TextEditingController();
  DateTime? _fechaNacimiento;
  String? _correo;

  bool _guardando = false;
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _apellidoController.dispose();
    _telefonoController.dispose();
    _direccionController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final perfil = await _service.miPerfil();
      if (!mounted) return;
      setState(() {
        _nombreController.text = perfil.nombre;
        _apellidoController.text = perfil.apellido ?? '';
        _telefonoController.text = perfil.telefono ?? '';
        _direccionController.text = perfil.direccion ?? '';
        _fechaNacimiento = perfil.fechaNacimiento != null ? DateTime.tryParse(perfil.fechaNacimiento!) : null;
        _correo = perfil.correo;
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

  Future<void> _elegirFecha() async {
    final hoy = DateTime.now();
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fechaNacimiento ?? DateTime(hoy.year - 12),
      firstDate: DateTime(1900),
      lastDate: hoy,
      helpText: 'Fecha de nacimiento',
    );
    if (elegida != null) setState(() => _fechaNacimiento = elegida);
  }

  Future<void> _guardarPerfil() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _guardando = true);
    try {
      final perfil = await _service.actualizar(
        nombre: _nombreController.text.trim(),
        apellido: _apellidoController.text.trim(),
        telefono: _telefonoController.text.trim(),
        direccion: _direccionController.text.trim(),
        fechaNacimiento: _fechaNacimiento != null ? AppDateUtils.toApiDate(_fechaNacimiento!) : null,
      );
      if (!mounted) return;
      await Provider.of<AuthService>(context, listen: false).actualizarNombre(perfil.nombre);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil actualizado correctamente'), backgroundColor: AppColors.sageGreen),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar: ${mensajeDeError(e)}'), backgroundColor: AppColors.coralRed),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nombreAvatar = '${_nombreController.text} ${_apellidoController.text}'.trim();
    return Scaffold(
      appBar: AppBar(title: const Text('Editar Perfil')),
      body: _cargando
          ? const LoadingState(message: 'Cargando perfil...')
          : _error != null
              ? ErrorState(title: 'No se pudo cargar el perfil', message: _error, onRetry: _cargarDatos)
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: ResponsiveContent(
                    maxWidth: 560,
                    padding: EdgeInsets.zero,
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Column(
                              children: [
                                InitialsAvatar(name: nombreAvatar.isEmpty ? 'U' : nombreAvatar, size: 84),
                                const SizedBox(height: AppSpacing.sm),
                                if (_correo != null)
                                  Text(_correo!, style: const TextStyle(color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          TextFormField(
                            controller: _nombreController,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Nombre',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            validator: (v) => v == null || v.trim().isEmpty ? 'El nombre es obligatorio' : null,
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextFormField(
                            controller: _apellidoController,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Apellido',
                              prefixIcon: Icon(Icons.badge_outlined),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextFormField(
                            controller: _telefonoController,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Teléfono',
                              prefixIcon: Icon(Icons.phone_outlined),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextFormField(
                            controller: _direccionController,
                            decoration: const InputDecoration(
                              labelText: 'Dirección',
                              prefixIcon: Icon(Icons.home_outlined),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          InkWell(
                            onTap: _elegirFecha,
                            borderRadius: BorderRadius.circular(12),
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Fecha de nacimiento',
                                prefixIcon: Icon(Icons.cake_outlined),
                              ),
                              child: Text(
                                _fechaNacimiento != null
                                    ? AppDateUtils.formatDate(AppDateUtils.toApiDate(_fechaNacimiento!))
                                    : 'Seleccionar',
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          SizedBox(
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _guardando ? null : _guardarPerfil,
                              child: _guardando
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                    )
                                  : const Text('Guardar Cambios'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
    );
  }
}
