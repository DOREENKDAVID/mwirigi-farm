// "🥚 Eggs" pill body — dedicated egg-management workspace.
//
// Sections (top → bottom):
//   1. Today's totals (crates · eggs · % of target · production %)
//   2. Inline log form — rounded inputs, one row per house, Save button
//   3. Per-house cards (LayerHouseCard with hen emoji + capacity bar)
//   4. Recent logs (last few entries from history)
//
// Logging flow:
//   On Save → POST /api/layers/production for each non-zero house →
//   call `onChanged` → parent reloads `/layers-unit`, which propagates
//   new values into the LayerHouseView list and the recent-logs slice.
//   No optimistic state; server is the source of truth.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/models/layers.dart' as legacy;
import '../../core/models/layers_unit.dart';
import '../../core/service/api_service.dart';
import 'layer_house_card.dart';

class EggsTabSection extends StatefulWidget {
  const EggsTabSection({
    super.key,
    required this.unit,
    required this.histories,
    required this.onChanged,
    this.dailyTargetCrates = 700,
  });

  final LayersUnit unit;
  final List<legacy.ProductionHistory> histories;
  final VoidCallback onChanged;
  final int dailyTargetCrates;

  @override
  State<EggsTabSection> createState() => _EggsTabSectionState();
}

class _EggsTabSectionState extends State<EggsTabSection> {
  static const _primary = Color(0xFF27500A);
  static const _txt2 = Color(0xFF6B7770);
  static const _txt3 = Color(0xFF99A39B);
  static const int _eggsPerCrate = 30;

  late Map<String, TextEditingController> _crateCtrls;
  DateTime _date = DateTime.now();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _crateCtrls = {
      for (final h in widget.unit.layers.houses) h.id: TextEditingController(),
    };
  }

  @override
  void didUpdateWidget(covariant EggsTabSection old) {
    super.didUpdateWidget(old);
    // Refresh controller map if the house list changed (e.g. parent
    // reloaded the unit and produced a new list reference).
    final ids = widget.unit.layers.houses.map((h) => h.id).toSet();
    final missing = ids.difference(_crateCtrls.keys.toSet());
    final stale = _crateCtrls.keys.toSet().difference(ids);
    if (missing.isNotEmpty || stale.isNotEmpty) {
      for (final k in stale) {
        _crateCtrls[k]?.dispose();
        _crateCtrls.remove(k);
      }
      for (final k in missing) {
        _crateCtrls[k] = TextEditingController();
      }
    }
  }

  @override
  void dispose() {
    for (final c in _crateCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  int get _enteredCrates {
    var t = 0;
    for (final c in _crateCtrls.values) {
      final n = int.tryParse(c.text.trim());
      if (n != null && n > 0) t += n;
    }
    return t;
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

  Future<void> _save() async {
    final entries = <_HouseEntry>[];
    for (final h in widget.unit.layers.houses) {
      final raw = _crateCtrls[h.id]!.text.trim();
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
      _toast('Enter crates for at least one house.');
      return;
    }

    setState(() => _submitting = true);
    var saved = 0;
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
      // Clear inputs so the form is ready for the next pass.
      for (final c in _crateCtrls.values) {
        c.clear();
      }
      _toast('Logged eggs for $saved house${saved == 1 ? '' : 's'}');
      // Trigger parent reload so per-house cards + KPIs reflect the
      // new server-side state without a manual refresh.
      widget.onChanged();
    } catch (err) {
      final msg = saved > 0
          ? 'Saved $saved/${entries.length}. '
              '${err.toString().replaceFirst('Exception: ', '')}'
          : err.toString().replaceFirst('Exception: ', '');
      _toast(msg);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final houses = widget.unit.layers.houses;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TodaySummary(
          unit: widget.unit,
          dailyTargetCrates: widget.dailyTargetCrates,
        ),
        const SizedBox(height: 16),
        _LogForm(
          date: _date,
          onPickDate: _submitting ? null : _pickDate,
          enteredCrates: _enteredCrates,
          submitting: _submitting,
          houses: houses,
          controllers: _crateCtrls,
          onChanged: () => setState(() {}),
          onSave: _save,
        ),
        const SizedBox(height: 16),
        _SectionHeader(
          title: '🐔  HOUSES — TODAY',
          trailing: '${houses.length} hou${houses.length == 1 ? "se" : "ses"}',
        ),
        const SizedBox(height: 8),
        // Cards auto-update via parent reload after POST — values come
        // straight from the LayerHouseView, never recomputed locally.
        LayerHousesGrid(houses: houses),
        for (final h in widget.histories.where((h) => h.records.isNotEmpty)) ...[
          const SizedBox(height: 18),
          _RecentLogs(history: h),
        ],
      ],
    );
  }
}

