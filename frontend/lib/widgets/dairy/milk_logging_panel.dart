import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/models/dairy_ops.dart';
import '../../core/service/api_service.dart';
import 'edit_milk_deductions_dialog.dart';

/// "Milk logging" card — the primary daily dairy workflow per the v4.1
/// HTML mockup. Composition top → bottom:
///
///   1. Card header + Manager-view toggle button.
///   2. Session tabs (AM · Midday · PM) with "logged/total" counts.
///   3. Worker bar — pills for each dairy worker. Tap a worker to enter
///      their cow grid for the active session.
///   4. Worker view body — once a worker is selected:
///        a. Cow grid: per-cow numeric input, prefilled with today's
///           reading if any. Auto-flagged below-avg cows are marked.
///        b. Live worker subtotal + Submit button.
///        c. Summary panel: gross / calf / household / net for this
///           session, plus the across-session day totals.
///   5. Manager view body — when toggled on:
///        a. Per-worker rollup table (cows · AM · MID · PM · total).
///        b. Below-average readings list (cow · house · worker · session).
///
/// State ownership:
///   * `_today` — last fetched TodaySessions snapshot (refreshed after
///     every successful submit + on parent reload).
///   * `_selectedSession` / `_selectedWorkerId` — active tab + worker.
///   * `_drafts` — per-cow text controllers for the active worker/session.
///   * `_managerView` — toggle for the alternate aggregate view.
///
/// The widget is self-contained: parent passes a `houseFilterId` (set
/// from the Houses overview grid) and an optional `onChanged` callback
/// for KPI refreshes.
class MilkLoggingPanel extends StatefulWidget {
  const MilkLoggingPanel({
    super.key,
    this.houseFilterId,
    this.onChanged,
    this.houses = const [],
  });

  /// When non-null, the worker bar + cow grid filter to cows in this
  /// house. The filter is applied client-side over the today-sessions
  /// payload so we don't need a separate endpoint.
  final String? houseFilterId;

  /// Fired after every successful session submit so the parent can
  /// refresh KPI cards / houses overview.
  final VoidCallback? onChanged;

  /// Houses list — used to render the small "HA" / "HB" tag on cow
  /// cards and the per-house labels in the manager view.
  final List<DairyHouseOverview> houses;

  @override
  State<MilkLoggingPanel> createState() => MilkLoggingPanelState();
}

class MilkLoggingPanelState extends State<MilkLoggingPanel> {
  static const _flagBg = Color(0xFFFCEBEB);
  static const _flagFg = Color(0xFFB42318);

  Future<TodaySessions>? _futureToday;
  Future<DayNetSummary>? _futureSummary;

  TodaySessions? _today;

  MilkSession _selectedSession = MilkSession.am;
  String? _selectedWorkerId;
  bool _managerView = false;
  bool _submitting = false;

  // Per-cow draft inputs — recreated whenever the active worker /
  // session changes so editing a different worker doesn't carry stale
  // values.
  final Map<String, TextEditingController> _drafts = {};

  @override
  void initState() {
    super.initState();
    _futureToday = _loadToday();
    _futureSummary = _loadSummary();
  }

