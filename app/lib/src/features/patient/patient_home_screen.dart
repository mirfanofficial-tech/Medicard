import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PatientHomeScreen extends StatelessWidget {
  const PatientHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient'),
        leading: BackButton(onPressed: () => context.go('/')),
      ),
      body: const Center(
        child: Text('Patient home — timeline, uploads, access history (Phase 1+).'),
      ),
    );
  }
}
