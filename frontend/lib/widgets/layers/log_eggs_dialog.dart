import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/models/layers_unit.dart';
import '../../core/service/api_service.dart';

/// Quick "Log Egg Production" dialog for a single day, across every layer
/// house in one shot. Mirrors the design mock:
///
///   Date *                 |  Total Crates *   (auto-summed, read-only)
///   House A | House B | House C   (per-house crate inputs)
///   [Save]  [Cancel]
///
/// Submits one POST per house with non-zero crates. Each POST goes to
/// `/layers/production`, converting crates → eggs (1 crate = 30 eggs)
/// and using the house's current `birdCount` as `openingStock`.
///
/// Returns `true` (count > 0) on the first successful save so the caller
/// can refresh.
class LogEggsDialog extends StatefulWidget {
  const LogEggsDialog({super.key, required this.houses});
  final List<LayerHouseView> houses;

  @override
  State<LogEggsDialog> createState() => _LogEggsDialogState();
}

class _LogEggsDialogState extends State<LogEggsDialog> {
  // 1 crate = 30 eggs. Mirrors the convention used in the layers seed
  // and the daily-entry form (trays = eggsCollected / 30).
  static const int _eggsPerCrate = 30;

  late final Map<String, TextEditingController> _crateControllers;

  DateTime _date = DateTime.now();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _crateControllers = {
      for (final h in widget.houses) h.id: TextEditingController(),
    };
  }

  @override
  void dispose() {
    for (final c in _crateControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // Sum of every house's crate input, ignoring blanks/invalid entries.
  // Re-runs on every keystroke (we call setState in onChanged).
  int get _totalCrates {
    var total = 0;
    for (final c in _crateControllers.values) {
      final n = int.tryParse(c.text.trim());
      if (n != null && n > 0) total += n;
    }
    return total;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    final entries = <_HouseEntry>[];
    for (final h in widget.houses) {
      final raw = _crateControllers[h.id]!.text.trim();
      if (raw.isEmpty) continue;
      final crates = int.tryParse(raw);
      if (crates == null || crates < 0) {
        _toast('${h.name}: enter a whole number of crates (≥ 0)');
        return;
      }
      if (crates == 0) continue;
      entries.add(_HouseEntry(house: h, crates: crates));
    }
    if (entries.isEmpty) {
      _toast('Enter crate counts for at least one house.');
      return;
    }

    setState(() => _submitting = true);
    int saved = 0;
    final iso = _date.toIso8601String();
    try {
      for (final e in entries) {
        await ApiService.createLayerProductionEntry({
          'houseId': e.house.id,
          'date': iso,
          'openingStock': e.house.birdCount,
          'eggsCollected': e.crates * _eggsPerCrate,
        });
        saved += 1;
      }
      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } catch (err) {
      if (!mounted) return;
      setState(() => _submitting = false);
      // Partial-success path: some saves landed before this one threw.
      // Surface the count so the user knows what got through.
      final msg = saved > 0
          ? 'Saved ${entries[0].house.name}…${entries[saved - 1].house.name} '
              '($saved/${entries.length}). ${err.toString().replaceFirst('Exception: ', '')}'
          : err.toString().replaceFirst('Exception: ', '');
      _toast(msg);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF27500A);
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Log Egg Production',
                style: TextStyle(
                  color: primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                "Today's crate count per house",
                style: TextStyle(fontSize: 13, color: Color(0xFF7A7A7A)),
              ),
              const SizedBox(height: 22),

              // Row 1: Date + Total Crates (auto-summed, read-only).
              _TwoCol(
                left: _Field(
                  label: 'DATE *',
                  child: InkWell(
                    onTap: _submitting ? null : _pickDate,
                    borderRadius: BorderRadius.circular(8),
                    child: InputDecorator(
                      decoration: _decoration().copyWith(
                        suffixIcon: const Padding(
                          padding: EdgeInsets.only(right: 10),
                          child: Icon(
                            Icons.calendar_month_outlined,
                            size: 20,
                            color: Color(0xFF555555),
                          ),
                        ),
                      ),
                      child: Text(
                        DateFormat('dd/MM/yyyy').format(_date),
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                ),
                right: _Field(
                  label: 'TOTAL CRATES *',
                  child: InputDecorator(
                    decoration: _decoration().copyWith(
                      filled: true,
                      fillColor: const Color(0xFFFAFAF7),
                    ),
                    child: Text(
                      _totalCrates == 0 ? '0' : '$_totalCrates',
                      style: TextStyle(
                        fontSize: 15,
                        color: _totalCrates == 0
                            ? const Color(0xFF999999)
                            : Colors.black87,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Per-house crate inputs.
              LayoutBuilder(
                builder: (context, c) {
                  final wide = c.maxWidth >= 460;
                  final fields = [
                    for (final h in widget.houses)
                      _Field(
                        label: h.name.toUpperCase(),
                        child: TextField(
                          controller: _crateControllers[h.id],
                          enabled: !_submitting,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: (_) => setState(() {}),
                          decoration: _decoration(),
                        ),
                      ),
                  ];
                  if (!wide) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < fields.length; i++) ...[
                          fields[i],
                          if (i < fields.length - 1)
                            const SizedBox(height: 14),
                        ],
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < fields.length; i++) ...[
                        Expanded(child: fields[i]),
                        if (i < fields.length - 1) const SizedBox(width: 14),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 28),

              // Save + Cancel — bottom-left, matching the mock.
              Row(
                children: [
                  FilledButton(
                    onPressed: _submitting ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 14,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
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
                        : const Text('Save'),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton(
                    onPressed: _submitting
                        ? null
                        : () => Navigator.of(context).pop(0),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF555555),
                      side: const BorderSide(color: Color(0x33000000)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 14,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Shared input style — flat, soft border, 8px radius, focus turns
  // green to match the design mock.
  InputDecoration _decoration() {
    return const InputDecoration(
      isDense: true,
      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(color: Color(0x22000000)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(color: Color(0x22000000)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(color: Color(0xFF27500A), width: 1.6),
      ),
    );
  }
}

class _HouseEntry {
  _HouseEntry({required this.house, required this.crates});
  final LayerHouseView house;
  final int crates;
}

// Two-column row that collapses to a single column on narrow screens.
class _TwoCol extends StatelessWidget {
  const _TwoCol({required this.left, required this.right});
  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 460) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [left, const SizedBox(height: 18), right],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            const SizedBox(width: 18),
            Expanded(child: right),
          ],
        );
      },
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6, left: 2),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: Color(0xFF7A7A7A),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
