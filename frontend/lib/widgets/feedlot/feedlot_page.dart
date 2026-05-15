import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/feedlot.dart';
import '../../core/service/api_service.dart';
import '../dairy/report_sick_dialog.dart';
import '../dashboard/kpi_card.dart';
import '../dashboard/kpi_grid.dart';
import '../reminders/unit_reminders_card.dart';
import 'add_bull_dialog.dart';
import 'add_dooper_dialog.dart';
import 'bull_register_table.dart';
import 'doopers_register_table.dart';
import 'feedlot_inventory_card.dart';
import 'feedlot_pill_tabs.dart';

/// Feedlot & Doopers page — pill-driven layout matching the Dairy /
/// Layers / Staff / Feeds modules. Composition top → bottom:
///   • Unit header
///   • 4 KPI cards (pinned across pills)
///   • Pill row (11 sections)
///   • Body for the active pill
///
/// All existing functionality is preserved: the `BullRegisterTable` and
/// `DoopersRegisterTable` widgets render unchanged, the add-bull /
/// add-dooper dialogs still fire from the page, and the SOP tag
/// allocation logic on the backend stays untouched. The new sections
/// (Health / Feeding / Breeding / Inventory / Weights / Sales / Reports
/// / Observations) render a "Coming soon" placeholder until their data
/// models land.
class FeedlotPage extends StatefulWidget {
  const FeedlotPage({super.key});

  @override
  State<FeedlotPage> createState() => _FeedlotPageState();
}

class _FeedlotData {
  _FeedlotData({
    required this.kpis,
    required this.bulls,
    required this.sheep,
  });
  final FeedlotKpis kpis;
  final List<BullView> bulls;
  final List<SheepView> sheep;
}

class _FeedlotPageState extends State<FeedlotPage> {
  static const _primary = Color(0xFF27500A);
  static const _txt2 = Color(0xFF6B7770);

