import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../demo/demo_backend.dart';
import 'env.dart';

/// Secure token store. Access + refresh tokens live here, never in memory-only
/// state and never in plain shared preferences.
class TokenStore {
  const TokenStore(this._storage);

  final FlutterSecureStorage _storage;

  Future<String?> get accessToken => _storage.read(key: 'access_token');
  Future<String?> get refreshToken => _storage.read(key: 'refresh_token');

  Future<void> save({required String access, required String refresh}) async {
    await _storage.write(key: 'access_token', value: access);
    await _storage.write(key: 'refresh_token', value: refresh);
  }

  Future<void> clear() async {
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
  }
}

/// Demo mode: tokens live in memory, so a doctor tab and a patient tab on the same
/// browser each keep their own sign-in (secure storage is shared between tabs).
class _MemoryTokenStore extends TokenStore {
  _MemoryTokenStore() : super(const FlutterSecureStorage());

  String? _access;
  String? _refresh;

  @override
  Future<String?> get accessToken async => _access;
  @override
  Future<String?> get refreshToken async => _refresh;

  @override
  Future<void> save({required String access, required String refresh}) async {
    _access = access;
    _refresh = refresh;
  }

  @override
  Future<void> clear() async {
    _access = null;
    _refresh = null;
  }
}

final tokenStoreProvider = Provider<TokenStore>(
  (ref) => Env.demo ? _MemoryTokenStore() : const TokenStore(FlutterSecureStorage()),
);

final dioProvider = Provider<Dio>((ref) {
  final tokens = ref.watch(tokenStoreProvider);
  final dio = Dio(
    BaseOptions(
      baseUrl: Env.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );
  // DEMO=true: answer every call from static data — no network at all.
  if (Env.demo) dio.httpClientAdapter = DemoAdapter();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await tokens.accessToken;
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
    ),
  );
  return dio;
});
