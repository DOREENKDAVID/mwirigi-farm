import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/cow.dart';
import '../../core/models/dairy_ops.dart';
import '../../core/service/api_service.dart';
import 'register_cow_dialog.dart';
import 'release_cow_dialog.dart';
import 'worker_availability_dialog.dart';
import 'report_sick_dialog.dart';

/// Cow Records card. Two independent filter pill rows + a search bar +
/// a responsive table that flows to per-row cards on narrow screens.
///
/// Filter behavior (matches the v4.1 HTML):
///   * Worker pills and House pills are SEPARATE filter categories.
///   * Tap a pill to set/clear it. Tapping "All" inside a category
///     resets just that category (the other stays put).
///   * Both categories AND together server-side via the new
///     `?workerId=&houseId=` query params.
///
/// State:
///   * Worker + House filter IDs are owned by the parent so an external
///     widget (e.g. HousesOverviewCard) can keep them in sync.
///   * Search query is debounced 350ms.
class CowRecordsTable extends StatefulWidget {
  const CowRecordsTable({
    super.key,
    required this.workers,
    required this.houses,
    required this.selectedWorkerId,
    required this.selectedHouseId,
    required this.onWorkerSelect,
    required this.onHouseSelect,
    required this.onChanged,
  });

  final List<DairyWorkerSummary> workers;
  final List<DairyHouseOverview> houses;

  /// `null` = "All". Empty string isn't allowed.
  final String? selectedWorkerId;
  final String? selectedHouseId;

  /// Pass null to clear the filter.
  final ValueChanged<String?> onWorkerSelect;
  final ValueChanged<String?> onHouseSelect;

  /// Fired after any cow CRUD action so the parent can refresh KPIs /
  /// houses overview alongside the table.
  final VoidCallback onChanged;

  @override
  State<CowRecordsTable> createState() => CowRecordsTableState();
}

class CowRecordsTableState extends State<CowRecordsTable> {
  static const _primary = Color(0xFF27500A);

  // Roles that can register, edit, release, or delete cows. Mirrors
  // the backend authorizeRoles gate on POST/PUT/DELETE /dairy/cows.
  // For other roles (VET, WORKER, …) the buttons are hidden so we
  // don't queue offline actions the server will reject as 403.
  static const _cowEditorRoles = {'CEO', 'DAIRY_MANAGER', 'ADMIN'};

  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  String _search = '';
  bool _canEditCows = false;

