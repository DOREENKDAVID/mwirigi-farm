import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/feeds.dart';
import '../../core/service/api_service.dart';
import '../dashboard/kpi_card.dart';
import '../dashboard/kpi_grid.dart';
import 'bulk_feed_card.dart';
import 'distribution_card.dart';
import 'feeds_pill_tabs.dart';
import 'log_delivery_dialog.dart';
import 'raw_material_inventory.dart';

/// Feeds Management dashboard — pill-driven layout matching the
/// Dairy / Layers / Staff modules.
///
/// Top → bottom:
///   • Unit header (🌾 + title + subtitle)
///   • 4 KPI cards (Materials tracked / Critical / Low / Adequate)
///   • Pill row (Overview / Raw Materials / Deliveries / Factory /
///                Bulk / Distribution / Inventory / Analytics)
///   • Body for the active pill
///
/// Implemented pill bodies: Overview · Raw Materials · Bulk Feed ·
/// Distribution. The remaining four (Deliveries · Factory · Inventory
/// · Analytics) render a "Coming soon" placeholder with the planned
/// content — the nav structure is in place so they can be wired in
/// follow-up turns without reshuffling the page.
class FeedsPage extends StatefulWidget {
  const FeedsPage({super.key});

  @override
  State<FeedsPage> createState() => _FeedsPageState();
}

class _FeedsPageState extends State<FeedsPage> {
  static const _primary = Color(0xFF27500A);
  static const _txt2 = Color(0xFF6B7770);

  Future<_FeedsBundle>? _future;
  FeedsTab _active = FeedsTab.overview;
  final _inventoryKey = GlobalKey<RawMaterialInventoryState>();

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_FeedsBundle> _load() async {
    final kpisFuture = ApiService.getFeedsDashboard();
    final bulkFuture = ApiService.getBulkFeed();
    final distFuture = ApiService.getFeedDistribution();
    final materialsFuture = ApiService.getFeedMaterials(limit: 200);

    final kpis = FeedKpis.fromJson(
      (await kpisFuture).cast<String, dynamic>(),
    );
    final bulk = (await bulkFuture)
        .whereType<Map>()
        .map((m) => BulkFeed.fromJson(m.cast<String, dynamic>()))
        .toList(growable: false);
    final dist = (await distFuture)
        .whereType<Map>()
        .map((m) => FeedDistribution.fromJson(m.cast<String, dynamic>()))
        .toList(growable: false);
    final materials = ((await materialsFuture)['items'] as List? ?? const [])
        .whereType<Map>()
        .map((m) => FeedMaterial.fromJson(m.cast<String, dynamic>()))
        .toList(growable: false);

    return _FeedsBundle(
      kpis: kpis,
      bulkFeed: bulk,
      distribution: dist,
      materials: materials,
    );
  }

  Future<void> _refreshAll() async {
    setState(() => _future = _load());
    await Future.wait([
      _future!,
      _inventoryKey.currentState?.reload() ?? Future.value(),
    ]);
  }

  void _refreshKpisOnly() {
    setState(() => _future = _load());
  }

