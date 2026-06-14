// Activity & Audit Report page.
//
// Accessible from Reports → Activities pill.
// Loads audit log entries from GET /api/activity-log and displays them
// as a date-grouped timeline with filter controls.
//
// Filters:
//   • Date range (preset pills + custom picker)
//   • Module  (All · Dairy · Layers · Health · Staff · Piggery)
//   • Action  (All · Created · Updated · Deleted)
//
// AppBar actions: Download PDF (print dialog) · Share (OS share sheet).

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../../core/service/api_service.dart';
import '../../core/utils/activity_report_pdf.dart';

class ActivityReportPage extends StatefulWidget {
  const ActivityReportPage({super.key});

  @override
  State<ActivityReportPage> createState() => _ActivityReportPageState();
}

class _ActivityReportPageState extends State<ActivityReportPage> {
  static const _primary   = Color(0xFF27500A);
  static const _bg        = Color(0xFFF5F4F0);
  static const _txt2      = Color(0xFF6B7770);
  static const _border    = Color(0x14000000);

  // ── Filter state ────────────────────────────────────────────────────
  _Period _period = _Period.month;
  DateTimeRange? _customRange;
  String? _module;  // null = All
  String? _action;  // null = All

  static const _modules = ['Dairy', 'Layers', 'Health', 'Staff', 'Piggery'];
  static const _actions = ['CREATE', 'UPDATE', 'DELETE', 'RELEASE'];
  static const _actionLabels = {
    'CREATE':  'Created',
    'UPDATE':  'Updated',
    'DELETE':  'Deleted',
    'RELEASE': 'Released',
  };

  Future<_Result>? _future;

  @override
  void initState() {
    super.initState();
    _future = _fetch();
  }

  DateTimeRange get _range {
    if (_period == _Period.custom && _customRange != null) return _customRange!;
    final now = DateTime.now();
    switch (_period) {
      case _Period.today:
        return DateTimeRange(
            start: DateTime(now.year, now.month, now.day), end: now);
      case _Period.week:
        return DateTimeRange(
            start: now.subtract(const Duration(days: 7)), end: now);
      case _Period.month:
        return DateTimeRange(
            start: DateTime(now.year, now.month, 1), end: now);
      case _Period.quarter:
        return DateTimeRange(
            start: now.subtract(const Duration(days: 90)), end: now);
      case _Period.year:
        return DateTimeRange(
            start: DateTime(now.year, 1, 1), end: now);
      case _Period.custom:
        return DateTimeRange(
            start: now.subtract(const Duration(days: 30)), end: now);
    }
  }

  Future<_Result> _fetch() async {
    final r = _range;
    final raw = await ApiService.getActivityLog(
      module: _module,
      from: r.start,
      to: r.end,
      limit: 200,
    );
    final rows = ((raw['rows'] as List?) ?? [])
        .whereType<Map>()
        .map((m) => ActivityLogRow.fromJson(m.cast<String, dynamic>()))
        .where((e) => _action == null || e.action == _action)
        .toList();
    final total = raw['total'] as int? ?? rows.length;
    return _Result(rows: rows, total: total);
  }

