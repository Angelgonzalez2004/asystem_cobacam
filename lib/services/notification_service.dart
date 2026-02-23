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

  static Future<void> saveDeviceToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Para Web, necesitas la clave VAPID de la consola de Firebase (Cloud Messaging -> Web Push certificates)
      String? token = await _messaging.getToken(
        vapidKey: kIsWeb ? 'TU_CLAVE_VAPID_AQUI' : null,
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
