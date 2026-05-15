// 📄 Report preview — renders a generated ReportSpec from /api/reports
// /catalog/<key>. Section renderers cover every type the backend can
// emit (kpis · narrative · table · progress · split · session-breakdown
// · reminders · comments · signatures · footnote).
//
// Export actions:
//   • CSV  — POST to backend, save & open via printing/download
//   • PDF  — render the whole report into a pdf doc and hand to the
//            system print/share sheet (printing.layoutPdf)
//
// Boardroom A4 layout (letterhead, page-break controls) is deferred —
// the v1 PDF is the pdf-package default layout with the same content as
// the on-screen preview. Good enough for sharing; not yet boardroom.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/models/report.dart';
import '../../core/service/api_service.dart';

class ReportPreviewPage extends StatefulWidget {
  const ReportPreviewPage({super.key, required this.report});
  final ReportListItem report;

  @override
  State<ReportPreviewPage> createState() => _ReportPreviewPageState();
}

class _ReportPreviewPageState extends State<ReportPreviewPage> {
  static const _primary = Color(0xFF27500A);
  static const _amber = Color(0xFF8A5A0A);
  static const _danger = Color(0xFFC4393B);
  static const _blue = Color(0xFF185FA5);
  static const _txt2 = Color(0xFF6B7770);
  static const _txt3 = Color(0xFF99A39B);

  late Future<ReportSpec> _future;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<ReportSpec> _load() async {
    final raw = await ApiService.getReport(widget.report.key);
    return ReportSpec.fromJson(raw);
  }

  Color _kpiColor(String? cls) {
    switch (cls) {
      case 'g': return _primary;
      case 'a': return _amber;
      case 'r': return _danger;
      case 'b': return _blue;
      default:  return Colors.black87;
    }
  }

