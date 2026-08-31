import 'package:flutter/material.dart';

/// MediCard palette. The one rule that matters app-wide: verified clinical data
/// reads green, unverified (AI-extracted, not yet confirmed) reads amber, and the
/// two must never be visually confusable.
class MediCardColors {
  static const seed = Color(0xFF1B6FB3);
  static const verified = Color(0xFF1B873F);
  static const unverified = Color(0xFFB25E00);
  static const danger = Color(0xFFC62828);
}

ThemeData buildMediCardTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: MediCardColors.seed);
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    appBarTheme: const AppBarTheme(centerTitle: false),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );
}

/// Small pill used wherever a record or field is shown, so provenance is always
/// visible at a glance.
class ProvenanceTag extends StatelessWidget {
  const ProvenanceTag({super.key, required this.verified});

  final bool verified;

  @override
  Widget build(BuildContext context) {
    final color = verified ? MediCardColors.verified : MediCardColors.unverified;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        verified ? 'Verified' : 'Unverified',
        style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}
