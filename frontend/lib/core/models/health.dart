// Models for the Health & Vaccines module.
//
// Source endpoints (all derived state is server-computed):
//   GET  /api/health/kpis                       → HealthKpis
//   GET  /api/health/vaccinations               → List<VaccinationRow>
//   GET  /api/health/treatments                 → List<TreatmentRow>
//   GET  /api/health/protocol-reference         → ProtocolReference
//   GET  /api/health/protocols                  → List<VaccineProtocol> (admin/vet)
//   POST /api/health/vaccinations               → log a record
//   PATCH /api/health/vaccinations/records/:id  → edit a record
//   POST /api/health/treatments                 → log a treatment
//   PATCH /api/health/treatments/:id            → update a treatment

int _toInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.round();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

DateTime? _parseDate(dynamic v) {
  if (v == null) return null;
  try {
    return DateTime.parse(v.toString());
  } catch (_) {
    return null;
  }
}

/// Top KPI tile triple. underTreatmentByUnit is `{ Dairy: 2, Piggery: 1 }`.
class HealthKpis {
  HealthKpis({
    required this.vaccinesDue7d,
    required this.underTreatment,
    required this.underTreatmentByUnit,
    required this.complianceRate,
  });

  final int vaccinesDue7d;
  final int underTreatment;
  final Map<String, int> underTreatmentByUnit;
  final int complianceRate;

  factory HealthKpis.fromJson(Map<String, dynamic> j) {
    final raw = (j['underTreatmentByUnit'] as Map?) ?? const {};
    final byUnit = <String, int>{};
    raw.forEach((k, v) => byUnit[k.toString()] = _toInt(v));
    return HealthKpis(
      vaccinesDue7d: _toInt(j['vaccinesDue7d']),
      underTreatment: _toInt(j['underTreatment']),
      underTreatmentByUnit: byUnit,
      complianceRate: _toInt(j['complianceRate']),
    );
  }

  /// "Dairy: 2 · Piggery: 1" — display sub-line for the Under-treatment KPI.
  String get treatmentBreakdown {
    if (underTreatmentByUnit.isEmpty) return 'No active cases';
    final entries = underTreatmentByUnit.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return entries.map((e) => '${e.key}: ${e.value}').join(' · ');
  }
}

/// One row in the unified vaccination schedule table. The backend
/// composes annual + recurring + brooder rows into this single shape.
class VaccinationRow {
  VaccinationRow({
    required this.id,
    required this.source,
    required this.vaccine,
    required this.unit,
    required this.animals,
    required this.status,
    this.protocolId,
    this.species,
    this.type,
    this.lastDone,
    this.lastDoneAt,
    this.nextDue,
    this.nextDueAt,
    this.daysUntilDue,
    this.notes,
    this.allowedMonths = const [],
    this.recurrenceMonths,
    this.lastRecordId,
    this.lastRecordNotes,
    this.lastRecordNextDue,
    this.lastRecordAdministeredBy,
  });

  final String id;
  final String source; // "DB" | "BROODER"
  final String? protocolId;
  final String vaccine;
  final String unit;
  final String? species;
  final String? type;
  final int animals;
  final String? lastDone;
  final DateTime? lastDoneAt;
  final String? nextDue;
  final DateTime? nextDueAt;
  final String status;
  final int? daysUntilDue;
  final String? notes;
  /// Months (1..12) when an ANNUAL vaccine is administered. Empty for
  /// recurring/brooder rows. Forwarded from the backend protocol — the
  /// frontend doesn't compute it.
  final List<int> allowedMonths;
  final int? recurrenceMonths;
  final String? lastRecordId;
  final String? lastRecordNotes;
  final DateTime? lastRecordNextDue;
  final String? lastRecordAdministeredBy;

