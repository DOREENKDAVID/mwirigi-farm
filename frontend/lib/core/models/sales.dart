// Models for the Sales module.
//
// Source endpoints:
//   GET    /api/sales            → SaleList (total + rows)
//   POST   /api/sales            → ProductSale
//   PATCH  /api/sales/:id        → ProductSale
//   DELETE /api/sales/:id        → 204
//   GET    /api/sales/summary    → SalesTodaySummary

num _toNum(dynamic v) {
  if (v is num) return v;
  if (v is String) return num.tryParse(v) ?? 0;
  return 0;
}

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

/// One sale transaction row.
class ProductSale {
  ProductSale({
    required this.id,
    required this.module,
    required this.saleDate,
    required this.quantity,
    required this.unitLabel,
    required this.buyerType,
    required this.buyerName,
    required this.paymentMode,
    this.paymentReference,
    required this.amountPaid,
    this.notes,
    this.createdByName,
    required this.createdAt,
  });

  final String id;
  final String module;      // 'DAIRY' | 'LAYERS'
  final DateTime saleDate;
  final num quantity;
  final String unitLabel;   // 'crates' | 'L'
  final String buyerType;
  final String buyerName;
  final String paymentMode;
  final String? paymentReference;
  final num amountPaid;
  final String? notes;
  final String? createdByName;
  final DateTime createdAt;

  factory ProductSale.fromJson(Map<String, dynamic> j) {
    final createdBy = j['createdBy'];
    return ProductSale(
      id: (j['id'] ?? '').toString(),
      module: (j['module'] ?? 'LAYERS').toString(),
      saleDate: _parseDate(j['saleDate']) ?? DateTime.now(),
      quantity: _toNum(j['quantity']),
      unitLabel: (j['unitLabel'] ?? '').toString(),
      buyerType: (j['buyerType'] ?? 'OTHER').toString(),
      buyerName: (j['buyerName'] ?? '').toString(),
      paymentMode: (j['paymentMode'] ?? 'CASH').toString(),
      paymentReference: j['paymentReference']?.toString(),
      amountPaid: _toNum(j['amountPaid']),
      notes: j['notes']?.toString(),
      createdByName: createdBy is Map ? createdBy['userName']?.toString() : null,
      createdAt: _parseDate(j['createdAt']) ?? DateTime.now(),
    );
  }
}

/// Paginated response from GET /api/sales.
class SaleList {
  SaleList({required this.total, required this.rows});
  final int total;
  final List<ProductSale> rows;

  factory SaleList.fromJson(Map<String, dynamic> j) {
    return SaleList(
      total: _toInt(j['total']),
      rows: (j['rows'] as List? ?? [])
          .whereType<Map>()
          .map((m) => ProductSale.fromJson(m.cast<String, dynamic>()))
          .toList(),
    );
  }
}

/// Quick summary of today's sales for a given module.
class SalesTodaySummary {
  SalesTodaySummary({
    required this.count,
    required this.totalQuantity,
    required this.totalRevenue,
  });

  final int count;
  final num totalQuantity;
  final num totalRevenue;

  factory SalesTodaySummary.fromJson(Map<String, dynamic> j) {
    return SalesTodaySummary(
      count: _toInt(j['count']),
      totalQuantity: _toNum(j['totalQuantity']),
      totalRevenue: _toNum(j['totalRevenue']),
    );
  }
}

// ── display helpers ───────────────────────────────────────────────────────

String buyerTypeLabel(String t) {
  const labels = {
    'SCHOOL': 'School',
    'INDIVIDUAL': 'Individual',
    'ORGANIZATION': 'Organization',
    'HOTEL': 'Hotel',
    'DISTRIBUTOR': 'Distributor',
    'OTHER': 'Other',
  };
  return labels[t] ?? t;
}

String paymentModeLabel(String m) {
  const labels = {
    'CASH': 'Cash',
    'MPESA': 'M-Pesa',
    'BANK_TRANSFER': 'Bank Transfer',
    'CREDIT': 'Credit',
    'CHEQUE': 'Cheque',
    'CARD': 'Card',
  };
  return labels[m] ?? m;
}
