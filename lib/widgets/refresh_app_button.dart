import 'package:flutter/material.dart';

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