import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';

class RecuperarContrasenaScreen extends StatefulWidget {
  const RecuperarContrasenaScreen({super.key});

  @override
  State<RecuperarContrasenaScreen> createState() => _RecuperarContrasenaScreenState();
}

class _RecuperarContrasenaScreenState extends State<RecuperarContrasenaScreen> {
  final _api = ApiService();
  final _correoController = TextEditingController();
  final _codigoController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _step1 = true;
  bool _step2 = false;
  bool _step3 = false;

  bool _isLoading = false;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _correoController.dispose();
    _codigoController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _enviarCodigo() async {
    final correo = _correoController.text.trim();

    if (correo.isEmpty) {
      _mostrarError('Ingresa tu correo electrónico');
      return;
    }

    if (!correo.contains('@')) {
      _mostrarError('Ingresa un correo electrónico válido');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _api.post('/api/auth/recuperar-password', {
        'correo': correo,
      });

      setState(() {
        _isLoading = false;
        _step1 = false;
        _step2 = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Código enviado a tu correo electrónico'),
            backgroundColor: AppColors.sageGreen,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        _mostrarError(e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  Future<void> _verificarCodigo() async {
    final codigo = _codigoController.text.trim();

    if (codigo.isEmpty) {
      _mostrarError('Ingresa el código de verificación');
      return;
    }

    if (codigo.length < 6) {
      _mostrarError('El código debe tener al menos 6 caracteres');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _api.post('/api/auth/verificar-codigo', {
        'correo': _correoController.text.trim(),
        'codigo': codigo,
      });

      setState(() {
        _isLoading = false;
        _step2 = false;
        _step3 = true;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        _mostrarError(e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  Future<void> _restablecerContrasena() async {
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (newPassword.isEmpty) {
      _mostrarError('Ingresa tu nueva contraseña');
      return;
    }

    if (newPassword.length < 6) {
      _mostrarError('La contraseña debe tener al menos 6 caracteres');
      return;
    }

    if (newPassword != confirmPassword) {
      _mostrarError('Las contraseñas no coinciden');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _api.post('/api/auth/restablecer-password', {
        'correo': _correoController.text.trim(),
        'codigo': _codigoController.text.trim(),
        'newPassword': newPassword,
      });

      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contraseña restablecida correctamente'),
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
        title: const Text('Recuperar Contraseña'),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lock_open, color: Colors.white, size: 32),
                  const SizedBox(height: 12),
                  const Text(
                    'Recupera tu contraseña',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Sigue los pasos para restablecer tu contraseña de forma segura',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  // Indicador de pasos
                  Row(
                    children: [
                      _buildStepIndicator(1, _step1),
                      _buildStepLine(),
                      _buildStepIndicator(2, _step2),
                      _buildStepLine(),
                      _buildStepIndicator(3, _step3),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Paso 1: Correo
            if (_step1) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Paso 1: Verifica tu correo',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkNavy,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Ingresa tu correo electrónico registrado y te enviaremos un código de verificación.',
                        style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _correoController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Correo electrónico *',
                          hintText: 'tu@correo.com',
                          prefixIcon: Icon(Icons.email, color: AppColors.darkNavy),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _enviarCodigo,
                  child: _isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text('Enviar Código'),
                ),
              ),
            ],

            // Paso 2: Código
            if (_step2) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Paso 2: Ingresa el código',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkNavy,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Hemos enviado un código de verificación a ${_correoController.text.trim()}',
                        style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _codigoController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Código de verificación *',
                          hintText: 'Ej: 123456',
                          prefixIcon: Icon(Icons.pin, color: AppColors.darkNavy),
                        ),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 20, letterSpacing: 8),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              setState(() {
                                _step1 = true;
                                _step2 = false;
                                _codigoController.clear();
                              });
                            },
                      child: const Text('Reenviar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _verificarCodigo,
                      child: _isLoading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Text('Verificar'),
                    ),
                  ),
                ],
              ),
            ],

            // Paso 3: Nueva contraseña
            if (_step3) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Paso 3: Nueva contraseña',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkNavy,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Ingresa tu nueva contraseña. Debe tener al menos 6 caracteres.',
                        style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _newPasswordController,
                        obscureText: _obscureNew,
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
                      const SizedBox(height: 16),
                      TextField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirm,
                        decoration: InputDecoration(
                          labelText: 'Confirmar contraseña *',
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
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _restablecerContrasena,
                  child: _isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text('Restablecer Contraseña'),
                ),
              ),
            ],

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator(int step, bool active) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: active ? AppColors.tealCyan : Colors.grey.shade300,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          '$step',
          style: TextStyle(
            color: active ? Colors.white : Colors.grey.shade600,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildStepLine() {
    return Expanded(
      child: Container(
        height: 2,
        color: Colors.grey.shade300,
      ),
    );
  }
}
