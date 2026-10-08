import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../shared/models/actividad.dart';
import '../../services/auth_service.dart';
import '../../services/carta_service.dart';
import '../../../core/theme/app_theme.dart';

class EscribirCartaScreen extends StatefulWidget {
  final Actividad? actividad;

  const EscribirCartaScreen({super.key, this.actividad});

  @override
  State<EscribirCartaScreen> createState() => _EscribirCartaScreenState();
}

class _EscribirCartaScreenState extends State<EscribirCartaScreen> {
  final _tituloController = TextEditingController();
  final _contenidoController = TextEditingController();

  final _cartaService = CartaService();
  bool _isSaving = false;

  String _tipoCarta = 'GENERAL';
  final List<String> _tiposCarta = ['GENERAL', 'AGRADECIMIENTO', 'SOLICITUD', 'REPORTE'];

  @override
  void dispose() {
    _tituloController.dispose();
    _contenidoController.dispose();
    super.dispose();
  }

  Future<void> _guardarCarta({bool enviar = false}) async {
    final titulo = _tituloController.text.trim();
    final contenido = _contenidoController.text.trim();

    if (titulo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El título de la carta es obligatorio'),
          backgroundColor: AppColors.coralRed,
        ),
      );
      return;
    }

    if (contenido.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El contenido de la carta es obligatorio'),
          backgroundColor: AppColors.coralRed,
        ),
      );
      return;
    }

    if (contenido.length < 20) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El contenido debe tener al menos 20 caracteres'),
          backgroundColor: AppColors.coralRed,
        ),
      );
      return;
    }

    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    if (user?.apadrinadoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: No se encontró el ID del apadrinado'),
          backgroundColor: AppColors.coralRed,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      var carta = await _cartaService.crear(
        titulo: titulo,
        contenido: contenido,
        apadrinadoId: user!.apadrinadoId!,
        actividadId: widget.actividad?.id,
        tipoCarta: _tipoCarta,
      );

      if (enviar) {
        carta = await _cartaService.enviarCarta(carta.id);
      }

      setState(() => _isSaving = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(enviar ? 'Carta enviada correctamente' : 'Carta guardada como borrador'),
            backgroundColor: AppColors.sageGreen,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}'),
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
        title: const Text('Escribir Carta'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Información de la actividad (si aplica)
            if (widget.actividad != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.tealCyan.withAlpha(15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.tealCyan.withAlpha(50)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.assignment, color: AppColors.tealCyan, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Actividad: ${widget.actividad!.titulo}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.darkNavy,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

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
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _tiposCarta.map((tipo) {
                final isSelected = _tipoCarta == tipo;
                return ChoiceChip(
                  label: Text(tipo),
                  selected: isSelected,
                  selectedColor: AppColors.darkNavy,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : AppColors.charcoal,
                    fontWeight: FontWeight.bold,
                  ),
                  onSelected: (_) => setState(() => _tipoCarta = tipo),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            // Título
            TextField(
              controller: _tituloController,
              decoration: const InputDecoration(
                labelText: 'Título de la carta *',
                hintText: 'Ej: Carta de agradecimiento',
                prefixIcon: Icon(Icons.title, color: AppColors.darkNavy),
              ),
              maxLength: 100,
            ),

            const SizedBox(height: 16),

            // Contenido
            TextField(
              controller: _contenidoController,
              decoration: const InputDecoration(
                labelText: 'Contenido de la carta *',
                hintText: 'Querido padrino, le escribo para...',
                prefixIcon: Icon(Icons.edit_note, color: AppColors.darkNavy),
                alignLabelWithHint: true,
              ),
              maxLines: 12,
              minLines: 8,
              maxLength: 2000,
            ),

            const SizedBox(height: 8),

            // Contador de caracteres
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _contenidoController,
              builder: (context, value, _) {
                final count = value.text.length;
                final color = count < 20 ? AppColors.coralRed : AppColors.sageGreen;
                return Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '$count / 2000 caracteres (mínimo 20)',
                    style: TextStyle(
                      fontSize: 12,
                      color: color,
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            // Botones de acción
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isSaving ? null : () => _guardarCarta(enviar: false),
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: const Text('Guardar Borrador'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : () => _guardarCarta(enviar: true),
                    icon: const Icon(Icons.send),
                    label: const Text('Enviar Carta'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.darkNavy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