  @override
  void dispose() {
    for (final c in _drafts.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<TodaySessions> _loadToday() async {
    final raw = await ApiService.getDairyTodaySessions();
    final t = TodaySessions.fromJson(raw);
    _today = t;
    // If no worker is selected yet, pick the first one with cows so the
    // UI lands in a useful state.
    if (_selectedWorkerId == null && t.workers.isNotEmpty) {
      _selectedWorkerId = t.workers.first.id;
      _seedDraftsForActiveSelection();
    }
    return t;
  }

  Future<DayNetSummary> _loadSummary() async {
    final raw = await ApiService.getDairyTodayNet();
    return DayNetSummary.fromJson(raw);
  }

  Future<void> reload() async {
    setState(() {
      _futureToday = _loadToday();
      _futureSummary = _loadSummary();
    });
    await Future.wait([_futureToday!, _futureSummary!]);
  }

  // Find the active worker view (post-house-filter).
  WorkerSessionView? get _activeWorker {
    final t = _today;
    if (t == null || _selectedWorkerId == null) return null;
    try {
      return t.workers.firstWhere((w) => w.id == _selectedWorkerId);
    } catch (_) {
      return null;
    }
  }

  // The cows the active worker is currently logging — filtered by the
  // optional house selection AND excluding PREGNANT cows (they're not
  // milking; surfaced via the maternity callout instead).
  List<CowSessionView> get _activeCows {
    final w = _activeWorker;
    if (w == null) return const [];
    final filterId = widget.houseFilterId;
    return w.cows.where((c) {
      if (c.status == 'PREGNANT') return false;
      if (filterId != null && c.houseId != filterId) return false;
      return true;
    }).toList();
  }

  // Count of PREGNANT cows belonging to the active worker (post house
  // filter). Drives the "N of <Worker>'s cows are in maternity" line.
  int get _activeMaternityCount {
    final w = _activeWorker;
    if (w == null) return 0;
    final filterId = widget.houseFilterId;
    return w.cows.where((c) {
      if (c.status != 'PREGNANT') return false;
      if (filterId != null && c.houseId != filterId) return false;
      return true;
    }).length;
  }

  // House id → short letter label ("Dairy A" → "HA"). Maternity is
  // surfaced separately as a callout, so it gets a generic emoji
  // fallback. Built once per build from `widget.houses`.
  Map<String, String> _houseLabels() {
    final out = <String, String>{};
    for (final h in widget.houses) {
      if (h.id == '__maternity__') continue;
      // "Dairy A" → "HA"; falls back to first 2 chars otherwise.
      final stripped = h.name.replaceFirst(RegExp(r'^Dairy\s+'), '');
      final letter = stripped.isNotEmpty ? stripped.substring(0, 1) : '?';
      out[h.id] = 'H$letter';
    }
    return out;
  }

  void _seedDraftsForActiveSelection() {
    // Dispose old controllers; we don't need to keep them since the
    // server is the source of truth and we re-seed on every change.
    for (final c in _drafts.values) {
      c.dispose();
    }
    _drafts.clear();

    for (final cow in _activeCows) {
      final entry = cow.entries[_selectedSession];
      _drafts[cow.id] = TextEditingController(
        text: entry == null ? '' : _fmtLitres(entry),
      );
    }
  }

  void _setSession(MilkSession s) {
    if (s == _selectedSession) return;
    setState(() {
      _selectedSession = s;
      _seedDraftsForActiveSelection();
    });
  }

  void _setWorker(String workerId) {
    if (workerId == _selectedWorkerId) return;
    setState(() {
      _selectedWorkerId = workerId;
      _seedDraftsForActiveSelection();
    });
  }

  // Live subtotal — reads the in-flight TextEditingController values
  // rather than the persisted entries, so user keystrokes update the
  // total before they hit Submit.
  double get _liveSubtotal {
    var total = 0.0;
    for (final cow in _activeCows) {
      final n = double.tryParse(_drafts[cow.id]?.text.trim() ?? '');
      if (n != null && n > 0) total += n;
    }
    return total;
  }

  Future<void> _submit() async {
    final w = _activeWorker;
    if (w == null) return;
    final entries = <Map<String, dynamic>>[];
    for (final cow in _activeCows) {
      final raw = _drafts[cow.id]?.text.trim() ?? '';
      if (raw.isEmpty) continue;
      final n = double.tryParse(raw);
      if (n == null || n <= 0 || n > 100) continue;
      entries.add({'cowId': cow.id, 'litres': n});
    }
    if (entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter at least one reading.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final res = await ApiService.submitDairyMilkSession(
        workerId: w.id,
        session: _selectedSession.wire,
        entries: entries,
      );
      // Endpoint returns the refreshed today-sessions in `data`.
      final dataRaw = res['data'];
      if (dataRaw is Map) {
        _today = TodaySessions.fromJson(dataRaw.cast<String, dynamic>());
      }
      // Refresh the day-net summary independently (separate endpoint).
      final netRaw = await ApiService.getDairyTodayNet();
      if (!mounted) return;
      setState(() {
        _futureSummary = Future.value(DayNetSummary.fromJson(netRaw));
        _seedDraftsForActiveSelection();
        _submitting = false;
      });
      widget.onChanged?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Saved ${entries.length} reading${entries.length == 1 ? '' : 's'} '
            'for ${w.name} (${_selectedSession.label}).',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  /// Open the deductions edit dialog and refetch the day-net summary
  /// after a save so the calf + household lines reflect the override
  /// (or the reverted auto-detect) immediately.
  Future<void> _openEditDeductions(DayNetSummary current) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => EditMilkDeductionsDialog(summary: current),
    );
    if (saved != true || !mounted) return;
    try {
      final raw = await ApiService.getDairyTodayNet();
      if (!mounted) return;
      setState(() {
        _futureSummary = Future.value(DayNetSummary.fromJson(raw));
      });
      widget.onChanged?.call();
    } catch (_) {
      // best-effort refresh — the dialog already toasted on its own
      // error path; nothing to do here.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: FutureBuilder<TodaySessions>(
        future: _futureToday,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const SizedBox(
              height: 240,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snap.hasError) {
            return _ErrorBlock(
              message:
                  snap.error.toString().replaceFirst('Exception: ', ''),
              onRetry: reload,
            );
          }
          final today = snap.data!;
          if (today.workers.isEmpty) {
            return const _EmptyBlock(
              message: 'No dairy workers configured yet.',
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(
                managerView: _managerView,
                onToggle: () =>
                    setState(() => _managerView = !_managerView),
                activeWorker: _activeWorker?.name,
                activeMilkingCount: _activeWorker == null
                    ? null
                    : _activeCows.length,
                activeSession: _selectedSession,
              ),
              const SizedBox(height: 10),
              _SessionTabs(
                today: today,
                selected: _selectedSession,
                onSelect: _setSession,
              ),
              const SizedBox(height: 14),
              if (_managerView)
                FutureBuilder<DayNetSummary>(
                  future: _futureSummary,
                  builder: (context, sumSnap) => _ManagerView(
                    today: today,
                    session: _selectedSession,
                    summary: sumSnap.data,
                  ),
                )
              else
                _WorkerView(
                  today: today,
                  selectedWorker: _selectedWorkerId,
                  onPickWorker: _setWorker,
                  selectedSession: _selectedSession,
                  activeCows: _activeCows,
                  drafts: _drafts,
                  liveSubtotal: _liveSubtotal,
                  submitting: _submitting,
                  onSubmit: _submit,
                  onTextChanged: () => setState(() {}),
                  houseLabels: _houseLabels(),
                  maternityCount: _activeMaternityCount,
                  activeWorkerName: _activeWorker?.name,
                ),
              const SizedBox(height: 16),
              FutureBuilder<DayNetSummary>(
                future: _futureSummary,
                builder: (context, sumSnap) {
                  if (!sumSnap.hasData) return const SizedBox.shrink();
                  return _SummaryGrid(
                    today: today,
                    session: _selectedSession,
                    summary: sumSnap.data!,
                    onEditDeductions: () => _openEditDeductions(sumSnap.data!),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

// ===== Header =====

class _Header extends StatelessWidget {
  const _Header({
    required this.managerView,
    required this.onToggle,
    this.activeWorker,
    this.activeMilkingCount,
    this.activeSession,
  });
  final bool managerView;
  final VoidCallback onToggle;
  final String? activeWorker;
  final int? activeMilkingCount;
  final MilkSession? activeSession;

  @override
  Widget build(BuildContext context) {
    // Context line shown when a worker is selected:
    //   "Ronald · 6 cows milking · AM session"
    // Falls back to the generic 3-sessions-a-day blurb in manager view
    // or before any worker pick.
    final showContext = !managerView &&
        activeWorker != null &&
        activeMilkingCount != null &&
        activeSession != null;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  style: const TextStyle(color: Color(0xFF27500A)),
                  children: [
                    const TextSpan(
                      text: '🥛  MILK LOGGING',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                    if (showContext)
                      TextSpan(
                        text:
                            '  —  $activeWorker  ·  $activeMilkingCount cow${activeMilkingCount == 1 ? '' : 's'} milking  ·  ${activeSession!.label} session',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF7A7A7A),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '3 sessions/day: AM · midday · PM. Tap a worker, enter litres '
                'per cow, submit. Below-average readings auto-flag.',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.black54,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: onToggle,
          icon: Icon(
            managerView ? Icons.person_outlined : Icons.bar_chart_outlined,
            size: 14,
          ),
          label: Text(managerView ? 'Worker view' : 'Manager view'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF27500A),
            side: const BorderSide(color: Color(0x33000000)),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            textStyle: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

// ===== Session Tabs =====

class _SessionTabs extends StatelessWidget {
  const _SessionTabs({
    required this.today,
    required this.selected,
    required this.onSelect,
  });
  final TodaySessions today;
  final MilkSession selected;
  final ValueChanged<MilkSession> onSelect;

  @override
  Widget build(BuildContext context) {
    final agg = today.aggregateProgress;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEFEDE6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          for (final s in MilkSession.values)
            Expanded(
              child: InkWell(
                onTap: () => onSelect(s),
                borderRadius: BorderRadius.circular(8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected == s ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        s.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: selected == s
                              ? const Color(0xFF27500A)
                              : Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: selected == s
                              ? const Color(0xFF27500A)
                              : const Color(0x22000000),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${agg[s]?.logged ?? 0}/${agg[s]?.total ?? 0}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: selected == s
                                ? Colors.white
                                : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ===== Worker View =====

class _WorkerView extends StatelessWidget {
  const _WorkerView({
    required this.today,
    required this.selectedWorker,
    required this.onPickWorker,
    required this.selectedSession,
    required this.activeCows,
    required this.drafts,
    required this.liveSubtotal,
    required this.submitting,
    required this.onSubmit,
    required this.onTextChanged,
    required this.houseLabels,
    required this.maternityCount,
    required this.activeWorkerName,
  });

  final TodaySessions today;
  final String? selectedWorker;
  final ValueChanged<String> onPickWorker;
  final MilkSession selectedSession;
  final List<CowSessionView> activeCows;
  final Map<String, TextEditingController> drafts;
  final double liveSubtotal;
  final bool submitting;
  final VoidCallback onSubmit;
  final VoidCallback onTextChanged;

  /// Map of houseId → short letter label (e.g. "HA"). Drives the
  /// chip on each cow card.
  final Map<String, String> houseLabels;

  /// Pregnant cows belonging to the active worker (post house filter).
  /// Surfaces as a callout under the cow grid.
  final int maternityCount;

  /// Worker name for the maternity callout's possessive ("Ronald's").
  final String? activeWorkerName;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Worker pills
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final w in today.workers)
              _WorkerPill(
                worker: w,
                selected: w.id == selectedWorker,
                session: selectedSession,
                onTap: () => onPickWorker(w.id),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (selectedWorker == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 36),
            child: Center(
              child: Text(
                'Pick a worker above to log this session\'s readings.',
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
            ),
          )
        else if (activeCows.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 36),
            child: Center(
              child: Text(
                'No cows match the current filter.',
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
            ),
          )
        else ...[
          _CowGrid(
            cows: activeCows,
            session: selectedSession,
            drafts: drafts,
            onTextChanged: onTextChanged,
            houseLabels: houseLabels,
          ),
          const SizedBox(height: 14),
          _SubtotalBar(
            subtotal: liveSubtotal,
            submitting: submitting,
            onSubmit: onSubmit,
          ),
          if (maternityCount > 0) ...[
            const SizedBox(height: 12),
            _MaternityCallout(
              count: maternityCount,
              workerName: activeWorkerName,
            ),
          ],
        ],
      ],
    );
  }
}

class _WorkerPill extends StatelessWidget {
  const _WorkerPill({
    required this.worker,
    required this.selected,
    required this.session,
    required this.onTap,
  });
  final WorkerSessionView worker;
  final bool selected;
  final MilkSession session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final progress = worker.progress[session];
    final complete =
        progress != null && progress.total > 0 && progress.logged == progress.total;
    final bg = selected
        ? const Color(0xFF27500A)
        : complete
            ? const Color(0xFFEAF3DE)
            : Colors.white;
    final fg = selected ? Colors.white : Colors.black87;
    final border = selected
        ? const Color(0xFF27500A)
        : complete
            ? const Color(0xFFB7D7A6)
            : const Color(0x33000000);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              worker.name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 1,
              ),
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withValues(alpha: 0.2)
                    : const Color(0xFFF0EFE9),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                // Once the worker has completed every cow for this
                // session, swap the "n/total" badge for a static cow
                // count (e.g. "(6)") — the green ✓ that follows
                // already conveys completion.
                complete
                    ? '${worker.cowCount}'
                    : '${progress?.logged ?? 0}/${progress?.total ?? 0}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ),
            // ✓ tick when this worker has logged every cow for the
            // active session. Mirrors the v4.1 mockup where completed
            // pills get a checkmark next to the name.
            if (complete) ...[
              const SizedBox(width: 6),
              Icon(
                Icons.check_rounded,
                size: 14,
                color: selected ? Colors.white : const Color(0xFF27500A),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CowGrid extends StatelessWidget {
  const _CowGrid({
    required this.cows,
    required this.session,
    required this.drafts,
    required this.onTextChanged,
    required this.houseLabels,
  });

  final List<CowSessionView> cows;
  final MilkSession session;
  final Map<String, TextEditingController> drafts;
  final VoidCallback onTextChanged;
  final Map<String, String> houseLabels;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 900
            ? 5
            : c.maxWidth >= 720
                ? 4
                : c.maxWidth >= 480
                    ? 2
                    : 1;
        final width = (c.maxWidth - 12 * (cols - 1)) / cols;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final cow in cows)
              SizedBox(
                width: width,
                child: _CowEntry(
                  cow: cow,
                  session: session,
                  controller: drafts[cow.id],
                  onChanged: onTextChanged,
                  houseLabel: cow.houseId == null
                      ? null
                      : houseLabels[cow.houseId!],
                ),
              ),
          ],
        );
      },
    );
  }
}

// "1 of Ronald's cows are in maternity — not milking right now."
class _MaternityCallout extends StatelessWidget {
  const _MaternityCallout({required this.count, required this.workerName});
  final int count;
  final String? workerName;

  @override
  Widget build(BuildContext context) {
    final possessive =
        workerName == null ? "the worker's" : "$workerName's";
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFAEEDA),
        borderRadius: BorderRadius.circular(8),
        border: const Border(
          left: BorderSide(color: Color(0xFF854F0B), width: 3),
        ),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF854F0B),
            height: 1.4,
          ),
          children: [
            TextSpan(
              text: '$count ',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            TextSpan(
              text:
                  'of $possessive cows ${count == 1 ? 'is' : 'are'} in maternity — not milking right now.',
            ),
          ],
        ),
      ),
    );
  }
}

class _CowEntry extends StatelessWidget {
  const _CowEntry({
    required this.cow,
    required this.session,
    required this.controller,
    required this.onChanged,
    required this.houseLabel,
  });

  final CowSessionView cow;
  final MilkSession session;
  final TextEditingController? controller;
  final VoidCallback onChanged;

  /// Short letter label for the cow's house ("HA", "HB", "HE", etc.)
  /// or null if unassigned. Rendered as a small tag in the card's
  /// top-right corner per the v4.1 mockup.
  final String? houseLabel;

  @override
  Widget build(BuildContext context) {
    final avg = cow.avg[session] ?? 0;
    // We can't trust the persisted "flagged" bit while the user is
    // typing — recompute on the live value so flags update in real
    // time. (The DB-stored flag is still authoritative on submit.)
    final liveValue = double.tryParse(controller?.text.trim() ?? '');
    final hasValue = liveValue != null && liveValue > 0;
    final flagged = liveValue != null &&
        liveValue > 0 &&
        avg > 0 &&
        liveValue < avg * 0.7;

    // Card state colors:
    //   * flagged          → soft red (Below avg)
    //   * has value        → soft green (Logged)
    //   * empty            → white (Pending)
    final (cardBg, cardBorder) = flagged
        ? (MilkLoggingPanelState._flagBg, const Color(0xFFE6BFBE))
        : hasValue
            ? (const Color(0xFFEAF3DE), const Color(0xFFB7D7A6))
            : (Colors.white, const Color(0x14000000));

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tag pill (left) + house chip (right). Mirrors the
          // "Topten | HA" header in the design mock.
          Row(
            children: [
              Expanded(
                // Workers see local names in the milk-logging grid;
                // the technical tag (Mw-019, etc.) is reserved for
                // the cow records table where it's the lookup key.
                child: _TagPill(text: cow.displayName),
              ),
              if (houseLabel != null) ...[
                const SizedBox(width: 6),
                _HouseTagChip(label: houseLabel!),
              ],
            ],
          ),
          if (avg > 0) ...[
            const SizedBox(height: 6),
            Text(
              'avg ${_fmtLitres(avg)}L',
              style: const TextStyle(
                fontSize: 11,
                color: Colors.black54,
              ),
            ),
          ],
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
            ],
            onChanged: (_) => onChanged(),
            // Once a value is in the field we present it large + bold,
            // matching the "9.6 L" / "10.3 L" prominence in the
            // submitted-state screenshot. Pre-submission the empty
            // input is shown smaller with a "0" placeholder.
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: hasValue ? 22 : 16,
              fontWeight: FontWeight.w800,
              color: flagged
                  ? MilkLoggingPanelState._flagFg
                  : hasValue
                      ? const Color(0xFF27500A)
                      : Colors.black54,
            ),
            decoration: InputDecoration(
              isDense: true,
              hintText: '0',
              suffixText: 'L',
              filled: true,
              fillColor: hasValue
                  ? Colors.white.withValues(alpha: 0.5)
                  : const Color(0xFFFAFAF7),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: Color(0xFF27500A),
                  width: 1.6,
                ),
              ),
            ),
          ),
          if (flagged) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '▼',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: MilkLoggingPanelState._flagFg,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'Below avg (${_fmtLitres(avg)}L)',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: MilkLoggingPanelState._flagFg,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// Cow tag pill — green text on soft green bg, matching the design.
class _TagPill extends StatelessWidget {
  const _TagPill({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF3DE),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: Color(0xFF27500A),
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

// Small "HA" / "HB" / "HE" chip on the right of the cow card header.
class _HouseTagChip extends StatelessWidget {
  const _HouseTagChip({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF3DE),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: Color(0xFF27500A),
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _SubtotalBar extends StatelessWidget {
  const _SubtotalBar({
    required this.subtotal,
    required this.submitting,
    required this.onSubmit,
  });

  final double subtotal;
  final bool submitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF3DE),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'WORKER SUBTOTAL',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 0.6,
                    color: Colors.black54,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2),
              ],
            ),
          ),
          const SizedBox.shrink(),
          Builder(
            builder: (_) => Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Text(
                '${_fmtLitres(subtotal)} L',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF27500A),
                ),
              ),
            ),
          ),
          FilledButton(
            onPressed: submitting ? null : onSubmit,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF27500A),
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: submitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('✓ Submit session'),
          ),
        ],
      ),
    );
  }
}

