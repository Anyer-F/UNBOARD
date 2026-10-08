import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';

class CambiarContrasenaScreen extends StatefulWidget {
  const CambiarContrasenaScreen({super.key});

  @override
  State<CambiarContrasenaScreen> createState() => _CambiarContrasenaScreenState();
}

class _CambiarContrasenaScreenState extends State<CambiarContrasenaScreen> {
  final _api = ApiService();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validarPassword(String password) {
    if (password.isEmpty) return 'La contraseña es obligatoria';
    if (password.length < 6) return 'Debe tener al menos 6 caracteres';
    return null;
  }

  Future<void> _cambiarContrasena() async {
    final currentPassword = _currentPasswordController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    // Validaciones
    if (currentPassword.isEmpty) {
      _mostrarError('Ingresa tu contraseña actual');
      return;
    }

    final errorNew = _validarPassword(newPassword);
    if (errorNew != null) {
      _mostrarError(errorNew);
      return;
    }

    if (newPassword != confirmPassword) {
      _mostrarError('Las contraseñas no coinciden');
      return;
    }

    if (currentPassword == newPassword) {
      _mostrarError('La nueva contraseña debe ser diferente a la actual');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = Provider.of<AuthService>(context, listen: false).currentUser;
      if (user != null) {
        await _api.post('/api/auth/cambiar-password', {
          'usuarioId': user.usuarioId,
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        });
      }

      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contraseña cambiada correctamente'),
            backgroundColor: AppColors.sageGreen,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        _mostrarError(e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: AppColors.coralRed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cambiar Contraseña'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.darkNavy,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lock_reset, color: Colors.white, size: 32),
                  SizedBox(height: 12),
                  Text(
                    'Actualiza tu contraseña',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Por seguridad, tu contraseña debe tener al menos 6 caracteres',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Formulario
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Contraseña actual
                    TextField(
                      controller: _currentPasswordController,
                      obscureText: _obscureCurrent,
                      decoration: InputDecoration(
                        labelText: 'Contraseña actual *',
                        prefixIcon: const Icon(Icons.lock_outline, color: AppColors.darkNavy),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureCurrent ? Icons.visibility_off : Icons.visibility,
                            color: Colors.grey,
                          ),
                          onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Nueva contraseña
                    TextField(
                      controller: _newPasswordController,
                      obscureText: _obscureNew,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Nueva contraseña *',
                        prefixIcon: const Icon(Icons.lock, color: AppColors.darkNavy),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureNew ? Icons.visibility_off : Icons.visibility,
                            color: Colors.grey,
                          ),
                          onPressed: () => setState(() => _obscureNew = !_obscureNew),
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Indicador de fortaleza
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _newPasswordController,
                      builder: (context, value, _) {
                        final password = value.text;
                        if (password.isEmpty) return const SizedBox.shrink();

                        int strength = 0;
                        if (password.length >= 6) strength++;
                        if (password.length >= 10) strength++;
                        if (password.contains(RegExp(r'[A-Z]'))) strength++;
                        if (password.contains(RegExp(r'[0-9]'))) strength++;

                        final labels = ['Muy débil', 'Débil', 'Regular', 'Buena', 'Fuerte'];
                        final colors = [
                          AppColors.coralRed,
                          AppColors.coralRed,
                          AppColors.mustardGold,
                          AppColors.tealCyan,
                          AppColors.sageGreen,
                        ];

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: (strength + 1) / 5,
                              backgroundColor: Colors.grey.shade200,
                              valueColor: AlwaysStoppedAnimation<Color>(colors[strength]),
                              minHeight: 4,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Fortaleza: ${labels[strength]}',
                              style: TextStyle(
                                fontSize: 12,
                                color: colors[strength],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 16),

                    // Confirmar contraseña
                    TextField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirm,
                      decoration: InputDecoration(
                        labelText: 'Confirmar nueva contraseña *',
                        prefixIcon: const Icon(Icons.lock_reset, color: AppColors.darkNavy),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                            color: Colors.grey,
                          ),
                          onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Botón cambiar
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _cambiarContrasena,
                child: _isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text('Cambiar Contraseña'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
