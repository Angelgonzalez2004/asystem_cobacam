import 'package:asystem_cobacam/services/lock_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String _enteredPin = '';
  bool _isBiometricsAvailable = false;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _checkBiometricsAndAuthenticate();
  }

  Future<void> _checkBiometricsAndAuthenticate() async {
    final lockService = Provider.of<LockService>(context, listen: false);
    final available = await lockService.isBiometricsAvailable();
    setState(() {
      _isBiometricsAvailable = available;
    });
    // Si están disponibles, intentar autenticar inmediatamente al cargar la pantalla
    if (available) {
      await lockService.authenticateWithBiometrics();
    }
  }

  void _onNumberPressed(String number) {
    if (_isError) {
      setState(() {
        _isError = false;
        _enteredPin = '';
      });
    }
    if (_enteredPin.length < 4) {
      setState(() {
        _enteredPin += number;
      });
      if (_enteredPin.length == 4) {
        _verifyPin();
      }
    }
  }

  void _onDeletePressed() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
        _isError = false;
      });
    }
  }

  Future<void> _verifyPin() async {
    final lockService = Provider.of<LockService>(context, listen: false);
    final success = await lockService.verifyPin(_enteredPin);
    if (!success) {
      setState(() {
        _isError = true;
      });
      // Vibrate or shake animation can be added here
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        setState(() {
          _enteredPin = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            Icon(
              Icons.lock_outline_rounded,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            const Text(
              'Aplicación Bloqueada',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _isError ? 'PIN Incorrecto' : 'Ingresa tu PIN para continuar',
              style: TextStyle(
                fontSize: 16,
                color: _isError
                    ? Theme.of(context).colorScheme.error
                    : Colors.grey,
              ),
            ),
            const SizedBox(height: 40),
            _buildPinDots(),
            const Spacer(),
            _buildNumpad(),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildPinDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: index < _enteredPin.length
                ? (_isError
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.primary)
                : Colors.grey.shade300,
          ),
        );
      }),
    );
  }

  Widget _buildNumpad() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _numpadButton('1'),
            _numpadButton('2'),
            _numpadButton('3'),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _numpadButton('4'),
            _numpadButton('5'),
            _numpadButton('6'),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _numpadButton('7'),
            _numpadButton('8'),
            _numpadButton('9'),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _numpadButton(
              'biometrics',
              child: Icon(
                Icons.fingerprint,
                size: 32,
                color: _isBiometricsAvailable
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey.shade400,
              ),
            ),
            _numpadButton('0'),
            _numpadButton(
              'delete',
              child: const Icon(Icons.backspace_outlined, size: 28),
            ),
          ],
        ),
      ],
    );
  }

  Widget _numpadButton(String value, {Widget? child}) {
    // Hide biometrics button on web
    if (value == 'biometrics' && (kIsWeb || !_isBiometricsAvailable)) {
      return const SizedBox(width: 72, height: 72);
    }

    return SizedBox(
      width: 72,
      height: 72,
      child: OutlinedButton(
        onPressed: () {
          if (value == 'delete') {
            _onDeletePressed();
          } else if (value == 'biometrics') {
            Provider.of<LockService>(context, listen: false)
                .authenticateWithBiometrics();
          } else {
            _onNumberPressed(value);
          }
        },
        style: OutlinedButton.styleFrom(
          shape: const CircleBorder(),
          side: BorderSide.none,
          backgroundColor: Colors.grey.withOpacity(0.05),
        ),
        child: child ??
            Text(value,
                style:
                    const TextStyle(fontSize: 28, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