  void _refetch() => setState(() => _future = _fetch());

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 2)),
      lastDate: DateTime.now(),
      initialDateRange: _customRange ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 30)),
            end: DateTime.now(),
          ),
    );
    if (picked == null) return;
    setState(() {
      _customRange = picked;
      _period = _Period.custom;
    });
    _refetch();
  }

  String get _periodLabel {
    if (_period == _Period.custom && _customRange != null) {
      final fmt = DateFormat('d MMM');
      return '${fmt.format(_customRange!.start)} → ${fmt.format(_customRange!.end)}';
    }
    return _period.label;
  }

  Future<void> _exportPdf({required bool share}) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await (_future ?? _fetch());
      final userName = await ApiService.readUserName();
      final bytes = await buildActivityReportPdf(ActivityReportInput(
        rows: result.rows,
        total: result.total,
        periodLabel: _periodLabel,
        moduleLabel: _module,
        actionLabel: _action == null ? null : _actionLabels[_action],
        generatedBy: userName,
      ));
      const name = 'Mwirigi-Activity-Report';
      if (share) {
        await Printing.sharePdf(bytes: bytes, filename: '$name.pdf');
      } else {
        await Printing.layoutPdf(name: name, onLayout: (_) async => bytes);
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text(
            'PDF export failed: ${e.toString().replaceFirst('Exception: ', '')}'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('Activity Report'),
        backgroundColor: Colors.white,
        foregroundColor: _primary,
        elevation: 0.5,
        actions: [
          TextButton.icon(
            onPressed: () => _exportPdf(share: false),
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
            label: const Text('Download'),
            style: TextButton.styleFrom(
              foregroundColor: _primary,
              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
          TextButton.icon(
            onPressed: () => _exportPdf(share: true),
            icon: const Icon(Icons.share_outlined, size: 18),
            label: const Text('Share'),
            style: TextButton.styleFrom(
              foregroundColor: _primary,
              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          _FilterBar(
            period: _period,
            module: _module,
            action: _action,
            modules: _modules,
            actions: _actions,
            actionLabels: _actionLabels,
            onPeriod: (p) {
              if (p == _Period.custom) {
                _pickCustomRange();
              } else {
                setState(() => _period = p);
                _refetch();
              }
            },
            onModule: (m) {
              setState(() => _module = m);
              _refetch();
            },
            onAction: (a) {
              setState(() => _action = a);
              _refetch();
            },
          ),
          Expanded(
            child: FutureBuilder<_Result>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return _ErrorView(
                    message: snap.error
                        .toString()
                        .replaceFirst('Exception: ', ''),
                    onRetry: _refetch,
                  );
                }
                final result = snap.data!;
                if (result.rows.isEmpty) {
                  return const _EmptyView();
                }
                return _ActivityList(rows: result.rows, total: result.total);
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Filter bar ─────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.period,
    required this.module,
    required this.action,
    required this.modules,
    required this.actions,
    required this.actionLabels,
    required this.onPeriod,
    required this.onModule,
    required this.onAction,
  });

  final _Period period;
  final String? module;
  final String? action;
  final List<String> modules;
  final List<String> actions;
  final Map<String, String> actionLabels;
  final ValueChanged<_Period> onPeriod;
  final ValueChanged<String?> onModule;
  final ValueChanged<String?> onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Period row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final p in _Period.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _Pill(
                      label: p.label,
                      active: period == p,
                      onTap: () => onPeriod(p),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Module + Action row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _Pill(
                  label: 'All modules',
                  active: module == null,
                  onTap: () => onModule(null),
                ),
                const SizedBox(width: 6),
                for (final m in modules) ...[
                  _Pill(
                    label: m,
                    active: module == m,
                    onTap: () => onModule(module == m ? null : m),
                  ),
                  const SizedBox(width: 6),
                ],
                const SizedBox(width: 12),
                _Pill(
                  label: 'All actions',
                  active: action == null,
                  accent: false,
                  onTap: () => onAction(null),
                ),
                const SizedBox(width: 6),
                for (final a in actions) ...[
                  _Pill(
                    label: actionLabels[a] ?? a,
                    active: action == a,
                    accent: false,
                    color: _actionColor(a),
                    onTap: () => onAction(action == a ? null : a),
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _actionColor(String a) {
    switch (a) {
      case 'CREATE':
        return const Color(0xFF27500A);
      case 'DELETE':
        return const Color(0xFFB52C2B);
      default:
        return const Color(0xFF854F0B);
    }
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.active,
    required this.onTap,
    this.accent = true,
    this.color,
  });

  final String label;
  final bool active;
  final bool accent;
  final Color? color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = color ?? (accent ? const Color(0xFF27500A) : const Color(0xFF4A5568));
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? c : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: active ? c : const Color(0xFFD1D5DB)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : const Color(0xFF374151),
          ),
        ),
      ),
    );
  }
}

// ── Timeline list ───────────────────────────────────────────────────────

class _ActivityList extends StatelessWidget {
  const _ActivityList({required this.rows, required this.total});

  final List<ActivityLogRow> rows;
  final int total;

  @override
  Widget build(BuildContext context) {
    // Group by calendar date.
    final groups = <String, List<ActivityLogRow>>{};
    final dayFmt = DateFormat('EEEE, d MMMM yyyy');
    for (final r in rows) {
      final key = dayFmt.format(r.createdAt.toLocal());
      groups.putIfAbsent(key, () => []).add(r);
    }

    return RefreshIndicator(
      onRefresh: () async {},
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Showing ${rows.length} of $total changes',
              style: const TextStyle(fontSize: 12, color: _ActivityReportPageState._txt2),
            ),
          ),
          for (final entry in groups.entries) ...[
            _DateHeader(label: entry.key),
            const SizedBox(height: 6),
            for (final row in entry.value) _ActivityTile(row: row),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _DateHeader extends StatelessWidget {
  const _DateHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF3DE),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: _ActivityReportPageState._primary,
          ),
        ),
      ),
      const SizedBox(width: 8),
      const Expanded(child: Divider(height: 1)),
    ]);
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.row});
  final ActivityLogRow row;

  @override
  Widget build(BuildContext context) {
    final timeFmt = DateFormat('HH:mm');
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _ActivityReportPageState._border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Action badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _badgeBg(row.action),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              row.action,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: _badgeFg(row.action),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF1A1A1A)),
                    children: [
                      TextSpan(
                        text: row.actorName ?? 'System',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const TextSpan(text: '  '),
                      TextSpan(
                        text: '${row.module} · ${row.entity}',
                        style: const TextStyle(
                            color: _ActivityReportPageState._txt2,
                            fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (row.reason != null && row.reason!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    row.reason!,
                    style: const TextStyle(
                        fontSize: 11,
                        color: _ActivityReportPageState._txt2,
                        fontStyle: FontStyle.italic),
                  ),
                ],
              ],
            ),
          ),
          // Time
          Text(
            timeFmt.format(row.createdAt.toLocal()),
            style: const TextStyle(
                fontSize: 11, color: _ActivityReportPageState._txt2),
          ),
        ],
      ),
    );
  }

  Color _badgeBg(String action) {
    switch (action) {
      case 'CREATE':  return const Color(0xFFEAF3DE);
      case 'DELETE':  return const Color(0xFFFFEEEE);
      case 'RELEASE': return const Color(0xFFEEE8FF);
      default:        return const Color(0xFFFAEEDA);
    }
  }

  Color _badgeFg(String action) {
    switch (action) {
      case 'CREATE':  return const Color(0xFF27500A);
      case 'DELETE':  return const Color(0xFFB52C2B);
      case 'RELEASE': return const Color(0xFF5B2CA6);
      default:        return const Color(0xFF854F0B);
    }
  }
}

// ── Empty / error views ────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history_outlined, size: 48, color: Color(0xFFD1D5DB)),
          SizedBox(height: 12),
          Text('No activity found',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          SizedBox(height: 4),
          Text('Try adjusting the filters or date range.',
              style: TextStyle(color: _ActivityReportPageState._txt2, fontSize: 13)),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40, color: Color(0xFFE24B4A)),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

// ── Internal models ─────────────────────────────────────────────────────

class _Result {
  const _Result({required this.rows, required this.total});
  final List<ActivityLogRow> rows;
  final int total;
}

enum _Period {
  today('Today'),
  week('Last 7 days'),
  month('This Month'),
  quarter('Last 90 days'),
  year('This Year'),
  custom('Custom');

  const _Period(this.label);
  final String label;
}
