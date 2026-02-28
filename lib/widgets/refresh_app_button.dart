import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:asystem_cobacam/services/hive_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class RefreshAppButton extends StatefulWidget {
  const RefreshAppButton({super.key});

  @override
  State<RefreshAppButton> createState() => _RefreshAppButtonState();
}

class _RefreshAppButtonState extends State<RefreshAppButton> {
  bool _isRefreshing = false;

  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      final hiveService = Provider.of<HiveService>(context, listen: false);
      
      // 1. Limpiar TODA la caché local (Hive) para forzar descarga de Firebase
      debugPrint('🔄 Limpiando caché de datos (Hive)...');
      await hiveService.clearAllBoxes();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Actualizando datos y sistema...'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.blue,
          ),
        );
      }

      // 2. Dar un pequeño respiro para que el usuario vea el mensaje
      await Future.delayed(const Duration(milliseconds: 800));

      if (kIsWeb) {
        // 3. EN WEB: Recarga forzada del navegador para ignorar caché del Hosting
        debugPrint('🌐 Recargando navegador (Hard Reload)...');
        html.window.location.reload();
      } else {
        // 4. EN MÓVIL/DESKTOP: Reiniciar flujo de navegación
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
        }
      }
    } catch (e) {
      debugPrint('❌ Error al refrescar la app: $e');
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: IconButton.filled(
        onPressed: _isRefreshing ? null : _handleRefresh,
        icon: _isRefreshing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
        tooltip: 'Actualizar / Reiniciar sistema',
        style: IconButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          padding: const EdgeInsets.all(8),
        ),
      ),
    );
  }
}
