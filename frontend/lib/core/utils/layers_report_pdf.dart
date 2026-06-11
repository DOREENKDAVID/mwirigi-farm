// Layers Production Report PDF builder.
//
// Entry point: `previewLayersReportPdf`. Takes a LayersProductionReport
// and filter labels, renders an A4 PDF with the Mwirigi Farm logo, and
// opens the system print / share sheet via the `printing` plugin.
//
// Mirrors the style of `dairy_report_pdf.dart` — same green header,
// same body typography, same signature block.

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/layers_report.dart';

// ── Shared style tokens ───────────────────────────────────────────────

const _green     = PdfColor.fromInt(0xff27500a);
const _greenSoft = PdfColor.fromInt(0xffeaf3de);
const _amber     = PdfColor.fromInt(0xff854f0b);
const _amberSoft = PdfColor.fromInt(0xfffaeeda);
const _red       = PdfColor.fromInt(0xffc4393b);
const _ink       = PdfColor.fromInt(0xff1a1a1a);
const _txt2      = PdfColor.fromInt(0xff6b7770);
const _txt3      = PdfColor.fromInt(0xff99a39b);
const _border    = PdfColor.fromInt(0xffd9d9d9);

// ── Public entry point ────────────────────────────────────────────────

Future<void> previewLayersReportPdf({
  required LayersProductionReport report,
  required String periodLabel,
  String? houseLabel,
  String? generatedBy,
}) async {
  final logoBytes = await _loadLogo();
  final doc = pw.Document();
  doc.addPage(_buildPage(
    report: report,
    periodLabel: periodLabel,
    houseLabel: houseLabel,
    generatedBy: generatedBy,
    logoBytes: logoBytes,
  ));
  final bytes = await doc.save();
  await Printing.layoutPdf(
    name: 'Mwirigi-Layers-Production-Report',
    onLayout: (_) async => bytes,
  );
}

// ── Logo loader ───────────────────────────────────────────────────────

Future<Uint8List?> _loadLogo() async {
  try {
    final data = await rootBundle.load('assets/branding/logo.png');
    return data.buffer.asUint8List();
  } catch (_) {
    return null;
  }
}

// ── Page builder ──────────────────────────────────────────────────────

pw.Page _buildPage({
  required LayersProductionReport report,
  required String periodLabel,
  String? houseLabel,
  String? generatedBy,
  Uint8List? logoBytes,
}) {
  final r = report;

  // Daily rows — show up to 31 (one month) so a long range doesn't
  // overflow a single page; the on-screen chart already shows the full view.
  final daily = r.daily.length <= 31
      ? r.daily
      : r.daily.sublist(r.daily.length - 31);

  final filterChips = <List<String>>[
    ['Period', periodLabel],
    if (houseLabel != null) ['House', houseLabel],
  ];

  return pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(36, 40, 36, 36),
    footer: _footer,
    build: (context) => [
      _header(
        logoBytes: logoBytes,
        filterChips: filterChips,
        generatedBy: generatedBy,
      ),
      pw.SizedBox(height: 14),
      _kpiStrip([
        _Kpi(
          'Crates',
          _fmtCrates(r.totals.crates),
          sub: '${NumberFormat.decimalPattern().format(r.totals.eggs)} eggs',
        ),
        _Kpi(
          'Active birds',
          NumberFormat.decimalPattern().format(r.totals.activeBirds),
          sub: 'Latest closing stock',
        ),
        _Kpi(
          'Mortality',
          '${r.totals.dead}',
          sub: 'vs ${r.previousTotals.dead} last period',
        ),
        _Kpi(
          'Feed (kg)',
          r.totals.feedKg.toStringAsFixed(1),
          sub: 'vs ${r.previousTotals.feedKg.toStringAsFixed(1)} last period',
        ),
      ]),
      pw.SizedBox(height: 10),
      _deltaStrip(
        delta: r.delta.crates,
        previous: '${_fmtCrates(r.previousTotals.crates)} crates previous period',
      ),
      pw.SizedBox(height: 16),
      _sectionTitle('Daily crates'),
      pw.SizedBox(height: 6),
      if (daily.isEmpty)
        _empty('No records in this period.')
      else
        _dataTable(
          headers: const ['Date', 'Day', 'Crates', 'Eggs', 'Dead', 'Feed kg'],
          rows: [
            for (final p in daily)
              [
                p.date,
                p.dow,
                _fmtCrates(p.crates),
                '${p.eggs}',
                '${p.dead}',
                p.feedKg.toStringAsFixed(1),
              ],
          ],
        ),
      if (r.houses.length > 1) ...[
        pw.SizedBox(height: 16),
        _sectionTitle('Per-house breakdown'),
        pw.SizedBox(height: 6),
        _dataTable(
          headers: const ['House', 'Crates', 'Eggs', 'Dead'],
          rows: [
            for (final h in r.houses)
              [
                h.name,
                _fmtCrates(h.crates),
                '${h.eggs}',
                '${h.dead}',
              ],
          ],
        ),
      ],
      pw.SizedBox(height: 20),
      _signatureBlock(),
    ],
  );
}

// ── Shared widgets ────────────────────────────────────────────────────

