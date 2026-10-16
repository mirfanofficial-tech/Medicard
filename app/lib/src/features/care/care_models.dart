// Models for the patient "home" / care plan and the doctor's patient overview.

List<T> _list<T>(dynamic v, T Function(Map<String, dynamic>) f) => (v as List? ?? [])
    .map((e) => f(Map<String, dynamic>.from(e as Map)))
    .toList();

List<String> _strings(dynamic v) => (v as List? ?? []).map((e) => e.toString()).toList();

// ------------------------------------------------------------------ patient

class TodayItem {
  TodayItem({
    required this.key,
    required this.kind,
    required this.title,
    required this.sub,
    required this.time,
    required this.done,
  });

  final String key;
  final String kind; // medicine | diet | activity
  final String title;
  final String sub;
  final String time;
  final bool done;

  factory TodayItem.fromJson(Map<String, dynamic> j) => TodayItem(
        key: j['key'] as String,
        kind: j['kind'] as String? ?? 'medicine',
        title: j['title'] as String? ?? '',
        sub: j['sub'] as String? ?? '',
        time: j['time'] as String? ?? '',
        done: j['done'] as bool? ?? false,
      );
}

class TodayView {
  TodayView({required this.done, required this.total, required this.items});
  final int done;
  final int total;
  final List<TodayItem> items;

  factory TodayView.fromJson(Map<String, dynamic> j) => TodayView(
        done: j['done'] as int? ?? 0,
        total: j['total'] as int? ?? 0,
        items: _list(j['items'], TodayItem.fromJson),
      );
}

class NextMedicine {
  NextMedicine({required this.key, required this.name, required this.at, required this.inMinutes});
  final String key;
  final String name;
  final String at;
  final int inMinutes;

  factory NextMedicine.fromJson(Map<String, dynamic> j) => NextMedicine(
        key: j['key'] as String,
        name: j['name'] as String? ?? '',
        at: j['at'] as String? ?? '',
        inMinutes: j['in_minutes'] as int? ?? 0,
      );

  /// "in 2 h 10 m", "now", or "40 min ago".
  String get relative {
    final m = inMinutes;
    if (m.abs() < 5) return 'now';
    final a = m.abs();
    final txt = a >= 60 ? '${a ~/ 60} h ${a % 60} m' : '$a min';
    return m > 0 ? 'in $txt' : '$txt ago';
  }
}

class SummaryPoint {
  SummaryPoint(this.label, this.value);
  final String label;
  final double value;
}

class HomeSummary {
  HomeSummary({required this.text, required this.trend, required this.note});
  final String text;
  final List<SummaryPoint> trend;
  final String note;

  factory HomeSummary.fromJson(Map<String, dynamic> j) => HomeSummary(
        text: j['text'] as String? ?? '',
        trend: _list(
          j['trend'],
          (e) => SummaryPoint(e['label'] as String? ?? '', (e['value'] as num).toDouble()),
        ),
        note: j['note'] as String? ?? '',
      );
}

class ReportItem {
  ReportItem({
    required this.recordId,
    required this.title,
    required this.sub,
    required this.verdict,
    required this.level,
  });
  final String recordId;
  final String title;
  final String sub;
  final String verdict;
  final String level; // high | low | normal | unknown

  factory ReportItem.fromJson(Map<String, dynamic> j) => ReportItem(
        recordId: j['record_id'] as String,
        title: j['title'] as String? ?? '',
        sub: j['sub'] as String? ?? '',
        verdict: j['verdict'] as String? ?? '',
        level: j['level'] as String? ?? 'unknown',
      );
}

class Tip {
  Tip({required this.emoji, required this.title, required this.sub, required this.fromDoctor});
  final String emoji;
  final String title;
  final String sub;
  final bool fromDoctor;

  factory Tip.fromJson(Map<String, dynamic> j) => Tip(
        emoji: j['emoji'] as String? ?? '•',
        title: j['title'] as String? ?? '',
        sub: j['sub'] as String? ?? '',
        fromDoctor: j['from_doctor'] as bool? ?? false,
      );
}

