import 'package:flutter/material.dart';
import '../../shared/models/carta.dart';
import '../../services/carta_service.dart';
import '../../../core/theme/app_theme.dart';

class RevisarCartasScreen extends StatefulWidget {
  const RevisarCartasScreen({super.key});

  @override
  State<RevisarCartasScreen> createState() => _RevisarCartasScreenState();
}

class _RevisarCartasScreenState extends State<RevisarCartasScreen> {
  final _cartaService = CartaService();

  List<Carta> _cartas = [];
  bool _isLoading = true;
  String _filtroEstado = 'TODAS';

  @override
  void initState() {
    super.initState();
    _cargarCartas();
  }

  Future<void> _cargarCartas() async {
    setState(() => _isLoading = true);
    try {
      final cartas = await _cartaService.listarTodas();
      setState(() {
        _cartas = cartas;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar cartas: $e'),
            backgroundColor: AppColors.coralRed,
          ),
        );
      }
    }
  }

  List<Carta> get _cartasFiltradas {
    if (_filtroEstado == 'TODAS') return _cartas;
    return _cartas.where((c) => c.estado == _filtroEstado).toList();
  }

  Color _getEstadoColor(String estado) {
    switch (estado) {
      case 'BORRADOR':
        return Colors.grey;
      case 'ENVIADA':
        return AppColors.tealCyan;
      case 'RECIBIDA':
        return AppColors.darkNavy;
      case 'APROBADA':
        return AppColors.sageGreen;
      case 'RECHAZADA':
        return AppColors.coralRed;
      default:
        return Colors.grey;
    }
  }

  String _getEstadoTexto(String estado) {
    switch (estado) {
      case 'BORRADOR':
        return 'Borrador';
      case 'ENVIADA':
        return 'Enviada';
      case 'RECIBIDA':
        return 'Recibida';
      case 'APROBADA':
        return 'Aprobada';
      case 'RECHAZADA':
        return 'Rechazada';
      default:
        return estado;
    }
  }

  Future<void> _aprobarCarta(Carta carta) async {
    try {
      await _cartaService.cambiarEstado(carta.id, 'APROBADA');
      _cargarCartas();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Carta aprobada correctamente'),
            backgroundColor: AppColors.sageGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al aprobar carta: $e'),
            backgroundColor: AppColors.coralRed,
          ),
        );
      }
    }
  }

  Future<void> _rechazarCarta(Carta carta) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rechazar Carta'),
        content: const Text('¿Estás seguro de que deseas rechazar esta carta?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.coralRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await _cartaService.cambiarEstado(carta.id, 'RECHAZADA');
        _cargarCartas();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Carta rechazada'),
              backgroundColor: AppColors.coralRed,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al rechazar carta: $e'),
              backgroundColor: AppColors.coralRed,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Revisar Cartas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarCartas,
          ),
        ],
      ),
      body: Column(
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
                Text(
                  'Total: ${_cartas.length} cartas',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Revisa y gestiona las cartas de tus apadrinados',
                  style: TextStyle(
                    color: Colors.white.withAlpha(200),
                    fontSize: 13,
                  ),
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
                _buildFiltroChip('BORRADOR'),
                _buildFiltroChip('ENVIADA'),
                _buildFiltroChip('RECIBIDA'),
                _buildFiltroChip('APROBADA'),
                _buildFiltroChip('RECHAZADA'),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Lista de cartas
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _cartasFiltradas.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _cargarCartas,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          itemCount: _cartasFiltradas.length,
                          itemBuilder: (context, index) {
                            final carta = _cartasFiltradas[index];
                            return _buildCartaCard(carta);
                          },
                        ),
                      ),
          ),
        ],
      ),
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
            Icon(Icons.mail_outline, size: 60, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              'No hay cartas para revisar',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartaCard(Carta carta) {
    final estadoColor = _getEstadoColor(carta.estado);
    final estadoTexto = _getEstadoTexto(carta.estado);

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
                    carta.titulo,
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
              carta.contenido,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.person, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  'De: ${carta.apadrinadoNombre ?? "Anónimo"}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const Spacer(),
                Text(
                  carta.fechaCreacion ?? '',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
            if (carta.estado == 'ENVIADA' || carta.estado == 'RECIBIDA') ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.coralRed,
                      side: const BorderSide(color: AppColors.coralRed),
                    ),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Rechazar'),
                    onPressed: () => _rechazarCarta(carta),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.sageGreen,
                    ),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Aprobar'),
                    onPressed: () => _aprobarCarta(carta),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