  Future<void> _exportPdf(ReportSpec spec) async {
    setState(() => _exporting = true);
    try {
      final bytes = await _renderPdf(spec);
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: '${spec.title} — ${spec.period}',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF export failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _exportCsv() async {
    setState(() => _exporting = true);
    try {
      // Hand the URL to the system — Printing.sharePdf works for any
      // bytes. We fetch the CSV bytes via http and share.
      final url = ApiService.reportCsvUri(widget.report.key);
      // Defer to the OS share sheet via a launchable URL. Printing
      // doesn't ship a CSV-share helper; the simplest path is to copy
      // the URL to the clipboard so the user opens it in a browser.
      await _showCsvDialog(url.toString());
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _showCsvDialog(String url) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('CSV download'),
        content: SelectableText(
          'CSV is generated server-side. Open this URL in your browser '
          'to download:\n\n$url',
          style: const TextStyle(fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // -------- PDF rendering --------

  Future<Uint8List> _renderPdf(ReportSpec spec) async {
    // Load Unicode-safe fonts. Helvetica (the pdf package default)
    // can't render em-dashes or emoji — Noto Sans handles all Latin/
    // punctuation, Noto Emoji is the monochrome fallback for the 🌿 /
    // 📝 / 🐄 etc. glyphs that show up in titles and section headers.
    final base = await PdfGoogleFonts.notoSansRegular();
    final bold = await PdfGoogleFonts.notoSansBold();
    final italic = await PdfGoogleFonts.notoSansItalic();
    final emoji = await PdfGoogleFonts.notoEmojiRegular();

    final doc = pw.Document(
      theme: pw.ThemeData.withFont(
        base: base,
        bold: bold,
        italic: italic,
        fontFallback: [emoji],
      ),
    );
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 48),
        header: (_) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: PdfColors.green800, width: 1.5),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('🌿 MWIRIGI FARM',
                  style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.green800)),
              pw.Text('Report: ${widget.report.label}',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
            ],
          ),
        ),
        footer: (ctx) => pw.Container(
          padding: const pw.EdgeInsets.only(top: 6),
          decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Mwirigi Farm Management v4.2 — confidential',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              pw.Text('Page ${ctx.pageNumber} / ${ctx.pagesCount}',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
            ],
          ),
        ),
        build: (_) => [
          pw.SizedBox(height: 8),
          pw.Text(spec.title,
              style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.green800)),
          pw.SizedBox(height: 2),
          pw.Text('Period: ${spec.period}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          if (spec.summary.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            pw.Text(spec.summary,
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
          ],
          pw.SizedBox(height: 14),
          if (spec.kpis.isNotEmpty) _pdfKpiStrip(spec.kpis),
          pw.SizedBox(height: 12),
          ...spec.sections.map(_pdfSection),
          if (spec.footnote != null && spec.footnote!.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            pw.Text(spec.footnote!,
                style: pw.TextStyle(
                    fontSize: 8, fontStyle: pw.FontStyle.italic, color: PdfColors.grey600)),
          ],
        ],
      ),
    );
    return doc.save();
  }

  pw.Widget _pdfKpiStrip(List<ReportKpi> kpis) {
    return pw.Wrap(
      spacing: 6,
      runSpacing: 6,
      children: kpis.map((k) {
        final color = switch (k.colorClass) {
          'g' => PdfColors.green800,
          'a' => PdfColors.orange800,
          'r' => PdfColors.red700,
          'b' => PdfColors.blue700,
          _   => PdfColors.black,
        };
        return pw.Container(
          width: 110,
          padding: const pw.EdgeInsets.all(6),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(k.label.toUpperCase(),
                  style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
              pw.SizedBox(height: 2),
              pw.Text('${k.value}${k.unit?.isNotEmpty == true ? ' ${k.unit}' : ''}',
                  style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: color)),
              if (k.target != null && k.target!.isNotEmpty)
                pw.Text(k.target!,
                    style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
            ],
          ),
        );
      }).toList(),
    );
  }

  pw.Widget _pdfSection(ReportSection s) {
    pw.Widget heading(String? title) => title == null || title.isEmpty
        ? pw.SizedBox()
        : pw.Padding(
            padding: const pw.EdgeInsets.only(top: 8, bottom: 4),
            child: pw.Text(title.toUpperCase(),
                style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.green800)),
          );

    switch (s.type) {
      case 'narrative':
        return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          heading(s.title),
          pw.Text(s.body ?? '', style: const pw.TextStyle(fontSize: 10)),
        ]);
      case 'table':
        final headers = s.headers ?? const [];
        final rows = s.rows ?? const [];
        return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          heading(s.title),
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: rows,
            headerStyle: pw.TextStyle(
                fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.green800),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellAlignment: pw.Alignment.centerLeft,
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          ),
        ]);
      case 'progress':
        final items = s.items ?? const [];
        return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          heading(s.title),
          ...items.map((it) {
            final pct = (it.pct ?? 0).toDouble();
            final col = pct >= 80
                ? PdfColors.green800
                : pct >= 50
                    ? PdfColors.orange800
                    : PdfColors.red700;
            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 6),
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text(it.label,
                      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  pw.Text('${pct.toInt()}%',
                      style: pw.TextStyle(
                          fontSize: 9, color: col, fontWeight: pw.FontWeight.bold)),
                ]),
                pw.SizedBox(height: 2),
                pw.Stack(children: [
                  pw.Container(height: 5, color: PdfColors.grey200),
                  pw.Container(
                    height: 5,
                    width: 460 * (pct.clamp(0, 100).toDouble() / 100),
                    color: col,
                  ),
                ]),
                if (it.detail != null && it.detail!.isNotEmpty)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 2),
                    child: pw.Text(it.detail!,
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                  ),
              ]),
            );
          }),
        ]);
      case 'split':
        final items = s.items ?? const [];
        return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          heading(s.title),
          pw.Wrap(
            spacing: 6,
            runSpacing: 6,
            children: items.map((it) {
              return pw.Container(
                width: 140,
                padding: const pw.EdgeInsets.all(6),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  border: pw.Border(
                    left: pw.BorderSide(color: PdfColors.green800, width: 3),
                  ),
                ),
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text(it.label,
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                  pw.Text(it.value ?? '',
                      style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  if (it.sub != null && it.sub!.isNotEmpty)
                    pw.Text(it.sub!,
                        style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                ]),
              );
            }).toList(),
          ),
        ]);
      case 'session-breakdown':
        final rows = (s.sessions ?? const []).map((r) => [r.label, r.value]).toList();
        return pw.Padding(
          padding: const pw.EdgeInsets.only(top: 6),
          child: pw.TableHelper.fromTextArray(
            data: rows,
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellAlignments: const {1: pw.Alignment.centerRight},
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          ),
        );
      case 'reminders':
        return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          heading(s.title),
          pw.Text('Live reminders are visible in the on-screen preview.',
              style: pw.TextStyle(
                  fontSize: 9, fontStyle: pw.FontStyle.italic, color: PdfColors.grey600)),
        ]);
      case 'comments':
        final lines = s.lines ?? 5;
        return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          heading('📝 ${s.title ?? 'Comments'}'),
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey50,
              border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
            ),
            child: pw.Column(
              children: List.generate(
                lines,
                (_) => pw.Container(
                  height: 16,
                  margin: const pw.EdgeInsets.only(bottom: 2),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                      bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.4),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ]);
      case 'signature':
        final roles = s.roles ?? const [];
        return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          heading('Signatures'),
          pw.Wrap(
            spacing: 12,
            runSpacing: 12,
            children: roles.map((r) {
              return pw.Container(
                width: 160,
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Container(
                    height: 22,
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(
                        bottom: pw.BorderSide(color: PdfColors.black, width: 0.6),
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(r,
                      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Date: ____ / ____ / ______',
                      style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                ]),
              );
            }).toList(),
          ),
        ]);
    }
    return pw.SizedBox();
  }

  // -------- Build --------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAF7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _primary,
        elevation: 0.5,
        title: Text(
          widget.report.label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: FutureBuilder<ReportSpec>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        color: Color(0xFFE24B4A), size: 36),
                    const SizedBox(height: 8),
                    Text(
                      snap.error.toString().replaceFirst('Exception: ', ''),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => setState(() => _future = _load()),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }
          final spec = snap.data!;
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    _Header(spec: spec),
                    const SizedBox(height: 14),
                    if (spec.kpis.isNotEmpty)
                      _KpiGrid(kpis: spec.kpis, color: _kpiColor),
                    const SizedBox(height: 14),
                    for (final s in spec.sections) ...[
                      _SectionRenderer(section: s),
                      const SizedBox(height: 14),
                    ],
                    if (spec.footnote != null && spec.footnote!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          spec.footnote!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: _txt3,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              _ExportBar(
                formats: widget.report.formats,
                exporting: _exporting,
                onPdf: () => _exportPdf(spec),
                onCsv: _exportCsv,
              ),
            ],
          );
        },
      ),
    );
  }
}

