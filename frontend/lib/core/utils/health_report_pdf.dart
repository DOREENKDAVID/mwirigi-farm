// Health Report PDF builder.
// Entry point: `buildHealthReportPdf` — takes filtered vaccination and
// treatment rows plus KPIs already computed by the page and returns A4 bytes.
// Mirrors dairy_report_pdf.dart styling (green header, signature block).

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/health.dart';

const _green     = PdfColor.fromInt(0xff27500a);
const _greenSoft = PdfColor.fromInt(0xffeaf3de);
const _amber     = PdfColor.fromInt(0xff854f0b);
const _amberSoft = PdfColor.fromInt(0xfffaeeda);
const _ink       = PdfColor.fromInt(0xff1a1a1a);
const _txt2      = PdfColor.fromInt(0xff6b7770);
const _txt3      = PdfColor.fromInt(0xff99a39b);
const _border    = PdfColor.fromInt(0xffd9d9d9);

class HealthReportInput {
  const HealthReportInput({
    required this.vaccinations,
    required this.treatments,
    required this.doneThisPeriod,
    required this.overdueCount,
    required this.due7dCount,
    required this.activeCases,
    required this.periodLabel,
    this.unitLabel,
    this.generatedBy,
  });

  final List<VaccinationRow> vaccinations;
  final List<TreatmentRow> treatments;
  final int doneThisPeriod;
  final int overdueCount;
  final int due7dCount;
  final int activeCases;
  final String periodLabel;
  final String? unitLabel;
  final String? generatedBy;
}

Future<List<int>> buildHealthReportPdf(HealthReportInput input) async {
  final logoBytes = await _loadLogo();
  final doc = pw.Document();
  doc.addPage(_buildPage(input, logoBytes));
  return doc.save();
}

Future<Uint8List?> _loadLogo() async {
  try {
    final data = await rootBundle.load('assets/branding/logo.png');
    return data.buffer.asUint8List();
  } catch (_) {
    return null;
  }
}

pw.MultiPage _buildPage(HealthReportInput r, Uint8List? logo) {
  final df = DateFormat('d MMM yy');
  return pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(36, 40, 36, 36),
    footer: _footer,
    build: (context) => [
      _header(r, logo),
      pw.SizedBox(height: 14),
      _kpiStrip([
        _Kpi('Done (period)', '${r.doneThisPeriod}', sub: 'vaccinations'),
        _Kpi('Overdue', '${r.overdueCount}', sub: 'action needed'),
        _Kpi('Due in 7d', '${r.due7dCount}', sub: 'upcoming'),
        _Kpi('Active cases', '${r.activeCases}', sub: 'under treatment'),
      ]),
      pw.SizedBox(height: 14),
      _sectionTitle('Vaccination schedule'),
      pw.SizedBox(height: 6),
      if (r.vaccinations.isEmpty)
        _empty('No vaccination records for this filter.')
      else
        _dataTable(
          headers: const ['Vaccine', 'Unit', 'Last done', 'Next due', 'Status'],
          rows: [
            for (final v in r.vaccinations.take(30))
              [
                v.vaccine,
                v.unit,
                v.lastDoneAt == null ? 'Never' : df.format(v.lastDoneAt!),
                v.nextDueAt == null ? '—' : df.format(v.nextDueAt!),
                _statusLabel(v),
              ],
          ],
        ),
      pw.SizedBox(height: 14),
      _sectionTitle('Treatments'),
      pw.SizedBox(height: 6),
      if (r.treatments.isEmpty)
        _empty('No treatment records for this period / unit.')
      else
        _dataTable(
          headers: const ['Tag', 'Unit', 'Diagnosis', 'Medication', 'Status', 'Started'],
          rows: [
            for (final t in r.treatments.take(30))
              [
                t.tag,
                t.unit,
                t.diagnosis,
                t.medication,
                t.statusLabel,
                df.format(t.startDate),
              ],
          ],
        ),
      pw.SizedBox(height: 18),
      _signatureBlock(),
    ],
  );
}

String _statusLabel(VaccinationRow v) {
  switch (v.status) {
    case 'OVERDUE':
      return '${(v.daysUntilDue ?? 0).abs()}d overdue';
    case 'DUE_NOW':
    case 'DUE_WINDOW_OPEN':
      return 'Due now';
    case 'DUE_SOON':
      return 'in ${v.daysUntilDue}d';
    default:
      return v.status;
  }
}

