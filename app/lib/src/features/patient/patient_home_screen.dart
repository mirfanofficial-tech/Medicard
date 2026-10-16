import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/language.dart';
import '../../theme.dart';
import '../../ui/widgets.dart';
import '../chat/chat_panel.dart';
import '../chat/chat_controller.dart';
import '../../demo/demo_data.dart' show demoPatientChatQuestions;
import '../care/care_models.dart';
import 'patient_repository.dart';

/// One simple page: next medicine, today's care, plain-language summary, latest
/// reports, small steps and an ask box. Everything else is one tap away.
class PatientHomeScreen extends ConsumerWidget {
  const PatientHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(patientHomeProvider);
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(patientHomeProvider.future),
          child: home.when(
            loading: () => const LoadingBlock(),
            error: (e, _) => ListView(children: [ErrorBlock(e)]),
            data: (h) => Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  children: _sections(context, ref, h),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _sections(BuildContext context, WidgetRef ref, PatientHome h) {
    return [
      _Header(name: h.name),
      const SizedBox(height: 14),
      _AskBar(questions: h.asks),
      if (h.pendingRequests > 0) ...[
        const SizedBox(height: 16),
        _RequestBanner(count: h.pendingRequests),
      ],
      const SizedBox(height: 16),
      if (h.nextMedicine != null)
        _NextMedicineCard(
          next: h.nextMedicine!,
          onTook: () async {
            await ref.read(patientRepositoryProvider).logCare(h.nextMedicine!.key, true);
            ref.invalidate(patientHomeProvider);
          },
        )
      else
        const _AllDoneCard(),
      const SizedBox(height: 14),
      _TodayCard(today: h.today),
      if (h.numbers.isNotEmpty) ...[
        const _Title('My numbers', 'میرے نتائج'),
        _Numbers(h.numbers),
      ],
      const _Title('Your health, simply', 'آپ کی صحت'),
      _SummaryCard(summary: h.summary),
      const _Title('Your latest reports', 'رپورٹس'),
      if (h.reports.isEmpty)
        const Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text('No reports yet. Tap Scan to add your first one.',
                style: TextStyle(fontSize: 15)),
          ),
        )
      else
        for (final r in h.reports) ...[
          _ReportTile(r),
          const SizedBox(height: 10),
        ],
      const SizedBox(height: 2),
      OutlinedButton.icon(
        onPressed: () => context.go('/patient/records'),
        icon: const Icon(Icons.keyboard_arrow_down),
        label: const Text('Load more reports'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: MediCardColors.primary, width: 1.5),
        ),
      ),
      if (h.followUp != null) ...[
        const SizedBox(height: 14),
        _FollowUpCard(h.followUp!),
      ],
      if (h.tips.isNotEmpty) ...[
        const _Title('Small steps for you', 'چھوٹے قدم'),
        for (final t in h.tips) ...[
          _TipTile(t),
          const SizedBox(height: 10),
        ],
      ],
      if (h.emergency != null) ...[
        const _Title('Emergency card', 'ہنگامی کارڈ'),
        _EmergencyCard(h.emergency!),
      ],
    ];
  }
}

class _Title extends StatelessWidget {
  const _Title(this.en, this.ur);
  final String en;
  final String ur;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 26, 0, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Text(en, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
            ),
            Text(ur, style: const TextStyle(fontSize: 14, color: MediCardColors.muted)),
          ],
        ),
      );
}

class _Header extends ConsumerWidget {
  const _Header({required this.name});
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final urdu = ref.watch(urduProvider);
    final initials = name.trim().split(' ').where((p) => p.isNotEmpty).take(2).map((p) => p[0]).join();
    return Row(children: [
      InkWell(
        onTap: () => context.go('/patient/profile'),
        customBorder: const CircleBorder(),
        child: CircleAvatar(
          radius: 24,
          backgroundColor: MediCardColors.primary,
          child: Text(initials.toUpperCase(),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('السلام علیکم', style: TextStyle(fontSize: 15, color: MediCardColors.muted)),
          Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        ]),
      ),
      Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: MediCardColors.border),
        ),
        child: Row(children: [
          _LangChip('اردو', urdu, () => ref.read(urduProvider.notifier).state = true),
          _LangChip('EN', !urdu, () => ref.read(urduProvider.notifier).state = false),
        ]),
      ),
    ]);
  }
}

