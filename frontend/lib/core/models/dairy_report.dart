// DTOs for the Dairy Reports dashboard.
//
// Phase 1 ships only the Milk Production report. Adding a new report
// type means adding a new `*Report` class here + a matching service
// method on the backend.

double _toDouble(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}

double? _toDoubleNullable(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

int _toInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.round();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

DateTime _toDate(dynamic v) =>
    DateTime.tryParse((v ?? '').toString()) ?? DateTime.now();

/// Period preset — pairs with `DairyReportPeriod` on the frontend pill
/// bar and the resolveRange() helper on the backend.
enum DairyReportPeriod {
  today('today', 'Today'),
  week('week', 'Week'),
  month('month', 'Month'),
  quarter('quarter', 'Quarter'),
  halfYear('halfyear', 'Half-year'),
  annual('annual', 'Year'),
  custom('custom', 'Custom');

  const DairyReportPeriod(this.wire, this.label);
  final String wire;
  final String label;
}

/// Report-type pill enum. Drives the report-type pill rail. The four
/// phase-2 reports are enabled; the remaining three (Calves, Workers,
/// Inventory) stay disabled until Phase 2.5 lands.
enum DairyReportType {
  milk('milk', '🥛 Milk', enabled: true),
  reproduction('reproduction', '🧬 Reproduction', enabled: true),
  health('health', '🩺 Health', enabled: true),
  vaccinations('vaccinations', '💉 Vaccinations', enabled: true),
  calves('calves', '🐮 Calves'),
  worker('worker', '👷 Workers'),
  inventory('inventory', '📦 Inventory');

  const DairyReportType(this.wire, this.label, {this.enabled = false});
  final String wire;
  final String label;
  final bool enabled;
}

class ReportPeriodWindow {
  ReportPeriodWindow({
    required this.label,
    required this.start,
    required this.end,
    required this.prevStart,
    required this.prevEnd,
  });
  final String label;
  final DateTime start;
  final DateTime end;
  final DateTime prevStart;
  final DateTime prevEnd;

  factory ReportPeriodWindow.fromJson(Map<String, dynamic> j) =>
      ReportPeriodWindow(
        label: (j['label'] ?? '').toString(),
        start: _toDate(j['start']),
        end: _toDate(j['end']),
        prevStart: _toDate(j['prevStart']),
        prevEnd: _toDate(j['prevEnd']),
      );
}

class MilkSessionBreakdown {
  MilkSessionBreakdown({
    required this.dawn,
    required this.am,
    required this.mid,
    required this.pm,
  });
  final double dawn;
  final double am;
  final double mid;
  final double pm;

  factory MilkSessionBreakdown.fromJson(Map<String, dynamic> j) =>
      MilkSessionBreakdown(
        dawn: _toDouble(j['DAWN']),
        am: _toDouble(j['AM']),
        mid: _toDouble(j['MID']),
        pm: _toDouble(j['PM']),
      );

  double get total => dawn + am + mid + pm;
}

class MilkReportTotals {
  MilkReportTotals({
    required this.litres,
    required this.prevLitres,
    required this.deltaPct,
    required this.activeCows,
    required this.avgPerCow,
    required this.sessions,
  });
  final double litres;
  final double prevLitres;
  /// `null` when the previous window had no data — UI shows "—" then.
  final double? deltaPct;
  final int activeCows;
  final double avgPerCow;
  final MilkSessionBreakdown sessions;

  factory MilkReportTotals.fromJson(Map<String, dynamic> j) =>
      MilkReportTotals(
        litres: _toDouble(j['litres']),
        prevLitres: _toDouble(j['prevLitres']),
        deltaPct: _toDoubleNullable(j['deltaPct']),
        activeCows: _toInt(j['activeCows']),
        avgPerCow: _toDouble(j['avgPerCow']),
        sessions: j['sessions'] is Map
            ? MilkSessionBreakdown.fromJson(
                (j['sessions'] as Map).cast<String, dynamic>())
            : MilkSessionBreakdown(dawn: 0, am: 0, mid: 0, pm: 0),
      );
}

class MilkReportCow {
  MilkReportCow({
    required this.cowId,
    required this.tag,
    required this.litres,
    this.nickname,
  });
  final String cowId;
  final String tag;
  final String? nickname;
  final double litres;

  String get displayName =>
      (nickname == null || nickname!.isEmpty) ? tag : '$tag · $nickname';

  factory MilkReportCow.fromJson(Map<String, dynamic> j) => MilkReportCow(
        cowId: (j['cowId'] ?? '').toString(),
        tag: (j['tag'] ?? '').toString(),
        nickname: j['nickname']?.toString(),
        litres: _toDouble(j['litres']),
      );
}

class MilkReportDailyPoint {
  MilkReportDailyPoint({
    required this.date,
    required this.dow,
    required this.litres,
  });
  final String date; // ISO yyyy-mm-dd
  final String dow;
  final double litres;

  factory MilkReportDailyPoint.fromJson(Map<String, dynamic> j) =>
      MilkReportDailyPoint(
        date: (j['date'] ?? '').toString(),
        dow: (j['dow'] ?? '').toString(),
        litres: _toDouble(j['litres']),
      );
}

class MilkProductionReport {
  MilkProductionReport({
    required this.period,
    required this.totals,
    required this.daily,
    this.best,
    this.lowest,
  });
  final ReportPeriodWindow period;
  final MilkReportTotals totals;
  final List<MilkReportDailyPoint> daily;
  final MilkReportCow? best;
  final MilkReportCow? lowest;

  factory MilkProductionReport.fromJson(Map<String, dynamic> j) {
    final dailyRaw = (j['daily'] as List?) ?? const [];
    return MilkProductionReport(
      period: j['period'] is Map
          ? ReportPeriodWindow.fromJson(
              (j['period'] as Map).cast<String, dynamic>())
          : ReportPeriodWindow(
              label: '',
              start: DateTime.now(),
              end: DateTime.now(),
              prevStart: DateTime.now(),
              prevEnd: DateTime.now(),
            ),
      totals: j['totals'] is Map
          ? MilkReportTotals.fromJson(
              (j['totals'] as Map).cast<String, dynamic>())
          : MilkReportTotals(
              litres: 0,
              prevLitres: 0,
              deltaPct: null,
              activeCows: 0,
              avgPerCow: 0,
              sessions:
                  MilkSessionBreakdown(dawn: 0, am: 0, mid: 0, pm: 0),
            ),
      best: j['best'] is Map
          ? MilkReportCow.fromJson((j['best'] as Map).cast<String, dynamic>())
          : null,
      lowest: j['lowest'] is Map
          ? MilkReportCow.fromJson(
              (j['lowest'] as Map).cast<String, dynamic>())
          : null,
      daily: dailyRaw
          .whereType<Map>()
          .map((m) =>
              MilkReportDailyPoint.fromJson(m.cast<String, dynamic>()))
          .toList(),
    );
  }
}

/* =====================================================================
 * Reproduction Report
 * =================================================================== */

class ReportDailyCount {
  ReportDailyCount({required this.date, required this.dow, required this.count});
  final String date;
  final String dow;
  final int count;
  factory ReportDailyCount.fromJson(Map<String, dynamic> j) =>
      ReportDailyCount(
        date: (j['date'] ?? '').toString(),
        dow: (j['dow'] ?? '').toString(),
        count: _toInt(j['count']),
      );
}

class ReproductionTotals {
  ReproductionTotals({
    required this.aiCount,
    required this.calvings,
    required this.pregnanciesConfirmed,
    required this.pendingChecks,
    required this.expectedCalvings,
    required this.prevAiCount,
    required this.deltaPct,
  });
  final int aiCount;
  final int calvings;
  final int pregnanciesConfirmed;
  final int pendingChecks;
  final int expectedCalvings;
  final int prevAiCount;
  final double? deltaPct;

  factory ReproductionTotals.fromJson(Map<String, dynamic> j) =>
      ReproductionTotals(
        aiCount: _toInt(j['aiCount']),
        calvings: _toInt(j['calvings']),
        pregnanciesConfirmed: _toInt(j['pregnanciesConfirmed']),
        pendingChecks: _toInt(j['pendingChecks']),
        expectedCalvings: _toInt(j['expectedCalvings']),
        prevAiCount: _toInt(j['prevAiCount']),
        deltaPct: _toDoubleNullable(j['deltaPct']),
      );
}

class UpcomingCalving {
  UpcomingCalving({
    required this.id,
    required this.tag,
    this.nickname,
    this.sireCode,
    this.expectedCalvingDate,
    this.daysOut,
  });
  final String id;
  final String? tag;
  final String? nickname;
  final String? sireCode;
  final DateTime? expectedCalvingDate;
  final int? daysOut;

  factory UpcomingCalving.fromJson(Map<String, dynamic> j) => UpcomingCalving(
        id: (j['id'] ?? '').toString(),
        tag: j['tag']?.toString(),
        nickname: j['nickname']?.toString(),
        sireCode: j['sireCode']?.toString(),
        expectedCalvingDate: j['expectedCalvingDate'] != null
            ? DateTime.tryParse(j['expectedCalvingDate'].toString())
            : null,
        daysOut: j['daysOut'] is num
            ? (j['daysOut'] as num).toInt()
            : (j['daysOut'] is String
                ? int.tryParse(j['daysOut'] as String)
                : null),
      );
}

class ReproductionEvent {
  ReproductionEvent({
    required this.id,
    required this.eventType,
    required this.eventDate,
    this.sireCode,
    this.pregnancyStatus,
    this.expectedCalvingDate,
    this.calfTag,
    this.calfSex,
    this.cowTag,
    this.cowNickname,
  });
  final String id;
  final String eventType;
  final DateTime eventDate;
  final String? sireCode;
  final String? pregnancyStatus;
  final DateTime? expectedCalvingDate;
  final String? calfTag;
  final String? calfSex;
  final String? cowTag;
  final String? cowNickname;

  factory ReproductionEvent.fromJson(Map<String, dynamic> j) {
    final cow = j['cow'] is Map
        ? (j['cow'] as Map).cast<String, dynamic>()
        : null;
    return ReproductionEvent(
      id: (j['id'] ?? '').toString(),
      eventType: (j['eventType'] ?? '').toString(),
      eventDate: _toDate(j['eventDate']),
      sireCode: j['sireCode']?.toString(),
      pregnancyStatus: j['pregnancyStatus']?.toString(),
      expectedCalvingDate: j['expectedCalvingDate'] != null
          ? DateTime.tryParse(j['expectedCalvingDate'].toString())
          : null,
      calfTag: j['calfTag']?.toString(),
      calfSex: j['calfSex']?.toString(),
      cowTag: cow?['tag']?.toString(),
      cowNickname: cow?['nickname']?.toString(),
    );
  }
}

class ReproductionReport {
  ReproductionReport({
    required this.period,
    required this.totals,
    required this.pregnancyRate,
    required this.conceptionRate,
    required this.aiTrend,
    required this.calvingTrend,
    required this.upcomingCalvings,
    required this.recentEvents,
  });
  final ReportPeriodWindow period;
  final ReproductionTotals totals;
  final double? pregnancyRate;
  final double? conceptionRate;
  final List<ReportDailyCount> aiTrend;
  final List<ReportDailyCount> calvingTrend;
  final List<UpcomingCalving> upcomingCalvings;
  final List<ReproductionEvent> recentEvents;

  factory ReproductionReport.fromJson(Map<String, dynamic> j) =>
      ReproductionReport(
        period: ReportPeriodWindow.fromJson(
            (j['period'] as Map).cast<String, dynamic>()),
        totals: ReproductionTotals.fromJson(
            (j['totals'] as Map).cast<String, dynamic>()),
        pregnancyRate: _toDoubleNullable(j['pregnancyRate']),
        conceptionRate: _toDoubleNullable(j['conceptionRate']),
        aiTrend: ((j['aiTrend'] as List?) ?? const [])
            .whereType<Map>()
            .map((m) =>
                ReportDailyCount.fromJson(m.cast<String, dynamic>()))
            .toList(),
        calvingTrend: ((j['calvingTrend'] as List?) ?? const [])
            .whereType<Map>()
            .map((m) =>
                ReportDailyCount.fromJson(m.cast<String, dynamic>()))
            .toList(),
        upcomingCalvings: ((j['upcomingCalvings'] as List?) ?? const [])
            .whereType<Map>()
            .map((m) =>
                UpcomingCalving.fromJson(m.cast<String, dynamic>()))
            .toList(),
        recentEvents: ((j['recentEvents'] as List?) ?? const [])
            .whereType<Map>()
            .map((m) =>
                ReproductionEvent.fromJson(m.cast<String, dynamic>()))
            .toList(),
      );
}

/* =====================================================================
 * Health Report
 * =================================================================== */

class HealthTotals {
  HealthTotals({
    required this.sick,
    required this.active,
    required this.recovered,
    required this.critical,
    required this.prev,
    required this.deltaPct,
  });
  final int sick;
  final int active;
  final int recovered;
  final int critical;
  final int prev;
  final double? deltaPct;

  factory HealthTotals.fromJson(Map<String, dynamic> j) => HealthTotals(
        sick: _toInt(j['sick']),
        active: _toInt(j['active']),
        recovered: _toInt(j['recovered']),
        critical: _toInt(j['critical']),
        prev: _toInt(j['prev']),
        deltaPct: _toDoubleNullable(j['deltaPct']),
      );
}

class DiseaseFrequency {
  DiseaseFrequency({required this.diagnosis, required this.count});
  final String diagnosis;
  final int count;
  factory DiseaseFrequency.fromJson(Map<String, dynamic> j) =>
      DiseaseFrequency(
        diagnosis: (j['diagnosis'] ?? '').toString(),
        count: _toInt(j['count']),
      );
}

class HouseHealthCount {
  HouseHealthCount({this.houseId, required this.houseName, required this.count});
  final String? houseId;
  final String houseName;
  final int count;
  factory HouseHealthCount.fromJson(Map<String, dynamic> j) => HouseHealthCount(
        houseId: j['houseId']?.toString(),
        houseName: (j['houseName'] ?? '—').toString(),
        count: _toInt(j['count']),
      );
}

class PendingCase {
  PendingCase({
    required this.id,
    required this.tag,
    this.nickname,
    required this.diagnosis,
    required this.medication,
    required this.status,
    required this.startDate,
    this.attendingVet,
    this.notes,
  });
  final String id;
  final String tag;
  final String? nickname;
  final String diagnosis;
  final String medication;
  final String status;
  final DateTime startDate;
  final String? attendingVet;
  final String? notes;

  factory PendingCase.fromJson(Map<String, dynamic> j) => PendingCase(
        id: (j['id'] ?? '').toString(),
        tag: (j['tag'] ?? '').toString(),
        nickname: j['nickname']?.toString(),
        diagnosis: (j['diagnosis'] ?? '').toString(),
        medication: (j['medication'] ?? '').toString(),
        status: (j['status'] ?? '').toString(),
        startDate: _toDate(j['startDate']),
        attendingVet: j['attendingVet']?.toString(),
        notes: j['notes']?.toString(),
      );
}

class HealthReport {
  HealthReport({
    required this.period,
    required this.totals,
    required this.diseases,
    required this.houseBreakdown,
    required this.pendingCases,
  });
  final ReportPeriodWindow period;
  final HealthTotals totals;
  final List<DiseaseFrequency> diseases;
  final List<HouseHealthCount> houseBreakdown;
  final List<PendingCase> pendingCases;

  factory HealthReport.fromJson(Map<String, dynamic> j) => HealthReport(
        period: ReportPeriodWindow.fromJson(
            (j['period'] as Map).cast<String, dynamic>()),
        totals: HealthTotals.fromJson(
            (j['totals'] as Map).cast<String, dynamic>()),
        diseases: ((j['diseases'] as List?) ?? const [])
            .whereType<Map>()
            .map((m) =>
                DiseaseFrequency.fromJson(m.cast<String, dynamic>()))
            .toList(),
        houseBreakdown: ((j['houseBreakdown'] as List?) ?? const [])
            .whereType<Map>()
            .map((m) =>
                HouseHealthCount.fromJson(m.cast<String, dynamic>()))
            .toList(),
        pendingCases: ((j['pendingCases'] as List?) ?? const [])
            .whereType<Map>()
            .map((m) => PendingCase.fromJson(m.cast<String, dynamic>()))
            .toList(),
      );
}

/* =====================================================================
 * Vaccination Report
 * =================================================================== */

class VaccinationTotals {
  VaccinationTotals({
    required this.completed,
    required this.upcoming,
    required this.overdue,
    required this.coveragePct,
    required this.activeCows,
    required this.prev,
    required this.deltaPct,
  });
  final int completed;
  final int upcoming;
  final int overdue;
  final double? coveragePct;
  final int activeCows;
  final int prev;
  final double? deltaPct;

  factory VaccinationTotals.fromJson(Map<String, dynamic> j) =>
      VaccinationTotals(
        completed: _toInt(j['completed']),
        upcoming: _toInt(j['upcoming']),
        overdue: _toInt(j['overdue']),
        coveragePct: _toDoubleNullable(j['coveragePct']),
        activeCows: _toInt(j['activeCows']),
        prev: _toInt(j['prev']),
        deltaPct: _toDoubleNullable(j['deltaPct']),
      );
}

class VaccinationSchedule {
  VaccinationSchedule({
    required this.protocolId,
    required this.name,
    required this.species,
    required this.type,
    this.lastAdministeredAt,
    this.nextDueAt,
    required this.daysUntilDue,
    required this.status, // OVERDUE | DUE_SOON | OK
  });
  final String protocolId;
  final String name;
  final String? species;
  final String type;
  final DateTime? lastAdministeredAt;
  final DateTime? nextDueAt;
  final int daysUntilDue;
  final String status;

  factory VaccinationSchedule.fromJson(Map<String, dynamic> j) =>
      VaccinationSchedule(
        protocolId: (j['protocolId'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        species: j['species']?.toString(),
        type: (j['type'] ?? '').toString(),
        lastAdministeredAt: j['lastAdministeredAt'] != null
            ? DateTime.tryParse(j['lastAdministeredAt'].toString())
            : null,
        nextDueAt: j['nextDueAt'] != null
            ? DateTime.tryParse(j['nextDueAt'].toString())
            : null,
        daysUntilDue: _toInt(j['daysUntilDue']),
        status: (j['status'] ?? '').toString(),
      );
}

class RecentVaccination {
  RecentVaccination({
    required this.id,
    required this.vaccine,
    required this.animalCount,
    required this.administeredAt,
    this.notes,
  });
  final String id;
  final String vaccine;
  final int animalCount;
  final DateTime administeredAt;
  final String? notes;

  factory RecentVaccination.fromJson(Map<String, dynamic> j) =>
      RecentVaccination(
        id: (j['id'] ?? '').toString(),
        vaccine: (j['vaccine'] ?? '').toString(),
        animalCount: _toInt(j['animalCount']),
        administeredAt: _toDate(j['administeredAt']),
        notes: j['notes']?.toString(),
      );
}

class VaccinationMonthPoint {
  VaccinationMonthPoint({required this.month, required this.count});
  final String month; // yyyy-MM
  final int count;
  factory VaccinationMonthPoint.fromJson(Map<String, dynamic> j) =>
      VaccinationMonthPoint(
        month: (j['month'] ?? '').toString(),
        count: _toInt(j['count']),
      );
}

class VaccinationReport {
  VaccinationReport({
    required this.period,
    required this.totals,
    required this.schedules,
    required this.upcomingVaccinations,
    required this.recentVaccinations,
    required this.monthlyTrend,
  });
  final ReportPeriodWindow period;
  final VaccinationTotals totals;
  final List<VaccinationSchedule> schedules;
  final List<VaccinationSchedule> upcomingVaccinations;
  final List<RecentVaccination> recentVaccinations;
  final List<VaccinationMonthPoint> monthlyTrend;

  factory VaccinationReport.fromJson(Map<String, dynamic> j) =>
      VaccinationReport(
        period: ReportPeriodWindow.fromJson(
            (j['period'] as Map).cast<String, dynamic>()),
        totals: VaccinationTotals.fromJson(
            (j['totals'] as Map).cast<String, dynamic>()),
        schedules: ((j['schedules'] as List?) ?? const [])
            .whereType<Map>()
            .map((m) =>
                VaccinationSchedule.fromJson(m.cast<String, dynamic>()))
            .toList(),
        upcomingVaccinations:
            ((j['upcomingVaccinations'] as List?) ?? const [])
                .whereType<Map>()
                .map((m) =>
                    VaccinationSchedule.fromJson(m.cast<String, dynamic>()))
                .toList(),
        recentVaccinations: ((j['recentVaccinations'] as List?) ?? const [])
            .whereType<Map>()
            .map((m) =>
                RecentVaccination.fromJson(m.cast<String, dynamic>()))
            .toList(),
        monthlyTrend: ((j['monthlyTrend'] as List?) ?? const [])
            .whereType<Map>()
            .map((m) =>
                VaccinationMonthPoint.fromJson(m.cast<String, dynamic>()))
            .toList(),
      );
}