  Future<_FeedlotData>? _future;
  FeedlotTab _active = FeedlotTab.overview;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_FeedlotData> _load() async {
    final kpisFuture = ApiService.getFeedlotKpis();
    final bullsFuture = ApiService.getFeedlotBulls();
    final sheepFuture = ApiService.getFeedlotSheep();

    final kpis = FeedlotKpis.fromJson(
      (await kpisFuture).cast<String, dynamic>(),
    );
    final bulls = (await bullsFuture)
        .whereType<Map>()
        .map((m) => BullView.fromJson(m.cast<String, dynamic>()))
        .toList();
    final sheep = (await sheepFuture)
        .whereType<Map>()
        .map((m) => SheepView.fromJson(m.cast<String, dynamic>()))
        .toList();

    return _FeedlotData(kpis: kpis, bulls: bulls, sheep: sheep);
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _openAddBull() async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AddBullDialog(),
    );
    if (saved == true) {
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bull added to feedlot')),
        );
      }
    }
  }

  Future<void> _openAddDooper() async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AddDooperDialog(),
    );
    if (saved == true) {
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Doopers added to flock')),
        );
      }
    }
  }

  Future<void> _openReportSick(String unit) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ReportSickDialog(defaultUnit: unit),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sick animal reported to vet')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<_FeedlotData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return _ErrorView(
              message: snap.error.toString().replaceFirst('Exception: ', ''),
              onRetry: _refresh,
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
              FeedlotPillTabs(
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

  List<Widget> _tabBody(_FeedlotData data) {
    switch (_active) {
      case FeedlotTab.overview:
        return [
          _CapacityCard(kpis: data.kpis),
          const SizedBox(height: 16),
          _OverviewActions(
            onAddBull: _openAddBull,
            onAddDooper: _openAddDooper,
            onOpenBulls: () => setState(() => _active = FeedlotTab.bulls),
            onOpenDoppers:
                () => setState(() => _active = FeedlotTab.doppers),
          ),
          const SizedBox(height: 16),
          _GlanceRow(
            bullsCount: data.bulls.length,
            sheepCount: data.sheep.length,
            doopersFlock: data.kpis.doopersFlock,
            lambsThisMonth: data.kpis.lambsThisMonth,
          ),
        ];
      case FeedlotTab.bulls:
        return [
          _SectionActionBar(
            label: 'Add bull',
            emoji: '🐂',
            onTap: _openAddBull,
            onReportSick: () => _openReportSick('Feedlot'),
          ),
          const SizedBox(height: 10),
          BullRegisterTable(
            bulls: data.bulls,
            onChanged: _refresh,
          ),
        ];
      case FeedlotTab.doppers:
        return [
          _SectionActionBar(
            label: 'Add dopper',
            emoji: '🐑',
            onTap: _openAddDooper,
            onReportSick: () => _openReportSick('Doopers'),
          ),
          const SizedBox(height: 10),
          DoopersRegisterTable(
            sheep: data.sheep,
            onChanged: _refresh,
          ),
        ];
      case FeedlotTab.health:
        // Pull straight from the Reminders module — feedlot vaccines,
        // deworming, and follow-up reminders are already generated
        // there from the Health/Vaccine protocols and treatments.
        // Sub-pills let the user toggle between Feedlot bulls and
        // Doopers sheep since both share the unit's vet but are
        // tagged separately in the Health module.
        return const [_HealthSubPills()];
      case FeedlotTab.feeding:
        return [
          _ModuleLinkCard(
            emoji: '🌾',
            title: 'Feed comes from the Feeds module',
            body:
                'Feedlot rations are tracked in the central Feeds module '
                "alongside the rest of the farm's raw materials and "
                'distribution. Daily allocations, stock levels, and feed '
                'cost are computed there — no duplicate logic in Feedlot.',
            bullets: [
              'Concentrate, silage, and napier daily allocations',
              'Stock-on-hand and days-left for every raw material',
              'Reorder alerts when stock drops below lead-time × usage',
            ],
            cta: 'Open the Feeds module',
          ),
        ];
      case FeedlotTab.breeding:
        return [
          _ComingSoon(
            tab: _active,
            description:
                'Breeding — sire / dam lineage, breeding dates, '
                'conception rates, lambing/calving intervals.',
          ),
        ];
      case FeedlotTab.inventory:
        return [const FeedlotInventoryCard()];
      case FeedlotTab.weights:
        return [
          _ComingSoon(
            tab: _active,
            description:
                'Weight management — periodic weight logs, average daily '
                'gain (ADG), growth charts, target market-weight tracking.',
          ),
        ];
      case FeedlotTab.sales:
        return [
          _ComingSoon(
            tab: _active,
            description:
                'Sales — sold animals, buyer, sale weight, price/kg, '
                'transport cost, profit estimate. Printable invoice / '
                'receipt support.',
          ),
        ];
      case FeedlotTab.reports:
        return [
          _ComingSoon(
            tab: _active,
            description:
                'Reports — mortality · sales · vaccination · feed cost · '
                'breeding · weight gain. PDF + CSV export.',
          ),
        ];
      case FeedlotTab.observations:
        return [
          _ComingSoon(
            tab: _active,
            description:
                'Observations — pinned notes, priorities, linked animal '
                'tags, filtering, attachments.',
          ),
        ];
    }
  }
}

// =====================================================================
// Unit header
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
            color: const Color(0xFFE1F5EE),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Text('🐂', style: TextStyle(fontSize: 20)),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Feedlot & Doopers',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: _FeedlotPageState._primary,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Capacity target: 100 bulls · Tag registry · '
                'Doopers flock',
                style: TextStyle(
                  fontSize: 12,
                  color: _FeedlotPageState._txt2,
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
// KPI row (same on every pill)
// =====================================================================

class _KpiRow extends StatelessWidget {
  const _KpiRow({required this.kpis});
  final FeedlotKpis kpis;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern();
    final cards = <Widget>[
      KpiCard(
        label: 'Bulls on feed',
        value: fmt.format(kpis.bullsOnFeed),
        sub: kpis.bullsOnFeed >= 50 ? 'At target' : 'Building up',
      ),
      KpiCard(
        label: 'Avg days on feed',
        value: fmt.format(kpis.avgDaysOnFeed),
        sub: 'Target: dispose at 60d',
      ),
      KpiCard(
        label: 'Doopers flock',
        value: fmt.format(kpis.doopersFlock),
        sub: 'Ewes, rams, lambs',
      ),
      KpiCard(
        label: 'Lambs this month',
        value: fmt.format(kpis.lambsThisMonth),
        sub: 'Live births',
      ),
    ];

    return KpiGrid(children: cards);
  }
}

