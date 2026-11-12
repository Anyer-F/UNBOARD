import 'package:flutter/material.dart';

import '../../../core/constants/app_radius.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/comunidad.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/states.dart';
import '../../../services/comunidad_service.dart';
import 'comunidad_detalle_screen.dart';
import 'comunidad_form_dialog.dart';

/// Comunidades bajo la responsabilidad del Coordinador.
class ComunidadesScreen extends StatefulWidget {
  const ComunidadesScreen({super.key});

  @override
  State<ComunidadesScreen> createState() => _ComunidadesScreenState();
}

class _ComunidadesScreenState extends State<ComunidadesScreen> {
  final _servicio = ComunidadService();

  List<Comunidad> _comunidades = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _isLoading = _comunidades.isEmpty;
      _error = null;
    });
    try {
      final lista = await _servicio.listar();
      if (mounted) {
        setState(() {
          _comunidades = lista;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = mensajeDeError(e);
        });
      }
    }
  }

  Future<void> _nueva() async {
    final creada = await mostrarFormularioComunidad(context);
    if (creada != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Comunidad "${creada.nombre}" creada con su Módulo 1.')),
      );
      _cargar();
    }
  }

  Future<void> _abrir(Comunidad c) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ComunidadDetalleScreen(comunidadId: c.id)),
    );
    if (mounted) _cargar();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const LoadingState(message: 'Cargando comunidades...');
    }
    if (_error != null && _comunidades.isEmpty) {
      return ErrorState(title: 'No se pudieron cargar las comunidades', message: _error, onRetry: _cargar);
    }

    return RefreshIndicator(
      onRefresh: _cargar,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final horizontal = constraints.maxWidth >= 600 ? 24.0 : 16.0;
          final ancho = (constraints.maxWidth - horizontal * 2).clamp(0.0, 1100.0);
          final columnas = ancho >= 900 ? 3 : (ancho >= 560 ? 2 : 1);
          final anchoTarjeta = ((ancho - AppSpacing.md * (columnas - 1)) / columnas).floorToDouble();

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(horizontal, 16, horizontal, 32),
            child: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: ancho,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _comunidades.length == 1
                                ? '1 comunidad bajo tu responsabilidad'
                                : '${_comunidades.length} comunidades bajo tu responsabilidad',
                            style: const TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _nueva,
                          icon: const Icon(Icons.add),
                          label: const Text('Nueva comunidad'),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (_comunidades.isEmpty)
                      const EmptyState(
                        icon: Icons.location_city_outlined,
                        title: 'Sin comunidades',
                        description: 'Crea una comunidad para comenzar a organizar a tus apadrinados',
                      )
                    else
                      Wrap(
                        spacing: AppSpacing.md,
                        runSpacing: AppSpacing.md,
                        children: [
                          for (final c in _comunidades)
                            SizedBox(
                              width: anchoTarjeta,
                              child: _ComunidadCard(comunidad: c, onTap: () => _abrir(c)),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ComunidadCard extends StatelessWidget {
  final Comunidad comunidad;
  final VoidCallback onTap;

  const _ComunidadCard({required this.comunidad, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = comunidad;
    return AppCard(
      onTap: onTap,
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.tealCyan.withAlpha(20),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(Icons.location_city_outlined, color: AppColors.tealCyan),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.nombre,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.charcoal),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (c.ubicacion.isNotEmpty)
                      Text(
                        c.ubicacion,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textTertiary),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              _Pastilla(icon: Icons.people_outline, texto: '${c.totalApadrinados ?? 0} apadrinados'),
              _Pastilla(icon: Icons.view_module_outlined, texto: '${c.totalModulos ?? 0} módulos'),
              _Pastilla(
                icon: c.ingresoDirecto ? Icons.login : Icons.how_to_reg_outlined,
                texto: c.ingresoDirecto ? 'Ingreso directo' : 'Con solicitud',
                color: c.ingresoDirecto ? AppColors.sageGreen : AppColors.darkNavy,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pastilla extends StatelessWidget {
  final IconData icon;
  final String texto;
  final Color color;

  const _Pastilla({required this.icon, required this.texto, this.color = AppColors.textSecondary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(texto, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

