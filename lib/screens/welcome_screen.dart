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
      padding: EdgeInsets.symmetric(horizontal: isWide ? 60.0 : 40.0),
      child: FadeInDown(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: isWide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
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
                      color: const Color(0xFF1E3A8A).withOpacity(0.3),
                      blurRadius: 40,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/images/logo1.png',
                  height: isWide ? 160 : 100,
                ),
              ),
            ),
            const SizedBox(height: 48),
            Text(
              'ASYSTEM',
              style: theme.textTheme.displayMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w100,
                letterSpacing: 10,
                fontSize: isWide ? 36 : 24,
              ),
            ),
            Text(
              'COBACAM',
              textAlign: isWide ? TextAlign.left : TextAlign.center,
              style: theme.textTheme.displayLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                height: 0.9,
                letterSpacing: -1,
                fontSize: isWide ? 72 : 48,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              height: 4,
              width: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                gradient: const LinearGradient(
                  colors: [Color(0xFFFACC15), Color(0xFFEAB308)], // Dorado Institucional
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'PLATAFORMA INTEGRAL DE GESTIÓN ACADÉMICA',
              textAlign: isWide ? TextAlign.left : TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: isWide ? 14 : 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 3.5,
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
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.account_balance_rounded,
                color: Color(0xFFFACC15),
                size: 40,
              ),
              const SizedBox(height: 24),
              const Text(
                'Portal de Acceso',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Servicios Digitales Exclusivos para la Comunidad COBACAM',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context, 
                    SlideRightRoute(page: const LoginScreen())
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1E3A8A),
                  minimumSize: const Size(double.infinity, 60),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  elevation: 12,
                  shadowColor: Colors.black.withOpacity(0.5),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'INGRESAR AL PORTAL',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        fontSize: 15,
                      ),
                    ),
                    SizedBox(width: 12),
                    Icon(Icons.arrow_forward_rounded, size: 20),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'SISTEMA DE EXCELENCIA ACADÉMICA v2026',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
