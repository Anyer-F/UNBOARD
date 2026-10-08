import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../shared/models/actividad.dart';
import '../../shared/models/apadrinado.dart';
import '../../services/actividad_service.dart';
import '../../services/auth_service.dart';
import '../../services/expediente_service.dart';
import '../../../core/theme/app_theme.dart';

class EstadisticasScreen extends StatefulWidget {
  const EstadisticasScreen({super.key});

  @override
  State<EstadisticasScreen> createState() => _EstadisticasScreenState();
}

class _EstadisticasScreenState extends State<EstadisticasScreen> {
  final _actividadService = ActividadService();
  final _expedienteService = ExpedienteService();

  List<Actividad> _actividades = [];
  List<Apadrinado> _apadrinados = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    try {
      final user = Provider.of<AuthService>(context, listen: false).currentUser;
      if (user?.coordinadorId != null) {
        final actividades = await _actividadService.listarPorCoordinador(user!.coordinadorId!);
        final apadrinados = await _expedienteService.listarApadrinadosPorCoordinador(user.coordinadorId!);
        setState(() {
          _actividades = actividades;
          _apadrinados = apadrinados;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar estadísticas: $e'),
            backgroundColor: AppColors.coralRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalActividades = _actividades.length;
    final pendientes = _actividades.where((a) => a.estado == 'PENDIENTE').length;
    final enProceso = _actividades.where((a) => a.estado == 'EN_PROCESO').length;
    final entregadas = _actividades.where((a) => a.estado == 'ENTREGADA').length;
    final aprobadas = _actividades.where((a) => a.estado == 'APROBADA').length;
    final correcciones = _actividades.where((a) => a.estado == 'CORRECCION_SOLICITADA').length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Estadísticas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarDatos,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.darkNavy,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Panel de Estadísticas',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Resumen de actividad del programa',
                          style: TextStyle(
                            color: Colors.white.withAlpha(200),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Métricas principales
                  const Text(
                    'Métricas Generales',
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
                        child: _buildMetricCard(
                          'Apadrinados',
                          '${_apadrinados.length}',
                          Icons.people,
                          AppColors.tealCyan,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMetricCard(
                          'Actividades',
                          '$totalActividades',
                          Icons.assignment,
                          AppColors.coralRed,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Estado de actividades
                  const Text(
                    'Estado de Actividades',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkNavy,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildEstadoCard('Pendientes', pendientes, totalActividades, AppColors.mustardGold),
                  _buildEstadoCard('En Proceso', enProceso, totalActividades, AppColors.tealCyan),
                  _buildEstadoCard('Entregadas', entregadas, totalActividades, AppColors.darkNavy),
                  _buildEstadoCard('Aprobadas', aprobadas, totalActividades, AppColors.sageGreen),
                  _buildEstadoCard('Correcciones', correcciones, totalActividades, AppColors.coralRed),

                  const SizedBox(height: 20),

                  // Distribución por comunidad
                  const Text(
                    'Distribución por Comunidad',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkNavy,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._buildComunidadStats(),

                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEstadoCard(String label, int count, int total, Color color) {
    final percentage = total > 0 ? (count / total * 100).toStringAsFixed(1) : '0.0';
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
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.charcoal,
              ),
            ),
          ),
          Text(
            '$count ($percentage%)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildComunidadStats() {
    final comunidadCount = <String, int>{};
    for (final apadrinado in _apadrinados) {
      final comunidad = apadrinado.comunidadNombre ?? 'Sin asignar';
      comunidadCount[comunidad] = (comunidadCount[comunidad] ?? 0) + 1;
    }

    if (comunidadCount.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: const Center(
            child: Text(
              'No hay datos de comunidades',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ),
      ];
    }

    return comunidadCount.entries.map((entry) {
      final percentage = (entry.value / _apadrinados.length * 100).toStringAsFixed(1);
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
            const Icon(Icons.location_on, size: 20, color: AppColors.tealCyan),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                entry.key,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.charcoal,
                ),
              ),
            ),
            Text(
              '${entry.value} ($percentage%)',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.darkNavy,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}
