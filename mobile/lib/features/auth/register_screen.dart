import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/validators.dart';
import '../../../services/auth_service.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';

/// Registro público: crea una cuenta de apadrinado. Después de
/// registrarse, el apadrinado solicita incorporarse a su comunidad
/// con el código que le comparte el coordinador.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _apellidoController = TextEditingController();
  final _correoController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _direccionController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmarController = TextEditingController();
  DateTime? _fechaNacimiento;
  bool _obscurePassword = true;
  bool _obscureConfirmar = true;
  bool _aceptaTerminos = false;
  bool _guardando = false;

  @override
  void dispose() {
    _nombreController.dispose();
    _apellidoController.dispose();
    _correoController.dispose();
    _telefonoController.dispose();
    _direccionController.dispose();
    _passwordController.dispose();
    _confirmarController.dispose();
    super.dispose();
  }

  String? _validarConfirmacion(String? value) {
    final required = Validators.required(value, field: 'La confirmación');
    if (required != null) return required;
    if (value != _passwordController.text) {
      return 'Las contraseñas no coinciden';
    }
    return null;
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

  Future<void> _registrarse() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_aceptaTerminos) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes aceptar los términos para continuar'),
          backgroundColor: AppColors.coralRed,
        ),
      );
      return;
    }

    setState(() => _guardando = true);
    try {
      await Provider.of<AuthService>(context, listen: false).registrar(
        nombre: _nombreController.text,
        apellido: _apellidoController.text,
        correo: _correoController.text,
        password: _passwordController.text,
        telefono: _telefonoController.text,
        direccion: _direccionController.text,
        fechaNacimiento: _fechaNacimiento != null ? AppDateUtils.toApiDate(_fechaNacimiento!) : null,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Cuenta creada! Ahora únete a tu comunidad con el código de tu coordinador.'),
          backgroundColor: AppColors.sageGreen,
        ),
      );
      Navigator.pushNamedAndRemoveUntil(context, '/join-community', (_) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensajeDeError(e)), backgroundColor: AppColors.coralRed),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.sizeOf(context).width;
    final dosColumnas = ancho >= 640;

    Widget par(Widget a, Widget b) => dosColumnas
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: a),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: b),
            ],
          )
        : Column(children: [a, const SizedBox(height: AppSpacing.md), b]);

    return Scaffold(
      backgroundColor: AppColors.lightBg,
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: dosColumnas ? 640 : 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Crea tu cuenta',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.darkNavy),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    const Text(
                      'Regístrate como apadrinado. Después podrás unirte a tu comunidad con el código que te '
                      'comparta tu coordinador.',
                      style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    par(
                      AppTextField(
                        controller: _nombreController,
                        labelText: 'Nombre',
                        hintText: 'Juan',
                        prefixIcon: Icons.person_outline,
                        textCapitalization: TextCapitalization.words,
                        validator: (v) => Validators.required(v, field: 'El nombre'),
                      ),
                      AppTextField(
                        controller: _apellidoController,
                        labelText: 'Apellido',
                        hintText: 'Pérez',
                        prefixIcon: Icons.badge_outlined,
                        textCapitalization: TextCapitalization.words,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    par(
                      AppTextField(
                        controller: _correoController,
                        labelText: 'Correo electrónico',
                        hintText: 'tu.correo@ejemplo.com',
                        prefixIcon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        textCapitalization: TextCapitalization.none,
                        validator: Validators.email,
                      ),
                      AppTextField(
                        controller: _telefonoController,
                        labelText: 'Teléfono (opcional)',
                        hintText: '5555-0000',
                        prefixIcon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    par(
                      AppTextField(
                        controller: _direccionController,
                        labelText: 'Dirección (opcional)',
                        prefixIcon: Icons.home_outlined,
                      ),
                      InkWell(
                        onTap: _elegirFecha,
                        borderRadius: BorderRadius.circular(12),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Fecha de nacimiento (opcional)',
                            prefixIcon: Icon(Icons.cake_outlined),
                          ),
                          child: Text(
                            _fechaNacimiento != null
                                ? AppDateUtils.formatDate(AppDateUtils.toApiDate(_fechaNacimiento!))
                                : 'Seleccionar',
                            style: TextStyle(
                              color: _fechaNacimiento != null ? AppColors.charcoal : AppColors.textTertiary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    par(
                      AppTextField(
                        controller: _passwordController,
                        labelText: 'Contraseña',
                        prefixIcon: Icons.lock_outline,
                        obscureText: _obscurePassword,
                        helperText: 'Mínimo 6 caracteres',
                        textCapitalization: TextCapitalization.none,
                        validator: Validators.password,
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      AppTextField(
                        controller: _confirmarController,
                        labelText: 'Confirmar contraseña',
                        prefixIcon: Icons.lock_person_outlined,
                        obscureText: _obscureConfirmar,
                        textCapitalization: TextCapitalization.none,
                        validator: _validarConfirmacion,
                        suffixIcon: IconButton(
                          icon: Icon(_obscureConfirmar ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                          onPressed: () => setState(() => _obscureConfirmar = !_obscureConfirmar),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Checkbox(
                          value: _aceptaTerminos,
                          onChanged: (v) => setState(() => _aceptaTerminos = v ?? false),
                        ),
                        const Expanded(
                          child: Text(
                            'Acepto los términos de uso y la política de privacidad',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    PrimaryButton(
                      label: 'Crear cuenta',
                      icon: Icons.person_add_outlined,
                      isLoading: _guardando,
                      onPressed: _guardando ? null : _registrarse,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Center(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('¿Ya tienes cuenta? Inicia sesión'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
