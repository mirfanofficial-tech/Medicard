import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../access/models.dart' show AiSummary;

class PatientProfile {
  PatientProfile({
    required this.patientId,
    required this.name,
    required this.medicardCode,
    this.phone,
    this.dob,
    this.gender,
    this.bloodGroup,
    this.address,
  });

  final String patientId;
  final String name;
  final String medicardCode;
  final String? phone;
  final String? dob;
  final String? gender;
  final String? bloodGroup;
  final String? address;

  factory PatientProfile.fromJson(Map<String, dynamic> j) => PatientProfile(
        patientId: j['patient_id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        medicardCode: j['medicard_code'] as String? ?? '',
        phone: j['phone'] as String?,
        dob: j['dob'] as String?,
        gender: j['gender'] as String?,
        bloodGroup: j['blood_group'] as String?,
        address: j['address'] as String?,
      );
}

class RecentRecord {
  RecentRecord({
    required this.recordId,
    required this.type,
    required this.verified,
    this.provider,
    this.docDate,
  });

  final String recordId;
  final String type;
  final bool verified;
  final String? provider;
  final String? docDate;

  factory RecentRecord.fromJson(Map<String, dynamic> j) => RecentRecord(
        recordId: j['record_id'] as String,
        type: j['type'] as String? ?? 'note',
        verified: j['verified'] as bool? ?? false,
        provider: j['provider'] as String?,
        docDate: j['doc_date'] as String?,
      );
}

class Overview {
  Overview({
    required this.name,
    required this.records,
    required this.labReports,
    required this.prescriptions,
    required this.imaging,
    required this.medications,
    required this.allergies,
    required this.recent,
  });

  final String name;
  final int records;
  final int labReports;
  final int prescriptions;
  final int imaging;
  final int medications;
  final int allergies;
  final List<RecentRecord> recent;

