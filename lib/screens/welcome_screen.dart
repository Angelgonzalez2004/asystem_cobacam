import 'package:asystem_cobacam/screens/login_screen.dart';
import 'package:asystem_cobacam/utils/slide_transition.dart';
import 'package:flutter/material.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      // The background is now handled by the global theme
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Center the content for web/larger screens
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo
                    Image.asset(
                      'assets/images/logo1.png',
                      height: 120,
                    ),
                    const SizedBox(height: 40),

                    // Welcome Title
                    Text(
                      'Bienvenido a Asystem-Cobacam',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: colors.primary,
                        fontSize: 28,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Informational Text
                    Text(
                      'Bienvenido a Asystem-Cobacam, la plataforma integral diseñada para optimizar la gestión académica de su institución.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colors.onSurface.withAlpha(200),
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 15),
                    Text(
                      'Nuestra solución centraliza el control de asistencias, la eficiente generación de horarios y la administración detallada de alumnos y personal académico. Agilice sus procesos operativos y mejore la experiencia educativa para todos.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurface.withAlpha(180),
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 15),
                    Text(
                      'Implementamos un sistema de pase de lista moderno mediante el escaneo de credenciales con códigos de barras, utilizando lectores especializados o la cámara de dispositivos móviles, garantizando precisión y rapidez en cada registro.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurface.withAlpha(180),
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 50),

                    // Login Button - now styled by the global theme
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(context, SlideRightRoute(page: const LoginScreen()));
                      },
                      child: const Text('Ir a Login'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
