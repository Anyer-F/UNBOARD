import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../shared/models/comunidad.dart';
import '../../services/auth_service.dart';
import '../../services/expediente_service.dart';
import '../../../core/theme/app_theme.dart';

class RegistrarApadrinadoScreen extends StatefulWidget {
  const RegistrarApadrinadoScreen({super.key});

  @override
  State<RegistrarApadrinadoScreen> createState() => _RegistrarApadrinadoScreenState();
}

class _RegistrarApadrinadoScreenState extends State<RegistrarApadrinadoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _correoController = TextEditingController();
  final _passwordController = TextEditingController(text: 'password123');

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _cargandoComunidades = true;

  final _expedienteService = ExpedienteService();
  List<Comunidad> _comunidades = [];
  int? _comunidadSeleccionadaId;

  @override
  void initState() {
    super.initState();
    _cargarComunidades();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _correoController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _cargarComunidades() async {
    try {
      final list = await _expedienteService.listarComunidades();
      setState(() {
        _comunidades = list;
        if (_comunidades.isNotEmpty) {
          _comunidadSeleccionadaId = _comunidades.first.id;
        }
        _cargandoComunidades = false;
      });
    } catch (_) {
      setState(() => _cargandoComunidades = false);
    }
  }

  Future<void> _registrar() async {
    if (!_formKey.currentState!.validate()) return;

    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    final coordinadorId = user?.coordinadorId;

    setState(() => _isLoading = true);

    try {
      final payload = {
        'nombre': _nombreController.text.trim(),
        'correo': _correoController.text.trim(),
        'password': _passwordController.text.trim().isNotEmpty ? _passwordController.text.trim() : 'password123',
        'coordinadorId': coordinadorId,
        'comunidadId': _comunidadSeleccionadaId,
      };

      await _expedienteService.crearApadrinado(payload);

      if (!mounted) return;
      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Apadrinado registrado y Expediente Digital creado con éxito!'),
          backgroundColor: AppColors.sageGreen,
          duration: Duration(seconds: 4),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Error al registrar', style: TextStyle(color: AppColors.coralRed)),
          content: Text(e.toString().replaceAll('Exception: ', '')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthService>(context).currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Apadrinado'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Banner informativo
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.tealCyan.withAlpha(20),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.tealCyan.withAlpha(50)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.tealCyan, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Creación Automática de Expediente',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.darkNavy,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Al registrar al apadrinado se creará su cuenta de acceso y automáticamente su expediente digital único, donde se concentrarán todas sus cartas, evidencias y actividades.',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade800, height: 1.3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Formulario
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Datos del Beneficiario',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppColors.darkNavy,
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Nombre completo
                        TextFormField(
                          controller: _nombreController,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Nombre y Apellidos *',
                            hintText: 'Ej. Pedro Pablo Morales',
                            prefixIcon: Icon(Icons.person_outline, color: AppColors.darkNavy),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Por favor ingresa el nombre del apadrinado';
                            }
                            if (value.trim().length < 3) {
                              return 'El nombre debe tener al menos 3 caracteres';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 16),

                        // Correo Electrónico
                        TextFormField(
                          controller: _correoController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Correo Electrónico *',
                            hintText: 'pedro.morales@unbound.org',
                            prefixIcon: Icon(Icons.email_outlined, color: AppColors.darkNavy),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Por favor ingresa un correo de acceso';
                            }
                            if (!value.contains('@') || !value.contains('.')) {
                              return 'Ingresa un correo electrónico válido';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 16),

                        // Contraseña Inicial
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Contraseña de Acceso *',
                            helperText: 'Contraseña sugerida: password123',
                            prefixIcon: const Icon(Icons.lock_outline, color: AppColors.darkNavy),
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Ingresa una contraseña para la cuenta';
                            }
                            if (value.trim().length < 4) {
                              return 'La contraseña debe tener al menos 4 caracteres';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 20),

                        // Comunidad
                        const Text(
                          'Comunidad de Huehuetenango *',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.darkNavy),
                        ),
                        const SizedBox(height: 8),

                        _cargandoComunidades
                            ? const Padding(
                                padding: EdgeInsets.all(12.0),
                                child: Center(child: CircularProgressIndicator()),
                              )
                            : _comunidades.isEmpty
                                ? const Text('No hay comunidades disponibles en el sistema.', style: TextStyle(color: Colors.red))
                                : DropdownButtonFormField<int>(
                                    value: _comunidadSeleccionadaId,
                                    decoration: const InputDecoration(
                                      prefixIcon: Icon(Icons.location_on_outlined, color: AppColors.darkNavy),
                                    ),
                                    items: _comunidades.map((c) {
                                      return DropdownMenuItem<int>(
                                        value: c.id,
                                        child: Text('${c.nombre} (${c.municipio ?? "Huehuetenango"})'),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      setState(() {
                                        _comunidadSeleccionadaId = val;
                                      });
                                    },
                                    validator: (val) => val == null ? 'Selecciona una comunidad' : null,
                                  ),

                        const SizedBox(height: 16),

                        // Coordinador Responsable (Solo lectura)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.badge_outlined, color: Colors.grey, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Coordinador Responsable', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                    Text(
                                      user?.nombre ?? 'Coordinador de Proyecto',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.darkNavy),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // Botón de Enviar
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.darkNavy,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _isLoading ? null : _registrar,
                    icon: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.person_add_alt_1),
                    label: Text(
                      _isLoading ? 'Registrando...' : 'Registrar Apadrinado',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
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
