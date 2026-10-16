import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme.dart';
import '../access/access_repository.dart';
import '../access/models.dart';
import 'doctor_top_bar.dart';

final _criticalProvider =
    FutureProvider.autoDispose.family<CriticalView, String>((ref, pid) {
  return ref.watch(accessRepositoryProvider).patientCritical(pid);
});

/// The emergency view: only what a doctor needs to act safely — allergies first.
class CriticalSummaryScreen extends ConsumerWidget {
  const CriticalSummaryScreen({super.key, required this.patientId});

  final String patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crit = ref.watch(_criticalProvider(patientId));
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: ListView(
              padding: EdgeInsets.symmetric(
                  horizontal: MediaQuery.of(context).size.width >= 700 ? 28 : 14, vertical: 16),
              children: [
                const DoctorTopBar(),
                const SizedBox(height: 16),
                crit.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(60),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Could not load the emergency summary.\n$e'),
                  ),
                  data: (c) => _view(context, c),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _view(BuildContext context, CriticalView c) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF991B1B), Color(0xFFDC2626)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(15)),
            child: const Icon(Icons.emergency, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('EMERGENCY VIEW — CRITICAL INFORMATION ONLY',
                  style: TextStyle(
                      color: Colors.white70, fontSize: 11, letterSpacing: 1.1, fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(c.patientName,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 25, fontWeight: FontWeight.w800)),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 14),
      _Card(
        icon: Icons.warning_amber_rounded,
        color: MediCardColors.danger,
        title: 'Allergies',
        child: c.allergies.isEmpty
            ? const Text('None recorded', style: TextStyle(color: MediCardColors.muted))
            : Wrap(spacing: 8, runSpacing: 8, children: [
                for (final a in c.allergies)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(999)),
                    child: Text(a,
                        style: const TextStyle(
                            color: Color(0xFFB91C1C), fontWeight: FontWeight.w800, fontSize: 15)),
                  ),
              ]),
      ),
      const SizedBox(height: 12),
      _Card(
        icon: Icons.medication_outlined,
        color: const Color(0xFF6D28D9),
        title: 'Current medicines',
        child: c.currentMedications.isEmpty
            ? const Text('None recorded', style: TextStyle(color: MediCardColors.muted))
            : Column(children: [
                for (final m in c.currentMedications)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      Expanded(
                        child: Text('${m['name']}',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      ),
                      Text(
                        [m['dose'], m['freq']]
                            .where((e) => e != null && '$e'.isNotEmpty)
                            .join(' · '),
                        style: const TextStyle(color: MediCardColors.muted, fontSize: 13),
                      ),
                    ]),
                  ),
              ]),
      ),
      const SizedBox(height: 12),
      _Card(
        icon: Icons.monitor_heart_outlined,
        color: const Color(0xFF3730A3),
        title: 'Conditions',
        child: c.conditions.isEmpty
            ? const Text('None recorded', style: TextStyle(color: MediCardColors.muted))
            : Wrap(spacing: 8, runSpacing: 8, children: [
                for (final d in c.conditions)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(999)),
                    child: Text(d,
                        style: const TextStyle(
                            color: Color(0xFF3730A3), fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
              ]),
      ),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.history, color: Color(0xFFB45309), size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'This emergency access is logged with your reason and the patient is told about it '
              'afterwards. The full record stays closed until the patient consents.',
              style: TextStyle(fontSize: 13, height: 1.45, color: Color(0xFF78350F)),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 16),
      OutlinedButton.icon(
        onPressed: () => context.go('/doctor'),
        icon: const Icon(Icons.arrow_back),
        label: const Text('Back to dashboard'),
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
      ),
    ]);
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.icon, required this.color, required this.title, required this.child});
  final IconData icon;
  final Color color;
  final String title;
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
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 12),
          child,
        ]),
      );
}