// =====================================================================
// Overview pill — capacity, quick actions, glance row
// =====================================================================

class _CapacityCard extends StatelessWidget {
  const _CapacityCard({required this.kpis});
  final FeedlotKpis kpis;

  @override
  Widget build(BuildContext context) {
    const target = 100;
    final current = kpis.bullsOnFeed;
    final pct = (current / target * 100).clamp(0, 100).toDouble();
    final remaining = (target - current).clamp(0, target);

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
            '📊  PATH TO 100-BULL CAPACITY',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: _FeedlotPageState._primary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$current',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: _FeedlotPageState._primary,
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                '/ $target bulls',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _FeedlotPageState._txt2,
                ),
              ),
              const Spacer(),
              Text(
                '${pct.toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: _FeedlotPageState._primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Capacity progress bar.
          Stack(
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: const Color(0xFFE9ECE5),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: pct / 100),
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOut,
                builder: (_, value, __) => FractionallySizedBox(
                  widthFactor: value,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: _FeedlotPageState._primary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            remaining > 0
                ? '$remaining bulls to add to reach the 100-head target. '
                    'Tags are pre-allocated YY-NNN; allocate the next in '
                    'sequence as new calves arrive.'
                : 'Capacity reached. New intake should rotate against '
                    'animals scheduled for sale.',
            style: const TextStyle(
              fontSize: 11,
              color: _FeedlotPageState._txt2,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewActions extends StatelessWidget {
  const _OverviewActions({
    required this.onAddBull,
    required this.onAddDooper,
    required this.onOpenBulls,
    required this.onOpenDoppers,
  });
  final VoidCallback onAddBull;
  final VoidCallback onAddDooper;
  final VoidCallback onOpenBulls;
  final VoidCallback onOpenDoppers;

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
              color: _FeedlotPageState._txt2,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _QuickPill(
                emoji: '🐂',
                label: 'Tag a calf',
                onTap: onAddBull,
              ),
              _QuickPill(
                emoji: '🐑',
                label: 'Add doopers',
                onTap: onAddDooper,
              ),
              _QuickPill(
                emoji: '📋',
                label: 'Bulls register',
                onTap: onOpenBulls,
              ),
              _QuickPill(
                emoji: '📋',
                label: 'Doopers register',
                onTap: onOpenDoppers,
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
                color: _FeedlotPageState._primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlanceRow extends StatelessWidget {
  const _GlanceRow({
    required this.bullsCount,
    required this.sheepCount,
    required this.doopersFlock,
    required this.lambsThisMonth,
  });
  final int bullsCount;
  final int sheepCount;
  final int doopersFlock;
  final int lambsThisMonth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 600;
        final bulls = _GlanceCard(
          emoji: '🐂',
          title: 'Bull tag registry',
          headline: '$bullsCount tags',
          sub: 'allocated for this year',
        );
        final doppers = _GlanceCard(
          emoji: '🐑',
          title: 'Doopers flock',
          headline: '$doopersFlock head',
          sub: '$lambsThisMonth lambs this month · $sheepCount records',
        );
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: bulls),
              const SizedBox(width: 12),
              Expanded(child: doppers),
            ],
          );
        }
        return Column(
          children: [bulls, const SizedBox(height: 12), doppers],
        );
      },
    );
  }
}