class _LangChip extends StatelessWidget {
  const _LangChip(this.label, this.on, this.onTap);
  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: on ? MediCardColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: on ? Colors.white : MediCardColors.muted)),
        ),
      );
}

class _RequestBanner extends StatelessWidget {
  const _RequestBanner({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () => context.push('/patient/sharing/requests'),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            const Icon(Icons.shield_outlined, color: Color(0xFFB45309)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                count == 1
                    ? 'A doctor wants to see your records.\nTap to allow or say no'
                    : '$count doctors want to see your records.\nTap to allow or say no',
                style: const TextStyle(fontSize: 14, height: 1.35, fontWeight: FontWeight.w600),
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF92400E)),
          ]),
        ),
      );
}

class _NextMedicineCard extends StatefulWidget {
  const _NextMedicineCard({required this.next, required this.onTook});
  final NextMedicine next;
  final Future<void> Function() onTook;

  @override
  State<_NextMedicineCard> createState() => _NextMedicineCardState();
}

class _NextMedicineCardState extends State<_NextMedicineCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final n = widget.next;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [MediCardColors.primaryDark, MediCardColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: MediCardColors.primary.withOpacity(0.28),
              blurRadius: 30,
              offset: const Offset(0, 14)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('NEXT MEDICINE',
              style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w800,
                  color: Colors.white.withOpacity(0.85))),
          const Spacer(),
          Text('اگلی دوا', style: TextStyle(color: Colors.white.withOpacity(0.9))),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(18)),
            child: const Icon(Icons.medication_outlined, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(n.name,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
              const SizedBox(height: 4),
              Text('${n.at} · ${n.relative}',
                  style: TextStyle(fontSize: 15, color: Colors.white.withOpacity(0.9))),
            ]),
          ),
        ]),
        const SizedBox(height: 16),
        SizedBox(
          height: 56,
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _busy
                ? null
                : () async {
                    setState(() => _busy = true);
                    try {
                      await widget.onTook();
                    } finally {
                      if (mounted) setState(() => _busy = false);
                    }
                  },
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('I took it', style: TextStyle(fontSize: 17)),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: MediCardColors.primaryDark,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
      ]),
    );
  }
}

