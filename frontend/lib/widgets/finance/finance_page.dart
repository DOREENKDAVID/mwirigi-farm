// 💰 Financial Dashboard — CEO-level consolidated view.
//
// Mirrors the v4.2 HTML mockup exactly:
//   • Header (💰 icon + "CEO level · All units consolidated")
//   • 4 KPIs: Revenue MTD · Expenses MTD · Net Profit · Best Unit
//   • Pill nav (Overview / Revenue / Expenses / P&L / Cashflow /
//     Budgets / Payroll / Reports) — Overview is live; the others
//     render a "Coming soon" placeholder so the navigation structure
//     is in place even though only the Overview body has been wired
//   • Overview body: Revenue-by-unit donut chart (with legend) +
//     Unit P&L summary table
//
// Provider/StatefulWidget pattern matches the rest of the app.

import 'package:flutter/material.dart';

import '../dashboard/kpi_grid.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../core/models/finance.dart';
import '../../core/models/staff.dart';
import '../../core/service/api_service.dart';

enum FinanceTab {
  overview('Overview'),
  revenue('Revenue'),
  expenses('Expenses'),
  pnl('Profit & Loss'),
  cashflow('Cashflow'),
  budgets('Budgets'),
  payroll('Payroll'),
  reports('Reports');

  const FinanceTab(this.label);
  final String label;
}

class FinancePage extends StatefulWidget {
  const FinancePage({super.key});
  @override
  State<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends State<FinancePage> {
  static const _primary = Color(0xFF27500A);
  static const _txt2 = Color(0xFF6B7770);
  static const _txt3 = Color(0xFF99A39B);
  static const _danger = Color(0xFFC4393B);
  static const _gold = Color(0xFFA88404);

  late Future<FinanceDashboard> _future;
  FinanceTab _active = FinanceTab.overview;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<FinanceDashboard> _load() async {
    final raw = await ApiService.getFinanceDashboard();
    return FinanceDashboard.fromJson(raw);
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<FinanceDashboard>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return _ErrorView(
              message:
                  snap.error.toString().replaceFirst('Exception: ', ''),
              onRetry: _refresh,
            );
          }
          final data = snap.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 80),
            children: [
              _UnitHeader(period: data.period),
              const SizedBox(height: 16),
              _KpiRow(kpis: data.kpis),
              const SizedBox(height: 16),
              _PillTabs(
                active: _active,
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

  List<Widget> _tabBody(FinanceDashboard data) {
    switch (_active) {
      case FinanceTab.overview:
        return [
          LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth >= 880;
              final donut = _RevenueByUnitCard(slices: data.revenueByUnit);
              final pnl = _UnitPnlTable(rows: data.pnl);
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: donut),
                    const SizedBox(width: 16),
                    Expanded(child: pnl),
                  ],
                );
              }
              return Column(
                children: [donut, const SizedBox(height: 16), pnl],
              );
            },
          ),
        ];
      case FinanceTab.payroll:
        return [const _PayrollPanel()];
      default:
        return [_ComingSoonBlock(tab: _active)];
    }
  }
}

// ===================================================================
// Header
// ===================================================================

class _UnitHeader extends StatelessWidget {
  const _UnitHeader({required this.period});
  final FinancePeriod period;
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
          child: const Text('💰', style: TextStyle(fontSize: 20)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Financial Dashboard',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: _FinancePageState._primary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'CEO level · All units consolidated · ${period.label}',
                style: const TextStyle(
                  fontSize: 12,
                  color: _FinancePageState._txt2,
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
// KPI row
// ===================================================================

class _KpiRow extends StatelessWidget {
  const _KpiRow({required this.kpis});
  final FinanceKpis kpis;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.compactCurrency(
      locale: 'en_KE',
      symbol: 'KSh ',
      decimalDigits: 2,
    );
    final positive = kpis.netProfit >= 0;

    final tiles = [
      _KpiCard(
        label: 'Revenue MTD',
        value: fmt.format(kpis.revenue),
        sub: 'All units',
        color: _FinancePageState._primary,
      ),
      _KpiCard(
        label: 'Expenses MTD',
        value: fmt.format(kpis.expenses),
        sub: 'Feeds, labour, health',
        color: const Color(0xFF222222),
      ),
      _KpiCard(
        label: 'Net profit',
        value: fmt.format(kpis.netProfit),
        sub: '${kpis.marginPct.toStringAsFixed(0)}% margin',
        color: positive
            ? _FinancePageState._primary
            : _FinancePageState._danger,
      ),
      _KpiCard(
        label: 'Best unit',
        value: kpis.bestUnit?.unit ?? '—',
        sub: kpis.bestUnit != null
            ? '${kpis.bestUnit!.revenuePct.toStringAsFixed(0)}% of revenue'
            : '',
        color: _FinancePageState._gold,
      ),
    ];

    return KpiGrid(children: tiles);
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
  });
  final String label;
  final String value;
  final String sub;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAF7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x14000000)),
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
              color: _FinancePageState._txt2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            sub,
            style: const TextStyle(
              fontSize: 11,
              color: _FinancePageState._txt3,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ===================================================================
// Pill tabs
// ===================================================================

class _PillTabs extends StatelessWidget {
  const _PillTabs({required this.active, required this.onSelect});
  final FinanceTab active;
  final ValueChanged<FinanceTab> onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final t in FinanceTab.values) ...[
            _Pill(
              label: t.label,
              active: active == t,
              onTap: () => onSelect(t),
            ),
            if (t != FinanceTab.values.last) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final bg = active ? _FinancePageState._primary : Colors.white;
    final fg = active ? Colors.white : Colors.black87;
    final border =
        active ? _FinancePageState._primary : const Color(0x33000000);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: fg,
          ),
        ),
      ),
    );
  }
}