  Future<void> _openLogDelivery(List<FeedMaterial> materials) async {
    if (materials.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add a material before logging a delivery.'),
        ),
      );
      return;
    }
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => LogDeliveryDialog(materials: materials),
    );
    if (saved == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Delivery logged')),
        );
      }
      await _refreshAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: FutureBuilder<_FeedsBundle>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return _ErrorView(
              message: snap.error.toString().replaceFirst('Exception: ', ''),
              onRetry: _refreshAll,
            );
          }
          final data = snap.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 80),
            children: [
              const _UnitHeader(),
              const SizedBox(height: 16),
              _KpiRow(kpis: data.kpis),
              const SizedBox(height: 16),
              FeedsPillTabs(
                selected: _active,
                onSelect: (t) => setState(() => _active = t),
              ),
              const SizedBox(height: 16),
              ..._tabBody(data),
            ],
          );
        },
      ),
    );
  }

  // ----------------- Pill body dispatch -----------------

  List<Widget> _tabBody(_FeedsBundle data) {
    switch (_active) {
      case FeedsTab.overview:
        // Light snapshot: alerts row + quick actions + side-by-side
        // bulk / distribution previews. Full inventory drill-down
        // lives behind the Raw Materials pill.
        return [
          _AlertsCard(kpis: data.kpis),
          const SizedBox(height: 16),
          _QuickActions(
            onLogDelivery: () => _openLogDelivery(data.materials),
            onOpenRaw: () => setState(() => _active = FeedsTab.rawMaterials),
            onOpenFactory: () => setState(() => _active = FeedsTab.factory),
            onOpenBulk: () => setState(() => _active = FeedsTab.bulk),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth >= 880;
              final bulk = BulkFeedCard(entries: data.bulkFeed);
              final dist = DistributionCard(
                rows: data.distribution,
                onChanged: _refreshKpisOnly,
              );
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: bulk),
                    const SizedBox(width: 16),
                    Expanded(child: dist),
                  ],
                );
              }
              return Column(
                children: [bulk, const SizedBox(height: 16), dist],
              );
            },
          ),
        ];
      case FeedsTab.rawMaterials:
        return [
          RawMaterialInventory(
            key: _inventoryKey,
            kpis: data.kpis,
            onChanged: _refreshKpisOnly,
          ),
        ];
      case FeedsTab.bulk:
        return [BulkFeedCard(entries: data.bulkFeed)];
      case FeedsTab.distribution:
        return [
          DistributionCard(
            rows: data.distribution,
            onChanged: _refreshKpisOnly,
          ),
        ];
      case FeedsTab.deliveries:
        return [
          _ComingSoon(
            tab: _active,
            description:
                'Dedicated deliveries log — supplier, invoice, GRN, '
                'cost history. The Raw Materials pill already supports '
                'logging a delivery against any material.',
            onPrimary: () => _openLogDelivery(data.materials),
            primaryLabel: 'Log delivery now',
          ),
        ];
      case FeedsTab.factory:
        return [
          _ComingSoon(
            tab: _active,
            description:
                'Feed production batches — formulation runs, ingredient '
                'usage, production output, cost/kg, wastage. Needs the '
                '`FeedBatch` data model on the backend.',
          ),
        ];
      case FeedsTab.inventory:
        return [
          _ComingSoon(
            tab: _active,
            description:
                'Feeds-factory warehouse inventory — raw materials, '
                'finished feeds, supplements, minerals, additives. '
                'Stock movement history, expiry tracking, valuation.',
          ),
        ];
      case FeedsTab.analytics:
        return [
          _ComingSoon(
            tab: _active,
            description:
                'Consumption trends, material usage, cost analysis, '
                'supplier performance, projected depletion. Reuses the '
                'existing daily-use math from raw materials.',
          ),
        ];
    }
  }
}

class _FeedsBundle {
  _FeedsBundle({
    required this.kpis,
    required this.bulkFeed,
    required this.distribution,
    required this.materials,
  });
  final FeedKpis kpis;
  final List<BulkFeed> bulkFeed;
  final List<FeedDistribution> distribution;
  final List<FeedMaterial> materials;
}

// =====================================================================
// Unit header (no top button — actions live in the Overview pill body)
// =====================================================================

