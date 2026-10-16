import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/env.dart';
import '../../theme.dart';
import '../../ui/widgets.dart';
import '../access/access_repository.dart';
import '../care/care_models.dart';
import '../../demo/demo_data.dart' show demoDoctorDayQuestions, demoQuestions;
import '../chat/chat_controller.dart';
import '../chat/chat_panel.dart';
import 'doctor_top_bar.dart';

/// The doctor's landing dashboard: who they can see right now, what's waiting,
/// what needs attention and what they did this week.
class DoctorHomeScreen extends ConsumerStatefulWidget {
  const DoctorHomeScreen({super.key});

  @override
  ConsumerState<DoctorHomeScreen> createState() => _DoctorHomeScreenState();
}

class _DoctorHomeScreenState extends ConsumerState<DoctorHomeScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Keep the dashboard live: a patient's approval shows up without a manual refresh.
    _timer = Timer.periodic(
      Env.demo ? const Duration(seconds: 3) : const Duration(seconds: 20),
      (_) => ref.invalidate(doctorDashboardProvider),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(authControllerProvider).profile;
    final verified = (profile['status'] as String? ?? '') == 'active';
    final name = profile['name'] as String? ?? 'Doctor';

    return Scaffold(
      body: SafeArea(
        child: !verified
            ? _Unverified(name: name)
            : ref.watch(doctorDashboardProvider).when(
                  skipLoadingOnReload: true,
                  skipLoadingOnRefresh: true,
                  loading: () => const LoadingBlock(),
                  error: (e, _) => ListView(children: [ErrorBlock(e)]),
                  data: (d) => RefreshIndicator(
                    onRefresh: () => ref.refresh(doctorDashboardProvider.future),
                    child: _Dashboard(d: d),
                  ),
                ),
      ),
    );
  }
}

class _Unverified extends ConsumerWidget {
  const _Unverified({required this.name});
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Dr $name', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),
          const InfoBanner(
            'Your account is awaiting licence review. Searching patient records is disabled '
            'until a reviewer approves it.',
            icon: Icons.hourglass_top,
            color: MediCardColors.unverified,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
        ],
      );
}

String _greeting() {
  final h = DateTime.now().hour;
  return h < 12 ? 'Good morning' : h < 17 ? 'Good afternoon' : 'Good evening';
}

String _today() {
  const wd = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  const mo = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final n = DateTime.now();
  return '${wd[n.weekday - 1]}, ${n.day} ${mo[n.month - 1]} ${n.year}';
}

String _left(DateTime? t) {
  if (t == null) return '';
  final d = t.difference(DateTime.now());
  if (d.isNegative) return 'expired';
  return d.inHours > 0 ? '${d.inHours} h ${d.inMinutes % 60} m left' : '${d.inMinutes} m left';
}

String _ago(DateTime? t) {
  if (t == null) return '';
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 2) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  if (d.inDays == 1) return 'yesterday';
  return '${d.inDays} days ago';
}

Color _sev(String s) => switch (s) {
      'urgent' => MediCardColors.danger,
      'watch' => MediCardColors.warning,
      _ => MediCardColors.primary,
    };

