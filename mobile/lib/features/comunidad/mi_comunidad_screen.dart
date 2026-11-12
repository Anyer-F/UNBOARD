import 'package:flutter/material.dart';

import '../../core/constants/app_radius.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../services/comunidad_service.dart';
import '../../shared/models/modulo.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../shared/widgets/states.dart';
import 'modulo_apadrinado_screen.dart';

/// Comunidad del apadrinado: su coordinador responsable y los módulos
/// en el orden definido por el coordinador.
class MiComunidadContent extends StatefulWidget {
  const MiComunidadContent({super.key});

  @override
  State<MiComunidadContent> createState() => _MiComunidadContentState();
}

class _MiComunidadContentState extends State<MiComunidadContent> {
  final _service = ComunidadService();
  MiComunidad? _datos;
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = _datos == null;
      _error = null;
    });
    try {
      final datos = await _service.miComunidad();
      if (!mounted) return;
      setState(() {
        _datos = datos;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = mensajeDeError(e);
        _cargando = false;
      });
    }
  }

  Future<void> _abrirModulo(ModuloContenido contenido) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ModuloApadrinadoScreen(contenido: contenido)),
    );
    if (mounted) _cargar();
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const LoadingState(message: 'Cargando tu comunidad...');
    if (_datos == null) {
      return ErrorState(title: 'No se pudo cargar tu comunidad', message: _error, onRetry: _cargar);
    }
    final d = _datos!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columnas = constraints.maxWidth >= 900 ? 3 : constraints.maxWidth >= 600 ? 2 : 1;
        return RefreshIndicator(
          onRefresh: _cargar,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.xxl),
            child: ResponsiveContent(
              maxWidth: 1100,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _EncabezadoComunidad(datos: d),
                  const SizedBox(height: AppSpacing.xl),
                  SectionHeader(
                    title: 'Módulos',
                    subtitle: '${d.modulos.length} módulo(s) de tu comunidad',
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (d.modulos.isEmpty)
                    const EmptyState(
                      icon: Icons.folder_off_outlined,
                      title: 'Aún no hay módulos',
                      description: 'Tu coordinador todavía no ha publicado actividades.',
                    )
                  else
                    _Cuadricula(
                      columnas: columnas,
                      children: [
                        for (final m in d.modulos) _ModuloCard(contenido: m, onTap: () => _abrirModulo(m)),
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EncabezadoComunidad extends StatelessWidget {
  final MiComunidad datos;

  const _EncabezadoComunidad({required this.datos});

  @override
  Widget build(BuildContext context) {
    final c = datos.comunidad;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.darkNavy,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_city_outlined, color: Colors.white, size: 28),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  c.nombre,
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          if (c.ubicacion.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(c.ubicacion, style: TextStyle(color: Colors.white.withAlpha(204), fontSize: 13)),
          ],
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(20),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Row(
              children: [
                InitialsAvatar(name: datos.coordinadorNombre ?? 'Coordinador', size: 40),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Coordinador responsable',
                          style: TextStyle(color: Colors.white.withAlpha(179), fontSize: 11)),
                      Text(
                        datos.coordinadorNombre ?? 'Sin asignar',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                      if (datos.coordinadorCorreo != null)
                        Text(
                          datos.coordinadorCorreo!,
                          style: TextStyle(color: Colors.white.withAlpha(204), fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModuloCard extends StatelessWidget {
  final ModuloContenido contenido;
  final VoidCallback onTap;

  const _ModuloCard({required this.contenido, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final m = contenido.modulo;
    final nuevos = [...contenido.anuncios, ...contenido.material].where((s) => s.estado == 'PUBLICADO').length;
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
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.tealCyan.withAlpha(26),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Text('${m.orden}',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.tealCyan)),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  m.nombre,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.charcoal),
                ),
              ),
              if (nuevos > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.coralRed,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text('$nuevos nuevo(s)',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          if (m.descripcion != null && m.descripcion!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              m.descripcion!,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              _Conteo(Icons.pending_actions_outlined, 'En proceso', contenido.enProceso.length, AppColors.mustardGold),
              _Conteo(Icons.check_circle_outline, 'Realizadas', contenido.realizadas.length, AppColors.sageGreen),
              _Conteo(Icons.campaign_outlined, 'Anuncios', contenido.anuncios.length, AppColors.darkNavy),
              _Conteo(Icons.menu_book_outlined, 'Material', contenido.material.length, AppColors.tealCyan),
            ],
          ),
        ],
      ),
    );
  }
}

class _Conteo extends StatelessWidget {
  final IconData icon;
  final String etiqueta;
  final int valor;
  final Color color;

  const _Conteo(this.icon, this.etiqueta, this.valor, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text('$etiqueta: $valor', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

/// Cuadrícula simple de altura variable (filas de [columnas] tarjetas).
class _Cuadricula extends StatelessWidget {
  final int columnas;
  final List<Widget> children;

  const _Cuadricula({required this.columnas, required this.children});

  @override
  Widget build(BuildContext context) {
    final filas = <Widget>[];
    for (var i = 0; i < children.length; i += columnas) {
      final fila = children.sublist(i, (i + columnas).clamp(0, children.length));
      filas.add(Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var j = 0; j < columnas; j++) ...[
                if (j > 0) const SizedBox(width: AppSpacing.md),
                Expanded(child: j < fila.length ? fila[j] : const SizedBox.shrink()),
              ],
            ],
          ),
        ),
      ));
    }
    return Column(children: filas);
  }
}
