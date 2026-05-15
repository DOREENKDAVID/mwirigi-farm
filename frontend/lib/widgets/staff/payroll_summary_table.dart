import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/models/staff.dart';
import '../../core/service/api_service.dart';
import 'payslip_pdf.dart';

/// Payroll Summary card. Bottom-of-page table with monthly totals + action
/// buttons. Approve & Process Payroll calls /staff/payroll/process and
/// flips all rows to PAID. Each row exposes its salary advances as
/// coloured pills; tapping a row opens a bottom sheet to add / approve /
/// decline / remove advances. Net pay is recomputed by the backend
/// (`gross + bonuses + overtime − advances − penalties`).
class PayrollSummaryTable extends StatefulWidget {
  const PayrollSummaryTable({
    super.key,
    required this.payroll,
    required this.onChanged,
  });

  final PayrollSummary payroll;
  final VoidCallback onChanged;

  @override
  State<PayrollSummaryTable> createState() => _PayrollSummaryTableState();
}

class _PayrollSummaryTableState extends State<PayrollSummaryTable> {
  static const _primary = Color(0xFF27500A);
  static const _txt2 = Color(0xFF6B7770);

  bool _processing = false;

  Future<void> _approve() async {
    setState(() => _processing = true);
    try {
      await ApiService.processStaffPayroll();
      widget.onChanged();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payroll processed — all marked PAID')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _exportCsv() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('CSV export not yet implemented.')),
    );
  }

  Future<void> _openAdvanceSheet(PayrollRow row) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AdvanceSheet(
        row: row,
        month: widget.payroll.month,
        year: widget.payroll.year,
      ),
    );
    if (changed == true) widget.onChanged();
  }

  String _monthLabel() {
    final date = DateTime(widget.payroll.year, widget.payroll.month);
    return DateFormat('MMMM yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern();
    final rows = widget.payroll.rows;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0x14000000)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'PAYROLL SUMMARY — ${_monthLabel().toUpperCase()}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: _txt2,
                  ),
                ),
              ),
              Text(
                'Net total: KSh ${fmt.format(widget.payroll.totalNet.round())}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: _primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Text(
                  'No payroll rows for this month.',
                  style: TextStyle(fontSize: 12, color: _txt2),
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 18,
                headingTextStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: _txt2,
                ),
                dataTextStyle:
                    const TextStyle(fontSize: 13, color: Colors.black87),
                columns: const [
                  DataColumn(label: Text('NAME')),
                  DataColumn(label: Text('ROLE')),
                  DataColumn(label: Text('UNIT')),
                  DataColumn(label: Text('DAYS'), numeric: true),
                  DataColumn(label: Text('DAILY RATE'), numeric: true),
                  DataColumn(label: Text('GROSS (KSH)'), numeric: true),
                  DataColumn(label: Text('ADVANCE')),
                  DataColumn(label: Text('NET (KSH)'), numeric: true),
                  DataColumn(label: Text('STATUS')),
                  DataColumn(label: Text('')),
                ],
                rows: [
                  for (final r in rows)
                    DataRow(
                      onSelectChanged: (_) => _openAdvanceSheet(r),
                      cells: [
                        DataCell(Text(r.name)),
                        DataCell(Text(_roleLabel(r.role))),
                        DataCell(Text(r.unit)),
                        DataCell(Text('${r.daysWorked}')),
                        DataCell(Text(
                          r.salaryType == 'MONTHLY'
                              ? '—'
                              : (r.dailyRate == null
                                  ? '—'
                                  : fmt.format(r.dailyRate!.round())),
                        )),
                        DataCell(Text(
                          fmt.format(r.grossPay.round()),
                          style:
                              const TextStyle(fontWeight: FontWeight.w700),
                        )),
                        DataCell(_AdvancePillCell(
                          row: r,
                          onTap: () => _openAdvanceSheet(r),
                        )),
                        DataCell(Text(
                          fmt.format(r.netPay.round()),
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: r.netPay < r.grossPay
                                ? const Color(0xFF8A5A0A)
                                : _primary,
                          ),
                        )),
                        DataCell(_PayrollStatusPill(status: r.status)),
                        DataCell(IconButton(
                          icon: const Icon(Icons.print_outlined, size: 16),
                          tooltip: 'Print payslip',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => PayslipPdf.presentForRow(
                            row: r,
                            month: widget.payroll.month,
                            year: widget.payroll.year,
                          ),
                        )),
                      ],
                    ),
                ],
              ),
            ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton(
                onPressed: _processing ? null : _approve,
                style: FilledButton.styleFrom(backgroundColor: _primary),
                child: _processing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Approve & Process Payroll'),
              ),
              OutlinedButton.icon(
                onPressed: _exportCsv,
                icon: const Icon(Icons.download_outlined, size: 16),
                label: const Text('Export CSV'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF185FA5),
                  side: const BorderSide(color: Color(0xFF378ADD)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _roleLabel(String wire) {
    switch (wire) {
      case 'CEO':              return 'CEO';
      case 'ADMIN':            return 'Admin';
      case 'DAIRY_MANAGER':    return 'Dairy Manager';
      case 'LAYERS_MANAGER':   return 'Layers Manager';
      case 'PIGGERY_MANAGER':  return 'Piggery Manager';
      case 'FEEDLOT_MANAGER':  return 'Feedlot Manager';
      case 'FEEDS_MANAGER':    return 'Feeds Manager';
      case 'STORE_MANAGER':    return 'Store Manager';
      case 'VET':              return 'Vet';
      case 'WORKER':           return 'Worker';
      case 'ICT':              return 'ICT';
      default:                 return wire;
    }
  }
}

// =====================================================================
// Advance pill cell — collapsed view inside the table
// =====================================================================

class _AdvancePillCell extends StatelessWidget {
  const _AdvancePillCell({required this.row, required this.onTap});
  final PayrollRow row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final advances = row.advancePills;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: advances.isEmpty
            ? const _AddPlaceholderChip()
            : Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final a in advances) _AdvancePill(adjustment: a),
                  if (advances.length < 3) const _AddPlaceholderChip(),
                ],
              ),
      ),
    );
  }
}

