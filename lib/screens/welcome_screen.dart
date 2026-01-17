import 'package:asystem_cobacam/screens/login_screen.dart';
import 'package:asystem_cobacam/utils/animations.dart';
import 'package:asystem_cobacam/utils/slide_transition.dart';
import 'package:flutter/material.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 800) {
            return _buildWideLayout(context);
          } else {
            return _buildNarrowLayout(context);
          }
        },
      ),
    );
  }

  Widget _buildWideLayout(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: _buildBrandingPanel(context),
        ),
        Expanded(
          flex: 3,
          child: _buildLoginPanel(context),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout(BuildContext context) {
    return Column(
      children: [
        // Use a smaller, more compact branding panel for mobile
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 40.0),
          child: _buildBrandingPanel(context, isNarrow: true),
        ),
        Expanded(
          child: _buildLoginPanel(context),
        ),
      ],
    );
  }

  Widget _buildBrandingPanel(BuildContext context, {bool isNarrow = false}) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textStyle = TextStyle(
      color: colors.onPrimary.withOpacity(0.8),
      fontSize: isNarrow ? 14 : 16,
      height: 1.5,
    );

    return Container(
      color: colors.primary,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(40.0),
          child: FadeInUp(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: isNarrow
                  ? CrossAxisAlignment.center
                  : CrossAxisAlignment.start,
              children: [
                Hero(
                  tag: 'app_logo_main',
                  child: Image.asset(
                    'assets/images/logo2.jpg', // Using the alternative logo which might be better for a dark background
                    height: isNarrow ? 80 : 120,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Asystem COBACAM',
                  textAlign: isNarrow ? TextAlign.center : TextAlign.start,
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: colors.onPrimary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Innovación y control en la palma de tu mano. La plataforma que unifica la experiencia académica.',
                  textAlign: isNarrow ? TextAlign.center : TextAlign.start,
                  style: textStyle,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginPanel(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      color: theme.scaffoldBackgroundColor,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(40.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: FadeInUp(
              delay: const Duration(milliseconds: 200),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.school_outlined,
                    size: 64,
                    color: colors.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Bienvenido',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Inicia sesión para acceder a tu portal.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colors.onSurface.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 48),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushReplacement(
                          context, SlideRightRoute(page: const LoginScreen()));
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                    ),
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text('Ingresar al Portal'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
