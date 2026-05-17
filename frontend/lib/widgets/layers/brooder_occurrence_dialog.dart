import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/models/brooder.dart';
import '../../core/service/api_service.dart';
import '../../core/utils/image_picker_helper.dart';

/// Log an incident on a brooder cycle. Posts to
/// /api/layers/brooder/occurrences. Reporter is taken from the JWT
/// server-side, not the body.
class BrooderOccurrenceDialog extends StatefulWidget {
  const BrooderOccurrenceDialog({
    super.key,
    required this.brooderId,
    required this.brooderLabel,
  });

  final String brooderId;
  final String brooderLabel;

  @override
  State<BrooderOccurrenceDialog> createState() =>
      _BrooderOccurrenceDialogState();
}

class _BrooderOccurrenceDialogState extends State<BrooderOccurrenceDialog> {
  final _formKey = GlobalKey<FormState>();
  final _numberAffected = TextEditingController(text: '0');
  final _description = TextEditingController();
  final _action = TextEditingController();

  BrooderOccurrenceType? _type;
  BrooderOccurrenceSeverity _severity = BrooderOccurrenceSeverity.low;
  DateTime _occurredAt = DateTime.now();
  bool _followUpNeeded = false;
  Uint8List? _pendingBytes;
  String? _pendingFilename;
  String? _pendingContentType;
  String? _imageUrl;
  bool _uploadingImage = false;
  bool _submitting = false;

  @override
  void dispose() {
    _numberAffected.dispose();
    _description.dispose();
    _action.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_occurredAt),
    );
    if (!mounted) return;
    setState(() {
      _occurredAt = DateTime(
        picked.year,
        picked.month,
        picked.day,
        time?.hour ?? _occurredAt.hour,
        time?.minute ?? _occurredAt.minute,
      );
    });
  }

  Future<void> _pickImage() async {
    final picked = await pickCowImage(context);
    if (picked == null || !mounted) return;
    setState(() {
      _pendingBytes = picked.bytes;
      _pendingFilename = picked.filename;
      _pendingContentType = picked.contentType;
      _imageUrl = null;
    });
  }

  Future<bool> _uploadImageIfNeeded() async {
    if (_pendingBytes == null) return true;
    setState(() => _uploadingImage = true);
    try {
      final url = await ApiService.uploadCowImage(
        bytes: _pendingBytes!,
        filename: _pendingFilename ?? 'occurrence.jpg',
        contentType: _pendingContentType ?? 'image/jpeg',
      );
      setState(() {
        _imageUrl = url;
        _pendingBytes = null;
        _uploadingImage = false;
      });
      return true;
    } catch (e) {
      if (!mounted) return false;
      setState(() => _uploadingImage = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Image upload failed: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
      return false;
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!await _uploadImageIfNeeded()) return;

    setState(() => _submitting = true);
    try {
      await ApiService.logBrooderOccurrence({
        'brooderId': widget.brooderId,
        'type': _type!.wire,
        'severity': _severity.wire,
        'occurredAt': _occurredAt.toIso8601String(),
        'numberAffected': int.tryParse(_numberAffected.text) ?? 0,
        'description': _description.text.trim().isEmpty
            ? null
            : _description.text.trim(),
        'actionTaken':
            _action.text.trim().isEmpty ? null : _action.text.trim(),
        'imageUrl': _imageUrl,
        'followUpNeeded': _followUpNeeded,
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
    final fmt = DateFormat('EEE, MMM d • HH:mm');
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.report_outlined, color: Color(0xFF854F0B), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Log occurrence — ${widget.brooderLabel}',
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
                _label('OCCURRENCE TYPE *'),
                DropdownButtonFormField<BrooderOccurrenceType>(
                  initialValue: _type,
                  isExpanded: true,
                  decoration: _inputDec(),
                  items: [
                    for (final t in BrooderOccurrenceType.values)
                      DropdownMenuItem(value: t, child: Text(t.label)),
                  ],
                  onChanged: _submitting
                      ? null
                      : (v) => setState(() => _type = v),
                  validator: (v) => v == null ? 'Type is required' : null,
                ),
                const SizedBox(height: 14),
                _row([
                  _field('DATE & TIME', InkWell(
                    onTap: _submitting ? null : _pickDate,
                    child: InputDecorator(
                      decoration: _inputDec(),
                      child: Row(
                        children: [
                          Expanded(child: Text(fmt.format(_occurredAt))),
                          const Icon(Icons.event, size: 18, color: Colors.black54),
                        ],
                      ),
                    ),
                  )),
                  _field('SEVERITY', DropdownButtonFormField<BrooderOccurrenceSeverity>(
                    initialValue: _severity,
                    isExpanded: true,
                    decoration: _inputDec(),
                    items: [
                      for (final s in BrooderOccurrenceSeverity.values)
                        DropdownMenuItem(value: s, child: Text(s.label)),
                    ],
                    onChanged: _submitting
                        ? null
                        : (v) => setState(() => _severity = v ?? _severity),
                  )),
                ]),
                const SizedBox(height: 14),
                _label('NUMBER AFFECTED'),
                TextFormField(
                  controller: _numberAffected,
                  enabled: !_submitting,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: _inputDec(hint: '0'),
                ),
                const SizedBox(height: 14),
                _label('DESCRIPTION'),
                TextFormField(
                  controller: _description,
                  enabled: !_submitting,
                  maxLines: 3,
                  decoration: _inputDec(hint: 'What happened? Symptoms, scale, where it was observed…'),
                ),
                const SizedBox(height: 14),
                _label('ACTION TAKEN'),
                TextFormField(
                  controller: _action,
                  enabled: !_submitting,
                  maxLines: 2,
                  decoration: _inputDec(hint: 'Optional — what was done immediately'),
                ),
                const SizedBox(height: 8),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _followUpNeeded,
                  title: const Text(
                    'Follow-up needed',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Flag for vet / manager review',
                    style: TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                  onChanged: _submitting
                      ? null
                      : (v) => setState(() => _followUpNeeded = v),
                ),
                _label('ATTACH IMAGE'),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _submitting ? null : _pickImage,
                        icon: const Icon(Icons.attach_file, size: 16),
                        label: Text(
                          _pendingBytes != null || _imageUrl != null
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
                if (_uploadingImage)
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
              : const Icon(Icons.check, size: 16),
          label: const Text('Log occurrence'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF854F0B),
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