class _AllDoneCard extends StatelessWidget {
  const _AllDoneCard();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: const Color(0xFFECFDF3),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFBBF7D0))),
        child: const Row(children: [
          Icon(Icons.check_circle, color: MediCardColors.success, size: 34),
          SizedBox(width: 14),
          Expanded(
            child: Text('All medicines taken for today. Well done! 👏',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ]),
      );
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.today});
  final TodayView today;

  @override
  Widget build(BuildContext context) {
    final frac = today.total == 0 ? 0.0 : today.done / today.total;
    return InkWell(
      onTap: () => context.push('/patient/care-plan'),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: MediCardColors.border),
        ),
        child: Row(children: [
          SizedBox(
            width: 52,
            height: 52,
            child: Stack(alignment: Alignment.center, children: [
              CircularProgressIndicator(
                value: frac,
                strokeWidth: 6,
                backgroundColor: MediCardColors.border,
                color: MediCardColors.primary,
              ),
              Text('${today.done}/${today.total}',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
            ]),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("Today's care", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              SizedBox(height: 2),
              Text('Medicines, diet and activity',
                  style: TextStyle(fontSize: 13, color: MediCardColors.muted)),
            ]),
          ),
          const Text('See plan ›',
              style: TextStyle(
                  color: MediCardColors.primary, fontWeight: FontWeight.w800, fontSize: 13.5)),
        ]),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});
  final HomeSummary summary;

  @override
  Widget build(BuildContext context) {
    final pts = summary.trend;
    final maxV = pts.isEmpty ? 1.0 : pts.map((p) => p.value).reduce((a, b) => a > b ? a : b);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MediCardColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(summary.text, style: const TextStyle(fontSize: 15.5, height: 1.55)),
        if (pts.length >= 2) ...[
          const SizedBox(height: 14),
          SizedBox(
            height: 100,
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              for (var i = 0; i < pts.length; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 7),
                    child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                      Text(pts[i].value.toStringAsFixed(1),
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: _barColor(i, pts.length))),
                      const SizedBox(height: 3),
                      Container(
                        height: 12 + 40 * (pts[i].value / maxV),
                        decoration: BoxDecoration(
                          color: _barColor(i, pts.length),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(pts[i].label,
                          style: const TextStyle(fontSize: 11, color: MediCardColors.muted)),
                    ]),
                  ),
                ),
            ]),
          ),
        ],
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
              color: MediCardColors.bg, borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            const Icon(Icons.auto_awesome, size: 15, color: MediCardColors.muted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(summary.note,
                  style: const TextStyle(fontSize: 12, color: MediCardColors.muted)),
            ),
          ]),
        ),
      ]),
    );
  }

  Color _barColor(int i, int n) => i == n - 1
      ? MediCardColors.danger
      : i == n - 2
          ? MediCardColors.warning
          : const Color(0xFF7FC4BE);
}

class _ReportTile extends StatelessWidget {
  const _ReportTile(this.r);
  final ReportItem r;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (r.level) {
      'high' || 'low' => (const Color(0xFFFEE2E2), const Color(0xFFB91C1C)),
      'normal' => (const Color(0xFFDCFCE7), const Color(0xFF15803D)),
      _ => (MediCardColors.bg, MediCardColors.muted),
    };
    return InkWell(
      onTap: () => context.push('/patient/records/${r.recordId}'),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: MediCardColors.border),
        ),
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
                color: const Color(0xFFDBEAFE), borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.science_outlined, color: Color(0xFF1D4ED8)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
              const SizedBox(height: 2),
              Text(r.sub, style: const TextStyle(fontSize: 12.5, color: MediCardColors.muted)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
            child: Text(r.verdict,
                style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 12)),
          ),
        ]),
      ),
    );
  }
}

class _FollowUpCard extends StatelessWidget {
  const _FollowUpCard(this.f);
  final FollowUp f;

  @override
  Widget build(BuildContext context) {
    final d = DateTime.tryParse(f.date);
    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: MediCardColors.primary, width: 1.5),
      ),
      child: Row(children: [
        Container(
          width: 54,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
              color: MediCardColors.primaryTint, borderRadius: BorderRadius.circular(14)),
          child: Column(children: [
            Text(d == null ? '' : months[d.month - 1],
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF0A5D57))),
            Text(d == null ? '' : '${d.day}',
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF0A5D57))),
          ]),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Next visit${f.withDoctor != null ? ' · ${f.withDoctor}' : ''}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 2),
            Text(f.when, style: const TextStyle(fontSize: 13, color: MediCardColors.muted)),
          ]),
        ),
      ]),
    );
  }
}

class _TipTile extends StatelessWidget {
  const _TipTile(this.t);
  final Tip t;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: t.fromDoctor ? MediCardColors.primaryTint : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: MediCardColors.border),
        ),
        child: Row(children: [
          Text(t.emoji, style: const TextStyle(fontSize: 26)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 2),
              Text(t.sub, style: const TextStyle(fontSize: 13, color: Color(0xFF475569))),
            ]),
          ),
        ]),
      );
}