// ===== Manager View =====
//
// Mirrors the v4.1 mockup's "All workers · all sessions · day rollup"
// panel exactly:
//
//   ┌─────────────────────────────────────────────────────────┐
//   │ WORKER  │ COWS │  AM  │ MIDDAY │  PM  │ TOTAL │
//   ├─────────┼──────┼──────┼────────┼──────┼───────┤
//   │ Ronald  │  6   │ —    │ 36 ✓   │ 27 ✓ │  63 L │
//   │ Musyoka │  5   │ —    │ 33 ✓   │ 28 ✓ │  61 L │
//   │ ...                                                   │
//   ├─ DAY GROSS ─┼──────┼──── 0 ─── 331 ── 250 ── 581 L ───┤
//   ├─ DAY NET (after deductions) ─── 541.4 L ──── TARGET 2,000 L · 27% ─
//
// Each session cell has a number + a green ✓ badge when that worker
// submitted at least one reading for that session. Below-average flags
// are still listed underneath the table.

class _ManagerView extends StatelessWidget {
  const _ManagerView({
    required this.today,
    required this.session,
    this.summary,
  });
  final TodaySessions today;
  final MilkSession session;
  final DayNetSummary? summary;

  // Pulled from FarmConfig.milkTarget on the seed (2000 L/day). Hardcoded
  // here so the rollup renders a target percentage even before the
  // backend exposes the value via /api/dairy/summary. Easy to swap to
  // a constructor param later.
  static const int _dailyTargetLitres = 2000;

