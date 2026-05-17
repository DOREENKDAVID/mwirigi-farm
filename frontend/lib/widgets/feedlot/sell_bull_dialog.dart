import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/models/feedlot.dart';
import '../../core/service/api_service.dart';
import '../../core/utils/image_picker_helper.dart';

/// Sell a bull out of the feedlot. Captures buyer + price + weight
/// and an optional receipt photo, then posts to
/// /feedlot/bulls/:id/sell. The bull falls out of listBulls once the
/// sale is recorded (server filters on soldAt = null).
class SellBullDialog extends StatefulWidget {
  const SellBullDialog({super.key, required this.bull});

  final BullView bull;

  @override
  State<SellBullDialog> createState() => _SellBullDialogState();
}

class _SellBullDialogState extends State<SellBullDialog> {
  final _formKey = GlobalKey<FormState>();
  final _buyerName = TextEditingController();
  final _buyerPhone = TextEditingController();
  final _saleWeight = TextEditingController();
  final _salePrice = TextEditingController();
  final _notes = TextEditingController();

  DateTime _saleDate = DateTime.now();
  PaymentMethod? _paymentMethod;
  Uint8List? _pendingBytes;
  String? _pendingFilename;
  String? _pendingContentType;
  String? _receiptUrl;
  bool _uploadingReceipt = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill sale weight with the current weight so the user can confirm
    // or adjust at the time of sale.
    _saleWeight.text = widget.bull.currentWeight.toString();
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

  Future<void> _pickReceipt() async {
    final picked = await pickCowImage(context);
    if (picked == null || !mounted) return;
    setState(() {
      _pendingBytes = picked.bytes;
      _pendingFilename = picked.filename;
      _pendingContentType = picked.contentType;
      _receiptUrl = null;
    });
  }

  Future<bool> _uploadReceiptIfNeeded() async {
    if (_pendingBytes == null) return true;
    setState(() => _uploadingReceipt = true);
    try {
      final url = await ApiService.uploadCowImage(
        bytes: _pendingBytes!,
        filename: _pendingFilename ?? 'receipt.jpg',
        contentType: _pendingContentType ?? 'image/jpeg',
      );
      setState(() {
        _receiptUrl = url;
        _pendingBytes = null;
        _uploadingReceipt = false;
      });
      return true;
    } catch (e) {
      if (!mounted) return false;
      setState(() => _uploadingReceipt = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: ${e.toString().replaceFirst('Exception: ', '')}')),
      );
      return false;
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!await _uploadReceiptIfNeeded()) return;

    setState(() => _submitting = true);
    try {
      await ApiService.sellBull(widget.bull.id, {
        'saleDate': _saleDate.toIso8601String(),
        'soldWeightKg': double.parse(_saleWeight.text),
        'salePrice': double.parse(_salePrice.text),
        'buyerName': _buyerName.text.trim(),
        'buyerPhone':
            _buyerPhone.text.trim().isEmpty ? null : _buyerPhone.text.trim(),
        'paymentMethod': _paymentMethod?.wire,
        'saleNotes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        'receiptUrl': _receiptUrl,
      });
      if (!mounted) return;
      Navigator.of(context).pop(true);
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
              'Sell ${widget.bull.tag}',
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
                  _field('PAYMENT METHOD', DropdownButtonFormField<PaymentMethod>(
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
                  )),
                ]),
                const SizedBox(height: 14),
                _row([
                  _field('SALE WEIGHT (KG) *', TextFormField(
                    controller: _saleWeight,
                    enabled: !_submitting,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                    decoration: _inputDec(hint: 'e.g. 480'),
                    validator: _validatePositive,
                  )),
                  _field('SALE PRICE *', TextFormField(
                    controller: _salePrice,
                    enabled: !_submitting,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                    decoration: _inputDec(hint: 'KES'),
                    validator: _validatePositive,
                  )),
                ]),
                const SizedBox(height: 14),
                _label('NOTES'),
                TextFormField(
                  controller: _notes,
                  enabled: !_submitting,
                  maxLines: 3,
                  decoration: _inputDec(hint: 'Optional — buyer reference, condition, etc.'),
                ),
                const SizedBox(height: 14),
                _label('ATTACH RECEIPT'),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _submitting ? null : _pickReceipt,
                        icon: const Icon(Icons.attach_file, size: 16),
                        label: Text(
                          _pendingBytes != null || _receiptUrl != null
                              ? 'Replace photo'
                              : 'Take or choose photo',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                    if (_pendingBytes != null) ...[
                      const SizedBox(width: 10),
                      Container(
                        width: 40,
                        height: 40,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0x33000000)),
                        ),
                        child: Image.memory(_pendingBytes!, fit: BoxFit.cover),
                      ),
                    ],
                  ],
                ),
                if (_uploadingReceipt)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _submitting ? null : _submit,
          icon: _submitting
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.check, size: 16),
          label: const Text('Record sale'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF2E7D32),
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  String? _validatePositive(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    final n = double.tryParse(v);
    if (n == null || n <= 0) return 'Must be > 0';
    return null;
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