class _HouseEntry {
  _HouseEntry({required this.house, required this.crates});
  final LayerHouseView house;
  final int crates;
}

// ---------------------------------------------------------------
// Today's summary header
// ---------------------------------------------------------------

class _TodaySummary extends StatelessWidget {
  const _TodaySummary({required this.unit, required this.dailyTargetCrates});
  final LayersUnit unit;
  final int dailyTargetCrates;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern();
    final crates = unit.layers.cratesToday;
    final eggs = (crates * 30).toInt();
    final birds = unit.layers.totalBirds;
    final pctTarget = dailyTargetCrates > 0
        ? ((crates / dailyTargetCrates) * 100).round()
        : 0;
    final pctLaying = birds > 0
        ? ((eggs / birds) * 100).clamp(0, 200).toDouble()
        : 0.0;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x14000000)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            "🥚  TODAY'S EGG PRODUCTION",
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: _EggsTabSectionState._primary,
            ),
          ),
          const SizedBox(height: 12),
          // Three tiles always rendered side-by-side. `Expanded` lets
          // each tile pick up an equal share of the row width, even on
          // narrow phones, and the inner text wraps within the tile.
          //
          // IntrinsicHeight + stretch makes the three cards visually
          // line up at the same height without forcing an infinite
          // vertical constraint (the ListView this lives inside is
          // unbounded — stretch alone would crash).
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _SummaryTile(
                    label: 'Crates',
                    value: _fmtNum(crates),
                    sub: '$pctTarget% of $dailyTargetCrates target',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SummaryTile(
                    label: 'Eggs',
                    value: fmt.format(eggs),
                    sub: '${fmt.format(birds)} hens',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SummaryTile(
                    label: 'Production',
                    value: '${pctLaying.toStringAsFixed(0)}%',
                    sub: pctLaying >= 80
                        ? 'Strong'
                        : pctLaying >= 60
                            ? 'On track'
                            : 'Below target',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _fmtNum(num n) {
    if (n == n.roundToDouble()) {
      return NumberFormat.decimalPattern().format(n.toInt());
    }
    return n.toStringAsFixed(1);
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
    required this.sub,
  });
  final String label;
  final String value;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8F4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: _EggsTabSectionState._txt2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: _EggsTabSectionState._primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            style: const TextStyle(
              fontSize: 11,
              color: _EggsTabSectionState._txt3,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------
// Inline log form
// ---------------------------------------------------------------

class _LogForm extends StatelessWidget {
  const _LogForm({
    required this.date,
    required this.onPickDate,
    required this.enteredCrates,
    required this.submitting,
    required this.houses,
    required this.controllers,
    required this.onChanged,
    required this.onSave,
  });

  final DateTime date;
  final VoidCallback? onPickDate;
  final int enteredCrates;
  final bool submitting;
  final List<LayerHouseView> houses;
  final Map<String, TextEditingController> controllers;
  final VoidCallback onChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x14000000)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Text(
                '✏️  LOG EGG PRODUCTION',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: _EggsTabSectionState._primary,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Crates per house — saves on tap',
                  style: TextStyle(
                    fontSize: 11,
                    color: _EggsTabSectionState._txt3,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth >= 520;
              final dateField = _Field(
                label: 'Date',
                child: InkWell(
                  onTap: onPickDate,
                  borderRadius: BorderRadius.circular(14),
                  child: InputDecorator(
                    decoration: _decoration(suffixIcon: const Padding(
                      padding: EdgeInsets.only(right: 10),
                      child: Icon(
                        Icons.calendar_month_outlined,
                        size: 18,
                        color: Color(0xFF6B7770),
                      ),
                    )),
                    child: Text(
                      DateFormat('dd MMM yyyy').format(date),
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              );
              final totalField = _Field(
                label: 'Total crates',
                child: InputDecorator(
                  decoration: _decoration().copyWith(
                    filled: true,
                    fillColor: const Color(0xFFF6F8F4),
                  ),
                  child: Text(
                    enteredCrates == 0 ? '0' : '$enteredCrates',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: enteredCrates == 0
                          ? const Color(0xFF99A39B)
                          : _EggsTabSectionState._primary,
                    ),
                  ),
                ),
              );
              return wide
                  ? Row(
                      children: [
                        Expanded(child: dateField),
                        const SizedBox(width: 12),
                        Expanded(child: totalField),
                      ],
                    )
                  : Column(
                      children: [
                        dateField,
                        const SizedBox(height: 12),
                        totalField,
                      ],
                    );
            },
          ),
          const SizedBox(height: 12),
          // Per-house inputs — one row each, full-width on mobile, paired
          // on wider screens.
          LayoutBuilder(
            builder: (context, c) {
              final perRow = c.maxWidth >= 700
                  ? 3
                  : c.maxWidth >= 460
                      ? 2
                      : 1;
              final cellW = (c.maxWidth - 12 * (perRow - 1)) / perRow;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final h in houses)
                    SizedBox(
                      width: cellW,
                      child: _Field(
                        label: '🐔  ${h.name}',
                        child: TextField(
                          controller: controllers[h.id],
                          enabled: !submitting,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: (_) => onChanged(),
                          decoration: _decoration(
                            hint: 'crates',
                            suffix: 'crates',
                          ),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: submitting ? null : onSave,
                  icon: submitting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check, size: 18),
                  label: Text(submitting ? 'Saving…' : 'Save logs'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _EggsTabSectionState._primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static InputDecoration _decoration({
    String? hint,
    String? suffix,
    Widget? suffixIcon,
  }) {
    const radius = BorderRadius.all(Radius.circular(14));
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        fontSize: 13,
        color: Color(0xFF99A39B),
        fontWeight: FontWeight.w500,
      ),
      suffixText: suffix,
      suffixStyle: const TextStyle(
        fontSize: 12,
        color: Color(0xFF6B7770),
        fontWeight: FontWeight.w600,
      ),
      suffixIcon: suffixIcon,
      isDense: true,
      filled: true,
      fillColor: const Color(0xFFF6F8F4),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: const OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: Color(0x14000000)),
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: Color(0x14000000)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: Color(0xFF27500A), width: 1.6),
      ),
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
          padding: const EdgeInsets.only(bottom: 6, left: 4),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: _EggsTabSectionState._txt2,
            ),
          ),
        ),
        child,
      ],
    );
  }
}

