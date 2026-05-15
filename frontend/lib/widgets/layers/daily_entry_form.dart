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

  @override
  void initState() {
    super.initState();
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
    final today = _startOfToday();
    LayerProduction? todayRecord;
    for (final r in widget.records) {
      if (_isSameDay(r.date, today)) {
        todayRecord = r;
        break;
      }
    }
    if (todayRecord != null) {
      _openingController.text = todayRecord.openingStock.toString();
      _eggsController.text = todayRecord.eggsCollected.toString();
      _feedController.text = todayRecord.feedKg.toString();
      _deadController.text = todayRecord.deadRemoved.toString();
      _remarksController.text = todayRecord.remarks ?? '';
    } else {
      // Newest record (records returned in ascending date order).
      final last = widget.records.isNotEmpty ? widget.records.last : null;
      _openingController.text = last?.closingStock.toString() ?? '';
      _eggsController.text = '';
      _feedController.text = '';
      _deadController.text = '';
      _remarksController.text = '';
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final opening = int.parse(_openingController.text.trim());
    final eggs = int.parse(_eggsController.text.trim());
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
        if (_remarksController.text.trim().isNotEmpty)
          'remarks': _remarksController.text.trim(),
      });
      if (!mounted) return;
      widget.onSubmitted();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Today's entry saved for ${widget.house.name}")),
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
    final dateLabel = DateFormat('EEEE, d MMMM').format(DateTime.now());

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
                        '$dateLabel · Capacity ${widget.house.capacity}',
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
                      : const Text(
                          "Submit today's entry",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ],
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
                      child: _IntField(
                        controller: _eggsController,
                        label: 'Eggs collected',
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
  const _DecimalField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

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
        if (v.isEmpty) return null;
        final n = double.tryParse(v);
        if (n == null || n < 0) return 'Must be non-negative';
        return null;
      },
    );
  }
}

DateTime _startOfToday() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

Color _hexToColor(String hex) {
  var s = hex.replaceAll('#', '');
  if (s.length == 6) s = 'FF$s';
  return Color(int.tryParse(s, radix: 16) ?? 0xFF27500A);
}
