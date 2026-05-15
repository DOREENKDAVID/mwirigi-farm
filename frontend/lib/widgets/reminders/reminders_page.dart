// 🔔 Reminders & upcoming milestones — central scheduling page.
//
// Layout:
//   • Page header (title + sub-line)
//   • 4 KPI cards (Overdue · Due · Upcoming · Active)
//   • Sticky filter strip — Unit pills (All · Dairy · Layers · Piggery · Herd)
//                           Status pills (Active · Overdue · Due · Upcoming · Future · Done)
//   • Grouped reminder list — Today / This week / Later / Done
//
// Each reminder is rendered by `_ReminderCard` with:
//   • coloured left accent bar (urgency)
//   • icon · title · description · due-date chip · unit chip · status pill
//   • action menu (mark done · snooze 1d/3d/7d · undo)

import 'package:flutter/material.dart';

import '../dashboard/kpi_grid.dart';

import '../../core/models/reminder.dart';
import '../../core/service/api_service.dart';
import 'reminder_card.dart';

class RemindersPage extends StatefulWidget {
  const RemindersPage({super.key});
  @override
  State<RemindersPage> createState() => _RemindersPageState();
}

class _RemindersPageState extends State<RemindersPage> {
  static const _primary = Color(0xFF27500A);
  static const _txt2 = Color(0xFF6B7770);
  static const _txt3 = Color(0xFF99A39B);
  static const _danger = Color(0xFFC4393B);
  static const _amber = Color(0xFF8A5A0A);

  late Future<_PageData> _future;
  String _unit = 'all';   // all / Dairy / Layers / Piggery / Herd
  String _status = 'active'; // active / overdue / due / upcoming / future / done

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_PageData> _load() async {
    // Always pull all reminders (filtering is local) so the unit + status
    // pill counts stay in sync with the underlying feed.
    final results = await Future.wait([
      ApiService.getReminders(),
      ApiService.getReminderKpis(),
    ]);
    final list = (results[0] as List)
        .whereType<Map>()
        .map((m) => Reminder.fromJson(m.cast<String, dynamic>()))
        .toList();
    final kpis = ReminderKpis.fromJson(
      (results[1] as Map).cast<String, dynamic>(),
    );
    return _PageData(reminders: list, kpis: kpis);
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  // -------- Local filter logic --------

  List<Reminder> _filter(List<Reminder> all) {
    return all.where((r) {
      if (_unit != 'all' &&
          r.unit.toLowerCase() != _unit.toLowerCase()) {
        return false;
      }
      switch (_status) {
        case 'active':
          return r.bucket != 'DONE';
        case 'overdue':
          return r.bucket == 'OVERDUE';
        case 'due':
          return r.bucket == 'DUE';
        case 'upcoming':
          return r.bucket == 'UPCOMING';
        case 'future':
          return r.bucket == 'FUTURE';
        case 'done':
          return r.bucket == 'DONE';
        default:
          return true;
      }
    }).toList();
  }

  Map<String, List<Reminder>> _groupByTimeframe(List<Reminder> rows) {
    final today = <Reminder>[];
    final thisWeek = <Reminder>[];
    final later = <Reminder>[];
    final done = <Reminder>[];
    for (final r in rows) {
      if (r.bucket == 'DONE') {
        done.add(r);
        continue;
      }
      final d = r.daysUntilDue ?? 999;
      if (d < 0 || d == 0) {
        today.add(r);
      } else if (d <= 7) {
        thisWeek.add(r);
      } else {
        later.add(r);
      }
    }
    final out = <String, List<Reminder>>{};
    if (today.isNotEmpty) out['Today / Overdue'] = today;
    if (thisWeek.isNotEmpty) out['This week'] = thisWeek;
    if (later.isNotEmpty) out['Later'] = later;
    if (done.isNotEmpty) out['Done'] = done;
    return out;
  }

  // -------- Actions --------

  Future<void> _markDone(Reminder r) async {
    try {
      await ApiService.markReminderDone(r.syntheticId);
      _toast('Marked done');
      await _refresh();
    } catch (e) {
      _toast('Failed: $e');
    }
  }

  Future<void> _snooze(Reminder r, int days) async {
    try {
      await ApiService.snoozeReminder(r.syntheticId, days);
      _toast('Snoozed ${days}d');
      await _refresh();
    } catch (e) {
      _toast('Failed: $e');
    }
  }

  Future<void> _undo(Reminder r) async {
    try {
      await ApiService.undoReminder(r.syntheticId);
      _toast('Reverted');
      await _refresh();
    } catch (e) {
      _toast('Failed: $e');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<_PageData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return _ErrorView(
              message: snap.error.toString().replaceFirst('Exception: ', ''),
              onRetry: _refresh,
            );
          }
          final data = snap.data!;
          final filtered = _filter(data.reminders);
          final groups = _groupByTimeframe(filtered);

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 80),
            children: [
              const _PageHeader(),
              const SizedBox(height: 16),
              _KpiRow(kpis: data.kpis),
              const SizedBox(height: 16),
              _UnitPills(
                selected: _unit,
                onSelect: (v) => setState(() => _unit = v),
                reminders: data.reminders,
              ),
              const SizedBox(height: 8),
              _StatusPills(
                selected: _status,
                onSelect: (v) => setState(() => _status = v),
                reminders: data.reminders,
              ),
              const SizedBox(height: 18),
              if (filtered.isEmpty)
                const _EmptyState()
              else
                for (final entry in groups.entries) ...[
                  _GroupHeader(title: entry.key, count: entry.value.length),
                  const SizedBox(height: 8),
                  for (final r in entry.value) ...[
                    ReminderCard(
                      // Stable identity so Flutter matches the same card
                      // across reorders (mark-done / snooze move it
                      // between groups). Prevents mouse-tracker desyncs.
                      key: ValueKey('reminder-${r.syntheticId}'),
                      reminder: r,
                      onMarkDone: () => _markDone(r),
                      onSnooze: (days) => _snooze(r, days),
                      onUndo: () => _undo(r),
                    ),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 10),
                ],
            ],
          );
        },
      ),
    );
  }
}

