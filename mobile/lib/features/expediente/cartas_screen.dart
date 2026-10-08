import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../shared/models/carta.dart';
import '../../services/carta_service.dart';
import '../../services/auth_service.dart';
import '../../../core/theme/app_theme.dart';

class CartasScreen extends StatefulWidget {
  const CartasScreen({super.key});

  @override
  State<CartasScreen> createState() => _CartasScreenState();
}

class _CartasScreenState extends State<CartasScreen> {
  final _cartaService = CartaService();
  final _searchController = TextEditingController();

  List<Carta> _cartas = [];
  bool _isLoading = true;
  String _filtroEstado = 'TODAS';

  @override
  void initState() {
    super.initState();
    _cargarCartas();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _cargarCartas() async {
    setState(() => _isLoading = true);
    try {
      final user = Provider.of<AuthService>(context, listen: false).currentUser;
      final apadrinadoId = user?.apadrinadoId;

      if (apadrinadoId != null) {
        final cartas = await _cartaService.listarPorApadrinado(apadrinadoId);
        setState(() {
          _cartas = cartas;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
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
    var filtradas = _cartas;

    // Filtro por estado
    if (_filtroEstado != 'TODAS') {
      filtradas = filtradas.where((c) => c.estado == _filtroEstado).toList();
    }

    // Filtro por búsqueda
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      filtradas = filtradas.where((c) {
        return c.titulo.toLowerCase().contains(query) ||
            c.contenido.toLowerCase().contains(query);
      }).toList();
    }

    return filtradas;
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

  Future<void> _eliminarCarta(Carta carta) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Carta'),
        content: const Text('¿Estás seguro de que deseas eliminar esta carta? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.coralRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await _cartaService.eliminar(carta.id);
        _cargarCartas();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Carta eliminada correctamente'),
              backgroundColor: AppColors.sageGreen,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al eliminar: $e'),
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
        title: const Text('Mis Cartas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarCartas,
          ),
        ],
      ),
      body: Column(
        children: [
          // Banner informativo
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
                  'Gestión de Cartas',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Escribe y envía tus cartas a tu padrino o coordinador',
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
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Buscar cartas...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Filtros por estado
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
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.tealCyan,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.edit),
        label: const Text('Nueva Carta', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () async {
          final creada = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CartaCrearScreen()),
          );
          if (creada == true) _cargarCartas();
        },
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
            Text(
              _filtroEstado == 'TODAS'
                  ? 'No hay cartas aún.'
                  : 'No hay cartas con estado $_filtroEstado.',
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.tealCyan),
              icon: const Icon(Icons.edit),
              label: const Text('Escribir Primera Carta'),
              onPressed: () async {
                final creada = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CartaCrearScreen()),
                );
                if (creada == true) _cargarCartas();
              },
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
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          final actualizado = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => CartaDetalleScreen(carta: carta)),
          );
          if (actualizado == true) _cargarCartas();
        },
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
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
                  height: 1.3,
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
                    carta.fechaCreacion ?? 'Sin fecha',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                  const Spacer(),
                  if (carta.isBorrador)
                    TextButton.icon(
                      icon: const Icon(Icons.send, size: 14),
                      label: const Text('Enviar', style: TextStyle(fontSize: 12)),
                      onPressed: () async {
                        try {
                          await _cartaService.enviarCarta(carta.id);
                          _cargarCartas();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Carta enviada correctamente'),
                                backgroundColor: AppColors.sageGreen,
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error al enviar: $e'),
                                backgroundColor: AppColors.coralRed,
                              ),
                            );
                          }
                        }
                      },
                    ),
                  if (carta.isBorrador)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.coralRed),
                      onPressed: () => _eliminarCarta(carta),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== PANTALLA DE CREAR CARTA ====================

class CartaCrearScreen extends StatefulWidget {
  const CartaCrearScreen({super.key});

  @override
  State<CartaCrearScreen> createState() => _CartaCrearScreenState();
}

class _CartaCrearScreenState extends State<CartaCrearScreen> {
  final _cartaService = CartaService();
  final _tituloController = TextEditingController();
  final _contenidoController = TextEditingController();
  final _observacionesController = TextEditingController();

  String _tipoCarta = 'GENERAL';
  bool _isSubmitting = false;

  final List<String> _tiposCarta = [
    'GENERAL',
    'CARTA_PADRINO',
    'CARTA_APADRINADO',
    'CUMPLEAÑOS',
    'GRACIAS',
    'NAVIDAD',
    'PERSONAL',
  ];

  @override
  void dispose() {
    _tituloController.dispose();
    _contenidoController.dispose();
    _observacionesController.dispose();
    super.dispose();
  }

