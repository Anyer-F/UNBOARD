import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../core/network/api_client.dart';

class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  FirebaseMessaging? _firebaseMessaging;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final ApiService _api = ApiService();

  String? _fcmToken;
  bool _isInitialized = false;

  String? get fcmToken => _fcmToken;
  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Inicializar Firebase
      await Firebase.initializeApp();
      debugPrint('Firebase inicializado correctamente');

      // Inicializar Firebase Messaging después de Firebase
      _firebaseMessaging = FirebaseMessaging.instance;

      // Solicitar permisos de notificación
      await _requestPermissions();

      // Configurar notificaciones locales
      await _setupLocalNotifications();

      // Obtener token FCM
      await _getFcmToken();

      // Configurar manejadores de mensajes
      _setupMessageHandlers();

      _isInitialized = true;
      debugPrint('PushNotificationService inicializado correctamente');
    } catch (e) {
      debugPrint('Error al inicializar PushNotificationService: $e');
      debugPrint('La app continuará sin notificaciones push');
      // Marcar como inicializado para no reintentar
      _isInitialized = true;
    }
  }

  Future<void> _requestPermissions() async {
    if (kIsWeb) return;
    if (_firebaseMessaging == null) return;

    NotificationSettings settings = await _firebaseMessaging!.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    debugPrint('Permisos de notificación: ${settings.authorizationStatus}');

    // En iOS, configurar presentación de notificaciones en primer plano
    if (Platform.isIOS) {
      await _firebaseMessaging!.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }

  Future<void> _setupLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('Notificación local tocada: ${response.payload}');
      },
    );

    // Crear canal de notificaciones para Android
    const androidChannel = AndroidNotificationChannel(
      'unbound_notifications',
      'Notificaciones UNBOUND',
      description: 'Notificaciones de la Fundación UNBOUND',
      importance: Importance.high,
      playSound: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  Future<void> _getFcmToken() async {
    try {
      if (_firebaseMessaging == null) return;
      
      _fcmToken = await _firebaseMessaging!.getToken();
      debugPrint('FCM Token: $_fcmToken');

      // Registrar token en el backend
      if (_fcmToken != null) {
        await _registrarTokenEnBackend(_fcmToken!);
      }

      // Escuchar actualizaciones del token
      _firebaseMessaging!.onTokenRefresh.listen((newToken) {
        debugPrint('FCM Token actualizado: $newToken');
        _fcmToken = newToken;
        _registrarTokenEnBackend(newToken);
      });
    } catch (e) {
      debugPrint('Error al obtener FCM Token: $e');
    }
  }

  Future<void> _registrarTokenEnBackend(String token) async {
    try {
      await _api.post('/api/fcm/registrar-token', {
        'fcmToken': token,
        'dispositivo': Platform.operatingSystem,
      });
      debugPrint('Token FCM registrado en el backend');
    } catch (e) {
      debugPrint('Error al registrar token FCM en backend: $e');
    }
  }

  void _setupMessageHandlers() {
    // Mensajes en primer plano
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Mensaje recibido en primer plano: ${message.notification?.title}');
      _mostrarNotificacionLocal(message);
    });

    // Mensajes en segundo plano (cuando la app está cerrada)
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Cuando el usuario abre la app desde una notificación
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('App abierta desde notificación: ${message.notification?.title}');
      _manejarTapNotificacion(message);
    });
  }

  Future<void> _mostrarNotificacionLocal(RemoteMessage message) async {
    final notification = message.notification;
    final android = message.notification?.android;

    if (notification != null) {
      final androidDetails = AndroidNotificationDetails(
        'unbound_notifications',
        'Notificaciones UNBOUND',
        channelDescription: 'Notificaciones de la Fundación UNBOUND',
        importance: Importance.high,
        priority: Priority.high,
        icon: android?.smallIcon ?? '@mipmap/ic_launcher',
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        details,
        payload: message.data.toString(),
      );
    }
  }

  void _manejarTapNotificacion(RemoteMessage message) {
    final tipo = message.data['tipo'];
    final idReferencia = message.data['idReferencia'];

    debugPrint('Tipo: $tipo, ID Referencia: $idReferencia');

    // Aquí puedes navegar a la pantalla correspondiente según el tipo
    // Por ejemplo:
    // if (tipo == 'ACTIVIDAD') {
    //   Navigator.push(...);
    // }
  }

  Future<void> suscribirATema(String tema) async {
    try {
      if (_firebaseMessaging == null) return;
      await _firebaseMessaging!.subscribeToTopic(tema);
      debugPrint('Suscrito al tema: $tema');
    } catch (e) {
      debugPrint('Error al suscribir al tema $tema: $e');
    }
  }

  Future<void> desuscribirDeTema(String tema) async {
    try {
      if (_firebaseMessaging == null) return;
      await _firebaseMessaging!.unsubscribeFromTopic(tema);
      debugPrint('Desuscrito del tema: $tema');
    } catch (e) {
      debugPrint('Error al desuscribir del tema $tema: $e');
    }
  }

  Future<void> eliminarToken() async {
    try {
      if (_firebaseMessaging == null) return;
      await _firebaseMessaging!.deleteToken();
      _fcmToken = null;
      debugPrint('Token FCM eliminado');
    } catch (e) {
      debugPrint('Error al eliminar token FCM: $e');
    }
  }
}

// Función para manejar mensajes en segundo plano
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('Mensaje en segundo plano: ${message.notification?.title}');
}