class _AddPlaceholderChip extends StatelessWidget {
  const _AddPlaceholderChip();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F2),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x33000000)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add, size: 11, color: Color(0xFF6B7770)),
          SizedBox(width: 3),
          Text(
            'Advance',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6B7770),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdvancePill extends StatelessWidget {
  const _AdvancePill({required this.adjustment});
  final PayrollAdjustment adjustment;

  @override
  Widget build(BuildContext context) {
    final palette = _palette(adjustment.status);
    final amount =
        NumberFormat.decimalPattern().format(adjustment.amount.round());
    // Date label: prefer requestDate (the v2 explicit field) then
    // requestedAt (legacy timestamp). Drops to "—" when neither is set,
    // which only happens for rows seeded before the migration.
    final date = adjustment.requestDate ?? adjustment.requestedAt;
    final dateLabel =
        date == null ? null : DateFormat('d MMM').format(date);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: palette.bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: palette.border,
          width: palette.outlined ? 1 : 0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'KSh $amount',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: palette.fg,
            ),
          ),
          if (dateLabel != null) ...[
            const SizedBox(width: 4),
            Container(
              width: 3,
              height: 3,
              decoration: BoxDecoration(
                color: palette.fg.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              dateLabel,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: palette.fg,
                letterSpacing: 0.04,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static _PillPalette _palette(AdjustmentStatus s) {
    switch (s) {
      case AdjustmentStatus.pending:
        return const _PillPalette(
          bg: Color(0xFFEDEDED),
          fg: Color(0xFF555555),
          border: Color(0xFFAAAAAA),
        );
      case AdjustmentStatus.approved:
        return const _PillPalette(
          bg: Color(0xFFFCEDC8),
          fg: Color(0xFF8A5A0A),
          border: Color(0xFFD4912A),
        );
      case AdjustmentStatus.deducted:
        return const _PillPalette(
          bg: Color(0xFFEAF3DE),
          fg: Color(0xFF27500A),
          border: Color(0xFF27500A),
        );
      case AdjustmentStatus.declined:
        return const _PillPalette(
          bg: Colors.white,
          fg: Color(0xFFC4393B),
          border: Color(0xFFC4393B),
          outlined: true,
        );
    }
  }
}

class _PillPalette {
  const _PillPalette({
    required this.bg,
    required this.fg,
    required this.border,
    this.outlined = false,
  });
  final Color bg;
  final Color fg;
  final Color border;
  final bool outlined;
}

class _PayrollStatusPill extends StatelessWidget {
  const _PayrollStatusPill({required this.status});
  final PayrollStatus status;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = status == PayrollStatus.paid
        ? (const Color(0xFFEAF3DE), const Color(0xFF27500A))
        : (const Color(0xFFFAEEDA), const Color(0xFF854F0B));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

// =====================================================================
// Advance bottom sheet — view, add, approve, decline, delete
// =====================================================================

class _AdvanceSheet extends StatefulWidget {
  const _AdvanceSheet({
    required this.row,
    required this.month,
    required this.year,
  });
  final PayrollRow row;
  final int month;
  final int year;

  @override
  State<_AdvanceSheet> createState() => _AdvanceSheetState();
}

class _AdvanceSheetState extends State<_AdvanceSheet> {
  static const _primary = Color(0xFF27500A);
  static const _txt2 = Color(0xFF6B7770);
  static const _txt3 = Color(0xFF99A39B);

  late List<PayrollAdjustment> _adjustments;
  bool _changed = false;
  bool _busy = false;

  // Whether the inline add-advance form is expanded. The form widget
  // owns all of its own field state — we just need to know when to
  // render it.
  bool _showAdd = false;

  @override
  void initState() {
    super.initState();
    _adjustments = List.from(widget.row.advancePills);
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // Form-driven create. Returns true when the API call succeeded so the
  // form can reset its inputs. The form sends a fully-formed body — we
  // just stamp `userId` here, because the form doesn't know who it's
  // creating an advance for.
  Future<bool> _submitAdvance(Map<String, dynamic> body) async {
    setState(() => _busy = true);
    try {
      final created = await ApiService.createPayrollAdjustment({
        ...body,
        'userId': widget.row.userId,
      });
      final newAdj =
          PayrollAdjustment.fromJson(created.cast<String, dynamic>());
      setState(() {
        _adjustments = [..._adjustments, newAdj];
        _changed = true;
        _showAdd = false;
      });
      _toast('Advance ${newAdj.referenceNo ?? 'added'}');
      return true;
    } catch (e) {
      _toast('Failed: ${e.toString().replaceFirst('Exception: ', '')}');
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // Push state mutations to the next frame so the action button that
  // triggered them has time to release any hover overlay before the
  // widget tree rebuilds. Avoids the `mouse_tracker.dart:199` assertion
  // we hit on the reminders module for the same reason.
  void _applyNextFrame(VoidCallback fn) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      fn();
    });
  }

  Future<void> _setStatus(PayrollAdjustment a, AdjustmentStatus next) async {
    setState(() => _busy = true);
    try {
      final updated = await ApiService.updatePayrollAdjustment(
        a.id,
        {'status': next.wire},
      );
      final newAdj =
          PayrollAdjustment.fromJson(updated.cast<String, dynamic>());
      _applyNextFrame(() {
        setState(() {
          _adjustments = [
            for (final x in _adjustments) x.id == a.id ? newAdj : x,
          ];
          _changed = true;
        });
      });
      _toast('Marked ${next.label.toLowerCase()}');
    } catch (e) {
      _toast('Failed: $e');
    } finally {
      _applyNextFrame(() => setState(() => _busy = false));
    }
  }

  Future<void> _delete(PayrollAdjustment a) async {
    setState(() => _busy = true);
    try {
      await ApiService.deletePayrollAdjustment(a.id);
      _applyNextFrame(() {
        setState(() {
          _adjustments = _adjustments.where((x) => x.id != a.id).toList();
          _changed = true;
        });
      });
      _toast('Removed');
    } catch (e) {
      _toast('Failed: $e');
    } finally {
      _applyNextFrame(() => setState(() => _busy = false));
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern();
    final totalCounted = _adjustments
        .where((a) =>
            a.status == AdjustmentStatus.approved ||
            a.status == AdjustmentStatus.deducted)
        .fold<num>(0, (s, a) => s + a.amount);
    final netPreview =
        widget.row.grossPay - totalCounted + widget.row.bonuses + widget.row.overtime - widget.row.penalties;

    return DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (_, scrollCtl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0x33000000),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollCtl,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.row.name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: _primary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${widget.row.unit} · Salary advances',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: _txt2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: _busy
                              ? null
                              : () =>
                                  Navigator.of(context).pop(_changed),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _NetPreviewCard(
                      gross: widget.row.grossPay,
                      advances: totalCounted,
                      net: netPreview,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'ADVANCES',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: _txt2,
                            ),
                          ),
                        ),
                        if (!_showAdd)
                          TextButton.icon(
                            onPressed: _busy
                                ? null
                                : () => setState(() => _showAdd = true),
                            icon: const Icon(Icons.add, size: 14),
                            label: const Text('Add advance'),
                            style: TextButton.styleFrom(
                              foregroundColor: _primary,
                              backgroundColor: const Color(0xFFE7F0DD),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              textStyle: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_showAdd) ...[
                      _AddAdvanceForm(
                        month: widget.month,
                        year: widget.year,
                        onSubmit: _submitAdvance,
                        onCancel: _busy
                            ? null
                            : () => setState(() => _showAdd = false),
                        busy: _busy,
                      ),
                      const SizedBox(height: 14),
                    ],
                    if (_adjustments.isEmpty && !_showAdd)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 24, horizontal: 16),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF6F8F4),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'No advances on this payroll yet.',
                          style: TextStyle(fontSize: 12, color: _txt3),
                        ),
                      )
                    else
                      for (final a in _adjustments) ...[
                        _AdvanceRowCard(
                          // Stable identity so Flutter matches the same
                          // card across the list rebuild that follows
                          // approve / decline / delete — same fix that
                          // resolved the mouse-tracker assertion on the
                          // reminders module.
                          key: ValueKey('adj-${a.id}'),
                          adjustment: a,
                          onApprove: _busy
                              ? null
                              : () =>
                                  _setStatus(a, AdjustmentStatus.approved),
                          onDecline: _busy
                              ? null
                              : () =>
                                  _setStatus(a, AdjustmentStatus.declined),
                          onDelete: _busy ? null : () => _delete(a),
                          fmt: fmt,
                        ),
                        const SizedBox(height: 8),
                      ],
                  ],
                ),
              ),
            ],
          ),
        ),
    );
  }
}

