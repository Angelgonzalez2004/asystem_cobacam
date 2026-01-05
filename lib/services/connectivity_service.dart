import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectivityService {
  // StreamController para notificar cambios de conectividad
  final StreamController<ConnectivityResult> _connectivityController =
      StreamController<ConnectivityResult>.broadcast();

  // Expone el stream para que otros componentes puedan escucharlo
  Stream<ConnectivityResult> get connectivityStream => _connectivityController.stream;

  ConnectivityService() {
    // Escucha los cambios de conectividad y los añade al stream
    Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      if (kDebugMode) {
        print('Conectividad ha cambiado: $result');
      }
      _connectivityController.add(result);
    });
  }

  // Método para obtener el estado actual de la conectividad
  Future<ConnectivityResult> checkConnectivity() async {
    return await Connectivity().checkConnectivity();
  }

  // Método para cerrar el StreamController cuando ya no sea necesario
  void dispose() {
    _connectivityController.close();
  }
}
