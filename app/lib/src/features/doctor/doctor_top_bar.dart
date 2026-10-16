import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_controller.dart';
import '../../demo/demo_data.dart' show demoDoctorDayQuestions, demoQuestions;
import '../../theme.dart';
import '../chat/chat_controller.dart';
import '../chat/chat_panel.dart';
import '../access/access_repository.dart';

/// Shared top bar for the doctor screens: patient-code search, a privacy note,
/// notifications and the doctor's profile menu.
class DoctorTopBar extends ConsumerStatefulWidget {
  const DoctorTopBar({super.key, this.showBack = false, this.patientId});

  final bool showBack;

  /// When set, the AI assistant answers about this patient.
  final String? patientId;

  @override
  ConsumerState<DoctorTopBar> createState() => _DoctorTopBarState();
}

class _DoctorTopBarState extends ConsumerState<DoctorTopBar> {
  final _code = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _search() async {
    final code = _code.text.replaceAll(' ', '').trim().toUpperCase();
    if (code.length < 6) {
      _toast('Enter the patient\'s MediCard code.');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(accessRepositoryProvider).requestAccess(code);
      _code.clear();
      _toast('Request sent. The patient approves it on their phone.');
      ref.invalidate(doctorDashboardProvider);
    } on DioException catch (e) {
      _toast(e.response?.data?['detail']?.toString() ??
          'Could not send the request.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(authControllerProvider).profile;
    final name = profile['name'] as String? ?? 'Doctor';
    final specialty = profile['specialty'] as String? ?? 'Physician';
    final pending = ref.watch(doctorDashboardProvider).maybeWhen(
          data: (d) => d.stats.pending,
          orElse: () => 0,
        );
    final initials = name
        .split(' ')
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0])
        .join();

    return LayoutBuilder(builder: (context, c) {
      final wide =
          c.maxWidth >= 860; // show the doctor's name next to the avatar
      final badge = c.maxWidth >= 1250; // room for the privacy note
      final tiny = c.maxWidth < 560; // phone: icon-only buttons
      final search = Container(
        padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: MediCardColors.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.search, color: MediCardColors.muted, size: 20),
          const SizedBox(width: 8),
          Flexible(
            child: ConstrainedBox(
              constraints:
                  BoxConstraints(maxWidth: c.maxWidth >= 1000 ? 210 : 150),
              child: TextField(
                controller: _code,
                textCapitalization: TextCapitalization.characters,
                onSubmitted: (_) => _search(),
                style: const TextStyle(
                    fontWeight: FontWeight.w700, letterSpacing: 1.5),
                decoration: const InputDecoration(
                  hintText: 'Enter patient ID',
                  isDense: true,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                ),
              ),
            ),
          ),
          if (tiny)
            IconButton.filled(
              onPressed: _busy ? null : _search,
              tooltip: 'Search',
              style: IconButton.styleFrom(minimumSize: const Size(38, 38)),
              icon: const Icon(Icons.arrow_forward, size: 20),
            )
          else
            FilledButton(
              onPressed: _busy ? null : _search,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 18),
              ),
              child: Text(_busy ? '…' : 'Search'),
            ),
        ]),
      );

      final bell = Stack(clipBehavior: Clip.none, children: [
        Container(
          width: tiny ? 40 : 46,
          height: tiny ? 40 : 46,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: MediCardColors.border),
          ),
          child: IconButton(
            tooltip: 'Requests waiting for patients',
            onPressed: () => context.go('/doctor'),
            icon: const Icon(Icons.notifications_none),
          ),
        ),
        if (pending > 0)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                  color: MediCardColors.danger, shape: BoxShape.circle),
              child: Text('$pending',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800)),
            ),
          ),
      ]);

      final profileChip = PopupMenuButton<String>(
        tooltip: 'Account',
        onSelected: (v) {
          if (v == 'out') ref.read(authControllerProvider.notifier).logout();
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'out', child: Text('Sign out')),
        ],
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          CircleAvatar(
            radius: tiny ? 19 : 23,
            backgroundColor: MediCardColors.primary,
            child: Text(initials.toUpperCase(),
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w800)),
          ),
          if (wide) ...[
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Dr $name',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(specialty,
                  style: const TextStyle(
                      fontSize: 12.5, color: MediCardColors.muted)),
            ]),
            const Icon(Icons.keyboard_arrow_down, color: MediCardColors.muted),
          ],
        ]),
      );

      return Row(children: [
        if (widget.showBack) ...[
          IconButton(
            onPressed: () => context.go('/doctor'),
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Dashboard',
          ),
          const SizedBox(width: 4),
        ],
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: search),
          ),
        ),
        const SizedBox(width: 12),
        if (badge)
          const Row(children: [
            Icon(Icons.verified_user_outlined,
                color: MediCardColors.verified, size: 22),
            SizedBox(width: 8),
            Text('All data is encrypted & secure',
                style: TextStyle(
                    color: MediCardColors.verified,
                    fontWeight: FontWeight.w600)),
            SizedBox(width: 24),
          ]),
        _AiButton(patientId: widget.patientId, compact: !wide),
        const SizedBox(width: 12),
        bell,
        const SizedBox(width: 14),
        profileChip,
      ]);
    });
  }
}


class _AiButton extends StatelessWidget {
  const _AiButton({required this.patientId, required this.compact});
  final String? patientId;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    void open() => showChat(
          context,
          scope: ChatScope.doctor(patientId: patientId),
          title: 'AI clinical assistant',
          subtitle: patientId == null ? 'Your day · advisory only' : 'About this patient · advisory only',
          welcome: patientId == null
              ? 'Good day, doctor. Ask me about your schedule, who needs attention, or open a '
                  "patient and I'll answer from their record — with sources."
              : 'I can answer from this patient\'s shared records and show you the source of every '
                  'answer. The clinical decision is always yours.',
          suggestions: patientId == null ? demoDoctorDayQuestions : demoQuestions,
          accent: doctorAccent,
          onSourceTap: patientId == null
              ? null
              : (id) => openRecordFromChat(context, patientId!, id),
        );
    return compact
        ? IconButton.filled(
            onPressed: open,
            tooltip: 'AI assistant',
            style: IconButton.styleFrom(backgroundColor: doctorAccent),
            icon: const Icon(Icons.auto_awesome, color: Colors.white),
          )
        : FilledButton.icon(
            onPressed: open,
            icon: const Icon(Icons.auto_awesome, size: 18),
            label: const Text('AI assistant'),
            style: FilledButton.styleFrom(
              backgroundColor: doctorAccent,
              minimumSize: const Size(0, 46),
            ),
          );
  }
}
