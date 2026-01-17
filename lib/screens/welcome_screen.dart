import 'package:asystem_cobacam/screens/login_screen.dart';
import 'package:asystem_cobacam/utils/animations.dart';
import 'package:asystem_cobacam/utils/slide_transition.dart';
import 'package:flutter/material.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Fondo Decorativo Moderno (Gradientes sutiles)
          Positioned(
            top: -200,
            right: -100,
            child: Container(
              width: 600,
              height: 600,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    colors.primary.withOpacity(0.1),
                    colors.primary.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -150,
            left: -150,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    colors.secondary.withOpacity(0.1),
                    colors.secondary.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Barra de Navegación "Falsa" (Header)
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24.0, vertical: 16),
                  child: Row(
                    children: [
                      Hero(
                        tag: 'app_logo_mini',
                        child:
                            Image.asset('assets/images/logo1.png', height: 40),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'COBACAM',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: colors.primary,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1200),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24.0, vertical: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const SizedBox(height: 40),

                              // HERO SECTION
                              FadeInUp(
                                duration: const Duration(milliseconds: 800),
                                child: Column(
                                  children: [
                                    Hero(
                                      tag: 'app_logo_main',
                                      child: Container(
                                        padding: const EdgeInsets.all(20),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: colors.primary
                                                  .withOpacity(0.15),
                                              blurRadius: 30,
                                              offset: const Offset(0, 10),
                                            )
                                          ],
                                        ),
                                        child: Image.asset(
                                            'assets/images/logo1.png',
                                            height: 120),
                                      ),
                                    ),
                                    const SizedBox(height: 40),
                                    Text(
                                      'Gestión Académica\nInteligente',
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.displayMedium
                                          ?.copyWith(
                                        fontWeight: FontWeight.w900,
                                        color: colors.onSurface,
                                        height: 1.1,
                                        letterSpacing: -1.0,
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    ConstrainedBox(
                                      constraints:
                                          const BoxConstraints(maxWidth: 600),
                                      child: Text(
                                        'Plataforma integral para el control escolar, asistencia digital y comunicación efectiva entre estudiantes, docentes y administrativos del sistema COBACAM.',
                                        textAlign: TextAlign.center,
                                        style:
                                            theme.textTheme.bodyLarge?.copyWith(
                                          color:
                                              colors.onSurface.withOpacity(0.7),
                                          fontSize: 18,
                                          height: 1.5,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 40),
                                    _buildPrimaryButton(context),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 100),

                              // FEATURES / ROLES SECTION
                              Text(
                                'SECCIONES DEL SISTEMA',
                                style: TextStyle(
                                  color: colors.primary,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 30),

                              LayoutBuilder(
                                builder: (context, constraints) {
                                  // Responsive Grid: 1 columna en móvil, 2 en tablet, 4 en desktop
                                  int cols = 1;
                                  if (constraints.maxWidth > 600) cols = 2;
                                  if (constraints.maxWidth > 1000) cols = 4;

                                  return GridView.count(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    crossAxisCount: cols,
                                    crossAxisSpacing: 20,
                                    mainAxisSpacing: 20,
                                    childAspectRatio:
                                        0.85, // Más altas para estilo "Card Web"
                                    children: [
                                      _buildFeatureCard(
                                        context,
                                        'Estudiantes',
                                        'Accede a tu historial, justificaciones y credencial digital.',
                                        Icons.school_rounded,
                                        Colors.blue,
                                      ),
                                      _buildFeatureCard(
                                        context,
                                        'Académicas',
                                        'Gestión de grupos, calificaciones y seguimiento académico.',
                                        Icons.menu_book_rounded,
                                        Colors.orange,
                                      ),
                                      _buildFeatureCard(
                                        context,
                                        'Prefectura',
                                        'Scanner de asistencia QR y control de accesos en tiempo real.',
                                        Icons.qr_code_scanner_rounded,
                                        Colors.green,
                                      ),
                                      _buildFeatureCard(
                                        context,
                                        'Administración',
                                        'Panel de control global, estadísticas y gestión de planteles.',
                                        Icons.admin_panel_settings_rounded,
                                        Colors.purple,
                                      ),
                                    ],
                                  );
                                },
                              ),

                              const SizedBox(height: 100),

                              // FOOTER SIMPLE
                              Divider(color: colors.onSurface.withOpacity(0.1)),
                              const SizedBox(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '© 2026 COBACAM',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color:
                                            colors.onSurface.withOpacity(0.5)),
                                  ),
                                  const SizedBox(width: 20),
                                  Text(
                                    'v1.0.0',
                                    style: TextStyle(
                                        color:
                                            colors.onSurface.withOpacity(0.3)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).primaryColor.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () {
          Navigator.push(context, SlideRightRoute(page: const LoginScreen()));
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 20),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
          elevation: 0,
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Ingresar al Portal',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(width: 12),
            Icon(Icons.arrow_forward_rounded),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard(BuildContext context, String title, String desc,
      IconData icon, Color accentColor) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? theme.cardColor : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: accentColor, size: 30),
          ),
          const Spacer(),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            desc,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
