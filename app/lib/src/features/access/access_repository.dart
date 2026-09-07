import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../records/models.dart';
import 'models.dart';

class AccessRepository {
  AccessRepository(this._dio);

  final Dio _dio;

  // ---- doctor ----

  Future<void> requestAccess(String code) =>
      _dio.post('/doctor/access-requests', data: {'medicard_code': code});

  Future<List<DoctorGrant>> activeGrants() async {
    final r = await _dio.get('/doctor/grants');
    return (r.data as List)
        .map((e) => DoctorGrant.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<CriticalView> breakGlass(String code, String reason) async {
    final r = await _dio.post('/doctor/break-glass',
        data: {'medicard_code': code, 'reason': reason});
    return CriticalView.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  Future<List<RecordSummary>> patientRecords(String patientId) async {
    final r = await _dio.get('/doctor/patients/$patientId/records');
    return (r.data as List)
        .map((e) => RecordSummary.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<RecordDetail> patientRecordDetail(String patientId, String recordId) async {
    final r = await _dio.get('/doctor/patients/$patientId/records/$recordId');
    return RecordDetail.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  Future<CriticalView> patientCritical(String patientId) async {
    final r = await _dio.get('/doctor/patients/$patientId/critical');
    return CriticalView.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  Future<void> endGrant(String grantId) => _dio.post('/doctor/grants/$grantId/end');

  Future<AiSummary> aiSummary(String patientId) async {
    final r = await _dio.get('/doctor/patients/$patientId/ai-summary');
    return AiSummary.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  Future<AiAnswer> aiAsk(String patientId, String question) async {
    final r = await _dio.post('/doctor/patients/$patientId/ai-ask',
        data: {'question': question});
    return AiAnswer.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  Future<RxContext> prescribeContext(String patientId) async {
    final r = await _dio.get('/doctor/patients/$patientId/prescribe/context');
    return RxContext.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  Future<List<RxCheck>> prescribeCheck(
    String patientId,
    List<Map<String, dynamic>> medications,
  ) async {
    final r = await _dio.post('/doctor/patients/$patientId/prescribe/check',
        data: {'medications': medications});
    return (r.data['checks'] as List)
        .map((e) => RxCheck.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<RxCheck>> prescribeCreate(
    String patientId, {
    String? docDate,
    required List<Map<String, dynamic>> medications,
    String? notes,
  }) async {
    final r = await _dio.post('/doctor/patients/$patientId/prescribe', data: {
      'doc_date': docDate,
      'medications': medications,
      'notes': notes,
    });
    return (r.data['checks'] as List? ?? [])
        .map((e) => RxCheck.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  // ---- patient ----

  Future<List<PendingRequest>> pendingRequests() async {
    final r = await _dio.get('/patient/access-requests');
    return (r.data as List)
        .map((e) => PendingRequest.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> approve(String requestId) =>
      _dio.post('/patient/access-requests/$requestId/approve');

  Future<void> deny(String requestId) =>
      _dio.post('/patient/access-requests/$requestId/deny');

  Future<List<Map<String, dynamic>>> myGrants() async {
    final r = await _dio.get('/patient/grants');
    return (r.data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> revokeGrant(String grantId) =>
      _dio.post('/patient/grants/$grantId/revoke');

  Future<List<AuditEntry>> accessHistory() async {
    final r = await _dio.get('/patient/access-history');
    return (r.data as List)
        .map((e) => AuditEntry.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}

final accessRepositoryProvider =
    Provider<AccessRepository>((ref) => AccessRepository(ref.watch(dioProvider)));

final doctorGrantsProvider = FutureProvider.autoDispose<List<DoctorGrant>>(
  (ref) => ref.watch(accessRepositoryProvider).activeGrants(),
);

final pendingRequestsProvider = FutureProvider.autoDispose<List<PendingRequest>>(
  (ref) => ref.watch(accessRepositoryProvider).pendingRequests(),
);

final accessHistoryProvider = FutureProvider.autoDispose<List<AuditEntry>>(
  (ref) => ref.watch(accessRepositoryProvider).accessHistory(),
);

final patientGrantsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>(
  (ref) => ref.watch(accessRepositoryProvider).myGrants(),
);

final aiSummaryProvider =
    FutureProvider.autoDispose.family<AiSummary, String>((ref, patientId) {
  return ref.watch(accessRepositoryProvider).aiSummary(patientId);
});
