import 'package:flutter/material.dart';

class ManageClassroomsScreen extends StatelessWidget {
  const ManageClassroomsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestionar Aulas'),
      ),
      body: const Center(
        child: Text('Pantalla de Gestión de Aulas'),
      ),
    );
  }
}
