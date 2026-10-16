import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme.dart';
import '../../ui/widgets.dart';
import '../care/care_models.dart';
import 'patient_repository.dart';

class CarePlanScreen extends ConsumerWidget {
  const CarePlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(carePlanProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('My care plan'),
        leading: BackButton(onPressed: () => context.canPop() ? context.pop() : context.go('/patient')),
      ),
      body: plan.when(
        loading: () => const LoadingBlock(),
        error: (e, _) => ErrorBlock(e),
        data: (p) => RefreshIndicator(
          onRefresh: () => ref.refresh(carePlanProvider.future),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                children: [
                  if (p.hasPlan) ...[
                    Text('Made from ${p.issuedBy ?? 'your doctor'}\'s advice'
                        '${p.issuedOn != null ? ' on ${p.issuedOn}' : ''}',
                        style: const TextStyle(fontSize: 13, color: MediCardColors.muted)),
                    const SizedBox(height: 14),
                    _Progress(p),
                  ] else
                    const InfoBanner(
                      "Your doctor hasn't added a care plan yet. Your medicines for today are below.",
                    ),
                  const SizedBox(height: 22),
                  _TodayList(today: p.today),
                  if (p.hasPlan && (p.eatMore.isNotEmpty || p.eatLess.isNotEmpty)) ...[
                    const SizedBox(height: 26),
                    const Text('What to eat',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(child: _DietBox('✓ Eat more', p.eatMore, const Color(0xFFECFDF3),
                          const Color(0xFF15803D))),
                      const SizedBox(width: 10),
                      Expanded(child: _DietBox('✕ Eat less', p.eatLess, const Color(0xFFFEF2F2),
                          const Color(0xFFB91C1C))),
                    ]),
                    if (p.dietNote != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text('Based on your doctor\'s note: “${p.dietNote!.toLowerCase()}”.',
                            style: const TextStyle(fontSize: 12, color: MediCardColors.muted)),
                      ),
                  ],
                  if (p.events.isNotEmpty) ...[
                    const SizedBox(height: 26),
                    const Text('Coming up',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: MediCardColors.border),
                      ),
                      child: Column(children: [
                        for (var i = 0; i < p.events.length; i++) ...[
                          if (i > 0) const Divider(height: 1),
                          ListTile(
                            leading: Icon(
                              p.events[i].kind == 'test'
                                  ? Icons.science_outlined
                                  : Icons.event_available_outlined,
                              color: MediCardColors.primary,
                            ),
                            title: Text(p.events[i].title,
                                style: const TextStyle(fontWeight: FontWeight.w700)),
                            trailing: Text(p.events[i].when,
                                style: const TextStyle(
                                    color: MediCardColors.muted, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ]),
                    ),
                  ],
                  if (p.followUp != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: MediCardColors.primary, width: 1.5),
                      ),
                      child: Row(children: [
                        const Icon(Icons.event, color: MediCardColors.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Follow-up${p.followUp!.withDoctor != null ? ' with ${p.followUp!.withDoctor}' : ''}'
                            ' · ${p.followUp!.when}',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                          ),
                        ),
                      ]),
                    ),
                  ],
                  const SizedBox(height: 22),
                  Text(p.disclaimer,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: MediCardColors.muted, height: 1.5)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress(this.p);
  final CarePlanData p;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [MediCardColors.primaryDark, MediCardColors.primary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('Week ${p.week} of ${p.of}',
                style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
            const Spacer(),
            Text('${p.percent}% done',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 6),
          const Text("You're on track. Keep going 👏",
              style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: p.percent / 100,
              minHeight: 10,
              backgroundColor: Colors.white24,
              color: Colors.white,
            ),
          ),
        ]),
      );
}

class _DietBox extends StatelessWidget {
  const _DietBox(this.title, this.items, this.bg, this.fg);
  final String title;
  final List<String> items;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: bg, borderRadius: BorderRadius.circular(18), border: Border.all(color: fg.withOpacity(0.25))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: fg)),
          const SizedBox(height: 8),
          for (final i in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text(i, style: const TextStyle(fontSize: 14.5, height: 1.3)),
            ),
        ]),
      );
}

class _TodayList extends ConsumerStatefulWidget {
  const _TodayList({required this.today});
  final TodayView today;

  @override
  ConsumerState<_TodayList> createState() => _TodayListState();
}

class _TodayListState extends ConsumerState<_TodayList> {
  late TodayView _today = widget.today;
  final _pending = <String>{};

  @override
  void didUpdateWidget(covariant _TodayList old) {
    super.didUpdateWidget(old);
    _today = widget.today;
  }

  Future<void> _toggle(TodayItem i) async {
    if (_pending.contains(i.key)) return;
    setState(() => _pending.add(i.key));
    try {
      final t = await ref.read(patientRepositoryProvider).logCare(i.key, !i.done);
      if (mounted) setState(() => _today = t);
      ref.invalidate(patientHomeProvider);
    } finally {
      if (mounted) setState(() => _pending.remove(i.key));
    }
  }

  IconData _icon(String kind) => switch (kind) {
        'medicine' => Icons.medication_outlined,
        'diet' => Icons.restaurant_outlined,
        _ => Icons.directions_walk,
      };

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Text('Today', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const Spacer(),
        Text('${_today.done} of ${_today.total} done',
            style: const TextStyle(color: MediCardColors.muted, fontWeight: FontWeight.w600)),
      ]),
      const SizedBox(height: 10),
      if (_today.items.isEmpty)
        const Text('Nothing scheduled for today.',
            style: TextStyle(color: MediCardColors.muted)),
      for (final i in _today.items)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            onTap: () => _toggle(i),
            borderRadius: BorderRadius.circular(18),
            child: Container(
              constraints: const BoxConstraints(minHeight: 64),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: MediCardColors.border),
              ),
              child: Row(children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i.done ? MediCardColors.success : Colors.white,
                    border: Border.all(
                        color: i.done ? MediCardColors.success : const Color(0xFFCBD5E1), width: 2.5),
                  ),
                  child: i.done ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(i.title,
                        style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: i.done ? MediCardColors.muted : MediCardColors.ink,
                            decoration: i.done ? TextDecoration.lineThrough : null)),
                    const SizedBox(height: 2),
                    Text(i.sub,
                        style: const TextStyle(fontSize: 13, color: MediCardColors.muted)),
                  ]),
                ),
                Icon(_icon(i.kind), color: MediCardColors.primary),
              ]),
            ),
          ),
        ),
    ]);
  }
}