class _Dashboard extends ConsumerWidget {
  const _Dashboard({required this.d});
  final DoctorDashboardData d;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= 1000;
      final pad = wide ? 32.0 : 16.0;
      final main = <Widget>[
        _RequestCard(onSent: () => ref.invalidate(doctorDashboardProvider)),
        const SizedBox(height: 18),
        if (d.schedule.isNotEmpty) ...[_Schedule(items: d.schedule), const SizedBox(height: 18)],
        _ActiveSection(active: d.active),
      ];
      final activePatient = d.active.isEmpty ? null : d.active.first.patientId;
      final side = <Widget>[
        if (d.briefBullets.isNotEmpty) ...[_Brief(d), const SizedBox(height: 16)],
        ChatPanel(
          scope: ChatScope.doctor(patientId: activePatient),
          title: 'AI clinical assistant',
          subtitle: activePatient == null ? 'Your day · advisory only' : 'Ayesha is open · advisory only',
          welcome: activePatient == null
              ? 'Good day, doctor. Ask me about your schedule or who needs attention — once a '
                  "patient approves access I can answer from their record, with sources."
              : "Ayesha's record is open. Ask me anything about it — I'll show the source of every answer.",
          suggestions: activePatient == null
              ? demoDoctorDayQuestions
              : [...demoQuestions.take(3), demoDoctorDayQuestions.first],
          accent: doctorAccent,
          height: 520,
          onSourceTap: activePatient == null
              ? null
              : (id) => openRecordFromChat(context, activePatient, id),
        ),
        const SizedBox(height: 16),
        _WeekChart(week: d.week),
        const SizedBox(height: 16),
        _PendingCard(pending: d.pending),
        const SizedBox(height: 16),
        _ActivityCard(items: d.activity),
        const SizedBox(height: 14),
        const Text(
          'AI output is advisory only — you keep full prescribing authority and responsibility.',
          style: TextStyle(fontSize: 11.5, color: MediCardColors.muted, height: 1.4),
        ),
      ];
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(pad, 18, pad, 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1280),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const DoctorTopBar(),
              const SizedBox(height: 22),
              _Header(d: d),
              const SizedBox(height: 18),
              _Stats(stats: d.stats, wide: wide),
              const SizedBox(height: 18),
              if (wide)
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(flex: 7, child: Column(children: main)),
                  const SizedBox(width: 20),
                  Expanded(flex: 4, child: Column(children: side)),
                ])
              else
                Column(children: [...main, const SizedBox(height: 18), ...side]),
            ]),
          ),
        ),
      );
    });
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.d});
  final DoctorDashboardData d;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final first = d.name.split(' ').first;
    final sub = [d.specialty, d.hospital].whereType<String>().where((e) => e.isNotEmpty).join(' · ');
    return Row(children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${_greeting()}, Dr $first',
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text(sub.isEmpty ? _today() : '$sub  ·  ${_today()}',
              style: const TextStyle(fontSize: 13.5, color: MediCardColors.muted)),
        ]),
      ),
      const StatusPill(label: 'Licence verified', color: MediCardColors.verified, icon: Icons.verified),
    ]);
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.stats, required this.wide});
  final DashStatsData stats;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      _StatTile(Icons.lock_open_outlined, '${stats.activeAccess}', 'Patients you can see now',
          MediCardColors.primary),
      _StatTile(Icons.hourglass_bottom, '${stats.pending}', 'Waiting for patient approval',
          MediCardColors.warning),
      _StatTile(Icons.medication_outlined, '${stats.prescriptions30d}', 'Prescriptions · 30 days',
          const Color(0xFF6D28D9)),
      _StatTile(Icons.groups_outlined, '${stats.patientsSeen30d}', 'Patients seen · 30 days',
          const Color(0xFF1D4ED8)),
    ];
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 900 ? 4 : 2;
      const gap = 12.0;
      final w = (c.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(spacing: gap, runSpacing: gap, children: [
        for (final t in tiles) SizedBox(width: w, child: t),
      ]);
    });
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile(this.icon, this.value, this.label, this.color);
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: MediCardColors.border),
        ),
        child: Row(children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
                color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(13)),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(value,
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, height: 1.1)),
              Text(label,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 12, color: MediCardColors.muted)),
            ]),
          ),
        ]),
      );
}

class _RequestCard extends ConsumerStatefulWidget {
  const _RequestCard({required this.onSent});
  final VoidCallback onSent;

