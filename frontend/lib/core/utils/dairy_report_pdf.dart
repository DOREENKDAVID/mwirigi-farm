// =====================================================================
// Dairy Report PDF builder
// =====================================================================
//
// One entry point per report type — `previewDairyMilkReportPdf`,
// `previewDairyReproductionReportPdf`, etc. — each takes the same
// DTO shape used by the dashboard cards and turns it into an A4 PDF
// that respects the active filters (period · animal · house · worker).
//
// Charts are deliberately rendered as compact tables of values
// instead of static images. The dashboard already shows the
// graphical view; the PDF is the file-the-vet-prints-and-signs and
// reads better with tabular data underneath the KPIs.
//
// Mirrors the styling of `sale_receipt_pdf.dart` so the two PDFs feel
// like they came from the same farm: same green header, same body
// typography, same signature block.

import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/dairy_report.dart';

// --- Shared style tokens ---------------------------------------------

const _green     = PdfColor.fromInt(0xff27500a);
const _greenSoft = PdfColor.fromInt(0xffeaf3de);
const _amber     = PdfColor.fromInt(0xff854f0b);
const _amberSoft = PdfColor.fromInt(0xffFAEEDA);
const _red       = PdfColor.fromInt(0xffc4393b);
const _ink       = PdfColor.fromInt(0xff1a1a1a);
const _txt2      = PdfColor.fromInt(0xff6b7770);
const _txt3      = PdfColor.fromInt(0xff99a39b);
const _border    = PdfColor.fromInt(0xffd9d9d9);

/// Filters that drive a report. Stays a thin record so the dashboard
/// can hand its current pill selections straight through.
class DairyReportFilterLabels {
  const DairyReportFilterLabels({
    required this.periodLabel,
    this.house,
    this.worker,
    this.animal,
  });

  /// Already-resolved labels (e.g. "House A", "Sam", "MW-001 · Topten").
  /// `null` means the filter wasn't applied. The PDF skips empty rows
  /// so it doesn't show "House: null".
  final String periodLabel;
  final String? house;
  final String? worker;
  final String? animal;
}

// --- Public entry points ---------------------------------------------

Future<Uint8List> buildDairyMilkReportPdf({
  required MilkProductionReport report,
  required DairyReportFilterLabels filters,
  String? generatedBy,
}) async {
  final doc = pw.Document();
  doc.addPage(_milkPage(report, filters, generatedBy));
  return doc.save();
}

Future<Uint8List> buildDairyReproductionReportPdf({
  required ReproductionReport report,
  required DairyReportFilterLabels filters,
  String? generatedBy,
}) async {
  final doc = pw.Document();
  doc.addPage(_reproductionPage(report, filters, generatedBy));
  return doc.save();
}

Future<Uint8List> buildDairyHealthReportPdf({
  required HealthReport report,
  required DairyReportFilterLabels filters,
  String? generatedBy,
}) async {
  final doc = pw.Document();
  doc.addPage(_healthPage(report, filters, generatedBy));
  return doc.save();
}

Future<Uint8List> buildDairyVaccinationReportPdf({
  required VaccinationReport report,
  required DairyReportFilterLabels filters,
  String? generatedBy,
}) async {
  final doc = pw.Document();
  doc.addPage(_vaccinationPage(report, filters, generatedBy));
  return doc.save();
}

// --- Page builders, one per report type ------------------------------

