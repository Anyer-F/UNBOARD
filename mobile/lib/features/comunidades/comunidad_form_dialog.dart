import 'package:flutter/material.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../services/comunidad_service.dart';
import '../../shared/models/comunidad.dart';

/// Diálogo para crear o editar una comunidad. Devuelve la comunidad
/// guardada o `null` si se cancela.
Future<Comunidad?> mostrarFormularioComunidad(BuildContext context, {Comunidad? comunidad}) {
  return showDialog<Comunidad>(
    context: context,
    builder: (_) => _ComunidadFormDialog(comunidad: comunidad),
  );
}

class _ComunidadFormDialog extends StatefulWidget {
  final Comunidad? comunidad;

  const _ComunidadFormDialog({this.comunidad});

  @override
  State<_ComunidadFormDialog> createState() => _ComunidadFormDialogState();
}

class _ComunidadFormDialogState extends State<_ComunidadFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombre;
  late final TextEditingController _municipio;
  late final TextEditingController _departamento;
  late String _modo;
  bool _guardando = false;
  String? _error;

  bool get _esEdicion => widget.comunidad != null;

  @override
  void initState() {
    super.initState();
    final c = widget.comunidad;
    _nombre = TextEditingController(text: c?.nombre ?? '');
    _municipio = TextEditingController(text: c?.municipio ?? '');
    _departamento = TextEditingController(text: c?.departamento ?? 'Huehuetenango');
    _modo = c?.modoIncorporacion ?? 'SOLICITUD';
  }

  @override
  void dispose() {
    _nombre.dispose();
    _municipio.dispose();
    _departamento.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    final servicio = ComunidadService();
    try {
      final Comunidad guardada;
      if (_esEdicion) {
        guardada = await servicio.actualizar(widget.comunidad!.id, {
          'nombre': _nombre.text.trim(),
          'municipio': _municipio.text.trim(),
          'departamento': _departamento.text.trim(),
          'modoIncorporacion': _modo,
        });
      } else {
        guardada = await servicio.crear(
          nombre: _nombre.text.trim(),
          municipio: _municipio.text.trim(),
          departamento: _departamento.text.trim(),
          modoIncorporacion: _modo,
        );
      }
      if (mounted) Navigator.pop(context, guardada);
    } catch (e) {
      if (mounted) {
        setState(() {
          _guardando = false;
          _error = mensajeDeError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_esEdicion ? 'Editar comunidad' : 'Nueva comunidad'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SizedBox(
          width: 420,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _nombre,
                    decoration: const InputDecoration(labelText: 'Nombre *', hintText: 'Ej. Aldea San Juan'),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Ingrese el nombre' : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _municipio,
                    decoration: const InputDecoration(labelText: 'Municipio'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _departamento,
                    decoration: const InputDecoration(labelText: 'Departamento'),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const Text('Incorporación con el código de acceso',
                      style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.charcoal)),
                  const SizedBox(height: AppSpacing.sm),
                  SelectorModoIncorporacion(
                    valor: _modo,
                    onChanged: (v) => setState(() => _modo = v),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(_error!, style: const TextStyle(color: AppColors.coralRed)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _guardando ? null : _guardar,
          child: _guardando
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(_esEdicion ? 'Guardar' : 'Crear'),
        ),
      ],
    );
  }
}

/// Selector entre incorporación con solicitud o ingreso directo.
class SelectorModoIncorporacion extends StatelessWidget {
  final String valor;
  final ValueChanged<String> onChanged;

  const SelectorModoIncorporacion({super.key, required this.valor, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'SOLICITUD', icon: Icon(Icons.how_to_reg_outlined), label: Text('Con solicitud')),
            ButtonSegment(value: 'DIRECTO', icon: Icon(Icons.login), label: Text('Directo')),
          ],
          selected: {valor},
          onSelectionChanged: (s) => onChanged(s.first),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          valor == 'DIRECTO'
              ? 'El código válido incorpora al apadrinado de inmediato.'
              : 'Usted revisa el perfil del solicitante y acepta o rechaza.',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
