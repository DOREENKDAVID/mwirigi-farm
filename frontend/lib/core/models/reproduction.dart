// Reproduction tracker models. The backend exposes:
//   GET    /api/reproduction              → list rows (one per cow)
//   POST   /api/reproduction              → create AI or CALVING event
//   GET    /api/reproduction/:cowId       → full per-cow history
//   PATCH  /api/reproduction/:id          → update pregnancy status
//   DELETE /api/reproduction/:id          → soft delete

enum ReproductionEventType {
  ai('AI', 'Artificial Insemination'),
  calving('CALVING', 'Calving');

  const ReproductionEventType(this.wire, this.label);
  final String wire;
  final String label;
}

enum PregnancyStatus {
  pending('PENDING', 'Pending'),
  confirmed('CONFIRMED', 'Confirmed'),
  open('OPEN', 'Open'),
  aborted('ABORTED', 'Aborted');

  const PregnancyStatus(this.wire, this.label);
  final String wire;
  final String label;

  static PregnancyStatus? fromWire(String? s) {
    if (s == null) return null;
    for (final v in values) {
      if (v.wire == s) return v;
    }
    return null;
  }
}

// One row from `GET /api/reproduction` — the table renders these directly.
class ReproductionRow {
  ReproductionRow({
    required this.cowId,
    required this.tag,
    required this.lastAiDate,
    required this.pregnancyStatus,
    required this.expectedCalvingDate,
    required this.lifetimeCalvesCount,
  });

  final String cowId;
  final String tag;
  final DateTime? lastAiDate;
  final PregnancyStatus? pregnancyStatus;
  final DateTime? expectedCalvingDate;
  final int lifetimeCalvesCount;

  factory ReproductionRow.fromJson(Map<String, dynamic> j) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      try {
        return DateTime.parse(v.toString());
      } catch (_) {
        return null;
      }
    }

    return ReproductionRow(
      cowId: (j['cowId'] ?? '').toString(),
      tag: (j['tag'] ?? '').toString(),
      lastAiDate: parseDate(j['lastAiDate']),
      pregnancyStatus: PregnancyStatus.fromWire(j['pregnancyStatus']?.toString()),
      expectedCalvingDate: parseDate(j['expectedCalvingDate']),
      lifetimeCalvesCount: (j['lifetimeCalvesCount'] as num?)?.toInt() ?? 0,
    );
  }
}