class FollowUp {
  FollowUp({required this.date, required this.when, this.withDoctor});
  final String date;
  final String when;
  final String? withDoctor;

  factory FollowUp.fromJson(Map<String, dynamic> j) => FollowUp(
        date: j['date'] as String? ?? '',
        when: j['when'] as String? ?? '',
        withDoctor: j['with_doctor'] as String?,
      );
}

class NumberTile {
  NumberTile({
    required this.label,
    required this.value,
    required this.unit,
    required this.status,
    required this.trend,
    required this.goal,
  });
  final String label;
  final String value;
  final String unit;
  final String status; // high | low | normal | unknown
  final String trend; // up | down | flat
  final String goal;
}

class EmergencyCard {
  EmergencyCard({
    required this.bloodGroup,
    required this.allergies,
    required this.conditions,
    required this.medicines,
  });
  final String? bloodGroup;
  final List<String> allergies;
  final List<String> conditions;
  final List<String> medicines;
}

class PatientHome {
  PatientHome({
    this.numbers = const [],
    this.emergency,
    required this.name,
    required this.nextMedicine,
    required this.today,
    required this.summary,
    required this.reports,
    required this.moreReports,
    required this.tips,
    required this.asks,
    required this.followUp,
    required this.pendingRequests,
  });

  final List<NumberTile> numbers;
  final EmergencyCard? emergency;
  final String name;
  final NextMedicine? nextMedicine;
  final TodayView today;
  final HomeSummary summary;
  final List<ReportItem> reports;
  final bool moreReports;
  final List<Tip> tips;
  final List<String> asks;
  final FollowUp? followUp;
  final int pendingRequests;

  factory PatientHome.fromJson(Map<String, dynamic> j) => PatientHome(
        numbers: _list(
          j['numbers'],
          (e) => NumberTile(
            label: e['label'] as String? ?? '',
            value: e['value'] as String? ?? '',
            unit: e['unit'] as String? ?? '',
            status: e['status'] as String? ?? 'unknown',
            trend: e['trend'] as String? ?? 'flat',
            goal: e['goal'] as String? ?? '',
          ),
        ),
        emergency: j['emergency'] == null
            ? null
            : () {
                final e = Map<String, dynamic>.from(j['emergency'] as Map);
                return EmergencyCard(
                  bloodGroup: e['blood_group'] as String?,
                  allergies: _strings(e['allergies']),
                  conditions: _strings(e['conditions']),
                  medicines: _strings(e['medicines']),
                );
              }(),
        name: j['name'] as String? ?? '',
        nextMedicine: j['next_medicine'] == null
            ? null
            : NextMedicine.fromJson(Map<String, dynamic>.from(j['next_medicine'] as Map)),
        today: TodayView.fromJson(Map<String, dynamic>.from(j['today'] as Map)),
        summary: HomeSummary.fromJson(Map<String, dynamic>.from(j['summary'] as Map)),
        reports: _list(j['reports'], ReportItem.fromJson),
        moreReports: j['more_reports'] as bool? ?? false,
        tips: _list(j['tips'], Tip.fromJson),
        asks: _strings(j['asks']),
        followUp: j['follow_up'] == null
            ? null
            : FollowUp.fromJson(Map<String, dynamic>.from(j['follow_up'] as Map)),
        pendingRequests: j['pending_requests'] as int? ?? 0,
      );
}

class CareEvent {
  CareEvent({required this.title, required this.when, required this.kind});
  final String title;
  final String when;
  final String kind;

  factory CareEvent.fromJson(Map<String, dynamic> j) => CareEvent(
        title: j['title'] as String? ?? '',
        when: j['when'] as String? ?? '',
        kind: j['kind'] as String? ?? '',
      );
}

class CarePlanData {
  CarePlanData({
    required this.hasPlan,
    required this.issuedBy,
    required this.issuedOn,
    required this.week,
    required this.of,
    required this.percent,
    required this.today,
    required this.dietNote,
    required this.eatMore,
    required this.eatLess,
    required this.activity,
    required this.events,
    required this.followUp,
    required this.disclaimer,
  });

