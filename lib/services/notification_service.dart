import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';

/// Manejador de mensajes en segundo plano. 
/// Debe ser una función top-level (fuera de cualquier clase).
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // No es necesario inicializar Firebase aquí si ya se hizo en el main,
  // pero es una buena práctica si vas a acceder a servicios.
  if (kDebugMode) {
    print("Manejando mensaje en segundo plano: ${message.messageId}");
  }
}

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  // Definición del canal para Android (Alta prioridad)
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'attendance_alerts_channel', // id
    'Alertas de Asistencia COBACAM', // title
    description: 'Canal para notificaciones críticas de entrada y salida de alumnos.', // description
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    showBadge: true,
  );

  static Future<void> initialize() async {
    // 1. Pedir permisos
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      if (kDebugMode) print('Permiso concedido para notificaciones.');
    }

    // 2. Configurar el manejador de fondo
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 3. Configurar notificaciones locales y canal de Android
    if (!kIsWeb) {
      // Crear el canal en Android
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);

      const AndroidInitializationSettings initializationSettingsAndroid = 
          AndroidInitializationSettings('@mipmap/ic_launcher');
      
      const InitializationSettings initializationSettings = 
          InitializationSettings(android: initializationSettingsAndroid);
          
      await _localNotifications.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse details) {
          // Aquí puedes manejar qué pasa cuando el usuario toca la notificación
        },
      );
    }

    // 4. Escuchar notificaciones en primer plano (Foreground)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      if (notification != null && !kIsWeb) {
        // Mostramos la notificación local usando el canal de alta importancia
        _localNotifications.show(
          id: notification.hashCode,
          title: notification.title,
          body: notification.body,
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              _channel.id,
              _channel.name,
              channelDescription: _channel.description,
              importance: _channel.importance,
              priority: Priority.high,
              icon: android?.smallIcon ?? '@mipmap/ic_launcher',
              playSound: true,
              enableVibration: true,
            ),
          ),
          payload: message.data.toString(),
        );
      }
    });

    // 5. Guardar el token si hay un usuario logueado
    await saveDeviceToken();
  }

  /// Envía una solicitud de notificación de asistencia a la base de datos.
  /// Los tutores vinculados recibirán esta alerta en sus dispositivos.
  static Future<void> sendAttendanceNotification({
    required String studentName,
    required List<String> guardianIds,
    required String type, // 'entrada' o 'salida'
    required String time,
    required String campusName,
  }) async {
    if (guardianIds.isEmpty) return;

    try {
      final notificationsRef = FirebaseDatabase.instance.ref('notifications_queue');
      final newNotificationRef = notificationsRef.push();

      final String title = '🔔 ASISTENCIA ASYSTEM';
      final String body = 'El alumno $studentName ha registrado su ${type.toUpperCase()} en el plantel $campusName a las $time.';

      await newNotificationRef.set({
        'title': title,
        'body': body,
        'recipients': guardianIds, // Lista de UIDs de tutores
        'timestamp': ServerValue.timestamp,
        'type': 'attendance_alert',
        'data': {
          'studentName': studentName,
          'type': type,
          'time': time,
        }
      });
      
      if (kDebugMode) print('Solicitud de notificación enviada a la cola para $studentName');
    } catch (e) {
      if (kDebugMode) print('Error al solicitar notificación: $e');
    }
  }

  static Future<void> saveDeviceToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // 1. Obtener el Token (Con soporte para Web)
      String? token;
      if (kIsWeb) {
        token = await _messaging.getToken(
          vapidKey: 'BO4q2r-Pexrs-mXjXkxhdnzXbelHi2jY3EDBY-dmTFm--FQAdvLzvTR35bdMjnwG_9mtAuYFknPeYLGQppcF7_w',
        );
      } else {
        token = await _messaging.getToken();
      }
      
      if (token != null) {
        if (kDebugMode) print('Token FCM obtenido: $token');
        
        // 2. Guardar en la base de datos del usuario
        // Usamos un hash del token como llave para permitir múltiples dispositivos por usuario
        final tokenHash = token.hashCode.toString();
        await FirebaseDatabase.instance
            .ref('users/${user.uid}/fcmTokens/$tokenHash')
            .set({
              'token': token,
              'lastUpdated': ServerValue.timestamp,
              'platform': kIsWeb ? 'Web' : (defaultTargetPlatform == TargetPlatform.android ? 'Android' : 'iOS'),
            });
            
        if (kDebugMode) print('Token FCM guardado exitosamente en Firebase.');
      }
    } catch (e) {
      if (kDebugMode) print('Error crítico guardando token FCM: $e');
    }
  }
}
