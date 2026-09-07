class Medication {
  Medication({required this.name, this.dose, this.route, this.freq});

  String name;
  String? dose;
  String? route;
  String? freq;

  factory Medication.fromJson(Map<String, dynamic> j) => Medication(
        name: j['name'] as String? ?? '',
        dose: j['dose'] as String?,
        route: j['route'] as String?,
        freq: j['freq'] as String?,
      );

  Map<String, dynamic> toJson() =>
      {'name': name, 'dose': dose, 'route': route, 'freq': freq};
}

class LabResult {
  LabResult({required this.name, this.value, this.unit, this.refRange});

  String name;
  String? value;
  String? unit;
  String? refRange;

  factory LabResult.fromJson(Map<String, dynamic> j) => LabResult(
        name: j['name'] as String? ?? '',
        value: j['value'] as String?,
        unit: j['unit'] as String?,
        refRange: j['ref_range'] as String?,
      );

  Map<String, dynamic> toJson() =>
      {'name': name, 'value': value, 'unit': unit, 'ref_range': refRange};
}

class RecordData {
  RecordData({
    required this.diagnoses,
    required this.medications,
    required this.labResults,
    required this.allergies,
    this.notes,
  });

  List<String> diagnoses;
  List<Medication> medications;
  List<LabResult> labResults;
  List<String> allergies;
  String? notes;

  factory RecordData.fromJson(Map<String, dynamic> j) => RecordData(
        diagnoses: (j['diagnoses'] as List? ?? []).map((e) => e.toString()).toList(),
        medications: (j['medications'] as List? ?? [])
            .map((e) => Medication.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        labResults: (j['lab_results'] as List? ?? [])
            .map((e) => LabResult.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        allergies: (j['allergies'] as List? ?? []).map((e) => e.toString()).toList(),
        notes: j['notes'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'diagnoses': diagnoses,
        'medications': medications.map((m) => m.toJson()).toList(),
        'lab_results': labResults.map((l) => l.toJson()).toList(),
        'allergies': allergies,
        'notes': notes,
      };
}

class ExtractionView {
  ExtractionView({required this.status, required this.confidenceByField, this.error});

  final String status;
  final Map<String, double> confidenceByField;
  final String? error;

  factory ExtractionView.fromJson(Map<String, dynamic> j) => ExtractionView(
        status: j['status'] as String? ?? 'unknown',
        confidenceByField: (j['confidence_by_field'] as Map? ?? {}).map(
          (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
        ),
        error: j['error'] as String?,
      );
}

class RecordSummary {
  RecordSummary({
    required this.id,
    required this.type,
    required this.verified,
    required this.sensitive,
    this.docDate,
    this.provider,
  });

  final String id;
  final String type;
  final bool verified;
  final bool sensitive;
  final String? docDate;
  final String? provider;

  factory RecordSummary.fromJson(Map<String, dynamic> j) => RecordSummary(
        id: j['record_id'] as String,
        type: j['type'] as String? ?? 'note',
        verified: j['verified'] as bool? ?? false,
        sensitive: j['sensitive'] as bool? ?? false,
        docDate: j['doc_date'] as String?,
        provider: j['provider'] as String?,
      );
}

class RecordDetail {
  RecordDetail({
    required this.summary,
    required this.data,
    this.sourceUrl,
    this.extraction,
  });

  final RecordSummary summary;
  final RecordData data;
  final String? sourceUrl;
  final ExtractionView? extraction;

  factory RecordDetail.fromJson(Map<String, dynamic> j) => RecordDetail(
        summary: RecordSummary.fromJson(j),
        data: RecordData.fromJson(Map<String, dynamic>.from(j['data'] as Map? ?? {})),
        sourceUrl: j['source_url'] as String?,
        extraction: j['extraction'] == null
            ? null
            : ExtractionView.fromJson(Map<String, dynamic>.from(j['extraction'] as Map)),
      );
}
