import 'package:flutter/material.dart';
import '../../services/admin_service.dart';
import '../../../core/theme/app_theme.dart';

class EstadisticasGlobalesScreen extends StatefulWidget {
  const EstadisticasGlobalesScreen({super.key});

  @override
  State<EstadisticasGlobalesScreen> createState() => _EstadisticasGlobalesScreenState();
}

class _EstadisticasGlobalesScreenState extends State<EstadisticasGlobalesScreen> {
  final _adminService = AdminService();

  Map<String, dynamic> _stats = {};
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _cargarEstadisticas();
  }

  Future<void> _cargarEstadisticas() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final stats = await _adminService.obtenerEstadisticasGlobales();
      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  int _getStat(String key, {int defaultValue = 0}) {
    final val = _stats[key];
    if (val is int) return val;
    if (val is num) return val.toInt();
    return defaultValue;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Estadísticas Globales'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasError
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 60, color: AppColors.coralRed),
                      const SizedBox(height: 12),
                      const Text('Error al cargar las estadísticas'),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _cargarEstadisticas,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reintentar'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _cargarEstadisticas,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
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
                              Text(
                                'Resumen General del Sistema',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Fundación UNBOUND • Huehuetenango, Guatemala',
                                style: TextStyle(color: Colors.white70, fontSize: 13),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Estadísticas principales
                        const Text(
                          'Usuarios y Comunidades',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.darkNavy,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                label: 'Total Usuarios',
                                value: '${_getStat("totalUsuarios")}',
                                icon: Icons.people,
                                color: AppColors.tealCyan,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildStatCard(
                                label: 'Comunidades',
                                value: '${_getStat("totalComunidades")}',
                                icon: Icons.location_city,
                                color: AppColors.mustardGold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                label: 'Coordinadores',
                                value: '${_getStat("totalCoordinadores")}',
                                icon: Icons.supervisor_account,
                                color: AppColors.coralRed,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildStatCard(
                                label: 'Apadrinados',
                                value: '${_getStat("totalApadrinados")}',
                                icon: Icons.child_care,
                                color: AppColors.sageGreen,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Estadísticas de actividades
                        const Text(
                          'Actividades',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.darkNavy,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                label: 'Total Actividades',
                                value: '${_getStat("totalActividades")}',
                                icon: Icons.assignment,
                                color: AppColors.darkNavy,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildStatCard(
                                label: 'Pendientes',
                                value: '${_getStat("actividadesPendientes")}',
                                icon: Icons.pending_actions,
                                color: AppColors.mustardGold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                label: 'En Proceso',
                                value: '${_getStat("actividadesEnProceso")}',
                                icon: Icons.hourglass_top,
                                color: AppColors.tealCyan,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildStatCard(
                                label: 'Completadas',
                                value: '${_getStat("actividadesCompletadas")}',
                                icon: Icons.check_circle,
                                color: AppColors.sageGreen,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Estadísticas de cartas
                        const Text(
                          'Cartas',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.darkNavy,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                label: 'Total Cartas',
                                value: '${_getStat("totalCartas")}',
                                icon: Icons.mail,
                                color: AppColors.coralRed,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildStatCard(
                                label: 'Borradores',
                                value: '${_getStat("cartasBorrador")}',
                                icon: Icons.edit_note,
                                color: AppColors.mustardGold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                label: 'Enviadas',
                                value: '${_getStat("cartasEnviadas")}',
                                icon: Icons.send,
                                color: AppColors.tealCyan,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildStatCard(
                                label: 'Aprobadas',
                                value: '${_getStat("cartasAprobadas")}',
                                icon: Icons.check_circle_outline,
                                color: AppColors.sageGreen,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Estadísticas de expedientes
                        const Text(
                          'Expedientes',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.darkNavy,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                label: 'Total Expedientes',
                                value: '${_getStat("totalExpedientes")}',
                                icon: Icons.folder,
                                color: AppColors.darkNavy,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildStatCard(
                                label: 'Documentos',
                                value: '${_getStat("totalDocumentos")}',
                                icon: Icons.description,
                                color: AppColors.tealCyan,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: color.withAlpha(30),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