/// Always-visible entry to the AI assistant: a search-style bar plus quick questions.
class _AskBar extends StatelessWidget {
  const _AskBar({required this.questions});
  final List<String> questions;

  void _open(BuildContext context, [String? q]) => showChat(
        context,
        scope: const ChatScope.patient(),
        title: 'Your health assistant',
        subtitle: 'Answers from your own records',
        welcome: 'Hello! I can explain your reports, medicines, diet and next tests in simple '
            'words. What would you like to know?',
        suggestions: demoPatientChatQuestions,
        firstQuestion: q,
      );

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      InkWell(
        onTap: () => _open(context),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 56,
          padding: const EdgeInsets.only(left: 16, right: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: MediCardColors.primary.withOpacity(0.5), width: 1.5),
            boxShadow: [
              BoxShadow(
                  color: MediCardColors.primary.withOpacity(0.10),
                  blurRadius: 16,
                  offset: const Offset(0, 6)),
            ],
          ),
          child: Row(children: [
            const Icon(Icons.auto_awesome, color: MediCardColors.primary),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Ask your health assistant…',
                  style: TextStyle(color: MediCardColors.muted, fontSize: 15)),
            ),
            Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(color: MediCardColors.primary, shape: BoxShape.circle),
              child: const Icon(Icons.mic, color: Colors.white, size: 22),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 10),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (final q in questions.take(3))
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ActionChip(
                label: Text(q),
                onPressed: () => _open(context, q),
                backgroundColor: MediCardColors.primaryTint,
                side: BorderSide.none,
                labelStyle: const TextStyle(
                    color: Color(0xFF0A5D57), fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
        ]),
      ),
    ]);
  }
}

class _Numbers extends StatelessWidget {
  const _Numbers(this.items);
  final List<NumberTile> items;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 132,
        child: Row(children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(child: _NumberCard(items[i])),
          ],
        ]),
      );
}

class _NumberCard extends StatelessWidget {
  const _NumberCard(this.n);
  final NumberTile n;

  @override
  Widget build(BuildContext context) {
    final (color, word) = switch (n.status) {
      'high' => (MediCardColors.danger, 'High'),
      'low' => (MediCardColors.warning, 'Low'),
      'normal' => (MediCardColors.success, 'Good'),
      _ => (MediCardColors.muted, ''),
    };
    final arrow = switch (n.trend) {
      'up' => Icons.arrow_upward,
      'down' => Icons.arrow_downward,
      _ => Icons.arrow_forward,
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(n.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: MediCardColors.muted, height: 1.2)),
        const Spacer(),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(n.value,
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: color)),
            ),
          ),
          const SizedBox(width: 3),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Icon(arrow, size: 15, color: color),
          ),
        ]),
        if (word.isNotEmpty)
          Text(word, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
        Text(n.goal,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10.5, color: MediCardColors.muted)),
      ]),
    );
  }
}

class _EmergencyCard extends StatelessWidget {
  const _EmergencyCard(this.e);
  final EmergencyCard e;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF5F5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.emergency, color: MediCardColors.danger),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Show this to a doctor in an emergency',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
            ),
            if (e.bloodGroup != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: MediCardColors.danger, borderRadius: BorderRadius.circular(10)),
                child: Text(e.bloodGroup!,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
              ),
          ]),
          const SizedBox(height: 12),
          _line('Allergies', e.allergies.isEmpty ? 'None known' : e.allergies.join(', '),
              MediCardColors.danger),
          _line('Conditions', e.conditions.join(', '), const Color(0xFF475569)),
          _line('Medicines', e.medicines.join(' · '), const Color(0xFF475569)),
        ]),
      );

  Widget _line(String k, String v, Color c) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Text.rich(TextSpan(children: [
          TextSpan(text: '$k: ', style: TextStyle(fontWeight: FontWeight.w800, color: c)),
          TextSpan(text: v),
        ]), style: const TextStyle(fontSize: 13.5, height: 1.4)),
      );
}
