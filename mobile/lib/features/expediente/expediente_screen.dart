import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_radius.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/responsive.dart';
import '../../../shared/models/actividad.dart';
import '../../../shared/models/carta.dart';
import '../../../shared/models/documento.dart';
import '../../../shared/models/expediente.dart';
import '../../../shared/models/historial_actividad.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/cards.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../../shared/widgets/states.dart';
import '../../../services/actividad_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/carta_service.dart';
import '../../../services/expediente_service.dart';

/// Expediente digital del Apadrinado (especificación §15).
///
/// Funciona como una carpeta digital organizada:
/// encabezado con fotografía, nombre, comunidad y estado;
/// después pestañas con Datos, Actividades, Documentos,
/// Fotografías, Cartas y Historial.
class ExpedienteScreen extends StatefulWidget {
  const ExpedienteScreen({super.key});

  @override
  State<ExpedienteScreen> createState() => _ExpedienteScreenState();
}

class _ExpedienteScreenState extends State<ExpedienteScreen>
    with SingleTickerProviderStateMixin {
  final _expedienteService = ExpedienteService();
  final _cartaService = CartaService();
  final _actividadService = ActividadService();

  Expediente? _expediente;
  List<Carta> _cartas = [];
  List<HistorialActividad> _historial = [];
  bool _isLoading = true;
  String? _error;

  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _cargarDatos();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    if (user?.apadrinadoId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final exp = await _expedienteService.obtenerPorApadrinadoId(
        user!.apadrinadoId!,
      );
      final cartas = await _cartaService.listarPorApadrinado(user.apadrinadoId!);
      final historial =
          await _actividadService.obtenerHistorialPorApadrinado(user.apadrinadoId!);

      if (mounted) {
        setState(() {
          _expediente = exp;
          _cartas = cartas;
          _historial = historial;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  List<Documento> get _documentos => _expediente?.documentos ?? [];

  List<Documento> get _fotografias =>
      _documentos.where((d) => d.isImage).toList();

  List<Actividad> get _actividades => _expediente?.actividades ?? [];

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const LoadingState(message: 'Cargando expediente...');
    }

    if (_error != null && _expediente == null) {
      return ErrorState(
        title: 'No se pudo cargar el expediente',
        message: _error,
        onRetry: _cargarDatos,
      );
    }

    final apadrinado = _expediente?.apadrinado;

    return RefreshIndicator(
      onRefresh: _cargarDatos,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: Responsive.screenPadding(context).copyWith(
              top: AppSpacing.lg,
              bottom: AppSpacing.xxl,
            ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: Responsive.maxContentWidth(context),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Encabezado del expediente
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  children: [
                    InitialsAvatar(
                      name: apadrinado?.nombre ?? 'A',
                      size: 64,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      apadrinado?.nombre ?? 'Apadrinado',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.charcoal,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      apadrinado?.comunidadNombre ?? 'Sin comunidad',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    StatusChip(
                      estado: 'ACTIVO',
                      customText: 'Expediente activo',
                      color: AppColors.sageGreen,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _CountTile(
                          value: '${_documentos.length}',
                          label: 'Documentos',
                        ),
                        _CountTile(
                          value: '${_actividades.length}',
                          label: 'Actividades',
                        ),
                        _CountTile(
                          value: '${_cartas.length}',
                          label: 'Cartas',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Pestañas
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      tabAlignment: TabAlignment.center,
                      dividerColor: AppColors.borderLight,
                      labelStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      tabs: const [
                        Tab(text: 'Datos'),
                        Tab(text: 'Actividades'),
                        Tab(text: 'Documentos'),
                        Tab(text: 'Fotografías'),
                        Tab(text: 'Cartas'),
                        Tab(text: 'Historial'),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(
                      height: 420,
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _DatosTab(apadrinado: apadrinado),
                          _ActividadesTab(actividades: _actividades),
                          _DocumentosTab(documentos: _documentos),
                          _FotografiasTab(fotografias: _fotografias),
                          _CartasTab(cartas: _cartas),
                          _HistorialTab(historial: _historial),
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
    );
  }
}

class _CountTile extends StatelessWidget {
  final String value;
  final String label;

  const _CountTile({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.darkNavy,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// Datos personales.
class _DatosTab extends StatelessWidget {
  final dynamic apadrinado;

  const _DatosTab({required this.apadrinado});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      children: [
        InfoTile(
          icon: Icons.person_outline,
          label: 'Nombre',
          value: apadrinado?.nombre ?? 'No disponible',
        ),
        const Divider(height: 1, indent: 60),
        InfoTile(
          icon: Icons.email_outlined,
          label: 'Correo',
          value: apadrinado?.correo ?? 'No disponible',
        ),
        const Divider(height: 1, indent: 60),
        InfoTile(
          icon: Icons.location_city_outlined,
          label: 'Comunidad',
          value: apadrinado?.comunidadNombre ?? 'No asignada',
        ),
        const Divider(height: 1, indent: 60),
        InfoTile(
          icon: Icons.person_pin_outlined,
          label: 'Coordinador',
          value: apadrinado?.coordinadorNombre ?? 'No asignado',
        ),
      ],
    );
  }
}

/// Actividades del expediente.
class _ActividadesTab extends StatelessWidget {
  final List<Actividad> actividades;

  const _ActividadesTab({required this.actividades});

  @override
  Widget build(BuildContext context) {
    if (actividades.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: EmptyState(
            icon: Icons.assignment_outlined,
            title: 'Sin actividades',
            description: 'Las actividades asignadas aparecerán aquí',
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      itemCount: actividades.length,
      itemBuilder: (context, index) {
        final act = actividades[index];
        return ActivityCard(actividad: act);
      },
    );
  }
}

/// Documentos del expediente.
class _DocumentosTab extends StatelessWidget {
  final List<Documento> documentos;

  const _DocumentosTab({required this.documentos});

  @override
  Widget build(BuildContext context) {
    if (documentos.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: EmptyState(
            icon: Icons.description_outlined,
            title: 'Sin documentos',
            description: 'Los documentos subirán aquí',
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      itemCount: documentos.length,
      itemBuilder: (context, index) {
        final doc = documentos[index];
        return DocumentCard(documento: doc);
      },
    );
  }
}

/// Fotografías del expediente.
class _FotografiasTab extends StatelessWidget {
  final List<Documento> fotografias;

  const _FotografiasTab({required this.fotografias});

  @override
  Widget build(BuildContext context) {
    if (fotografias.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: EmptyState(
            icon: Icons.photo_library_outlined,
            title: 'Sin fotografías',
            description: 'Las fotografías que subas aparecerán aquí',
          ),
        ),
      );
    }

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: Responsive.gridColumns(
          context,
          phoneColumns: 2,
          tabletColumns: 4,
        ),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: fotografias.length,
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: const Center(
            child: Icon(
              Icons.image_outlined,
              color: AppColors.textSecondary,
            ),
          ),
        );
      },
    );
  }
}

/// Cartas del expediente.
class _CartasTab extends StatelessWidget {
  final List<Carta> cartas;

  const _CartasTab({required this.cartas});

  @override
  Widget build(BuildContext context) {
    if (cartas.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: EmptyState(
            icon: Icons.mail_outline,
            title: 'Sin cartas',
            description: 'Las cartas escritas aparecerán aquí',
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      itemCount: cartas.length,
      itemBuilder: (context, index) {
        final carta = cartas[index];
        return AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
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
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  StatusChip(estado: carta.estado),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                carta.contenido,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                AppDateUtils.formatDate(carta.fechaCreacion),
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Historial de cambios (línea temporal vertical, §29).
class _HistorialTab extends StatelessWidget {
  final List<HistorialActividad> historial;

  const _HistorialTab({required this.historial});

  @override
  Widget build(BuildContext context) {
    if (historial.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: EmptyState(
            icon: Icons.history_outlined,
            title: 'Sin historial',
            description: 'Los cambios aparecerán aquí',
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      itemCount: historial.length,
      itemBuilder: (context, index) {
        final h = historial[index];
        final esUltimo = index == historial.length - 1;

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Línea temporal
              Column(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: AppColors.darkNavy,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 2,
                      ),
                    ),
                  ),
                  if (!esUltimo)
                    Expanded(
                      child: Container(
                        width: 2,
                        color: AppColors.borderLight,
                      ),
                    ),
                ],
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        h.accion,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.charcoal,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          h.modificadoPorNombre ?? 'Sistema',
                          AppDateUtils.formatDateTime(h.fechaHora),
                        ].join(' · '),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (h.observaciones != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          h.observaciones!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                      if (h.estadoNuevo.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xs),
                        StatusChip(estado: h.estadoNuevo),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