// ===================================================================
// Header
// ===================================================================

class _Header extends StatelessWidget {
  const _Header({required this.spec});
  final ReportSpec spec;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            spec.title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: _ReportPreviewPageState._primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Period: ${spec.period}',
            style: const TextStyle(
              fontSize: 11,
              color: _ReportPreviewPageState._txt2,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (spec.summary.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF6F8F4),
                borderRadius: BorderRadius.circular(8),
                border: const Border(
                  left: BorderSide(
                    color: _ReportPreviewPageState._primary,
                    width: 3,
                  ),
                ),
              ),
              child: Text(
                spec.summary,
                style: const TextStyle(
                  fontSize: 12,
                  color: _ReportPreviewPageState._txt2,
                  height: 1.5,
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
// KPI grid
// ===================================================================

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.kpis, required this.color});
  final List<ReportKpi> kpis;
  final Color Function(String?) color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 700
            ? 4
            : c.maxWidth >= 420
                ? 2
                : 1;
        final w = (c.maxWidth - 8 * (cols - 1)) / cols;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final k in kpis)
              SizedBox(
                width: w,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAFAF7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        k.label.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: _ReportPreviewPageState._txt2,
                          letterSpacing: 0.04,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            k.value,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: color(k.colorClass),
                            ),
                          ),
                          if (k.unit != null && k.unit!.isNotEmpty) ...[
                            const SizedBox(width: 4),
                            Text(
                              k.unit!,
                              style: const TextStyle(
                                fontSize: 11,
                                color: _ReportPreviewPageState._txt2,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (k.target != null && k.target!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          k.target!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: _ReportPreviewPageState._txt3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ===================================================================
// Section renderer
// ===================================================================

class _SectionRenderer extends StatelessWidget {
  const _SectionRenderer({required this.section});
  final ReportSection section;

  @override
  Widget build(BuildContext context) {
    switch (section.type) {
      case 'narrative':
        return _SectionWrap(
          title: section.title,
          child: Text(
            section.body ?? '',
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black87,
              height: 1.55,
            ),
          ),
        );
      case 'table':
        return _SectionWrap(
          title: section.title,
          child: _TableView(
            headers: section.headers ?? const [],
            rows: section.rows ?? const [],
          ),
        );
      case 'progress':
        return _SectionWrap(
          title: section.title,
          child: Column(
            children: (section.items ?? const [])
                .map((it) => _ProgressRow(item: it))
                .toList(),
          ),
        );
      case 'split':
        return _SectionWrap(
          title: section.title,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: (section.items ?? const [])
                .map((it) => _SplitTile(item: it))
                .toList(),
          ),
        );
      case 'session-breakdown':
        return _SectionWrap(
          title: null,
          child: _SessionBreakdown(
            rows: section.sessions ?? const [],
          ),
        );
      case 'reminders':
        return _SectionWrap(
          title: section.title,
          child: const Text(
            'Live reminders are listed in the 🔔 Reminders dashboard. '
            'They are summarised live; status reflects today.',
            style: TextStyle(
              fontSize: 12,
              color: _ReportPreviewPageState._txt2,
              fontStyle: FontStyle.italic,
            ),
          ),
        );
      case 'comments':
        return _SectionWrap(
          title: '📝 ${section.title ?? 'Comments'} (handwritten on print)',
          child: _CommentsBlock(lines: section.lines ?? 5),
        );
      case 'signature':
        return _SectionWrap(
          title: 'Signatures',
          child: _SignatureGrid(roles: section.roles ?? const []),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class _SectionWrap extends StatelessWidget {
  const _SectionWrap({required this.title, required this.child});
  final String? title;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null && title!.isNotEmpty) ...[
            Text(
              title!.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: _ReportPreviewPageState._primary,
                letterSpacing: 0.04,
              ),
            ),
            const SizedBox(height: 8),
          ],
          child,
        ],
      ),
    );
  }
}