  final bool hasPlan;
  final String? issuedBy;
  final String? issuedOn;
  final int week;
  final int of;
  final int percent;
  final TodayView today;
  final String? dietNote;
  final List<String> eatMore;
  final List<String> eatLess;
  final List<String> activity;
  final List<CareEvent> events;
  final FollowUp? followUp;
  final String disclaimer;

  factory CarePlanData.fromJson(Map<String, dynamic> j) {
    final diet = Map<String, dynamic>.from(j['diet'] as Map? ?? {});
    return CarePlanData(
      hasPlan: j['has_plan'] as bool? ?? false,
      issuedBy: j['issued_by'] as String?,
      issuedOn: j['issued_on'] as String?,
      week: j['week'] as int? ?? 0,
      of: j['of'] as int? ?? 0,
      percent: j['percent'] as int? ?? 0,
      today: TodayView.fromJson(Map<String, dynamic>.from(j['today'] as Map)),
      dietNote: diet['note'] as String?,
      eatMore: _strings(diet['more']),
      eatLess: _strings(diet['less']),
      activity: _strings(j['activity']),
      events: _list(j['events'], CareEvent.fromJson),
      followUp: j['follow_up'] == null
          ? null
          : FollowUp.fromJson(Map<String, dynamic>.from(j['follow_up'] as Map)),
      disclaimer: j['disclaimer'] as String? ?? '',
    );
  }
}

class PatientAnswer {
  PatientAnswer({required this.answer, required this.fromRecords, required this.notice});
  final String answer;
  final bool fromRecords;
  final String notice;

  factory PatientAnswer.fromJson(Map<String, dynamic> j) => PatientAnswer(
        answer: j['answer'] as String? ?? '',
        fromRecords: j['answered_from_records'] as bool? ?? false,
        notice: j['notice'] as String? ?? '',
      );
}

// ------------------------------------------------------------------- doctor

class HistoryAlert {
  HistoryAlert({
    required this.kind,
    required this.severity,
    required this.title,
    required this.text,
    required this.sourceRecordId,
    required this.sourceLabel,
  });
  final String kind; // allergy | reaction | stopped
  final String severity; // urgent | watch | info
  final String title;
  final String text;
  final String sourceRecordId;
  final String sourceLabel;

  factory HistoryAlert.fromJson(Map<String, dynamic> j) => HistoryAlert(
        kind: j['kind'] as String? ?? '',
        severity: j['severity'] as String? ?? 'info',
        title: j['title'] as String? ?? '',
        text: j['text'] as String? ?? '',
        sourceRecordId: j['source_record_id'] as String? ?? '',
        sourceLabel: j['source_label'] as String? ?? '',
      );
}

class TrendData {
  TrendData({
    required this.name,
    required this.unit,
    required this.latest,
    required this.flag,
    required this.values,
  });
  final String name;
  final String? unit;
  final double latest;
  final String flag; // high | low | normal | unknown
  final List<double> values;

  factory TrendData.fromJson(Map<String, dynamic> j) => TrendData(
        name: j['name'] as String? ?? '',
        unit: j['unit'] as String?,
        latest: (j['latest'] as num).toDouble(),
        flag: j['flag'] as String? ?? 'unknown',
        values: (j['points'] as List? ?? [])
            .map((p) => ((p as Map)['value'] as num).toDouble())
            .toList(),
      );
}

class DoctorTip {
  DoctorTip(this.severity, this.text);
  final String severity;
  final String text;
}

class AdherenceRow {
  AdherenceRow(this.label, this.done, this.total);
  final String label;
  final int done;
  final int total;
}

class LabRowData {
  LabRowData({
    required this.name,
    required this.value,
    required this.unit,
    required this.ref,
    required this.flag,
    required this.date,
    required this.recordId,
  });
  final String name;
  final String value;
  final String? unit;
  final String? ref;
  final String flag; // high | low | normal | unknown
  final String? date;
  final String recordId;
}

