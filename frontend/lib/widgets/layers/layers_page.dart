import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/layers.dart' as legacy;
import '../../core/models/layers_unit.dart';
import '../../core/service/api_service.dart';
import '../dashboard/kpi_card.dart';
import '../dashboard/kpi_grid.dart';
import 'section_tabs.dart';

/// Layers Unit page (composed from the unified `/api/layers-unit` endpoint).
///
/// Layout top → bottom:
///   1. Page header (title + sub-line: house count + brooder + target)
///   2. 4 KPIs: Layers in production · Brooder chicks · Crates today · Mortality today
///   3. Brooder house card (KPIs + progress + vaccination timeline + allocation plan)
///   4. 2-col row: Layer houses table | 7-day production chart
///   5. Daily-entry form (legacy — lets a manager log today's house entry)
class LayersPage extends StatefulWidget {
  const LayersPage({super.key});

  @override
  State<LayersPage> createState() => _LayersPageState();
}

class _LayersPageState extends State<LayersPage> {
  Future<_PageData>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_PageData> _load() async {
    final unitRaw = await ApiService.getLayersUnit();
    final unit = LayersUnit.fromJson(unitRaw.cast<String, dynamic>());

    // Pull legacy per-house production history for the inline daily-entry
    // form so logging today's eggs still works. Fall back gracefully when
    // there are no houses or no records.
    legacy.ProductionHistory? history;
    if (unit.layers.houses.isNotEmpty) {
      final firstId = unit.layers.houses.first.id;
      try {
        final raw = await ApiService.getLayersProductionForHouse(firstId);
        history = legacy.ProductionHistory.fromJson(
          raw.cast<String, dynamic>(),
        );
      } catch (_) {
        history = null;
      }
    }

    return _PageData(unit: unit, history: history);
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<_PageData>(
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
          final unit = data.unit;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 80),
            children: [
              _PageHeader(
                houseCount: unit.layers.houses.length,
                brooderPresent: unit.brooder != null,
                houses: unit.layers.houses,
                onLogged: _refresh,
              ),
              const SizedBox(height: 16),
              _KpiRow(unit: unit),
              const SizedBox(height: 16),
              LayersSectionTabs(
                unit: unit,
                history: data.history,
                onSubmittedDailyEntry: _refresh,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PageData {
  _PageData({required this.unit, this.history});
  final LayersUnit unit;
  final legacy.ProductionHistory? history;
}

class _PageHeader extends StatefulWidget {
  const _PageHeader({
    required this.houseCount,
    required this.brooderPresent,
    required this.houses,
    required this.onLogged,
  });
  final int houseCount;
  final bool brooderPresent;
  final List<LayerHouseView> houses;

  /// Fired after the "Log Eggs" dialog saves at least one entry — caller
  /// re-fetches `/layers-unit` so the KPIs and tables refresh.
  final VoidCallback onLogged;

  @override
  State<_PageHeader> createState() => _PageHeaderState();
}

class _PageHeaderState extends State<_PageHeader> {
  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF27500A);
    final brooderLabel = widget.brooderPresent ? ' + 1 brooder' : '';

    final title = Row(
      children: [
        // 🥚 unit icon — matches the HTML's `unit-ico` square.
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFFAEEDA),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Text('🥚', style: TextStyle(fontSize: 20)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Layers Unit',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: primary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${widget.houseCount} layer houses$brooderLabel · Target 700 crates/day',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ),
      ],
    );

    // Log Eggs lives inside the Eggs pill's action area, so the page
    // header is just the unit title + subtitle.
    return LayoutBuilder(
      builder: (context, c) {
        return title;
      },
    );
  }
}

class _KpiRow extends StatelessWidget {
  const _KpiRow({required this.unit});
  final LayersUnit unit;

  static const _target = 700;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern();
    final layers = unit.layers;
    final brooder = unit.brooder;

    final layingHouses = layers.houses.map((h) => h.name).join(', ');
    final layingAge = layers.houses.isEmpty
        ? '—'
        : 'Day ${layers.houses.map((h) => h.flockAgeDays).reduce((a, b) => a > b ? a : b)}';

    final cratesPct = _target > 0
        ? ((layers.cratesToday / _target) * 100).round()
        : 0;

    final mortalityPct = layers.totalBirds > 0
        ? (layers.mortalityToday / layers.totalBirds) * 100
        : 0.0;

    final brooderSub = brooder == null
        ? '—'
        : '${(brooder.ageDays / 30).toStringAsFixed(1)} months old';

    final cards = <Widget>[
      KpiCard(
        label: 'Layers in production',
        value: fmt.format(layers.totalBirds),
        sub: layers.houses.isEmpty
            ? 'No houses'
            : 'Houses $layingHouses ($layingAge)',
      ),
      KpiCard(
        label: 'Brooder chicks',
        value: brooder == null ? '—' : fmt.format(brooder.population),
        sub: brooderSub,
      ),
      KpiCard(
        label: 'Crates today',
        value: _formatNum(layers.cratesToday),
        sub: '$cratesPct% of $_target target',
      ),
      KpiCard(
        label: 'Mortality today',
        value: '${layers.mortalityToday}',
        sub: '${mortalityPct.toStringAsFixed(2)}% — ${_mortalityLabel(mortalityPct)}',
        trendColor:
            mortalityPct > 0.1 ? const Color(0xFFE24B4A) : const Color(0xFF27500A),
      ),
    ];

    return KpiGrid(children: cards);
  }

  static String _formatNum(num n) {
    if (n == n.roundToDouble()) {
      return NumberFormat.decimalPattern().format(n.toInt());
    }
    return n.toStringAsFixed(1);
  }

  static String _mortalityLabel(double pct) {
    if (pct == 0) return 'no losses';
    if (pct < 0.1) return 'acceptable';
    if (pct < 0.3) return 'monitor';
    return 'high';
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
        Text(
          'Could not load Layers Unit',
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
