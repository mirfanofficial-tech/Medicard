import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'scan_session.dart';

/// Shows the picture the patient scanned with a laser line sweeping over it and the
/// steps ticking off, then hands over to the review screen. (Demo mode: the data that
/// follows is static.)
class ScanAnimationScreen extends ConsumerStatefulWidget {
  const ScanAnimationScreen({super.key, required this.recordId});

  final String recordId;

  @override
  ConsumerState<ScanAnimationScreen> createState() => _ScanAnimationScreenState();
}

class _ScanAnimationScreenState extends ConsumerState<ScanAnimationScreen>
    with SingleTickerProviderStateMixin {
  static const _steps = [
    'Picture received',
    'Reading the text',
    'Finding medicines and test values',
    'Checking what we are unsure about',
  ];
  static const _stepMs = 1100;

  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
  )..repeat(reverse: true);

  Timer? _timer;
  int _step = 0;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: _stepMs), (t) {
      if (!mounted) return;
      if (_step < _steps.length) {
        setState(() => _step++);
      }
      if (_step >= _steps.length && !_done) {
        _done = true;
        t.cancel();
        _sweep.stop();
        setState(() {});
        Timer(const Duration(milliseconds: 1100), () {
          if (mounted) context.pushReplacement('/patient/records/${widget.recordId}/review');
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bytes = ref.watch(scanImageProvider);
    final progress = (_step / _steps.length).clamp(0.0, 1.0);
    return Scaffold(
      backgroundColor: const Color(0xFF071F1E),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 10, 22, 24),
              child: Column(children: [
                Row(children: [
                  IconButton(
                    onPressed: () => context.go('/patient/scan'),
                    icon: const Icon(Icons.close, color: Colors.white),
                    tooltip: 'Cancel',
                  ),
                  const Spacer(),
                  const Text('Scanning',
                      style: TextStyle(
                          color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  const SizedBox(width: 48),
                ]),
                const SizedBox(height: 8),
                Expanded(child: _Scanner(bytes: bytes, sweep: _sweep, done: _done)),
                const SizedBox(height: 18),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: _done ? 1 : progress,
                    minHeight: 6,
                    backgroundColor: Colors.white12,
                    color: const Color(0xFF7CF0D6),
                  ),
                ),
                const SizedBox(height: 14),
                for (var i = 0; i < _steps.length; i++) _StepRow(_steps[i], i < _step, i == _step),
                if (_done)
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text('Done — please check the details',
                        style: TextStyle(
                            color: Color(0xFF7CF0D6), fontWeight: FontWeight.w800, fontSize: 15)),
                  ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow(this.text, this.done, this.active);
  final String text;
  final bool done;
  final bool active;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          SizedBox(
            width: 22,
            height: 22,
            child: done
                ? const Icon(Icons.check_circle, color: Color(0xFF7CF0D6), size: 22)
                : active
                    ? const Padding(
                        padding: EdgeInsets.all(3),
                        child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                      )
                    : const Icon(Icons.circle_outlined, color: Colors.white30, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                    color: done || active ? Colors.white : Colors.white38)),
          ),
        ]),
      );
}

class _Scanner extends StatelessWidget {
  const _Scanner({required this.bytes, required this.sweep, required this.done});
  final Uint8List? bytes;
  final AnimationController sweep;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      return Stack(alignment: Alignment.center, children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
                color: done ? const Color(0xFF7CF0D6) : Colors.white24, width: done ? 2.5 : 1.5),
            boxShadow: [
              BoxShadow(
                  color: const Color(0xFF7CF0D6).withOpacity(done ? 0.35 : 0.14),
                  blurRadius: 34,
                  spreadRadius: 2),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              width: c.maxWidth,
              height: c.maxHeight,
              child: Stack(fit: StackFit.expand, children: [
                Container(color: const Color(0xFF0B2A28)),
                if (bytes != null)
                  Image.memory(
                    bytes!,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Icon(Icons.description_outlined, color: Colors.white54, size: 90),
                    ),
                  )
                else
                  const Center(
                    child: Icon(Icons.description_outlined, color: Colors.white54, size: 90),
                  ),
                if (!done)
                  AnimatedBuilder(
                    animation: sweep,
                    builder: (context, _) {
                      final y = Curves.easeInOut.transform(sweep.value) * c.maxHeight;
                      return Stack(children: [
                        // glowing trail above the line
                        Positioned(
                          left: 0,
                          right: 0,
                          top: 0,
                          height: y,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  const Color(0xFF7CF0D6).withOpacity(0.0),
                                  const Color(0xFF7CF0D6).withOpacity(0.22),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          top: y - 1.5,
                          child: Container(
                            height: 3,
                            decoration: BoxDecoration(
                              color: const Color(0xFF7CF0D6),
                              boxShadow: [
                                BoxShadow(
                                    color: const Color(0xFF7CF0D6).withOpacity(0.9),
                                    blurRadius: 16,
                                    spreadRadius: 2),
                              ],
                            ),
                          ),
                        ),
                      ]);
                    },
                  ),
                if (done)
                  Container(
                    color: const Color(0xFF7CF0D6).withOpacity(0.16),
                    child: const Center(
                      child: Icon(Icons.check_circle, color: Color(0xFF7CF0D6), size: 84),
                    ),
                  ),
              ]),
            ),
          ),
        ),
        const Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _Brackets()))),
      ]);
    });
  }
}

/// Camera-style corner marks around the document.
class _Brackets extends CustomPainter {
  const _Brackets();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFF7CF0D6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    const l = 30.0;
    const m = 10.0;
    void corner(double x, double y, double dx, double dy) {
      canvas.drawLine(Offset(x, y), Offset(x + dx * l, y), p);
      canvas.drawLine(Offset(x, y), Offset(x, y + dy * l), p);
    }

    corner(m, m, 1, 1);
    corner(size.width - m, m, -1, 1);
    corner(m, size.height - m, 1, -1);
    corner(size.width - m, size.height - m, -1, -1);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
