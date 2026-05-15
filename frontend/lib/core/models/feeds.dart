// Feeds Management domain models.
//
// Source endpoints (all wrap responses in {success, message, data}):
//   GET  /api/feeds/dashboard      → FeedKpis
//   GET  /api/feeds/materials      → paginated FeedMaterial list (decorated with
//                                     daysLeft / status / reorderAtKg by the API)
//   POST /api/feeds/materials      → create
//   PATCH /api/feeds/materials/:id → metadata patch
//   POST /api/feeds/deliveries     → log delivery (atomic stock bump)
//   POST /api/feeds/consumption    → log consumption (atomic dailyUse update)
//   GET/PATCH /api/feeds/bulk-feed → silage / Napier
//   GET/POST  /api/feeds/distribution → daily allocation per livestock unit
//
// Per the project convention, the backend computes status. The frontend
// trusts those values rather than re-deriving them.

import 'package:flutter/material.dart';

// Status returned from /materials. Values mirror the FEED_STATUS constants
// in the backend's feeds.utils.js.
enum FeedStatus {
  critical('CRITICAL', 'Critical', _critBg, _critFg),
  low('LOW', 'Low', _lowBg, _lowFg),
  adequate('ADEQUATE', 'Adequate', _adqBg, _adqFg);

  const FeedStatus(this.wire, this.label, this.bg, this.fg);
  final String wire;
  final String label;
  final Color bg;
  final Color fg;

  static FeedStatus fromWire(String? raw) {
    if (raw == null) return FeedStatus.adequate;
    return FeedStatus.values.firstWhere(
      (s) => s.wire == raw,
      orElse: () => FeedStatus.adequate,
    );
  }
}

const _critBg = Color(0xFFFCEBEB);
const _critFg = Color(0xFFB42318);
const _lowBg = Color(0xFFFAEEDA);
const _lowFg = Color(0xFF854F0B);
const _adqBg = Color(0xFFEAF3DE);
const _adqFg = Color(0xFF27500A);

// Mirrors backend BulkFeedStatus enum.
enum BulkFeedStatus {
  active('ACTIVE', 'Active', _adqBg, _adqFg),
  replenishSoon('REPLENISH_SOON', 'Replenish soon', _critBg, _critFg),
  maturing('MATURING', 'Maturing', _matBg, _matFg),
  depleted('DEPLETED', 'Depleted', _depBg, _depFg);

  const BulkFeedStatus(this.wire, this.label, this.bg, this.fg);
  final String wire;
  final String label;
  final Color bg;
  final Color fg;

  static BulkFeedStatus fromWire(String? raw) {
    if (raw == null) return BulkFeedStatus.active;
    return BulkFeedStatus.values.firstWhere(
      (s) => s.wire == raw,
      orElse: () => BulkFeedStatus.active,
    );
  }
}

const _matBg = Color(0xFFD9EFEA);
const _matFg = Color(0xFF0E5E50);
const _depBg = Color(0xFFEDEDED);
const _depFg = Color(0xFF555555);

// JSON coercion helpers — backend returns numbers as either int or double
// depending on column.
int _toInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.round();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

double _toDouble(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}

double? _toDoubleNullable(dynamic v) {
  if (v == null) return null;
  return _toDouble(v);
}

DateTime? _parseDate(dynamic v) {
  if (v == null) return null;
  try {
    return DateTime.parse(v.toString());
  } catch (_) {
    return null;
  }
}

class FeedKpis {
  FeedKpis({
    required this.materialsTracked,
    required this.critical,
    required this.low,
    required this.adequate,
  });

  final int materialsTracked;
  final int critical;
  final int low;
  final int adequate;

  factory FeedKpis.fromJson(Map<String, dynamic> j) => FeedKpis(
        materialsTracked: _toInt(j['materialsTracked']),
        critical: _toInt(j['critical']),
        low: _toInt(j['low']),
        adequate: _toInt(j['adequate']),
      );
}

class FeedMaterial {
  FeedMaterial({
    required this.id,
    required this.name,
    required this.category,
    required this.packSize,
    required this.stockOnHandKg,
    required this.dailyUseKg,
    required this.reorderLevelDays,
    required this.reorderAtKg,
    required this.status,
    this.daysLeft,
    this.supplier,
    this.costPerKg,
  });

  final String id;
  final String name;
  final String category;
  final String packSize;
  final double stockOnHandKg;
  final double dailyUseKg;
  final int reorderLevelDays;
  final double reorderAtKg;
  final FeedStatus status;
  final double? daysLeft; // null when dailyUseKg == 0
  final String? supplier;
  final double? costPerKg;