  @override
  ConsumerState<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends ConsumerState<_RequestCard> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _msg;
  bool _ok = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  /// Break-glass: critical information only, a reason is required, the patient is told.
  Future<void> _emergency(BuildContext context) async {
    final res = await showDialog<({String code, String reason})>(
      context: context,
      builder: (_) => _EmergencyDialog(initialCode: _code.text),
    );
    if (res == null) return;
    setState(() {
      _busy = true;
      _msg = null;
    });
    try {
      final c = await ref.read(accessRepositoryProvider).breakGlass(res.code, res.reason);
      widget.onSent();
      if (!mounted) return;
      final grants = await ref.read(accessRepositoryProvider).activeGrants();
      final g = grants.where((x) => !x.isFull).firstOrNull;
      if (g != null && mounted) {
        // ignore: use_build_context_synchronously
        context.go('/doctor/patients/${g.patientId}/critical');
      } else {
        setState(() {
          _ok = true;
          _msg = 'Emergency access opened for ${c.patientName}.';
        });
      }
    } on DioException catch (e) {
      setState(() {
        _ok = false;
        _msg = e.response?.data?['detail']?.toString() ?? 'Emergency access failed.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    final code = _code.text.replaceAll(' ', '').trim().toUpperCase();
    if (code.length < 6) return;
    setState(() {
      _busy = true;
      _msg = null;
    });
    try {
      await ref.read(accessRepositoryProvider).requestAccess(code);
      _code.clear();
      setState(() {
        _ok = true;
        _msg = 'Request sent. The patient approves it on their phone.';
      });
      widget.onSent();
    } on DioException catch (e) {
      setState(() {
        _ok = false;
        _msg = e.response?.data?['detail']?.toString() ?? 'Could not send the request.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

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
          const Row(children: [
            Icon(Icons.person_search, color: Colors.white),
            SizedBox(width: 10),
            Text('Open a patient\'s record',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 4),
          Text('Enter their MediCard code. They approve on their phone — per visit, time-limited, logged.',
              style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13, height: 1.4)),
          const SizedBox(height: 14),
          Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
            SizedBox(
              width: 260,
              child: TextField(
                controller: _code,
                textCapitalization: TextCapitalization.characters,
                onSubmitted: (_) => _send(),
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 3),
                decoration: const InputDecoration(hintText: 'MediCard code'),
              ),
            ),
            FilledButton(
              onPressed: _busy ? null : _send,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: MediCardColors.primaryDark,
                minimumSize: const Size(160, 52),
              ),
              child: Text(_busy ? 'Sending…' : 'Request access'),
            ),
            OutlinedButton.icon(
              onPressed: () => _emergency(context),
              icon: const Icon(Icons.emergency_outlined, size: 18),
              label: const Text('Emergency access'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white70),
                minimumSize: const Size(0, 52),
              ),
            ),
          ]),
          if (_msg != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(_msg!,
                  style: TextStyle(
                      color: _ok ? Colors.white : const Color(0xFFFFD6D6),
                      fontWeight: FontWeight.w600)),
            ),
        ]),
      );
}

class _ActiveSection extends ConsumerWidget {
  const _ActiveSection({required this.active});
  final List<DashActiveData> active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Expanded(
          child: Text('Your patients right now',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
        ),
        Text('${active.length} with access',
            style: const TextStyle(color: MediCardColors.muted, fontWeight: FontWeight.w600)),
      ]),
      const SizedBox(height: 10),
      if (active.isEmpty)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: MediCardColors.border),
          ),
          child: const Column(children: [
            Icon(Icons.lock_outline, size: 36, color: MediCardColors.muted),
            SizedBox(height: 8),
            Text('No patient has approved access yet',
                style: TextStyle(fontWeight: FontWeight.w700)),
            SizedBox(height: 2),
            Text('Enter a MediCard code above to start.',
                style: TextStyle(color: MediCardColors.muted)),
          ]),
        )
      else
        for (final a in active) ...[
          _PatientCard(a: a),
          const SizedBox(height: 12),
        ],
    ]);
  }
}