class _UnitHeader extends StatelessWidget {
  const _UnitHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF3DE),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Text('🌾', style: TextStyle(fontSize: 20)),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Feeds Management',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: _FeedsPageState._primary,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Raw materials · Factory · Silage · Distribution',
                style: TextStyle(
                  fontSize: 12,
                  color: _FeedsPageState._txt2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =====================================================================
// KPI row (pinned, same on every pill)
// =====================================================================

class _KpiRow extends StatelessWidget {
  const _KpiRow({required this.kpis});
  final FeedKpis kpis;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern();
    final cards = <Widget>[
      KpiCard(
        label: 'Materials tracked',
        value: fmt.format(kpis.materialsTracked),
        sub: 'Active raw materials',
      ),
      KpiCard(
        label: 'Critical / order now',
        value: fmt.format(kpis.critical),
        sub: 'Below reorder level',
        trend: kpis.critical > 0 ? 'Reorder' : null,
        trendColor: const Color(0xFFB42318),
      ),
      KpiCard(
        label: 'Low / monitor',
        value: fmt.format(kpis.low),
        sub: 'Within lead time',
        trend: kpis.low > 0 ? 'Watch' : null,
        trendColor: const Color(0xFF854F0B),
      ),
      KpiCard(
        label: 'Adequate',
        value: fmt.format(kpis.adequate),
        sub: 'Healthy stock',
        trendColor: const Color(0xFF27500A),
      ),
    ];

    return KpiGrid(children: cards);
  }
}

// =====================================================================
// Overview pill — alerts + quick actions
// =====================================================================

class _AlertsCard extends StatelessWidget {
  const _AlertsCard({required this.kpis});
  final FeedKpis kpis;

  @override
  Widget build(BuildContext context) {
    final hasCritical = kpis.critical > 0;
    final hasLow = kpis.low > 0;
    final allClear = !hasCritical && !hasLow;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: allClear ? const Color(0xFFEFF5E6) : const Color(0xFFFCEDC8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            allClear ? Icons.check_circle_outline : Icons.warning_amber_rounded,
            color: allClear
                ? const Color(0xFF27500A)
                : const Color(0xFF8A5A0A),
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  allClear
                      ? 'Feed stock is healthy.'
                      : 'Stock attention needed',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: allClear
                        ? const Color(0xFF27500A)
                        : const Color(0xFF8A5A0A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  allClear
                      ? 'No materials below reorder level. Keep an eye on consumption rates.'
                      : '${kpis.critical} critical · ${kpis.low} low · '
                          'open the Raw Materials pill to action.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: _FeedsPageState._txt2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onLogDelivery,
    required this.onOpenRaw,
    required this.onOpenFactory,
    required this.onOpenBulk,
  });
  final VoidCallback onLogDelivery;
  final VoidCallback onOpenRaw;
  final VoidCallback onOpenFactory;
  final VoidCallback onOpenBulk;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'QUICK ACTIONS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: _FeedsPageState._txt2,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _QuickPill(
                emoji: '🚚',
                label: 'Log delivery',
                onTap: onLogDelivery,
              ),
              _QuickPill(
                emoji: '📦',
                label: 'Raw materials',
                onTap: onOpenRaw,
              ),
              _QuickPill(
                emoji: '🏭',
                label: 'Factory batch',
                onTap: onOpenFactory,
              ),
              _QuickPill(
                emoji: '🌱',
                label: 'Bulk feed',
                onTap: onOpenBulk,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickPill extends StatelessWidget {
  const _QuickPill({
    required this.emoji,
    required this.label,
    required this.onTap,
  });
  final String emoji;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFFF6F8F4),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0x14000000)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _FeedsPageState._primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// Coming-soon placeholder for deferred pills
// =====================================================================

class _ComingSoon extends StatelessWidget {
  const _ComingSoon({
    required this.tab,
    required this.description,
    this.onPrimary,
    this.primaryLabel,
  });
  final FeedsTab tab;
  final String description;
  final VoidCallback? onPrimary;
  final String? primaryLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: Column(
        children: [
          Text(tab.emoji, style: const TextStyle(fontSize: 36)),
          const SizedBox(height: 8),
          Text(
            '${tab.label} — coming soon',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: _FeedsPageState._primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: _FeedsPageState._txt2,
              height: 1.5,
            ),
          ),
          if (onPrimary != null && primaryLabel != null) ...[
            const SizedBox(height: 14),
            FilledButton(
              onPressed: onPrimary,
              style: FilledButton.styleFrom(
                backgroundColor: _FeedsPageState._primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
              ),
              child: Text(primaryLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                size: 36, color: Color(0xFF854F0B)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
