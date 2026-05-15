// Ngushish (horticulture/irrigation/fodder) domain models.
//
// Source endpoints:
//   GET  /api/ngushish/dashboard   → NgushishKpis
//   GET  /api/ngushish/crops       → paginated CropView list
//   GET  /api/ngushish/crops/:id   → CropDetails (with harvests/dispatches/irrigation)
//   POST /api/ngushish/crops       → create crop
//   PATCH/DELETE /api/ngushish/crops/:id
//   POST /api/ngushish/harvests    → log harvest
//   POST /api/ngushish/dispatches  → log dispatch
//   POST /api/ngushish/irrigation  → log irrigation
//
// All API responses follow the {success, message, data} envelope. The
// ApiService strips the envelope before constructing these models.

import 'package:flutter/material.dart';

// Mirrors the backend Prisma enum exactly. `wire` is the JSON value sent
// over the API; `label` is the human-readable form used in the UI.
// Order matches the dialog's status dropdown (Planted first, lifecycle
// in chronological order). The fallback for unknown values is `active`
// since that's the most generic state.
enum CropStatus {
  planted('PLANTED', 'Planted', _statusGreenBg, _statusGreenFg),
  growing('GROWING', 'Growing', _statusGreenBg, _statusGreenFg),
  maturing('MATURING', 'Maturing', _statusAmberBg, _statusAmberFg),
  readySoon('READY_SOON', 'Ready soon', _statusTealBg, _statusTealFg),
  active('ACTIVE', 'Active', _statusGreenBg, _statusGreenFg),
  tasseling('TASSELING', 'Tasseling', _statusTealBg, _statusTealFg),
  ready('READY', 'Ready', _statusRedBg, _statusRedFg),
  awaiting('AWAITING', 'Awaiting', _statusAmberBg, _statusAmberFg),
  infrastructure(
      'INFRASTRUCTURE', 'Infrastructure', _statusGreyBg, _statusGreyFg),
  harvested('HARVESTED', 'Harvested', _statusGreyBg, _statusGreyFg),
  failed('FAILED', 'Failed', _statusRedBg, _statusRedFg);

  const CropStatus(this.wire, this.label, this.bg, this.fg);
  final String wire;
  final String label;
  final Color bg;
  final Color fg;

  static CropStatus fromWire(String? raw) {
    if (raw == null) return CropStatus.active;
    return CropStatus.values.firstWhere(
      (s) => s.wire == raw,
      orElse: () => CropStatus.active,
    );
  }
}

const _statusGreenBg = Color(0xFFEAF3DE);
const _statusGreenFg = Color(0xFF27500A);
const _statusTealBg = Color(0xFFD9EFEA);
const _statusTealFg = Color(0xFF0E5E50);
const _statusAmberBg = Color(0xFFFAEEDA);
const _statusAmberFg = Color(0xFF854F0B);
const _statusGreyBg = Color(0xFFEDEDED);
const _statusGreyFg = Color(0xFF555555);
const _statusRedBg = Color(0xFFFCEBEB);
const _statusRedFg = Color(0xFF501313);

// JSON coercion helpers — defensive because the backend can return
// numeric fields as either int or double depending on the column.
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

DateTime? _parseDate(dynamic v) {
  if (v == null) return null;
  try {
    return DateTime.parse(v.toString());
  } catch (_) {
    return null;
  }
}

class NgushishKpis {
  NgushishKpis({
    required this.activeCrops,
    required this.irrigatedArea,
    required this.produceDispatchedTodayKg,
    required this.revenueToday,
  });

  final int activeCrops;
  final double irrigatedArea;
  final double produceDispatchedTodayKg;
  final double revenueToday;

  factory NgushishKpis.fromJson(Map<String, dynamic> j) {
    return NgushishKpis(
      activeCrops: _toInt(j['activeCrops']),
      irrigatedArea: _toDouble(j['irrigatedArea']),
      produceDispatchedTodayKg: _toDouble(j['produceDispatchedTodayKg']),
      revenueToday: _toDouble(j['revenueToday']),
    );
  }
}