// ===================================================================
// Revenue by unit (donut)
// ===================================================================

class _RevenueByUnitCard extends StatelessWidget {
  const _RevenueByUnitCard({required this.slices});
  final List<RevenueSlice> slices;

  Color _hex(String hex) {
    final s = hex.replaceFirst('#', '');
    final v = int.tryParse(s, radix: 16) ?? 0x6B7770;
    return Color(0xFF000000 | v);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'REVENUE BY UNIT',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: _FinancePageState._txt2,
            ),
          ),
          const SizedBox(height: 10),
          if (slices.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(
                child: Text(
                  'No revenue recorded this month yet.',
                  style: TextStyle(
                    fontSize: 12,
                    color: _FinancePageState._txt3,
                  ),
                ),
              ),
            )
          else ...[
            // Legend (chips with %s) — wraps so it stays mobile-friendly.
            Wrap(
              spacing: 10,
              runSpacing: 6,
              children: [
                for (final s in slices)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _hex(s.color),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${s.unit} ${s.pct.toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontSize: 11,
                          color: _FinancePageState._txt2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 60,
                  startDegreeOffset: -90,
                  sections: [
                    for (final s in slices)
                      PieChartSectionData(
                        value: s.amount,
                        color: _hex(s.color),
                        title: '${s.pct.toStringAsFixed(0)}%',
                        radius: 50,
                        titleStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ===================================================================
// Unit P&L summary
// ===================================================================

class _UnitPnlTable extends StatelessWidget {
  const _UnitPnlTable({required this.rows});
  final List<UnitPnl> rows;

  String _fmtK(double v) {
    final abs = v.abs();
    if (abs >= 1000000) return '${(v / 1000000).toStringAsFixed(2)}M';
    if (abs >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'UNIT P&L SUMMARY',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: _FinancePageState._txt2,
            ),
          ),
          const SizedBox(height: 12),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(
                child: Text(
                  'No financial activity recorded this month yet.',
                  style: TextStyle(
                    fontSize: 12,
                    color: _FinancePageState._txt3,
                  ),
                ),
              ),
            )
          else
            Table(
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              columnWidths: const {
                0: FlexColumnWidth(1.4),
                1: FlexColumnWidth(1.0),
                2: FlexColumnWidth(1.0),
                3: FlexColumnWidth(1.2),
              },
              children: [
                const TableRow(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Color(0x14000000)),
                    ),
                  ),
                  children: [
                    _Th('Unit'),
                    _Th('Revenue', alignRight: true),
                    _Th('Expenses', alignRight: true),
                    _Th('Profit', alignRight: true),
                  ],
                ),
                for (final r in rows)
                  TableRow(
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Color(0x0F000000)),
                      ),
                    ),
                    children: [
                      _Td(r.unit, bold: true),
                      _Td(_fmtK(r.revenue), alignRight: true),
                      _Td(_fmtK(r.expenses), alignRight: true),
                      _ProfitTd(value: r.profit, formatter: _fmtK),
                    ],
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Th extends StatelessWidget {
  const _Th(this.label, {this.alignRight = false});
  final String label;
  final bool alignRight;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Align(
        alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: _FinancePageState._txt2,
            letterSpacing: 0.04,
          ),
        ),
      ),
    );
  }
}

