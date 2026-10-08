import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/admin_service.dart';
import '../../../core/theme/app_theme.dart';
import '../auth/login_screen.dart';
import '../notificaciones/notificaciones_screen.dart';
import '../perfil/perfil_screen.dart';
import 'gestionar_usuarios_screen.dart';
import 'gestionar_comunidades_screen.dart';
import 'estadisticas_globales_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _adminService = AdminService();

  Map<String, dynamic> _stats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarEstadisticas();
  }

  Future<void> _cargarEstadisticas() async {
    setState(() => _isLoading = true);
    try {
      final stats = await _adminService.obtenerEstadisticasGlobales();
      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  int _getStat(String key, {int defaultValue = 0}) {
    final val = _stats[key];
    if (val is int) return val;
    if (val is num) return val.toInt();
    return defaultValue;
  }

  Future<void> _cerrarSesion() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro de que deseas salir de tu cuenta?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.coralRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cerrar Sesión'),
          ),
        ],
      ),
    );

    if (confirmar == true && mounted) {
      await Provider.of<AuthService>(context, listen: false).logout();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthService>(context).currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de Administrador'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            tooltip: 'Notificaciones',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificacionesScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Salir',
            onPressed: _cerrarSesion,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargarEstadisticas,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Banner de bienvenida
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: const BoxDecoration(
                        color: AppColors.darkNavy,
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(24),
                          bottomRight: Radius.circular(24),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: AppColors.mustardGold,
                                child: Text(
                                  user?.nombre.isNotEmpty == true ? user!.nombre[0] : 'A',
                                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '¡Hola, ${user?.nombre ?? "Administrador"}!',
                                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                    ),
                                    const Text(
                                      'Administrador del Sistema • UNBOUND',
                                      style: TextStyle(color: Colors.white70, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),

                          // Métricas clave
                          Row(
                            children: [
                              _buildMetricCard('Usuarios', '${_getStat("totalUsuarios")}', Icons.people, AppColors.tealCyan),
                              const SizedBox(width: 10),
                              _buildMetricCard('Comunidades', '${_getStat("totalComunidades")}', Icons.location_city, AppColors.mustardGold),
                              const SizedBox(width: 10),
                              _buildMetricCard('Cartas', '${_getStat("totalCartas")}', Icons.mail, AppColors.sageGreen),
                            ],
                          ),

                          const SizedBox(height: 18),

                          // Accesos rápidos
                          Row(
                            children: [
                              Expanded(
                                child: _buildQuickAccessCard(
                                  icon: Icons.people_outline,
                                  label: 'Usuarios',
                                  color: AppColors.tealCyan,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => const GestionarUsuariosScreen()),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildQuickAccessCard(
                                  icon: Icons.location_city,
                                  label: 'Comunidades',
                                  color: AppColors.coralRed,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => const GestionarComunidadesScreen()),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildQuickAccessCard(
                                  icon: Icons.bar_chart,
                                  label: 'Estadísticas',
                                  color: AppColors.sageGreen,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => const EstadisticasGlobalesScreen()),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          Row(
                            children: [
                              Expanded(
                                child: _buildQuickAccessCard(
                                  icon: Icons.person_outline,
                                  label: 'Mi Perfil',
                                  color: AppColors.mustardGold,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => const PerfilScreen()),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildQuickAccessCard(
                                  icon: Icons.settings_outlined,
                                  label: 'Configurar',
                                  color: AppColors.tealCyan,
                                  onTap: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Configuración disponible en el menú principal')),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildQuickAccessCard(
                                  icon: Icons.help_outline,
                                  label: 'Ayuda',
                                  color: AppColors.coralRed,
                                  onTap: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Próximamente: Centro de ayuda')),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Resumen del sistema
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: const Text(
                        'Resumen del Sistema',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.darkNavy),
                      ),
                    ),
                    const SizedBox(height: 12),

                    _buildSummaryCard(
                      icon: Icons.people,
                      label: 'Total de Usuarios',
                      value: '${_getStat("totalUsuarios")}',
                      color: AppColors.tealCyan,
                    ),
                    _buildSummaryCard(
                      icon: Icons.location_city,
                      label: 'Comunidades Activas',
                      value: '${_getStat("totalComunidades")}',
                      color: AppColors.mustardGold,
                    ),
                    _buildSummaryCard(
                      icon: Icons.assignment,
                      label: 'Actividades Creadas',
                      value: '${_getStat("totalActividades")}',
                      color: AppColors.coralRed,
                    ),
                    _buildSummaryCard(
                      icon: Icons.mail,
                      label: 'Cartas Enviadas',
                      value: '${_getStat("totalCartas")}',
                      color: AppColors.sageGreen,
                    ),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(25),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withAlpha(40)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11), maxLines: 1),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAccessCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(25),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withAlpha(40)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withAlpha(30),
          child: Icon(icon, color: color),
        ),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: Text(
          value,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
        ),
      ),
    );
  }
}