  @override
  Widget build(BuildContext context) {
    final flags = <_MgrFlag>[];
    for (final w in today.workers) {
      for (final cow in w.cows) {
        for (final s in MilkSession.values) {
          if (cow.flagged[s] == true) {
            flags.add(_MgrFlag(
              worker: w.name,
              cow: cow.displayName,
              session: s,
              litres: cow.entries[s] ?? 0,
              avg: cow.avg[s] ?? 0,
            ));
          }
        }
      }
    }

    // Per-session column gross used by both the worker rows and the
    // DAY GROSS footer. Sourced from `summary` when available so it
    // matches the deductions panel; otherwise derived from worker
    // totals.
    final colGross = <MilkSession, double>{
      for (final s in MilkSession.values)
        s: summary?.sessions[s] ??
            today.workers.fold<double>(0, (acc, w) => acc + (w.totals[s] ?? 0)),
    };
    final dayGross = colGross.values.fold<double>(0, (a, b) => a + b);
    final dayNet = summary?.dayNet ?? dayGross;
    final deductions = summary?.totalDeductions ?? 0;
    final pctOfTarget = _dailyTargetLitres > 0
        ? ((dayNet / _dailyTargetLitres) * 100).round()
        : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'All workers · all sessions · day rollup',
          style: TextStyle(
            fontSize: 12,
            color: Colors.black54,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 10),
        // Header row. Column labels come from MilkSession.values so a
        // new session (e.g. Dawn) lands in the right column without a
        // separate copy-paste in the header.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              const Expanded(flex: 5, child: _MgrCell('WORKER', isHeader: true)),
              const Expanded(flex: 2, child: _MgrCell('COWS', isHeader: true)),
              for (final s in MilkSession.values)
                Expanded(
                  flex: 3,
                  child: _MgrCell(
                    s.label.toUpperCase(),
                    isHeader: true,
                    alignEnd: true,
                  ),
                ),
              const Expanded(
                flex: 3,
                child: _MgrCell('TOTAL', isHeader: true, alignEnd: true),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0x14000000)),
        // Worker rows.
        for (var i = 0; i < today.workers.length; i++) ...[
          _MgrDataRow(
            worker: today.workers[i],
            session: session,
          ),
          if (i < today.workers.length - 1)
            const Divider(height: 1, color: Color(0x14000000)),
        ],
        const Divider(height: 1, color: Color(0x14000000)),
        // DAY GROSS — a single banded row aligned with the columns.
        Container(
          color: const Color(0xFFEAF3DE),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              const Expanded(
                flex: 5,
                child: _MgrCell('DAY GROSS', bold: true, emphasized: true),
              ),
              const Expanded(flex: 2, child: SizedBox.shrink()),
              for (final s in MilkSession.values)
                Expanded(
                  flex: 3,
                  child: _MgrCell(
                    colGross[s] == 0
                        ? '0'
                        : _fmtLitres(colGross[s]!),
                    bold: true,
                    emphasized: true,
                    alignEnd: true,
                  ),
                ),
              Expanded(
                flex: 3,
                child: _MgrCell(
                  '${_fmtLitres(dayGross)} L',
                  bold: true,
                  emphasized: true,
                  alignEnd: true,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // DAY NET footer — three columns: Day net (left), deductions
        // (centre), target % (right).
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF3DE),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionLabel('DAY NET (AFTER DEDUCTIONS)'),
                    const SizedBox(height: 4),
                    Text(
                      '${_fmtLitres(dayNet)} L',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF27500A),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionLabel('CALVES + HOUSEHOLD'),
                    const SizedBox(height: 4),
                    Text(
                      '− ${_fmtLitres(deductions)} L',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFB42318),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionLabel('TARGET'),
                    const SizedBox(height: 4),
                    Text(
                      '${_fmtLitres(_dailyTargetLitres)} L · $pctOfTarget%',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF27500A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Below-average flags — kept under the table for vet review.
        Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              size: 14,
              color: MilkLoggingPanelState._flagFg,
            ),
            const SizedBox(width: 6),
            Text(
              'BELOW-AVERAGE READINGS (need vet attention)  ${flags.length}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: MilkLoggingPanelState._flagFg,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (flags.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'No flagged readings — herd is healthy.',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
          )
        else
          for (final f in flags) ...[
            _FlagBlock(row: f),
            const SizedBox(height: 6),
          ],
      ],
    );
  }
}

