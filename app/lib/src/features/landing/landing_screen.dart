import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme.dart';

const _mint = Color(0xFF7CF0D6);

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MediCardColors.primaryDark,
      body: Stack(children: [
        const Positioned.fill(child: _Backdrop()),
        SafeArea(
          child: LayoutBuilder(builder: (context, c) {
            final wide = c.maxWidth >= 900;
            final tall = c.maxHeight >= 780;
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: c.maxHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1180),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: wide ? 48 : 24, vertical: wide ? 40 : 20),
                      child: wide
                          ? const Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                              Expanded(flex: 6, child: _Hero(wide: true)),
                              SizedBox(width: 40),
                              Expanded(flex: 5, child: _CardShowcase()),
                            ])
                          : Column(children: [
                              const _Hero(wide: false),
                              if (tall) ...const [
                                SizedBox(height: 28),
                                _CardShowcase(compact: true),
                              ],
                            ]),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ]),
    );
  }
}

/// Gradient background with soft circles.
class _Backdrop extends StatelessWidget {
  const _Backdrop();

  Widget _circle(double size, Color color, {double? l, double? t, double? r, double? b}) =>
      Positioned(
        left: l,
        top: t,
        right: r,
        bottom: b,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF063F3B), MediCardColors.primaryDark, MediCardColors.primary],
          stops: [0, 0.45, 1],
        ),
      ),
      child: Stack(children: [
        _circle(520, Colors.white.withOpacity(0.05), r: -160, t: -180),
        _circle(340, Colors.white.withOpacity(0.06), l: -120, b: -120),
        _circle(220, _mint.withOpacity(0.10), r: 120, b: 80),
        _circle(120, Colors.white.withOpacity(0.07), l: 140, t: 90),
        _circle(36, _mint.withOpacity(0.35), l: 90, t: 240),
        _circle(22, Colors.white.withOpacity(0.25), r: 80, t: 150),
      ]),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.wide});
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final align = wide ? CrossAxisAlignment.start : CrossAxisAlignment.center;
    final ta = wide ? TextAlign.left : TextAlign.center;
    return Column(crossAxisAlignment: align, mainAxisSize: MainAxisSize.min, children: [
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.16),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white24),
          ),
          child: const Icon(Icons.health_and_safety, color: Colors.white, size: 26),
        ),
        const SizedBox(width: 12),
        const Text('MediCard',
            style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
      ]),
      SizedBox(height: wide ? 48 : 28),
      Text(
        'Your complete health history.\nAnywhere. Instantly.',
        textAlign: ta,
        style: TextStyle(
          color: Colors.white,
          fontSize: wide ? 50 : 30,
          height: 1.12,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 14),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Text(
          'Keep every prescription and report in one place — and share it with a doctor '
          'only when you say so.',
          textAlign: ta,
          style: TextStyle(
              color: Colors.white.withOpacity(0.85), fontSize: wide ? 17 : 15, height: 1.5),
        ),
      ),
      SizedBox(height: wide ? 28 : 22),
      _Motto(wide: wide),
      SizedBox(height: wide ? 34 : 26),
      ConstrainedBox(
        constraints: BoxConstraints(maxWidth: wide ? 420 : 460),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          FilledButton(
            onPressed: () => context.go('/patient/auth'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: MediCardColors.primaryDark,
              minimumSize: const Size.fromHeight(56),
              elevation: 0,
            ),
            child: const Text('Get Started', style: TextStyle(fontSize: 16)),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => context.go('/patient/auth'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white70, width: 1.5),
              minimumSize: const Size.fromHeight(56),
            ),
            child: const Text('I already have an account', style: TextStyle(fontSize: 16)),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => context.go('/doctor/auth'),
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: const Text("I'm a doctor", style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
    ]);
  }
}

/// "Your data. Your control." — set as a statement, with a gradient stroke under "control".
class _Motto extends StatelessWidget {
  const _Motto({required this.wide});
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final size = wide ? 26.0 : 22.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: wide ? MainAxisAlignment.start : MainAxisAlignment.center,
      children: [
        Container(
          width: 4,
          height: size * 2.1,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_mint, Colors.white24],
            ),
          ),
        ),
        const SizedBox(width: 14),
        Flexible(
            child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Your data.',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.78),
                      fontSize: size,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3)),
              const SizedBox(height: 2),
              Stack(alignment: Alignment.bottomLeft, children: [
                Container(
                  height: 9,
                  margin: const EdgeInsets.only(bottom: 3),
                  width: size * 6.4,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    gradient: LinearGradient(
                        colors: [_mint.withOpacity(0.55), _mint.withOpacity(0.0)]),
                  ),
                ),
                Text('Your control.',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: size + 6,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3)),
              ]),
            ]),
        )),
      ],
    );
  }
}

/// A floating MediCard with soft rings behind it.
class _CardShowcase extends StatelessWidget {
  const _CardShowcase({this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final h = compact ? 240.0 : 470.0;
    return SizedBox(
      height: h,
      child: Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
        Container(
          width: compact ? 230 : 400,
          height: compact ? 230 : 400,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              Colors.white.withOpacity(0.16),
              Colors.white.withOpacity(0.0),
            ]),
          ),
        ),
        Container(
          width: compact ? 200 : 340,
          height: compact ? 200 : 340,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.16), width: 1.5),
          ),
        ),
        Transform.rotate(
          angle: -0.1,
          child: Container(
            width: compact ? 270 : 330,
            height: compact ? 150 : 190,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              color: Colors.white.withOpacity(0.14),
              border: Border.all(color: Colors.white24),
            ),
          ),
        ),
        _MockCard(compact: compact),
        if (!compact) ...const [
          Positioned(
              right: 0, top: 40, child: _Badge(Icons.verified, 'Verified by you', Color(0xFF15803D))),
          Positioned(
              left: 0,
              bottom: 52,
              child: _Badge(Icons.lock_person_outlined, 'Dr Sara needs your OK', Color(0xFF0E7A73))),
        ],
      ]),
    );
  }
}

class _MockCard extends StatelessWidget {
  const _MockCard({required this.compact});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: compact ? 250 : 320,
      padding: EdgeInsets.all(compact ? 16 : 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.28), blurRadius: 40, offset: const Offset(0, 22)),
        ],
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              const Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('MEDICARD CODE',
                      style: TextStyle(
                          fontSize: 10.5,
                          letterSpacing: 1.3,
                          fontWeight: FontWeight.w800,
                          color: MediCardColors.muted)),
                  SizedBox(height: 4),
                  Text('46A9 FT39',
                      style:
                          TextStyle(fontSize: 25, fontWeight: FontWeight.w800, letterSpacing: 3)),
                ]),
              ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: MediCardColors.primaryTint, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.qr_code_2, color: MediCardColors.primary, size: 28),
              ),
            ]),
            SizedBox(height: compact ? 12 : 20),
            const Wrap(spacing: 8, runSpacing: 6, children: [
              StatusPill(label: '6 records verified', color: MediCardColors.verified),
              StatusPill(label: '1 allergy', color: MediCardColors.danger),
            ]),
            SizedBox(height: compact ? 10 : 16),
            const Text('Ayesha Khan · Blood group B+',
                style: TextStyle(fontSize: 12.5, color: MediCardColors.muted)),
          ]),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.icon, this.text, this.color);
  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.18), blurRadius: 18, offset: const Offset(0, 8)),
          ],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: color)),
        ]),
      );
}
