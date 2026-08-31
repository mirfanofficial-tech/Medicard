import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_repository.dart';

enum AuthStatus { unknown, signedOut, patient, doctor }

class AuthState {
  const AuthState({required this.status, this.profile = const {}});

  final AuthStatus status;
  final Map<String, dynamic> profile;

  bool get isSignedIn => status == AuthStatus.patient || status == AuthStatus.doctor;

  AuthState copyWith({AuthStatus? status, Map<String, dynamic>? profile}) =>
      AuthState(status: status ?? this.status, profile: profile ?? this.profile);

  static const unknown = AuthState(status: AuthStatus.unknown);
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repo) : super(AuthState.unknown) {
    refresh();
  }

  final AuthRepository _repo;

  Future<void> refresh() async {
    final me = await _repo.me();
    if (me == null) {
      state = const AuthState(status: AuthStatus.signedOut);
      return;
    }
    final role = me['role'] as String?;
    state = AuthState(
      status: role == 'doctor' ? AuthStatus.doctor : AuthStatus.patient,
      profile: Map<String, dynamic>.from(me['profile'] as Map? ?? {}),
    );
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AuthState(status: AuthStatus.signedOut);
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref.watch(authRepositoryProvider));
});
