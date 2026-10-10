import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';

class ConfigScreen extends StatefulWidget {
  const ConfigScreen({super.key});

  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  final _urlController = TextEditingController();
  final _api = ApiService();

  @override
  void initState() {
    super.initState();
    _urlController.text = _api.baseUrl;
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;
    await _api.setBaseUrl(url);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Servidor actualizado correctamente'),
          backgroundColor: AppColors.sageGreen,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración del Servidor'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dirección del Backend (API REST)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.darkNavy,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Indica la URL del servidor Spring Boot. Si usas un dispositivo móvil físico en la misma red Wi-Fi, usa la IP de tu PC (ej: http://192.168.1.15:8081).',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'URL del Backend',
                hintText: 'http://10.0.2.2:8081',
                prefixIcon: Icon(Icons.dns, color: AppColors.darkNavy),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Accesos rápidos comunes:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  label: const Text('Localhost (8081)'),
                  onPressed: () => _urlController.text = 'http://localhost:8081',
                ),
                ActionChip(
                  label: const Text('Emulador Android (10.0.2.2:8081)'),
                  onPressed: () => _urlController.text = 'http://10.0.2.2:8081',
                ),
              ],
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _guardar,
                child: const Text('Guardar Configuración'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
