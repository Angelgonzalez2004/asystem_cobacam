import 'package:asystem_cobacam/utils/animations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  // MÉTODO PARA MOSTRAR MENSAJES INSTITUCIONALES
  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isError ? Icons.error_outline : Icons.mark_email_read_outlined, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        backgroundColor: isError ? Colors.red.shade900.withOpacity(0.9) : const Color(0xFF1E3A8A).withOpacity(0.95),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _handlePasswordReset() async {
    if (_emailController.text.trim().isEmpty) {
      _showMessage('Por favor, ingresa tu correo institucional.', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: _emailController.text.trim());
      if (mounted) {
        _showMessage('¡Enviado! Revisa tu bandeja de entrada para restablecer tu contraseña.');
        await Future.delayed(const Duration(seconds: 3));
        if (!mounted) return;
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String message = 'Ocurrió un error al procesar la solicitud.';
      if (e.code == 'user-not-found') {
        message = 'El correo ingresado no está registrado en el sistema.';
      } else if (e.code == 'invalid-email') {
        message = 'El formato del correo electrónico no es válido.';
      }
      _showMessage(message, isError: true);
    } catch (e) {
      if (mounted) _showMessage('Error de conexión. Intenta de nuevo más tarde.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Fondo Institucional
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1E3A8A), Color(0xFF1E293B), Color(0xFF0F172A)],
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40),
                child: FadeInUp(
                  duration: const Duration(milliseconds: 600),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Container(
                      padding: const EdgeInsets.all(40.0),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(40),
                        border: Border.all(color: Colors.white.withOpacity(0.15)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 60, offset: const Offset(0, 30)),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
                              child: const Icon(Icons.lock_reset_rounded, size: 50, color: Colors.white),
                            ),
                          ),
                          const SizedBox(height: 32),
                          const Text(
                            'RECUPERAR CUENTA',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w200, letterSpacing: 1.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Ingresa tu correo institucional registrado para recibir las instrucciones de recuperación.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14, height: 1.5),
                          ),
                          const SizedBox(height: 48),

                          _buildPremiumTextField(
                            controller: _emailController,
                            label: 'CORREO INSTITUCIONAL',
                            icon: Icons.email_outlined,
                          ),

                          const SizedBox(height: 40),

                          _isLoading
                              ? const Center(child: CircularProgressIndicator(color: Colors.white))
                              : ElevatedButton(
                                  onPressed: _handlePasswordReset,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: const Color(0xFF0F172A),
                                    minimumSize: const Size(double.infinity, 65),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                    elevation: 0,
                                  ),
                                  child: const Text(
                                    'ENVIAR ENLACE',
                                    style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5),
                                  ),
                                ),

                          const SizedBox(height: 40),
                          Center(
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text(
                                'Volver al inicio de sesión',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          Positioned(
            top: 50,
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white.withOpacity(0.2))),
          child: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
            cursorColor: Colors.white,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              filled: false,
              prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.8), size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              hintText: 'ejemplo@cobacam.edu.mx',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }
}
