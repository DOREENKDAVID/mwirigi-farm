import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/models/cow.dart';
import '../../core/models/dairy_ops.dart';
import '../../core/service/api_service.dart';
import '../../core/utils/image_picker_helper.dart';

/// Register / edit a cow. Mirrors the v4.1 HTML "Register New Cow" /
/// "Edit Cow" dialog exactly:
///
///   PHOTO ──── (existing)
///   1. IDENTITY
///       Tag *               Name / local name
///       Date of birth       Breed
///       Breed origin        Current status
///       Worker · House · Source
///   2. CALVING HISTORY
///       i Tag rules · + Add calving
///       (read-only list of existing CALVING records when editing;
///        the "+ Add calving" button opens an inline form)
///   3. NOTES & OBSERVATIONS
///       textarea
///   [Save] [Cancel]
///
/// Modes:
///   * `cow == null`  → create. POSTs /api/dairy/cows.
///   * `cow != null`  → edit. PUTs /api/dairy/cows/tag/:tag with the
///     diff. The tag itself is read-only on edit (it's the lookup key).
///
/// Lactation number, weight, color markings, mother/father tag, and
/// acquisition date are still present on the Cow database model but
/// were dropped from this dialog per the v4.1 spec — those are kept
/// for historical data and a future "Advanced details" panel.
///
/// Image upload is two-stage so the cow row stays consistent on a
/// failure: pick file → upload to /api/uploads/cows → backend returns
/// `imageUrl` → submit cow with that URL.
class RegisterCowDialog extends StatefulWidget {
  const RegisterCowDialog({
    super.key,
    this.cow,
    this.workers = const [],
    this.houses = const [],
  });

  /// When non-null, the dialog opens in edit mode and prefills fields.
  final Cow? cow;

  /// Available dairy workers for the "Worker" dropdown.
  final List<DairyWorkerSummary> workers;

  /// Available dairy houses for the "House" dropdown.
  final List<DairyHouseOverview> houses;

  @override
  State<RegisterCowDialog> createState() => _RegisterCowDialogState();
}

class _RegisterCowDialogState extends State<RegisterCowDialog> {
  static const _primary = Color(0xFF27500A);

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _tag;
  late final TextEditingController _nickname;
  late final TextEditingController _notes;

  Breed? _breed;
  BreedOrigin? _breedOrigin;
  CowStatus _status = CowStatus.milking;
  DateTime? _dob;
  String? _workerId;
  String? _houseId;
  String? _source;

  // Photo state.
  String? _imageUrl;
  Uint8List? _pendingBytes;
  String? _pendingFilename;
  String? _pendingContentType;

  // Calving history loaded from /reproduction/:cowId on edit. Drives
  // the section 2 read-only list. New rows are added via an inline
  // "+ Add calving" button which opens a focused form (see
  // [_AddCalvingForm]) — they're persisted via POST /reproduction
  // immediately, then the list reloads.
  List<_CalvingRow> _calvings = const [];
  bool _loadingCalvings = false;
  bool _showCalvingForm = false;

  bool _uploadingImage = false;
  bool _submitting = false;

  bool get _isEdit => widget.cow != null;

  @override
  void initState() {
    super.initState();
    final c = widget.cow;
    _tag = TextEditingController(text: c?.tag ?? '');
    _nickname = TextEditingController(text: c?.nickname ?? '');
    _notes = TextEditingController(text: c?.healthNotes ?? '');
    _breed = c?.breed;
    _breedOrigin = BreedOrigin.fromWire(c?.breedOrigin);
    _status = c?.status ?? CowStatus.milking;
    _dob = c?.dateOfBirth;
    _workerId = c?.workerId;
    _houseId = c?.houseId;
    _source = c?.acquisitionType;
    _imageUrl = c?.imageUrl;
    if (_isEdit) {
      _loadCalvings();
    }
  }

