import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/models/feedlot.dart';
import '../../core/service/api_service.dart';
import '../../core/utils/sale_receipt_pdf.dart';

/// Sell a sheep (dooper) out of the flock. Mirrors SellBullDialog
/// but treats `soldWeightKg` as optional — lambs and culls aren't
/// always weighed at sale. Posts to /feedlot/sheep/:id/sell which
/// also writes a Revenue row (ANIMAL_SALES, unit Doopers) so the
/// finance cashflow ledger picks up the income in the same
/// transaction.
class SellDopperDialog extends StatefulWidget {
  const SellDopperDialog({super.key, required this.sheep});

  final SheepView sheep;

  @override
  State<SellDopperDialog> createState() => _SellDopperDialogState();
}

class _SellDopperDialogState extends State<SellDopperDialog> {
  final _formKey = GlobalKey<FormState>();
  final _buyerName = TextEditingController();
  final _buyerPhone = TextEditingController();
  final _saleWeight = TextEditingController();
  final _salePrice = TextEditingController();
  final _notes = TextEditingController();

  DateTime _saleDate = DateTime.now();
  PaymentMethod? _paymentMethod;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill the weight when one is recorded so the user can
    // confirm or adjust. Lambs often have no entry / current weight
    // — leave blank in that case.
    final w = widget.sheep.currentWeight ?? widget.sheep.entryWeight;
    if (w != null) _saleWeight.text = w.toString();
  }

  @override
  void dispose() {
    _buyerName.dispose();
    _buyerPhone.dispose();
    _saleWeight.dispose();
    _salePrice.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _saleDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null && mounted) setState(() => _saleDate = picked);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _submitting = true);
    try {
      final salePrice = double.parse(_salePrice.text);
      final weightText = _saleWeight.text.trim();
      final soldWeightKg = weightText.isEmpty ? null : double.parse(weightText);

      await ApiService.sellSheep(widget.sheep.id, {
        'saleDate': _saleDate.toIso8601String(),
        if (soldWeightKg != null) 'soldWeightKg': soldWeightKg,
        'salePrice': salePrice,
        'buyerName': _buyerName.text.trim(),
        'buyerPhone':
            _buyerPhone.text.trim().isEmpty ? null : _buyerPhone.text.trim(),
        'paymentMethod': _paymentMethod?.wire,
        'saleNotes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      });
      if (!mounted) return;
      Navigator.of(context).pop(true);
      previewSaleReceipt(SaleReceiptData(
        kind: widget.sheep.category.label, // "Ewe" / "Ram" / "Lamb"
        animalTag: widget.sheep.tag,
        saleDate: _saleDate,
        salePrice: salePrice,
        soldWeightKg: soldWeightKg,
        buyerName: _buyerName.text.trim(),
        buyerPhone:
            _buyerPhone.text.trim().isEmpty ? null : _buyerPhone.text.trim(),
        paymentMethod: _paymentMethod?.wire,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('EEE, MMM d, y');
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.point_of_sale, color: Color(0xFF2E7D32), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Sell ${widget.sheep.tag}'
              ' (${widget.sheep.category.label.toLowerCase()})',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF3DE),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'A PDF receipt is generated automatically after save '
                    'and a matching Revenue entry is posted to the finance '
                    'cashflow ledger (unit: Doopers).',
                    style: TextStyle(fontSize: 11, color: Color(0xFF27500A)),
                  ),
                ),
                const SizedBox(height: 14),
                _row([
                  _field('BUYER NAME *', TextFormField(
                    controller: _buyerName,
                    enabled: !_submitting,
                    decoration: _inputDec(hint: 'e.g. John Mwangi'),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Buyer name is required'
                        : null,
                  )),
                  _field('BUYER PHONE', TextFormField(
                    controller: _buyerPhone,
                    enabled: !_submitting,
                    keyboardType: TextInputType.phone,
                    decoration: _inputDec(hint: '07XX XXX XXX'),
                  )),
                ]),
                const SizedBox(height: 14),
                _row([
                  _field('SALE DATE', InkWell(
                    onTap: _submitting ? null : _pickDate,
                    child: InputDecorator(
                      decoration: _inputDec(),
                      child: Row(
                        children: [
                          Expanded(child: Text(fmt.format(_saleDate))),
                          const Icon(Icons.event, size: 18, color: Colors.black54),
                        ],
                      ),
                    ),
                  )),
                  _field(
                    'PAYMENT METHOD',
                    DropdownButtonFormField<PaymentMethod>(
                      initialValue: _paymentMethod,
                      isExpanded: true,
                      decoration: _inputDec(),
                      items: [
                        for (final p in PaymentMethod.values)
                          DropdownMenuItem(value: p, child: Text(p.label)),
                      ],
                      onChanged: _submitting
                          ? null
                          : (v) => setState(() => _paymentMethod = v),
                    ),
                  ),
                ]),
                const SizedBox(height: 14),
                _row([
                  _field('SALE WEIGHT (KG)', TextFormField(
                    controller: _saleWeight,
                    enabled: !_submitting,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    decoration: _inputDec(hint: 'Optional — e.g. 32'),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      final n = double.tryParse(v);
                      if (n == null || n <= 0 || n > 500) {
                        return 'Must be 0-500';
                      }
                      return null;
                    },
                  )),
                  _field('SALE PRICE *', TextFormField(
                    controller: _salePrice,
                    enabled: !_submitting,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    decoration: _inputDec(hint: 'KES'),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      final n = double.tryParse(v);
                      if (n == null || n <= 0) return 'Must be > 0';
                      return null;
                    },
                  )),
                ]),
                const SizedBox(height: 14),
                _label('NOTES'),
                TextFormField(
                  controller: _notes,
                  enabled: !_submitting,
                  maxLines: 3,
                  decoration: _inputDec(
                    hint: 'Optional — buyer reference, condition, etc.',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              _submitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
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
              : const Icon(Icons.receipt_long, size: 16),
          label: const Text('Record sale & receipt'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF2E7D32),
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _row(List<Widget> children) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            Expanded(child: children[i]),
            if (i < children.length - 1) const SizedBox(width: 12),
          ],
        ],
      );

  Widget _field(String label, Widget child) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [_label(label), child],
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            color: Colors.black54,
          ),
        ),
      );

  InputDecoration _inputDec({String? hint}) => InputDecoration(
        hintText: hint,
        isDense: true,
        filled: true,
        fillColor: const Color(0xFFEFEDE6),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        hintStyle: const TextStyle(fontSize: 13, color: Colors.black45),
      );
}
