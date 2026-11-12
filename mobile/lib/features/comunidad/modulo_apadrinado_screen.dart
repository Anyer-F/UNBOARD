import 'package:flutter/material.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../services/comunidad_service.dart';
import '../../shared/models/asignacion.dart';
import '../../shared/models/modulo.dart';
import '../../shared/widgets/actividad_widgets.dart';
import '../../shared/widgets/common_widgets.dart';
import '../actividades/asignacion_screen.dart';

/// Módulo de la comunidad visto por el apadrinado: solo las actividades
/// que le fueron asignadas, separadas en proceso, realizadas, anuncios
/// y material de apoyo.
class ModuloApadrinadoScreen extends StatefulWidget {
  final ModuloContenido contenido;

  const ModuloApadrinadoScreen({super.key, required this.contenido});

  @override
  State<ModuloApadrinadoScreen> createState() => _ModuloApadrinadoScreenState();
}

class _ModuloApadrinadoScreenState extends State<ModuloApadrinadoScreen> {
  final _service = ComunidadService();
  late ModuloContenido _contenido = widget.contenido;

  /// Recarga el módulo (los estados cambian al abrir o entregar).
  Future<void> _recargar() async {
    try {
      final datos = await _service.miComunidad();
      final actualizado = datos.modulos.where((m) => m.modulo.id == _contenido.modulo.id);
      if (mounted && actualizado.isNotEmpty) setState(() => _contenido = actualizado.first);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensajeDeError(e))));
    }
  }

  Future<void> _abrir(Asignacion s) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AsignacionScreen(asignacionId: s.id)),
    );
    if (mounted) _recargar();
  }

  @override
  Widget build(BuildContext context) {
    final c = _contenido;
    final secciones = <_Seccion>[
      _Seccion('Actividades en proceso', 'Tareas pendientes, enviadas o con correcciones',
          Icons.pending_actions_outlined, c.enProceso),
      _Seccion('Actividades realizadas', 'Tareas aprobadas por tu coordinador', Icons.check_circle_outline,
          c.realizadas),
      _Seccion('Anuncios', 'Información publicada por tu coordinador', Icons.campaign_outlined, c.anuncios),
      _Seccion('Material de apoyo', 'Archivos para consultar y descargar', Icons.menu_book_outlined, c.material),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(c.modulo.nombre)),
      body: RefreshIndicator(
        onRefresh: _recargar,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.xxl),
          child: ResponsiveContent(
            maxWidth: 820,
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (c.modulo.descripcion != null && c.modulo.descripcion!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
                    child: Text(c.modulo.descripcion!,
                        style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                  ),
                if (c.total == 0)
                  const Padding(
                    padding: EdgeInsets.all(AppSpacing.xl),
                    child: Text(
                      'Este módulo aún no tiene actividades para ti.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                for (final s in secciones)
                  if (s.items.isNotEmpty) ...[
                    SectionHeader(title: '${s.titulo} (${s.items.length})', subtitle: s.subtitulo),
                    for (final a in s.items) AsignacionCard(asignacion: a, onTap: () => _abrir(a)),
                    const SizedBox(height: AppSpacing.lg),
                  ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Seccion {
  final String titulo;
  final String subtitulo;
  final IconData icono;
  final List<Asignacion> items;

  _Seccion(this.titulo, this.subtitulo, this.icono, this.items);
}