pw.Page _milkPage(
  MilkProductionReport r,
  DairyReportFilterLabels f,
  String? generatedBy,
) {
  final daily = r.daily;
  // Show the last 14 entries at most so a long-period report doesn't
  // blow past one page. The dashboard already has the full chart.
  final shown = daily.length <= 14 ? daily : daily.sublist(daily.length - 14);

  return pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(36, 40, 36, 36),
    footer: _footer,
    build: (context) => [
      _header('Dairy Report — Milk Production', f, generatedBy),
      pw.SizedBox(height: 14),
      _kpiStrip([
        _Kpi('Total litres', r.totals.litres.toStringAsFixed(1),
            sub: '${r.totals.activeCows} active cows'),
        _Kpi('Avg / cow', r.totals.avgPerCow.toStringAsFixed(1), sub: 'L'),
        _Kpi('Best cow', r.best?.tag ?? '—',
            sub: r.best == null
                ? '—'
                : '${r.best!.litres.toStringAsFixed(1)} L'),
        _Kpi('Lowest cow', r.lowest?.tag ?? '—',
            sub: r.lowest == null
                ? '—'
                : '${r.lowest!.litres.toStringAsFixed(1)} L'),
      ]),
      pw.SizedBox(height: 10),
      _deltaStrip(
        delta: r.totals.deltaPct,
        previous:
            '${r.totals.prevLitres.toStringAsFixed(1)} L previous period',
      ),
      pw.SizedBox(height: 14),
      _sectionTitle('Session breakdown'),
      pw.SizedBox(height: 6),
      _twoColTable(rows: [
        ['Dawn', '${r.totals.sessions.dawn.toStringAsFixed(1)} L'],
        ['AM', '${r.totals.sessions.am.toStringAsFixed(1)} L'],
        ['Mid', '${r.totals.sessions.mid.toStringAsFixed(1)} L'],
        ['PM', '${r.totals.sessions.pm.toStringAsFixed(1)} L'],
      ]),
      pw.SizedBox(height: 14),
      _sectionTitle('Daily trend'),
      pw.SizedBox(height: 6),
      _dataTable(
        headers: const ['Date', 'Day', 'Litres'],
        rows: [
          for (final p in shown) [p.date, p.dow, p.litres.toStringAsFixed(1)],
        ],
      ),
      pw.SizedBox(height: 18),
      _signatureBlock(),
    ],
  );
}

pw.Page _reproductionPage(
  ReproductionReport r,
  DairyReportFilterLabels f,
  String? generatedBy,
) {
  final df = DateFormat('d MMM yy');
  return pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(36, 40, 36, 36),
    footer: _footer,
    build: (context) => [
      _header('Dairy Report — Reproduction', f, generatedBy),
      pw.SizedBox(height: 14),
      _kpiStrip([
        _Kpi('AI done', '${r.totals.aiCount}',
            sub: 'in this period'),
        _Kpi('Pregnancies', '${r.totals.pregnanciesConfirmed}',
            sub: '${r.totals.pendingChecks} pending'),
        _Kpi('Calvings', '${r.totals.calvings}',
            sub: '${r.totals.expectedCalvings} expected ahead'),
        _Kpi(
          'Preg. rate',
          r.pregnancyRate == null
              ? '—'
              : '${r.pregnancyRate!.toStringAsFixed(1)}%',
          sub: r.conceptionRate == null
              ? 'of decided checks'
              : 'conception ${r.conceptionRate!.toStringAsFixed(1)}%',
        ),
      ]),
      pw.SizedBox(height: 10),
      _deltaStrip(
        delta: r.totals.deltaPct,
        previous: '${r.totals.prevAiCount} AI previous period',
      ),
      pw.SizedBox(height: 14),
      _sectionTitle('Upcoming calvings'),
      pw.SizedBox(height: 6),
      if (r.upcomingCalvings.isEmpty)
        _empty('No expected calvings on file.')
      else
        _dataTable(
          headers: const ['Tag', 'Name', 'Sire', 'Expected', 'Days out'],
          rows: [
            for (final u in r.upcomingCalvings)
              [
                u.tag ?? '—',
                u.nickname ?? '—',
                u.sireCode ?? '—',
                u.expectedCalvingDate == null
                    ? '—'
                    : df.format(u.expectedCalvingDate!),
                u.daysOut == null
                    ? '—'
                    : (u.daysOut! >= 0
                        ? 'in ${u.daysOut}d'
                        : '${-u.daysOut!}d late'),
              ],
          ],
        ),
      pw.SizedBox(height: 14),
      _sectionTitle('Recent reproduction events'),
      pw.SizedBox(height: 6),
      if (r.recentEvents.isEmpty)
        _empty('No reproduction events in this period.')
      else
        _dataTable(
          headers: const ['Date', 'Type', 'Cow', 'Sire', 'Status'],
          rows: [
            for (final e in r.recentEvents.take(20))
              [
                df.format(e.eventDate),
                e.eventType,
                [
                  e.cowTag ?? '—',
                  if (e.cowNickname != null && e.cowNickname!.isNotEmpty)
                    e.cowNickname!,
                ].join(' · '),
                e.sireCode ?? '—',
                e.pregnancyStatus ?? '—',
              ],
          ],
        ),
      pw.SizedBox(height: 18),
      _signatureBlock(),
    ],
  );
}

