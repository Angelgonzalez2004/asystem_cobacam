import 'dart:async';
import 'package:asystem_cobacam/screens/welcome_screen.dart';
import 'package:asystem_cobacam/services/session_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class SessionGuard extends StatefulWidget {
  final Widget child;
  const SessionGuard({super.key, required this.child});

  @override
  State<SessionGuard> createState() => _SessionGuardState();
}

class _SessionGuardState extends State<SessionGuard> {
  StreamSubscription<DatabaseEvent>? _sessionSubscription;
  bool _isKicked = false;

  @override
  void initState() {
    super.initState();
    _startMonitoring();
  }

  @override
  void dispose() {
    _sessionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _startMonitoring() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final deviceId = await SessionService().getCurrentDeviceId();
    final sessionRef = FirebaseDatabase.instance.ref('users/${user.uid}/sessions/$deviceId');

    // Escuchar cambios en mi propia sesión
    _sessionSubscription = sessionRef.onValue.listen((event) async {
      // Si el snapshot no existe (value == null), significa que alguien borró la sesión
      if (event.snapshot.value == null && !_isKicked) {
        _isKicked = true;
        _handleKick();
      }
    });
  }

  Future<void> _handleKick() async {
    // Evitar loops si ya se está saliendo
    if (!mounted) return;

    // 1. Cerrar sesión de Firebase
    await FirebaseAuth.instance.signOut();

    if (!mounted) return;

    // 2. Mostrar alerta
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Sesión Cerrada'),
        content: const Text(
          'Tu sesión ha sido revocada desde otro dispositivo o ha expirado por seguridad.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              // 3. Redirigir a WelcomeScreen limpiando todo el stack
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const WelcomeScreen()),
                (route) => false,
              );
            },
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
