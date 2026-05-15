// Unit-scoped reminders pill body. Used by Dairy / Layers / Piggery
// pill switchers — each instance fetches `/api/reminders?unit=<unit>`
// so a unit only ever sees its own reminders.
//
// Layout:
//   • Compact header with unit badge + count summary
//   • 3-tile mini KPI strip (Overdue · Due · Upcoming)
//   • Status filter pill row (Active / Overdue / Due / Upcoming / Done)
//   • Grouped reminder list (Today · This week · Later · Done)
//   • "Open full reminders →" button at bottom (snackbar pointer; the
//     parent app shell controls navigation, so we just hint the user)
//
// All actions go through ApiService → main reminders module. No local
// duplication of state.

import 'package:flutter/material.dart';

import '../../core/models/reminder.dart';
import '../../core/service/api_service.dart';
import 'reminder_card.dart';

class UnitRemindersCard extends StatefulWidget {
  const UnitRemindersCard({
    super.key,
    required this.unit,
    this.onOpenFullDashboard,
  });

  /// Unit name as known to the backend (`Dairy` / `Layers` / `Piggery`
  /// / `Feedlot` / `Herd`).
  final String unit;

  /// Optional handler so the parent (e.g. MainScreen) can switch to
  /// the full Reminders page. When null, the link is hidden.
  final VoidCallback? onOpenFullDashboard;

  @override
  State<UnitRemindersCard> createState() => _UnitRemindersCardState();
}

class _UnitRemindersCardState extends State<UnitRemindersCard> {
  static const _primary = Color(0xFF27500A);
  static const _txt2 = Color(0xFF6B7770);
  static const _txt3 = Color(0xFF99A39B);
  static const _danger = Color(0xFFC4393B);
  static const _amber = Color(0xFF8A5A0A);

