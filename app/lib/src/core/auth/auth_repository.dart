import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api_client.dart';

class AuthRepository {
  AuthRepository(this._dio, this._tokens);

  final Dio _dio;
  final TokenStore _tokens;

  Future<String?> requestPatientOtp(String phone) async {
    final r = await _dio.post('/auth/patient/otp/request', data: {'phone': phone});
    return r.data['dev_code'] as String?;
  }

  /// Returns the parsed body: {patient_id, medicard_code, is_new}.
  Future<Map<String, dynamic>> verifyPatientOtp({
    required String phone,
    required String code,
    String? name,
  }) async {
    final r = await _dio.post('/auth/patient/otp/verify', data: {
      'phone': phone,
      'code': code,
      if (name != null && name.isNotEmpty) 'name': name,
    });
    final tokens = r.data['tokens'] as Map<String, dynamic>;
    await _tokens.save(
      access: tokens['access_token'] as String,
      refresh: tokens['refresh_token'] as String,
    );
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> registerDoctor({
    required String name,
    required String email,
    required String password,
    required String licenceNo,
    String? specialty,
    String? hospital,
  }) async {
    final r = await _dio.post('/auth/doctor/register', data: {
      'name': name,
      'email': email,
      'password': password,
      'licence_no': licenceNo,
      if (specialty != null && specialty.isNotEmpty) 'specialty': specialty,
      if (hospital != null && hospital.isNotEmpty) 'hospital': hospital,
    });
    await _saveTokens(r.data['tokens'] as Map<String, dynamic>);
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> loginDoctor({
    required String email,
    required String password,
  }) async {
    final r = await _dio.post('/auth/doctor/login', data: {
      'email': email,
      'password': password,
    });
    await _saveTokens(r.data['tokens'] as Map<String, dynamic>);
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>?> me() async {
    if (await _tokens.accessToken == null) return null;
    try {
      final r = await _dio.get('/auth/me');
      return Map<String, dynamic>.from(r.data as Map);
    } on DioException {
      return null;
    }
  }

  Future<void> logout() => _tokens.clear();

  Future<void> _saveTokens(Map<String, dynamic> tokens) => _tokens.save(
        access: tokens['access_token'] as String,
        refresh: tokens['refresh_token'] as String,
      );
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(dioProvider), ref.watch(tokenStoreProvider)),
);