class _PatientCard extends ConsumerWidget {
  const _PatientCard({required this.a});
  final DashActiveData a;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initials = a.name.split(' ').where((p) => p.isNotEmpty).take(2).map((p) => p[0]).join();
    final emergency = a.source == 'break_glass';
    final facts = [
      if (a.age != null) '${a.age} y',
      if (a.gender != null) a.gender!,
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: emergency ? MediCardColors.danger : MediCardColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: MediCardColors.primary,
            child: Text(initials.toUpperCase(),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(a.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              Text(facts, style: const TextStyle(fontSize: 12.5, color: MediCardColors.muted)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            StatusPill(
              label: emergency ? 'Emergency · critical only' : (a.isFull ? 'Full access' : 'Critical only'),
              color: emergency ? MediCardColors.danger : MediCardColors.verified,
            ),
            const SizedBox(height: 4),
            Text(_left(a.expiresAt),
                style: const TextStyle(fontSize: 12, color: MediCardColors.muted)),
          ]),
        ]),
        if (a.alerts.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final t in a.alerts)
              Container(
                constraints: const BoxConstraints(maxWidth: 420),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _sev(t.severity).withOpacity(0.09),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                    t.severity == 'urgent' ? Icons.error_outline : Icons.trending_up,
                    size: 15,
                    color: _sev(t.severity),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(t.text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w600, color: _sev(t.severity))),
                  ),
                ]),
              ),
          ]),
        ],
        const SizedBox(height: 14),
        Wrap(spacing: 10, runSpacing: 8, children: [
          FilledButton.icon(
            onPressed: () => context.go(a.isFull
                ? '/doctor/patients/${a.patientId}/records'
                : '/doctor/patients/${a.patientId}/critical'),
            icon: const Icon(Icons.folder_open, size: 18),
            label: const Text('Open'),
            style: FilledButton.styleFrom(minimumSize: const Size(110, 44)),
          ),
          if (a.isFull) ...[
            OutlinedButton.icon(
              onPressed: () => context.go('/doctor/patients/${a.patientId}/prescribe'),
              icon: const Icon(Icons.edit_note, size: 18),
              label: const Text('Prescribe'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
            ),
            OutlinedButton.icon(
              onPressed: () => context.go('/doctor/patients/${a.patientId}/ai'),
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: const Text('AI summary'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
            ),
          ],
          TextButton(
            onPressed: () async {
              await ref.read(accessRepositoryProvider).endGrant(a.grantId);
              ref.invalidate(doctorDashboardProvider);
            },
            child: const Text('End access'),
          ),
        ]),
      ]),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, this.trailing, required this.child});
  final String title;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: MediCardColors.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ),
            if (trailing != null) trailing!,
          ]),
          const SizedBox(height: 12),
          child,
        ]),
      );
}

class _WeekChart extends StatelessWidget {
  const _WeekChart({required this.week});
  final List<DashDayData> week;

  @override
  Widget build(BuildContext context) {
    final maxV = week.fold<int>(1, (m, d) => d.views + d.prescriptions > m ? d.views + d.prescriptions : m);
    return _Card(
      title: 'Your week',
      trailing: const Row(mainAxisSize: MainAxisSize.min, children: [
        _Dot(MediCardColors.primary, 'Records opened'),
        SizedBox(width: 10),
        _Dot(Color(0xFF6D28D9), 'Prescriptions'),
      ]),
      child: SizedBox(
        height: 130,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          for (final d in week)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  if (d.prescriptions > 0)
                    Container(
                      height: 80 * d.prescriptions / maxV,
                      decoration: const BoxDecoration(
                        color: Color(0xFF6D28D9),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
                      ),
                    ),
                  Container(
                    height: d.views == 0 ? 3 : 80 * d.views / maxV,
                    decoration: BoxDecoration(
                      color: d.views == 0 ? MediCardColors.border : MediCardColors.primary,
                      borderRadius: d.prescriptions > 0
                          ? BorderRadius.zero
                          : const BorderRadius.vertical(top: Radius.circular(6)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(d.day, style: const TextStyle(fontSize: 11, color: MediCardColors.muted)),
                ]),
              ),
            ),
        ]),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot(this.color, this.label);
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10.5, color: MediCardColors.muted)),
      ]);
}