pw.Widget _header(HealthReportInput r, Uint8List? logo) {
  final fmtDate = DateFormat('d MMM yyyy · HH:mm');
  final chips = <List<String>>[
    ['Period', r.periodLabel],
    if (r.unitLabel != null) ['Unit', r.unitLabel!],
  ];
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(children: [
            if (logo != null) ...[
              pw.Image(pw.MemoryImage(logo), width: 36, height: 36),
              pw.SizedBox(width: 10),
            ],
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('Mwirigi Farm',
                  style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: _green)),
              pw.Text('Manage · Grow · Prosper',
                  style: const pw.TextStyle(fontSize: 10, color: _txt2)),
            ]),
          ]),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text('Generated ${fmtDate.format(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 9, color: _txt2)),
            if (r.generatedBy != null)
              pw.Text('by ${r.generatedBy!}',
                  style: const pw.TextStyle(fontSize: 9, color: _txt2)),
          ]),
        ],
      ),
      pw.SizedBox(height: 14),
      pw.Container(width: double.infinity, height: 2, color: _green),
      pw.SizedBox(height: 12),
      pw.Text('Health Report',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: _ink)),
      pw.SizedBox(height: 6),
      pw.Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final c in chips)
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: pw.BoxDecoration(
                color: _greenSoft,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
              ),
              child: pw.RichText(
                text: pw.TextSpan(children: [
                  pw.TextSpan(text: '${c[0]}: ',
                      style: const pw.TextStyle(fontSize: 9, color: _txt2)),
                  pw.TextSpan(text: c[1],
                      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _green)),
                ]),
              ),
            ),
        ],
      ),
    ],
  );
}

class _Kpi {
  const _Kpi(this.label, this.value, {this.sub});
  final String label;
  final String value;
  final String? sub;
}

pw.Widget _kpiStrip(List<_Kpi> cells) {
  return pw.Row(children: [
    for (var i = 0; i < cells.length; i++) ...[
      pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _border),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          ),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(cells[i].label.toUpperCase(),
                style: const pw.TextStyle(fontSize: 8, color: _txt3)),
            pw.SizedBox(height: 4),
            pw.Text(cells[i].value,
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: _green)),
            if (cells[i].sub != null)
              pw.Text(cells[i].sub!, style: const pw.TextStyle(fontSize: 8, color: _txt2)),
          ]),
        ),
      ),
      if (i < cells.length - 1) pw.SizedBox(width: 6),
    ],
  ]);
}

pw.Widget _sectionTitle(String text) => pw.Text(
      text.toUpperCase(),
      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _txt2, letterSpacing: 0.5),
    );

pw.Widget _dataTable({required List<String> headers, required List<List<String>> rows}) {
  return pw.Table(
    border: pw.TableBorder.all(color: _border, width: 0.5),
    children: [
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _greenSoft),
        children: [
          for (final h in headers)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              child: pw.Text(h.toUpperCase(),
                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _green, letterSpacing: 0.4)),
            ),
        ],
      ),
      for (final row in rows)
        pw.TableRow(children: [
          for (final cell in row)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              child: pw.Text(cell, style: const pw.TextStyle(fontSize: 9, color: _ink)),
            ),
        ]),
    ],
  );
}

pw.Widget _empty(String text) => pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: pw.BoxDecoration(
        color: _amberSoft,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 10, color: _amber)),
    );

pw.Widget _signatureBlock() => pw.Container(
      padding: const pw.EdgeInsets.only(top: 18),
      child: pw.Row(children: [
        _signatureLine('Prepared by (Manager)'),
        pw.SizedBox(width: 24),
        _signatureLine('Reviewed by (Vet)'),
      ]),
    );

pw.Widget _signatureLine(String label) => pw.Expanded(
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
        pw.Container(
          height: 36,
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: _ink)),
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: _txt2)),
        pw.SizedBox(height: 6),
        pw.Text('Date: ____ / ____ / ______',
            style: const pw.TextStyle(fontSize: 8, color: _txt3)),
      ]),
    );

pw.Widget _footer(pw.Context context) => pw.Container(
      alignment: pw.Alignment.center,
      margin: const pw.EdgeInsets.only(top: 12),
      child: pw.Text(
        'Mwirigi Farm Management System  ·  Page ${context.pageNumber} of ${context.pagesCount}',
        style: const pw.TextStyle(fontSize: 8, color: _txt3),
      ),
    );