pw.Widget _header({
  required Uint8List? logoBytes,
  required List<List<String>> filterChips,
  String? generatedBy,
}) {
  final fmtDate = DateFormat('d MMM yyyy · HH:mm');

  final logoOrText = logoBytes != null
      ? pw.Image(
          pw.MemoryImage(logoBytes),
          height: 42,
          fit: pw.BoxFit.contain,
        )
      : pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Mwirigi Farm',
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
                color: _green,
              ),
            ),
            pw.Text(
              'Manage · Grow · Prosper',
              style: const pw.TextStyle(fontSize: 9, color: _txt2),
            ),
          ],
        );

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          logoOrText,
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'Generated ${fmtDate.format(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 9, color: _txt2),
              ),
              if (generatedBy != null && generatedBy.isNotEmpty)
                pw.Text(
                  'by $generatedBy',
                  style: const pw.TextStyle(fontSize: 9, color: _txt2),
                ),
            ],
          ),
        ],
      ),
      pw.SizedBox(height: 12),
      pw.Container(width: double.infinity, height: 2, color: _green),
      pw.SizedBox(height: 10),
      pw.Text(
        'Layers Unit — Production Report',
        style: pw.TextStyle(
          fontSize: 16,
          fontWeight: pw.FontWeight.bold,
          color: _ink,
        ),
      ),
      pw.SizedBox(height: 6),
      pw.Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final chip in filterChips)
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: pw.BoxDecoration(
                color: _greenSoft,
                borderRadius:
                    const pw.BorderRadius.all(pw.Radius.circular(10)),
              ),
              child: pw.RichText(
                text: pw.TextSpan(
                  children: [
                    pw.TextSpan(
                      text: '${chip[0]}: ',
                      style: const pw.TextStyle(fontSize: 9, color: _txt2),
                    ),
                    pw.TextSpan(
                      text: chip[1],
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: _green,
                      ),
                    ),
                  ],
                ),
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
  return pw.Row(
    children: [
      for (var i = 0; i < cells.length; i++) ...[
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _border),
              borderRadius:
                  const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  cells[i].label.toUpperCase(),
                  style: const pw.TextStyle(fontSize: 8, color: _txt3),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  cells[i].value,
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: _green,
                  ),
                ),
                if (cells[i].sub != null) ...[
                  pw.SizedBox(height: 2),
                  pw.Text(
                    cells[i].sub!,
                    style: const pw.TextStyle(fontSize: 8, color: _txt2),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (i < cells.length - 1) pw.SizedBox(width: 6),
      ],
    ],
  );
}

pw.Widget _deltaStrip({required double? delta, required String previous}) {
  final color = delta == null
      ? _txt2
      : (delta >= 0 ? PdfColor.fromInt(0xff1d9e75) : _red);
  final text = delta == null
      ? '— vs previous'
      : '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)}% vs previous';
  return pw.Container(
    padding: const pw.EdgeInsets.all(8),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: _border),
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
    ),
    child: pw.Row(
      children: [
        pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
        ),
        pw.SizedBox(width: 12),
        pw.Text(
          previous,
          style: const pw.TextStyle(fontSize: 10, color: _txt2),
        ),
      ],
    ),
  );
}

pw.Widget _sectionTitle(String text) => pw.Text(
      text.toUpperCase(),
      style: pw.TextStyle(
        fontSize: 10,
        fontWeight: pw.FontWeight.bold,
        color: _txt2,
        letterSpacing: 0.5,
      ),
    );

pw.Widget _dataTable({
  required List<String> headers,
  required List<List<String>> rows,
}) {
  return pw.Table(
    border: pw.TableBorder.all(color: _border, width: 0.5),
    children: [
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _greenSoft),
        children: [
          for (final h in headers)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                  horizontal: 6, vertical: 5),
              child: pw.Text(
                h.toUpperCase(),
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: _green,
                  letterSpacing: 0.4,
                ),
              ),
            ),
        ],
      ),
      for (final row in rows)
        pw.TableRow(
          children: [
            for (final cell in row)
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 6, vertical: 5),
                child: pw.Text(
                  cell,
                  style: const pw.TextStyle(fontSize: 9, color: _ink),
                ),
              ),
          ],
        ),
    ],
  );
}

pw.Widget _empty(String text) => pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: pw.BoxDecoration(
        color: _amberSoft,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Text(
        text,
        style: const pw.TextStyle(fontSize: 10, color: _amber),
      ),
    );

pw.Widget _signatureBlock() {
  return pw.Container(
    padding: const pw.EdgeInsets.only(top: 18),
    child: pw.Row(
      children: [
        _signatureLine('Prepared by (Layers Manager)'),
        pw.SizedBox(width: 24),
        _signatureLine('Reviewed by (CEO)'),
      ],
    ),
  );
}

pw.Widget _signatureLine(String label) => pw.Expanded(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(
            height: 36,
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: _ink)),
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 9, color: _txt2),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Date: ____ / ____ / ______',
            style: const pw.TextStyle(fontSize: 8, color: _txt3),
          ),
        ],
      ),
    );

pw.Widget _footer(pw.Context context) => pw.Container(
      alignment: pw.Alignment.center,
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Text(
        'Mwirigi Farm Management System  ·  Page ${context.pageNumber}'
        ' of ${context.pagesCount}',
        style: const pw.TextStyle(fontSize: 8, color: _txt3),
      ),
    );

// ── Helpers ───────────────────────────────────────────────────────────

String _fmtCrates(double v) =>
    v == v.toInt() ? v.toInt().toString() : v.toStringAsFixed(1);
