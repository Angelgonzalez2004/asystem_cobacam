import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:asystem_cobacam/main.dart'; // To access navigator or restart logic if needed

class RefreshAppButton extends StatelessWidget {
  const RefreshAppButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.refresh_rounded),
      tooltip: 'Actualizar / Reiniciar',
      onPressed: () {
        // Soft Restart: Go to root and clear stack
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      },
    );
  }
}