// One worker row in the manager rollup. Per-session cells get a green
// ✓ badge when the worker submitted any reading for that session.
class _MgrDataRow extends StatelessWidget {
  const _MgrDataRow({required this.worker, required this.session});
  final WorkerSessionView worker;
  final MilkSession session;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: _MgrCell(worker.name, bold: true),
          ),
          Expanded(
            flex: 2,
            child: _MgrCell('${worker.cowCount}'),
          ),
          for (final s in MilkSession.values)
            Expanded(
              flex: 3,
              child: _MgrSessionCell(
                value: worker.totals[s] ?? 0,
                logged: (worker.progress[s]?.logged ?? 0) > 0,
                emphasized: s == session,
              ),
            ),
          Expanded(
            flex: 3,
            child: _MgrCell(
              '${_fmtLitres(worker.dayTotal)} L',
              bold: true,
              alignEnd: true,
              emphasized: true,
            ),
          ),
        ],
      ),
    );
  }
}

// Right-aligned session cell: number + ✓ badge (green pill) when any
// reading is logged. Empty cells render an em-dash.
class _MgrSessionCell extends StatelessWidget {
  const _MgrSessionCell({
    required this.value,
    required this.logged,
    required this.emphasized,
  });
  final double value;
  final bool logged;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    if (!logged && value == 0) {
      return _MgrCell('—', alignEnd: true);
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _fmtLitres(value),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: emphasized
                ? const Color(0xFF27500A)
                : Colors.black87,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          width: 18,
          height: 18,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Color(0xFFEAF3DE),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_rounded,
            size: 12,
            color: Color(0xFF27500A),
          ),
        ),
      ],
    );
  }
}