  late Future<List<Reminder>> _future;
  String _status = 'active';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant UnitRemindersCard old) {
    super.didUpdateWidget(old);
    if (old.unit != widget.unit) {
      _future = _load();
    }
  }

  Future<List<Reminder>> _load() async {
    // Hit the main reminders module with a unit filter — the backend
    // service.listReminders applies the same filtering it uses for the
    // top-level dashboard, so this card stays in sync automatically.
    final raw = await ApiService.getReminders(unit: widget.unit);
    return raw
        .whereType<Map>()
        .map((m) => Reminder.fromJson(m.cast<String, dynamic>()))
        .toList();
  }

  Future<void> _reload() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _markDone(Reminder r) async {
    try {
      await ApiService.markReminderDone(r.syntheticId);
      _toast('Marked done');
      await _reload();
    } catch (e) {
      _toast('Failed: $e');
    }
  }

  Future<void> _snooze(Reminder r, int days) async {
    try {
      await ApiService.snoozeReminder(r.syntheticId, days);
      _toast('Snoozed ${days}d');
      await _reload();
    } catch (e) {
      _toast('Failed: $e');
    }
  }

  Future<void> _undo(Reminder r) async {
    try {
      await ApiService.undoReminder(r.syntheticId);
      _toast('Reverted');
      await _reload();
    } catch (e) {
      _toast('Failed: $e');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // -------- Local filtering / grouping --------

  List<Reminder> _filter(List<Reminder> all) {
    return all.where((r) {
      switch (_status) {
        case 'active':
          return r.bucket != 'DONE';
        case 'overdue':
          return r.bucket == 'OVERDUE';
        case 'due':
          return r.bucket == 'DUE';
        case 'upcoming':
          return r.bucket == 'UPCOMING';
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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Reminder>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 240,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return _ErrorState(
            message: snap.error.toString(),
            onRetry: _reload,
          );
        }
        final all = snap.data ?? const <Reminder>[];
        final overdue = all.where((r) => r.bucket == 'OVERDUE').length;
        final due = all.where((r) => r.bucket == 'DUE').length;
        final upcoming = all.where((r) => r.bucket == 'UPCOMING').length;
        final done = all.where((r) => r.bucket == 'DONE').length;
        final filtered = _filter(all);
        final groups = _groupByTimeframe(filtered);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(unit: widget.unit, total: all.length, onReload: _reload),
            const SizedBox(height: 12),
            _MiniKpiStrip(
              overdue: overdue,
              due: due,
              upcoming: upcoming,
            ),
            const SizedBox(height: 12),
            _StatusPills(
              selected: _status,
              onSelect: (v) => setState(() => _status = v),
              counts: {
                'active': all.where((r) => r.bucket != 'DONE').length,
                'overdue': overdue,
                'due': due,
                'upcoming': upcoming,
                'done': done,
              },
            ),
            const SizedBox(height: 16),
            if (filtered.isEmpty)
              const _Empty()
            else
              for (final entry in groups.entries) ...[
                _GroupHeader(title: entry.key, count: entry.value.length),
                const SizedBox(height: 8),
                for (final r in entry.value) ...[
                  ReminderCard(
                    // Stable identity so Flutter matches the same card
                    // across reorders. Prevents mouse-tracker desyncs.
                    key: ValueKey('reminder-${r.syntheticId}'),
                    reminder: r,
                    onMarkDone: () => _markDone(r),
                    onSnooze: (days) => _snooze(r, days),
                    onUndo: () => _undo(r),
                    showUnitChip: false, // already scoped to one unit
                  ),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 10),
              ],
            if (widget.onOpenFullDashboard != null) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: widget.onOpenFullDashboard,
                  icon: const Icon(Icons.open_in_new, size: 14),
                  label: const Text('Open full reminders dashboard'),
                  style: TextButton.styleFrom(
                    foregroundColor: _primary,
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

// ===================================================================
// Header
// ===================================================================

class _Header extends StatelessWidget {
  const _Header({
    required this.unit,
    required this.total,
    required this.onReload,
  });
  final String unit;
  final int total;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFFAEEDA),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text('🔔', style: TextStyle(fontSize: 16)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reminders — $unit',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: _UnitRemindersCardState._primary,
                ),
              ),
              Text(
                '$total reminder${total == 1 ? '' : 's'} · synced from main module',
                style: const TextStyle(
                  fontSize: 11,
                  color: _UnitRemindersCardState._txt3,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.refresh, size: 18),
          onPressed: onReload,
          tooltip: 'Refresh',
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}

// ===================================================================
// Mini KPI strip (3 tiles)
// ===================================================================

class _MiniKpiStrip extends StatelessWidget {
  const _MiniKpiStrip({
    required this.overdue,
    required this.due,
    required this.upcoming,
  });
  final int overdue;
  final int due;
  final int upcoming;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MiniKpi(
            label: 'Overdue',
            value: '$overdue',
            color: _UnitRemindersCardState._danger,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MiniKpi(
            label: 'Due (3d)',
            value: '$due',
            color: _UnitRemindersCardState._amber,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MiniKpi(
            label: 'Upcoming',
            value: '$upcoming',
            color: _UnitRemindersCardState._primary,
          ),
        ),
      ],
    );
  }
}

class _MiniKpi extends StatelessWidget {
  const _MiniKpi({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: _UnitRemindersCardState._txt2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ===================================================================
// Status filter pills
// ===================================================================

class _StatusPills extends StatelessWidget {
  const _StatusPills({
    required this.selected,
    required this.onSelect,
    required this.counts,
  });
  final String selected;
  final ValueChanged<String> onSelect;
  final Map<String, int> counts;

  @override
  Widget build(BuildContext context) {
    final pills = <(String, String)>[
      ('active', 'Active'),
      ('overdue', 'Overdue'),
      ('due', 'Due'),
      ('upcoming', 'Upcoming'),
      ('done', 'Done'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final p in pills) ...[
            _Pill(
              text: p.$2,
              count: counts[p.$1] ?? 0,
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

class _Pill extends StatelessWidget {
  const _Pill({
    required this.text,
    required this.count,
    required this.active,
    required this.onTap,
  });
  final String text;
  final int count;
  final bool active;
  final VoidCallback onTap;

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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
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
                fontSize: 12,
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
              color: _UnitRemindersCardState._txt2,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '($count)',
            style: const TextStyle(
              fontSize: 11,
              color: _UnitRemindersCardState._txt3,
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

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFEFF5E6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline,
              size: 32, color: _UnitRemindersCardState._primary),
          SizedBox(height: 6),
          Text(
            'All caught up.',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _UnitRemindersCardState._primary,
            ),
          ),
          SizedBox(height: 2),
          Text(
            'No reminders match this filter.',
            style: TextStyle(
              fontSize: 11,
              color: _UnitRemindersCardState._txt2,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFCEDC8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFAC7B0F)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Could not load reminders.\n$message',
              style: const TextStyle(fontSize: 12, color: Color(0xFF8A5A0A)),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