  factory VaccinationRow.fromJson(Map<String, dynamic> j) {
    return VaccinationRow(
      id: (j['id'] ?? '').toString(),
      source: (j['source'] ?? 'DB').toString(),
      protocolId: j['protocolId']?.toString(),
      vaccine: (j['vaccine'] ?? '').toString(),
      unit: (j['unit'] ?? '').toString(),
      species: j['species']?.toString(),
      type: j['type']?.toString(),
      animals: _toInt(j['animals']),
      lastDone: j['lastDone']?.toString(),
      lastDoneAt: _parseDate(j['lastDoneAt']),
      nextDue: j['nextDue']?.toString(),
      nextDueAt: _parseDate(j['nextDueAt']),
      daysUntilDue:
          j['daysUntilDue'] == null ? null : _toInt(j['daysUntilDue']),
      status: (j['status'] ?? 'UPCOMING').toString(),
      notes: j['notes']?.toString(),
      allowedMonths: (j['allowedMonths'] as List? ?? const [])
          .map((e) => _toInt(e))
          .where((m) => m >= 1 && m <= 12)
          .toList(),
      recurrenceMonths: j['recurrenceMonths'] == null
          ? null
          : _toInt(j['recurrenceMonths']),
      lastRecordId: j['lastRecordId']?.toString(),
      lastRecordNotes: j['lastRecordNotes']?.toString(),
      lastRecordNextDue: _parseDate(j['lastRecordNextDue']),
      lastRecordAdministeredBy: j['lastRecordAdministeredBy']?.toString(),
    );
  }
}

/// One row in the active treatments table.
class TreatmentRow {
  TreatmentRow({
    required this.id,
    required this.tag,
    required this.unit,
    required this.diagnosis,
    required this.medication,
    required this.startDate,
    required this.status,
    required this.statusLabel,
    required this.daysUnderTreatment,
    this.endDate,
    this.attendingVet,
    this.notes,
  });

  final String id;
  final String tag;
  final String unit;
  final String diagnosis;
  final String medication;
  final DateTime startDate;
  final DateTime? endDate;
  final String status; // ACTIVE | IMPROVING | RECOVERED | CANCELLED
  final String statusLabel; // "Day 2" / "Improving"
  final int daysUnderTreatment;
  final String? attendingVet;
  final String? notes;

  factory TreatmentRow.fromJson(Map<String, dynamic> j) {
    return TreatmentRow(
      id: (j['id'] ?? '').toString(),
      tag: (j['tag'] ?? '').toString(),
      unit: (j['unit'] ?? '').toString(),
      diagnosis: (j['diagnosis'] ?? '').toString(),
      medication: (j['medication'] ?? '').toString(),
      startDate: _parseDate(j['startDate']) ?? DateTime.now(),
      endDate: _parseDate(j['endDate']),
      status: (j['status'] ?? 'ACTIVE').toString(),
      statusLabel: (j['statusLabel'] ?? '').toString(),
      daysUnderTreatment: _toInt(j['daysUnderTreatment']),
      attendingVet: j['attendingVet']?.toString(),
      notes: j['notes']?.toString(),
    );
  }
}

/// One step inside a vet protocol reference template.
class ProtocolStep {
  ProtocolStep({
    required this.id,
    required this.dayLabel,
    required this.procedure,
    this.notes,
  });

  final String id;
  final String dayLabel;
  final String procedure;
  final String? notes;

  factory ProtocolStep.fromJson(Map<String, dynamic> j) => ProtocolStep(
        id: (j['id'] ?? '').toString(),
        dayLabel: (j['dayLabel'] ?? '').toString(),
        procedure: (j['procedure'] ?? '').toString(),
        notes: j['notes']?.toString(),
      );
}

/// Vet protocol reference library — three tabs.
class ProtocolReference {
  ProtocolReference({
    required this.chicks,
    required this.calves,
    required this.piglets,
  });

  final List<ProtocolStep> chicks;
  final List<ProtocolStep> calves;
  final List<ProtocolStep> piglets;

  factory ProtocolReference.fromJson(Map<String, dynamic> j) {
    List<ProtocolStep> parse(String key) {
      final list = (j[key] as List?) ?? const [];
      return list
          .whereType<Map>()
          .map((m) => ProtocolStep.fromJson(m.cast<String, dynamic>()))
          .toList();
    }

    return ProtocolReference(
      chicks: parse('chicks'),
      calves: parse('calves'),
      piglets: parse('piglets'),
    );
  }
}

/// Editable vaccine protocol definition (used by the "Log Vaccine" modal
/// to populate the protocol dropdown).
class VaccineProtocol {
  VaccineProtocol({
    required this.id,
    required this.name,
    required this.unit,
    required this.type,
    this.species,
  });

  final String id;
  final String name;
  final String unit;
  final String type;
  final String? species;

  factory VaccineProtocol.fromJson(Map<String, dynamic> j) => VaccineProtocol(
        id: (j['id'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        unit: (j['unit'] ?? '').toString(),
        type: (j['type'] ?? '').toString(),
        species: j['species']?.toString(),
      );
}
