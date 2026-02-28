import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    // 1. Pedir permisos
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      if (kDebugMode) print('Permiso concedido para notificaciones.');
    }

    // 2. Configurar notificaciones locales (solo para móviles)
    if (!kIsWeb) {
      const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
      const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
      await _localNotifications.initialize(settings: initializationSettings);
    }

    // 3. Escuchar notificaciones en primer plano (Foreground)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        if (kIsWeb) {
          // En web, el navegador suele manejar esto si tiene permiso, 
          // pero podemos mostrar un aviso visual extra si queremos.
          if (kDebugMode) print('Notificación recibida en web: ${message.notification!.title}');
        } else {
          _showLocalNotification(message.notification!);
        }
      }
    });

    // 4. Guardar el token si hay un usuario logueado
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
      // Para Web, necesitas la clave VAPID de la consola de Firebase (Cloud Messaging -> Web Push certificates)
      String? token = await _messaging.getToken(
        vapidKey: kIsWeb ? 'BO4q2r-Pexrs-mXjXkxhdnzXbelHi2jY3EDBY-dmTFm--FQAdvLzvTR35bdMjnwG_9mtAuYFknPeYLGQppcF7_w' : null,
      );
      
      if (token != null) {
        // Guardamos el token en una subcolección para permitir múltiples dispositivos
        final tokenHash = token.hashCode.toString();
        await FirebaseDatabase.instance
            .ref('users/${user.uid}/fcmTokens/$tokenHash')
            .set(token);
      }
    } catch (e) {
      if (kDebugMode) print('Error guardando token FCM: $e');
    }
  }

  static Future<void> _showLocalNotification(RemoteNotification notification) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'attendance_channel',
      'Notificaciones de Asistencia',
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: platformDetails,
    );
  }
}
