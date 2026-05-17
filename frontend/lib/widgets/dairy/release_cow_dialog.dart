import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/cow.dart';
import '../../core/service/api_service.dart';
import '../../core/utils/image_picker_helper.dart';

/// Release a cow from the active herd. The dialog gathers release
/// type + date + destination + reason + optional document image,
/// then posts to /dairy/cows/tag/:tag/release. authorizedBy is set
/// server-side from the JWT — not collected here.
class ReleaseCowDialog extends StatefulWidget {
  const ReleaseCowDialog({super.key, required this.cow});

  final Cow cow;

  @override
  State<ReleaseCowDialog> createState() => _ReleaseCowDialogState();
}

class _ReleaseCowDialogState extends State<ReleaseCowDialog> {
  final _formKey = GlobalKey<FormState>();
  final _destination = TextEditingController();
  final _reason = TextEditingController();

  CowReleaseType? _type;
  DateTime _date = DateTime.now();
  Uint8List? _pendingBytes;
  String? _pendingFilename;
  String? _pendingContentType;
  String? _documentUrl;
  bool _uploadingDoc = false;
  bool _submitting = false;

  @override
  void dispose() {
    _destination.dispose();
    _reason.dispose();
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

  Future<void> _pickDocument() async {
    final picked = await pickCowImage(context);
    if (picked == null || !mounted) return;
    setState(() {
      _pendingBytes = picked.bytes;
      _pendingFilename = picked.filename;
      _pendingContentType = picked.contentType;
      _documentUrl = null;
    });
  }

  Future<bool> _uploadDocIfNeeded() async {
    if (_pendingBytes == null) return true;
    setState(() => _uploadingDoc = true);
    try {
      final url = await ApiService.uploadCowImage(
        bytes: _pendingBytes!,
        filename: _pendingFilename ?? 'release.jpg',
        contentType: _pendingContentType ?? 'image/jpeg',
      );
      setState(() {
        _documentUrl = url;
        _pendingBytes = null;
        _uploadingDoc = false;
      });
      return true;
    } catch (e) {
      if (!mounted) return false;
      setState(() => _uploadingDoc = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: ${e.toString().replaceFirst('Exception: ', '')}')),
      );
      return false;
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!await _uploadDocIfNeeded()) return;

    setState(() => _submitting = true);
    try {
      await ApiService.releaseCow(widget.cow.tag, {
        'releaseType': _type!.wire,
        'releaseDate': _date.toIso8601String(),
        'destination': _destination.text.trim().isEmpty
            ? null
            : _destination.text.trim(),
        'reason': _reason.text.trim().isEmpty ? null : _reason.text.trim(),
        'documentUrl': _documentUrl,
      });
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
    final fmt = DateFormat('EEE, MMM d, y');
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.exit_to_app, color: Color(0xFFB42318), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Release ${widget.cow.tag}'
              '${widget.cow.nickname != null ? ' (${widget.cow.nickname})' : ''}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 460,
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
                    color: const Color(0xFFFFF4F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0x33B42318)),
                  ),
                  child: const Text(
                    'This cow will be removed from the active herd. Milk and reproduction history is retained for reports.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF7A2A1F)),
                  ),
                ),
                const SizedBox(height: 16),
                _label('RELEASE TYPE *'),
                DropdownButtonFormField<CowReleaseType>(
                  initialValue: _type,
                  isExpanded: true,
                  decoration: _inputDec(),
                  items: [
                    for (final t in CowReleaseType.values)
                      DropdownMenuItem(value: t, child: Text(t.label)),
                  ],
                  onChanged: _submitting
                      ? null
                      : (v) => setState(() => _type = v),
                  validator: (v) => v == null ? 'Release type is required' : null,
                ),
                const SizedBox(height: 14),
                _label('RELEASE DATE'),
                InkWell(
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
                const SizedBox(height: 14),
                _label('DESTINATION'),
                TextFormField(
                  controller: _destination,
                  enabled: !_submitting,
                  decoration: _inputDec(hint: 'e.g. Kiambu Market, Mr. Karuga'),
                ),
                const SizedBox(height: 14),
                _label('REASON / NOTES'),
                TextFormField(
                  controller: _reason,
                  enabled: !_submitting,
                  maxLines: 3,
                  decoration: _inputDec(hint: 'Optional context for the records'),
                ),
                const SizedBox(height: 14),
                _label('ATTACH DOCUMENT'),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _submitting ? null : _pickDocument,
                        icon: const Icon(Icons.attach_file, size: 16),
                        label: Text(
                          _pendingBytes != null
                              ? 'Replace photo'
                              : _documentUrl != null
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
                if (_uploadingDoc)
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
          label: const Text('Release cow'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFB42318),
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

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
