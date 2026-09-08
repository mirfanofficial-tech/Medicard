import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Center(
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: MediCardColors.primaryTint,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: const Icon(Icons.health_and_safety,
                      size: 52, color: MediCardColors.primary),
                ),
              ),
              const SizedBox(height: 24),
              const Text('MediCard',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 30, fontWeight: FontWeight.w800, color: MediCardColors.ink)),
              const SizedBox(height: 8),
              const Text(
                'Your complete health history.\nAnywhere. Instantly.',
                textAlign: TextAlign.center,
                style: TextStyle(color: MediCardColors.muted, height: 1.4),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => context.go('/patient/auth'),
                child: const Text('Get Started'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => context.go('/patient/auth'),
                child: const Text('I already have an account'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.go('/doctor/auth'),
                child: const Text("I'm a doctor"),
              ),
              const SizedBox(height: 8),
              const Text('Your data. Your control.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: MediCardColors.muted)),
            ],
          ),
        ),
      ),
    );
  }
}