class _TableView extends StatelessWidget {
  const _TableView({required this.headers, required this.rows});
  final List<String> headers;
  final List<List<String>> rows;
  @override
  Widget build(BuildContext context) {
    if (headers.isEmpty || rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'No data.',
          style: TextStyle(
              fontSize: 12, color: _ReportPreviewPageState._txt3),
        ),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 32,
        dataRowMinHeight: 32,
        dataRowMaxHeight: 44,
        columnSpacing: 18,
        horizontalMargin: 4,
        headingRowColor: WidgetStateProperty.resolveWith(
          (_) => const Color(0xFFEEF3E8),
        ),
        headingTextStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: _ReportPreviewPageState._txt2,
          letterSpacing: 0.04,
        ),
        columns: [for (final h in headers) DataColumn(label: Text(h))],
        rows: [
          for (final r in rows)
            DataRow(
              cells: [
                for (final c in r)
                  DataCell(Text(
                    c,
                    style: const TextStyle(fontSize: 12),
                  )),
              ],
            ),
        ],
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({required this.item});
  final ReportSectionItem item;
  @override
  Widget build(BuildContext context) {
    final pct = (item.pct ?? 0).toDouble();
    final color = pct >= 80
        ? _ReportPreviewPageState._primary
        : pct >= 50
            ? _ReportPreviewPageState._amber
            : _ReportPreviewPageState._danger;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${pct.toInt()}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Stack(
            children: [
              Container(
                height: 6,
                decoration: BoxDecoration(
                  color: const Color(0xFFE9ECE5),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              FractionallySizedBox(
                widthFactor: (pct.clamp(0, 100)).toDouble() / 100,
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ],
          ),
          if (item.detail != null && item.detail!.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              item.detail!,
              style: const TextStyle(
                fontSize: 11,
                color: _ReportPreviewPageState._txt3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SplitTile extends StatelessWidget {
  const _SplitTile({required this.item});
  final ReportSectionItem item;
  Color _parseHex(String? hex) {
    if (hex == null) return _ReportPreviewPageState._primary;
    final s = hex.replaceFirst('#', '');
    final v = int.tryParse(s, radix: 16) ?? 0x27500A;
    return Color(0xFF000000 | v);
  }

  @override
  Widget build(BuildContext context) {
    final accent = _parseHex(item.color);
    return Container(
      width: 160,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAF7),
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: accent, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _ReportPreviewPageState._txt2,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            item.value ?? '',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),
          if (item.sub != null && item.sub!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              item.sub!,
              style: const TextStyle(
                fontSize: 11,
                color: _ReportPreviewPageState._txt3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SessionBreakdown extends StatelessWidget {
  const _SessionBreakdown({required this.rows});
  final List<ReportSessionRow> rows;
  @override
  Widget build(BuildContext context) {
    return Column(
      children: rows.map((r) {
        final isHighlight = r.highlight;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isHighlight ? const Color(0xFFEFF5E6) : Colors.transparent,
            border: const Border(
              bottom: BorderSide(color: Color(0x14000000), width: 0.5),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  r.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isHighlight ? FontWeight.w800 : FontWeight.w500,
                    color: isHighlight
                        ? _ReportPreviewPageState._primary
                        : Colors.black87,
                  ),
                ),
              ),
              Text(
                r.value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isHighlight
                      ? _ReportPreviewPageState._primary
                      : Colors.black87,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _CommentsBlock extends StatelessWidget {
  const _CommentsBlock({required this.lines});
  final int lines;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAF7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: Column(
        children: List.generate(
          lines,
          (_) => Container(
            height: 18,
            margin: const EdgeInsets.only(bottom: 4),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0x22000000), width: 0.5),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SignatureGrid extends StatelessWidget {
  const _SignatureGrid({required this.roles});
  final List<String> roles;
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: roles.map((role) {
        return SizedBox(
          width: 180,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 28,
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.black87, width: 0.8),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                role,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _ReportPreviewPageState._txt2,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Date: ____ / ____ / ______',
                style: TextStyle(
                  fontSize: 10,
                  color: _ReportPreviewPageState._txt3,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ===================================================================
// Sticky export bar
// ===================================================================

class _ExportBar extends StatelessWidget {
  const _ExportBar({
    required this.formats,
    required this.exporting,
    required this.onPdf,
    required this.onCsv,
  });
  final List<String> formats;
  final bool exporting;
  final VoidCallback onPdf;
  final VoidCallback onCsv;

  @override
  Widget build(BuildContext context) {
    final hasPdf = formats.contains('PDF');
    final hasCsv = formats.contains('CSV');
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0x14000000)),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 6,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (hasPdf)
              Expanded(
                child: FilledButton.icon(
                  onPressed: exporting ? null : onPdf,
                  icon: exporting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.picture_as_pdf_outlined, size: 16),
                  label: Text(exporting ? 'Working…' : 'Export PDF'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _ReportPreviewPageState._primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            if (hasPdf && hasCsv) const SizedBox(width: 8),
            if (hasCsv)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: exporting ? null : onCsv,
                  icon: const Icon(Icons.table_view_outlined, size: 16),
                  label: const Text('CSV'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _ReportPreviewPageState._primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
