// Sales management page — shared by Layers (egg crates) and Dairy (milk litres).
//
// Layout:
//   1. KPI strip  — today's count · total quantity · total revenue
//   2. Filter bar — period picker  (not wired to backend yet; UI placeholder)
//   3. Sales list — one card per transaction, newest first
//
// Log Sale FAB opens LogSaleDialog. After a successful POST the list
// reloads automatically.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/models/sales.dart';
import '../../core/service/api_service.dart';

// ── entry point ───────────────────────────────────────────────────────────

class SalesPage extends StatefulWidget {
  const SalesPage({
    super.key,
    required this.module,  // 'LAYERS' or 'DAIRY'
  });

  final String module;

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  Future<_PageData>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_PageData> _load() async {
    final salesRaw = await ApiService.getSales(module: widget.module, limit: 100);
    final summaryRaw = await ApiService.getSalesSummary(widget.module);
    return _PageData(
      list: SaleList.fromJson(salesRaw.cast<String, dynamic>()),
      summary: SalesTodaySummary.fromJson(summaryRaw.cast<String, dynamic>()),
    );
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _openLogSale() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => LogSaleDialog(module: widget.module),
    );
    if (saved == true) _refresh();
  }

  Future<void> _confirmDelete(ProductSale sale) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete sale?'),
        content: Text(
          'Remove the ${sale.buyerName} sale of '
          '${sale.quantity} ${sale.unitLabel} on '
          '${DateFormat('d MMM yyyy').format(sale.saleDate)}?\n\n'
          'The linked Finance revenue entry will be preserved.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE24B4A)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiService.deleteSale(sale.id);
      _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final unitName = widget.module == 'LAYERS' ? 'Egg' : 'Milk';
    return FutureBuilder<_PageData>(
      future: _future,
      builder: (context, snap) {
        final loading = snap.connectionState == ConnectionState.waiting;
        final data = snap.data;

        // SalesPage is embedded inside a parent ListView — use Column so
        // content sizes to its children instead of collapsing to zero.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── KPI strip ──────────────────────────────────────────────
            if (data != null) _SummaryStrip(summary: data.summary, unitLabel: widget.module == 'LAYERS' ? 'crates' : 'L'),
            // ── Log Sale action ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(top: 14, bottom: 4),
              child: FilledButton.icon(
                onPressed: _openLogSale,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Log Sale'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF27500A),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            if (loading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (snap.hasError)
              Padding(
                padding: const EdgeInsets.all(24),
                child: _ErrorCard(
                  message: snap.error.toString().replaceFirst('Exception: ', ''),
                  onRetry: _refresh,
                ),
              )
            else if (data != null) ...[
              // ── list ─────────────────────────────────────────────────
              if (data.list.rows.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 60),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.sell_outlined, size: 40, color: Color(0xFFAAAAAA)),
                        const SizedBox(height: 12),
                        Text(
                          'No $unitName sales recorded yet.',
                          style: const TextStyle(fontSize: 13, color: Colors.black54),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tap + Log Sale to record your first sale.',
                          style: TextStyle(fontSize: 12, color: Colors.black54.withAlpha(150)),
                        ),
                      ],
                    ),
                  ),
                )
              else
                for (final sale in data.list.rows) ...[
                  const SizedBox(height: 10),
                  _SaleCard(
                    sale: sale,
                    onDelete: () => _confirmDelete(sale),
                    onEdit: () async {
                      final saved = await showDialog<bool>(
                        context: context,
                        builder: (_) => LogSaleDialog(
                          module: widget.module,
                          existing: sale,
                        ),
                      );
                      if (saved == true) _refresh();
                    },
                  ),
                ],
            ],
          ],
        );
      },
    );
  }

}

class _PageData {
  _PageData({required this.list, required this.summary});
  final SaleList list;
  final SalesTodaySummary summary;
}

