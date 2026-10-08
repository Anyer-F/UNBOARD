import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../shared/models/notificacion.dart';
import '../../shared/widgets/cards.dart';
import '../../shared/widgets/states.dart';
import '../../services/auth_service.dart';
import '../../services/notificacion_service.dart';

/// Lista de notificaciones (especificación §30).
///
/// Puede usarse como pestaña embebida ([embedded]) del shell
/// o como pantalla independiente.
class NotificacionesScreen extends StatefulWidget {
  final bool embedded;

  const NotificacionesScreen({super.key, this.embedded = false});

  @override
  State<NotificacionesScreen> createState() => _NotificacionesScreenState();
}

class _NotificacionesScreenState extends State<NotificacionesScreen> {
  final _notifService = NotificacionService();
  List<Notificacion> _notificaciones = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarNotificaciones();
  }

  Future<void> _cargarNotificaciones() async {
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    if (user == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final notifs = await _notifService.listarPorUsuario(user.usuarioId);
      if (mounted) {
        setState(() {
          _notificaciones = notifs;
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

  Future<void> _marcarTodasLeidas() async {
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    if (user == null) return;

    try {
      await _notifService.marcarTodasComoLeidas(user.usuarioId);
      _cargarNotificaciones();
    } catch (_) {}
  }

  Future<void> _marcarLeida(Notificacion notif) async {
    if (notif.leida) return;
    try {
      await _notifService.marcarComoLeida(notif.id);
      _cargarNotificaciones();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    Widget body;

    if (_isLoading) {
      body = const LoadingState(message: 'Cargando notificaciones...');
    } else if (_error != null) {
      body = ErrorState(
        title: 'No se pudieron cargar las notificaciones',
        message: _error,
        onRetry: _cargarNotificaciones,
      );
    } else if (_notificaciones.isEmpty) {
      body = const EmptyState(
        icon: Icons.notifications_none_outlined,
        title: 'Sin notificaciones',
        description: 'Cuando tengas novedades aparecerán aquí',
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _cargarNotificaciones,
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          itemCount: _notificaciones.length,
          itemBuilder: (context, index) {
            final notif = _notificaciones[index];
            return NotificationCard(
              notificacion: notif,
              onTap: () => _marcarLeida(notif),
            );
          },
        ),
      );
    }

    if (widget.embedded) {
      return body;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: 'Marcar todas como leídas',
            onPressed: _marcarTodasLeidas,
          ),
        ],
      ),
      body: body,
    );
  }
}
