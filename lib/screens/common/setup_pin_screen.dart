import 'package:asystem_cobacam/services/lock_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

enum PinSetupStep { create, confirm }

class SetupPinScreen extends StatefulWidget {
  const SetupPinScreen({super.key});

  @override
  State<SetupPinScreen> createState() => _SetupPinScreenState();
}

class _SetupPinScreenState extends State<SetupPinScreen> {
  PinSetupStep _currentStep = PinSetupStep.create;
  String _firstPin = '';
  String _secondPin = '';
  bool _isError = false;

  void _onNumberPressed(String number) {
    if (_isError) {
      _reset();
    }

    String currentPin =
        _currentStep == PinSetupStep.create ? _firstPin : _secondPin;
    if (currentPin.length < 4) {
      setState(() {
        if (_currentStep == PinSetupStep.create) {
          _firstPin += number;
        } else {
          _secondPin += number;
        }
      });

      if ((_currentStep == PinSetupStep.create && _firstPin.length == 4)) {
        Future.delayed(const Duration(milliseconds: 200), () {
          setState(() {
            _currentStep = PinSetupStep.confirm;
          });
        });
      } else if (_secondPin.length == 4) {
        _confirmPin();
      }
    }
  }

  void _onDeletePressed() {
    String currentPin =
        _currentStep == PinSetupStep.create ? _firstPin : _secondPin;
    if (currentPin.isNotEmpty) {
      setState(() {
        if (_currentStep == PinSetupStep.create) {
          _firstPin = _firstPin.substring(0, _firstPin.length - 1);
        } else {
          _secondPin = _secondPin.substring(0, _secondPin.length - 1);
        }
        _isError = false;
      });
    }
  }

  void _reset() {
    setState(() {
      _firstPin = '';
      _secondPin = '';
      _currentStep = PinSetupStep.create;
      _isError = false;
    });
  }

  Future<void> _confirmPin() async {
    if (_firstPin == _secondPin) {
      final lockService = Provider.of<LockService>(context, listen: false);
      await lockService.setPin(_firstPin);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PIN configurado correctamente.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } else {
      setState(() {
        _isError = true;
      });
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) {
        _reset();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String title;
    final String subtitle;
    final int dotCount;

    switch (_currentStep) {
      case PinSetupStep.create:
        title = 'Crea un PIN';
        subtitle = 'Establece un PIN de 4 dígitos para bloquear la aplicación.';
        dotCount = _firstPin.length;
        break;
      case PinSetupStep.confirm:
        title = 'Confirma tu PIN';
        subtitle = _isError
            ? 'Los PINs no coinciden. Inténtalo de nuevo.'
            : 'Vuelve a introducir el PIN.';
        dotCount = _secondPin.length;
        break;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurar PIN de Seguridad'),
      ),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            Icon(
              Icons.phonelink_lock_rounded,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 16,
                color: _isError
                    ? Theme.of(context).colorScheme.error
                    : Colors.grey,
              ),
            ),
            const SizedBox(height: 40),
            _buildPinDots(dotCount),
            const Spacer(),
            _buildNumpad(),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildPinDots(int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: index < count
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
            const SizedBox(width: 72, height: 72), // Placeholder
            _numpadButton('0'),
            _numpadButton(
              'delete',
              child: Icon(Icons.backspace_outlined, size: 28),
            ),
          ],
        ),
      ],
    );
  }

  Widget _numpadButton(String value, {Widget? child}) {
    return SizedBox(
      width: 72,
      height: 72,
      child: OutlinedButton(
        onPressed: () {
          if (value == 'delete') {
            _onDeletePressed();
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
