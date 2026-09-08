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

  Future<PatientProfile> me() async {
    final r = await _dio.get('/patient/me');
    return PatientProfile.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  Future<PatientProfile> updateMe(Map<String, dynamic> patch) async {
    final r = await _dio.patch('/patient/me', data: patch);
    return PatientProfile.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  Future<Overview> overview() async {
    final r = await _dio.get('/patient/overview');
    return Overview.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  Future<List<DerivedMed>> medications() async {
    final r = await _dio.get('/patient/medications');
    return (r.data as List)
        .map((e) => DerivedMed.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<AllergyItem>> allergies() async {
    final r = await _dio.get('/patient/allergies');
    return (r.data as List)
        .map((e) => AllergyItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<AiSummary> aiSummary() async {
    final r = await _dio.get('/patient/ai-summary');
    return AiSummary.fromJson(Map<String, dynamic>.from(r.data as Map));
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