class _PendingCard extends StatelessWidget {
  const _PendingCard({required this.pending});
  final List<DashPendingData> pending;

  @override
  Widget build(BuildContext context) => _Card(
        title: 'Waiting for approval',
        child: pending.isEmpty
            ? const Text('No requests waiting.', style: TextStyle(color: MediCardColors.muted))
            : Column(children: [
                for (final p in pending)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      const CircleAvatar(
                        radius: 18,
                        backgroundColor: Color(0xFFFEF3C7),
                        child: Icon(Icons.hourglass_bottom, size: 18, color: Color(0xFFB45309)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text('Asked ${_ago(p.createdAt)}',
                              style: const TextStyle(fontSize: 12, color: MediCardColors.muted)),
                        ]),
                      ),
                      const StatusPill(label: 'Pending', color: MediCardColors.unverified),
                    ]),
                  ),
              ]),
      );
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.items});
  final List<DashActivityData> items;

  IconData _icon(String a) => switch (a) {
        'prescribe' => Icons.medication_outlined,
        'grant' => Icons.check_circle_outline,
        'deny' || 'revoke' => Icons.block,
        'break_glass' => Icons.emergency_outlined,
        'request' => Icons.send_outlined,
        'end' => Icons.lock_outline,
        _ => Icons.visibility_outlined,
      };

  @override
  Widget build(BuildContext context) => _Card(
        title: 'Recent activity',
        child: items.isEmpty
            ? const Text('Nothing yet.', style: TextStyle(color: MediCardColors.muted))
            : Column(children: [
                for (var i = 0; i < items.length; i++)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      border: i == 0
                          ? null
                          : const Border(top: BorderSide(color: MediCardColors.border)),
                    ),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Icon(_icon(items[i].action), size: 18, color: MediCardColors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${items[i].text} · ${items[i].name}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          Text(_ago(items[i].at),
                              style: const TextStyle(fontSize: 11.5, color: MediCardColors.muted)),
                        ]),
                      ),
                    ]),
                  ),
              ]),
      );
}


class _Schedule extends StatelessWidget {
  const _Schedule({required this.items});
  final List<ScheduleItem> items;

  @override
  Widget build(BuildContext context) {
    final done = items.where((i) => i.status == 'done').length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MediCardColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(
            child: Text("Today's patients",
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
          ),
          Text('$done of ${items.length} seen',
              style: const TextStyle(color: MediCardColors.muted, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 4),
        const Text('Records open only after the patient approves — per visit.',
            style: TextStyle(fontSize: 12.5, color: MediCardColors.muted)),
        const SizedBox(height: 10),
        for (var i = 0; i < items.length; i++) _row(context, items[i], i == 0),
      ]),
    );
  }

  Widget _row(BuildContext context, ScheduleItem p, bool first) {
    final (label, color) = switch (p.status) {
      'done' => ('Seen', MediCardColors.verified),
      'in_consultation' => ('In consultation', MediCardColors.primary),
      _ => ('Waiting', MediCardColors.unverified),
    };
    final initials = p.name.split(' ').where((e) => e.isNotEmpty).take(2).map((e) => e[0]).join();
    final live = p.status == 'in_consultation' && p.patientId != null;
    return InkWell(
      onTap: live ? () => context.go('/doctor/patients/${p.patientId}/records') : null,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
        decoration: BoxDecoration(
          color: p.active ? MediCardColors.primaryTint.withOpacity(0.55) : null,
          borderRadius: BorderRadius.circular(14),
          border: first ? null : const Border(top: BorderSide(color: MediCardColors.border)),
        ),
        child: Row(children: [
          SizedBox(
            width: 52,
            child: Text(p.time,
                style: const TextStyle(fontWeight: FontWeight.w700, color: MediCardColors.muted)),
          ),
          CircleAvatar(
            radius: 19,
            backgroundColor: p.active ? MediCardColors.primary : const Color(0xFFE2E8F0),
            child: Text(initials.toUpperCase(),
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: p.active ? Colors.white : MediCardColors.muted)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.name, style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(
                p.codeHint != null && !live
                    ? '${p.reason} · code ${p.codeHint}'
                    : p.reason,
                style: const TextStyle(fontSize: 12.5, color: MediCardColors.muted),
              ),
            ]),
          ),
          StatusPill(label: label, color: color),
          if (live) const Icon(Icons.chevron_right, color: MediCardColors.muted),
        ]),
      ),
    );
  }
}