// ---------------------------------------------------------------
// Recent logs (last 5 days from the per-house history slice)
// ---------------------------------------------------------------

class _RecentLogs extends StatelessWidget {
  const _RecentLogs({required this.history});
  final legacy.ProductionHistory history;

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('d MMM');
    final rows = history.records.take(5).toList();
    if (rows.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                '📋  RECENT LOGS — ${history.house.name.toUpperCase()}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: _EggsTabSectionState._primary,
                ),
              ),
              const Spacer(),
              Text(
                'last ${rows.length}',
                style: const TextStyle(
                  fontSize: 11,
                  color: _EggsTabSectionState._txt3,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < rows.length; i++) ...[
            _LogRow(record: rows[i], dateFmt: dateFmt),
            if (i != rows.length - 1)
              const Divider(height: 16, color: Color(0x10000000)),
          ],
        ],
      ),
    );
  }
}

class _LogRow extends StatelessWidget {
  const _LogRow({required this.record, required this.dateFmt});
  final legacy.LayerProduction record;
  final DateFormat dateFmt;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern();
    return Row(
      children: [
        Container(
          width: 50,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFF6F8F4),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            dateFmt.format(record.date),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _EggsTabSectionState._primary,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${fmt.format(record.eggsCollected)} eggs · '
                '${_fmt(record.trays)} crates',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF222222),
                ),
              ),
              Text(
                'opening ${fmt.format(record.openingStock)} · '
                'feed ${_fmt(record.feedKg)}kg · '
                'dead ${record.deadRemoved}',
                style: const TextStyle(
                  fontSize: 11,
                  color: _EggsTabSectionState._txt2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF5E6),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '${record.percentLaying.toStringAsFixed(0)}%',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: _EggsTabSectionState._primary,
            ),
          ),
        ),
      ],
    );
  }

  static String _fmt(num n) {
    if (n == n.roundToDouble()) return n.toInt().toString();
    return n.toStringAsFixed(1);
  }
}

// ---------------------------------------------------------------
// Section header
// ---------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.trailing});
  final String title;
  final String trailing;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            color: _EggsTabSectionState._primary,
          ),
        ),
        const Spacer(),
        Text(
          trailing,
          style: const TextStyle(
            fontSize: 11,
            color: _EggsTabSectionState._txt3,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