  factory Overview.fromJson(Map<String, dynamic> j) => Overview(
        name: j['name'] as String? ?? '',
        records: j['records'] as int? ?? 0,
        labReports: j['lab_reports'] as int? ?? 0,
        prescriptions: j['prescriptions'] as int? ?? 0,
        imaging: j['imaging'] as int? ?? 0,
        medications: j['medications'] as int? ?? 0,
        allergies: j['allergies'] as int? ?? 0,
        recent: (j['recent'] as List? ?? [])
            .map((e) => RecentRecord.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

class DerivedMed {
  DerivedMed({required this.name, this.dose, this.route, this.freq, this.sourceDate});
  final String name;
  final String? dose;
  final String? route;
  final String? freq;
  final String? sourceDate;

  factory DerivedMed.fromJson(Map<String, dynamic> j) => DerivedMed(
        name: j['name'] as String? ?? '',
        dose: j['dose'] as String?,
        route: j['route'] as String?,
        freq: j['freq'] as String?,
        sourceDate: j['source_date'] as String?,
      );
}

class AllergyItem {
  AllergyItem({required this.name, required this.sourceRecordIds});
  final String name;
  final List<String> sourceRecordIds;

  factory AllergyItem.fromJson(Map<String, dynamic> j) => AllergyItem(
        name: j['name'] as String? ?? '',
        sourceRecordIds:
            (j['source_record_ids'] as List? ?? []).map((e) => e.toString()).toList(),
      );
}

class PatientRepository {
  PatientRepository(this._dio);
  final Dio _dio;

  // The deployed server may predate the patient-redesign endpoints; on a
  // 404/405 we derive the same views client-side from /auth/me and /records.
  static bool _missing(Object e) =>
      e is DioException && (e.response?.statusCode == 404 || e.response?.statusCode == 405);

  Future<PatientProfile> me() async {
    try {
      final r = await _dio.get('/patient/me');
      return PatientProfile.fromJson(Map<String, dynamic>.from(r.data as Map));
    } catch (e) {
      if (!_missing(e)) rethrow;
      final r = await _dio.get('/auth/me');
      final profile = Map<String, dynamic>.from((r.data as Map)['profile'] as Map? ?? {});
      return PatientProfile.fromJson(profile);
    }
  }

  Future<PatientProfile> updateMe(Map<String, dynamic> patch) async {
    try {
      final r = await _dio.patch('/patient/me', data: patch);
      return PatientProfile.fromJson(Map<String, dynamic>.from(r.data as Map));
    } catch (e) {
      if (_missing(e)) {
        throw Exception('Profile editing is not available on this server yet.');
      }
      rethrow;
    }
  }

  /// Verified records, newest first, with full detail (fallback path only).
  Future<List<Map<String, dynamic>>> _verifiedDetails() async {
    final list = await _dio.get('/records');
    final rows = (list.data as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .where((e) => e['verified'] == true)
        .toList();
    final out = <Map<String, dynamic>>[];
    for (final row in rows) {
      final d = await _dio.get('/records/${row['record_id']}');
      out.add(Map<String, dynamic>.from(d.data as Map));
    }
    return out;
  }

  List<DerivedMed> _meds(List<Map<String, dynamic>> records) {
    final seen = <String>{};
    final out = <DerivedMed>[];
    for (final r in records.where((r) => r['type'] == 'prescription')) {
      final data = Map<String, dynamic>.from(r['data'] as Map? ?? {});
      for (final m in (data['medications'] as List? ?? [])) {
        final mm = Map<String, dynamic>.from(m as Map);
        final name = (mm['name'] as String? ?? '').trim();
        if (name.isEmpty || !seen.add(name.toLowerCase())) continue;
        out.add(DerivedMed(
          name: name,
          dose: mm['dose'] as String?,
          route: mm['route'] as String?,
          freq: mm['freq'] as String?,
          sourceDate: r['doc_date'] as String?,
        ));
      }
    }
    return out;
  }

  List<AllergyItem> _allergies(List<Map<String, dynamic>> records) {
    final byName = <String, List<String>>{};
    for (final r in records) {
      final data = Map<String, dynamic>.from(r['data'] as Map? ?? {});
      for (final a in (data['allergies'] as List? ?? [])) {
        byName.putIfAbsent(a.toString(), () => []).add(r['record_id'].toString());
      }
    }
    final names = byName.keys.toList()..sort();
    return [for (final n in names) AllergyItem(name: n, sourceRecordIds: byName[n]!)];
  }

  Future<Overview> overview() async {
    try {
      final r = await _dio.get('/patient/overview');
      return Overview.fromJson(Map<String, dynamic>.from(r.data as Map));
    } catch (e) {
      if (!_missing(e)) rethrow;
      final name = (await me()).name;
      final rows = ((await _dio.get('/records')).data as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      int count(String t) => rows.where((r) => r['type'] == t).length;
      final details = await _verifiedDetails();
      return Overview(
        name: name,
        records: rows.length,
        labReports: count('lab'),
        prescriptions: count('prescription'),
        imaging: count('imaging'),
        medications: _meds(details).length,
        allergies: _allergies(details).length,
        recent: rows.take(5).map(RecentRecord.fromJson).toList(),
      );
    }
  }

  Future<List<DerivedMed>> medications() async {
    try {
      final r = await _dio.get('/patient/medications');
      return (r.data as List)
          .map((e) => DerivedMed.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      if (!_missing(e)) rethrow;
      return _meds(await _verifiedDetails());
    }
  }

  Future<List<AllergyItem>> allergies() async {
    try {
      final r = await _dio.get('/patient/allergies');
      return (r.data as List)
          .map((e) => AllergyItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      if (!_missing(e)) rethrow;
      return _allergies(await _verifiedDetails());
    }
  }

  Future<AiSummary> aiSummary() async {
    try {
      final r = await _dio.get('/patient/ai-summary');
      return AiSummary.fromJson(Map<String, dynamic>.from(r.data as Map));
    } catch (e) {
      if (_missing(e)) {
        throw Exception('AI summary is not available on this server yet.');
      }
      rethrow;
    }
  }
}

final patientRepositoryProvider =
    Provider<PatientRepository>((ref) => PatientRepository(ref.watch(dioProvider)));

final patientMeProvider =
    FutureProvider.autoDispose<PatientProfile>((ref) => ref.watch(patientRepositoryProvider).me());

final patientOverviewProvider =
    FutureProvider.autoDispose<Overview>((ref) => ref.watch(patientRepositoryProvider).overview());

final patientMedicationsProvider = FutureProvider.autoDispose<List<DerivedMed>>(
    (ref) => ref.watch(patientRepositoryProvider).medications());

final patientAllergiesProvider = FutureProvider.autoDispose<List<AllergyItem>>(
    (ref) => ref.watch(patientRepositoryProvider).allergies());

final patientAiSummaryProvider = FutureProvider.autoDispose<AiSummary>(
    (ref) => ref.watch(patientRepositoryProvider).aiSummary());
