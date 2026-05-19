// Farmers Choice (FC) dispatch log entry. Mirrors the
// FarmersChoiceDelivery row on the backend.

int _toInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.round();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

class FcDelivery {
  FcDelivery({
    required this.id,
    required this.date,
    required this.ref,
    required this.pens,
    required this.count,
    required this.category,
    required this.driver,
    this.ageRange,
    this.notes,
    this.revenueId,
  });

  final String id;
  final DateTime date;
  final String ref;
  final String pens;
  final int count;
  final String category;   // Beaconners | Fatteners | Winners | Mixed
  final String? ageRange;  // e.g. "5-6mo"
  final String driver;
  final String? notes;
  final String? revenueId; // present when the save also created a Revenue row

  bool get hasRevenue => revenueId != null;

  factory FcDelivery.fromJson(Map<String, dynamic> j) => FcDelivery(
        id: (j['id'] ?? '').toString(),
        date: DateTime.tryParse((j['date'] ?? '').toString()) ?? DateTime.now(),
        ref: (j['ref'] ?? '').toString(),
        pens: (j['pens'] ?? '').toString(),
        count: _toInt(j['count']),
        category: (j['category'] ?? '').toString(),
        ageRange: j['ageRange']?.toString(),
        driver: (j['driver'] ?? '').toString(),
        notes: j['notes']?.toString(),
        revenueId: j['revenueId']?.toString(),
      );
}