class _MgrCell extends StatelessWidget {
  const _MgrCell(
    this.text, {
    this.isHeader = false,
    this.emphasized = false,
    this.bold = false,
    this.alignEnd = false,
  });
  final String text;
  final bool isHeader;
  final bool emphasized;
  final bool bold;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: alignEnd ? TextAlign.right : TextAlign.left,
      style: TextStyle(
        fontSize: isHeader ? 10 : 13,
        fontWeight: isHeader || bold ? FontWeight.w800 : FontWeight.w500,
        letterSpacing: isHeader ? 0.6 : 0,
        color: isHeader
            ? Colors.black54
            : emphasized
                ? const Color(0xFF27500A)
                : Colors.black87,
      ),
    );
  }
}

class _MgrFlag {
  _MgrFlag({
    required this.worker,
    required this.cow,
    required this.session,
    required this.litres,
    required this.avg,
  });
  final String worker;
  final String cow;
  final MilkSession session;
  final double litres;
  final double avg;
}

class _FlagBlock extends StatelessWidget {
  const _FlagBlock({required this.row});
  final _MgrFlag row;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: MilkLoggingPanelState._flagBg,
        borderRadius: BorderRadius.circular(8),
        border: const Border(
          left: BorderSide(
            color: MilkLoggingPanelState._flagFg,
            width: 3,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${row.cow}  ·  ${row.worker}  ·  ${row.session.label}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: MilkLoggingPanelState._flagFg,
              ),
            ),
          ),
          Text(
            '${_fmtLitres(row.litres)} L (avg ${_fmtLitres(row.avg)} L)',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: MilkLoggingPanelState._flagFg,
            ),
          ),
        ],
      ),
    );
  }
}

