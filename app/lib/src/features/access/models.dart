class DoctorGrant {
  DoctorGrant({
    required this.grantId,
    required this.patientId,
    required this.patientName,
    required this.scope,
    required this.source,
    required this.expiresAt,
  });

  final String grantId;
  final String patientId;
  final String patientName;
  final String scope; // full | critical
  final String source; // consent | break_glass
  final String expiresAt;

  bool get isFull => scope == 'full';

  factory DoctorGrant.fromJson(Map<String, dynamic> j) => DoctorGrant(
        grantId: j['grant_id'] as String,
        patientId: j['patient_id'] as String,
        patientName: j['patient_name'] as String,
        scope: j['scope'] as String,
        source: j['source'] as String,
        expiresAt: j['expires_at'] as String,
      );
}

class PendingRequest {
  PendingRequest({
    required this.requestId,
    required this.doctorName,
    required this.forPatient,
    this.hospital,
    this.specialty,
  });

  final String requestId;
  final String doctorName;
  final String forPatient;
  final String? hospital;
  final String? specialty;

  factory PendingRequest.fromJson(Map<String, dynamic> j) => PendingRequest(
        requestId: j['request_id'] as String,
        doctorName: j['doctor_name'] as String,
        forPatient: j['for_patient'] as String,
        hospital: j['hospital'] as String?,
        specialty: j['specialty'] as String?,
      );
}

class AuditEntry {
  AuditEntry({
    required this.at,
    required this.action,
    required this.forPatient,
    this.scope,
    this.doctorName,
    this.hospital,
    this.reason,
  });

  final String at;
  final String action;
  final String forPatient;
  final String? scope;
  final String? doctorName;
  final String? hospital;
  final String? reason;

  factory AuditEntry.fromJson(Map<String, dynamic> j) => AuditEntry(
        at: j['at'] as String,
        action: j['action'] as String,
        forPatient: j['for_patient'] as String? ?? '—',
        scope: j['scope'] as String?,
        doctorName: j['doctor_name'] as String?,
        hospital: j['hospital'] as String?,
        reason: j['reason'] as String?,
      );
}

class CriticalView {
  CriticalView({
    required this.patientName,
    required this.allergies,
    required this.currentMedications,
    required this.conditions,
    required this.note,
  });

  final String patientName;
  final List<String> allergies;
  final List<Map<String, dynamic>> currentMedications;
  final List<String> conditions;
  final String note;

  factory CriticalView.fromJson(Map<String, dynamic> j) => CriticalView(
        patientName: j['patient_name'] as String,
        allergies: (j['allergies'] as List? ?? []).map((e) => e.toString()).toList(),
        currentMedications: (j['current_medications'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
        conditions: (j['conditions'] as List? ?? []).map((e) => e.toString()).toList(),
        note: j['note'] as String? ?? '',
      );
}
