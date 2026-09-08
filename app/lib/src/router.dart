import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/auth/auth_controller.dart';
import 'features/doctor/ai_panel_screen.dart';
import 'features/doctor/critical_summary_screen.dart';
import 'features/doctor/doctor_auth_screen.dart';
import 'features/doctor/doctor_home_screen.dart';
import 'features/doctor/doctor_record_detail_screen.dart';
import 'features/doctor/patient_records_screen.dart';
import 'features/doctor/prescribe_screen.dart';
import 'features/doctor/request_access_screen.dart';
import 'features/landing/landing_screen.dart';
import 'features/patient/access_history_screen.dart';
import 'features/patient/access_requests_screen.dart';
import 'features/patient/allergies_screen.dart';
import 'features/patient/help_screen.dart';
import 'features/patient/medications_screen.dart';
import 'features/patient/notifications_screen.dart';
import 'features/patient/patient_auth_screen.dart';
import 'features/patient/patient_home_screen.dart';
import 'features/patient/patient_profile_screen.dart';
import 'features/patient/patient_sharing_screen.dart';
import 'features/patient/personal_info_screen.dart';
import 'features/patient/settings_screen.dart';
import 'features/patient/patient_shell.dart';
import 'features/records/extraction_review_screen.dart';
import 'features/records/record_detail_screen.dart';
import 'features/records/timeline_screen.dart';
import 'features/records/upload_screen.dart';

final _rootKey = GlobalKey<NavigatorState>();
final _shellKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authControllerProvider, (_, __) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      if (auth.status == AuthStatus.unknown) return null;

      final loc = state.matchedLocation;
      final inAuthArea = loc == '/' || loc.endsWith('/auth');

      if (!auth.isSignedIn) return inAuthArea ? null : '/';

      final isDoctor = auth.status == AuthStatus.doctor;
      if (inAuthArea) return isDoctor ? '/doctor' : '/patient';
      if (isDoctor && !loc.startsWith('/doctor')) return '/doctor';
      if (!isDoctor && !loc.startsWith('/patient')) return '/patient';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, __) => const LandingScreen()),
      GoRoute(path: '/patient/auth', builder: (_, __) => const PatientAuthScreen()),
      GoRoute(path: '/doctor/auth', builder: (_, __) => const DoctorAuthScreen()),

      // ---- patient: full-screen routes above the tab shell ----
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/patient/records/:id/review',
        builder: (_, s) => ExtractionReviewScreen(recordId: s.pathParameters['id']!),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/patient/records/:id',
        builder: (_, s) => RecordDetailScreen(recordId: s.pathParameters['id']!),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/patient/notifications',
        builder: (_, __) => const NotificationsScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/patient/health/medications',
        builder: (_, __) => const MedicationsScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/patient/health/allergies',
        builder: (_, __) => const AllergiesScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/patient/profile/personal',
        builder: (_, __) => const PersonalInfoScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/patient/profile/settings',
        builder: (_, __) => const SettingsScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/patient/profile/help',
        builder: (_, __) => const HelpScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/patient/sharing/requests',
        builder: (_, __) => const AccessRequestsScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/patient/sharing/activity',
        builder: (_, __) => const AccessHistoryScreen(),
      ),

      // ---- patient: bottom-tab shell ----
      StatefulShellRoute.indexedStack(
        parentNavigatorKey: _rootKey,
        builder: (_, __, shell) => PatientShell(shell: shell),
        branches: [
          StatefulShellBranch(navigatorKey: _shellKey, routes: [
            GoRoute(path: '/patient', builder: (_, __) => const PatientHomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/patient/records', builder: (_, __) => const TimelineScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/patient/scan', builder: (_, __) => const UploadScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/patient/sharing', builder: (_, __) => const PatientSharingScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/patient/profile', builder: (_, __) => const PatientProfileScreen()),
          ]),
        ],
      ),

      // ---- doctor ----
      GoRoute(path: '/doctor', builder: (_, __) => const DoctorHomeScreen()),
      GoRoute(path: '/doctor/request', builder: (_, __) => const RequestAccessScreen()),
      GoRoute(
        path: '/doctor/patients/:id/records',
        builder: (_, s) => DoctorPatientRecordsScreen(patientId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/doctor/patients/:id/records/:rid',
        builder: (_, s) => DoctorRecordDetailScreen(
          patientId: s.pathParameters['id']!,
          recordId: s.pathParameters['rid']!,
        ),
      ),
      GoRoute(
        path: '/doctor/patients/:id/critical',
        builder: (_, s) => CriticalSummaryScreen(patientId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/doctor/patients/:id/ai',
        builder: (_, s) => AiPanelScreen(patientId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/doctor/patients/:id/prescribe',
        builder: (_, s) => PrescribeScreen(patientId: s.pathParameters['id']!),
      ),
    ],
  );
});
