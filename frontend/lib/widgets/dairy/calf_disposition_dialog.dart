import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/dairy_ops.dart';
import '../../core/service/api_service.dart';
import '../../core/utils/sale_receipt_pdf.dart';

/// "Record Disposition / Release" dialog for a calf — same layout as
/// the cow flow, but talks to /api/dairy/calves/:id/dispose and the
/// disposition type list is calf-appropriate (no "slaughtered" — that
/// would normally route through the feedlot transfer instead).
class CalfDispositionDialog extends StatefulWidget {
  const CalfDispositionDialog({super.key, required this.calf});

  final CalfRecord calf;

  @override
  State<CalfDispositionDialog> createState() => _CalfDispositionDialogState();
}

class _CalfDispositionDialogState extends State<CalfDispositionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _party = TextEditingController();
  final _amount = TextEditingController();
  final _receipt = TextEditingController();
  final _witness = TextEditingController();
  final _notes = TextEditingController();

  static const _options = <_DispOption>[
    _DispOption('SOLD_CASH', '💰 Sold (cash)', isSale: true),
    _DispOption('SOLD_CREDIT', '💳 Sold (credit / on account)', isSale: true),
    _DispOption('DIED', '⚰ Died (natural / illness)'),
    _DispOption('TRANSFERRED_OUT', '➡ Transferred out of farm'),
    _DispOption('TRANSFERRED_IN', '⬇ Transferred between units'),
    _DispOption('LOST', '❓ Lost (theft / missing / escaped)'),
  ];

  _DispOption _type = _options.first;
  DateTime _date = DateTime.now();
  bool _submitting = false;

  @override
  void dispose() {
    _party.dispose();
    _amount.dispose();
    _receipt.dispose();
    _witness.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 2)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final amount = num.tryParse(_amount.text.trim()) ?? 0;

    setState(() => _submitting = true);
    try {
      await ApiService.disposeCalf(widget.calf.id, {
        'type': _type.code,
        'date': _date.toIso8601String(),
        'party': _party.text.trim().isEmpty ? null : _party.text.trim(),
        'amount': amount,
        'receipt': _receipt.text.trim().isEmpty ? null : _receipt.text.trim(),
        'witness': _witness.text.trim().isEmpty ? null : _witness.text.trim(),
        'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      });

      // For any sale, auto-generate the PDF receipt locally — same
      // utility the feedlot Sell Bull / Sell Dopper flows use.
      if (_type.isSale) {
        await previewSaleReceipt(SaleReceiptData(
          kind: 'Calf',
          animalTag: widget.calf.calfTag ?? '—',
          saleDate: _date,
          salePrice: amount,
          buyerName: _party.text.trim(),
          paymentMethod: _type.code == 'SOLD_CASH' ? 'CASH' : 'CREDIT',
          notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          recordedBy: _witness.text.trim().isEmpty
              ? null
              : _witness.text.trim(),
        ));
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', '').replaceFirst('ApiException(', ''),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy');
    final isMobile = MediaQuery.of(context).size.width < 560;
    final c = widget.calf;
    final entityId = c.calfTag ?? '—';
    final entityLabel = c.calf?.nickname ?? entityId;
    final entityLocation =
        c.calf?.houseName ?? c.dam?.houseName ?? 'Maternity';

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '📋  Record Disposition / Release',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF27500A),
                  ),
                ),
                const SizedBox(height: 6),
                const Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'Captures the end-of-cycle event for this entity. Record stays in the system as ',
                      ),
                      TextSpan(
                        text: 'disposed',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      TextSpan(text: ', with this receipt attached.'),
                    ],
                  ),
                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7770), height: 1.4),
                ),
                const SizedBox(height: 16),

                // Entity card — mirrors the cow flow but shows "calf"
                // and uses the dam's house as a fallback location.
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F8F4),
                    borderRadius: BorderRadius.circular(10),
                    border: const Border(
                      left: BorderSide(color: Color(0xFF27500A), width: 3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ENTITY BEING RELEASED',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: Color(0xFF99A39B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 18,
                        runSpacing: 8,
                        children: [
                          _kv('Type', 'calf'),
                          _kv('ID', entityId, mono: true),
                          _kv('Name / label', entityLabel),
                          _kv('Current location', entityLocation),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                _Row2(
                  isMobile: isMobile,
                  left: _field(
                    label: 'DISPOSITION TYPE *',
                    child: DropdownButtonFormField<_DispOption>(
                      initialValue: _type,
                      isExpanded: true,
                      decoration: _inputDec(),
                      items: [
                        for (final o in _options)
                          DropdownMenuItem(value: o, child: Text(o.label)),
                      ],
                      onChanged: _submitting
                          ? null
                          : (v) => setState(() => _type = v ?? _options.first),
                    ),
                  ),
                  right: _field(
                    label: 'DATE *',
                    child: InkWell(
                      onTap: _submitting ? null : _pickDate,
                      child: InputDecorator(
                        decoration: _inputDec(),
                        child: Row(
                          children: [
                            Expanded(child: Text(fmt.format(_date))),
                            const Icon(Icons.event, size: 18, color: Colors.black54),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                _Row2(
                  isMobile: isMobile,
                  left: _field(
                    label: 'BUYER / BUTCHER / COUNTERPARTY',
                    child: TextFormField(
                      controller: _party,
                      enabled: !_submitting,
                      decoration: _inputDec(
                        hint: 'e.g. John Mwangi (cash) / Farmers Choice / Local butcher',
                      ),
                      validator: (v) {
                        if (_type.isSale && (v == null || v.trim().isEmpty)) {
                          return 'Buyer name is required for sales';
                        }
                        return null;
                      },
                    ),
                  ),
                  right: _field(
                    label: 'AMOUNT (KSH) — 0 IF FREE / N/A',
                    child: TextFormField(
                      controller: _amount,
                      enabled: !_submitting,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: false),
                      decoration: _inputDec(hint: '80000'),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                _field(
                  label: 'RECEIPT / DOCUMENT REFERENCE *',
                  child: TextFormField(
                    controller: _receipt,
                    enabled: !_submitting,
                    decoration: _inputDec(
                      hint:
                          'e.g. Receipt #001234 / FC waybill / M-Pesa ref / handwritten note saved in folder',
                    ),
                    validator: (v) {
                      final hasAmount =
                          (num.tryParse(_amount.text.trim()) ?? 0) > 0;
                      if (_type.isSale &&
                          hasAmount &&
                          (v == null || v.trim().isEmpty)) {
                        return 'Receipt reference is required for cash sales';
                      }
                      return null;
                    },
                  ),
                  hint:
                      'Required for cash sales. Be specific — this becomes the audit trail.',
                ),
                const SizedBox(height: 14),

                _Row2(
                  isMobile: isMobile,
                  left: _field(
                    label: 'WITNESSED BY',
                    child: TextFormField(
                      controller: _witness,
                      enabled: !_submitting,
                      decoration: _inputDec(
                        hint: 'Vet / second manager / family member',
                      ),
                    ),
                  ),
                  right: _field(
                    label: 'NOTES',
                    child: TextFormField(
                      controller: _notes,
                      enabled: !_submitting,
                      decoration: _inputDec(
                        hint:
                            'Brief context — cause of death, why sold, condition at sale, etc.',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAEEDA),
                    borderRadius: BorderRadius.circular(8),
                    border: const Border(
                      left: BorderSide(color: Color(0xFFAC7B0F), width: 3),
                    ),
                  ),
                  child: const Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '⚠ Important: ',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        TextSpan(
                          text:
                              'Once you save this, the record is locked into the audit log. The entity stays in the system (marked as ',
                        ),
                        TextSpan(
                          text: 'disposed',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        TextSpan(
                          text:
                              ') so reports can still reference it. You can ',
                        ),
                        TextSpan(
                          text: 'not',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        TextSpan(
                          text:
                              ' undo this — a PDF receipt is auto-generated for sales so the digital record always matches the paper trail.',
                        ),
                      ],
                    ),
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7770),
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _submitting
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _submitting ? null : _submit,
                      icon: _submitting
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check, size: 16),
                      label: const Text('Record disposition'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF27500A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 12),
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _kv(String label, String value, {bool mono = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Color(0xFF99A39B)),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            fontFamily: mono ? 'monospace' : null,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _field({required String label, required Widget child, String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: Color(0xFF6B7770),
            ),
          ),
        ),
        child,
        if (hint != null) ...[
          const SizedBox(height: 4),
          Text(
            hint,
            style: const TextStyle(fontSize: 11, color: Color(0xFF99A39B)),
          ),
        ],
      ],
    );
  }

  InputDecoration _inputDec({String? hint}) => InputDecoration(
        hintText: hint,
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0x22000000)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF27500A), width: 1.5),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0x22000000)),
        ),
        hintStyle: const TextStyle(fontSize: 12, color: Colors.black38),
      );
}

class _DispOption {
  const _DispOption(this.code, this.label, {this.isSale = false});
  final String code;
  final String label;
  final bool isSale;
}

class _Row2 extends StatelessWidget {
  const _Row2({
    required this.left,
    required this.right,
    required this.isMobile,
  });
  final Widget left;
  final Widget right;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [left, const SizedBox(height: 14), right],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 14),
        Expanded(child: right),
      ],
    );
  }
}
