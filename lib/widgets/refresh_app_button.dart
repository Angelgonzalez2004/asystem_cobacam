import 'package:flutter/material.dart';

class RefreshAppButton extends StatelessWidget {
  const RefreshAppButton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: IconButton.filled(
        onPressed: () {
          // Soft Restart: Go to root and clear stack
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
        },
        icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
        tooltip: 'Actualizar / Reiniciar',
        style: IconButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          padding: const EdgeInsets.all(8),
        ),
      ),
    );
  }
}