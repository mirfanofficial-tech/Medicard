import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme.dart';
import 'widgets.dart';

/// One selling point shown on the brand panel / header.
class AuthPoint {
  const AuthPoint(this.icon, this.text);
  final IconData icon;
  final String text;
}

/// Responsive frame for the sign-in / sign-up screens.
///
/// Wide (desktop / tablet landscape): brand panel on the left, form on the right.
/// Narrow (phone): compact gradient header, form card below it.
class AuthShell extends StatelessWidget {
  const AuthShell({
    super.key,
    required this.roleLabel,
    required this.headline,
    required this.tagline,
    required this.points,
    required this.child,
    this.onBack,
  });

  /// e.g. "For patients" / "For doctors".
  final String roleLabel;
  final String headline;
  final String tagline;
  final List<AuthPoint> points;
  final Widget child;
  final VoidCallback? onBack;

  static const _gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [MediCardColors.primaryDark, MediCardColors.primary],
  );

  static const double wideBreakpoint = 860;

  void _back(BuildContext context) => (onBack ?? () => context.go('/'))();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, c) =>
            c.maxWidth >= wideBreakpoint ? _wide(context) : _narrow(context),
      ),
    );
  }

  Widget _wide(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: Container(
            decoration: const BoxDecoration(gradient: _gradient),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(56, 32, 56, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Logo(light: true),
                    const Spacer(),
                    _RoleChip(roleLabel),
                    const SizedBox(height: 16),
                    Text(headline,
                        style: const TextStyle(
                            fontSize: 40,
                            height: 1.15,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
                    const SizedBox(height: 14),
                    Text(tagline,
                        style: TextStyle(
                            fontSize: 16, height: 1.5, color: Colors.white.withOpacity(0.85))),
                    const SizedBox(height: 32),
                    for (final p in points) _PointRow(p),
                    const Spacer(),
                    Text('Your data. Your control.',
                        style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
                  ],
                ),
              ),
            ),
          ),
        ),
        Expanded(
          flex: 4,
          child: SafeArea(
            child: Stack(
              children: [
                Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 56),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: child,
                    ),
                  ),
                ),
                Positioned(
                  top: 16,
                  left: 16,
                  child: TextButton.icon(
                    onPressed: () => _back(context),
                    icon: const Icon(Icons.arrow_back, size: 18),
                    label: const Text('Back'),
                    style: TextButton.styleFrom(foregroundColor: MediCardColors.muted),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _narrow(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: _gradient,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(
                      onPressed: () => _back(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      tooltip: 'Back',
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _Logo(light: true),
                          const SizedBox(height: 18),
                          _RoleChip(roleLabel),
                          const SizedBox(height: 10),
                          Text(headline,
                              style: const TextStyle(
                                  fontSize: 24,
                                  height: 1.2,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white)),
                          const SizedBox(height: 6),
                          Text(tagline,
                              style: TextStyle(
                                  fontSize: 14,
                                  height: 1.4,
                                  color: Colors.white.withOpacity(0.85))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            child: Center(
              child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480), child: child),
            ),
          ),
        ],
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo({required this.light});
  final bool light;

  @override
  Widget build(BuildContext context) {
    final fg = light ? Colors.white : MediCardColors.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(light ? 0.18 : 1),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(Icons.health_and_safety, color: fg, size: 22),
        ),
        const SizedBox(width: 10),
        Text('MediCard',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: fg)),
      ],
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label.toUpperCase(),
          style: const TextStyle(
              color: Colors.white, fontSize: 11, letterSpacing: 1, fontWeight: FontWeight.w700)),
    );
  }
}

class _PointRow extends StatelessWidget {
  const _PointRow(this.point);
  final AuthPoint point;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(point.icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Text(point.text,
                  style: TextStyle(color: Colors.white.withOpacity(0.92), fontSize: 14.5, height: 1.3)),
            ),
          ),
        ],
      ),
    );
  }
}

/// White rounded card that holds the form. Used inside [AuthShell].
class AuthCard extends StatelessWidget {
  const AuthCard({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: MediCardColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MediCardColors.border),
        boxShadow: [
          BoxShadow(
            color: MediCardColors.ink.withOpacity(0.05),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Two-option pill toggle (e.g. Create account / Sign in).
class AuthToggle extends StatelessWidget {
  const AuthToggle({
    super.key,
    required this.leftLabel,
    required this.rightLabel,
    required this.leftSelected,
    required this.onChanged,
  });

  final String leftLabel;
  final String rightLabel;
  final bool leftSelected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget seg(String label, bool left) {
      final on = left == leftSelected;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(left),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              color: on ? MediCardColors.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              boxShadow: on
                  ? [BoxShadow(color: MediCardColors.ink.withOpacity(0.08), blurRadius: 6)]
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: on ? MediCardColors.primary : MediCardColors.muted)),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: MediCardColors.bg,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: MediCardColors.border),
      ),
      child: Row(children: [seg(leftLabel, true), seg(rightLabel, false)]),
    );
  }
}

/// Inline error shown under a form.
class AuthError extends StatelessWidget {
  const AuthError(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) =>
      InfoBanner(message, icon: Icons.error_outline, color: MediCardColors.danger);
}