/// A short morning briefing — what the day looks like and who to look at first.
class _Brief extends StatelessWidget {
  const _Brief(this.d);
  final DoctorDashboardData d;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFF5F3FF), Color(0xFFEEF2FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFDDD6FE)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.wb_sunny_outlined, color: doctorAccent, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(d.briefHeadline ?? 'Your day at a glance',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ),
            const StatusPill(label: 'AI brief', color: doctorAccent),
          ]),
          const SizedBox(height: 10),
          for (final b in d.briefBullets)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Padding(
                  padding: EdgeInsets.only(top: 6, right: 10),
                  child: Icon(Icons.circle, size: 6, color: doctorAccent),
                ),
                Expanded(child: Text(b, style: const TextStyle(fontSize: 13.5, height: 1.45))),
              ]),
            ),
        ]),
      );
}


class _EmergencyDialog extends StatefulWidget {
  const _EmergencyDialog({this.initialCode = ''});
  final String initialCode;

  @override
  State<_EmergencyDialog> createState() => _EmergencyDialogState();
}

class _EmergencyDialogState extends State<_EmergencyDialog> {
  late final _code = TextEditingController(text: widget.initialCode);
  final _reason = TextEditingController();
  String? _err;

  static const _quick = [
    'Patient unconscious — cannot consent',
    'Cardiac arrest',
    'Severe bleeding / trauma',
    'Seizure — unresponsive',
  ];

  @override
  void dispose() {
    _code.dispose();
    _reason.dispose();
    super.dispose();
  }

  void _go() {
    final code = _code.text.replaceAll(' ', '').trim().toUpperCase();
    final reason = _reason.text.trim();
    if (code.length < 6) {
      setState(() => _err = "Enter the patient's MediCard code.");
      return;
    }
    if (reason.length < 4) {
      setState(() => _err = 'A reason is required — it is recorded and shown to the patient.');
      return;
    }
    Navigator.of(context).pop((code: code, reason: reason));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.all(18),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.emergency, color: MediCardColors.danger),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Emergency access',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              ),
            ]),
            const SizedBox(height: 12),
            const Text(
              'Use only when the patient cannot consent. You will see critical information only '
              '(allergies, current medicines, conditions). It is logged, and the patient is told '
              'afterwards.',
              style: TextStyle(fontSize: 13.5, height: 1.45, color: MediCardColors.muted),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _code,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 2),
              decoration: const InputDecoration(labelText: 'Patient MediCard code'),
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final q in _quick)
                ActionChip(
                  label: Text(q, style: const TextStyle(fontSize: 12.5)),
                  onPressed: () => setState(() => _reason.text = q),
                ),
            ]),
            const SizedBox(height: 10),
            TextField(
              controller: _reason,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Reason (required)'),
            ),
            if (_err != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(_err!, style: const TextStyle(color: MediCardColors.danger, fontSize: 13)),
              ),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: _go,
                  style: FilledButton.styleFrom(
                    backgroundColor: MediCardColors.danger,
                    minimumSize: const Size.fromHeight(50),
                  ),
                  child: const Text('Open emergency access'),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}
