import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Text('MediCard', style: theme.textTheme.displaySmall),
              const SizedBox(height: 8),
              Text(
                'Your medical history, in your hands.',
                style: theme.textTheme.bodyLarge,
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => context.go('/patient/auth'),
                child: const Text("I'm a patient"),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => context.go('/doctor/auth'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: const Text("I'm a doctor"),
              ),
              const SizedBox(height: 24),
              Text(
                'AI in MediCard is advisory only. It never prescribes — the '
                'licensed physician retains full responsibility.',
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