pw.Page _healthPage(
  HealthReport r,
  DairyReportFilterLabels f,
  String? generatedBy,
) {
  final df = DateFormat('d MMM yy');
  return pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(36, 40, 36, 36),
    footer: _footer,
    build: (context) => [
      _header('Dairy Report — Health', f, generatedBy),
      pw.SizedBox(height: 14),
      _kpiStrip([
        _Kpi('Sick animals', '${r.totals.sick}', sub: 'in this period'),
        _Kpi('Active cases', '${r.totals.active}',
            sub: '${r.totals.recovered} recovered'),
        _Kpi('Recovered', '${r.totals.recovered}', sub: 'this period'),
        _Kpi('Critical', '${r.totals.critical}', sub: 'severe-tagged'),
      ]),
      pw.SizedBox(height: 10),
      _deltaStrip(
        delta: r.totals.deltaPct,
        previous: '${r.totals.prev} cases previous period',
      ),
      pw.SizedBox(height: 14),
      _sectionTitle('Top diagnoses'),
      pw.SizedBox(height: 6),
      if (r.diseases.isEmpty)
        _empty('No diagnoses recorded.')
      else
        _dataTable(
          headers: const ['Diagnosis', 'Cases'],
          rows: [
            for (final d in r.diseases) [d.diagnosis, '${d.count}'],
          ],
        ),
      pw.SizedBox(height: 14),
      _sectionTitle('Active cases by house'),
      pw.SizedBox(height: 6),
      if (r.houseBreakdown.isEmpty)
        _empty('No active cases.')
      else
        _dataTable(
          headers: const ['House', 'Active cases'],
          rows: [
            for (final h in r.houseBreakdown) [h.houseName, '${h.count}'],
          ],
        ),
      pw.SizedBox(height: 14),
      _sectionTitle('Pending cases'),
      pw.SizedBox(height: 6),
      if (r.pendingCases.isEmpty)
        _empty('No pending cases — herd is clean.')
      else
        _dataTable(
          headers: const [
            'Tag',
            'Diagnosis',
            'Medication',
            'Status',
            'Started',
          ],
          rows: [
            for (final c in r.pendingCases.take(20))
              [
                [
                  c.tag,
                  if (c.nickname != null && c.nickname!.isNotEmpty)
                    c.nickname!,
                ].join(' · '),
                c.diagnosis,
                c.medication,
                c.status,
                df.format(c.startDate),
              ],
          ],
        ),
      pw.SizedBox(height: 18),
      _signatureBlock(vetLine: true),
    ],
  );
}

