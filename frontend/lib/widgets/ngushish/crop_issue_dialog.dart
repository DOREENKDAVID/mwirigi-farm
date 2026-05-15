// Crop issue reporting dialog. Replaces the previous animal-health
// `ReportSickDialog` for the Ngusishi (crops) module.
//
// Persistence: the new fields are encoded as a timestamped JSON-ish
// block appended to the affected crop's `notes` via PATCH
// /api/ngushish/crops/:id — works today without backend changes and
// surfaces inside the existing crop register actions cell.

import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/ngushish.dart';
import '../../core/service/api_service.dart';

class CropIssueDialog extends StatefulWidget {
  const CropIssueDialog({
    super.key,
    required this.blocks,
    this.initialBlock,
  });

  /// All registered crops — used to populate the block + crop dropdowns
  /// so issues are always tied to a real CropView row.
  final List<CropView> blocks;

  /// Pre-selects this block when launched from a per-row action.
  final CropView? initialBlock;

  @override
  State<CropIssueDialog> createState() => _CropIssueDialogState();
}

class _CropIssueDialogState extends State<CropIssueDialog> {
  static const _primary = Color(0xFF27500A);

  static const _issueTypes = [
    'Pest',
    'Disease',
    'Nutrient deficiency',
    'Irrigation problem',
    'Weed infestation',
    'Harvest delay',
    'Equipment issue',
    'Labour issue',
    'Weather damage',
    'Other',
  ];

  static const _severities = [
    ('LOW', '🟢 Low'),
    ('MEDIUM', '🟡 Medium'),
    ('HIGH', '🟠 High'),
    ('CRITICAL', '🔴 Critical'),
  ];

  static const _statuses = ['Open', 'Monitoring', 'In progress', 'Resolved'];

  final _formKey = GlobalKey<FormState>();
  final _actionController = TextEditingController();
  final _notesController = TextEditingController();

  CropView? _block;
  String? _issueType;
  String _severity = 'MEDIUM';
  String _status = 'Open';
  DateTime _dateDetected = DateTime.now();
  String? _assignedWorker;

  // Workers pulled async from /dairy/workers (shared list across modules
  // until a per-unit roster endpoint exists).
  List<String> _workers = const [];
  bool _loadingWorkers = true;

