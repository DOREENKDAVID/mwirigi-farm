// Payslip PDF renderer. One A4 page per employee, generated client-side
// from a `PayrollRow` + the period (month, year). Hands the resulting
// bytes to the `printing` package's system print/share dialog so the
// user can preview, save, or print directly.
//
// Layout:
//   • Farm letterhead + payslip title
//   • Employee details + payroll month
//   • Attendance summary
//   • Gross / overtime / bonus / advance pills / penalties
//   • Net pay (highlighted)
//   • Signature blocks (Prepared / Approved / Received)
//   • Footer: "This is a computer-generated payslip."
//
// Uses Noto Sans + Noto Emoji fonts for Unicode support (em-dash, KSh
// symbol, status emoji) — same approach as the Reports module.

import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/models/staff.dart';

class PayslipPdf {
  static Future<Uint8List> build({
    required PayrollRow row,
    required int month,
    required int year,
  }) async {
    final base = await PdfGoogleFonts.notoSansRegular();
    final bold = await PdfGoogleFonts.notoSansBold();
    final emoji = await PdfGoogleFonts.notoEmojiRegular();

    final doc = pw.Document(
      theme: pw.ThemeData.withFont(
        base: base,
        bold: bold,
        fontFallback: [emoji],
      ),
    );

    final fmt = NumberFormat.decimalPattern();
    final monthLabel =
        DateFormat('MMMM yyyy').format(DateTime(year, month));
    final reportId =
        'PSL-$year${month.toString().padLeft(2, '0')}-${_shortId(row.userId)}';
    final generated = DateFormat('d MMM yyyy · HH:mm').format(DateTime.now());

    final advances =
        row.adjustments.where((a) => a.type == AdjustmentType.advance).toList();
    final approvedAdvances = advances
        .where((a) =>
            a.status == AdjustmentStatus.approved ||
            a.status == AdjustmentStatus.deducted)
        .toList();
    final totalAdvanceDeducted =
        approvedAdvances.fold<num>(0, (s, a) => s + a.amount);

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 36),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _letterhead(reportId: reportId, generated: generated),
            pw.SizedBox(height: 14),
            _titleBlock(monthLabel: monthLabel),
            pw.SizedBox(height: 14),
            _employeeBlock(row: row),
            pw.SizedBox(height: 12),
            _attendanceBlock(row: row),
            pw.SizedBox(height: 12),
            _earningsBlock(
              row: row,
              fmt: fmt,
              totalAdvances: totalAdvanceDeducted,
            ),
            if (advances.isNotEmpty) ...[
              pw.SizedBox(height: 12),
              _advancesBlock(advances: advances, fmt: fmt),
            ],
            pw.SizedBox(height: 14),
            _netPayBlock(row: row, fmt: fmt),
            pw.Spacer(),
            _signatureBlock(),
            pw.SizedBox(height: 10),
            _footer(),
          ],
        ),
      ),
    );

    return doc.save();
  }

  /// Open the system print/share dialog with the generated payslip.
  static Future<void> presentForRow({
    required PayrollRow row,
    required int month,
    required int year,
  }) async {
    final bytes = await build(row: row, month: month, year: year);
    final monthLabel = DateFormat('MMMM yyyy').format(DateTime(year, month));
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: 'Payslip · ${row.name} · $monthLabel',
    );
  }

  // ----- letterhead -----
  static pw.Widget _letterhead({
    required String reportId,
    required String generated,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.green800, width: 1.5),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Container(
                width: 42,
                height: 42,
                alignment: pw.Alignment.center,
                decoration: pw.BoxDecoration(
                  color: PdfColors.green50,
                  border: pw.Border.all(color: PdfColors.green200),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Text('🌿', style: const pw.TextStyle(fontSize: 22)),
              ),
              pw.SizedBox(width: 10),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'MWIRIGI FARM',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.green800,
                    ),
                  ),
                  pw.Text(
                    'Integrated Agricultural Operations · Mt Kenya Region',
                    style: pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey600,
                      fontStyle: pw.FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'Payslip ID: $reportId',
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey700,
                ),
              ),
              pw.Text(
                'Generated: $generated',
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _titleBlock({required String monthLabel}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border(
          left: pw.BorderSide(color: PdfColors.green800, width: 3),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'EMPLOYEE PAYSLIP',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.green800,
            ),
          ),
          pw.Text(
            'Pay period: $monthLabel',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey800,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _employeeBlock({required PayrollRow row}) {
    return _section(
      title: 'EMPLOYEE',
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _kv('Name', row.name),
          _kv('Role', _roleLabel(row.role)),
          _kv('Unit', row.unit),
          _kv('Salary type',
              row.salaryType == 'MONTHLY' ? 'Monthly' : 'Daily'),
          if (row.salaryType != 'MONTHLY' && row.dailyRate != null)
            _kv('Daily rate', 'KSh ${row.dailyRate!.round()}'),
        ],
      ),
    );
  }

  static pw.Widget _attendanceBlock({required PayrollRow row}) {
    final estimatedDays = 22;
    final pct = (row.daysWorked / estimatedDays * 100).clamp(0, 100);
    return _section(
      title: 'ATTENDANCE',
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _kv('Days worked', '${row.daysWorked} / $estimatedDays'),
          _kv('Attendance %', '${pct.toStringAsFixed(0)}%'),
        ],
      ),
    );
  }

  static pw.Widget _earningsBlock({
    required PayrollRow row,
    required NumberFormat fmt,
    required num totalAdvances,
  }) {
    return _section(
      title: 'EARNINGS & DEDUCTIONS',
      child: pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
        columnWidths: const {
          0: pw.FlexColumnWidth(3),
          1: pw.FlexColumnWidth(2),
        },
        children: [
          _earningsRow('Gross pay', 'KSh ${fmt.format(row.grossPay.round())}'),
          if (row.overtime > 0)
            _earningsRow('Overtime',
                '+ KSh ${fmt.format(row.overtime.round())}'),
          if (row.bonuses > 0)
            _earningsRow('Bonuses', '+ KSh ${fmt.format(row.bonuses.round())}'),
          if (totalAdvances > 0)
            _earningsRow('Advance deductions',
                '− KSh ${fmt.format(totalAdvances.round())}',
                deduction: true),
          if (row.penalties > 0)
            _earningsRow('Penalties',
                '− KSh ${fmt.format(row.penalties.round())}',
                deduction: true),
        ],
      ),
    );
  }

  static pw.Widget _advancesBlock({
    required List<PayrollAdjustment> advances,
    required NumberFormat fmt,
  }) {
    final dateFmt = DateFormat('d MMM');
    return _section(
      title: 'SALARY ADVANCES — DETAIL',
      child: pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
        columnWidths: const {
          0: pw.FlexColumnWidth(2.5),
          1: pw.FlexColumnWidth(1.5),
          2: pw.FlexColumnWidth(1.5),
          3: pw.FlexColumnWidth(2),
          4: pw.FlexColumnWidth(1.5),
        },
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey200),
            children: [
              _th('Reference'),
              _th('Amount'),
              _th('Method'),
              _th('Txn / Reason'),
              _th('Status'),
            ],
          ),
          for (final a in advances)
            pw.TableRow(children: [
              _td(a.referenceNo ?? '—'),
              _td('KSh ${fmt.format(a.amount.round())}'),
              _td(a.paymentMethod?.label ?? '—'),
              _td([
                if (a.transactionCode != null && a.transactionCode!.isNotEmpty)
                  a.transactionCode!,
                if (a.reason != null && a.reason!.isNotEmpty) a.reason!,
                if ((a.requestDate ?? a.requestedAt) != null)
                  dateFmt.format(a.requestDate ?? a.requestedAt!),
              ].join(' · ')),
              _td(a.status.label),
            ]),
        ],
      ),
    );
  }

  static pw.Widget _netPayBlock({
    required PayrollRow row,
    required NumberFormat fmt,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: PdfColors.green50,
        border: pw.Border.all(color: PdfColors.green800, width: 1),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'NET PAY',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.green800,
            ),
          ),
          pw.Text(
            'KSh ${fmt.format(row.netPay.round())}',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.green800,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _signatureBlock() {
    pw.Widget cell(String role) {
      return pw.Container(
        width: 160,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              height: 26,
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.black, width: 0.6),
                ),
              ),
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              role,
              style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey800,
              ),
            ),
            pw.Text(
              'Date: ____ / ____ / ______',
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
            ),
          ],
        ),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'SIGNATURES',
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.green800,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            cell('Prepared by (HR)'),
            cell('Approved by (CEO)'),
            cell('Received by (Employee)'),
          ],
        ),
      ],
    );
  }

  static pw.Widget _footer() {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
        ),
      ),
      child: pw.Text(
        'This is a computer-generated payslip. Mwirigi Farm Management v4.2 — confidential.',
        style: pw.TextStyle(
          fontSize: 8,
          color: PdfColors.grey600,
          fontStyle: pw.FontStyle.italic,
        ),
      ),
    );
  }

  // ----- shared helpers -----

  static pw.Widget _section({
    required String title,
    required pw.Widget child,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.green800,
            letterSpacing: 0.5,
          ),
        ),
        pw.SizedBox(height: 6),
        child,
      ],
    );
  }

  static pw.Widget _kv(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 100,
            child: pw.Text(
              label,
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.TableRow _earningsRow(
    String label,
    String value, {
    bool deduction = false,
  }) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey900),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: pw.Text(
            value,
            textAlign: pw.TextAlign.right,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: deduction ? PdfColors.red700 : PdfColors.grey900,
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _th(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.grey800,
        ),
      ),
    );
  }

  static pw.Widget _td(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        text,
        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey900),
      ),
    );
  }

  static String _roleLabel(String wire) {
    switch (wire) {
      case 'CEO': return 'CEO';
      case 'ADMIN': return 'Admin';
      case 'DAIRY_MANAGER': return 'Dairy Manager';
      case 'LAYERS_MANAGER': return 'Layers Manager';
      case 'PIGGERY_MANAGER': return 'Piggery Manager';
      case 'FEEDLOT_MANAGER': return 'Feedlot Manager';
      case 'FEEDS_MANAGER': return 'Feeds Manager';
      case 'STORE_MANAGER': return 'Store Manager';
      case 'VET': return 'Vet';
      case 'WORKER': return 'Worker';
      case 'ICT': return 'ICT';
      default: return wire;
    }
  }

  static String _shortId(String userId) {
    final clean = userId.replaceAll('-', '');
    return clean.substring(0, clean.length < 6 ? clean.length : 6).toUpperCase();
  }
}
