// Activity / Audit Log Report PDF builder.
// Entry point: `buildActivityReportPdf` — takes a list of audit log rows
// and filter labels, returns A4 PDF bytes.
// Mirrors the Mwirigi Farm PDF style (green header, signature block).

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

const _green     = PdfColor.fromInt(0xff27500a);
const _greenSoft = PdfColor.fromInt(0xffeaf3de);
const _amber     = PdfColor.fromInt(0xff854f0b);
const _amberSoft = PdfColor.fromInt(0xfffaeeda);
const _ink       = PdfColor.fromInt(0xff1a1a1a);
const _txt2      = PdfColor.fromInt(0xff6b7770);
const _txt3      = PdfColor.fromInt(0xff99a39b);
const _border    = PdfColor.fromInt(0xffd9d9d9);
const _redSoft   = PdfColor.fromInt(0xfffff0f0);
const _redInk    = PdfColor.fromInt(0xffc4393b);

class ActivityLogRow {
  const ActivityLogRow({
    required this.createdAt,
    required this.action,
    required this.entity,
    required this.module,
    this.entityId,
    this.actorName,
    this.reason,
  });

  final DateTime createdAt;
  final String action;   // CREATE | UPDATE | DELETE
  final String entity;
  final String module;
  final String? entityId;
  final String? actorName;
  final String? reason;

  factory ActivityLogRow.fromJson(Map<String, dynamic> j) {
    final actor = j['actor'];
    return ActivityLogRow(
      createdAt: DateTime.tryParse((j['createdAt'] ?? '').toString()) ??
          DateTime.now(),
      action: (j['action'] ?? '').toString(),
      entity: (j['entity'] ?? '').toString(),
      module: (j['module'] ?? '').toString(),
      entityId: j['entityId']?.toString(),
      actorName: actor is Map ? actor['userName']?.toString() : null,
      reason: j['reason']?.toString(),
    );
  }
}

class ActivityReportInput {
  const ActivityReportInput({
    required this.rows,
    required this.total,
    required this.periodLabel,
    this.moduleLabel,
    this.actionLabel,
    this.generatedBy,
  });

  final List<ActivityLogRow> rows;
  final int total;
  final String periodLabel;
  final String? moduleLabel;
  final String? actionLabel;
  final String? generatedBy;
}

Future<Uint8List> buildActivityReportPdf(ActivityReportInput input) async {
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

pw.MultiPage _buildPage(ActivityReportInput r, Uint8List? logo) {
  final created = r.rows.where((e) => e.action == 'CREATE').length;
  final updated = r.rows.where((e) => e.action == 'UPDATE').length;
  final deleted = r.rows.where((e) => e.action == 'DELETE').length;

  return pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(36, 40, 36, 36),
    footer: _footer,
    build: (context) => [
      _header(r, logo),
      pw.SizedBox(height: 14),
      _kpiStrip([
        _Kpi('Total changes', '${r.total}', sub: 'in selected range'),
        _Kpi('Created', '$created', sub: 'new records'),
        _Kpi('Updated', '$updated', sub: 'edits'),
        _Kpi('Deleted', '$deleted', sub: 'removals'),
      ]),
      pw.SizedBox(height: 14),
      _sectionTitle('Activity log'),
      pw.SizedBox(height: 6),
      if (r.rows.isEmpty)
        _empty('No activity found for the selected filters.')
      else
        _activityTable(r.rows),
      pw.SizedBox(height: 18),
      _signatureBlock(),
    ],
  );
}

pw.Widget _activityTable(List<ActivityLogRow> rows) {
  final df = DateFormat('d MMM yy HH:mm');
  return pw.Table(
    border: pw.TableBorder.all(color: _border, width: 0.5),
    columnWidths: const {
      0: pw.FixedColumnWidth(90),  // Date/Time
      1: pw.FlexColumnWidth(1),    // Actor
      2: pw.FixedColumnWidth(52),  // Action
      3: pw.FlexColumnWidth(1.2),  // Module · Entity
      4: pw.FlexColumnWidth(1.5),  // Reason / notes
    },
    children: [
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _greenSoft),
        children: [
          for (final h in const ['Date / Time', 'Actor', 'Action', 'Module · Entity', 'Reason'])
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              child: pw.Text(h.toUpperCase(),
                  style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold,
                      color: _green, letterSpacing: 0.4)),
            ),
        ],
      ),
      for (final row in rows)
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: row.action == 'DELETE' ? _redSoft : null,
          ),
          children: [
            _cell(df.format(row.createdAt.toLocal())),
            _cell(row.actorName ?? '—'),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              child: pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: pw.BoxDecoration(
                  color: _actionBg(row.action),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Text(
                  row.action,
                  style: pw.TextStyle(
                    fontSize: 7,
                    fontWeight: pw.FontWeight.bold,
                    color: _actionFg(row.action),
                  ),
                ),
              ),
            ),
            _cell('${row.module} · ${row.entity}'),
            _cell(row.reason ?? '—'),
          ],
        ),
    ],
  );
}

PdfColor _actionBg(String action) {
  switch (action) {
    case 'CREATE':
      return _greenSoft;
    case 'DELETE':
      return _redSoft;
    default:
      return _amberSoft;
  }
}

PdfColor _actionFg(String action) {
  switch (action) {
    case 'CREATE':
      return _green;
    case 'DELETE':
      return _redInk;
    default:
      return _amber;
  }
}

pw.Widget _cell(String text) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 8, color: _ink)),
    );

pw.Widget _header(ActivityReportInput r, Uint8List? logo) {
  final fmtDate = DateFormat('d MMM yyyy · HH:mm');
  final chips = <List<String>>[
    ['Period', r.periodLabel],
    if (r.moduleLabel != null) ['Module', r.moduleLabel!],
    if (r.actionLabel != null) ['Action', r.actionLabel!],
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
      pw.Text('Activity & Audit Report',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: _ink)),
      pw.SizedBox(height: 6),
      pw.Wrap(spacing: 6, runSpacing: 6, children: [
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
      ]),
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
      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold,
          color: _txt2, letterSpacing: 0.5),
    );

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
        _signatureLine('Reviewed by (CEO)'),
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
