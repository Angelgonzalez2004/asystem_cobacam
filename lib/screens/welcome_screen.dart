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
      body: Stack(
        children: [
          // Fondo Institucional Ultra-Premium (Mesh Gradient Style)
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1E3A8A), // Azul Cobacam Intenso
                  Color(0xFF1E293B), // Slate Profundo
                  Color(0xFF0F172A), // Negro Azulado
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),
          
          // Efecto de luz decorativa superior para profundidad
          Positioned(
            top: -150,
            right: -50,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.primary.withOpacity(0.1),
              ),
            ),
          ),

          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 900) {
                  return _buildWideLayout(context);
                } else {
                  return _buildNarrowLayout(context);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWideLayout(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 6,
          child: Center(child: _buildBrandingContent(context, isWide: true)),
        ),
        Expanded(
          flex: 4,
          child: Center(child: _buildActionPanel(context)),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          const SizedBox(height: 80),
          _buildBrandingContent(context, isWide: false),
          const SizedBox(height: 60),
          _buildActionPanel(context),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildBrandingContent(BuildContext context, {required bool isWide}) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40.0),
      child: FadeInDown(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: isWide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: [
            Hero(
              tag: 'app_logo_main',
              child: Container(
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withOpacity(0.4),
                      blurRadius: 50,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/images/logo1.png',
                  height: isWide ? 180 : 120,
                ),
              ),
            ),
            const SizedBox(height: 56),
            Text(
              'ASYSTEM',
              style: theme.textTheme.displayMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w200, // Estilo ultra-moderno
                letterSpacing: 12,
                fontSize: isWide ? 42 : 32,
              ),
            ),
            Text(
              'COBACAM',
              style: theme.textTheme.displayLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                height: 0.85,
                letterSpacing: -1.5,
                fontSize: isWide ? 80 : 56,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              height: 6,
              width: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                gradient: LinearGradient(
                  colors: [theme.colorScheme.secondary, theme.colorScheme.tertiary],
                ),
              ),
            ),
            const SizedBox(height: 40),
            Text(
              'GESTIÓN ESCOLAR INTELIGENTE',
              textAlign: isWide ? TextAlign.left : TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 4.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionPanel(BuildContext context) {
    return Center(
      child: FadeInUp(
        delay: const Duration(milliseconds: 300),
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 64),
          constraints: const BoxConstraints(maxWidth: 420),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: Colors.white.withOpacity(0.15)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 60,
                offset: const Offset(0, 25),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Bienvenido',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w200,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Acceso al Portal Institucional',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 56),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context, 
                    SlideRightRoute(page: const LoginScreen())
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF0F172A),
                  minimumSize: const Size(double.infinity, 65),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                  elevation: 0,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'INICIAR SESIÓN',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        fontSize: 17,
                      ),
                    ),
                    SizedBox(width: 16),
                    Icon(Icons.arrow_forward_ios_rounded, size: 18),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
