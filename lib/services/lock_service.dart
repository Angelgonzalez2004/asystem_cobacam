import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class LockService with ChangeNotifier {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final LocalAuthentication _localAuth = LocalAuthentication();

  bool _isLocked = true;
  bool get isLocked => _isLocked;

  bool _isPinSet = false;
  bool get isPinSet => _isPinSet;

  bool _useBiometrics = false;
  bool get useBiometrics => _useBiometrics;

  LockService() {
    _init();
  }

  Future<void> _init() async {
    final pin = await _secureStorage.read(key: 'app_pin');
    _isPinSet = pin != null && pin.isNotEmpty;

    final biometricsPref = await _secureStorage.read(key: 'use_biometrics');
    _useBiometrics = biometricsPref == 'true';

    // Si hay un PIN configurado, la app debe empezar bloqueada.
    _isLocked = _isPinSet;

    notifyListeners();
  }

  Future<void> setUseBiometrics(bool value) async {
    await _secureStorage.write(key: 'use_biometrics', value: value.toString());
    _useBiometrics = value;
    notifyListeners();
  }

  Future<bool> isBiometricsAvailable() async {
    try {
      // En la web, `isDeviceSupported` puede dar `true` pero `canCheckBiometrics` es un mejor indicador.
      if (kIsWeb) return false;

      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      return canCheck && isSupported;
    } catch (e) {
      debugPrint('Error checking biometrics: $e');
      return false;
    }
  }

  Future<bool> authenticateWithBiometrics() async {
    if (!_useBiometrics || !await isBiometricsAvailable()) return false;
    return authenticateWithBiometricsManually();
  }

  Future<bool> authenticateWithBiometricsManually() async {
    try {
      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Desbloquea la aplicación para continuar',
        biometricOnly: true, // Forzar solo huella/rostro
      );

      if (didAuthenticate) {
        unlock();
      }
      return didAuthenticate;
    } catch (e) {
      debugPrint('Error during biometric authentication: $e');
      return false;
    }
  }

  Future<bool> verifyPin(String pin) async {
    final storedPin = await _secureStorage.read(key: 'app_pin');
    if (storedPin == pin) {
      unlock();
      return true;
    }
    return false;
  }

  Future<void> setPin(String newPin) async {
    await _secureStorage.write(key: 'app_pin', value: newPin);
    _isPinSet = true;
    // Después de configurar un PIN, bloqueamos la app para el próximo inicio.
    _isLocked = true;
    notifyListeners();
  }

  Future<void> removePin() async {
    await _secureStorage.delete(key: 'app_pin');
    await _secureStorage.delete(key: 'use_biometrics');
    _isPinSet = false;
    _useBiometrics = false;
    _isLocked = false; // Si no hay PIN, no hay bloqueo.
    notifyListeners();
  }

  void lock() {
    if (_isPinSet && !_isLocked) {
      _isLocked = true;
      notifyListeners();
    }
  }

  void unlock() {
    if (_isLocked) {
      _isLocked = false;
      notifyListeners();
    }
  }
}