class OverviewCountsData {
  OverviewCountsData(this.conditions, this.medications, this.allergies, this.documents, this.labTests);
  final int conditions;
  final int medications;
  final int allergies;
  final int documents;
  final int labTests;
}

class OverviewRecord {
  OverviewRecord({
    required this.recordId,
    required this.type,
    required this.title,
    required this.sub,
    required this.verified,
    this.summary,
    this.date,
  });
  final String? summary;
  final String? date;
  final String recordId;
  final String type;
  final String title;
  final String sub;
  final bool verified;
}

class OverviewMed {
  OverviewMed(this.name, this.dose, this.freq);
  final String name;
  final String? dose;
  final String? freq;
}

class PatientOverviewData {
  PatientOverviewData({
    required this.patientId,
    required this.name,
    required this.age,
    required this.gender,
    required this.bloodGroup,
    required this.code,
    required this.conditions,
    required this.allergies,
    required this.alerts,
    required this.trends,
    required this.records,
    required this.hiddenCount,
    required this.meds,
    required this.tips,
    required this.adherence,
    required this.visits,
    required this.notice,
    required this.counts,
    required this.labs,
    this.phone,
    this.registeredOn,
    this.lastUpdated,
    this.upcoming,
    this.grantExpiresAt,
  });

  final String? phone;
  final String? registeredOn;
  final String? lastUpdated;
  final OverviewCountsData counts;
  final List<LabRowData> labs;
  final String? upcoming; // e.g. "Follow-up · 30 Oct 2026"

  final String patientId;
  final String name;
  final int? age;
  final String? gender;
  final String? bloodGroup;
  final String code;
  final List<String> conditions;
  final List<String> allergies;
  final List<HistoryAlert> alerts;
  final List<TrendData> trends;
  final List<OverviewRecord> records;
  final int hiddenCount;
  final List<OverviewMed> meds;
  final List<DoctorTip> tips;
  final List<AdherenceRow> adherence;
  final List<String> visits;
  final String notice;
  final DateTime? grantExpiresAt;

  factory PatientOverviewData.fromJson(Map<String, dynamic> j) => PatientOverviewData(
        patientId: j['patient_id'] as String,
        name: j['name'] as String? ?? '',
        age: j['age'] as int?,
        gender: j['gender'] as String?,
        bloodGroup: j['blood_group'] as String?,
        code: j['medicard_code'] as String? ?? '',
        conditions: _strings(j['conditions']),
        allergies: _strings(j['allergies']),
        alerts: _list(j['history_alerts'], HistoryAlert.fromJson),
        trends: _list(j['trends'], TrendData.fromJson),
        records: _list(
          j['records'],
          (e) => OverviewRecord(
            recordId: e['record_id'] as String,
            type: e['type'] as String? ?? '',
            title: e['title'] as String? ?? '',
            sub: e['sub'] as String? ?? '',
            verified: e['verified'] as bool? ?? false,
            summary: e['summary'] as String?,
            date: e['date'] as String?,
          ),
        ),
        hiddenCount: j['hidden_count'] as int? ?? 0,
        meds: _list(
          j['medications'],
          (e) => OverviewMed(
              e['name'] as String? ?? '', e['dose'] as String?, e['freq'] as String?),
        ),
        tips: _list(j['tips'], (e) => DoctorTip(e['severity'] as String? ?? 'info', e['text'] as String? ?? '')),
        adherence: _list(
          j['adherence'],
          (e) => AdherenceRow(e['label'] as String? ?? '', e['done'] as int? ?? 0, e['total'] as int? ?? 0),
        ),
        visits: _list(j['visits'], (e) => '${e['date'] ?? ''} · ${e['text'] ?? ''}'),
        notice: j['advisory_notice'] as String? ?? '',
        phone: j['phone'] as String?,
        registeredOn: j['registered_on'] as String?,
        lastUpdated: j['last_updated'] as String?,
        counts: () {
          final c = Map<String, dynamic>.from(j['counts'] as Map? ?? {});
          return OverviewCountsData(c['conditions'] as int? ?? 0, c['medications'] as int? ?? 0,
              c['allergies'] as int? ?? 0, c['documents'] as int? ?? 0, c['lab_tests'] as int? ?? 0);
        }(),
        labs: _list(
          j['latest_labs'],
          (e) => LabRowData(
            name: e['name'] as String? ?? '',
            value: e['value'] as String? ?? '',
            unit: e['unit'] as String?,
            ref: e['ref'] as String?,
            flag: e['flag'] as String? ?? 'unknown',
            date: e['date'] as String?,
            recordId: e['record_id'] as String? ?? '',
          ),
        ),
        upcoming: j['upcoming'] == null
            ? null
            : '${(j['upcoming'] as Map)['title']} · ${(j['upcoming'] as Map)['when']}',
        grantExpiresAt: j['grant_expires_at'] == null
            ? null
            : DateTime.tryParse(j['grant_expires_at'] as String),
      );
}