// ===== Summary Grid (gross/net + day totals) =====

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({
    required this.today,
    required this.session,
    required this.summary,
    required this.onEditDeductions,
  });

  final TodaySessions today;
  final MilkSession session;
  final DayNetSummary summary;
  final VoidCallback onEditDeductions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 700;
        final left = _DeductionPanel(
          session: session,
          summary: summary,
          onEdit: onEditDeductions,
        );
        final right = _AcrossSessionsPanel(summary: summary);
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: left),
              const SizedBox(width: 12),
              Expanded(child: right),
            ],
          );
        }
        return Column(
          children: [left, const SizedBox(height: 12), right],
        );
      },
    );
  }
}

class _DeductionPanel extends StatelessWidget {
  const _DeductionPanel({
    required this.session,
    required this.summary,
    required this.onEdit,
  });
  final MilkSession session;
  final DayNetSummary summary;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final sessionGross = summary.sessions[session] ?? 0;
    // Prefer the live calf count for the "(N × 1L)" hint when the
    // value isn't overridden — that's the auto-detect from CALVING
    // events in the last 120 days. When overridden, fall back to the
    // raw litres so the hint matches what's actually deducted.
    final calfHeadcount = summary.calfOverridden
        ? summary.calfDeduction.toStringAsFixed(0)
        : summary.calfCount.toString();
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAF7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _SectionLabel('${session.label} SESSION SUMMARY'),
              ),
              InkWell(
                onTap: onEdit,
                borderRadius: BorderRadius.circular(20),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_outlined, size: 12, color: Color(0xFF1976D2)),
                      SizedBox(width: 4),
                      Text(
                        'Edit deductions',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1976D2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _DedRow(label: 'Gross collected', value: '${_fmtLitres(sessionGross)} L'),
          _DedRow(
            label: 'Calves under 4mo ($calfHeadcount × 1L)'
                '${summary.calfOverridden ? "  ·  override" : ""}',
            value: '− ${_fmtLitres(summary.calfDeduction)} L',
            minus: true,
          ),
          _DedRow(
            label: 'Household usage',
            value: '− ${_fmtLitres(summary.householdDeduction)} L',
            minus: true,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Divider(height: 1, color: Color(0x22000000)),
          ),
          _DedRow(
            label: 'Net for dispatch (day)',
            value: '${_fmtLitres(summary.dayNet)} L',
            net: true,
          ),
        ],
      ),
    );
  }
}

