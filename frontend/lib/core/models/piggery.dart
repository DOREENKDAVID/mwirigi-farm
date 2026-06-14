// Piggery domain models.

enum PigStatus {
  lactating('LACTATING', 'Nursing'),
  gestating('GESTATING', 'Gestation'),
  farrowingSoon('FARROWING_SOON', 'Farrowing soon'),
  weaned('WEANED', 'Weaned'),
  dry('DRY', 'Dry'),
  service('SERVICE', 'Servicing');

  const PigStatus(this.wire, this.label);
  final String wire;
  final String label;

  static PigStatus? fromWire(String? s) {
    if (s == null) return null;
    for (final v in values) {
      if (v.wire == s) return v;
    }
    return null;
  }
}

int _toInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.round();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

num _toNum(dynamic v) {
  if (v is num) return v;
  if (v is String) return num.tryParse(v) ?? 0;
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

String? _str(dynamic v) {
  if (v == null) return null;
  final s = v.toString();
  return s.isEmpty ? null : s;
}

class PiggeryKpis {
  PiggeryKpis({
    required this.totalPigs,
    required this.totalSows,
    required this.totalBoars,
    required this.pigletsMTD,
    required this.farrowingDue,
    required this.activeLitters,
    required this.pigletsOnMilk,
    required this.saleReady,
    required this.monthlyBeaconners,
    required this.totalHead,
  });

  final int totalPigs;
  final int totalSows;
  final int totalBoars;
  final int pigletsMTD;
  final int farrowingDue;
  final int activeLitters;
  final int pigletsOnMilk;
  final int saleReady;
  final int monthlyBeaconners;
  final int totalHead;

  factory PiggeryKpis.fromJson(Map<String, dynamic> j) {
    return PiggeryKpis(
      totalPigs: _toInt(j['totalPigs']),
      totalSows: _toInt(j['totalSows']),
      totalBoars: _toInt(j['totalBoars']),
      pigletsMTD: _toInt(j['pigletsMTD']),
      farrowingDue: _toInt(j['farrowingDue']),
      activeLitters: _toInt(j['activeLitters']),
      pigletsOnMilk: _toInt(j['pigletsOnMilk']),
      saleReady: _toInt(j['saleReady']),
      monthlyBeaconners: _toInt(j['monthlyBeaconners']),
      totalHead: _toInt(j['totalHead']),
    );
  }
}

class PigHouse {
  PigHouse({
    required this.code,
    required this.label,
    required this.role,
    required this.manager,
    required this.pens,
    required this.count,
    required this.subline,
    required this.sows,
    required this.boars,
    required this.litters,
    required this.piglets,
  });

  final String code;
  final String label;
  final String role;
  final String manager;
  final int pens;
  final int count;
  final String subline;
  final int sows;
  final int boars;
  final int litters;
  final int piglets;

  factory PigHouse.fromJson(Map<String, dynamic> j) {
    return PigHouse(
      code: (j['code'] ?? '').toString(),
      label: (j['label'] ?? '').toString(),
      role: (j['role'] ?? '').toString(),
      manager: (j['manager'] ?? '').toString(),
      pens: _toInt(j['pens']),
      count: _toInt(j['count']),
      subline: (j['subline'] ?? '').toString(),
      sows: _toInt(j['sows']),
      boars: _toInt(j['boars']),
      litters: _toInt(j['litters']),
      piglets: _toInt(j['piglets']),
    );
  }
}

class Sow {
  Sow({
    required this.id,
    required this.tag,
    required this.status,
    required this.litterCount,
    this.house,
    this.pen,
    this.lastFarrowed,
    this.dueDate,
    this.serviceDate,
    this.expFarrow,
    this.note,
    this.litterId,
    this.pigletCount,
    this.born,
    this.releasedAt,
    this.releaseReason,
  });

  final String id;
  final String tag;
  final PigStatus? status;
  final int litterCount;
  final String? house;
  final String? pen;
  final DateTime? lastFarrowed;
  final DateTime? dueDate;
  final DateTime? serviceDate;
  final DateTime? expFarrow;
  final String? note;
  final String? litterId;
  final int? pigletCount;
  final DateTime? born;
  final DateTime? releasedAt;
  final String? releaseReason;

  factory Sow.fromJson(Map<String, dynamic> j) {
    return Sow(
      id: (j['id'] ?? '').toString(),
      tag: (j['tag'] ?? '').toString(),
      status: PigStatus.fromWire(j['status']?.toString()),
      litterCount: _toInt(j['litterCount']),
      house: _str(j['house']),
      pen: _str(j['pen']),
      lastFarrowed: _parseDate(j['lastFarrowed']),
      dueDate: _parseDate(j['dueDate']),
      serviceDate: _parseDate(j['serviceDate']),
      expFarrow: _parseDate(j['expFarrow']),
      note: _str(j['note']),
      litterId: _str(j['litterId']),
      pigletCount: j['pigletCount'] == null ? null : _toInt(j['pigletCount']),
      born: _parseDate(j['born']),
      releasedAt: _parseDate(j['releasedAt']),
      releaseReason: _str(j['releaseReason']),
    );
  }
}

class Boar {
  Boar({
    required this.id,
    required this.tag,
    this.house,
    this.pen,
    this.breed,
    this.age,
    this.role,
    this.releasedAt,
    this.releaseReason,
    this.servicedSowId,
    this.servicedSowTag,
  });

  final String id;
  final String tag;
  final String? house;
  final String? pen;
  final String? breed;
  final String? age;
  final String? role;
  final DateTime? releasedAt;
  final String? releaseReason;
  final String? servicedSowId;
  final String? servicedSowTag;

  factory Boar.fromJson(Map<String, dynamic> j) {
    final sowMap = j['servicedSow'];
    return Boar(
      id: (j['id'] ?? '').toString(),
      tag: (j['tag'] ?? '').toString(),
      house: _str(j['house']),
      pen: _str(j['pen']),
      breed: _str(j['breed']),
      age: _str(j['age']),
      role: _str(j['role']),
      releasedAt: _parseDate(j['releasedAt']),
      releaseReason: _str(j['releaseReason']),
      servicedSowId: _str(j['servicedSowId']),
      servicedSowTag: sowMap is Map ? _str(sowMap['tag']) : null,
    );
  }
}

class Litter {
  Litter({
    required this.id,
    required this.litterId,
    required this.count,
    this.born,
    this.note,
    this.sowId,
    this.sowTag,
    this.pen,
    this.house,
  });

  final String id;
  final String litterId;
  final int count;
  final DateTime? born;
  final String? note;
  final String? sowId;
  final String? sowTag;
  final String? pen;
  final String? house;

  factory Litter.fromJson(Map<String, dynamic> j) {
    return Litter(
      id: (j['id'] ?? '').toString(),
      litterId: (j['litterId'] ?? '').toString(),
      count: _toInt(j['count']),
      born: _parseDate(j['born']),
      note: _str(j['note']),
      sowId: _str(j['sowId']),
      sowTag: _str(j['sowTag']),
      pen: _str(j['pen']),
      house: _str(j['house']),
    );
  }
}

class NurseryGroup {
  NurseryGroup({
    required this.id,
    required this.pen,
    required this.count,
    this.age,
    this.born,
    this.breed,
    this.note,
  });

  final String id;
  final String pen;
  final int count;
  final String? age;
  final DateTime? born;
  final String? breed;
  final String? note;

  factory NurseryGroup.fromJson(Map<String, dynamic> j) {
    return NurseryGroup(
      id: (j['id'] ?? '').toString(),
      pen: (j['pen'] ?? '').toString(),
      count: _toInt(j['count']),
      age: _str(j['age']),
      born: _parseDate(j['born']),
      breed: _str(j['breed']),
      note: _str(j['note']),
    );
  }
}

class FattenPen {
  FattenPen({
    required this.id,
    required this.pen,
    required this.house,
    required this.count,
    this.age,
    required this.saleReady,
    this.saleWindow,
    this.totalWeight,
    this.deadWeightDeduction,
    this.finalWeight,
    this.releasedAt,
    this.releaseDestination,
    this.releaseNotes,
    this.revenueId,
    this.pendingReleaseId,
  });

  final String id;
  final String pen;
  final String house;
  final int count;
  final String? age;
  final bool saleReady;
  final String? saleWindow;
  final double? totalWeight;
  final double? deadWeightDeduction;
  final double? finalWeight;
  final DateTime? releasedAt;
  final String? releaseDestination;
  final String? releaseNotes;
  final String? revenueId;
  final String? pendingReleaseId;

  bool get isReleased        => releasedAt != null;
  bool get isPendingRelease  => pendingReleaseId != null && releasedAt == null;

  factory FattenPen.fromJson(Map<String, dynamic> j) {
    return FattenPen(
      id: (j['id'] ?? '').toString(),
      pen: (j['pen'] ?? '').toString(),
      house: (j['house'] ?? '').toString(),
      count: _toInt(j['count']),
      age: _str(j['age']),
      saleReady: j['saleReady'] == true,
      saleWindow: _str(j['saleWindow']),
      totalWeight: j['totalWeight'] == null ? null : _toNum(j['totalWeight']).toDouble(),
      deadWeightDeduction: j['deadWeightDeduction'] == null ? null : _toNum(j['deadWeightDeduction']).toDouble(),
      finalWeight: j['finalWeight'] == null ? null : _toNum(j['finalWeight']).toDouble(),
      releasedAt: _parseDate(j['releasedAt']),
      releaseDestination: _str(j['releaseDestination']),
      releaseNotes: _str(j['releaseNotes']),
      revenueId: _str(j['revenueId']),
      pendingReleaseId: _str(j['pendingReleaseId']),
    );
  }
}

// ── Approval workflow models ─────────────────────────────────────────

class PenReleaseRequest {
  PenReleaseRequest({
    required this.id,
    required this.penId,
    required this.penLabel,
    required this.house,
    required this.count,
    required this.category,
    required this.status,
    required this.requestedAt,
    this.ageRange,
    this.approvedAt,
    this.rejectedAt,
    this.rejectionNotes,
    this.pendingDispatchId,
  });

  final String   id;
  final String   penId;
  final String   penLabel;
  final String   house;
  final int      count;
  final String   category;
  final String?  ageRange;
  final String   status; // PENDING | APPROVED | REJECTED | DISPATCHED
  final DateTime requestedAt;
  final DateTime? approvedAt;
  final DateTime? rejectedAt;
  final String?  rejectionNotes;
  final String?  pendingDispatchId;

  factory PenReleaseRequest.fromJson(Map<String, dynamic> j) => PenReleaseRequest(
    id:                (j['id'] ?? '').toString(),
    penId:             (j['penId'] ?? '').toString(),
    penLabel:          (j['penLabel'] ?? j['pen'] ?? '').toString(),
    house:             (j['house'] ?? '').toString(),
    count:             _toInt(j['count']),
    category:          (j['category'] ?? 'Beaconners').toString(),
    ageRange:          _str(j['ageRange']),
    status:            (j['status'] ?? 'PENDING').toString(),
    requestedAt:       _parseDate(j['requestedAt']) ?? DateTime.now(),
    approvedAt:        _parseDate(j['approvedAt']),
    rejectedAt:        _parseDate(j['rejectedAt']),
    rejectionNotes:    _str(j['rejectionNotes']),
    pendingDispatchId: _str(j['pendingDispatchId']),
  );
}

class PendingDispatchBatch {
  PendingDispatchBatch({
    required this.id,
    required this.category,
    required this.status,
    required this.createdAt,
    required this.pens,
    required this.totalCount,
    required this.requestIds,
    this.ageRange,
  });

  final String   id;
  final String   category;
  final String?  ageRange;
  final String   status;
  final DateTime createdAt;
  final List<String> pens;
  final int          totalCount;
  final List<String> requestIds;

  factory PendingDispatchBatch.fromJson(Map<String, dynamic> j) => PendingDispatchBatch(
    id:         (j['id'] ?? '').toString(),
    category:   (j['category'] ?? '').toString(),
    ageRange:   _str(j['ageRange']),
    status:     (j['status'] ?? 'ACCUMULATING').toString(),
    createdAt:  _parseDate(j['createdAt']) ?? DateTime.now(),
    pens:       (j['pens'] as List? ?? []).map((e) => e.toString()).toList(),
    totalCount: _toInt(j['totalCount']),
    requestIds: (j['requestIds'] as List? ?? []).map((e) => e.toString()).toList(),
  );
}

class DispatchLogEntry {
  DispatchLogEntry({
    required this.id,
    required this.date,
    required this.pens,
    required this.count,
    required this.category,
    required this.destination,
    this.ref,
    this.ageRange,
    this.driver,
    this.amount,
    this.notes,
    this.revenueId,
  });

  final String  id;
  final DateTime date;
  final String? ref;
  final String  pens;
  final int     count;
  final String  category;
  final String? ageRange;
  final String? driver;
  final double? amount;
  final String? notes;
  final String  destination;
  final String? revenueId;

  bool get hasRevenue => revenueId != null;

  factory DispatchLogEntry.fromJson(Map<String, dynamic> j) => DispatchLogEntry(
    id:          (j['id'] ?? '').toString(),
    date:        _parseDate(j['date']) ?? DateTime.now(),
    ref:         _str(j['ref']),
    pens:        (j['pens'] ?? '').toString(),
    count:       _toInt(j['count']),
    category:    (j['category'] ?? '').toString(),
    ageRange:    _str(j['ageRange']),
    driver:      _str(j['driver']),
    amount:      j['amount'] == null ? null : _toNum(j['amount']).toDouble(),
    notes:       _str(j['notes']),
    destination: (j['destination'] ?? 'FARMERS_CHOICE').toString(),
    revenueId:   _str(j['revenueId']),
  );
}

class FarrowingRecordView {
  FarrowingRecordView({
    required this.id,
    required this.date,
    this.service,
    required this.pigletsBorn,
    required this.pigletsAlive,
    required this.pigletsDead,
    this.winners,
    this.fatteners,
    this.beaconners,
    this.remarks,
    this.sowId,
    this.sowTag,
  });

  final String id;
  final DateTime date;
  final DateTime? service;
  final int pigletsBorn;
  final int pigletsAlive;
  final int pigletsDead;
  final int? winners;
  final int? fatteners;
  final int? beaconners;
  final String? remarks;
  final String? sowId;
  final String? sowTag;

  factory FarrowingRecordView.fromJson(Map<String, dynamic> j) {
    return FarrowingRecordView(
      id: (j['id'] ?? '').toString(),
      date: _parseDate(j['date']) ?? DateTime.now(),
      service: _parseDate(j['service']),
      pigletsBorn: _toInt(j['pigletsBorn']),
      pigletsAlive: _toInt(j['pigletsAlive']),
      pigletsDead: _toInt(j['pigletsDead']),
      winners: j['winners'] == null ? null : _toInt(j['winners']),
      fatteners: j['fatteners'] == null ? null : _toInt(j['fatteners']),
      beaconners: j['beaconners'] == null ? null : _toInt(j['beaconners']),
      remarks: _str(j['remarks']),
      sowId: _str(j['sowId']),
      sowTag: _str(j['sowTag']),
    );
  }
}

class MonthlyPigletPoint {
  MonthlyPigletPoint({
    required this.month,
    required this.piglets,
    required this.beaconners,
  });

  final String month;
  final int piglets;
  final int beaconners;

  DateTime? get monthDate {
    final parts = month.split('-');
    if (parts.length != 2) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (y == null || m == null) return null;
    return DateTime(y, m);
  }

  factory MonthlyPigletPoint.fromJson(Map<String, dynamic> j) {
    return MonthlyPigletPoint(
      month: (j['month'] ?? '').toString(),
      piglets: _toInt(j['piglets']),
      beaconners: _toInt(j['beaconners']),
    );
  }
}

// Unused but kept around so widget code can reference `_toNum` if needed.
// ignore: unused_element
num _kept(dynamic v) => _toNum(v);
