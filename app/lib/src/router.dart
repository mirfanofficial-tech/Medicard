import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/auth/auth_controller.dart';
import 'features/doctor/doctor_auth_screen.dart';
import 'features/doctor/doctor_home_screen.dart';
import 'features/landing/landing_screen.dart';
import 'features/patient/patient_auth_screen.dart';
import 'features/patient/patient_home_screen.dart';
import 'features/records/extraction_review_screen.dart';
import 'features/records/record_detail_screen.dart';
import 'features/records/timeline_screen.dart';
import 'features/records/upload_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authControllerProvider, (_, __) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      if (auth.status == AuthStatus.unknown) return null;

      final loc = state.matchedLocation;
      final inAuthArea = loc == '/' || loc.endsWith('/auth');

      if (!auth.isSignedIn) return inAuthArea ? null : '/';

      final home = auth.status == AuthStatus.doctor ? '/doctor' : '/patient';
      if (inAuthArea || !loc.startsWith(home)) return home;
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, __) => const LandingScreen()),
      GoRoute(path: '/patient/auth', builder: (_, __) => const PatientAuthScreen()),
      GoRoute(path: '/patient', builder: (_, __) => const PatientHomeScreen()),
      GoRoute(path: '/patient/records', builder: (_, __) => const TimelineScreen()),
      GoRoute(path: '/patient/records/upload', builder: (_, __) => const UploadScreen()),
      GoRoute(
        path: '/patient/records/:id/review',
        builder: (_, s) => ExtractionReviewScreen(recordId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/patient/records/:id',
        builder: (_, s) => RecordDetailScreen(recordId: s.pathParameters['id']!),
      ),
      GoRoute(path: '/doctor/auth', builder: (_, __) => const DoctorAuthScreen()),
      GoRoute(path: '/doctor', builder: (_, __) => const DoctorHomeScreen()),
    ],
  );
});