class _Td extends StatelessWidget {
  const _Td(this.text, {this.bold = false, this.alignRight = false});
  final String text;
  final bool bold;
  final bool alignRight;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Align(
        alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            color: const Color(0xFF222222),
          ),
        ),
      ),
    );
  }
}

class _ProfitTd extends StatelessWidget {
  const _ProfitTd({required this.value, required this.formatter});
  final double value;
  final String Function(double) formatter;
  @override
  Widget build(BuildContext context) {
    final positive = value >= 0;
    final color = positive
        ? _FinancePageState._primary
        : _FinancePageState._danger;
    final prefix = positive ? '+' : '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(
          '$prefix${formatter(value)}',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ),
    );
  }
}

// ===================================================================
// Payroll pill — reads from the Staff module's single source of truth
// (GET /api/staff/dashboard). No payroll data is duplicated here; the
// Finance pill purely summarises what the Staff module already owns.
// ===================================================================

class _PayrollPanel extends StatefulWidget {
  const _PayrollPanel();

  @override
  State<_PayrollPanel> createState() => _PayrollPanelState();
}

class _PayrollPanelState extends State<_PayrollPanel> {
  late Future<StaffDashboard> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<StaffDashboard> _load() async {
    final raw = await ApiService.getStaffDashboard();
    return StaffDashboard.fromJson(raw);
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  void _onEditRequested() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Payroll lives in the Staff module. Open Staff → Payroll to '
          'add, approve, or process pay runs.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<StaffDashboard>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return _PayrollErrorView(
            message: snap.error.toString().replaceFirst('Exception: ', ''),
            onRetry: _refresh,
          );
        }
        final dash = snap.data!;
        final payroll = dash.payroll;
        if (payroll.rows.isEmpty) {
          return _PayrollEmptyView(
            onEdit: _onEditRequested,
            onRefresh: _refresh,
          );
        }
        return Column(
          children: [
            _PayrollSourceBanner(
              monthLabel: _monthLabel(payroll.month, payroll.year),
              onEdit: _onEditRequested,
              onRefresh: _refresh,
            ),
            const SizedBox(height: 12),
            _PayrollKpiGrid(dash: dash),
            const SizedBox(height: 14),
            _PayrollByDepartmentCard(rows: payroll.rows),
            const SizedBox(height: 14),
            _PayrollRosterCard(payroll: payroll),
          ],
        );
      },
    );
  }

  String _monthLabel(int month, int year) {
    if (month < 1 || month > 12) return '$year';
    final d = DateTime(year, month);
    return DateFormat('MMMM yyyy').format(d);
  }
}

// -------- Banner: tells the user where editing lives --------

class _PayrollSourceBanner extends StatelessWidget {
  const _PayrollSourceBanner({
    required this.monthLabel,
    required this.onEdit,
    required this.onRefresh,
  });
  final String monthLabel;
  final VoidCallback onEdit;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF3DE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x2227500A)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline,
              size: 18, color: _FinancePageState._primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Payroll · $monthLabel',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: _FinancePageState._primary,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Read-only view. Edits happen in Staff → Payroll.',
                  style: TextStyle(
                    fontSize: 11,
                    color: _FinancePageState._txt2,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh, size: 18),
            visualDensity: VisualDensity.compact,
          ),
          TextButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.open_in_new, size: 14),
            label: const Text('Manage'),
            style: TextButton.styleFrom(
              foregroundColor: _FinancePageState._primary,
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }
}

// -------- KPI grid --------

class _PayrollKpiGrid extends StatelessWidget {
  const _PayrollKpiGrid({required this.dash});
  final StaffDashboard dash;

