import 'package:flutter/material.dart';

/// MediCard palette — teal primary, with the one rule that matters app-wide:
/// verified clinical data reads green, unverified (AI-extracted, not yet
/// confirmed) reads amber, and the two must never be visually confusable.
class MediCardColors {
  static const primary = Color(0xFF0E7A73);
  static const primaryDark = Color(0xFF0A5D57);
  static const primaryTint = Color(0xFFE3F2F1);

  /// Legacy alias — some doctor screens still reference `seed`.
  static const seed = primary;

  static const verified = Color(0xFF15803D);
  static const success = Color(0xFF16A34A);
  static const unverified = Color(0xFFB45309);
  static const warning = Color(0xFFD97706);
  static const danger = Color(0xFFDC2626);

  static const bg = Color(0xFFF5F7F8);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFE6E9EC);
  static const ink = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);
}

ThemeData buildMediCardTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: MediCardColors.primary,
    primary: MediCardColors.primary,
    surface: MediCardColors.surface,
  );
  const radius = 14.0;

  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c, width: w),
      );

  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: MediCardColors.bg,
    textTheme: const TextTheme(
      titleLarge: TextStyle(fontWeight: FontWeight.w700, color: MediCardColors.ink),
      titleMedium: TextStyle(fontWeight: FontWeight.w700, color: MediCardColors.ink),
      titleSmall: TextStyle(fontWeight: FontWeight.w600, color: MediCardColors.ink),
      bodyMedium: TextStyle(color: MediCardColors.ink),
      bodySmall: TextStyle(color: MediCardColors.muted),
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      backgroundColor: MediCardColors.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: MediCardColors.ink,
      ),
      iconTheme: IconThemeData(color: MediCardColors.ink),
    ),
    cardTheme: CardThemeData(
      color: MediCardColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: const BorderSide(color: MediCardColors.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: MediCardColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: border(MediCardColors.border),
      enabledBorder: border(MediCardColors.border),
      focusedBorder: border(MediCardColors.primary, 1.5),
      hintStyle: const TextStyle(color: MediCardColors.muted),
      labelStyle: const TextStyle(color: MediCardColors.muted),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: MediCardColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: MediCardColors.primary,
        minimumSize: const Size.fromHeight(52),
        side: const BorderSide(color: MediCardColors.primary),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: MediCardColors.surface,
      selectedColor: MediCardColors.primary,
      side: const BorderSide(color: MediCardColors.border),
      labelStyle: const TextStyle(fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    ),
    dividerTheme: const DividerThemeData(color: MediCardColors.border, space: 1),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: MediCardColors.surface,
      selectedItemColor: MediCardColors.primary,
      unselectedItemColor: MediCardColors.muted,
      type: BottomNavigationBarType.fixed,
      showUnselectedLabels: true,
    ),
  );
}

/// Provenance pill — shown wherever a record or field appears so a doctor or
/// patient always knows whether a human confirmed it.
class ProvenanceTag extends StatelessWidget {
  const ProvenanceTag({super.key, required this.verified});

  final bool verified;

  @override
  Widget build(BuildContext context) {
    return StatusPill(
      label: verified ? 'Verified' : 'Unverified',
      color: verified ? MediCardColors.verified : MediCardColors.unverified,
      icon: verified ? Icons.verified : Icons.pending_outlined,
    );
  }
}

/// Small tinted status pill (Verified / Normal / Low / High / Active / Expired…).
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, required this.color, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(icon == null ? 10 : 8, 3, 10, 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 13, color: color), const SizedBox(width: 4)],
          Text(label,
              style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
        ],
      ),
    );
  }
}
