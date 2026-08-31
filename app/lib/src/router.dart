import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/doctor/doctor_home_screen.dart';
import 'features/landing/landing_screen.dart';
import 'features/patient/patient_home_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, __) => const LandingScreen()),
      GoRoute(path: '/patient', builder: (_, __) => const PatientHomeScreen()),
      GoRoute(path: '/doctor', builder: (_, __) => const DoctorHomeScreen()),
    ],
  );
});
