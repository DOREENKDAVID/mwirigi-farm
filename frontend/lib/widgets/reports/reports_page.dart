// 📊 Reports & Exports — dashboard listing every available report,
// grouped by category. Each card opens the ReportPreviewPage.
//
// Card visual: rounded white container, coloured emoji tile, title +
// description, format pills (PDF / CSV). Mirrors the HTML mockup
// screenshots verbatim.

import 'package:flutter/material.dart';

import '../../core/models/report.dart';
import '../../core/service/api_service.dart';
import '../dairy/dairy_reports_page.dart';
import '../health/health_reports_page.dart';
import '../layers/layers_reports_page.dart';
import 'report_preview_page.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});
  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  static const _primary = Color(0xFF27500A);
  static const _txt2 = Color(0xFF6B7770);

  // Render order — matches the HTML reference layout.
  static const _categoryOrder = [
    'Daily & Production',
    'Health & Animal',
    'Inventory & Operations',
    'Financial & Strategic',
  ];

  // Short labels + emojis for the pill row. The full category name is
  // still the source of truth for grouping — the pills are display-only.
  static const _pillLabels = <String, (String, String)>{
    'Daily & Production': ('📅', 'Daily'),
    'Health & Animal': ('🐮', 'Health'),
    'Inventory & Operations': ('📦', 'Inventory'),
    'Financial & Strategic': ('💰', 'Financial'),
  };

  late Future<List<ReportListItem>> _future;
  String? _selectedCat;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<ReportListItem>> _load() async {
    final raw = await ApiService.getReportsCatalog();
    return raw
        .whereType<Map>()
        .map((m) => ReportListItem.fromJson(m.cast<String, dynamic>()))
        .toList();
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<ReportListItem>>(
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
          final items = snap.data ?? const <ReportListItem>[];
          final groups = <String, List<ReportListItem>>{};
          for (final i in items) {
            groups.putIfAbsent(i.category, () => []).add(i);
          }
          final orderedCats = [
            ..._categoryOrder.where(groups.containsKey),
            ...groups.keys.where((k) => !_categoryOrder.contains(k)),
          ];
          // Lock the selected category to one that actually has reports
          // — handles first paint + the rare case where the previously
          // selected category disappears after a refresh.
          final active = (orderedCats.contains(_selectedCat)
                  ? _selectedCat
                  : orderedCats.isNotEmpty
                      ? orderedCats.first
                      : null) ??
              '';
          final visibleReports = groups[active] ?? const <ReportListItem>[];

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 80),
            children: [
              _PageHeader(total: items.length),
              const SizedBox(height: 18),
              if (orderedCats.isNotEmpty) ...[
                _CategoryPills(
                  categories: orderedCats,
                  counts: {
                    for (final c in orderedCats) c: groups[c]!.length,
                  },
                  pillLabels: _pillLabels,
                  active: active,
                  onSelect: (c) => setState(() => _selectedCat = c),
                ),
                const SizedBox(height: 16),
              ],
              if (visibleReports.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(
                    child: Text(
                      'No reports in this category yet.',
                      style: TextStyle(
                        fontSize: 12,
                        color: _txt2,
                      ),
                    ),
                  ),
                )
              else
                _ReportCardGrid(
                  reports: visibleReports,
                  onOpen: (r) {
                    // Reports with a `dashboardKey` skip the catalog
                    // preview and open their in-app dashboard surface
                    // instead. Today only the renamed "Dairy Report"
                    // sets this, routing into the filter-aware Dairy
                    // Reports page (Milk · Reproduction · Health ·
                    // Vaccinations) where the user can drive the
                    // filters and export from there.
                    if (r.dashboardKey == 'dairy') {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const DairyReportsPage(),
                        ),
                      );
                      return;
                    }
                    if (r.dashboardKey == 'layers') {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const LayersReportsPage(),
                        ),
                      );
                      return;
                    }
                    if (r.dashboardKey == 'health') {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const HealthReportsPage(),
                        ),
                      );
                      return;
                    }
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ReportPreviewPage(report: r),
                      ),
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

// ===================================================================
// Category pills — replaces the per-section dark-green banner stack
// ===================================================================

class _CategoryPills extends StatelessWidget {
  const _CategoryPills({
    required this.categories,
    required this.counts,
    required this.pillLabels,
    required this.active,
    required this.onSelect,
  });

  final List<String> categories;
  final Map<String, int> counts;
  final Map<String, (String, String)> pillLabels;
  final String active;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          for (final c in categories) ...[
            _CategoryPill(
              emoji: pillLabels[c]?.$1 ?? '📁',
              // Use the short label when we know it; fall back to the
              // full category name for any unrecognised category so the
              // UI still renders something legible.
              label: pillLabels[c]?.$2 ?? c,
              count: counts[c] ?? 0,
              active: c == active,
              onTap: () => onSelect(c),
            ),
            if (c != categories.last) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({
    required this.emoji,
    required this.label,
    required this.count,
    required this.active,
    required this.onTap,
  });
  final String emoji;
  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = active ? _ReportsPageState._primary : Colors.white;
    final fg = active ? Colors.white : Colors.black87;
    final border =
        active ? _ReportsPageState._primary : const Color(0x33000000);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border),
          boxShadow: active
              ? const [
                  BoxShadow(
                    color: Color(0x1A27500A),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
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
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
              decoration: BoxDecoration(
                color: active
                    ? const Color(0x33FFFFFF)
                    : const Color(0xFFF5F5F2),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: active ? Colors.white : _ReportsPageState._txt2,
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
// Header
// ===================================================================

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.total});
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF3DE),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Text('📊', style: TextStyle(fontSize: 22)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Reports & Exports',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _ReportsPageState._primary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Print-ready reports with farm letterhead, live data and signature blocks · '
                'Showing $total report${total == 1 ? '' : 's'}',
                style: const TextStyle(
                  fontSize: 12,
                  color: _ReportsPageState._txt2,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ===================================================================
// Card grid
// ===================================================================

class _ReportCardGrid extends StatelessWidget {
  const _ReportCardGrid({required this.reports, required this.onOpen});
  final List<ReportListItem> reports;
  final ValueChanged<ReportListItem> onOpen;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 900
            ? 3
            : c.maxWidth >= 560
                ? 2
                : 1;
        final w = (c.maxWidth - 12 * (cols - 1)) / cols;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final r in reports)
              SizedBox(
                width: w,
                child: _ReportCard(report: r, onTap: () => onOpen(r)),
              ),
          ],
        );
      },
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report, required this.onTap});
  final ReportListItem report;
  final VoidCallback onTap;

  Color _parseHex(String hex) {
    final s = hex.replaceFirst('#', '');
    final v = int.tryParse(s, radix: 16) ?? 0xEAF3DE;
    return Color(0xFF000000 | v);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _parseHex(report.iconBg),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(report.icon, style: const TextStyle(fontSize: 20)),
            ),
            const SizedBox(height: 10),
            Text(
              report.label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: _ReportsPageState._primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              report.description,
              style: const TextStyle(
                fontSize: 12,
                color: _ReportsPageState._txt2,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              children: [
                for (final f in report.formats) _FormatPill(label: f),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FormatPill extends StatelessWidget {
  const _FormatPill({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: _ReportsPageState._txt2,
          letterSpacing: 0.05,
        ),
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
          'Could not load reports',
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