class _NetPreviewCard extends StatelessWidget {
  const _NetPreviewCard({
    required this.gross,
    required this.advances,
    required this.net,
  });
  final num gross;
  final num advances;
  final num net;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8F4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _NetCol(
              label: 'Gross',
              value: 'KSh ${fmt.format(gross.round())}',
              color: const Color(0xFF222222),
            ),
          ),
          Expanded(
            child: _NetCol(
              label: 'Advance',
              value: '− ${fmt.format(advances.round())}',
              color: const Color(0xFF8A5A0A),
            ),
          ),
          Expanded(
            child: _NetCol(
              label: 'Net',
              value: 'KSh ${fmt.format(net.round())}',
              color: const Color(0xFF27500A),
              bold: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _NetCol extends StatelessWidget {
  const _NetCol({
    required this.label,
    required this.value,
    required this.color,
    this.bold = false,
  });
  final String label;
  final String value;
  final Color color;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            color: _AdvanceSheetState._txt2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: bold ? 16 : 14,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

// Add-advance form — collects every field needed to issue an advance:
// amount · reason · request date · approval date · disbursement date ·
// repayment month · payment method (Cash / M-Pesa / Bank Transfer) +
// transaction code (required when method is M-Pesa). The form owns
// all of its own state; the parent only receives a single onSubmit
// payload when the manager taps Save.
class _AddAdvanceForm extends StatefulWidget {
  const _AddAdvanceForm({
    required this.month,
    required this.year,
    required this.onSubmit,
    required this.onCancel,
    required this.busy,
  });

  final int month;
  final int year;
  final Future<bool> Function(Map<String, dynamic> body) onSubmit;
  final VoidCallback? onCancel;
  final bool busy;

  @override
  State<_AddAdvanceForm> createState() => _AddAdvanceFormState();
}

class _AddAdvanceFormState extends State<_AddAdvanceForm> {
  final _amountCtl = TextEditingController();
  final _reasonCtl = TextEditingController();
  final _txnCodeCtl = TextEditingController();

  DateTime _requestDate = DateTime.now();
  DateTime? _approvedDate;
  DateTime? _disbursedDate;
  AdvancePaymentMethod _paymentMethod = AdvancePaymentMethod.mpesa;
  late int _repaymentMonth;
  late int _repaymentYear;

  @override
  void initState() {
    super.initState();
    _repaymentMonth = widget.month;
    _repaymentYear = widget.year;
  }

  @override
  void dispose() {
    _amountCtl.dispose();
    _reasonCtl.dispose();
    _txnCodeCtl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({
    required DateTime initial,
    required ValueChanged<DateTime> onPicked,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(initial.year - 2),
      lastDate: DateTime(initial.year + 2),
    );
    if (picked != null) onPicked(picked);
  }

  Future<void> _pickRepaymentMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(_repaymentYear, _repaymentMonth),
      firstDate: DateTime(widget.year - 1),
      lastDate: DateTime(widget.year + 2),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null) {
      setState(() {
        _repaymentMonth = picked.month;
        _repaymentYear = picked.year;
      });
    }
  }

  Future<void> _save() async {
    final raw = _amountCtl.text.trim();
    final amount = double.tryParse(raw);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount')),
      );
      return;
    }
    if (_paymentMethod == AdvancePaymentMethod.mpesa &&
        _txnCodeCtl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('M-Pesa transaction code is required'),
        ),
      );
      return;
    }
    final body = <String, dynamic>{
      'type': 'ADVANCE',
      // Direct manager-side create — defaults to APPROVED so it shows
      // up on the payroll cycle immediately. Use the bottom-sheet
      // workflow buttons to flip to PENDING / DECLINED later.
      'status': 'APPROVED',
      'amount': amount,
      'month': widget.month,
      'year': widget.year,
      'requestDate': _requestDate.toIso8601String(),
      if (_approvedDate != null)
        'approvedDate': _approvedDate!.toIso8601String(),
      if (_disbursedDate != null)
        'disbursedDate': _disbursedDate!.toIso8601String(),
      'repaymentMonth': _repaymentMonth,
      'repaymentYear': _repaymentYear,
      'paymentMethod': _paymentMethod.wire,
      if (_paymentMethod == AdvancePaymentMethod.mpesa)
        'transactionCode': _txnCodeCtl.text.trim(),
      if (_reasonCtl.text.trim().isNotEmpty)
        'reason': _reasonCtl.text.trim(),
    };
    final ok = await widget.onSubmit(body);
    if (ok && mounted) {
      _amountCtl.clear();
      _reasonCtl.clear();
      _txnCodeCtl.clear();
      setState(() {
        _requestDate = DateTime.now();
        _approvedDate = null;
        _disbursedDate = null;
      });
    }
  }

  InputDecoration _decoration({
    required String label,
    String? hint,
    String? prefix,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixText: prefix,
      suffixIcon: suffixIcon,
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  Widget _dateField({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
  }) {
    final fmt = DateFormat('d MMM yyyy');
    return InkWell(
      onTap: widget.busy ? null : onTap,
      borderRadius: BorderRadius.circular(10),
      child: InputDecorator(
        decoration: _decoration(
          label: label,
          suffixIcon: const Padding(
            padding: EdgeInsets.only(right: 8),
            child: Icon(Icons.calendar_today_outlined, size: 16),
          ),
        ),
        child: Text(
          value == null ? '—' : fmt.format(value),
          style: TextStyle(
            fontSize: 13,
            color: value == null ? const Color(0xFF99A39B) : Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMpesa = _paymentMethod == AdvancePaymentMethod.mpesa;
    final monthLabel =
        DateFormat('MMM yyyy').format(DateTime(_repaymentYear, _repaymentMonth));

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFCEDC8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Row 1: amount + reason
          LayoutBuilder(builder: (context, c) {
            final wide = c.maxWidth >= 460;
            final amount = TextField(
              controller: _amountCtl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration:
                  _decoration(label: 'Amount (KSh)', prefix: 'KSh '),
            );
            final reason = TextField(
              controller: _reasonCtl,
              decoration: _decoration(
                label: 'Reason (optional)',
                hint: 'e.g. School fees · medical',
              ),
            );
            return wide
                ? Row(children: [
                    Expanded(child: amount),
                    const SizedBox(width: 10),
                    Expanded(flex: 2, child: reason),
                  ])
                : Column(children: [
                    amount,
                    const SizedBox(height: 10),
                    reason,
                  ]);
          }),
          const SizedBox(height: 10),

          // Row 2: dates (request / approved / disbursed)
          LayoutBuilder(builder: (context, c) {
            final wide = c.maxWidth >= 600;
            final f1 = _dateField(
              label: 'Request date',
              value: _requestDate,
              onTap: () => _pickDate(
                initial: _requestDate,
                onPicked: (d) => setState(() => _requestDate = d),
              ),
            );
            final f2 = _dateField(
              label: 'Approval date',
              value: _approvedDate,
              onTap: () => _pickDate(
                initial: _approvedDate ?? DateTime.now(),
                onPicked: (d) => setState(() => _approvedDate = d),
              ),
            );
            final f3 = _dateField(
              label: 'Disbursement',
              value: _disbursedDate,
              onTap: () => _pickDate(
                initial: _disbursedDate ?? DateTime.now(),
                onPicked: (d) => setState(() => _disbursedDate = d),
              ),
            );
            if (wide) {
              return Row(children: [
                Expanded(child: f1),
                const SizedBox(width: 10),
                Expanded(child: f2),
                const SizedBox(width: 10),
                Expanded(child: f3),
              ]);
            }
            return Column(children: [
              f1,
              const SizedBox(height: 10),
              f2,
              const SizedBox(height: 10),
              f3,
            ]);
          }),
          const SizedBox(height: 10),

          // Row 3: repayment month + payment method
          LayoutBuilder(builder: (context, c) {
            final wide = c.maxWidth >= 460;
            final repayment = InkWell(
              onTap: widget.busy ? null : _pickRepaymentMonth,
              borderRadius: BorderRadius.circular(10),
              child: InputDecorator(
                decoration: _decoration(
                  label: 'Repayment month',
                  suffixIcon: const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(Icons.event_repeat_outlined, size: 16),
                  ),
                ),
                child: Text(
                  monthLabel,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
            final method = DropdownButtonFormField<AdvancePaymentMethod>(
              initialValue: _paymentMethod,
              decoration: _decoration(label: 'Payment method'),
              items: [
                for (final m in AdvancePaymentMethod.values)
                  DropdownMenuItem(value: m, child: Text(m.label)),
              ],
              onChanged: widget.busy
                  ? null
                  : (v) => setState(
                      () => _paymentMethod = v ?? _paymentMethod),
            );
            return wide
                ? Row(children: [
                    Expanded(child: repayment),
                    const SizedBox(width: 10),
                    Expanded(child: method),
                  ])
                : Column(children: [
                    repayment,
                    const SizedBox(height: 10),
                    method,
                  ]);
          }),

          // Row 4: M-Pesa transaction code (shown only when method = MPESA)
          if (isMpesa) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _txnCodeCtl,
              textCapitalization: TextCapitalization.characters,
              decoration: _decoration(
                label: 'M-Pesa transaction code *',
                hint: 'e.g. QGH7XK9P12',
              ),
            ),
          ],

          const SizedBox(height: 14),
          Row(
            children: [
              FilledButton.icon(
                onPressed: widget.busy ? null : _save,
                icon: widget.busy
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check, size: 16),
                label: Text(widget.busy ? 'Saving…' : 'Save advance'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF8A5A0A),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: widget.onCancel,
                child: const Text('Cancel'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdvanceRowCard extends StatelessWidget {
  const _AdvanceRowCard({
    super.key,
    required this.adjustment,
    required this.onApprove,
    required this.onDecline,
    required this.onDelete,
    required this.fmt,
  });
  final PayrollAdjustment adjustment;
  final VoidCallback? onApprove;
  final VoidCallback? onDecline;
  final VoidCallback? onDelete;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context) {
    final s = adjustment.status;
    final locked = s == AdjustmentStatus.deducted;
    final dateFmt = DateFormat('d MMM yy');
    final monthFmt = DateFormat('MMM yyyy');
    final requestDate = adjustment.requestDate ?? adjustment.requestedAt;
    final approvedDate = adjustment.approvedDate ?? adjustment.approvedAt;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- Header: reference + amount + status badge ----
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (adjustment.referenceNo != null)
                      Text(
                        adjustment.referenceNo!,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _AdvanceSheetState._txt3,
                          letterSpacing: 0.05,
                        ),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      'KSh ${fmt.format(adjustment.amount.round())}',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF222222),
                      ),
                    ),
                  ],
                ),
              ),
              _StatusBadge(status: s),
            ],
          ),
          if (adjustment.reason != null && adjustment.reason!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              adjustment.reason!,
              style: const TextStyle(
                fontSize: 12,
                color: _AdvanceSheetState._txt2,
              ),
            ),
          ],

          // ---- Detail grid: dates + payment method + txn code ----
          const SizedBox(height: 10),
          _DetailGrid(items: [
            if (requestDate != null)
              _Detail('Requested', dateFmt.format(requestDate)),
            if (approvedDate != null)
              _Detail('Approved', dateFmt.format(approvedDate)),
            if (adjustment.disbursedDate != null)
              _Detail('Disbursed', dateFmt.format(adjustment.disbursedDate!)),
            if (adjustment.repaymentMonth != null &&
                adjustment.repaymentYear != null)
              _Detail(
                'Repay',
                monthFmt.format(
                  DateTime(
                    adjustment.repaymentYear!,
                    adjustment.repaymentMonth!,
                  ),
                ),
              ),
            if (adjustment.paymentMethod != null)
              _Detail('Method', adjustment.paymentMethod!.label),
            if (adjustment.transactionCode != null &&
                adjustment.transactionCode!.isNotEmpty)
              _Detail('Txn code', adjustment.transactionCode!),
          ]),
          if (!locked) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              children: [
                if (s == AdjustmentStatus.pending ||
                    s == AdjustmentStatus.declined)
                  FilledButton.icon(
                    onPressed: onApprove,
                    icon: const Icon(Icons.check, size: 14),
                    label: const Text('Approve'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF8A5A0A),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                if (s == AdjustmentStatus.pending ||
                    s == AdjustmentStatus.approved)
                  OutlinedButton.icon(
                    onPressed: onDecline,
                    icon: const Icon(Icons.close, size: 14),
                    label: const Text('Decline'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFC4393B),
                      side: const BorderSide(color: Color(0x55C4393B)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 14),
                  label: const Text('Remove'),
                  style: TextButton.styleFrom(
                    foregroundColor: _AdvanceSheetState._txt2,
                    textStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final AdjustmentStatus status;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    switch (status) {
      case AdjustmentStatus.pending:
        bg = const Color(0xFFEDEDED);
        fg = const Color(0xFF555555);
        break;
      case AdjustmentStatus.approved:
        bg = const Color(0xFFFCEDC8);
        fg = const Color(0xFF8A5A0A);
        break;
      case AdjustmentStatus.deducted:
        bg = const Color(0xFFEAF3DE);
        fg = const Color(0xFF27500A);
        break;
      case AdjustmentStatus.declined:
        bg = Colors.white;
        fg = const Color(0xFFC4393B);
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: status == AdjustmentStatus.declined
            ? Border.all(color: fg)
            : null,
      ),
      child: Text(
        status.label.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: fg,
          letterSpacing: 0.05,
        ),
      ),
    );
  }
}

// One key-value pair inside the advance row's detail grid.
class _Detail {
  const _Detail(this.label, this.value);
  final String label;
  final String value;
}

// 2-up grid of detail rows. Wraps to one column on narrow widths.
class _DetailGrid extends StatelessWidget {
  const _DetailGrid({required this.items});
  final List<_Detail> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 360;
        final cellWidth = wide ? (c.maxWidth - 12) / 2 : c.maxWidth;
        return Wrap(
          spacing: 12,
          runSpacing: 6,
          children: [
            for (final d in items)
              SizedBox(
                width: cellWidth,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    SizedBox(
                      width: 72,
                      child: Text(
                        d.label.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: _AdvanceSheetState._txt3,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        d.value,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF333333),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
