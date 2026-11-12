import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_radius.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/validators.dart';
import '../../../services/auth_service.dart';
import '../../../services/comunidad_service.dart';
import '../../../shared/models/solicitud_incorporacion.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/confirmation_dialog.dart';

/// Incorporación a una comunidad con el código de acceso.
///
/// Para un apadrinado con cuenta que aún no pertenece a una comunidad:
/// envía la solicitud con el código y consulta su estado. Si la
/// comunidad admite el ingreso directo, el código basta.
class JoinCommunityScreen extends StatefulWidget {
  const JoinCommunityScreen({super.key});

  @override
  State<JoinCommunityScreen> createState() => _JoinCommunityScreenState();
}

class _JoinCommunityScreenState extends State<JoinCommunityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codigoController = TextEditingController();
  final _service = ComunidadService();
  bool _enviando = false;
  bool _actualizando = false;
  List<SolicitudIncorporacion> _solicitudes = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthService>(context, listen: false);
      if (!auth.isAuthenticated) {
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }
      _actualizar(silencioso: true);
    });
  }

  @override
  void dispose() {
    _codigoController.dispose();
    super.dispose();
  }

  bool get _tienePendiente => _solicitudes.any((s) => s.pendiente);

  /// Consulta las solicitudes y el perfil; si ya fue aceptado, entra.
  Future<void> _actualizar({bool silencioso = false}) async {
    setState(() => _actualizando = true);
    final auth = Provider.of<AuthService>(context, listen: false);
    try {
      final solicitudes = await _service.misSolicitudes();
      final user = await auth.refrescarPerfil();
      if (!mounted) return;
      setState(() => _solicitudes = solicitudes);
      if (user != null && user.apadrinadoId != null) {
        _entrar();
        return;
      }
      if (!silencioso) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_tienePendiente
                ? 'Tu solicitud sigue pendiente de revisión.'
                : 'Aún no perteneces a una comunidad.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      if (!silencioso) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensajeDeError(e)), backgroundColor: AppColors.coralRed),
        );
      }
    } finally {
      if (mounted) setState(() => _actualizando = false);
    }
  }

  void _entrar() {
    Navigator.pushNamedAndRemoveUntil(context, '/apadrinado/home', (_) => false);
  }

  Future<void> _solicitar() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _enviando = true);
    try {
      final solicitud = await _service.solicitarIncorporacion(_codigoController.text);
      if (!mounted) return;
      _codigoController.clear();
      if (solicitud.aprobada) {
        // Ingreso directo: el código bastó para incorporarse
        await Provider.of<AuthService>(context, listen: false).refrescarPerfil();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('¡Bienvenido a ${solicitud.comunidadNombre ?? 'tu comunidad'}!'),
            backgroundColor: AppColors.sageGreen,
          ),
        );
        _entrar();
        return;
      }
      await showConfirmationDialog(
        context,
        title: 'Solicitud enviada',
        message: 'Tu solicitud para unirte a ${solicitud.comunidadNombre ?? 'la comunidad'} fue enviada al '
            'coordinador. Recibirás una notificación cuando sea revisada.',
        confirmLabel: 'Entendido',
        cancelLabel: 'Cerrar',
      );
      await _actualizar(silencioso: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensajeDeError(e)), backgroundColor: AppColors.coralRed),
      );
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _cerrarSesion() async {
    await Provider.of<AuthService>(context, listen: false).logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthService>(context).currentUser;
    return Scaffold(
      backgroundColor: AppColors.lightBg,
      appBar: AppBar(
        title: const Text('Unirse a una comunidad'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            icon: _actualizando
                ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.refresh),
            onPressed: _actualizando ? null : () => _actualizar(),
          ),
          IconButton(tooltip: 'Cerrar sesión', icon: const Icon(Icons.logout), onPressed: _cerrarSesion),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _actualizar(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Hola${user != null ? ', ${user.nombre}' : ''}',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.darkNavy),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    const Text(
                      'Para ver tus actividades necesitas pertenecer a una comunidad.',
                      style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      decoration: BoxDecoration(
                        color: AppColors.tealCyan.withAlpha(13),
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.location_city_outlined, size: 40, color: AppColors.tealCyan),
                          SizedBox(height: AppSpacing.md),
                          Text(
                            'Código de comunidad',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.charcoal),
                          ),
                          SizedBox(height: AppSpacing.xs),
                          Text(
                            'Pide el código a tu coordinador. Según tu comunidad, el coordinador revisará tu '
                            'solicitud o ingresarás de inmediato.',
                            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Form(
                      key: _formKey,
                      child: AppTextField(
                        controller: _codigoController,
                        labelText: 'Código de comunidad',
                        hintText: 'CHIANTLA-26',
                        prefixIcon: Icons.qr_code_2_outlined,
                        textCapitalization: TextCapitalization.characters,
                        enabled: !_tienePendiente,
                        validator: Validators.communityCode,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    PrimaryButton(
                      label: _tienePendiente ? 'Solicitud en revisión' : 'Unirme a la comunidad',
                      icon: Icons.group_add_outlined,
                      isLoading: _enviando,
                      onPressed: _enviando || _tienePendiente ? null : _solicitar,
                    ),
                    if (_solicitudes.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xl),
                      const Text(
                        'Mis solicitudes',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.charcoal),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      for (final s in _solicitudes) _SolicitudTile(solicitud: s),
                    ],
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

class _SolicitudTile extends StatelessWidget {
  final SolicitudIncorporacion solicitud;

  const _SolicitudTile({required this.solicitud});

  @override
  Widget build(BuildContext context) {
    final s = solicitud;
    final (color, texto, icono) = s.aprobada
        ? (AppColors.sageGreen, 'Aceptada', Icons.check_circle_outline)
        : s.rechazada
            ? (AppColors.coralRed, 'Rechazada', Icons.cancel_outlined)
            : (AppColors.mustardGold, 'Pendiente de revisión', Icons.hourglass_top);
    return AppCard(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, color: color),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.comunidadNombre ?? 'Comunidad',
                    style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.charcoal)),
                const SizedBox(height: 2),
                Text(texto, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w600)),
                Text('Enviada: ${AppDateUtils.formatDateTime(s.fechaSolicitud)}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                if (s.rechazada && s.observaciones != null && s.observaciones!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Text('Motivo: ${s.observaciones}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
