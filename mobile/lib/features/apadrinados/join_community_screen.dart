import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_radius.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../services/auth_service.dart';
import '../../../services/expediente_service.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/confirmation_dialog.dart';

/// Unión a comunidad mediante código (especificación §21.4).
///
/// El Apadrinado ingresa el código de su comunidad
/// (ej. UNB-X7K92) para vincularse a ella.
class JoinCommunityScreen extends StatefulWidget {
  const JoinCommunityScreen({super.key});

  @override
  State<JoinCommunityScreen> createState() => _JoinCommunityScreenState();
}

class _JoinCommunityScreenState extends State<JoinCommunityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codigoController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _codigoController.dispose();
    super.dispose();
  }

  Future<void> _unirComunidad() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    if (user?.apadrinadoId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes iniciar sesión como Apadrinado'),
          backgroundColor: AppColors.coralRed,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ExpedienteService().unirComunidad(
        apadrinadoId: user!.apadrinadoId!,
        codigo: _codigoController.text.trim(),
      );

      if (!mounted) return;
      final confirmar = await showConfirmationDialog(
        context,
        title: 'Solicitud enviada',
        message:
            'Tu solicitud de incorporación fue enviada al Coordinador. Recibirás una notificación cuando sea revisada.',
        confirmLabel: 'Aceptar',
        cancelLabel: 'Ir al inicio',
      );
      if (confirmar && mounted) {
        Navigator.pop(context, true);
      } else if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppColors.coralRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBg,
      appBar: AppBar(
        title: const Text('Unirse a una comunidad'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.lg,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  decoration: BoxDecoration(
                    color: AppColors.tealCyan.withAlpha(13),
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.location_city_outlined,
                        size: 40,
                        color: AppColors.tealCyan,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const Text(
                        'Código de comunidad',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: AppColors.charcoal,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      const Text(
                        'Solicita el código a tu Coordinador. '
                        'Se usa para vincular tu expediente a tu comunidad.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppTextField(
                        controller: _codigoController,
                        labelText: 'Código de comunidad',
                        hintText: 'UNB-X7K92',
                        prefixIcon: Icons.qr_code_2_outlined,
                        validator: Validators.communityCode,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      PrimaryButton(
                        label: 'Solicitar incorporación',
                        icon: Icons.group_add_outlined,
                        isLoading: _isLoading,
                        onPressed: _isLoading ? null : _unirComunidad,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextButton.icon(
                        icon: const Icon(
                          Icons.help_outline,
                          size: 18,
                        ),
                        label: const Text('¿No tienes código?'),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('¿No tienes código?'),
                              content: const Text(
                                'Contacta al Coordinador de tu comunidad. '
                                'El código aparece en el panel del Coordinador '
                                'dentro de la sección Comunidades.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('Entendido'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
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
