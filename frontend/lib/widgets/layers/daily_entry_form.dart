import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/layers.dart';
import '../../core/service/api_service.dart';

/// Inline daily-entry form for one house. Submits to POST /api/layers/production.
///
/// Pre-fill rules:
///   - If today's record already exists, fields show its values (re-submit
///     overwrites it idempotently — backend uses upsert).
///   - Otherwise, openingStock is suggested from the latest record's
///     closingStock; remaining inputs are blank.
///
/// Per project rule, NO computation happens here. The "trays / % laying /
/// closing" preview shown in the HTML mockup is intentionally omitted —
/// the values become visible after submit, in the response and 7-day table.
class DailyEntryForm extends StatefulWidget {
  const DailyEntryForm({
    super.key,
    required this.house,
    required this.records,
    required this.onSubmitted,
  });

  final LayerHouse house;
  final List<LayerProduction> records;
  final VoidCallback onSubmitted;

  @override
  State<DailyEntryForm> createState() => _DailyEntryFormState();
}

class _DailyEntryFormState extends State<DailyEntryForm> {
  final _formKey = GlobalKey<FormState>();
  final _openingController = TextEditingController();
  final _eggsController = TextEditingController();
  final _feedController = TextEditingController();
  final _deadController = TextEditingController();
  final _remarksController = TextEditingController();

  bool _submitting = false;

  // Log date — defaults to today, but the user can pick a past date
  // to backfill or correct yesterday's / last week's reading.
  // Mirrors the historical-session mode in the dairy milk panel:
  // when the date is set to a past day, the existing record (if any)
  // preloads into the inputs and a save overwrites that day's row.
  // Backend's upsertDailyEntry already keys on (houseId, date) and
  // accepts the optional `date` field, so this is a frontend-only
  // change to the form.
  late DateTime _logDate;

  static DateTime _midnight(DateTime d) => DateTime(d.year, d.month, d.day);
  bool get _isToday =>
      _midnight(_logDate).isAtSameMomentAs(_midnight(DateTime.now()));

  // The DB stores eggsCollected as raw eggs (integer); the user
  // enters crates (1 crate = 30 eggs — matches log_eggs_dialog and
  // the rest of the layers UI). We convert at the form boundary so
  // the storage shape doesn't change.
  static const int _eggsPerCrate = 30;

  static String _formatCrates(double crates) {
    if (crates == 0) return '0';
    // Show one decimal for partial crates; integers stay integers.
    if (crates == crates.roundToDouble()) return crates.toStringAsFixed(0);
    return crates.toStringAsFixed(1);
  }

  @override
  void initState() {
    super.initState();
    _logDate = _midnight(DateTime.now());
    _populate();
  }

