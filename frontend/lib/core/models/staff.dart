// Staff & Labour models. Mirrors GET /api/staff/dashboard plus per-resource
// shapes from the staff module endpoints.

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

enum AttendanceStatus {
  present('PRESENT', 'Present'),
  absent('ABSENT', 'Absent'),
  halfDay('HALF_DAY', 'Half day'),
  off('OFF', 'Off');

  const AttendanceStatus(this.wire, this.label);
  final String wire;
  final String label;

  static AttendanceStatus fromWire(String? s) {
    for (final v in values) {
      if (v.wire == s) return v;
    }
    return AttendanceStatus.absent;
  }
}

enum TaskPriority {
  low('LOW', 'Low'),
  medium('MEDIUM', 'Medium'),
  high('HIGH', 'High');

  const TaskPriority(this.wire, this.label);
  final String wire;
  final String label;

  static TaskPriority fromWire(String? s) {
    for (final v in values) {
      if (v.wire == s) return v;
    }
    return TaskPriority.medium;
  }
}

enum TaskStatus {
  pending('PENDING', 'Pending'),
  inProgress('IN_PROGRESS', 'In progress'),
  done('DONE', 'Done');

  const TaskStatus(this.wire, this.label);
  final String wire;
  final String label;

  static TaskStatus fromWire(String? s) {
    for (final v in values) {
      if (v.wire == s) return v;
    }
    return TaskStatus.pending;
  }
}

enum EmploymentStatus {
  active('ACTIVE', 'Active'),
  released('RELEASED', 'Released');

  const EmploymentStatus(this.wire, this.label);
  final String wire;
  final String label;

  static EmploymentStatus fromWire(String? s) {
    for (final v in values) {
      if (v.wire == s) return v;
    }
    return EmploymentStatus.active;
  }
}

enum PayrollStatus {
  pending('PENDING', 'Pending'),
  paid('PAID', 'Paid');

  const PayrollStatus(this.wire, this.label);
  final String wire;
  final String label;

  static PayrollStatus fromWire(String? s) {
    for (final v in values) {
      if (v.wire == s) return v;
    }
    return PayrollStatus.pending;
  }
}

/// Staff member — used by assignment dropdowns, the Employees tab, and
/// the edit / release dialogs.
class Staff {
  Staff({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    this.jobTitle,
    this.department,
    this.phoneNumber,
    this.dailyRate,
    this.monthlySalary,
    this.salaryType,
    this.isActive = true,
    this.employmentStatus = EmploymentStatus.active,
    this.releaseDate,
    this.releaseReason,
    this.releaseNotes,
    this.releasedByName,
    this.createdAt,
  });

  final String id;
  final String fullName;
  final String email;
  final String role;
  final String? jobTitle;
  final String? department;
  final String? phoneNumber;
  final num? dailyRate;
  final num? monthlySalary;
  final String? salaryType;
  final bool isActive;
  final EmploymentStatus employmentStatus;
  final DateTime? releaseDate;
  final String? releaseReason;
  final String? releaseNotes;
  final String? releasedByName;
  final DateTime? createdAt;

  factory Staff.fromJson(Map<String, dynamic> j) {
    return Staff(
      id: (j['id'] ?? '').toString(),
      fullName: (j['fullName'] ?? '').toString(),
      email: (j['email'] ?? '').toString(),
      role: (j['role'] ?? '').toString(),
      jobTitle: j['jobTitle']?.toString(),
      department: j['department']?.toString(),
      phoneNumber: j['phoneNumber']?.toString(),
      dailyRate: j['dailyRate'] == null ? null : _toNum(j['dailyRate']),
      monthlySalary:
          j['monthlySalary'] == null ? null : _toNum(j['monthlySalary']),
      salaryType: j['salaryType']?.toString(),
      isActive: j['isActive'] != false,
      employmentStatus:
          EmploymentStatus.fromWire(j['employmentStatus']?.toString()),
      releaseDate: _parseDate(j['releaseDate']),
      releaseReason: j['releaseReason']?.toString(),
      releaseNotes: j['releaseNotes']?.toString(),
      releasedByName: j['releasedByName']?.toString(),
      createdAt: _parseDate(j['createdAt']),
    );
  }
}

class AttendanceEntry {
  AttendanceEntry({
    required this.userId,
    required this.fullName,
    required this.role,
    this.department,
    required this.status,
  });

  final String userId;
  final String fullName;
  final String role;
  final String? department;
  final AttendanceStatus status;

  factory AttendanceEntry.fromJson(Map<String, dynamic> j) {
    return AttendanceEntry(
      userId: (j['userId'] ?? '').toString(),
      fullName: (j['fullName'] ?? '').toString(),
      role: (j['role'] ?? '').toString(),
      department: j['department']?.toString(),
      status: AttendanceStatus.fromWire(j['status']?.toString()),
    );
  }
}

