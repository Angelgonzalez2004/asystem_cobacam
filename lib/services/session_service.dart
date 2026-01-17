import 'dart:convert';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class SessionService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  // Singleton
  static final SessionService _instance = SessionService._internal();
  factory SessionService() => _instance;
  SessionService._internal();

  /// Registra el dispositivo actual en la base de datos al iniciar sesión o abrir la app
  Future<void> registerCurrentSession() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final deviceData = await _getDeviceData();
      final String deviceId = _generateDeviceId(deviceData);

      // Obtener ubicación aproximada IP
      final locationData = await _getLocationData();

      final sessionRef = _db.child('users/${user.uid}/sessions/$deviceId');

      await sessionRef.set({
        'deviceId': deviceId,
        'model': deviceData['model'],
        'platform': deviceData['platform'],
        'lastActive': ServerValue.timestamp,
        'isWeb': kIsWeb,
        'location': locationData['location'] ?? 'Ubicación desconocida',
        'ip': locationData['ip'] ?? '',
      });
    } catch (e) {
      debugPrint('Error registering session: $e');
    }
  }

  /// Elimina una sesión específica
  Future<void> revokeSession(String deviceId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _db.child('users/${user.uid}/sessions/$deviceId').remove();
  }

  /// Obtiene el ID del dispositivo actual para identificarlo en la lista UI
  Future<String> getCurrentDeviceId() async {
    final data = await _getDeviceData();
    return _generateDeviceId(data);
  }

  // --- Helpers ---

  Future<Map<String, String>> _getLocationData() async {
    try {
      // Usamos ipapi.co que soporta HTTPS en el plan gratuito (limitado a 1000/día).
      // Es más seguro para Web (evita Mixed Content errors).
      final response = await http
          .get(Uri.parse('https://ipapi.co/json/'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // ipapi.co devuelve campos: ip, city, region, country_name
        return {
          'location': '${data['city']}, ${data['region']}',
          'ip': data['ip'] ?? '',
        };
      }
    } catch (e) {
      debugPrint('Error fetching location (HTTPS): $e');
      // Fallback silencioso: La app sigue funcionando, solo sin ubicación precisa.
    }
    return {};
  }

  Future<Map<String, String>> _getDeviceData() async {
    String model = 'Dispositivo Desconocido';
    String platform = 'Unknown';
    String idPart = 'unknown';

    try {
      if (kIsWeb) {
        final webInfo = await _deviceInfo.webBrowserInfo;
        model = '${webInfo.browserName.name} on ${webInfo.platform}';
        platform = 'Web';
        idPart = '${webInfo.vendor}_${webInfo.userAgent}';
      } else if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        model = '${androidInfo.manufacturer} ${androidInfo.model}';
        platform = 'Android';
        idPart = androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        model =
            '${iosInfo.name} (${iosInfo.systemName} ${iosInfo.systemVersion})';
        platform = 'iOS';
        idPart = iosInfo.identifierForVendor ?? 'ios_unknown';
      } else if (Platform.isWindows) {
        final winInfo = await _deviceInfo.windowsInfo;
        model = 'PC Windows (${winInfo.computerName})';
        platform = 'Windows';
        idPart = winInfo.deviceId;
      } else if (Platform.isLinux) {
        final linuxInfo = await _deviceInfo.linuxInfo;
        model = 'PC Linux (${linuxInfo.name})';
        platform = 'Linux';
        idPart = linuxInfo.machineId ?? 'linux_unknown';
      } else if (Platform.isMacOS) {
        final macInfo = await _deviceInfo.macOsInfo;
        model = 'Mac (${macInfo.computerName})';
        platform = 'macOS';
        idPart = macInfo.systemGUID ?? 'mac_unknown';
      }
    } catch (e) {
      debugPrint('Error getting device info: $e');
    }

    return {
      'model': model,
      'platform': platform,
      'rawId': idPart,
    };
  }

  String _generateDeviceId(Map<String, String> data) {
    String raw = '${data['platform']}_${data['rawId']}';
    return raw.replaceAll(RegExp(r'[.$#\[\]/]'), '_');
  }
}
