import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Plain-data sale receipt model. Used to render a PDF on-device
/// after Sell Bull / Sell Dopper succeeds — replaces the old
/// "attach a photo of the receipt" flow with an auto-generated one.
class SaleReceiptData {
  const SaleReceiptData({
    required this.kind, // "Bull" | "Sheep" — drives the header
    required this.animalTag,
    required this.saleDate,
    required this.salePrice,
    required this.buyerName,
    this.buyerPhone,
    this.soldWeightKg,
    this.paymentMethod,
    this.notes,
    this.recordedBy,
  });

  final String kind;
  final String animalTag;
  final DateTime saleDate;
  final num salePrice;
  final String buyerName;
  final String? buyerPhone;
  final num? soldWeightKg;
  final String? paymentMethod;
  final String? notes;
  final String? recordedBy;
}

/// Build the PDF bytes for a sale receipt. Used both by the in-app
/// preview (Printing.layoutPdf) and any future share/save flow.
Future<Uint8List> buildSaleReceiptPdf(SaleReceiptData data) async {
  final fmtDate = DateFormat('d MMM yyyy');
  final fmtTime = DateFormat('HH:mm');
  final fmtMoney = NumberFormat.currency(symbol: 'KES ', decimalDigits: 2);

  final doc = pw.Document();
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(36, 40, 36, 36),
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            // Header
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
                        color: PdfColor.fromInt(0xff27500a),
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Manage · Grow · Prosper',
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColor.fromInt(0xff666666),
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromInt(0xffeaf3de),
                        borderRadius: pw.BorderRadius.circular(999),
                      ),
                      child: pw.Text(
                        'SALE RECEIPT',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromInt(0xff27500a),
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      'No. ${_receiptNumber(data)}',
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 18),
            pw.Divider(color: PdfColor.fromInt(0xffcccccc)),
            pw.SizedBox(height: 14),

            // Sale summary
            pw.Text(
              '${data.kind} sale — ${data.animalTag}',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Recorded ${fmtDate.format(data.saleDate)} '
              '${fmtTime.format(data.saleDate)}'
              '${data.recordedBy != null ? " by ${data.recordedBy}" : ""}',
              style: const pw.TextStyle(
                fontSize: 11,
                color: PdfColor.fromInt(0xff666666),
              ),
            ),
            pw.SizedBox(height: 18),

            // Two-column details
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: _section(
                    'BUYER',
                    [
                      _kv('Name', data.buyerName),
                      if (data.buyerPhone != null && data.buyerPhone!.isNotEmpty)
                        _kv('Phone', data.buyerPhone!),
                    ],
                  ),
                ),
                pw.SizedBox(width: 18),
                pw.Expanded(
                  child: _section(
                    'SALE',
                    [
                      _kv('Date', fmtDate.format(data.saleDate)),
                      if (data.soldWeightKg != null)
                        _kv('Weight', '${data.soldWeightKg} kg'),
                      _kv('Price', fmtMoney.format(data.salePrice)),
                      if (data.paymentMethod != null &&
                          data.paymentMethod!.isNotEmpty)
                        _kv('Payment', _humanPayment(data.paymentMethod!)),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 18),

            if (data.notes != null && data.notes!.trim().isNotEmpty) ...[
              _section('NOTES', [
                pw.Text(
                  data.notes!.trim(),
                  style: const pw.TextStyle(fontSize: 11),
                ),
              ]),
              pw.SizedBox(height: 18),
            ],

            // Total
            pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromInt(0xffeaf3de),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'TOTAL DUE',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromInt(0xff27500a),
                      letterSpacing: 0.6,
                    ),
                  ),
                  pw.Text(
                    fmtMoney.format(data.salePrice),
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromInt(0xff27500a),
                    ),
                  ),
                ],
              ),
            ),

            pw.Spacer(),

            // Footer signatures
            pw.Row(
              children: [
                pw.Expanded(child: _signatureLine('Seller')),
                pw.SizedBox(width: 24),
                pw.Expanded(child: _signatureLine('Buyer')),
              ],
            ),
            pw.SizedBox(height: 14),
            pw.Text(
              'This receipt is auto-generated by Mwirigi Farm Management '
              'System and recorded in the finance cashflow ledger.',
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(
                fontSize: 9,
                color: PdfColor.fromInt(0xff888888),
              ),
            ),
          ],
        );
      },
    ),
  );
  return doc.save();
}

/// Open the print/share sheet for a sale receipt. Returns the bytes
/// in case a caller also wants to upload or attach them elsewhere.
Future<Uint8List> previewSaleReceipt(SaleReceiptData data) async {
  final bytes = await buildSaleReceiptPdf(data);
  await Printing.layoutPdf(
    name: 'Mwirigi-${data.kind}-${data.animalTag}-receipt',
    onLayout: (_) async => bytes,
  );
  return bytes;
}

// ---- private helpers ----

String _receiptNumber(SaleReceiptData d) {
  // Short stable-ish number derived from the sale timestamp + tag so a
  // re-print of the same sale matches. Not a UUID — just enough for a
  // human to cross-reference with the Revenue row.
  final ts = d.saleDate.millisecondsSinceEpoch ~/ 1000;
  final tag = d.animalTag.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
  return 'MF-${tag.substring(0, tag.length < 6 ? tag.length : 6)}-$ts';
}

String _humanPayment(String wire) {
  switch (wire) {
    case 'CASH':
      return 'Cash';
    case 'MPESA':
      return 'M-Pesa';
    case 'BANK_TRANSFER':
      return 'Bank transfer';
    case 'CHEQUE':
      return 'Cheque';
    default:
      return 'Other';
  }
}

pw.Widget _section(String title, List<pw.Widget> children) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
          color: PdfColor.fromInt(0xff888888),
          letterSpacing: 0.6,
        ),
      ),
      pw.SizedBox(height: 6),
      ...children,
    ],
  );
}

pw.Widget _kv(String key, String value) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 4),
    child: pw.RichText(
      text: pw.TextSpan(
        children: [
          pw.TextSpan(
            text: '$key:  ',
            style: const pw.TextStyle(
              fontSize: 11,
              color: PdfColor.fromInt(0xff666666),
            ),
          ),
          pw.TextSpan(
            text: value,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    ),
  );
}

pw.Widget _signatureLine(String label) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Container(
        height: 1,
        color: PdfColor.fromInt(0xff999999),
      ),
      pw.SizedBox(height: 4),
      pw.Text(
        label,
        style: const pw.TextStyle(
          fontSize: 10,
          color: PdfColor.fromInt(0xff666666),
        ),
      ),
    ],
  );
}
