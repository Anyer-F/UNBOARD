import 'package:flutter/material.dart';

import '../../core/constants/app_radius.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/responsive.dart';
import '../../services/comunidad_service.dart';
import '../../shared/models/modulo.dart';
import '../../shared/widgets/confirmation_dialog.dart';
import '../../shared/widgets/states.dart';

/// Módulos de una comunidad (coordinador): crear, renombrar,
/// reordenar y eliminar los que no tienen actividades.
class ModulosScreen extends StatefulWidget {
  final int comunidadId;
  final String? comunidadNombre;

  const ModulosScreen({super.key, required this.comunidadId, this.comunidadNombre});

  @override
  State<ModulosScreen> createState() => _ModulosScreenState();
}

class _ModulosScreenState extends State<ModulosScreen> {
  final _service = ComunidadService();

  List<Modulo> _modulos = [];
  bool _cargando = true;
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final lista = await _service.modulos(widget.comunidadId);
      if (!mounted) return;
      setState(() {
        _modulos = lista;
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

  void _mostrar(String mensaje, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(mensaje),
      backgroundColor: error ? AppColors.coralRed : AppColors.sageGreen,
    ));
  }

  Future<void> _ejecutar(Future<void> Function() accion, String exito) async {
    setState(() => _guardando = true);
    try {
      await accion();
      if (mounted) _mostrar(exito);
      await _cargar();
    } catch (e) {
      if (mounted) _mostrar(mensajeDeError(e), error: true);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _formulario({Modulo? modulo}) async {
    final nombre = TextEditingController(text: modulo?.nombre ?? '');
    final descripcion = TextEditingController(text: modulo?.descripcion ?? '');
    final formKey = GlobalKey<FormState>();
    final guardar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(modulo == null ? 'Nuevo módulo' : 'Editar módulo'),
        content: SizedBox(
          width: 420,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nombre,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    hintText: 'Ej. Módulo 2: Educación',
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Ingrese el nombre' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: descripcion,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Descripción (opcional)'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (guardar != true) return;
    if (modulo == null) {
      await _ejecutar(
        () => _service.crearModulo(widget.comunidadId,
            nombre: nombre.text.trim(), descripcion: descripcion.text.trim()),
        'Módulo creado',
      );
    } else {
      await _ejecutar(
        () => _service.actualizarModulo(modulo.id,
            nombre: nombre.text.trim(), descripcion: descripcion.text.trim()),
        'Módulo actualizado',
      );
    }
  }

  Future<void> _eliminar(Modulo modulo) async {
    final ok = await showConfirmationDialog(
      context,
      title: 'Eliminar módulo',
      message: '¿Eliminar "${modulo.nombre}"? Esta acción no se puede deshacer.',
      confirmLabel: 'Eliminar',
      isDanger: true,
      icon: Icons.delete_outline,
    );
    if (!ok) return;
    await _ejecutar(() => _service.eliminarModulo(modulo.id), 'Módulo eliminado');
  }

  Future<void> _reordenar(int anterior, int nuevo) async {
    if (nuevo > anterior) nuevo -= 1;
    final lista = List<Modulo>.from(_modulos);
    final m = lista.removeAt(anterior);
    lista.insert(nuevo, m);
    setState(() => _modulos = lista);
    await _ejecutar(
      () => _service.reordenarModulos(widget.comunidadId, lista.map((x) => x.id).toList()),
      'Orden actualizado',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.comunidadNombre != null ? 'Módulos · ${widget.comunidadNombre}' : 'Módulos'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _guardando ? null : () => _formulario(),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo módulo'),
      ),
      body: _contenido(),
    );
  }

  Widget _contenido() {
    if (_cargando) return const LoadingState(message: 'Cargando módulos...');
    if (_error != null) {
      return ErrorState(title: 'No se pudieron cargar los módulos', message: _error, onRetry: _cargar);
    }
    return RefreshIndicator(
      onRefresh: _cargar,
      child: ResponsiveContent(
        maxWidth: 720,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _ayuda()),
            SliverReorderableList(
              itemCount: _modulos.length,
              onReorder: _reordenar,
              itemBuilder: (context, i) => _ModuloTile(
                key: ValueKey(_modulos[i].id),
                index: i,
                modulo: _modulos[i],
                puedeEliminar: _modulos.length > 1 && _modulos[i].totalActividades == 0,
                onEditar: () => _formulario(modulo: _modulos[i]),
                onEliminar: () => _eliminar(_modulos[i]),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 96)),
          ],
        ),
      ),
    );
  }

  Widget _ayuda() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.tealCyan.withAlpha(20),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: AppColors.tealCyan, size: 20),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'El primer módulo es el módulo universal: mientras exista un solo módulo, '
              'todas las actividades se crean ahí. Arrastre los módulos para cambiar el orden '
              'en que los ven los apadrinados. Para eliminar un módulo con actividades, '
              'primero muévalas a otro módulo.',
              style: TextStyle(fontSize: 13, color: AppColors.charcoal),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModuloTile extends StatelessWidget {
  final int index;
  final Modulo modulo;
  final bool puedeEliminar;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  const _ModuloTile({
    super.key,
    required this.index,
    required this.modulo,
    required this.puedeEliminar,
    required this.onEditar,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.darkNavy.withAlpha(20),
          child: Text('${index + 1}',
              style: const TextStyle(color: AppColors.darkNavy, fontWeight: FontWeight.w700)),
        ),
        title: Text(modulo.nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          [
            '${modulo.totalActividades} actividad${modulo.totalActividades == 1 ? '' : 'es'}',
            if (modulo.descripcion != null && modulo.descripcion!.isNotEmpty) modulo.descripcion!,
          ].join(' · '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Editar',
              icon: const Icon(Icons.edit_outlined),
              onPressed: onEditar,
            ),
            IconButton(
              tooltip: puedeEliminar ? 'Eliminar' : 'Solo se eliminan módulos sin actividades',
              icon: Icon(Icons.delete_outline, color: puedeEliminar ? AppColors.coralRed : null),
              onPressed: puedeEliminar ? onEliminar : null,
            ),
            ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.all(AppSpacing.sm),
                child: Icon(Icons.drag_handle),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