class VoiceDraftMed {
  VoiceDraftMed({required this.name, this.dose, this.freq, this.days});
  final String name;
  final String? dose;
  final String? freq;
  final String? days;
}

class VoiceDraft {
  VoiceDraft({
    required this.complaint,
    required this.assessment,
    required this.plan,
    required this.meds,
    required this.dietNote,
    required this.eatMore,
    required this.eatLess,
    required this.activity,
    required this.tests,
    required this.followUpDays,
  });

  final String? complaint;
  final String? assessment;
  final String? plan;
  final List<VoiceDraftMed> meds;
  final String? dietNote;
  final List<String> eatMore;
  final List<String> eatLess;
  final List<String> activity;
  final List<({String name, int inDays})> tests;
  final int? followUpDays;

  factory VoiceDraft.fromJson(Map<String, dynamic> j) {
    final note = Map<String, dynamic>.from(j['note'] as Map? ?? {});
    final adv = Map<String, dynamic>.from(j['advice'] as Map? ?? {});
    final diet = adv['diet'] == null ? null : Map<String, dynamic>.from(adv['diet'] as Map);
    return VoiceDraft(
      complaint: note['complaint'] as String?,
      assessment: note['assessment'] as String?,
      plan: note['plan'] as String?,
      meds: _list(
        j['medications'],
        (e) => VoiceDraftMed(
          name: e['name'] as String? ?? '',
          dose: e['dose'] as String?,
          freq: e['freq'] as String?,
          days: e['days'] as String?,
        ),
      ),
      dietNote: diet?['note'] as String?,
      eatMore: _strings(diet?['more']),
      eatLess: _strings(diet?['less']),
      activity: _strings(adv['activity']),
      tests: (adv['tests'] as List? ?? [])
          .map((e) => (
                name: (e as Map)['name'] as String? ?? '',
                inDays: e['in_days'] as int? ?? 0,
              ))
          .toList(),
      followUpDays: adv['follow_up_days'] as int?,
    );
  }
}

// ---------------------------------------------------------- doctor dashboard

class DashStatsData {
  DashStatsData(this.activeAccess, this.pending, this.prescriptions30d, this.patientsSeen30d,
      this.emergency30d);
  final int activeAccess;
  final int pending;
  final int prescriptions30d;
  final int patientsSeen30d;
  final int emergency30d;
}

class DashDayData {
  DashDayData(this.day, this.views, this.prescriptions);
  final String day;
  final int views;
  final int prescriptions;
}

class DashActiveData {
  DashActiveData({
    required this.grantId,
    required this.patientId,
    required this.name,
    required this.age,
    required this.gender,
    required this.scope,
    required this.source,
    required this.expiresAt,
    required this.alerts,
  });
  final String grantId;
  final String patientId;
  final String name;
  final int? age;
  final String? gender;
  final String scope;
  final String source;
  final DateTime? expiresAt;
  final List<DoctorTip> alerts;

