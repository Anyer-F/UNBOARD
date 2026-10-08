import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../shared/models/apadrinado.dart';
import '../../services/auth_service.dart';
import '../../services/expediente_service.dart';
import '../../../core/theme/app_theme.dart';
import '../expediente/expediente_detalle_screen.dart';

class ApadrinadosListScreen extends StatefulWidget {
  final bool embedded;

  const ApadrinadosListScreen({super.key, this.embedded = false});

  @override
  State<ApadrinadosListScreen> createState() => _ApadrinadosListScreenState();
}

class _ApadrinadosListScreenState extends State<ApadrinadosListScreen> {
  final _expedienteService = ExpedienteService();
  final _searchController = TextEditingController();

  List<Apadrinado> _apadrinados = [];
  List<Apadrinado> _apadrinadosFiltrados = [];
  bool _isLoading = true;
  String _filtroComunidad = 'Todas';

  @override
  void initState() {
    super.initState();
    _cargarApadrinados();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _cargarApadrinados() async {
    setState(() => _isLoading = true);
    try {
      final user = Provider.of<AuthService>(context, listen: false).currentUser;
      if (user?.coordinadorId != null) {
        final apadrinados = await _expedienteService.listarApadrinadosPorCoordinador(user!.coordinadorId!);
        if (!mounted) return;
        setState(() {
          _apadrinados = apadrinados;
          _apadrinadosFiltrados = apadrinados;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar apadrinados: $e'),
            backgroundColor: AppColors.coralRed,
          ),
        );
      }
    }
  }

  void _filtrarApadrinados(String query) {
    setState(() {
      _apadrinadosFiltrados = _apadrinados.where((a) {
        final nombre = a.nombre?.toLowerCase() ?? '';
        final comunidad = a.comunidadNombre?.toLowerCase() ?? '';
        final correo = a.correo?.toLowerCase() ?? '';
        final matchQuery = nombre.contains(query.toLowerCase()) ||
            comunidad.contains(query.toLowerCase()) ||
            correo.contains(query.toLowerCase());
        final matchComunidad = _filtroComunidad == 'Todas' ||
            a.comunidadNombre == _filtroComunidad;
        return matchQuery && matchComunidad;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
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
                'Total: ${_apadrinados.length} apadrinados',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Gestiona la información de tus apadrinados',
                style: TextStyle(
                  color: Colors.white.withAlpha(200),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Buscador
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: TextField(
            controller: _searchController,
            onChanged: _filtrarApadrinados,
            decoration: InputDecoration(
              hintText: 'Buscar por nombre, comunidad o correo...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        _filtrarApadrinados('');
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Filtro por comunidad
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              _buildFiltroChip('Todas'),
              ..._apadrinados
                  .map((a) => a.comunidadNombre)
                  .where((c) => c != null)
                  .toSet()
                  .map((c) => _buildFiltroChip(c!)),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Lista de apadrinados
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _apadrinadosFiltrados.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _cargarApadrinados,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        itemCount: _apadrinadosFiltrados.length,
                        itemBuilder: (context, index) {
                          final apadrinado = _apadrinadosFiltrados[index];
                          return _buildApadrinadoCard(apadrinado);
                        },
                      ),
                    ),
        ),
      ],
    );

    if (widget.embedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Apadrinados'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarApadrinados,
          ),
        ],
      ),
      body: content,
    );
  }

  Widget _buildFiltroChip(String comunidad) {
    final isSelected = _filtroComunidad == comunidad;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(comunidad),
        selected: isSelected,
        selectedColor: AppColors.darkNavy,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : AppColors.charcoal,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
        onSelected: (_) {
          setState(() => _filtroComunidad = comunidad);
          _filtrarApadrinados(_searchController.text);
        },
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
            Icon(Icons.people_outline, size: 60, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              'No se encontraron apadrinados',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApadrinadoCard(Apadrinado apadrinado) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ExpedienteDetalleScreen(apadrinadoId: apadrinado.id),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.darkNavy.withAlpha(20),
                child: const Icon(Icons.person, color: AppColors.darkNavy, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      apadrinado.nombre ?? 'Apadrinado',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkNavy,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Comunidad: ${apadrinado.comunidadNombre ?? "Sin asignar"}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      apadrinado.correo ?? '',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
