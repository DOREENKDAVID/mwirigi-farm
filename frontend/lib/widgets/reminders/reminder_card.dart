// Shared reminder card. Used by:
//   • RemindersPage (full module dashboard)
//   • UnitRemindersCard (Dairy / Layers / Piggery pill bodies)
//
// Visual spec: rounded white container with a 4 px coloured left
// accent (urgency), icon tile, title, description, due-date chip,
// unit chip, status pill, and a "Done" + snooze popup action menu.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/reminder.dart';

class ReminderCard extends StatelessWidget {
  const ReminderCard({
    super.key,
    required this.reminder,
    required this.onMarkDone,
    required this.onSnooze,
    required this.onUndo,
    this.showUnitChip = true,
  });

  final Reminder reminder;
  final VoidCallback onMarkDone;
  final ValueChanged<int> onSnooze;
  final VoidCallback onUndo;
  /// When the card already lives inside a unit-scoped pill body, the
  /// caller can hide the redundant unit chip.
  final bool showUnitChip;

  static const _primary = Color(0xFF27500A);
  static const _txt2 = Color(0xFF6B7770);
  static const _danger = Color(0xFFC4393B);
  static const _amber = Color(0xFF8A5A0A);

  static const _dateFmt = 'd MMM yy';

  _Palette get _palette => switch (reminder.bucket) {
        'OVERDUE' => const _Palette(
            accent: Color(0xFFE24B4A),
            bg: Color(0xFFFEEBEB),
            label: 'OVERDUE',
            tone: _danger,
          ),
        'DUE' => const _Palette(
            accent: Color(0xFFD4912A),
            bg: Color(0xFFFFF1DD),
            label: 'DUE NOW',
            tone: _amber,
          ),
        'UPCOMING' => const _Palette(
            accent: Color(0xFF27500A),
            bg: Color(0xFFEFF5E6),
            label: 'UPCOMING',
            tone: _primary,
          ),
        'FUTURE' => const _Palette(
            accent: Color(0xFFAAAAAA),
            bg: Color(0xFFF5F5F2),
            label: 'FUTURE',
            tone: _txt2,
          ),
        'DONE' => const _Palette(
            accent: Color(0xFF6FA13E),
            bg: Color(0xFFEFF5E6),
            label: 'DONE',
            tone: _primary,
          ),
        _ => const _Palette(
            accent: Color(0xFFAAAAAA),
            bg: Color(0xFFF5F5F2),
            label: '—',
            tone: _txt2,
          ),
      };

  IconData get _icon => switch (reminder.icon) {
        'vaccine' => Icons.vaccines_outlined,
        'breeding' => Icons.female_outlined,
        'calving' => Icons.child_care_outlined,
        'farrow' => Icons.crib_outlined,
        'health' => Icons.medical_services_outlined,
        _ => Icons.event_outlined,
      };

  String _dueLabel() {
    if (reminder.effectiveDueDate == null) return '—';
    final fmt = DateFormat(_dateFmt);
    final base = fmt.format(reminder.effectiveDueDate!);
    final d = reminder.daysUntilDue;
    if (d == null) return base;
    if (d == 0) return '$base · today';
    if (d == 1) return '$base · tomorrow';
    if (d == -1) return '$base · 1d overdue';
    if (d < 0) return '$base · ${-d}d overdue';
    return '$base · in ${d}d';
  }

  @override
  Widget build(BuildContext context) {
    final p = _palette;
    final isDone = reminder.bucket == 'DONE';
    // The card has an outer Row with `crossAxisAlignment: stretch` so
    // the 4 px coloured accent strip can fill the card's full height.
    // Stretch-on-vertical needs a bounded height — IntrinsicHeight
    // gives the Row that bound by measuring the tallest child first.
    // Without it, the Row layouts under unbounded vertical constraints
    // (which it gets when sitting inside a vertical ListView body) and
    // throws box.dart:2251 / cascading mouse_tracker:199 assertions —
    // the failure mode the Layers Reminders pill was hitting.
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x14000000)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: p.accent),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: p.bg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Icon(_icon, size: 16, color: p.tone),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          reminder.title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF222222),
                            decoration: isDone
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _StatusPill(label: p.label, accent: p.accent),
                    ],
                  ),
                  if (reminder.description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      reminder.description,
                      style: const TextStyle(
                        fontSize: 12,
                        color: _txt2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            _Chip(
                              icon: Icons.calendar_today_outlined,
                              text: _dueLabel(),
                            ),
                            if (showUnitChip)
                              _Chip(
                                icon: Icons.label_outline,
                                text: reminder.unit,
                              ),
                            if (reminder.isSnoozed)
                              const _Chip(
                                icon: Icons.snooze,
                                text: 'snoozed',
                                tone: _amber,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      _ActionMenu(
                        isDone: isDone,
                        onMarkDone: onMarkDone,
                        onSnooze: onSnooze,
                        onUndo: onUndo,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }
}

class _Palette {
  const _Palette({
    required this.accent,
    required this.bg,
    required this.label,
    required this.tone,
  });
  final Color accent;
  final Color bg;
  final String label;
  final Color tone;
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.accent});
  final String label;
  final Color accent;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: accent,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.text, this.tone});
  final IconData icon;
  final String text;
  final Color? tone;
  @override
  Widget build(BuildContext context) {
    final c = tone ?? ReminderCard._txt2;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: c),
          const SizedBox(width: 3),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: c,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionMenu extends StatelessWidget {
  const _ActionMenu({
    required this.isDone,
    required this.onMarkDone,
    required this.onSnooze,
    required this.onUndo,
  });
  final bool isDone;
  final VoidCallback onMarkDone;
  final ValueChanged<int> onSnooze;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    if (isDone) {
      return TextButton.icon(
        onPressed: onUndo,
        icon: const Icon(Icons.undo, size: 14),
        label: const Text('Undo'),
        style: TextButton.styleFrom(
          foregroundColor: ReminderCard._txt2,
          textStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FilledButton.icon(
          onPressed: onMarkDone,
          icon: const Icon(Icons.check, size: 14),
          label: const Text('Done'),
          style: FilledButton.styleFrom(
            backgroundColor: ReminderCard._primary,
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 6,
            ),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        const SizedBox(width: 4),
        PopupMenuButton<int>(
          tooltip: 'Snooze',
          icon: const Icon(
            Icons.more_horiz,
            size: 18,
            color: ReminderCard._txt2,
          ),
          padding: EdgeInsets.zero,
          // Defer to a post-frame callback so the popup overlay has time
          // to finish dismissing before the parent rebuilds (the action
          // typically reorders the list, which destroys the menu's
          // anchor and otherwise crashes the mouse tracker).
          onSelected: (days) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (days == -1) {
                onUndo();
              } else {
                onSnooze(days);
              }
            });
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 1, child: Text('Snooze 1 day')),
            PopupMenuItem(value: 3, child: Text('Snooze 3 days')),
            PopupMenuItem(value: 7, child: Text('Snooze 7 days')),
            PopupMenuDivider(),
            PopupMenuItem(value: -1, child: Text('Clear snooze / done')),
          ],
        ),
      ],
    );
  }
}