  @override
  void dispose() {
    _tag.dispose();
    _nickname.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _loadCalvings() async {
    if (widget.cow == null) return;
    setState(() => _loadingCalvings = true);
    try {
      // /reproduction/:cowId returns the cow's full history. We filter
      // to CALVING events for the section 2 list.
      final raw = await ApiService.getReproductionHistory(widget.cow!.id);
      final events = (raw['events'] as List? ?? raw['rows'] as List? ?? const [])
          .whereType<Map>()
          .map((m) => m.cast<String, dynamic>())
          .where((m) => m['eventType'] == 'CALVING')
          .map(_CalvingRow.fromJson)
          .toList();
      events.sort((a, b) => b.date.compareTo(a.date));
      if (!mounted) return;
      setState(() {
        _calvings = events;
        _loadingCalvings = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingCalvings = false);
    }
  }

  Future<void> _pickPhoto() async {
    final picked = await pickCowImage(context);
    if (picked == null || !mounted) return;
    setState(() {
      _pendingBytes = picked.bytes;
      _pendingFilename = picked.filename;
      _pendingContentType = picked.contentType;
      _imageUrl = null;
    });
  }

  Future<bool> _uploadIfNeeded() async {
    if (_pendingBytes == null) return true;
    setState(() => _uploadingImage = true);
    try {
      final url = await ApiService.uploadCowImage(
        bytes: _pendingBytes!,
        filename: _pendingFilename ?? 'cow.jpg',
        contentType: _pendingContentType ?? 'image/jpeg',
      );
      setState(() {
        _imageUrl = url;
        _pendingBytes = null;
        _pendingFilename = null;
        _pendingContentType = null;
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
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;
    if (!await _uploadIfNeeded()) return;

    final body = <String, dynamic>{
      'tag': _tag.text.trim(),
      'status': _status.wire,
      'nickname': _nickname.text.trim().isEmpty ? null : _nickname.text.trim(),
      'imageUrl': _imageUrl,
      'breedOrigin': _breedOrigin?.wire,
      'workerId': _workerId,
      'houseId': _houseId == '__maternity__' ? null : _houseId,
      'acquisitionType': _source,
      'healthNotes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    };
    if (_breed != null) body['breed'] = _breed!.wire;
    if (_dob != null) body['dateOfBirth'] = _dob!.toIso8601String();

    setState(() => _submitting = true);
    try {
      if (_isEdit) {
        await ApiService.updateCow(widget.cow!.tag, body);
      } else {
        await ApiService.createCow(body);
      }
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

  Future<void> _addCalving({
    required DateTime date,
    required String calfTag,
    String? calfSex,
    double? calfBirthWeightKg,
    String? sireCode,
    int? calvingEase,
    String? calvingFate,
    String? notes,
  }) async {
    if (widget.cow == null) return;
    try {
      await ApiService.createReproductionRecord({
        'cowId': widget.cow!.id,
        'eventType': 'CALVING',
        'eventDate': date.toIso8601String(),
        'calfTag': calfTag,
        if (calfSex != null) 'calfSex': calfSex,
        if (calfBirthWeightKg != null) 'calfBirthWeightKg': calfBirthWeightKg,
        if (sireCode != null && sireCode.isNotEmpty) 'sireCode': sireCode,
        if (calvingEase != null) 'calvingEase': calvingEase,
        if (calvingFate != null && calvingFate.isNotEmpty)
          'calvingFate': calvingFate,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      });
      setState(() => _showCalvingForm = false);
      await _loadCalvings();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('d MMM yyyy');
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 720),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _isEdit
                      ? 'Edit Cow — ${widget.cow!.tag}${widget.cow!.nickname != null ? ' (${widget.cow!.nickname})' : ''}'
                      : 'Register New Cow',
                  style: const TextStyle(
                    color: _primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Complete cow record — leave any unknown field blank rather than guessing',
                  style: TextStyle(fontSize: 12, color: Color(0xFF7A7A7A)),
                ),
                const SizedBox(height: 22),

                // ----- Photo -----
                _SectionLabel('PHOTO'),
                const SizedBox(height: 8),
                _PhotoBlock(
                  imageUrl: _imageUrl,
                  pendingBytes: _pendingBytes,
                  uploading: _uploadingImage,
                  onPick: _submitting || _uploadingImage ? null : _pickPhoto,
                  onClear: _imageUrl == null && _pendingBytes == null
                      ? null
                      : () => setState(() {
                            _imageUrl = null;
                            _pendingBytes = null;
                            _pendingFilename = null;
                          }),
                ),
                const SizedBox(height: 22),

                // ----- 1. IDENTITY -----
                _SectionLabel('1. IDENTITY'),
                const SizedBox(height: 12),
                _TwoCol(
                  left: _Field(
                    label: 'COW TAG *',
                    child: TextFormField(
                      controller: _tag,
                      enabled: !_isEdit,
                      decoration: _decoration(hint: 'DAISY or MW-201'),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty)
                              ? 'Tag is required'
                              : null,
                    ),
                  ),
                  right: _Field(
                    label: 'COW NAME / LOCAL NAME',
                    child: TextFormField(
                      controller: _nickname,
                      decoration: _decoration(hint: 'e.g. Topten'),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Adult cows may use their given name (e.g. DAISY) or '
                  'legacy tag (MW-###).',
                  style: TextStyle(fontSize: 11, color: Colors.black45),
                ),
                const SizedBox(height: 14),
                _TwoCol(
                  left: _Field(
                    label: 'DATE OF BIRTH',
                    child: _DatePickerField(
                      value: _dob,
                      format: dateFmt,
                      onTap: _submitting
                          ? null
                          : () async {
                              final picked = await _pickDate(context, _dob);
                              if (picked != null && mounted) {
                                setState(() => _dob = picked);
                              }
                            },
                      onClear: _dob == null
                          ? null
                          : () => setState(() => _dob = null),
                    ),
                  ),
                  right: _Field(
                    label: 'BREED',
                    child: DropdownButtonFormField<Breed>(
                      initialValue: _breed,
                      decoration: _decoration(),
                      isExpanded: true,
                      items: [
                        for (final b in Breed.values)
                          DropdownMenuItem(value: b, child: Text(b.label)),
                      ],
                      onChanged: _submitting
                          ? null
                          : (v) => setState(() => _breed = v),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _TwoCol(
                  left: _Field(
                    label: 'BREED ORIGIN',
                    child: DropdownButtonFormField<BreedOrigin?>(
                      initialValue: _breedOrigin,
                      decoration: _decoration(),
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem<BreedOrigin?>(
                          child: Text('—'),
                        ),
                        for (final o in BreedOrigin.values)
                          DropdownMenuItem(value: o, child: Text(o.label)),
                      ],
                      onChanged: _submitting
                          ? null
                          : (v) => setState(() => _breedOrigin = v),
                    ),
                  ),
                  right: _Field(
                    label: 'CURRENT STATUS',
                    child: DropdownButtonFormField<CowStatus>(
                      initialValue: _status,
                      decoration: _decoration(),
                      isExpanded: true,
                      items: [
                        for (final s in CowStatus.values)
                          DropdownMenuItem(value: s, child: Text(s.label)),
                      ],
                      onChanged: _submitting
                          ? null
                          : (v) => setState(() => _status = v ?? _status),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _ThreeCol(
                  a: _Field(
                    label: 'ASSIGNED WORKER',
                    child: DropdownButtonFormField<String?>(
                      initialValue: _workerId,
                      decoration: _decoration(),
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem<String?>(child: Text('—')),
                        for (final w in widget.workers)
                          DropdownMenuItem(value: w.id, child: Text(w.name)),
                      ],
                      onChanged: _submitting
                          ? null
                          : (v) => setState(() => _workerId = v),
                    ),
                  ),
                  b: _Field(
                    label: 'HOUSE',
                    child: DropdownButtonFormField<String?>(
                      initialValue: _houseId,
                      decoration: _decoration(),
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem<String?>(child: Text('—')),
                        for (final h in widget.houses)
                          DropdownMenuItem(
                            value: h.id,
                            child: Text(
                              // Strip "Dairy " for display: "Dairy A" → "A".
                              h.id == '__maternity__'
                                  ? 'Maternity'
                                  : h.name.replaceFirst(
                                      RegExp(r'^Dairy\s+'),
                                      '',
                                    ),
                            ),
                          ),
                      ],
                      onChanged: _submitting
                          ? null
                          : (v) => setState(() => _houseId = v),
                    ),
                  ),
                  c: _Field(
                    label: 'SOURCE',
                    child: DropdownButtonFormField<String?>(
                      initialValue: _source,
                      decoration: _decoration(),
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem<String?>(child: Text('—')),
                        DropdownMenuItem(
                          value: 'Born on farm',
                          child: Text('Born on farm'),
                        ),
                        DropdownMenuItem(
                          value: 'Purchased',
                          child: Text('Purchased'),
                        ),
                      ],
                      onChanged: _submitting
                          ? null
                          : (v) => setState(() => _source = v),
                    ),
                  ),
                ),
                const SizedBox(height: 22),

                // ----- 2. CALVING HISTORY -----
                _CalvingHistorySection(
                  isEdit: _isEdit,
                  loading: _loadingCalvings,
                  rows: _calvings,
                  showForm: _showCalvingForm,
                  onToggleForm: () => setState(
                    () => _showCalvingForm = !_showCalvingForm,
                  ),
                  onAdd: _addCalving,
                  damName: (widget.cow?.nickname?.isNotEmpty ?? false)
                      ? widget.cow!.nickname!
                      : (widget.cow?.tag ?? ''),
                ),
                const SizedBox(height: 22),

                // ----- 3. NOTES & OBSERVATIONS -----
                _SectionLabel('3. NOTES & OBSERVATIONS'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _notes,
                  maxLines: 3,
                  decoration: _decoration(
                    hint:
                        'Any other relevant details (temperament, history, current treatment, etc.)',
                  ),
                ),
                const SizedBox(height: 24),

                // ----- Save / Cancel -----
                Row(
                  children: [
                    FilledButton(
                      onPressed:
                          _submitting || _uploadingImage ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: _primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 14,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: (_submitting || _uploadingImage)
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Save'),
                    ),
                    const SizedBox(width: 10),
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

  Future<DateTime?> _pickDate(BuildContext context, DateTime? initial) {
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: DateTime(now.year - 30),
      lastDate: DateTime(now.year + 1),
    );
  }

  InputDecoration _decoration({String? hint, String? suffix}) {
    return InputDecoration(
      hintText: hint,
      suffixText: suffix,
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

// ===== Calving history section =====

class _CalvingRow {
  _CalvingRow({
    required this.id,
    required this.date,
    this.calfTag,
    this.calfSex,
    this.calfBirthWeightKg,
    this.sireCode,
    this.calvingEase,
    this.calvingFate,
    this.notes,
  });
  final String id;
  final DateTime date;
  final String? calfTag;
  final String? calfSex;
  final double? calfBirthWeightKg;
  final String? sireCode;
  final int? calvingEase;
  final String? calvingFate;
  final String? notes;

  factory _CalvingRow.fromJson(Map<String, dynamic> j) {
    int? toInt(dynamic v) =>
        v is num ? v.toInt() : (v is String ? int.tryParse(v) : null);
    double? toDouble(dynamic v) =>
        v is num ? v.toDouble() : (v is String ? double.tryParse(v) : null);
    return _CalvingRow(
      id: (j['id'] ?? '').toString(),
      date: DateTime.tryParse(j['eventDate']?.toString() ?? '') ??
          DateTime.now(),
      calfTag: j['calfTag']?.toString(),
      calfSex: j['calfSex']?.toString(),
      calfBirthWeightKg: toDouble(j['calfBirthWeightKg']),
      sireCode: j['sireCode']?.toString(),
      calvingEase: toInt(j['calvingEase']),
      calvingFate: j['calvingFate']?.toString(),
      notes: j['notes']?.toString(),
    );
  }
}

typedef _AddCalvingFn = Future<void> Function({
  required DateTime date,
  required String calfTag,
  String? calfSex,
  double? calfBirthWeightKg,
  String? sireCode,
  int? calvingEase,
  String? calvingFate,
  String? notes,
});

class _CalvingHistorySection extends StatefulWidget {
  const _CalvingHistorySection({
    required this.isEdit,
    required this.loading,
    required this.rows,
    required this.showForm,
    required this.onToggleForm,
    required this.onAdd,
    required this.damName,
  });

  final bool isEdit;
  final bool loading;
  final List<_CalvingRow> rows;
  final bool showForm;
  final VoidCallback onToggleForm;
  final _AddCalvingFn onAdd;
  final String damName;

  @override
  State<_CalvingHistorySection> createState() => _CalvingHistorySectionState();
}

class _CalvingHistorySectionState extends State<_CalvingHistorySection> {
  // Tag-rules banner is collapsed by default — matches the HTML mockup
  // (`.tag-rules` only renders with the `.show` modifier). Tapping the
  // chip toggles it.
  bool _showTagRules = false;

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('d MMM yyyy');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const _SectionLabel('2. CALVING HISTORY'),
            const Spacer(),
            _TagRulesChip(
              active: _showTagRules,
              onTap: () =>
                  setState(() => _showTagRules = !_showTagRules),
            ),
            if (widget.isEdit) ...[
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: widget.onToggleForm,
                icon: Icon(
                  widget.showForm ? Icons.close : Icons.add,
                  size: 14,
                ),
                label: Text(widget.showForm ? 'Cancel' : 'Add calving'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF27500A),
                  backgroundColor: const Color(0xFFE7F0DD),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
        if (!widget.isEdit) ...[
          const SizedBox(height: 6),
          const Text(
            'Save the cow first, then come back to this section to log '
            'calving events one at a time.',
            style: TextStyle(fontSize: 11, color: Colors.black45),
          ),
        ] else ...[
          // Banner is collapsed by default — toggled by the Tag rules chip.
          if (_showTagRules) ...[
            const SizedBox(height: 8),
            const _TagRulesBanner(),
          ],
          const SizedBox(height: 8),
          const Text(
            'Ease: 1=Unassisted · 2=Minor help · 3=Help needed · '
            '4=Difficult · 5=Vet required',
            style: TextStyle(fontSize: 11, color: Colors.black45),
          ),
          const SizedBox(height: 8),
          if (widget.loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (widget.rows.isEmpty && !widget.showForm)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No calvings recorded yet.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            )
          else
            Column(
              children: [
                for (final r in widget.rows) ...[
                  _CalvingHistoryRow(row: r, dateFmt: dateFmt),
                  const SizedBox(height: 6),
                ],
              ],
            ),
          if (widget.showForm) ...[
            const SizedBox(height: 8),
            _AddCalvingForm(
              onSubmit: widget.onAdd,
              damName: widget.damName,
            ),
          ],
        ],
      ],
    );
  }
}

// Clickable "i Tag rules" chip in the section header. Toggles the
// _TagRulesBanner visibility — banner is collapsed by default, mirroring
// the HTML mockup's `.tag-rules` (hidden until the toggle adds `.show`).
class _TagRulesChip extends StatelessWidget {
  const _TagRulesChip({required this.active, required this.onTap});
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = active
        ? const Color(0xFFCFE0BC) // active fill — matches the mockup's pressed state
        : const Color(0xFFE7F0DD);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: active
                ? const Color(0xFF27500A)
                : Colors.transparent,
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline, size: 12, color: Color(0xFF27500A)),
            SizedBox(width: 4),
            Text(
              'Tag rules',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF27500A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Green tag-rules info banner, mirroring the HTML mockup verbatim.
class _TagRulesBanner extends StatelessWidget {
  const _TagRulesBanner();
  @override
  Widget build(BuildContext context) {
    const greenBg = Color(0xFFE7F0DD);
    const fg = Color(0xFF1F4008);
    Widget code(String text) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFD7E4C7),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            text,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              color: fg,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: greenBg,
        border: const Border(
          left: BorderSide(color: Color(0xFF27500A), width: 3),
        ),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(6),
          bottomRight: Radius.circular(6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Calf tagging (per Cattle Tagging Guideline):',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
          const SizedBox(height: 4),
          DefaultTextStyle(
            style: const TextStyle(fontSize: 12, color: fg, height: 1.55),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text('Female calf  →  '),
                    code('DAM-NAME-N'),
                    const Text(' (e.g. '),
                    code('DAISY-1'),
                    const Text(', then '),
                    code('DAISY-2'),
                    const Text(' for her next heifer).'),
                  ],
                ),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text('Male calf  →  next sequential number from '
                        'the feedlot counter (e.g. '),
                    code('1024'),
                    const Text(', '),
                    code('1025'),
                    const Text(').'),
                  ],
                ),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text('Bulls (breeding)  →  '),
                    code('B-001'),
                    const Text(', '),
                    code('B-002'),
                    const Text('.  Tag within '),
                    const Text(
                      '10 days',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const Text(' of birth.'),
                  ],
                ),
                const Text(
                    'Click the ✨ button to auto-suggest the right tag '
                    'based on sex.'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CalvingHistoryRow extends StatelessWidget {
  const _CalvingHistoryRow({required this.row, required this.dateFmt});
  final _CalvingRow row;
  final DateFormat dateFmt;

  @override
  Widget build(BuildContext context) {
    final sexLabel = row.calfSex == null
        ? '—'
        : (row.calfSex == 'F' ? '♀ F' : '♂ M');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAF7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              dateFmt.format(row.date),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              row.calfTag ?? '—',
              style: const TextStyle(
                fontSize: 13,
                fontFamily: 'monospace',
              ),
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              sexLabel,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          SizedBox(
            width: 60,
            child: Text(
              row.calfBirthWeightKg == null
                  ? '—'
                  : '${row.calfBirthWeightKg} kg',
              style: const TextStyle(fontSize: 12),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              row.calvingFate ?? row.notes ?? '',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// Add-calving form — matches the HTML mockup row 1: date · calf tag · ✨ ·
// sex; row 2: wt kg · sire ID · ease · fate. The ✨ button auto-suggests
// a tag based on sex and the dam's name.
class _AddCalvingForm extends StatefulWidget {
  const _AddCalvingForm({required this.onSubmit, required this.damName});
  final _AddCalvingFn onSubmit;
  final String damName;

  @override
  State<_AddCalvingForm> createState() => _AddCalvingFormState();
}

class _AddCalvingFormState extends State<_AddCalvingForm> {
  final _calfTag = TextEditingController();
  final _wt = TextEditingController();
  final _sire = TextEditingController();
  final _notes = TextEditingController();
  DateTime _date = DateTime.now();
  String? _sex; // "M" | "F"
  int? _ease; // 1..5
  String? _fate;
  bool _submitting = false;

  static const _fateOptions = [
    'Heifer to herd',
    'Bull → feedlot',
    'Stillborn',
    'Sold',
    'Died',
  ];

  @override
  void dispose() {
    _calfTag.dispose();
    _wt.dispose();
    _sire.dispose();
    _notes.dispose();
    super.dispose();
  }

  // ✨ auto-suggest:
  //   F → DAM-NAME-N (next sequential heifer)
  //   M → next 4-digit feedlot counter starting at 1024 (HTML default)
  //   Bull selection (fate = breeding) → B-XXX, but we don't have an
  //   explicit "breeding" fate yet, so we default to feedlot for males.
  String _suggestTag() {
    final dam = widget.damName.trim();
    if (_sex == 'F' && dam.isNotEmpty) {
      // We don't know the heifer count from this form alone — start at 1.
      // Caller can edit; the ✨ button is a hint, not a guarantee.
      final base = dam.replaceAll(RegExp(r'\s+'), '-').toUpperCase();
      return '$base-1';
    }
    if (_sex == 'M') {
      return '1024';
    }
    return _calfTag.text.trim();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 20),
      lastDate: now,
    );
    if (picked != null && mounted) {
      setState(() => _date = picked);
    }
  }

  Future<void> _save() async {
    final tag = _calfTag.text.trim();
    if (tag.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Calf tag is required')),
      );
      return;
    }
    final wt = double.tryParse(_wt.text.trim());
    setState(() => _submitting = true);
    await widget.onSubmit(
      date: _date,
      calfTag: tag,
      calfSex: _sex,
      calfBirthWeightKg: wt,
      sireCode: _sire.text.trim().isEmpty ? null : _sire.text.trim(),
      calvingEase: _ease,
      calvingFate: _fate,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    );
    if (mounted) setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd/MM/yyyy');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFEDE6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Row 1: date · calf tag · ✨ · sex
          Row(
            children: [
              Expanded(
                flex: 3,
                child: InkWell(
                  onTap: _submitting ? null : _pickDate,
                  child: InputDecorator(
                    decoration: _decoration(label: 'dd/mm/yyyy'),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 14),
                        const SizedBox(width: 6),
                        Text(dateFmt.format(_date),
                            style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _calfTag,
                  decoration: _decoration(label: 'Calf tag').copyWith(
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _SparkleButton(
                onTap: _submitting
                    ? null
                    : () {
                        final suggestion = _suggestTag();
                        if (suggestion.isNotEmpty) {
                          setState(() => _calfTag.text = suggestion);
                        }
                      },
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  initialValue: _sex,
                  decoration: _decoration(label: 'Sex'),
                  items: const [
                    DropdownMenuItem(value: 'F', child: Text('♀ Female')),
                    DropdownMenuItem(value: 'M', child: Text('♂ Male')),
                  ],
                  onChanged: _submitting
                      ? null
                      : (v) => setState(() => _sex = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Row 2: wt kg · sire · ease · fate
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _wt,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: _decoration(label: 'Wt kg'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _sire,
                  decoration: _decoration(label: 'Sire ID'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<int>(
                  initialValue: _ease,
                  decoration: _decoration(label: 'Ease'),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('1 — Unassisted')),
                    DropdownMenuItem(value: 2, child: Text('2 — Minor help')),
                    DropdownMenuItem(value: 3, child: Text('3 — Help needed')),
                    DropdownMenuItem(value: 4, child: Text('4 — Difficult')),
                    DropdownMenuItem(value: 5, child: Text('5 — Vet required')),
                  ],
                  onChanged: _submitting
                      ? null
                      : (v) => setState(() => _ease = v),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  initialValue: _fate,
                  decoration: _decoration(label: 'Fate'),
                  items: [
                    for (final f in _fateOptions)
                      DropdownMenuItem(value: f, child: Text(f)),
                  ],
                  onChanged: _submitting
                      ? null
                      : (v) => setState(() => _fate = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _notes,
            decoration: _decoration(label: 'Notes (optional)'),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              FilledButton(
                onPressed: _submitting ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF27500A),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save calving'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _decoration({required String label}) {
    return InputDecoration(
      labelText: label,
      isDense: true,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(color: Color(0x22000000)),
      ),
      filled: true,
      fillColor: Colors.white,
    );
  }
}

class _SparkleButton extends StatelessWidget {
  const _SparkleButton({required this.onTap});
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFFE7F0DD),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF27500A), width: 1.5),
        ),
        alignment: Alignment.center,
        child: const Text(
          '✨',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}

// ===== Photo block, layout helpers (unchanged from previous version) =====

class _PhotoBlock extends StatelessWidget {
  const _PhotoBlock({
    required this.imageUrl,
    required this.pendingBytes,
    required this.uploading,
    required this.onPick,
    required this.onClear,
  });

  final String? imageUrl;
  final Uint8List? pendingBytes;
  final bool uploading;
  final VoidCallback? onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFEDE6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0x14000000)),
            ),
            clipBehavior: Clip.antiAlias,
            alignment: Alignment.center,
            child: _previewChild(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  onPressed: onPick,
                  icon: const Icon(Icons.photo_camera_outlined, size: 16),
                  label: const Text('📷  Take / choose photo'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0x33000000)),
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    backgroundColor: Colors.white,
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Opens camera on phone',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF7A7A7A),
                        ),
                      ),
                    ),
                    if (onClear != null)
                      TextButton.icon(
                        onPressed: onClear,
                        icon: const Icon(Icons.close, size: 13),
                        label: const Text('Remove'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF555555),
                          textStyle: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 0,
                          ),
                          minimumSize: const Size(0, 28),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _previewChild() {
    if (uploading) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    if (pendingBytes != null) {
      return Image.memory(pendingBytes!, fit: BoxFit.cover, gaplessPlayback: true);
    }
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return Image.network(
        ApiService.assetUrl(imageUrl!),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            const Text('🐄', style: TextStyle(fontSize: 32)),
      );
    }
    return const Text('🐄', style: TextStyle(fontSize: 36));
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        letterSpacing: 0.6,
        fontWeight: FontWeight.w800,
        color: Color(0xFF27500A),
      ),
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

class _ThreeCol extends StatelessWidget {
  const _ThreeCol({required this.a, required this.b, required this.c});
  final Widget a;
  final Widget b;
  final Widget c;
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, cs) {
        if (cs.maxWidth < 560) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              a,
              const SizedBox(height: 14),
              b,
              const SizedBox(height: 14),
              c,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: a),
            const SizedBox(width: 14),
            Expanded(child: b),
            const SizedBox(width: 14),
            Expanded(child: c),
          ],
        );
      },
    );
  }
}

class _DatePickerField extends StatelessWidget {
  const _DatePickerField({
    required this.value,
    required this.format,
    required this.onTap,
    this.onClear,
  });
  final DateTime? value;
  final DateFormat format;
  final VoidCallback? onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
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
          suffixIcon: value == null
              ? const Padding(
                  padding: EdgeInsets.only(right: 10),
                  child: Icon(
                    Icons.calendar_month_outlined,
                    size: 20,
                    color: Color(0xFF555555),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: onClear,
                ),
        ),
        child: Text(
          value == null ? 'dd/mm/yyyy' : format.format(value!),
          style: TextStyle(
            color: value == null ? const Color(0xFF999999) : Colors.black87,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
