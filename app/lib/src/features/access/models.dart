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

class AiFlag {
  AiFlag({required this.text, required this.severity, required this.sourceRecordIds});

  final String text;
  final String severity; // info | watch | urgent
  final List<String> sourceRecordIds;

  factory AiFlag.fromJson(Map<String, dynamic> j) => AiFlag(
        text: j['text'] as String? ?? '',
        severity: j['severity'] as String? ?? 'info',
        sourceRecordIds: (j['source_record_ids'] as List? ?? [])
            .map((e) => e.toString())
            .toList(),
      );
}

class AiSummary {
  AiSummary({
    required this.summary,
    required this.flags,
    required this.relevantHistory,
    required this.model,
    required this.advisoryNotice,
  });

  final String summary;
  final List<AiFlag> flags;
  final List<String> relevantHistory;
  final String model;
  final String advisoryNotice;

  factory AiSummary.fromJson(Map<String, dynamic> j) => AiSummary(
        summary: j['summary'] as String? ?? '',
        flags: (j['flags'] as List? ?? [])
            .map((e) => AiFlag.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        relevantHistory:
            (j['relevant_history'] as List? ?? []).map((e) => e.toString()).toList(),
        model: j['model'] as String? ?? '',
        advisoryNotice: j['advisory_notice'] as String? ?? '',
      );
}

class AiAnswer {
  AiAnswer({
    required this.answer,
    required this.sourceRecordIds,
    required this.answeredFromRecords,
    required this.advisoryNotice,
  });

  final String answer;
  final List<String> sourceRecordIds;
  final bool answeredFromRecords;
  final String advisoryNotice;

  factory AiAnswer.fromJson(Map<String, dynamic> j) => AiAnswer(
        answer: j['answer'] as String? ?? '',
        sourceRecordIds: (j['source_record_ids'] as List? ?? [])
            .map((e) => e.toString())
            .toList(),
        answeredFromRecords: j['answered_from_records'] as bool? ?? false,
        advisoryNotice: j['advisory_notice'] as String? ?? '',
      );
}

class RxCandidate {
  RxCandidate({
    required this.name,
    this.dose,
    this.route,
    this.freq,
    required this.sourceRecordId,
    this.sourceDate,
  });

  final String name;
  final String? dose;
  final String? route;
  final String? freq;
  final String sourceRecordId;
  final String? sourceDate;

  factory RxCandidate.fromJson(Map<String, dynamic> j) => RxCandidate(
        name: j['name'] as String? ?? '',
        dose: j['dose'] as String?,
        route: j['route'] as String?,
        freq: j['freq'] as String?,
        sourceRecordId: j['source_record_id'] as String? ?? '',
        sourceDate: j['source_date'] as String?,
      );
}

class RxContext {
  RxContext({
    required this.patientName,
    required this.candidates,
    required this.knownAllergies,
    required this.assistantNote,
  });

  final String patientName;
  final List<RxCandidate> candidates;
  final List<String> knownAllergies;
  final String assistantNote;

  factory RxContext.fromJson(Map<String, dynamic> j) => RxContext(
        patientName: j['patient_name'] as String? ?? '',
        candidates: (j['candidates'] as List? ?? [])
            .map((e) => RxCandidate.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        knownAllergies:
            (j['known_allergies'] as List? ?? []).map((e) => e.toString()).toList(),
        assistantNote: j['assistant_note'] as String? ?? '',
      );
}

class RxCheck {
  RxCheck({
    required this.kind,
    required this.severity,
    required this.message,
    required this.drugs,
  });

  final String kind; // allergy | interaction | duplicate
  final String severity; // urgent | watch | info
  final String message;
  final List<String> drugs;

  factory RxCheck.fromJson(Map<String, dynamic> j) => RxCheck(
        kind: j['kind'] as String? ?? '',
        severity: j['severity'] as String? ?? 'info',
        message: j['message'] as String? ?? '',
        drugs: (j['drugs'] as List? ?? []).map((e) => e.toString()).toList(),
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