// ── summary strip ─────────────────────────────────────────────────────────

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.summary, required this.unitLabel});
  final SalesTodaySummary summary;
  final String unitLabel;

  @override
  Widget build(BuildContext context) {
    final fmtCcy = NumberFormat.currency(locale: 'en_KE', symbol: 'KES ');
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 0),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x14000000)),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '💰  TODAY\'S SALES',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: Color(0xFF27500A),
            ),
          ),
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _Tile(
                    label: 'Sales',
                    value: '${summary.count}',
                    sub: 'transactions',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _Tile(
                    label: 'Quantity',
                    value: _fmt(summary.totalQuantity),
                    sub: unitLabel,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _Tile(
                    label: 'Revenue',
                    value: fmtCcy.format(summary.totalRevenue),
                    sub: 'paid today',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _fmt(num n) {
    if (n == n.roundToDouble()) return n.toInt().toString();
    return n.toStringAsFixed(1);
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.value, required this.sub});
  final String label;
  final String value;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8F4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: Color(0xFF6B7770)),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF27500A)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(sub, style: const TextStyle(fontSize: 11, color: Color(0xFF99A39B), fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ── sale card ─────────────────────────────────────────────────────────────

class _SaleCard extends StatelessWidget {
  const _SaleCard({
    required this.sale,
    required this.onDelete,
    required this.onEdit,
  });
  final ProductSale sale;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('d MMM yyyy');
    final fmtCcy = NumberFormat.currency(locale: 'en_KE', symbol: 'KES ');

    final paymentBadgeColor = sale.paymentMode == 'CASH'
        ? const Color(0xFFE8F5E9)
        : sale.paymentMode == 'MPESA'
            ? const Color(0xFFFFF3E0)
            : const Color(0xFFE3F2FD);

    final paymentTextColor = sale.paymentMode == 'CASH'
        ? const Color(0xFF388E3C)
        : sale.paymentMode == 'MPESA'
            ? const Color(0xFFE65100)
            : const Color(0xFF1565C0);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // Date chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F8F4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  dateFmt.format(sale.saleDate),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF27500A)),
                ),
              ),
              const SizedBox(width: 8),
              // Payment mode badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: paymentBadgeColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  paymentModeLabel(sale.paymentMode),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: paymentTextColor),
                ),
              ),
              const Spacer(),
              // Action menu
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 18, color: Color(0xFF6B7770)),
                onSelected: (v) {
                  if (v == 'edit') onEdit();
                  if (v == 'delete') onDelete();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete', style: TextStyle(color: Color(0xFFE24B4A))),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sale.buyerName,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF222222)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${buyerTypeLabel(sale.buyerType)} · ${sale.quantity} ${sale.unitLabel}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF6B7770)),
                    ),
                    if (sale.paymentReference != null && sale.paymentReference!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Ref: ${sale.paymentReference}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF99A39B)),
                      ),
                    ],
                    if (sale.notes != null && sale.notes!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        sale.notes!,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF99A39B), fontStyle: FontStyle.italic),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                fmtCcy.format(sale.amountPaid),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF27500A)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, size: 36, color: Color(0xFFE24B4A)),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        const SizedBox(height: 12),
        FilledButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// LogSaleDialog — create or edit a sale
// ══════════════════════════════════════════════════════════════════════════

class LogSaleDialog extends StatefulWidget {
  const LogSaleDialog({
    super.key,
    required this.module,
    this.existing,
  });

  final String module;
  final ProductSale? existing;

  @override
  State<LogSaleDialog> createState() => _LogSaleDialogState();
}

class _LogSaleDialogState extends State<LogSaleDialog> {
  static const _primary = Color(0xFF27500A);

  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  late DateTime _saleDate;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _buyerNameCtrl;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _refCtrl;
  late final TextEditingController _notesCtrl;
  late String _buyerType;
  late String _paymentMode;

  bool get _isEdit => widget.existing != null;
  String get _unitLabel => widget.module == 'LAYERS' ? 'crates' : 'litres';

  static const _buyerTypes = [
    ('SCHOOL', 'School'),
    ('INDIVIDUAL', 'Individual'),
    ('ORGANIZATION', 'Organization'),
    ('HOTEL', 'Hotel'),
    ('DISTRIBUTOR', 'Distributor'),
    ('OTHER', 'Other'),
  ];