  Future<void> _guardarCarta() async {
    if (_tituloController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El título es obligatorio'),
          backgroundColor: AppColors.coralRed,
        ),
      );
      return;
    }

    if (_contenidoController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El contenido de la carta es obligatorio'),
          backgroundColor: AppColors.coralRed,
        ),
      );
      return;
    }

    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    final apadrinadoId = user?.apadrinadoId;

    if (apadrinadoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo obtener tu información de apadrinado'),
          backgroundColor: AppColors.coralRed,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await _cartaService.crear(
        titulo: _tituloController.text.trim(),
        contenido: _contenidoController.text.trim(),
        apadrinadoId: apadrinadoId,
        tipoCarta: _tipoCarta,
        observaciones: _observacionesController.text.trim().isNotEmpty
            ? _observacionesController.text.trim()
            : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Carta guardada como borrador'),
            backgroundColor: AppColors.sageGreen,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar carta: $e'),
            backgroundColor: AppColors.coralRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nueva Carta'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Escribe tu carta',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.darkNavy,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Redacta tu carta a tu padrino o coordinador. Puedes guardarla como borrador y enviarla después.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),

            // Título
            const Text(
              'Título de la carta',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.darkNavy,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _tituloController,
              decoration: const InputDecoration(
                hintText: 'Ej: Carta de agradecimiento, Informe de avances...',
              ),
            ),
            const SizedBox(height: 16),

            // Tipo de carta
            const Text(
              'Tipo de carta',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.darkNavy,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _tipoCarta,
              decoration: const InputDecoration(
                hintText: 'Selecciona el tipo de carta',
              ),
              items: _tiposCarta.map((tipo) {
                return DropdownMenuItem(
                  value: tipo,
                  child: Text(tipo.replaceAll('_', ' ')),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _tipoCarta = value);
                }
              },
            ),
            const SizedBox(height: 16),

            // Contenido
            const Text(
              'Contenido de la carta',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.darkNavy,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _contenidoController,
              maxLines: 10,
              decoration: const InputDecoration(
                hintText: 'Querido padrino,\n\nTe escribo para contarte sobre mis avances...',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),

            // Observaciones
            const Text(
              'Observaciones (opcional)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.darkNavy,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _observacionesController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Notas adicionales para el coordinador...',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 30),

            // Botón guardar
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.darkNavy),
                onPressed: _isSubmitting ? null : _guardarCarta,
                icon: _isSubmitting
                    ? const SizedBox.shrink()
                    : const Icon(Icons.save),
                label: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Guardar Carta'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== PANTALLA DE DETALLE DE CARTA ====================

class CartaDetalleScreen extends StatefulWidget {
  final Carta carta;

  const CartaDetalleScreen({super.key, required this.carta});

  @override
  State<CartaDetalleScreen> createState() => _CartaDetalleScreenState();
}

class _CartaDetalleScreenState extends State<CartaDetalleScreen> {
  final _cartaService = CartaService();
  late Carta _carta;
  bool _isEditing = false;
  bool _isSubmitting = false;

  final _tituloController = TextEditingController();
  final _contenidoController = TextEditingController();
  final _observacionesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _carta = widget.carta;
    _tituloController.text = _carta.titulo;
    _contenidoController.text = _carta.contenido;
    _observacionesController.text = _carta.observaciones ?? '';
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _contenidoController.dispose();
    _observacionesController.dispose();
    super.dispose();
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

  Future<void> _enviarCarta() async {
    setState(() => _isSubmitting = true);
    try {
      final actualizada = await _cartaService.enviarCarta(_carta.id);
      setState(() {
        _carta = actualizada;
        _isSubmitting = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Carta enviada correctamente'),
            backgroundColor: AppColors.sageGreen,
          ),
        );
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al enviar: $e'),
            backgroundColor: AppColors.coralRed,
          ),
        );
      }
    }
  }

  Future<void> _guardarCambios() async {
    setState(() => _isSubmitting = true);
    try {
      final actualizada = await _cartaService.actualizar(
        id: _carta.id,
        titulo: _tituloController.text.trim(),
        contenido: _contenidoController.text.trim(),
        observaciones: _observacionesController.text.trim().isNotEmpty
            ? _observacionesController.text.trim()
            : null,
      );
      setState(() {
        _carta = actualizada;
        _isEditing = false;
        _isSubmitting = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Carta actualizada correctamente'),
            backgroundColor: AppColors.sageGreen,
          ),
        );
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar: $e'),
            backgroundColor: AppColors.coralRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final estadoColor = _getEstadoColor(_carta.estado);
    final estadoTexto = _getEstadoTexto(_carta.estado);

    return Scaffold(
      appBar: AppBar(
        title: Text(_carta.titulo),
        actions: [
          if (_carta.isBorrador && !_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditing = true),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Estado
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: estadoColor.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: estadoColor),
              ),
              child: Text(
                estadoTexto,
                style: TextStyle(
                  color: estadoColor,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),

            if (_isEditing) ...[
              // Modo edición
              TextField(
                controller: _tituloController,
                decoration: const InputDecoration(
                  labelText: 'Título',
                ),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _contenidoController,
                maxLines: 12,
                decoration: const InputDecoration(
                  labelText: 'Contenido',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _observacionesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Observaciones',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => setState(() => _isEditing = false),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.darkNavy),
                      onPressed: _isSubmitting ? null : _guardarCambios,
                      child: _isSubmitting
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Guardar'),
                    ),
                  ),
                ],
              ),
            ] else ...[
              // Modo lectura
              const Text(
                'Título',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _carta.titulo,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkNavy,
                ),
              ),
              const SizedBox(height: 16),

              const Text(
                'Contenido',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Text(
                  _carta.contenido,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ),

              if (_carta.observaciones != null && _carta.observaciones!.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Observaciones',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.mustardGold.withAlpha(15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.mustardGold.withAlpha(50)),
                  ),
                  child: Text(
                    _carta.observaciones!,
                    style: const TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    'Creada: ${_carta.fechaCreacion ?? "Sin fecha"}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
              if (_carta.fechaEnvio != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.send, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      'Enviada: ${_carta.fechaEnvio}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 30),

              if (_carta.isBorrador) ...[
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.tealCyan),
                    onPressed: _isSubmitting ? null : _enviarCarta,
                    icon: _isSubmitting
                        ? const SizedBox.shrink()
                        : const Icon(Icons.send),
                    label: _isSubmitting
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Enviar Carta'),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