  @override
  Widget build(BuildContext context) {
    final compact = NumberFormat.compactCurrency(
      locale: 'en_KE',
      symbol: 'KSh ',
      decimalDigits: 2,
    );
    final fmt = NumberFormat.decimalPattern();

    final payroll = dash.payroll;
    final rows = payroll.rows;

    final paidSum = rows
        .where((r) => r.status == PayrollStatus.paid)
        .fold<num>(0, (s, r) => s + r.netPay);
    final pendingSum = rows
        .where((r) => r.status == PayrollStatus.pending)
        .fold<num>(0, (s, r) => s + r.netPay);
    final pendingCount =
        rows.where((r) => r.status == PayrollStatus.pending).length;
    final paidCount =
        rows.where((r) => r.status == PayrollStatus.paid).length;

    // Overdue = still pending when the payroll period is already in the
    // past (month/year before current).
    final now = DateTime.now();
    final periodIsPast = payroll.year < now.year ||
        (payroll.year == now.year && payroll.month < now.month);
    final overdueSum = periodIsPast ? pendingSum : 0;
    final overdueCount = periodIsPast ? pendingCount : 0;

    final staffCount = rows.length;
    final avg = staffCount > 0 ? payroll.totalNet / staffCount : 0;

    final tiles = <Widget>[
      _KpiCard(
        label: 'Total payroll',
        value: compact.format(payroll.totalNet),
        sub: '$staffCount staff · gross ${compact.format(payroll.totalGross)}',
        color: _FinancePageState._primary,
      ),
      _KpiCard(
        label: 'Paid',
        value: compact.format(paidSum),
        sub: '$paidCount paid',
        color: _FinancePageState._primary,
      ),
      _KpiCard(
        label: 'Pending',
        value: compact.format(pendingSum),
        sub: pendingCount == 0 ? 'All cleared' : '$pendingCount pending',
        color: pendingCount == 0
            ? _FinancePageState._txt2
            : const Color(0xFF8A5A0A),
      ),
      _KpiCard(
        label: 'Overdue',
        value: overdueCount == 0 ? 'KSh 0' : compact.format(overdueSum),
        sub: overdueCount == 0
            ? 'On schedule'
            : '$overdueCount overdue — last month',
        color: overdueCount == 0
            ? _FinancePageState._txt2
            : _FinancePageState._danger,
      ),
      _KpiCard(
        label: 'Staff on payroll',
        value: fmt.format(staffCount),
        sub: '${dash.totalStaff} total · ${dash.presentToday} today',
        color: const Color(0xFF222222),
      ),
      _KpiCard(
        label: 'Avg payroll cost',
        value: compact.format(avg),
        sub: 'Per staff · net',
        color: _FinancePageState._gold,
      ),
    ];

    return KpiGrid(children: tiles);
  }
}

// -------- Payroll by department --------

class _PayrollByDepartmentCard extends StatelessWidget {
  const _PayrollByDepartmentCard({required this.rows});
  final List<PayrollRow> rows;

  @override
  Widget build(BuildContext context) {
    final compact = NumberFormat.compactCurrency(
      locale: 'en_KE',
      symbol: 'KSh ',
      decimalDigits: 2,
    );
    final groups = <String, _DeptAgg>{};
    for (final r in rows) {
      final key = r.unit.isEmpty ? 'Unassigned' : r.unit;
      final g = groups.putIfAbsent(key, () => _DeptAgg(key));
      g.staff += 1;
      g.net += r.netPay;
      if (r.status == PayrollStatus.paid) {
        g.paid += r.netPay;
      } else {
        g.pending += r.netPay;
      }
    }
    final entries = groups.values.toList()
      ..sort((a, b) => b.net.compareTo(a.net));
    final total = entries.fold<num>(0, (s, e) => s + e.net);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'PAYROLL BY DEPARTMENT',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: _FinancePageState._txt2,
            ),
          ),
          const SizedBox(height: 12),
          for (final e in entries) ...[
            _DeptBar(agg: e, total: total, fmt: compact),
            if (e != entries.last) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _DeptAgg {
  _DeptAgg(this.label);
  final String label;
  int staff = 0;
  num net = 0;
  num paid = 0;
  num pending = 0;
}

class _DeptBar extends StatelessWidget {
  const _DeptBar({
    required this.agg,
    required this.total,
    required this.fmt,
  });
  final _DeptAgg agg;
  final num total;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context) {
    final pct = total <= 0 ? 0.0 : (agg.net / total).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                agg.label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF222222),
                ),
              ),
            ),
            Text(
              fmt.format(agg.net),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: _FinancePageState._primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: pct.clamp(0, 1),
            minHeight: 6,
            backgroundColor: const Color(0xFFEDEDED),
            valueColor: const AlwaysStoppedAnimation<Color>(
              _FinancePageState._primary,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${agg.staff} staff · ${(pct * 100).toStringAsFixed(0)}% of payroll · '
          'paid ${fmt.format(agg.paid)}'
          '${agg.pending > 0 ? " · pending ${fmt.format(agg.pending)}" : ""}',
          style: const TextStyle(
            fontSize: 11,
            color: _FinancePageState._txt2,
          ),
        ),
      ],
    );
  }
}

// -------- Per-staff roster summary --------