  static const _paymentModes = [
    ('CASH', 'Cash'),
    ('MPESA', 'M-Pesa'),
    ('BANK_TRANSFER', 'Bank Transfer'),
    ('CREDIT', 'Credit'),
    ('CHEQUE', 'Cheque'),
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _saleDate = e?.saleDate ?? DateTime.now();
    _qtyCtrl = TextEditingController(text: e != null ? _fmt(e.quantity) : '');
    _buyerNameCtrl = TextEditingController(text: e?.buyerName ?? '');
    _amountCtrl = TextEditingController(text: e != null ? e.amountPaid.toStringAsFixed(2) : '');
    _refCtrl = TextEditingController(text: e?.paymentReference ?? '');
    _notesCtrl = TextEditingController(text: e?.notes ?? '');
    _buyerType = e?.buyerType ?? 'SCHOOL';
    _paymentMode = e?.paymentMode ?? 'CASH';
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _buyerNameCtrl.dispose();
    _amountCtrl.dispose();
    _refCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  static String _fmt(num n) =>
      n == n.roundToDouble() ? n.toInt().toString() : n.toStringAsFixed(1);

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _saleDate,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null && mounted) setState(() => _saleDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final body = {
        'module': widget.module,
        'saleDate': _saleDate.toIso8601String(),
        'quantity': double.parse(_qtyCtrl.text.trim()),
        'buyerType': _buyerType,
        'buyerName': _buyerNameCtrl.text.trim(),
        'paymentMode': _paymentMode,
        'paymentReference': _refCtrl.text.trim().isEmpty ? null : _refCtrl.text.trim(),
        'amountPaid': double.parse(_amountCtrl.text.trim()),
        'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      };
      if (_isEdit) {
        await ApiService.updateSale(widget.existing!.id, body);
      } else {
        await ApiService.createSale(body);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEdit ? 'Edit Sale' : 'Log Sale';

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  children: [
                    const Text('💰', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 10),
                    Text(
                      title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _primary),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(false),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const Divider(height: 20),

                // Sale Date
                _label('Sale Date'),
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: _dec(suffixIcon: const Icon(Icons.calendar_month_outlined, size: 18)),
                    child: Text(
                      DateFormat('dd MMM yyyy').format(_saleDate),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Quantity + Buyer Type row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _label('Quantity ($_unitLabel)'),
                          TextFormField(
                            controller: _qtyCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                            decoration: _dec(hint: '0'),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Required';
                              if (double.tryParse(v.trim()) == null) return 'Invalid';
                              if (double.parse(v.trim()) <= 0) return 'Must be > 0';
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _label('Buyer Type'),
                          DropdownButtonFormField<String>(
                            initialValue: _buyerType,
                            decoration: _dec(),
                            isExpanded: true,
                            items: _buyerTypes
                                .map((t) => DropdownMenuItem(value: t.$1, child: Text(t.$2)))
                                .toList(),
                            onChanged: (v) => setState(() => _buyerType = v!),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Buyer name
                _label('Buyer Name'),
                TextFormField(
                  controller: _buyerNameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: _dec(hint: 'e.g. Kiambu High School'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Buyer name is required' : null,
                ),
                const SizedBox(height: 14),

                // Payment mode + Amount row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _label('Payment Mode'),
                          DropdownButtonFormField<String>(
                            initialValue: _paymentMode,
                            decoration: _dec(),
                            isExpanded: true,
                            items: _paymentModes
                                .map((t) => DropdownMenuItem(value: t.$1, child: Text(t.$2)))
                                .toList(),
                            onChanged: (v) => setState(() => _paymentMode = v!),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _label('Amount Paid (KES)'),
                          TextFormField(
                            controller: _amountCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                            decoration: _dec(hint: '0.00'),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Required';
                              if (double.tryParse(v.trim()) == null) return 'Invalid';
                              if (double.parse(v.trim()) < 0) return 'Must be ≥ 0';
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Payment reference
                _label('Payment Reference (optional)'),
                TextFormField(
                  controller: _refCtrl,
                  decoration: _dec(hint: 'M-Pesa code / bank ref / receipt no.'),
                ),
                const SizedBox(height: 14),

                // Notes
                _label('Notes (optional)'),
                TextFormField(
                  controller: _notesCtrl,
                  maxLines: 2,
                  decoration: _dec(hint: 'Partial payment, weekly delivery, repeat customer…'),
                ),
                const SizedBox(height: 20),

                // Save button
                FilledButton.icon(
                  onPressed: _saving ? null : _submit,
                  icon: _saving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check, size: 18),
                  label: Text(_saving ? 'Saving…' : (_isEdit ? 'Update Sale' : 'Record Sale')),
                  style: FilledButton.styleFrom(
                    backgroundColor: _primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6, left: 2),
        child: Text(
          text,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.4, color: Color(0xFF6B7770)),
        ),
      );

  static InputDecoration _dec({String? hint, Widget? suffixIcon}) {
    const radius = BorderRadius.all(Radius.circular(12));
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF99A39B)),
      suffixIcon: suffixIcon,
      isDense: true,
      filled: true,
      fillColor: const Color(0xFFF6F8F4),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: const OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: Color(0x14000000))),
      enabledBorder: const OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: Color(0x14000000))),
      focusedBorder: const OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: Color(0xFF27500A), width: 1.6)),
      errorBorder: const OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: Color(0xFFE24B4A))),
      focusedErrorBorder: const OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: Color(0xFFE24B4A), width: 1.6)),
    );
  }
}