class _GlanceCard extends StatelessWidget {
  const _GlanceCard({
    required this.emoji,
    required this.title,
    required this.headline,
    required this.sub,
  });
  final String emoji;
  final String title;
  final String headline;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAF7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFE1F5EE),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: _FeedlotPageState._txt2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  headline,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _FeedlotPageState._primary,
                  ),
                ),
                Text(
                  sub,
                  style: const TextStyle(
                    fontSize: 11,
                    color: _FeedlotPageState._txt2,
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

// =====================================================================
// Coming-soon placeholder
// =====================================================================

// Action bar shown above the Bulls / Doppers register tables. Provides
// an obvious "+ Add bull" / "+ Add dopper" entry point on the pill
// itself, separate from the Overview quick-actions row.
class _SectionActionBar extends StatelessWidget {
  const _SectionActionBar({
    required this.label,
    required this.emoji,
    required this.onTap,
    this.onReportSick,
  });
  final String label;
  final String emoji;
  final VoidCallback onTap;
  final VoidCallback? onReportSick;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (onReportSick != null) ...[
          OutlinedButton.icon(
            onPressed: onReportSick,
            icon: const Text('🤒', style: TextStyle(fontSize: 14)),
            label: const Text('Report sick'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFC0392B),
              side: const BorderSide(color: Color(0xFFC0392B)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              textStyle:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        FilledButton.icon(
          onPressed: onTap,
          icon: Text(emoji, style: const TextStyle(fontSize: 14)),
          label: Text('+ $label'),
          style: FilledButton.styleFrom(
            backgroundColor: _FeedlotPageState._primary,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            textStyle:
                const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    );
  }
}

// Cross-module link card — used by the Feeding pill to explicitly
// point the user at the Feeds module instead of building duplicate
// feed-management UI in Feedlot.
/// Health pill body — two sub-pills (Feedlot · Doopers) that swap the
/// underlying [UnitRemindersCard] filter. Lives here (rather than in a
/// generic widget) because the Doopers/Feedlot pairing is specific to
/// this module — the central Reminders module still treats them as
/// separate units in the API.
class _HealthSubPills extends StatefulWidget {
  const _HealthSubPills();

  @override
  State<_HealthSubPills> createState() => _HealthSubPillsState();
}

class _HealthSubPillsState extends State<_HealthSubPills> {
  String _unit = 'Feedlot';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _SubPill(
              emoji: '🐂',
              label: 'Feedlot',
              selected: _unit == 'Feedlot',
              onTap: () => setState(() => _unit = 'Feedlot'),
            ),
            const SizedBox(width: 8),
            _SubPill(
              emoji: '🐑',
              label: 'Doopers',
              selected: _unit == 'Doopers',
              onTap: () => setState(() => _unit = 'Doopers'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // ValueKey forces a fresh state when the unit changes so the
        // card's _future re-fetches against the new filter.
        UnitRemindersCard(
          key: ValueKey('health-$_unit'),
          unit: _unit,
        ),
      ],
    );
  }
}

class _SubPill extends StatelessWidget {
  const _SubPill({
    required this.emoji,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? _FeedlotPageState._primary : Colors.white;
    final fg = selected ? Colors.white : Colors.black87;
    final border = selected
        ? _FeedlotPageState._primary
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
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModuleLinkCard extends StatelessWidget {
  const _ModuleLinkCard({
    required this.emoji,
    required this.title,
    required this.body,
    required this.bullets,
    required this.cta,
  });
  final String emoji;
  final String title;
  final String body;
  final List<String> bullets;
  final String cta;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF3DE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(emoji, style: const TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _FeedlotPageState._primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: const TextStyle(
              fontSize: 12,
              color: _FeedlotPageState._txt2,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          for (final b in bullets)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '•  ',
                    style: TextStyle(
                      fontSize: 12,
                      color: _FeedlotPageState._primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      b,
                      style: const TextStyle(
                        fontSize: 12,
                        color: _FeedlotPageState._txt2,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          // Plain hint — switching modules is via the app drawer, so
          // this is just a textual pointer rather than a button.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF6F8F4),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.open_in_new,
                    size: 12, color: _FeedlotPageState._primary),
                const SizedBox(width: 4),
                Text(
                  cta,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: _FeedlotPageState._primary,
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

class _ComingSoon extends StatelessWidget {
  const _ComingSoon({required this.tab, required this.description});
  final FeedlotTab tab;
  final String description;

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
              color: _FeedlotPageState._primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: _FeedlotPageState._txt2,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// Error
// =====================================================================

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
        Text(
          'Could not load feedlot data',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
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