class _PayrollRosterCard extends StatelessWidget {
  const _PayrollRosterCard({required this.payroll});
  final PayrollSummary payroll;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern();
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'STAFF PAYROLL — READ ONLY',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: _FinancePageState._txt2,
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 18,
              headingTextStyle: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: _FinancePageState._txt2,
              ),
              dataTextStyle:
                  const TextStyle(fontSize: 12, color: Colors.black87),
              columns: const [
                DataColumn(label: Text('EMPLOYEE')),
                DataColumn(label: Text('ROLE')),
                DataColumn(label: Text('DEPARTMENT')),
                DataColumn(label: Text('GROSS'), numeric: true),
                DataColumn(label: Text('ADJUSTMENTS'), numeric: true),
                DataColumn(label: Text('NET'), numeric: true),
                DataColumn(label: Text('STATUS')),
              ],
              rows: [
                for (final r in payroll.rows)
                  DataRow(cells: [
                    DataCell(Text(
                      r.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    )),
                    DataCell(Text(r.jobTitle ?? r.role)),
                    DataCell(Text(r.unit.isEmpty ? '—' : r.unit)),
                    DataCell(Text(fmt.format(r.grossPay.round()))),
                    DataCell(_AdjustmentsCell(row: r, fmt: fmt)),
                    DataCell(Text(
                      fmt.format(r.netPay.round()),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    )),
                    DataCell(_StatusPill(
                      status: r.status,
                      periodMonth: payroll.month,
                      periodYear: payroll.year,
                    )),
                  ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdjustmentsCell extends StatelessWidget {
  const _AdjustmentsCell({required this.row, required this.fmt});
  final PayrollRow row;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];
    if (row.bonuses > 0) parts.add('+${fmt.format(row.bonuses.round())} bon');
    if (row.overtime > 0) parts.add('+${fmt.format(row.overtime.round())} OT');
    if (row.advances > 0) parts.add('−${fmt.format(row.advances.round())} adv');
    if (row.penalties > 0) {
      parts.add('−${fmt.format(row.penalties.round())} pen');
    }
    return Text(
      parts.isEmpty ? '—' : parts.join(' · '),
      style: const TextStyle(fontSize: 11, color: Color(0xFF555555)),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.status,
    required this.periodMonth,
    required this.periodYear,
  });
  final PayrollStatus status;
  final int periodMonth;
  final int periodYear;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final periodIsPast = periodYear < now.year ||
        (periodYear == now.year && periodMonth < now.month);
    final (Color bg, Color fg, String label) = switch (status) {
      PayrollStatus.paid => (
          const Color(0xFFEAF3DE),
          _FinancePageState._primary,
          'Paid',
        ),
      PayrollStatus.pending when periodIsPast => (
          const Color(0xFFFCEBEB),
          _FinancePageState._danger,
          'Overdue',
        ),
      PayrollStatus.pending => (
          const Color(0xFFFCEDC8),
          const Color(0xFF8A5A0A),
          'Pending',
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: fg,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// -------- Empty + error states --------

class _PayrollEmptyView extends StatelessWidget {
  const _PayrollEmptyView({required this.onEdit, required this.onRefresh});
  final VoidCallback onEdit;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: Column(
        children: [
          const Icon(Icons.payments_outlined,
              size: 36, color: _FinancePageState._txt3),
          const SizedBox(height: 10),
          const Text(
            'No payroll rows this month',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: _FinancePageState._primary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Add staff and run payroll inside the Staff module to see '
            'totals here.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: _FinancePageState._txt2),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            children: [
              FilledButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('Open Staff → Payroll'),
                style: FilledButton.styleFrom(
                  backgroundColor: _FinancePageState._primary,
                ),
              ),
              OutlinedButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Refresh'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PayrollErrorView extends StatelessWidget {
  const _PayrollErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline,
              size: 36, color: _FinancePageState._danger),
          const SizedBox(height: 10),
          const Text(
            'Could not load payroll',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: _FinancePageState._primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: _FinancePageState._txt2,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Retry'),
            style: FilledButton.styleFrom(
              backgroundColor: _FinancePageState._primary,
            ),
          ),
        ],
      ),
    );
  }
}

// ===================================================================
// Coming soon placeholder for non-Overview pills
// ===================================================================

class _ComingSoonBlock extends StatelessWidget {
  const _ComingSoonBlock({required this.tab});
  final FinanceTab tab;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.construction_outlined,
            size: 36,
            color: _FinancePageState._txt3,
          ),
          const SizedBox(height: 10),
          Text(
            '${tab.label} — coming soon',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: _FinancePageState._primary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'The data model is ready in the backend. The pill body will '
            'land in a follow-up turn.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: _FinancePageState._txt2,
            ),
          ),
        ],
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
        const Icon(Icons.error_outline,
            size: 40, color: Color(0xFFE24B4A)),
        const SizedBox(height: 12),
        const Text(
          'Could not load financial dashboard',
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
