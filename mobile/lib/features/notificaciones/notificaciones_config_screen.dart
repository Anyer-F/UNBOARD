import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';

class NotificacionesConfigScreen extends StatefulWidget {
  const NotificacionesConfigScreen({super.key});

  @override
  State<NotificacionesConfigScreen> createState() => _NotificacionesConfigScreenState();
}

class _NotificacionesConfigScreenState extends State<NotificacionesConfigScreen> {
  bool _notificacionesActivas = true;
  bool _nuevasActividades = true;
  bool _actividadesAprobadas = true;
  bool _correcciones = true;
  bool _nuevasCartas = true;
  bool _recordatorios = false;
  bool _sonido = true;
  bool _vibracion = true;

  @override
  void initState() {
    super.initState();
    _cargarPreferencias();
  }

  Future<void> _cargarPreferencias() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificacionesActivas = prefs.getBool('notificaciones_activas') ?? true;
      _nuevasActividades = prefs.getBool('notificar_nuevas_actividades') ?? true;
      _actividadesAprobadas = prefs.getBool('notificar_actividades_aprobadas') ?? true;
      _correcciones = prefs.getBool('notificar_correcciones') ?? true;
      _nuevasCartas = prefs.getBool('notificar_nuevas_cartas') ?? true;
      _recordatorios = prefs.getBool('notificar_recordatorios') ?? false;
      _sonido = prefs.getBool('notificaciones_sonido') ?? true;
      _vibracion = prefs.getBool('notificaciones_vibracion') ?? true;
    });
  }

  Future<void> _guardarPreferencia(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración de Notificaciones'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.darkNavy,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Notificaciones',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Gestiona cómo quieres recibir las notificaciones',
                    style: TextStyle(
                      color: Colors.white.withAlpha(200),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Interruptor principal
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _notificacionesActivas
                            ? AppColors.tealCyan.withAlpha(25)
                            : Colors.grey.withAlpha(25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _notificacionesActivas
                            ? Icons.notifications_active
                            : Icons.notifications_off,
                        color: _notificacionesActivas ? AppColors.tealCyan : Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Notificaciones',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.darkNavy,
                            ),
                          ),
                          Text(
                            _notificacionesActivas ? 'Activadas' : 'Desactivadas',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _notificacionesActivas,
                      activeColor: AppColors.tealCyan,
                      onChanged: (value) {
                        setState(() => _notificacionesActivas = value);
                        _guardarPreferencia('notificaciones_activas', value);
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Opciones de notificación
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tipos de notificación',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkNavy,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildNotificacionOption(
                    icon: Icons.assignment,
                    title: 'Nuevas actividades',
                    subtitle: 'Recibe notificaciones cuando se te asignen actividades',
                    value: _nuevasActividades,
                    onChanged: _notificacionesActivas
                        ? (value) {
                            setState(() => _nuevasActividades = value);
                            _guardarPreferencia('notificar_nuevas_actividades', value);
                          }
                        : null,
                  ),
                  _buildNotificacionOption(
                    icon: Icons.check_circle,
                    title: 'Actividades aprobadas',
                    subtitle: 'Recibe notificaciones cuando tus entregas sean aprobadas',
                    value: _actividadesAprobadas,
                    onChanged: _notificacionesActivas
                        ? (value) {
                            setState(() => _actividadesAprobadas = value);
                            _guardarPreferencia('notificar_actividades_aprobadas', value);
                          }
                        : null,
                  ),
                  _buildNotificacionOption(
                    icon: Icons.edit,
                    title: 'Correcciones',
                    subtitle: 'Recibe notificaciones cuando se soliciten correcciones',
                    value: _correcciones,
                    onChanged: _notificacionesActivas
                        ? (value) {
                            setState(() => _correcciones = value);
                            _guardarPreferencia('notificar_correcciones', value);
                          }
                        : null,
                  ),
                  _buildNotificacionOption(
                    icon: Icons.mail,
                    title: 'Nuevas cartas',
                    subtitle: 'Recibe notificaciones sobre nuevas cartas',
                    value: _nuevasCartas,
                    onChanged: _notificacionesActivas
                        ? (value) {
                            setState(() => _nuevasCartas = value);
                            _guardarPreferencia('notificar_nuevas_cartas', value);
                          }
                        : null,
                  ),
                  _buildNotificacionOption(
                    icon: Icons.alarm,
                    title: 'Recordatorios',
                    subtitle: 'Recibe recordatorios de fechas límite próximas',
                    value: _recordatorios,
                    onChanged: _notificacionesActivas
                        ? (value) {
                            setState(() => _recordatorios = value);
                            _guardarPreferencia('notificar_recordatorios', value);
                          }
                        : null,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Opciones de sonido y vibración
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sonido y vibración',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkNavy,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildNotificacionOption(
                    icon: Icons.volume_up,
                    title: 'Sonido',
                    subtitle: 'Reproducir sonido al recibir notificaciones',
                    value: _sonido,
                    onChanged: _notificacionesActivas
                        ? (value) {
                            setState(() => _sonido = value);
                            _guardarPreferencia('notificaciones_sonido', value);
                          }
                        : null,
                  ),
                  _buildNotificacionOption(
                    icon: Icons.vibration,
                    title: 'Vibración',
                    subtitle: 'Vibrar al recibir notificaciones',
                    value: _vibracion,
                    onChanged: _notificacionesActivas
                        ? (value) {
                            setState(() => _vibracion = value);
                            _guardarPreferencia('notificaciones_vibracion', value);
                          }
                        : null,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificacionOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    final isEnabled = onChanged != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 22,
            color: isEnabled ? AppColors.tealCyan : Colors.grey,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isEnabled ? AppColors.charcoal : Colors.grey,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isEnabled ? AppColors.textSecondary : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeColor: AppColors.tealCyan,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