class TaskRow {
  TaskRow({
    required this.id,
    required this.assignedToId,
    required this.assignedToName,
    required this.unit,
    required this.title,
    this.description,
    required this.priority,
    required this.status,
    this.dueDate,
  });

  final String id;
  final String assignedToId;
  final String assignedToName;
  final String unit;
  final String title;
  final String? description;
  final TaskPriority priority;
  final TaskStatus status;
  final DateTime? dueDate;

  factory TaskRow.fromJson(Map<String, dynamic> j) {
    return TaskRow(
      id: (j['id'] ?? '').toString(),
      assignedToId: (j['assignedToId'] ?? '').toString(),
      assignedToName: (j['assignedToName'] ?? '').toString(),
      unit: (j['unit'] ?? '').toString(),
      title: (j['title'] ?? '').toString(),
      description: j['description']?.toString(),
      priority: TaskPriority.fromWire(j['priority']?.toString()),
      status: TaskStatus.fromWire(j['status']?.toString()),
      dueDate: _parseDate(j['dueDate']),
    );
  }
}

// One adjustment applied to a payroll row — advance / bonus / penalty
// / overtime. Status flows: PENDING → APPROVED → DEDUCTED, or DECLINED.
enum AdjustmentType {
  advance('ADVANCE', 'Advance'),
  bonus('BONUS', 'Bonus'),
  penalty('PENALTY', 'Penalty'),
  overtime('OVERTIME', 'Overtime');

  const AdjustmentType(this.wire, this.label);
  final String wire;
  final String label;

  static AdjustmentType fromWire(String? s) {
    for (final v in values) {
      if (v.wire == s) return v;
    }
    return AdjustmentType.advance;
  }
}

enum AdjustmentStatus {
  pending('PENDING', 'Pending'),
  approved('APPROVED', 'Approved'),
  deducted('DEDUCTED', 'Deducted'),
  declined('DECLINED', 'Declined');

  const AdjustmentStatus(this.wire, this.label);
  final String wire;
  final String label;

  static AdjustmentStatus fromWire(String? s) {
    for (final v in values) {
      if (v.wire == s) return v;
    }
    return AdjustmentStatus.pending;
  }
}

enum AdvancePaymentMethod {
  cash('CASH', 'Cash'),
  mpesa('MPESA', 'M-Pesa'),
  bankTransfer('BANK_TRANSFER', 'Bank Transfer');

  const AdvancePaymentMethod(this.wire, this.label);
  final String wire;
  final String label;

  static AdvancePaymentMethod? fromWire(String? s) {
    if (s == null) return null;
    for (final v in values) {
      if (v.wire == s) return v;
    }
    return null;
  }
}

class PayrollAdjustment {
  PayrollAdjustment({
    required this.id,
    required this.type,
    required this.status,
    required this.amount,
    this.reason,
    this.notes,
    this.referenceNo,
    this.requestDate,
    this.approvedDate,
    this.disbursedDate,
    this.repaymentMonth,
    this.repaymentYear,
    this.paymentMethod,
    this.transactionCode,
    this.requestedAt,
    this.approvedAt,
  });

  final String id;
  final AdjustmentType type;
  final AdjustmentStatus status;
  final num amount;
  final String? reason;
  final String? notes;
  final String? referenceNo;
  final DateTime? requestDate;
  final DateTime? approvedDate;
  final DateTime? disbursedDate;
  final int? repaymentMonth;
  final int? repaymentYear;
  final AdvancePaymentMethod? paymentMethod;
  final String? transactionCode;
  final DateTime? requestedAt;
  final DateTime? approvedAt;

  factory PayrollAdjustment.fromJson(Map<String, dynamic> j) {
    DateTime? toDate(dynamic v) =>
        v == null ? null : DateTime.tryParse(v.toString());
    int? toInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v);
      return null;
    }

    return PayrollAdjustment(
      id: (j['id'] ?? '').toString(),
      type: AdjustmentType.fromWire(j['type']?.toString()),
      status: AdjustmentStatus.fromWire(j['status']?.toString()),
      amount: _toNum(j['amount']),
      reason: j['reason']?.toString(),
      notes: j['notes']?.toString(),
      referenceNo: j['referenceNo']?.toString(),
      requestDate: toDate(j['requestDate']),
      approvedDate: toDate(j['approvedDate']),
      disbursedDate: toDate(j['disbursedDate']),
      repaymentMonth: toInt(j['repaymentMonth']),
      repaymentYear: toInt(j['repaymentYear']),
      paymentMethod:
          AdvancePaymentMethod.fromWire(j['paymentMethod']?.toString()),
      transactionCode: j['transactionCode']?.toString(),
      requestedAt: toDate(j['requestedAt']),
      approvedAt: toDate(j['approvedAt']),
    );
  }
}