class _PageData {
  _PageData({required this.reminders, required this.kpis});
  final List<Reminder> reminders;
  final ReminderKpis kpis;
}

// ===================================================================
// Page header
// ===================================================================

class _PageHeader extends StatelessWidget {
  const _PageHeader();
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFFAEEDA),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Text('🔔', style: TextStyle(fontSize: 20)),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reminders & upcoming milestones',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: _RemindersPageState._primary,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Auto-generated from vaccinations, breeding, sows, and active treatments',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ===================================================================
// KPI row
// ===================================================================

class _KpiRow extends StatelessWidget {
  const _KpiRow({required this.kpis});
  final ReminderKpis kpis;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      _KpiTile(
        label: 'Overdue',
        value: '${kpis.overdue}',
        sub: 'past due — action needed',
        color: _RemindersPageState._danger,
      ),
      _KpiTile(
        label: 'Due now',
        value: '${kpis.due}',
        sub: 'within 3 days',
        color: _RemindersPageState._amber,
      ),
      _KpiTile(
        label: 'Upcoming (14d)',
        value: '${kpis.upcoming}',
        sub: 'plan ahead',
        color: _RemindersPageState._primary,
      ),
      _KpiTile(
        label: 'All active',
        value: '${kpis.active}',
        sub: 'through next 90 days',
        color: const Color(0xFF222222),
      ),
    ];

    return KpiGrid(spacing: 10, runSpacing: 10, children: tiles);
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
  });
  final String label;
  final String value;
  final String sub;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: _RemindersPageState._txt2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            style: const TextStyle(
              fontSize: 11,
              color: _RemindersPageState._txt3,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ===================================================================
// Unit + status pills
// ===================================================================

class _UnitPills extends StatelessWidget {
  const _UnitPills({
    required this.selected,
    required this.onSelect,
    required this.reminders,
  });
  final String selected;
  final ValueChanged<String> onSelect;
  final List<Reminder> reminders;

  @override
  Widget build(BuildContext context) {
    int countFor(String unit) {
      if (unit == 'all') {
        return reminders.where((r) => r.bucket != 'DONE').length;
      }
      return reminders
          .where((r) =>
              r.unit.toLowerCase() == unit.toLowerCase() &&
              r.bucket != 'DONE')
          .length;
    }

    final pills = <(String, String, String)>[
      ('all',     '🏷️',  'All units'),
      ('Dairy',   '🐄',  'Dairy'),
      ('Piggery', '🐷',  'Piggery'),
      ('Layers',  '🥚',  'Layers'),
      ('Feedlot', '🐂',  'Feedlot'),
      ('Herd',    '🩺',  'Herd-wide'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final p in pills) ...[
            _Pill(
              text: '${p.$2} ${p.$3}',
              count: countFor(p.$1),
              active: selected == p.$1,
              onTap: () => onSelect(p.$1),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _StatusPills extends StatelessWidget {
  const _StatusPills({
    required this.selected,
    required this.onSelect,
    required this.reminders,
  });
  final String selected;
  final ValueChanged<String> onSelect;
  final List<Reminder> reminders;

  @override
  Widget build(BuildContext context) {
    int count(String key) {
      switch (key) {
        case 'active':   return reminders.where((r) => r.bucket != 'DONE').length;
        case 'overdue':  return reminders.where((r) => r.bucket == 'OVERDUE').length;
        case 'due':      return reminders.where((r) => r.bucket == 'DUE').length;
        case 'upcoming': return reminders.where((r) => r.bucket == 'UPCOMING').length;
        case 'future':   return reminders.where((r) => r.bucket == 'FUTURE').length;
        case 'done':     return reminders.where((r) => r.bucket == 'DONE').length;
        default:         return 0;
      }
    }

    final pills = <(String, String)>[
      ('active',   'Active'),
      ('overdue',  'Overdue'),
      ('due',      'Due now'),
      ('upcoming', 'Upcoming'),
      ('future',   'Future'),
      ('done',     'Done'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final p in pills) ...[
            _Pill(
              text: p.$2,
              count: count(p.$1),
              active: selected == p.$1,
              onTap: () => onSelect(p.$1),
              compact: true,
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.text,
    required this.count,
    required this.active,
    required this.onTap,
    this.compact = false,
  });
  final String text;
  final int count;
  final bool active;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final bg = active ? const Color(0xFF27500A) : Colors.white;
    final fg = active ? Colors.white : const Color(0xFF222222);
    final border = active
        ? const Color(0xFF27500A)
        : const Color(0x33000000);
    final ctBg = active ? const Color(0x33FFFFFF) : const Color(0xFFEFF5E6);
    final ctFg = active ? Colors.white : const Color(0xFF27500A);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 14,
          vertical: compact ? 7 : 9,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              style: TextStyle(
                fontSize: compact ? 12 : 13,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: ctBg,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: ctFg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===================================================================
// Group header
// ===================================================================

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.title, required this.count});
  final String title;
  final int count;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 4),
      child: Row(
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: _RemindersPageState._txt2,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '($count)',
            style: const TextStyle(
              fontSize: 11,
              color: _RemindersPageState._txt3,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ===================================================================
// Empty / error states
// ===================================================================

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFEFF5E6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline,
              size: 36, color: _RemindersPageState._primary),
          SizedBox(height: 8),
          Text(
            'All caught up.',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _RemindersPageState._primary,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'No reminders match this filter.',
            style: TextStyle(
              fontSize: 12,
              color: _RemindersPageState._txt2,
            ),
          ),
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
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 80),
        const Icon(Icons.error_outline, size: 40, color: Color(0xFFE24B4A)),
        const SizedBox(height: 12),
        const Text(
          'Could not load reminders',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.black54, fontSize: 12),
        ),
        const SizedBox(height: 16),
        Center(
          child: FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ),
      ],
    );
  }
}