  Future<List<Cow>>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final role = await ApiService.readRole();
    if (!mounted) return;
    setState(() => _canEditCows = _cowEditorRoles.contains(role));
  }

  @override
  void didUpdateWidget(covariant CowRecordsTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload whenever the filter inputs change so the parent can drive
    // the filter state from outside (e.g. from the houses grid).
    if (oldWidget.selectedWorkerId != widget.selectedWorkerId ||
        oldWidget.selectedHouseId != widget.selectedHouseId) {
      _future = _load();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<List<Cow>> _load() async {
    final raw = await ApiService.getCows(
      workerId: widget.selectedWorkerId,
      houseId: widget.selectedHouseId,
      search: _search.isEmpty ? null : _search,
    );
    return raw
        .whereType<Map>()
        .map((m) => Cow.fromJson(m.cast<String, dynamic>()))
        .toList();
  }

  Future<void> reload() async {
    setState(() => _future = _load());
    await _future;
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() {
        _search = v.trim();
        _future = _load();
      });
    });
  }

  Future<void> _openRegister() async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => RegisterCowDialog(
        workers: widget.workers,
        houses: widget.houses,
      ),
    );
    if (saved == true) {
      _toast('Cow registered');
      await reload();
      widget.onChanged();
    }
  }

  Future<void> _openReportSick() async {
    final reported = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ReportSickDialog(defaultUnit: 'Dairy'),
    );
    if (reported == true) {
      _toast('Sent to vet queue');
      widget.onChanged();
    }
  }

  Future<void> _openEdit(Cow cow) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => RegisterCowDialog(
        cow: cow,
        workers: widget.workers,
        houses: widget.houses,
      ),
    );
    if (saved == true) {
      _toast('${cow.tag} updated');
      await reload();
      widget.onChanged();
    }
  }

  Future<void> _openAvailability() async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => WorkerAvailabilityDialog(workers: widget.workers),
    );
    if (changed == true) {
      widget.onChanged();
    }
  }

  Future<void> _openRelease(Cow cow) async {
    final released = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ReleaseCowDialog(cow: cow),
    );
    if (released == true) {
      _toast('${cow.tag} released from active herd');
      await reload();
      widget.onChanged();
    }
  }

  Future<void> _confirmDelete(Cow cow) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete cow?'),
        content: Text(
          '${cow.tag} will be removed from the herd. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiService.deleteCow(cow.tag);
      if (!mounted) return;
      _toast('${cow.tag} removed');
      await reload();
      widget.onChanged();
    } catch (e) {
      if (!mounted) return;
      _toast(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
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
      child: FutureBuilder<List<Cow>>(
        future: _future,
        builder: (context, snap) {
          final loading = snap.connectionState == ConnectionState.waiting;
          final cows = snap.data ?? const <Cow>[];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header — count label on its own row so it doesn't
              // get squeezed into a vertical sliver when the action
              // buttons need horizontal space. Buttons flow with Wrap
              // so they cascade to a second line on narrow phones
              // instead of clipping or overflowing.
              RichText(
                text: TextSpan(
                  style: const TextStyle(color: Colors.black54),
                  children: [
                    const TextSpan(
                      text: 'COW RECORDS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                    TextSpan(
                      text: '  —  ${cows.length} cow${cows.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.start,
                children: [
                  OutlinedButton.icon(
                    onPressed: _openAvailability,
                    icon: const Icon(Icons.manage_accounts, size: 14),
                    label: const Text('Availability'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1976D2),
                      side: const BorderSide(color: Color(0x551976D2)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _openReportSick,
                    icon: const Icon(
                      Icons.medical_services_outlined,
                      size: 14,
                    ),
                    label: const Text('Report sick'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFB42318),
                      side: const BorderSide(color: Color(0x55B42318)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (_canEditCows)
                    OutlinedButton.icon(
                      onPressed: _openRegister,
                      icon: const Icon(Icons.add, size: 14),
                      label: const Text('Register cow'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _primary,
                        side: const BorderSide(color: Color(0x33000000)),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Search bar, full-width.
              TextField(
                controller: _searchCtrl,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search by tag, name, breed, status…',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                  filled: true,
                  fillColor: const Color(0xFFEFEDE6),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 16,
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
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: _searchCtrl.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () {
                            _searchCtrl.clear();
                            _onSearchChanged('');
                          },
                        ),
                ),
              ),
              const SizedBox(height: 14),

              // ----- Filter by worker -----
              const _PillRowLabel('FILTER BY WORKER'),
              const SizedBox(height: 6),
              _PillRow(
                allLabel: 'All',
                allCount:
                    widget.workers.fold<int>(0, (s, w) => s + w.cowCount),
                selectedId: widget.selectedWorkerId,
                onSelect: widget.onWorkerSelect,
                items: [
                  for (final w in widget.workers)
                    _PillItem(id: w.id, label: w.name, count: w.cowCount),
                ],
              ),
              const SizedBox(height: 14),

              // ----- Filter by house -----
              const _PillRowLabel('FILTER BY HOUSE'),
              const SizedBox(height: 6),
              _PillRow(
                allLabel: 'All',
                allCount: widget.houses
                    .where((h) => h.id != '__maternity__')
                    .fold<int>(0, (s, h) => s + h.totalCows) +
                    widget.houses
                        .where((h) => h.id == '__maternity__')
                        .fold<int>(0, (s, h) => s + h.totalCows),
                selectedId: widget.selectedHouseId,
                onSelect: widget.onHouseSelect,
                items: [
                  for (final h in widget.houses)
                    _PillItem(
                      id: h.id,
                      // Display label rules:
                      //   "Dairy Maternity" → "Maternity"    (real row,
                      //   added in the v4.5 migration)
                      //   "__maternity__"   → "Maternity"    (legacy
                      //   synthetic id from before the real row existed)
                      //   "Dairy A"         → "House A"
                      label: () {
                        if (h.id == '__maternity__') return 'Maternity';
                        if (h.name.toLowerCase() == 'dairy maternity') {
                          return 'Maternity';
                        }
                        return h.name.replaceFirst(
                          RegExp(r'^Dairy\s+'),
                          'House ',
                        );
                      }(),
                      count: h.totalCows,
                      icon: (h.id == '__maternity__' ||
                              h.name.toLowerCase() == 'dairy maternity')
                          ? '🤰'
                          : null,
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // ----- Table / list -----
              if (loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 36),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (snap.hasError)
                _ErrorBlock(
                  message: snap.error
                      .toString()
                      .replaceFirst('Exception: ', ''),
                  onRetry: reload,
                )
              else if (cows.isEmpty)
                const _EmptyState()
              else
                LayoutBuilder(
                  builder: (context, c) {
                    final wide = c.maxWidth >= 760;
                    return wide
                        ? _DesktopTable(
                            cows: cows,
                            onEdit: _openEdit,
                            onDelete: _confirmDelete,
                            onRelease: _openRelease,
                            canEdit: _canEditCows,
                          )
                        : _MobileList(
                            cows: cows,
                            onEdit: _openEdit,
                            onDelete: _confirmDelete,
                            onRelease: _openRelease,
                            canEdit: _canEditCows,
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

class _PillItem {
  const _PillItem({
    required this.id,
    required this.label,
    required this.count,
    this.icon,
  });
  final String id;
  final String label;
  final int count;
  final String? icon;
}

class _PillRowLabel extends StatelessWidget {
  const _PillRowLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 10,
        letterSpacing: 0.6,
        fontWeight: FontWeight.w700,
        color: Color(0xFF7A7A7A),
      ),
    );
  }
}

class _PillRow extends StatelessWidget {
  const _PillRow({
    required this.allLabel,
    required this.allCount,
    required this.selectedId,
    required this.onSelect,
    required this.items,
  });

  final String allLabel;
  final int allCount;
  final String? selectedId;
  final ValueChanged<String?> onSelect;
  final List<_PillItem> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _Pill(
          label: allLabel,
          count: allCount,
          active: selectedId == null,
          onTap: () => onSelect(null),
        ),
        for (final i in items)
          _Pill(
            label: i.icon != null ? '${i.icon} ${i.label}' : i.label,
            count: i.count,
            active: selectedId == i.id,
            // Tapping the active pill clears that filter category.
            onTap: () => onSelect(selectedId == i.id ? null : i.id),
          ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.count,
    required this.active,
    required this.onTap,
  });
  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF27500A);
    final bg = active ? primary : const Color(0xFFF0EFE9);
    final fg = active ? Colors.white : Colors.black87;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: active
                    ? Colors.white.withValues(alpha: 0.2)
                    : const Color(0x22000000),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===== Cow photo (circular) =====

class _CowPhoto extends StatelessWidget {
  const _CowPhoto({required this.url, this.size = 36});
  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final src = (url == null || url!.isEmpty) ? null : ApiService.assetUrl(url!);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFEAF3DE),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0x14000000)),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: src == null
          ? Text('🐄', style: TextStyle(fontSize: size * 0.55))
          : Image.network(
              src,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Text('🐄', style: TextStyle(fontSize: size * 0.55)),
            ),
    );
  }
}

// ===== Status pill =====

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final CowStatus status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label) = switch (status) {
      CowStatus.milking => (
          const Color(0xFFEAF3DE),
          const Color(0xFF27500A),
          'Milking',
        ),
      CowStatus.dryOff => (
          const Color(0xFFEDEDED),
          const Color(0xFF555555),
          'Dry off',
        ),
      CowStatus.pregnant => (
          const Color(0xFFFAEEDA),
          const Color(0xFF854F0B),
          'Pregnant',
        ),
      CowStatus.sick => (
          const Color(0xFFFCEBEB),
          const Color(0xFFB42318),
          'Sick',
        ),
      CowStatus.heifer => (
          const Color(0xFFD9EFEA),
          const Color(0xFF0E5E50),
          'Heifer',
        ),
      CowStatus.open => (
          const Color(0xFFEDEDED),
          const Color(0xFF555555),
          'Open',
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(
        label,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.visible,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

// ===== Desktop table =====

class _DesktopTable extends StatelessWidget {
  const _DesktopTable({
    required this.cows,
    required this.onEdit,
    required this.onDelete,
    required this.onRelease,
    required this.canEdit,
  });
  final List<Cow> cows;
  final void Function(Cow) onEdit;
  final void Function(Cow) onDelete;
  final void Function(Cow) onRelease;
  final bool canEdit;

  // Flex weights — sum 28. CROP-style flex distribution so the table
  // uses the full card width rather than bunching at the left.
  static const _flexTag = 3;
  static const _flexPhoto = 2;
  static const _flexName = 3;
  static const _flexBreed = 3;
  static const _flexWorker = 3;
  static const _flexHouse = 3;
  static const _flexStatus = 3;
  static const _flexCalves = 2;
  static const _flexToday = 2;
  static const _flexAvg = 2;
  static const _flexActions = 2;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: const [
              Expanded(flex: _flexTag, child: _Hdr('TAG')),
              Expanded(flex: _flexPhoto, child: _Hdr('PHOTO')),
              Expanded(flex: _flexName, child: _Hdr('NAME')),
              Expanded(flex: _flexBreed, child: _Hdr('BREED')),
              Expanded(flex: _flexWorker, child: _Hdr('WORKER')),
              Expanded(flex: _flexHouse, child: _Hdr('HOUSE')),
              Expanded(flex: _flexStatus, child: _Hdr('STATUS')),
              Expanded(flex: _flexCalves, child: _Hdr('CALVES', alignEnd: true)),
              Expanded(flex: _flexToday, child: _Hdr('TODAY (L)', alignEnd: true)),
              Expanded(flex: _flexAvg, child: _Hdr('7D AVG', alignEnd: true)),
              Expanded(
                flex: _flexActions,
                child: _Hdr('ACTIONS', alignEnd: true),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0x14000000)),
        for (var i = 0; i < cows.length; i++) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Expanded(
                  flex: _flexTag,
                  child: _TagChip(tag: cows[i].tag),
                ),
                Expanded(
                  flex: _flexPhoto,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _CowPhoto(url: cows[i].imageUrl),
                  ),
                ),
                Expanded(
                  flex: _flexName,
                  child: Text(
                    cows[i].nickname ?? '—',
                    style: _bodyStyle,
                  ),
                ),
                Expanded(
                  flex: _flexBreed,
                  child: Text(cows[i].breed.label, style: _bodyStyle),
                ),
                Expanded(
                  flex: _flexWorker,
                  child: Text(
                    cows[i].workerName ?? '—',
                    style: _bodyStyle,
                  ),
                ),
                Expanded(
                  flex: _flexHouse,
                  child: Text(
                    cows[i].houseName?.replaceFirst(
                          RegExp(r'^Dairy\s+'),
                          'House ',
                        ) ??
                        '—',
                    style: _bodyStyle,
                  ),
                ),
                Expanded(
                  flex: _flexStatus,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _StatusPill(status: cows[i].status),
                  ),
                ),
                Expanded(
                  flex: _flexCalves,
                  child: Text(
                    '${cows[i].calvesLifetime}',
                    style: _bodyStyle,
                    textAlign: TextAlign.right,
                  ),
                ),
                Expanded(
                  flex: _flexToday,
                  child: Text(
                    cows[i].todayLitres == 0
                        ? '—'
                        : _fmt(cows[i].todayLitres),
                    style: _bodyStyle,
                    textAlign: TextAlign.right,
                  ),
                ),
                Expanded(
                  flex: _flexAvg,
                  child: Text(
                    cows[i].weekAvg == 0 ? '—' : _fmt(cows[i].weekAvg),
                    style: _bodyStyle,
                    textAlign: TextAlign.right,
                  ),
                ),
                Expanded(
                  flex: _flexActions,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: _RowActions(
                      cow: cows[i],
                      onEdit: onEdit,
                      onDelete: onDelete,
                      onRelease: onRelease,
                      canEdit: canEdit,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (i < cows.length - 1)
            const Divider(height: 1, color: Color(0x14000000)),
        ],
      ],
    );
  }
}

const _bodyStyle = TextStyle(fontSize: 13, color: Colors.black87);

class _Hdr extends StatelessWidget {
  const _Hdr(this.text, {this.alignEnd = false});
  final String text;
  final bool alignEnd;
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: alignEnd ? TextAlign.right : TextAlign.left,
      style: const TextStyle(
        fontSize: 10,
        letterSpacing: 0.6,
        fontWeight: FontWeight.w700,
        color: Color(0xFF7A7A7A),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.tag});
  final String tag;
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF3DE),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          tag,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.visible,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Color(0xFF27500A),
          ),
        ),
      ),
    );
  }
}