class CropView {
  CropView({
    required this.id,
    required this.name,
    required this.acreage,
    required this.status,
    required this.isPerennial,
    required this.irrigated,
    this.plantedDate,
    this.expectedHarvest,
    this.harvestFrequency,
    this.destination,
    this.irrigationType,
    this.notes,
    this.block,
    this.age,
    this.dueDate,
    this.season,
    this.actionNote,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final double acreage;
  final CropStatus status;
  final bool isPerennial;
  final bool irrigated;
  final DateTime? plantedDate;
  final DateTime? expectedHarvest;
  final String? harvestFrequency;
  final String? destination;
  final String? irrigationType;
  final String? notes;
  // Block-register fields (master template Rev 10 May 2026).
  final String? block;
  final String? age;
  final DateTime? dueDate;
  final String? season;
  final String? actionNote;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// True when the action note contains an urgency marker — used by
  /// register rows to render in red.
  bool get isUrgentAction {
    final n = (actionNote ?? '').toLowerCase();
    return n.contains('urgent') ||
        n.contains('harvest now') ||
        n.contains('in 5 days');
  }

  factory CropView.fromJson(Map<String, dynamic> j) {
    return CropView(
      id: (j['id'] ?? '').toString(),
      name: (j['name'] ?? '').toString(),
      acreage: _toDouble(j['acreage']),
      status: CropStatus.fromWire(j['status']?.toString()),
      isPerennial: j['isPerennial'] == true,
      irrigated: j['irrigated'] == true,
      plantedDate: _parseDate(j['plantedDate']),
      expectedHarvest: _parseDate(j['expectedHarvest']),
      harvestFrequency: j['harvestFrequency']?.toString(),
      destination: j['destination']?.toString(),
      irrigationType: j['irrigationType']?.toString(),
      notes: j['notes']?.toString(),
      block: j['block']?.toString(),
      age: j['age']?.toString(),
      dueDate: _parseDate(j['dueDate']),
      season: j['season']?.toString(),
      actionNote: j['actionNote']?.toString(),
      createdAt: _parseDate(j['createdAt']),
      updatedAt: _parseDate(j['updatedAt']),
    );
  }
}

class HarvestLog {
  HarvestLog({
    required this.id,
    required this.cropId,
    required this.quantityKg,
    required this.harvestDate,
    this.qualityGrade,
    this.notes,
    this.cropName,
  });

  final String id;
  final String cropId;
  final double quantityKg;
  final DateTime harvestDate;
  final String? qualityGrade;
  final String? notes;
  final String? cropName;

  factory HarvestLog.fromJson(Map<String, dynamic> j) {
    final crop = j['crop'];
    return HarvestLog(
      id: (j['id'] ?? '').toString(),
      cropId: (j['cropId'] ?? '').toString(),
      quantityKg: _toDouble(j['quantityKg']),
      harvestDate: _parseDate(j['harvestDate']) ?? DateTime.now(),
      qualityGrade: j['qualityGrade']?.toString(),
      notes: j['notes']?.toString(),
      cropName: crop is Map ? crop['name']?.toString() : null,
    );
  }
}

class DispatchLog {
  DispatchLog({
    required this.id,
    required this.cropId,
    required this.quantityKg,
    required this.destination,
    required this.revenue,
    required this.dispatchDate,
    this.buyerName,
    this.transportCost,
    this.notes,
    this.cropName,
  });

  final String id;
  final String cropId;
  final double quantityKg;
  final String destination;
  final double revenue;
  final DateTime dispatchDate;
  final String? buyerName;
  final double? transportCost;
  final String? notes;
  final String? cropName;

  factory DispatchLog.fromJson(Map<String, dynamic> j) {
    final crop = j['crop'];
    return DispatchLog(
      id: (j['id'] ?? '').toString(),
      cropId: (j['cropId'] ?? '').toString(),
      quantityKg: _toDouble(j['quantityKg']),
      destination: (j['destination'] ?? '').toString(),
      revenue: _toDouble(j['revenue']),
      dispatchDate: _parseDate(j['dispatchDate']) ?? DateTime.now(),
      buyerName: j['buyerName']?.toString(),
      transportCost:
          j['transportCost'] == null ? null : _toDouble(j['transportCost']),
      notes: j['notes']?.toString(),
      cropName: crop is Map ? crop['name']?.toString() : null,
    );
  }
}

class IrrigationLogEntry {
  IrrigationLogEntry({
    required this.id,
    required this.cropId,
    required this.irrigationDate,
    this.durationMinutes,
    this.waterSource,
    this.notes,
    this.cropName,
  });

  final String id;
  final String cropId;
  final DateTime irrigationDate;
  final int? durationMinutes;
  final String? waterSource;
  final String? notes;
  final String? cropName;

  factory IrrigationLogEntry.fromJson(Map<String, dynamic> j) {
    final crop = j['crop'];
    return IrrigationLogEntry(
      id: (j['id'] ?? '').toString(),
      cropId: (j['cropId'] ?? '').toString(),
      irrigationDate: _parseDate(j['irrigationDate']) ?? DateTime.now(),
      durationMinutes:
          j['durationMinutes'] == null ? null : _toInt(j['durationMinutes']),
      waterSource: j['waterSource']?.toString(),
      notes: j['notes']?.toString(),
      cropName: crop is Map ? crop['name']?.toString() : null,
    );
  }
}

// GET /crops/:id returns the crop with embedded relations. We keep CropView
// as the table model and add this richer wrapper for the details screen.
class CropDetails {
  CropDetails({
    required this.crop,
    required this.harvests,
    required this.dispatches,
    required this.irrigation,
  });

  final CropView crop;
  final List<HarvestLog> harvests;
  final List<DispatchLog> dispatches;
  final List<IrrigationLogEntry> irrigation;

  factory CropDetails.fromJson(Map<String, dynamic> j) {
    List<T> readList<T>(dynamic raw, T Function(Map<String, dynamic>) f) {
      if (raw is! List) return <T>[];
      return raw
          .whereType<Map>()
          .map((m) => f(m.cast<String, dynamic>()))
          .toList(growable: false);
    }

    return CropDetails(
      crop: CropView.fromJson(j),
      harvests: readList(j['harvests'], HarvestLog.fromJson),
      dispatches: readList(j['dispatches'], DispatchLog.fromJson),
      irrigation: readList(j['irrigation'], IrrigationLogEntry.fromJson),
    );
  }
}

// Returned by GET /crops alongside the items array.
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
    if (j == null) return Pagination(page: 1, limit: 20, total: 0, pages: 0);
    return Pagination(
      page: _toInt(j['page']),
      limit: _toInt(j['limit']),
      total: _toInt(j['total']),
      pages: _toInt(j['pages']),
    );
  }
}

class CropListResult {
  CropListResult({required this.items, required this.pagination});
  final List<CropView> items;
  final Pagination pagination;
}