  bool get isFull => scope == 'full';
}

class DashPendingData {
  DashPendingData(this.requestId, this.name, this.createdAt);
  final String requestId;
  final String name;
  final DateTime? createdAt;
}

class DashActivityData {
  DashActivityData(this.at, this.action, this.name, this.text);
  final DateTime? at;
  final String action;
  final String name;
  final String text;
}

class ScheduleItem {
  ScheduleItem({
    required this.name,
    required this.time,
    required this.reason,
    required this.status,
    required this.active,
    this.patientId,
    this.codeHint,
  });
  final String name;
  final String time;
  final String reason;
  final String status; // done | waiting | in_consultation
  final bool active;
  final String? patientId;
  final String? codeHint;
}

class DoctorDashboardData {
  DoctorDashboardData({
    this.briefHeadline,
    this.briefBullets = const [],
    this.schedule = const [],
    required this.name,
    required this.specialty,
    required this.hospital,
    required this.stats,
    required this.week,
    required this.active,
    required this.pending,
    required this.activity,
  });

  final String name;
  final String? specialty;
  final String? hospital;
  final String? briefHeadline;
  final List<String> briefBullets;
  final List<ScheduleItem> schedule;
  final DashStatsData stats;
  final List<DashDayData> week;
  final List<DashActiveData> active;
  final List<DashPendingData> pending;
  final List<DashActivityData> activity;

  factory DoctorDashboardData.fromJson(Map<String, dynamic> j) {
    final st = Map<String, dynamic>.from(j['stats'] as Map? ?? {});
    final brief = j['brief'] == null ? null : Map<String, dynamic>.from(j['brief'] as Map);
    return DoctorDashboardData(
      briefHeadline: brief?['headline'] as String?,
      briefBullets: _strings(brief?['bullets']),
      schedule: _list(
        j['schedule'],
        (e) => ScheduleItem(
          name: e['name'] as String? ?? '',
          time: e['time'] as String? ?? '',
          reason: e['reason'] as String? ?? '',
          status: e['status'] as String? ?? 'waiting',
          active: e['active'] as bool? ?? false,
          patientId: e['patient_id'] as String?,
          codeHint: e['code_hint'] as String?,
        ),
      ),
      name: j['name'] as String? ?? '',
      specialty: j['specialty'] as String?,
      hospital: j['hospital'] as String?,
      stats: DashStatsData(
        st['active_access'] as int? ?? 0,
        st['pending_requests'] as int? ?? 0,
        st['prescriptions_30d'] as int? ?? 0,
        st['patients_seen_30d'] as int? ?? 0,
        st['emergency_30d'] as int? ?? 0,
      ),
      week: _list(j['week'],
          (e) => DashDayData(e['day'] as String? ?? '', e['views'] as int? ?? 0, e['prescriptions'] as int? ?? 0)),
      active: _list(
        j['active'],
        (e) => DashActiveData(
          grantId: e['grant_id'] as String,
          patientId: e['patient_id'] as String,
          name: e['patient_name'] as String? ?? '',
          age: e['age'] as int?,
          gender: e['gender'] as String?,
          scope: e['scope'] as String? ?? 'full',
          source: e['source'] as String? ?? 'consent',
          expiresAt: DateTime.tryParse(e['expires_at'] as String? ?? ''),
          alerts: _list(e['alerts'],
              (a) => DoctorTip(a['severity'] as String? ?? 'info', a['text'] as String? ?? '')),
        ),
      ),
      pending: _list(
        j['pending'],
        (e) => DashPendingData(e['request_id'] as String, e['patient_name'] as String? ?? '',
            DateTime.tryParse(e['created_at'] as String? ?? '')),
      ),
      activity: _list(
        j['activity'],
        (e) => DashActivityData(DateTime.tryParse(e['at'] as String? ?? ''),
            e['action'] as String? ?? '', e['patient_name'] as String? ?? '', e['text'] as String? ?? ''),
      ),
    );
  }
}
