// Cow domain model + the two backend enums that go with it.
//
// `wire` is the SCREAMING_SNAKE_CASE value the backend stores and exchanges.
// `label` is the human-friendly text shown in dropdowns and tables, matching
// the HTML mockup ("Dry off", "Crossbreed", etc).

enum Breed {
  friesian('FRIESIAN', 'Friesian'),
  ayrshire('AYRSHIRE', 'Ayrshire'),
  jersey('JERSEY', 'Jersey'),
  brownSwiss('BROWN_SWISS', 'Brown Swiss'),
  sahiwal('SAHIWAL', 'Sahiwal'),
  boran('BORAN', 'Boran'),
  zebu('ZEBU', 'Zebu'),
  crossbreed('CROSSBREED', 'Crossbreed');

  const Breed(this.wire, this.label);
  final String wire;
  final String label;

  static Breed? fromWire(String? s) {
    if (s == null) return null;
    for (final v in values) {
      if (v.wire == s) return v;
    }
    return null;
  }
}

enum CowStatus {
  // The order here drives the dropdown order. Matches the v4.1 HTML
  // mockup: Milking → Dry → Pregnant → Heifer → Open → Sick.
  milking('MILKING', 'M — Milking'),
  dryOff('DRY_OFF', 'D — Dry'),
  pregnant('PREGNANT', 'P — Pregnant'),
  heifer('HEIFER', 'H — Heifer'),
  open('OPEN', 'O — Open (not yet confirmed)'),
  sick('SICK', 'S — Sick'); // Vet-set; usually transitioned via "Report sick".

  const CowStatus(this.wire, this.label);
  final String wire;
  final String label;

  static CowStatus? fromWire(String? s) {
    if (s == null) return null;
    for (final v in values) {
      if (v.wire == s) return v;
    }
    return null;
  }
}

/// Breed origin classifier per the cattle registry — F (Foreign /
/// Exotic), L (Local), X (Crossbreed / Grade). Stored as a single-
/// character string on the Cow model (`breedOrigin`).
enum BreedOrigin {
  exotic('F', 'F — Exotic / Foreign'),
  local('L', 'L — Local breed'),
  cross('X', 'X — Crossbreed / Grade');

  const BreedOrigin(this.wire, this.label);
  final String wire;
  final String label;

  static BreedOrigin? fromWire(String? s) {
    if (s == null) return null;
    for (final v in values) {
      if (v.wire == s) return v;
    }
    return null;
  }
}

class Cow {
  Cow({
    required this.id,
    required this.tag,
    required this.breed,
    required this.dateOfBirth,
    required this.status,
    required this.todayLitres,
    required this.weekAvg,
    this.calvesLifetime = 0,
    this.statusReason,
    this.nickname,
    this.imageUrl,
    this.breedOrigin,
    this.lactationNumber,
    this.weightKg,
    this.colorMarkings,
    this.acquisitionDate,
    this.acquisitionType,
    this.motherTag,
    this.fatherTag,
    this.healthNotes,
    this.workerId,
    this.workerName,
    this.houseId,
    this.houseName,
  });

  final String id;
  final String tag;
  final Breed breed;
  final DateTime dateOfBirth;
  final CowStatus status;
  final String? statusReason;
  final num todayLitres;
  final num weekAvg;
  final int calvesLifetime;

  // Extended Register Cow fields. All optional; UI shows fallbacks
  // (🐄 emoji thumbnail, em-dash, etc.) when null.
  final String? nickname;
  final String? imageUrl;
  /// 'F' / 'L' / 'X' — see BreedOrigin enum.
  final String? breedOrigin;
  final int? lactationNumber;
  final num? weightKg;
  final String? colorMarkings;
  final DateTime? acquisitionDate;
  final String? acquisitionType;
  final String? motherTag;
  final String? fatherTag;
  final String? healthNotes;

  // Worker + house relations come back inlined from /api/dairy/cows.
  final String? workerId;
  final String? workerName;
  final String? houseId;
  final String? houseName;

  factory Cow.fromJson(Map<String, dynamic> j) {
    final worker = j['worker'];
    final house = j['house'];
    return Cow(
      id: (j['id'] ?? '').toString(),
      tag: (j['tag'] ?? '').toString(),
      breed: Breed.fromWire(j['breed']?.toString()) ?? Breed.crossbreed,
      dateOfBirth: DateTime.parse(j['dateOfBirth'].toString()),
      status: CowStatus.fromWire(j['status']?.toString()) ?? CowStatus.milking,
      statusReason: _toStr(j['statusReason']),
      todayLitres: _toNum(j['todayLitres']),
      weekAvg: _toNum(j['weekAvg']),
      calvesLifetime: _toInt(j['calvesLifetime']),
      nickname: _toStr(j['nickname']),
      imageUrl: _toStr(j['imageUrl']),
      breedOrigin: _toStr(j['breedOrigin']),
      lactationNumber:
          j['lactationNumber'] == null ? null : _toInt(j['lactationNumber']),
      weightKg: j['weightKg'] == null ? null : _toNum(j['weightKg']),
      colorMarkings: _toStr(j['colorMarkings']),
      acquisitionDate: _toDate(j['acquisitionDate']),
      acquisitionType: _toStr(j['acquisitionType']),
      motherTag: _toStr(j['motherTag']),
      fatherTag: _toStr(j['fatherTag']),
      healthNotes: _toStr(j['healthNotes']),
      workerId: worker is Map ? worker['id']?.toString() : null,
      workerName: worker is Map ? worker['name']?.toString() : null,
      houseId: house is Map ? house['id']?.toString() : null,
      houseName: house is Map ? house['name']?.toString() : null,
    );
  }

  static num _toNum(dynamic v) {
    if (v is num) return v;
    if (v is String) return num.tryParse(v) ?? 0;
    return 0;
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.round();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  static String? _toStr(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  static DateTime? _toDate(dynamic v) {
    if (v == null) return null;
    try {
      return DateTime.parse(v.toString());
    } catch (_) {
      return null;
    }
  }
}