// ===== Mobile cards =====

class _MobileList extends StatelessWidget {
  const _MobileList({
    required this.cows,
    required this.onEdit,
    required this.onDelete,
    required this.onRelease,
    required this.canEdit,
  });
  final List<Cow> cows;
  final void Function(Cow) onEdit;
  final void Function(Cow) onDelete;
  final void Function(Cow) onRelease;
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final c in cows) ...[
          InkWell(
            onTap: () => onEdit(c),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAF7),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0x14000000)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CowPhoto(url: c.imageUrl, size: 48),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Wrap so [Tag, Name, Status] can flow to a 2nd
                        // line on narrow phones instead of overlapping
                        // the action buttons.
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _TagChip(tag: c.tag),
                            Text(
                              c.nickname ?? c.breed.label,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            _StatusPill(status: c.status),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${c.workerName ?? '—'} · ${c.houseName?.replaceFirst(RegExp(r'^Dairy\s+'), 'House ') ?? '—'}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Today ${c.todayLitres == 0 ? '—' : '${_fmt(c.todayLitres)} L'}  ·  '
                          '7d avg ${c.weekAvg == 0 ? '—' : '${_fmt(c.weekAvg)} L'}  ·  '
                          'calves ${c.calvesLifetime}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _RowActions(
                    cow: c,
                    onEdit: onEdit,
                    onDelete: onDelete,
                    onRelease: onRelease,
                    canEdit: canEdit,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _RowActions extends StatelessWidget {
  const _RowActions({
    required this.cow,
    required this.onEdit,
    required this.onDelete,
    required this.onRelease,
    required this.canEdit,
  });
  final Cow cow;
  final void Function(Cow) onEdit;
  final void Function(Cow) onDelete;
  final void Function(Cow) onRelease;
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    if (!canEdit) return const SizedBox.shrink();
    // Collapse the 3-icon row into a single overflow menu. On a
    // narrow phone the trio was eating ~96px of horizontal room and
    // squeezing the tag/name/status chips into vertically-wrapped
    // text. A 32px kebab keeps the same actions one tap deeper.
    return PopupMenuButton<String>(
      tooltip: 'Actions',
      icon: const Icon(Icons.more_vert, size: 20),
      padding: EdgeInsets.zero,
      onSelected: (v) {
        switch (v) {
          case 'edit':
            onEdit(cow);
            break;
          case 'release':
            onRelease(cow);
            break;
          case 'delete':
            onDelete(cow);
            break;
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 16),
              SizedBox(width: 10),
              Text('Edit'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'release',
          child: Row(
            children: [
              Icon(Icons.exit_to_app, size: 16, color: Color(0xFF854F0B)),
              SizedBox(width: 10),
              Text('Release / Sell'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 16, color: Color(0xFFB42318)),
              SizedBox(width: 10),
              Text('Delete', style: TextStyle(color: Color(0xFFB42318))),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Text('🐄', style: TextStyle(fontSize: 36)),
          SizedBox(height: 8),
          Text(
            'No cows match these filters.',
            style: TextStyle(fontSize: 13, color: Colors.black54),
          ),
        ],
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
          const Icon(Icons.error_outline, size: 32, color: Color(0xFF854F0B)),
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

String _fmt(num v) {
  if (v == v.toInt()) return v.toInt().toString();
  return v.toStringAsFixed(1);
}

// ignore: unused_element
String _fmtDate(DateTime d) => DateFormat('d MMM yyyy').format(d);