pw.Page _vaccinationPage(
  VaccinationReport r,
  DairyReportFilterLabels f,
  String? generatedBy,
) {
  final df = DateFormat('d MMM yy');
  return pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(36, 40, 36, 36),
    footer: _footer,
    build: (context) => [
      _header('Dairy Report — Vaccinations', f, generatedBy),
      pw.SizedBox(height: 14),
      _kpiStrip([
        _Kpi('Done', '${r.totals.completed}', sub: 'this period'),
        _Kpi('Upcoming', '${r.totals.upcoming}', sub: 'due in 30d'),
        _Kpi('Overdue', '${r.totals.overdue}', sub: 'action needed'),
        _Kpi(
          'Coverage',
          r.totals.coveragePct == null
              ? '—'
              : '${r.totals.coveragePct!.toStringAsFixed(0)}%',
          sub: '${r.totals.activeCows} active cows',
        ),
      ]),
      pw.SizedBox(height: 10),
      _deltaStrip(
        delta: r.totals.deltaPct,
        previous: '${r.totals.prev} done previous period',
      ),
      pw.SizedBox(height: 14),
      _sectionTitle('Upcoming / overdue'),
      pw.SizedBox(height: 6),
      if (r.upcomingVaccinations.isEmpty)
        _empty('All dairy protocols are on schedule.')
      else
        _dataTable(
          headers: const ['Vaccine', 'Last done', 'Next due', 'Status'],
          rows: [
            for (final s in r.upcomingVaccinations)
              [
                s.name,
                s.lastAdministeredAt == null
                    ? 'Never'
                    : df.format(s.lastAdministeredAt!),
                s.nextDueAt == null ? '—' : df.format(s.nextDueAt!),
                s.status == 'OVERDUE'
                    ? '${s.daysUntilDue.abs()}d late'
                    : 'in ${s.daysUntilDue}d',
              ],
          ],
        ),
      pw.SizedBox(height: 14),
      _sectionTitle('Recently vaccinated'),
      pw.SizedBox(height: 6),
      if (r.recentVaccinations.isEmpty)
        _empty('No vaccinations recorded in this period.')
      else
        _dataTable(
          headers: const ['Vaccine', 'Animals', 'Date'],
          rows: [
            for (final v in r.recentVaccinations)
              [
                v.vaccine,
                '${v.animalCount}',
                df.format(v.administeredAt),
              ],
          ],
        ),
      pw.SizedBox(height: 18),
      _signatureBlock(vetLine: true),
    ],
  );
}

// --- Shared widgets --------------------------------------------------

pw.Widget _header(
  String title,
  DairyReportFilterLabels f,
  String? generatedBy,
) {
  final fmtDate = DateFormat('d MMM yyyy · HH:mm');
  final filterChips = <List<String>>[
    ['Period', f.periodLabel],
    if (f.house != null) ['House', f.house!],
    if (f.worker != null) ['Worker', f.worker!],
    if (f.animal != null) ['Animal', f.animal!],
  ];
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Mwirigi Farm',
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                  color: _green,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Manage · Grow · Prosper',
                style: const pw.TextStyle(fontSize: 10, color: _txt2),
              ),
            ],
          ),
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
      pw.SizedBox(height: 14),
      pw.Container(
        width: double.infinity,
        height: 2,
        color: _green,
      ),
      pw.SizedBox(height: 12),
      pw.Text(
        title,
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
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 3,
              ),
              decoration: pw.BoxDecoration(
                color: _greenSoft,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
              ),
              child: pw.RichText(
                text: pw.TextSpan(
                  children: [
                    pw.TextSpan(
                      text: '${chip[0]}: ',
                      style: const pw.TextStyle(
                        fontSize: 9,
                        color: _txt2,
                      ),
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
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
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

pw.Widget _twoColTable({required List<List<String>> rows}) {
  return pw.Table(
    border: pw.TableBorder.all(color: _border, width: 0.5),
    columnWidths: const {
      0: pw.FlexColumnWidth(2),
      1: pw.FlexColumnWidth(1),
    },
    children: [
      for (final row in rows)
        pw.TableRow(children: [
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: pw.Text(row[0], style: const pw.TextStyle(fontSize: 10)),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: pw.Text(
              row[1],
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        ]),
    ],
  );
}

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
                horizontal: 6,
                vertical: 5,
              ),
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
                  horizontal: 6,
                  vertical: 5,
                ),
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

pw.Widget _signatureBlock({bool vetLine = false}) {
  return pw.Container(
    padding: const pw.EdgeInsets.only(top: 18),
    child: pw.Row(
      children: [
        _signatureLine('Prepared by (Manager)'),
        pw.SizedBox(width: 24),
        _signatureLine(vetLine ? 'Reviewed by (Vet)' : 'Reviewed by (CEO)'),
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
      margin: const pw.EdgeInsets.only(top: 12),
      child: pw.Text(
        'Mwirigi Farm Management System  ·  Page ${context.pageNumber}'
        ' of ${context.pagesCount}',
        style: const pw.TextStyle(fontSize: 8, color: _txt3),
      ),
    );

