import 'package:asystem_cobacam/screens/common/lock_screen.dart';
import 'package:asystem_cobacam/services/lock_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SessionGuard extends StatelessWidget {
  final Widget child;
  const SessionGuard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Consumer<LockService>(
      builder: (context, lockService, _) {
        if (lockService.isLocked) {
          return const LockScreen();
        }
        return child;
      },
    );
  }
}