class PayrollRow {
  PayrollRow({
    required this.userId,
    required this.name,
    required this.role,
    this.jobTitle,
    required this.unit,
    required this.daysWorked,
    this.dailyRate,
    this.monthlySalary,
    required this.salaryType,
    required this.grossPay,
    required this.netPay,
    required this.advances,
    required this.bonuses,
    required this.penalties,
    required this.overtime,
    required this.status,
    required this.adjustments,
  });

  final String userId;
  final String name;
  final String role;
  /// Free-text job title from User.jobTitle (e.g. "Dairy Worker",
  /// "Piggery Manager (A·B·C·EM)"). When null, fall back to [role].
  final String? jobTitle;
  final String unit;
  final int daysWorked;
  final num? dailyRate;
  final num? monthlySalary;
  final String salaryType;
  final num grossPay;
  final num netPay;
  final num advances;
  final num bonuses;
  final num penalties;
  final num overtime;
  final PayrollStatus status;
  final List<PayrollAdjustment> adjustments;

  /// Convenience: the advances that affect the next payroll (APPROVED
  /// + DEDUCTED). PENDING and DECLINED stay visible in the bottom
  /// sheet but don't shift net pay.
  List<PayrollAdjustment> get advancePills =>
      adjustments.where((a) => a.type == AdjustmentType.advance).toList();

  factory PayrollRow.fromJson(Map<String, dynamic> j) {
    return PayrollRow(
      userId: (j['userId'] ?? '').toString(),
      name: (j['name'] ?? '').toString(),
      role: (j['role'] ?? '').toString(),
      jobTitle: j['jobTitle']?.toString().isEmpty == true
          ? null
          : j['jobTitle']?.toString(),
      unit: (j['unit'] ?? '').toString(),
      daysWorked: _toInt(j['daysWorked']),
      dailyRate: j['dailyRate'] == null ? null : _toNum(j['dailyRate']),
      monthlySalary:
          j['monthlySalary'] == null ? null : _toNum(j['monthlySalary']),
      salaryType: (j['salaryType'] ?? 'DAILY').toString(),
      grossPay: _toNum(j['grossPay']),
      netPay: _toNum(j['netPay'] ?? j['grossPay']),
      advances: _toNum(j['advances']),
      bonuses: _toNum(j['bonuses']),
      penalties: _toNum(j['penalties']),
      overtime: _toNum(j['overtime']),
      status: PayrollStatus.fromWire(j['status']?.toString()),
      adjustments: ((j['adjustments'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => PayrollAdjustment.fromJson(m.cast<String, dynamic>()))
          .toList(),
    );
  }
}

class PayrollSummary {
  PayrollSummary({
    required this.month,
    required this.year,
    required this.rows,
    required this.totalGross,
    required this.totalNet,
  });

  final int month;
  final int year;
  final List<PayrollRow> rows;
  final num totalGross;
  final num totalNet;

  factory PayrollSummary.fromJson(Map<String, dynamic> j) {
    final rows = ((j['rows'] as List?) ?? const [])
        .whereType<Map>()
        .map((m) => PayrollRow.fromJson(m.cast<String, dynamic>()))
        .toList();
    return PayrollSummary(
      month: _toInt(j['month']),
      year: _toInt(j['year']),
      rows: rows,
      totalGross: _toNum(j['totalGross']),
      totalNet: j['totalNet'] != null
          ? _toNum(j['totalNet'])
          : rows.fold<num>(0, (s, r) => s + r.netPay),
    );
  }
}

/// Aggregate payload from GET /api/staff/dashboard.
class StaffDashboard {
  StaffDashboard({
    required this.totalStaff,
    required this.presentToday,
    required this.absentToday,
    required this.monthlyPayroll,
    required this.attendance,
    required this.tasks,
    required this.payroll,
  });

  final int totalStaff;
  final int presentToday;
  final int absentToday;
  final num monthlyPayroll;
  final List<AttendanceEntry> attendance;
  final List<TaskRow> tasks;
  final PayrollSummary payroll;

  factory StaffDashboard.fromJson(Map<String, dynamic> j) {
    return StaffDashboard(
      totalStaff: _toInt(j['totalStaff']),
      presentToday: _toInt(j['presentToday']),
      absentToday: _toInt(j['absentToday']),
      monthlyPayroll: _toNum(j['monthlyPayroll']),
      attendance: ((j['attendance'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => AttendanceEntry.fromJson(m.cast<String, dynamic>()))
          .toList(),
      tasks: ((j['tasks'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => TaskRow.fromJson(m.cast<String, dynamic>()))
          .toList(),
      payroll: PayrollSummary.fromJson(
        ((j['payroll'] as Map?) ?? const {}).cast<String, dynamic>(),
      ),
    );
  }
}
