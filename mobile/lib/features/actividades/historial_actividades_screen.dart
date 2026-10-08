import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../shared/models/actividad.dart';
import '../../services/actividad_service.dart';
import '../../services/auth_service.dart';
import '../../../core/theme/app_theme.dart';

class HistorialActividadesScreen extends StatefulWidget {
  const HistorialActividadesScreen({super.key});

  @override
  State<HistorialActividadesScreen> createState() => _HistorialActividadesScreenState();
}

class _HistorialActividadesScreenState extends State<HistorialActividadesScreen> {
  final _actividadService = ActividadService();

  List<Actividad> _actividades = [];
  bool _isLoading = true;
  String _filtroEstado = 'TODAS';

  @override
  void initState() {
    super.initState();
    _cargarActividades();
  }

  Future<void> _cargarActividades() async {
    setState(() => _isLoading = true);
    try {
      final user = Provider.of<AuthService>(context, listen: false).currentUser;
      if (user?.apadrinadoId != null) {
        final actividades = await _actividadService.listarPorApadrinado(user!.apadrinadoId!);
        setState(() {
          _actividades = actividades;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar historial: $e'),
            backgroundColor: AppColors.coralRed,
          ),
        );
      }
    }
  }

  List<Actividad> get _actividadesFiltradas {
    if (_filtroEstado == 'TODAS') return _actividades;
    return _actividades.where((a) => a.estado == _filtroEstado).toList();
  }

  Color _getEstadoColor(String? estado) {
    switch (estado?.toUpperCase()) {
      case 'PENDIENTE':
        return AppColors.mustardGold;
      case 'EN_PROCESO':
        return AppColors.tealCyan;
      case 'ENTREGADA':
        return AppColors.darkNavy;
      case 'APROBADA':
        return AppColors.sageGreen;
      case 'CORRECCION_SOLICITADA':
        return AppColors.coralRed;
      default:
        return Colors.grey;
    }
  }

  String _getEstadoTexto(String? estado) {
    switch (estado?.toUpperCase()) {
      case 'PENDIENTE':
        return 'Pendiente';
      case 'EN_PROCESO':
        return 'En Proceso';
      case 'ENTREGADA':
        return 'Entregada';
      case 'APROBADA':
        return 'Aprobada';
      case 'CORRECCION_SOLICITADA':
        return 'Corrección Solicitada';
      default:
        return estado ?? 'Desconocido';
    }
  }

  @override
  Widget build(BuildContext context) {
    final aprobadas = _actividades.where((a) => a.estado == 'APROBADA').length;
    final pendientes = _actividades.where((a) => a.estado == 'PENDIENTE' || a.estado == 'EN_PROCESO').length;
    final total = _actividades.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Actividades'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarActividades,
          ),
        ],
      ),
      body: Column(
        children: [
          // Banner con estadísticas
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
              children: [
                const Text(
                  'Tu Progreso',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem('Total', '$total', AppColors.tealCyan),
                    _buildStatItem('Aprobadas', '$aprobadas', AppColors.sageGreen),
                    _buildStatItem('Pendientes', '$pendientes', AppColors.mustardGold),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Filtros
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _buildFiltroChip('TODAS'),
                _buildFiltroChip('PENDIENTE'),
                _buildFiltroChip('EN_PROCESO'),
                _buildFiltroChip('ENTREGADA'),
                _buildFiltroChip('APROBADA'),
                _buildFiltroChip('CORRECCION_SOLICITADA'),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Lista de actividades
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _actividadesFiltradas.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _cargarActividades,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          itemCount: _actividadesFiltradas.length,
                          itemBuilder: (context, index) {
                            final actividad = _actividadesFiltradas[index];
                            return _buildActividadCard(actividad);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildFiltroChip(String estado) {
    final isSelected = _filtroEstado == estado;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(estado),
        selected: isSelected,
        selectedColor: AppColors.darkNavy,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : AppColors.charcoal,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
        onSelected: (_) => setState(() => _filtroEstado = estado),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 60, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              'No hay actividades en el historial',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActividadCard(Actividad actividad) {
    final estadoColor = _getEstadoColor(actividad.estado);
    final estadoTexto = _getEstadoTexto(actividad.estado);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    actividad.titulo,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkNavy,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: estadoColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: estadoColor),
                  ),
                  child: Text(
                    estadoTexto,
                    style: TextStyle(
                      color: estadoColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              actividad.descripcion ?? 'Sin descripción',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 12, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  'Fecha límite: ${actividad.fechaLimite ?? "Sin fecha"}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
