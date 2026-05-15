// Reminder feed item — one row from /api/reminders.
//
// Reminders are virtual (composed by the backend on every request from
// existing source tables). The frontend just renders. `syntheticId` is
// the stable identifier that survives regeneration; pass it back when
// marking done / snoozing / undoing.

class Reminder {
  Reminder({
    required this.syntheticId,
    required this.sourceType,
    required this.sourceId,
    required this.module,
    required this.unit,
    required this.title,
    required this.description,
    required this.dueDate,
    required this.effectiveDueDate,
    required this.bucket,
    required this.status,
    required this.priority,
    required this.icon,
    this.daysUntilDue,
    this.completedAt,
    this.snoozedUntil,
  });

  final String syntheticId;
  final String sourceType; // "vaccine" | "brooderVaccine" | "repro" | "pig" | "treatment"
  final String? sourceId;
  final String module;
  final String unit; // "Dairy" | "Layers" | "Piggery" | "Feedlot" | "Herd"
  final String title;
  final String description;
  final DateTime? dueDate;
  final DateTime? effectiveDueDate;
  /// "OVERDUE" | "DUE" | "UPCOMING" | "FUTURE" | "DONE"
  final String bucket;
  /// Visible status — usually mirrors `bucket` but can be `"SNOOZED"` for
  /// rows whose snoozedUntil is still in the future.
  final String status;
  final int priority;
  final String icon; // "vaccine" | "breeding" | "calving" | "farrow" | "health"
  final int? daysUntilDue;
  final DateTime? completedAt;
  final DateTime? snoozedUntil;

  bool get isDone => bucket == 'DONE';
  bool get isSnoozed => status == 'SNOOZED';

  factory Reminder.fromJson(Map<String, dynamic> j) {
    DateTime? toDate(dynamic v) =>
        v == null ? null : DateTime.tryParse(v.toString());
    int? toInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v);
      return null;
    }

    return Reminder(
      syntheticId: (j['syntheticId'] ?? '').toString(),
      sourceType: (j['sourceType'] ?? '').toString(),
      sourceId: j['sourceId']?.toString(),
      module: (j['module'] ?? '').toString(),
      unit: (j['unit'] ?? 'Herd').toString(),
      title: (j['title'] ?? '').toString(),
      description: (j['description'] ?? '').toString(),
      dueDate: toDate(j['dueDate']),
      effectiveDueDate: toDate(j['effectiveDueDate']) ?? toDate(j['dueDate']),
      bucket: (j['bucket'] ?? 'FUTURE').toString().toUpperCase(),
      status: (j['status'] ?? j['bucket'] ?? 'FUTURE').toString().toUpperCase(),
      priority: toInt(j['priority']) ?? 5,
      icon: (j['icon'] ?? 'reminder').toString(),
      daysUntilDue: toInt(j['daysUntilDue']),
      completedAt: toDate(j['completedAt']),
      snoozedUntil: toDate(j['snoozedUntil']),
    );
  }
}

class ReminderKpis {
  ReminderKpis({
    required this.overdue,
    required this.due,
    required this.upcoming,
    required this.future,
    required this.done,
    required this.active,
  });
  final int overdue;
  final int due;
  final int upcoming;
  final int future;
  final int done;
  final int active;

  factory ReminderKpis.fromJson(Map<String, dynamic> j) {
    int toInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    return ReminderKpis(
      overdue: toInt(j['overdue']),
      due: toInt(j['due']),
      upcoming: toInt(j['upcoming']),
      future: toInt(j['future']),
      done: toInt(j['done']),
      active: toInt(j['active']),
    );
  }
}