class _AcrossSessionsPanel extends StatelessWidget {
  const _AcrossSessionsPanel({required this.summary});
  final DayNetSummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionLabel('TODAY ACROSS SESSIONS'),
          const SizedBox(height: 8),
          for (final s in MilkSession.values)
            _DayRow(
              label: s.label,
              value: '${_fmtLitres(summary.sessions[s] ?? 0)} L',
            ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Divider(height: 1, color: Color(0x14000000)),
          ),
          _DayRow(
            label: 'Day total (net)',
            value: '${_fmtLitres(summary.dayNet)} L',
            bold: true,
          ),
        ],
      ),
    );
  }
}

class _DedRow extends StatelessWidget {
  const _DedRow({
    required this.label,
    required this.value,
    this.minus = false,
    this.net = false,
  });
  final String label;
  final String value;
  final bool minus;
  final bool net;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: net ? FontWeight.w800 : FontWeight.w500,
                color: net ? const Color(0xFF27500A) : Colors.black87,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: minus
                  ? const Color(0xFFB42318)
                  : net
                      ? const Color(0xFF27500A)
                      : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.label,
    required this.value,
    this.bold = false,
  });
  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color:
                  bold ? const Color(0xFF27500A) : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 10,
        letterSpacing: 0.6,
        fontWeight: FontWeight.w800,
        color: Colors.black54,
      ),
    );
  }
}

class _EmptyBlock extends StatelessWidget {
  const _EmptyBlock({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Center(
        child: Text(message,
            style: const TextStyle(fontSize: 13, color: Colors.black54)),
      ),
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          const Icon(Icons.error_outline,
              size: 28, color: Color(0xFF854F0B)),
          const SizedBox(height: 8),
          Text(message),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 14),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

String _fmtLitres(num v) {
  if (v == v.toInt()) return v.toInt().toString();
  return v.toStringAsFixed(1);
}

// Unused but kept for potential reuse — date formatter.
// ignore: unused_element
String _fmtDate(DateTime d) => DateFormat('d MMM').format(d);