  @override
  void didUpdateWidget(DailyEntryForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.house.id != widget.house.id ||
        oldWidget.records != widget.records) {
      _populate();
    }
  }

  @override
  void dispose() {
    _openingController.dispose();
    _eggsController.dispose();
    _feedController.dispose();
    _deadController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  void _populate() {
    // Find a record for the currently-picked date. In historical mode
    // this preloads the day's existing reading (edit instead of
    // re-enter); when there's no record yet for that day the inputs
    // start blank with the opening-stock suggestion seeded from the
    // last available record's closing stock.
    LayerProduction? matchRecord;
    for (final r in widget.records) {
      if (_isSameDay(r.date, _logDate)) {
        matchRecord = r;
        break;
      }
    }
    if (matchRecord != null) {
      _openingController.text = matchRecord.openingStock.toString();
      // The backend stores eggsCollected as a raw integer count; the
      // form's user-facing unit is crates (matches the rest of the
      // layers UI). Convert on display, convert back on submit. We
      // accept fractional crates because partial trays do happen
      // (e.g. 92 eggs = 3.07 crates).
      _eggsController.text =
          _formatCrates(matchRecord.eggsCollected / _eggsPerCrate);
      _feedController.text = matchRecord.feedKg.toString();
      _deadController.text = matchRecord.deadRemoved.toString();
      _remarksController.text = matchRecord.remarks ?? '';
    } else {
      // Newest record before _logDate (records arrive in ascending
      // date order). Used to seed the opening-stock guess so the
      // form is one tap away from a valid submit.
      LayerProduction? priorRecord;
      for (final r in widget.records) {
        if (r.date.isBefore(_logDate)) {
          priorRecord = r;
        } else {
          break;
        }
      }
      _openingController.text = priorRecord?.closingStock.toString() ?? '';
      _eggsController.text = '';
      _feedController.text = '';
      _deadController.text = '';
      _remarksController.text = '';
    }
  }

  Future<void> _pickLogDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _logDate,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now,
    );
    if (picked == null) return;
    final m = _midnight(picked);
    if (m.isAtSameMomentAs(_logDate)) return;
    setState(() {
      _logDate = m;
      _populate();
    });
  }

  void _backToToday() {
    final today = _midnight(DateTime.now());
    if (today.isAtSameMomentAs(_logDate)) return;
    setState(() {
      _logDate = today;
      _populate();
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final opening = int.parse(_openingController.text.trim());
    // User enters crates; backend stores raw eggs. We round here so
    // a fractional input like "3.07" submits as 92 eggs (the closest
    // whole-egg approximation of 3.07 crates).
    final crates = double.parse(_eggsController.text.trim());
    final eggs = (crates * _eggsPerCrate).round();
    final feed = _feedController.text.trim().isEmpty
        ? 0.0
        : double.parse(_feedController.text.trim());
    final dead = _deadController.text.trim().isEmpty
        ? 0
        : int.parse(_deadController.text.trim());

    setState(() => _submitting = true);
    try {
      await ApiService.createLayerProductionEntry({
        'houseId': widget.house.id,
        'openingStock': opening,
        'eggsCollected': eggs,
        'feedKg': feed,
        'deadRemoved': dead,
        // Backend keys upserts on (houseId, date). Omitting `date` in
        // today mode lets the server use its own now() — keeps the
        // wire compact for the common case. Historical mode sends
        // the picked midnight so the row routes to the right day.
        if (!_isToday) 'date': _logDate.toIso8601String(),
        if (_remarksController.text.trim().isNotEmpty)
          'remarks': _remarksController.text.trim(),
      });
      if (!mounted) return;
      widget.onSubmitted();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isToday
                ? "Today's entry saved for ${widget.house.name}"
                : "${DateFormat('d MMM').format(_logDate)} entry saved for ${widget.house.name}",
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _hexToColor(widget.house.color);
    final fullDate = DateFormat('EEEE, d MMMM').format(_logDate);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0x14000000)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily entry — ${widget.house.name}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$fullDate · Capacity ${widget.house.capacity}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton(
                  onPressed: _submitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF27500A),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _isToday
                              ? "Submit today's entry"
                              : 'Save ${DateFormat('d MMM').format(_logDate)} entry',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _DatePickerPill(
              date: _logDate,
              isToday: _isToday,
              onPick: _pickLogDate,
              onClear: _isToday ? null : _backToToday,
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final cols = constraints.maxWidth >= 720 ? 3 : 2;
                final colWidth = (constraints.maxWidth - 12 * (cols - 1)) / cols;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: colWidth,
                      child: _IntField(
                        controller: _openingController,
                        label: 'Opening stock',
                        required: true,
                      ),
                    ),
                    SizedBox(
                      width: colWidth,
                      // Crates (not raw eggs) match how the rest of the
                      // layers UI talks — Today's Egg Production card,
                      // log_eggs_dialog, the house tile's "Crates today"
                      // stat all use crates. Backend still stores eggs
                      // as an integer; the form converts at submit.
                      child: _DecimalField(
                        controller: _eggsController,
                        label: 'Crates collected',
                        required: true,
                      ),
                    ),
                    SizedBox(
                      width: colWidth,
                      child: _DecimalField(
                        controller: _feedController,
                        label: 'Feed (kg)',
                      ),
                    ),
                    SizedBox(
                      width: colWidth,
                      child: _IntField(
                        controller: _deadController,
                        label: 'Dead removed',
                      ),
                    ),
                    SizedBox(
                      width: cols == 3 ? colWidth * 2 + 12 : colWidth,
                      child: TextFormField(
                        controller: _remarksController,
                        decoration: const InputDecoration(
                          labelText: 'Remarks',
                          hintText: 'Observations, weather, etc.',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _IntField extends StatelessWidget {
  const _IntField({
    required this.controller,
    required this.label,
    this.required = false,
  });

  final TextEditingController controller;
  final String label;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: (value) {
        final v = value?.trim() ?? '';
        if (v.isEmpty) {
          return required ? '$label is required' : null;
        }
        final n = int.tryParse(v);
        if (n == null || n < 0) return 'Must be a non-negative integer';
        return null;
      },
    );
  }
}

class _DecimalField extends StatelessWidget {
  const _DecimalField({
    required this.controller,
    required this.label,
    this.required = false,
  });

  final TextEditingController controller;
  final String label;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: (value) {
        final v = value?.trim() ?? '';
        if (v.isEmpty) {
          return required ? '$label is required' : null;
        }
        final n = double.tryParse(v);
        if (n == null || n < 0) return 'Must be non-negative';
        return null;
      },
    );
  }
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

// Date-picker pill — same shape as the dairy milk panel so the
// historical-session affordance reads identically across the app.
// Today: calm green tone. Past date: amber tone + "Back to today"
// + an explicit "Editing historical entry" banner so a stale
// picker can never silently route real entries to a wrong day.
class _DatePickerPill extends StatelessWidget {
  const _DatePickerPill({
    required this.date,
    required this.isToday,
    required this.onPick,
    this.onClear,
  });

  final DateTime date;
  final bool isToday;
  final VoidCallback onPick;
  final VoidCallback? onClear;

  static const _primary = Color(0xFF27500A);
  static const _amber600 = Color(0xFFAC7B0F);
  static const _amber50 = Color(0xFFFCEDC8);

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('EEE, d MMM yyyy');
    final label = isToday ? 'Today · ${fmt.format(date)}' : fmt.format(date);
    final bg = isToday ? const Color(0xFFEAF3DE) : _amber50;
    final fg = isToday ? _primary : _amber600;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            InkWell(
              onTap: onPick,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: fg.withValues(alpha: 0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 14, color: fg),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: fg,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_drop_down, size: 18, color: fg),
                  ],
                ),
              ),
            ),
            if (!isToday)
              TextButton.icon(
                onPressed: onClear,
                icon: const Icon(Icons.refresh, size: 14),
                label: const Text('Back to today'),
                style: TextButton.styleFrom(
                  foregroundColor: _amber600,
                  textStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  minimumSize: const Size(0, 28),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
          ],
        ),
        if (!isToday) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            decoration: BoxDecoration(
              color: _amber50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _amber600.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.history, size: 14, color: _amber600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Editing historical entry — values shown are from '
                    '${fmt.format(date)}. Saving overwrites that day\'s row.',
                    style: const TextStyle(
                      fontSize: 11,
                      color: _amber600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

Color _hexToColor(String hex) {
  var s = hex.replaceAll('#', '');
  if (s.length == 6) s = 'FF$s';
  return Color(int.tryParse(s, radix: 16) ?? 0xFF27500A);
}
