import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class AyudaScreen extends StatelessWidget {
  const AyudaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ayuda y Soporte'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppColors.darkNavy,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '¿Necesitas ayuda?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Encuentra respuestas a las preguntas más frecuentes',
                    style: TextStyle(
                      color: Colors.white.withAlpha(200),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Preguntas frecuentes
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: const Text(
                'Preguntas Frecuentes',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkNavy,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildFaqItem(
              question: '¿Cómo escribo una carta?',
              answer:
                  'Ve a la sección "Mis Cartas" desde tu pantalla principal, toca el botón "Nueva Carta", escribe tu contenido y guarda como borrador o envía directamente.',
            ),
            _buildFaqItem(
              question: '¿Cómo subo una fotografía?',
              answer:
                  'Al atender una actividad, selecciona la opción "Tomar Foto" o "Galería" para adjuntar tu evidencia fotográfica.',
            ),
            _buildFaqItem(
              question: '¿Cómo consulto mi expediente digital?',
              answer:
                  'Desde tu pantalla principal, toca la tarjeta "Mi Expediente Digital" para ver toda tu información, cartas, fotos y documentos.',
            ),
            _buildFaqItem(
              question: '¿Qué significa cada estado de actividad?',
              answer:
                  'Pendiente: asignada pero no iniciada. En Proceso: trabajando en ella. Entregada: enviada al coordinador. Aprobada: revisada y aprobada. Corrección Solicitada: necesitas hacer ajustes.',
            ),
            _buildFaqItem(
              question: '¿Cómo cambio mi contraseña?',
              answer:
                  'Ve a tu perfil y selecciona la opción "Seguridad" para cambiar tu contraseña actual.',
            ),

            const SizedBox(height: 24),

            // Contacto de soporte
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: const Text(
                'Contacto de Soporte',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkNavy,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildContactCard(
              icon: Icons.email_outlined,
              title: 'Correo electrónico',
              subtitle: 'soporte@unbound-huehuetenango.org',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Abriendo cliente de correo...')),
                );
              },
            ),
            _buildContactCard(
              icon: Icons.phone_outlined,
              title: 'Teléfono',
              subtitle: '+502 7760-0000',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Llamando a soporte...')),
                );
              },
            ),
            _buildContactCard(
              icon: Icons.chat_outlined,
              title: 'Chat en vivo',
              subtitle: 'Lunes a Viernes 8:00 - 17:00',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Próximamente: Chat en vivo')),
                );
              },
            ),

            const SizedBox(height: 24),

            // Información de la app
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Acerca de la aplicación',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkNavy,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Fundación UNBOUND\nSede Huehuetenango, Guatemala\n\nVersión 1.0.0\n© 2024 Fundación UNBOUND',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildFaqItem({required String question, required String answer}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: ExpansionTile(
        title: Text(
          question,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.charcoal,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              answer,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: ListTile(
        leading: Icon(icon, color: AppColors.tealCyan),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
        onTap: onTap,
      ),
    );
  }
}
