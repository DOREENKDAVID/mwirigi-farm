class DashboardModel {
  final int milkNet;
  final int milkTarget;
  final int eggs;
  final int eggsTarget;
  final int piggery;
  final int piggeryTarget;
  final int cows;
  final int workers;

  DashboardModel({
    required this.milkNet,
    required this.milkTarget,
    required this.eggs,
    required this.eggsTarget,
    required this.piggery,
    required this.piggeryTarget,
    required this.cows,
    required this.workers,
  });

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  factory DashboardModel.fromJson(Map<String, dynamic> json) {
    final milk =
        (json['milk'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{};
    final eggs =
        (json['eggs'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{};
    final piggery =
        (json['piggery'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{};
    final dairy =
        ((json['dairyHerd'] ?? json['dairy']) as Map?)
                ?.cast<String, dynamic>() ??
            const <String, dynamic>{};

    return DashboardModel(
      milkNet: _toInt(milk['net'] ?? json['milkNet']),
      milkTarget: _toInt(milk['target'] ?? json['milkTarget']),
      eggs: _toInt(eggs['count'] ?? eggs['total'] ?? json['eggs']),
      eggsTarget: _toInt(eggs['target'] ?? json['eggsTarget']),
      piggery: _toInt(piggery['beaconners'] ?? json['piggery']),
      piggeryTarget: _toInt(piggery['target'] ?? json['piggeryTarget']),
      cows: _toInt(dairy['totalCows'] ?? dairy['cows']),
      workers: _toInt(dairy['workers']),
    );
  }
}
