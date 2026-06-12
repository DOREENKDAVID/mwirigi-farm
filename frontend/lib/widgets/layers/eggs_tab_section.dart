// "🥚 Eggs" pill body — dedicated egg-management workspace.
//
// Sections (top → bottom):
//   1. Date summary (crates · eggs · % of target · production %)
//      — reflects the selected date, not necessarily today
//   2. Inline log form — rounded inputs, one row per house, Save button
//   3. Per-house cards (LayerHouseCard with hen emoji + capacity bar)
//   4. Historical logs for the selected date
//
// Date-aware flow:
//   • Default _date = today → summary shows widget.unit KPIs; Recent Logs
//     shows the last-7-day window already fetched by the parent.
//   • User picks a past date → _loadHistoriesForDate fires a per-house GET
//     with ?date=ISO; Recent Logs renders only that day's records; summary
//     tiles compute from the fetched records.
//   • On Save → POST /api/layers/production for each non-zero house →
//     call `onChanged` (parent reloads KPIs/houses); if on a past date also
//     re-fetches that date's history locally.

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
  late TextEditingController _householdCtrl;
  DateTime _date = DateTime.now();
  bool _submitting = false;

  // History slice for the currently-selected date. Initialised from the
  // parent's 7-day window (already fetched). Replaced with a single-day
  // fetch whenever the user picks a past date.
  List<legacy.ProductionHistory> _dateHistories = const [];
  bool _historyLoading = false;

  // ── helpers ──────────────────────────────────────────────────────────────

  bool get _isToday {
    final now = DateTime.now();
    return _date.year == now.year &&
        _date.month == now.month &&
        _date.day == now.day;
  }

  // Records from whichever history slice is active that match _date exactly.
  List<legacy.LayerProduction> get _recordsForDate {
    final source = _isToday ? widget.histories : _dateHistories;
    return source
        .expand((h) => h.records)
        .where((r) =>
            r.date.year == _date.year &&
            r.date.month == _date.month &&
            r.date.day == _date.day)
        .toList();
  }

  // Total eggs for _date. Falls back to the unit snapshot when today has
  // no records logged yet (e.g. first thing in the morning).
  int get _summaryEggs {
    final recs = _recordsForDate;
    if (recs.isEmpty && _isToday) {
      return (widget.unit.layers.cratesToday * _eggsPerCrate).toInt();
    }
    return recs.fold(0, (s, r) => s + r.eggsCollected);
  }

  // Total opening stock for _date. Falls back to live bird count when no
  // records exist for that day.
  int get _summaryBirds {
    final recs = _recordsForDate;
    if (recs.isEmpty) return widget.unit.layers.totalBirds;
    return recs.fold(0, (s, r) => s + r.openingStock);
  }

  // ── lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _crateCtrls = {
      for (final h in widget.unit.layers.houses) h.id: TextEditingController(),
    };
    _householdCtrl = TextEditingController();
    _dateHistories = widget.histories;
  }

  @override
  void didUpdateWidget(covariant EggsTabSection old) {
    super.didUpdateWidget(old);
    // Parent reloaded (e.g. after a save) — sync the today-view history slice
    // so Recent Logs stays fresh without an extra fetch.
    if (_isToday) _dateHistories = widget.histories;

    // Refresh controller map if the house list changed.
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
    _householdCtrl.dispose();
    super.dispose();
  }

  // ── data loading ──────────────────────────────────────────────────────────

  Future<void> _loadHistoriesForDate(DateTime date) async {
    setState(() => _historyLoading = true);
    try {
      final results = await Future.wait(
        widget.unit.layers.houses.map((h) async {
          try {
            final raw = await ApiService.getLayersProductionForHouse(
              h.id,
              date: date,
            );
            return legacy.ProductionHistory.fromJson(
              raw.cast<String, dynamic>(),
            );
          } catch (_) {
            return null;
          }
        }),
      );
      if (mounted) {
        setState(() {
          _dateHistories =
              results.whereType<legacy.ProductionHistory>().toList();
        });
      }
    } finally {
      if (mounted) setState(() => _historyLoading = false);
    }
  }

  // ── user actions ──────────────────────────────────────────────────────────

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
    if (picked == null || !mounted) return;
    setState(() => _date = picked);
    // Today → use parent's already-fetched window; past date → fetch for
    // that specific day so Recent Logs shows only those records.
    final pickedIsToday = picked.year == now.year &&
        picked.month == now.month &&
        picked.day == now.day;
    if (!pickedIsToday) {
      await _loadHistoriesForDate(picked);
    }
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
    final householdUsed = int.tryParse(_householdCtrl.text.trim()) ?? 0;
    try {
      for (var i = 0; i < entries.length; i++) {
        final e = entries[i];
        await ApiService.createLayerProductionEntry({
          'houseId': e.house.id,
          'date': iso,
          'openingStock': e.house.birdCount,
          'eggsCollected': e.crates * _eggsPerCrate,
          // Attribute all household usage to the first house entry only,
          // so the per-farm sum remains correct after the backend aggregates.
          if (i == 0 && householdUsed > 0) 'householdUsed': householdUsed,
        });
        saved += 1;
      }
      for (final c in _crateCtrls.values) {
        c.clear();
      }
      _toast('Logged eggs for $saved house${saved == 1 ? '' : 's'}');
      // Parent refreshes KPIs + house cards.
      widget.onChanged();
      // For a past date the parent only reloads today's data, so also
      // refresh our local history slice for _date.
      if (!_isToday) {
        _loadHistoriesForDate(_date);
      }
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

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final houses = widget.unit.layers.houses;
    // For today → show parent's 7-day recent window; for past → show
    // the single-day slice we fetched.
    final displayHistories = _isToday ? widget.histories : _dateHistories;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DateSummary(
          date: _date,
          eggs: _summaryEggs,
          birds: _summaryBirds,
          dailyTargetCrates: widget.dailyTargetCrates,
          loading: _historyLoading,
        ),
        const SizedBox(height: 16),
        _LogForm(
          date: _date,
          onPickDate: _submitting ? null : _pickDate,
          enteredCrates: _enteredCrates,
          submitting: _submitting,
          houses: houses,
          controllers: _crateCtrls,
          householdCtrl: _householdCtrl,
          onChanged: () => setState(() {}),
          onSave: _save,
        ),
        const SizedBox(height: 16),
        _SectionHeader(
          title: '🐔  HOUSES — TODAY',
          trailing: '${houses.length} hou${houses.length == 1 ? "se" : "ses"}',
        ),
        const SizedBox(height: 8),
        LayerHousesGrid(houses: houses),
        if (_historyLoading) ...[
          const SizedBox(height: 24),
          const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ] else
          for (final h in displayHistories.where((h) => h.records.isNotEmpty)) ...[
            const SizedBox(height: 18),
            _RecentLogs(history: h, singleDay: !_isToday),
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
// Date summary header — reflects the selected date, not always today
// ---------------------------------------------------------------

class _DateSummary extends StatelessWidget {
  const _DateSummary({
    required this.date,
    required this.eggs,
    required this.birds,
    required this.dailyTargetCrates,
    required this.loading,
  });

  final DateTime date;
  final int eggs;
  final int birds;
  final int dailyTargetCrates;
  final bool loading;

  static const int _eggsPerCrate = 30;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern();
    final crates = eggs / _eggsPerCrate;
    final pctTarget = dailyTargetCrates > 0
        ? ((crates / dailyTargetCrates) * 100).round()
        : 0;
    final pctLaying = birds > 0
        ? ((eggs / birds) * 100).clamp(0, 200).toDouble()
        : 0.0;

    final now = DateTime.now();
    final isToday = date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
    final title = isToday
        ? "🥚  TODAY'S EGG PRODUCTION"
        : "🥚  EGG PRODUCTION — ${DateFormat('d MMM yyyy').format(date)}";

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
          Row(
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
              if (loading) ...[
                const Spacer(),
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _EggsTabSectionState._primary,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
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
    required this.householdCtrl,
    required this.onChanged,
    required this.onSave,
  });

  final DateTime date;
  final VoidCallback? onPickDate;
  final int enteredCrates;
  final bool submitting;
  final List<LayerHouseView> houses;
  final Map<String, TextEditingController> controllers;
  final TextEditingController householdCtrl;
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
          const SizedBox(height: 12),
          _Field(
            label: '🏠  Household Used (eggs) — optional',
            child: TextField(
              controller: householdCtrl,
              enabled: !submitting,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => onChanged(),
              decoration: _decoration(hint: '0', suffix: 'eggs'),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
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
// Recent logs — last 5 records for today, or the single record
// for a past date.
// ---------------------------------------------------------------

class _RecentLogs extends StatelessWidget {
  const _RecentLogs({required this.history, this.singleDay = false});
  final legacy.ProductionHistory history;
  final bool singleDay;

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('d MMM');
    final rows = history.records.take(5).toList();
    if (rows.isEmpty) {
      return const SizedBox.shrink();
    }
    final countLabel = singleDay
        ? '${rows.length} entr${rows.length == 1 ? 'y' : 'ies'}'
        : 'last ${rows.length}';
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
                countLabel,
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
                record.householdUsed > 0
                    ? 'avail ${fmt.format(record.availableEggs)} · '
                        'household ${record.householdUsed} · '
                        'opening ${fmt.format(record.openingStock)} · '
                        'dead ${record.deadRemoved}'
                    : 'opening ${fmt.format(record.openingStock)} · '
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