  // Photo (optional) — base64-encoded into the notes payload on submit.
  Uint8ListPicked? _photo;

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _block = widget.initialBlock ??
        (widget.blocks.isNotEmpty ? widget.blocks.first : null);
    _loadWorkers();
  }

  @override
  void dispose() {
    _actionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadWorkers() async {
    try {
      final raw = await ApiService.getDairyWorkers();
      final names = raw
          .whereType<Map>()
          .map((m) => (m['name'] ?? m['fullName'] ?? '').toString())
          .where((s) => s.isNotEmpty)
          .toList();
      if (!mounted) return;
      setState(() {
        _workers = names;
        _loadingWorkers = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingWorkers = false);
    }
  }

  Future<void> _pickPhoto() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final f = result.files.first;
    if (f.bytes == null) return;
    final ext = (f.extension ?? '').toLowerCase();
    final mime = switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
    setState(() {
      _photo = Uint8ListPicked(
        bytes: f.bytes!,
        filename: f.name,
        mime: mime,
      );
    });
  }

  Future<void> _submit() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;
    if (_block == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select an affected block')),
      );
      return;
    }
    setState(() => _submitting = true);

    final entry = <String, dynamic>{
      'kind': 'ISSUE',
      'issueType': _issueType,
      'severity': _severity,
      'status': _status,
      'dateDetected': _dateDetected.toIso8601String(),
      'assignedWorker': _assignedWorker,
      'actionRequired': _actionController.text.trim(),
      'notes': _notesController.text.trim(),
      'reportedAt': DateTime.now().toIso8601String(),
      if (_photo != null)
        'photo': 'data:${_photo!.mime};base64,${base64Encode(_photo!.bytes)}',
    };

    // Append the issue as a JSON-encoded line so a future migration can
    // parse the history back into a real Issue model.
    final prev = (_block!.notes ?? '').trim();
    final stamp = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());
    final line = '[$stamp] ${jsonEncode(entry)}';
    final merged = prev.isEmpty ? line : '$prev\n$line';

    // Urgent severity bubbles up to actionNote so it appears in red on
    // the register's "Notes & actions" column.
    final urgent =
        _severity == 'HIGH' || _severity == 'CRITICAL' || _status == 'Open';
    final actionNote = urgent
        ? '${_issueType ?? 'Issue'} (${_severity.toLowerCase()}) — '
            '${_actionController.text.trim().isEmpty ? "investigate" : _actionController.text.trim()}'
        : _block!.actionNote;

    try {
      await ApiService.updateNgushishCrop(_block!.id, {
        'notes': merged,
        if (actionNote != null) 'actionNote': actionNote,
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
    final dateFmt = DateFormat('dd/MM/yyyy');
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Text('🌿', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Report Crop Issue',
                        style: TextStyle(
                          color: _primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Logs against the selected block. History is preserved '
                  "in the block's notes so it shows up under the register.",
                  style: TextStyle(fontSize: 12, color: Color(0xFF7A7A7A)),
                ),
                const SizedBox(height: 18),
                _TwoCol(
                  left: _Field(
                    label: 'AFFECTED BLOCK *',
                    child: DropdownButtonFormField<CropView>(
                      initialValue: _block,
                      isExpanded: true,
                      decoration: _decoration(),
                      items: [
                        for (final b in widget.blocks)
                          DropdownMenuItem(
                            value: b,
                            child: Text(
                              '${b.block ?? "—"} · ${b.name}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: _submitting
                          ? null
                          : (v) => setState(() => _block = v),
                      validator: (v) => v == null ? 'Required' : null,
                    ),
                  ),
                  right: _Field(
                    label: 'CROP',
                    child: TextFormField(
                      enabled: false,
                      controller: TextEditingController(
                          text: _block?.name ?? '—'),
                      decoration: _decoration(),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _TwoCol(
                  left: _Field(
                    label: 'ISSUE TYPE *',
                    child: DropdownButtonFormField<String>(
                      initialValue: _issueType,
                      isExpanded: true,
                      decoration: _decoration(hint: '— select —'),
                      items: [
                        for (final t in _issueTypes)
                          DropdownMenuItem(value: t, child: Text(t)),
                      ],
                      onChanged: _submitting
                          ? null
                          : (v) => setState(() => _issueType = v),
                      validator: (v) => v == null ? 'Required' : null,
                    ),
                  ),
                  right: _Field(
                    label: 'SEVERITY *',
                    child: DropdownButtonFormField<String>(
                      initialValue: _severity,
                      isExpanded: true,
                      decoration: _decoration(),
                      items: [
                        for (final (wire, label) in _severities)
                          DropdownMenuItem(value: wire, child: Text(label)),
                      ],
                      onChanged: _submitting
                          ? null
                          : (v) => setState(() => _severity = v ?? _severity),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _TwoCol(
                  left: _Field(
                    label: 'DATE DETECTED *',
                    child: _DatePickerField(
                      value: _dateDetected,
                      enabled: !_submitting,
                      format: dateFmt,
                      onPick: (d) => setState(() => _dateDetected = d),
                    ),
                  ),
                  right: _Field(
                    label: 'STATUS *',
                    child: DropdownButtonFormField<String>(
                      initialValue: _status,
                      isExpanded: true,
                      decoration: _decoration(),
                      items: [
                        for (final s in _statuses)
                          DropdownMenuItem(value: s, child: Text(s)),
                      ],
                      onChanged: _submitting
                          ? null
                          : (v) => setState(() => _status = v ?? _status),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _Field(
                  label: 'ASSIGNED WORKER',
                  child: DropdownButtonFormField<String>(
                    initialValue: _assignedWorker,
                    isExpanded: true,
                    decoration: _decoration(
                      hint: _loadingWorkers ? 'Loading…' : '— select —',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Unassigned'),
                      ),
                      for (final w in _workers)
                        DropdownMenuItem(value: w, child: Text(w)),
                    ],
                    onChanged: _submitting
                        ? null
                        : (v) => setState(() => _assignedWorker = v),
                  ),
                ),
                const SizedBox(height: 14),
                _Field(
                  label: 'ACTION REQUIRED',
                  child: TextFormField(
                    controller: _actionController,
                    decoration: _decoration(
                      hint: "What needs to happen next? E.g. 'spray fungicide', "
                          "'replace damaged drip line', 'call agro-vet'",
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _Field(
                  label: 'OBSERVATIONS / NOTES *',
                  child: TextFormField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: _decoration(
                      hint:
                          "What did you observe? E.g. 'caterpillars on cabbage "
                          "heads block A3', 'leaf yellowing in maize B4', 'wilting "
                          "despite irrigation'…",
                    ),
                    validator: (v) {
                      final s = v?.trim() ?? '';
                      if (s.length < 2) return 'Describe what you observed';
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 14),
                _Field(
                  label: 'PHOTO (optional)',
                  child: _PhotoPickerField(
                    photo: _photo,
                    onPick: _submitting ? null : _pickPhoto,
                    onClear: _submitting
                        ? null
                        : () => setState(() => _photo = null),
                  ),
                ),
                const SizedBox(height: 22),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      onPressed: _submitting ? null : _submit,
                      icon: const Icon(Icons.send_outlined, size: 16),
                      label: _submitting
                          ? const Text('Saving…')
                          : const Text('Send to Manager'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 14,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    OutlinedButton(
                      onPressed: _submitting
                          ? null
                          : () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF555555),
                        side: const BorderSide(color: Color(0x33000000)),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 14,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: const Text('Cancel'),
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

  InputDecoration _decoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      isDense: true,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(color: Color(0x22000000)),
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(color: Color(0x22000000)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(color: _primary, width: 1.6),
      ),
    );
  }
}

// =====================================================================
// Shared form primitives (reused by RegisterBlockDialog + RegisterHarvestDialog)
// =====================================================================

class Uint8ListPicked {
  Uint8ListPicked({
    required this.bytes,
    required this.filename,
    required this.mime,
  });
  final Uint8List bytes;
  final String filename;
  final String mime;
}

class _TwoCol extends StatelessWidget {
  const _TwoCol({required this.left, required this.right});
  final Widget left;
  final Widget right;
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 460) {
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
      },
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child});
  final String label;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6, left: 2),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: Color(0xFF7A7A7A),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _DatePickerField extends StatelessWidget {
  const _DatePickerField({
    required this.value,
    required this.format,
    required this.onPick,
    required this.enabled,
  });
  final DateTime value;
  final DateFormat format;
  final ValueChanged<DateTime> onPick;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled
          ? () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: value,
                firstDate: DateTime(now.year - 2),
                lastDate: DateTime(now.year + 3),
              );
              if (picked != null) onPick(picked);
            }
          : null,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            borderSide: BorderSide(color: Color(0x22000000)),
          ),
          enabledBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            borderSide: BorderSide(color: Color(0x22000000)),
          ),
          suffixIcon: const Padding(
            padding: EdgeInsets.only(right: 10),
            child: Icon(
              Icons.calendar_month_outlined,
              size: 20,
              color: Color(0xFF555555),
            ),
          ),
        ),
        child: Text(
          format.format(value),
          style: const TextStyle(fontSize: 14, color: Colors.black87),
        ),
      ),
    );
  }
}

class _PhotoPickerField extends StatelessWidget {
  const _PhotoPickerField({
    required this.photo,
    required this.onPick,
    required this.onClear,
  });
  final Uint8ListPicked? photo;
  final VoidCallback? onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    if (photo == null) {
      return OutlinedButton.icon(
        onPressed: onPick,
        icon: const Icon(Icons.add_a_photo_outlined, size: 18),
        label: const Text('Attach photo'),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF555555),
          side: const BorderSide(color: Color(0x33000000)),
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          alignment: Alignment.centerLeft,
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8F5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x22000000)),
      ),
      child: Row(
        children: [
          const Icon(Icons.image_outlined,
              size: 20, color: Color(0xFF555555)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              photo!.filename,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          IconButton(
            tooltip: 'Remove',
            onPressed: onClear,
            icon: const Icon(Icons.close, size: 18),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