  factory FeedMaterial.fromJson(Map<String, dynamic> j) => FeedMaterial(
        id: (j['id'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        category: (j['category'] ?? '').toString(),
        packSize: (j['packSize'] ?? '').toString(),
        stockOnHandKg: _toDouble(j['stockOnHandKg']),
        dailyUseKg: _toDouble(j['dailyUseKg']),
        reorderLevelDays: _toInt(j['reorderLevelDays']),
        reorderAtKg: _toDouble(j['reorderAtKg']),
        status: FeedStatus.fromWire(j['status']?.toString()),
        daysLeft: _toDoubleNullable(j['daysLeft']),
        supplier: j['supplier']?.toString(),
        costPerKg: _toDoubleNullable(j['costPerKg']),
      );
}

class BulkFeed {
  BulkFeed({
    required this.id,
    required this.type,
    required this.quantity,
    required this.unit,
    required this.status,
    this.notes,
    this.updatedAt,
  });

  final String id;
  final String type; // SILAGE | NAPIER | MAIZE_SILAGE
  final double quantity;
  final String unit; // PERCENT | ACRES | TONNES
  final BulkFeedStatus status;
  final String? notes;
  final DateTime? updatedAt;

  // Display-friendly type label.
  String get typeLabel {
    switch (type) {
      case 'SILAGE':
        return 'Silage pit level';
      case 'NAPIER':
        return 'Napier (standing)';
      case 'MAIZE_SILAGE':
        return 'Maize for silage';
      default:
        return type;
    }
  }

  // "18% full" / "4.0 acres" / "12.5 tonnes" — matches the HTML mockup.
  String get stockDisplay {
    final n = quantity == quantity.roundToDouble()
        ? quantity.toStringAsFixed(quantity == 0 ? 0 : 1)
        : quantity.toStringAsFixed(2);
    switch (unit) {
      case 'PERCENT':
        return '$n% full';
      case 'ACRES':
        return '$n acres';
      case 'TONNES':
        return '$n tonnes';
      default:
        return '$n $unit';
    }
  }

  factory BulkFeed.fromJson(Map<String, dynamic> j) => BulkFeed(
        id: (j['id'] ?? '').toString(),
        type: (j['type'] ?? '').toString(),
        quantity: _toDouble(j['quantity']),
        unit: (j['unit'] ?? '').toString(),
        status: BulkFeedStatus.fromWire(j['status']?.toString()),
        notes: j['notes']?.toString(),
        updatedAt: _parseDate(j['updatedAt']),
      );
}

class FeedDistribution {
  FeedDistribution({
    required this.id,
    required this.livestockUnit,
    required this.concentrateKg,
    required this.silageKg,
    required this.napierKg,
    required this.animalCount,
    this.recordedAt,
  });

  final String id;
  final String livestockUnit;
  final double concentrateKg;
  final double silageKg;
  final double napierKg;
  final int animalCount;
  final DateTime? recordedAt;

  // Human-readable unit label with animal count, e.g. "Dairy (42 milking)".
  String get unitLabel {
    switch (livestockUnit) {
      case 'DAIRY':
        return 'Dairy ($animalCount milking)';
      case 'CALVES':
        return 'Calves & heifers';
      case 'HEIFERS':
        return 'Heifers ($animalCount)';
      case 'DOOPERS':
        return 'Doopers ($animalCount)';
      case 'FEEDLOT':
        return 'Feedlot ($animalCount bulls)';
      case 'PIGGERY':
        return 'Piggery ($animalCount)';
      case 'LAYERS':
        return 'Layers (~$animalCount)';
      case 'BROODER':
        return 'Brooder ($animalCount)';
      default:
        return livestockUnit;
    }
  }

  factory FeedDistribution.fromJson(Map<String, dynamic> j) => FeedDistribution(
        id: (j['id'] ?? '').toString(),
        livestockUnit: (j['livestockUnit'] ?? '').toString(),
        concentrateKg: _toDouble(j['concentrateKg']),
        silageKg: _toDouble(j['silageKg']),
        napierKg: _toDouble(j['napierKg']),
        animalCount: _toInt(j['animalCount']),
        recordedAt: _parseDate(j['recordedAt']),
      );
}

class Pagination {
  Pagination({
    required this.page,
    required this.limit,
    required this.total,
    required this.pages,
  });
  final int page;
  final int limit;
  final int total;
  final int pages;

  factory Pagination.fromJson(Map<String, dynamic>? j) {
    if (j == null) return Pagination(page: 1, limit: 50, total: 0, pages: 0);
    return Pagination(
      page: _toInt(j['page']),
      limit: _toInt(j['limit']),
      total: _toInt(j['total']),
      pages: _toInt(j['pages']),
    );
  }
}

class FeedMaterialListResult {
  FeedMaterialListResult({required this.items, required this.pagination});
  final List<FeedMaterial> items;
  final Pagination pagination;
}
