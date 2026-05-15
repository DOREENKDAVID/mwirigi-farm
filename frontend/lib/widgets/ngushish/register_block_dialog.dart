// Register Block dialog — creates a new crop block (Ngusishi) via
// POST /api/ngushish/crops. Captures the master-template fields used
// by the Blocks pill register: block code, area, crop type, status,
// planting/harvest dates, season, soil/irrigation, assigned worker.
//
// Fields the backend doesn't model directly (cropVariety, soilType,
// assignedWorker) are folded into the `notes` payload so they survive
// across refreshes and a future migration can lift them into columns.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/service/api_service.dart';
import 'crop_issue_dialog.dart' show Uint8ListPicked;

class RegisterBlockDialog extends StatefulWidget {
  const RegisterBlockDialog({super.key});

  @override
  State<RegisterBlockDialog> createState() => _RegisterBlockDialogState();
}

class _RegisterBlockDialogState extends State<RegisterBlockDialog> {
  static const _primary = Color(0xFF27500A);

  static const _cropTypes = [
    'Maize',
    'Cabbage',
    'Potatoes',
    'Beans',
    'Tomatoes',
    'Avocado',
    'Napier grass',
    'Mixed crop',
    'Other',
  ];

  static const _statuses = [
    ('AWAITING', 'Awaiting planting'),
    ('GROWING', 'Growing'),
    ('READY', 'Ready'),
    ('HARVESTED', 'Harvested'),
    ('INFRASTRUCTURE', 'Infrastructure'),
  ];

  static const _seasons = [
    'Long Rain',
    'Short Rain',
    'Irrigation',
    'Perennial',
  ];

  static const _soilTypes = ['Loam', 'Clay', 'Sandy', 'Black cotton', 'Mixed'];

  static const _irrigationTypes = [
    'Rain-fed',
    'Drip',
    'Sprinkler',
    'Furrow',
    'Manual',
  ];

  final _formKey = GlobalKey<FormState>();
  final _blockController = TextEditingController();
  final _areaController = TextEditingController();
  final _varietyController = TextEditingController();
  final _notesController = TextEditingController();

  String? _cropType;
  String _status = 'AWAITING';
  String? _season;
  String? _soilType;
  String _irrigationType = 'Rain-fed';
  String? _assignedWorker;
  DateTime? _plantingDate;
  DateTime? _expectedHarvest;

  List<String> _workers = const [];
  bool _loadingWorkers = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadWorkers();
  }

  @override
  void dispose() {
    _blockController.dispose();
    _areaController.dispose();
    _varietyController.dispose();
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

  Future<void> _submit() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;
    setState(() => _submitting = true);

    // Encode extras the backend doesn't have dedicated columns for.
    final extras = <String, dynamic>{
      'cropVariety': _varietyController.text.trim(),
      'soilType': _soilType,
      'assignedWorker': _assignedWorker,
    }..removeWhere((_, v) => v == null || (v is String && v.isEmpty));
    final notesPayload = StringBuffer(_notesController.text.trim());
    if (extras.isNotEmpty) {
      if (notesPayload.isNotEmpty) notesPayload.write('\n');
      notesPayload.write(jsonEncode({'kind': 'META', ...extras}));
    }

    final body = <String, dynamic>{
      'name': _cropType,
      'block': _blockController.text.trim(),
      'acreage': double.tryParse(_areaController.text.trim()) ?? 0,
      'status': _status,
      'isPerennial': _season == 'Perennial',
      'irrigated': _irrigationType != 'Rain-fed',
      'irrigationType': _irrigationType,
      if (_plantingDate != null)
        'plantedDate': _plantingDate!.toIso8601String(),
      if (_expectedHarvest != null) ...{
        'expectedHarvest': _expectedHarvest!.toIso8601String(),
        'dueDate': _expectedHarvest!.toIso8601String(),
      },
      if (_season != null) 'season': _season,
      if (notesPayload.isNotEmpty) 'notes': notesPayload.toString(),
    };

    try {
      await ApiService.createNgushishCrop(body);
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

  String? _ageHint() {
    if (_plantingDate == null) return null;
    final days = DateTime.now().difference(_plantingDate!).inDays;
    if (days < 0) return 'Planting scheduled in ${-days}d';
    if (days == 0) return 'Planted today';
    if (days < 14) return '${days}d old';
    if (days < 60) return '${(days / 7).floor()} weeks old';
    final months = days ~/ 30;
    final rem = (days % 30) ~/ 15;
    return rem == 0 ? '$months months old' : '$months½ months old';
  }

  String? _countdownHint() {
    if (_expectedHarvest == null) return null;
    final days = _expectedHarvest!.difference(DateTime.now()).inDays;
    if (days < 0) return '${-days}d overdue';
    if (days == 0) return 'Harvest today';
    if (days == 1) return 'Harvest tomorrow';
    return 'In ${days}d';
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd/MM/yyyy');
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
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
                    const Text('📋', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Register New Block',
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
                  'Adds a row to the crop register and the harvest planner.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF7A7A7A)),
                ),
                const SizedBox(height: 18),
                _TwoCol(
                  left: _Field(
                    label: 'BLOCK CODE *',
                    child: TextFormField(
                      controller: _blockController,
                      decoration: _decoration(hint: 'e.g. A1i or C3 or B5'),
                      textCapitalization: TextCapitalization.characters,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Required'
                          : null,
                    ),
                  ),
                  right: _Field(
                    label: 'AREA (ac) *',
                    child: TextFormField(
                      controller: _areaController,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: _decoration(hint: 'e.g. 0.5 or 1.2'),
                      validator: (v) {
                        final s = v?.trim() ?? '';
                        final n = double.tryParse(s);
                        if (n == null || n <= 0) return 'Enter a valid acreage';
                        return null;
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _TwoCol(
                  left: _Field(
                    label: 'CROP TYPE *',
                    child: DropdownButtonFormField<String>(
                      initialValue: _cropType,
                      isExpanded: true,
                      decoration: _decoration(hint: '— select —'),
                      items: [
                        for (final c in _cropTypes)
                          DropdownMenuItem(value: c, child: Text(c)),
                      ],
                      onChanged: _submitting
                          ? null
                          : (v) => setState(() => _cropType = v),
                      validator: (v) => v == null ? 'Required' : null,
                    ),
                  ),
                  right: _Field(
                    label: 'CROP VARIETY',
                    child: TextFormField(
                      controller: _varietyController,
                      decoration:
                          _decoration(hint: 'e.g. Gloria F1 / Shangi / DK 8031'),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _TwoCol(
                  left: _Field(
                    label: 'STATUS *',
                    child: DropdownButtonFormField<String>(
                      initialValue: _status,
                      isExpanded: true,
                      decoration: _decoration(),
                      items: [
                        for (final (wire, label) in _statuses)
                          DropdownMenuItem(value: wire, child: Text(label)),
                      ],
                      onChanged: _submitting
                          ? null
                          : (v) => setState(() => _status = v ?? _status),
                    ),
                  ),
                  right: _Field(
                    label: 'SEASON',
                    child: DropdownButtonFormField<String>(
                      initialValue: _season,
                      isExpanded: true,
                      decoration: _decoration(hint: '— select —'),
                      items: [
                        for (final s in _seasons)
                          DropdownMenuItem(value: s, child: Text(s)),
                      ],
                      onChanged: _submitting
                          ? null
                          : (v) => setState(() => _season = v),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _TwoCol(
                  left: _Field(
                    label: 'PLANTING DATE',
                    child: _DateField(
                      value: _plantingDate,
                      enabled: !_submitting,
                      format: dateFmt,
                      hint: '— pick date —',
                      onPick: (d) => setState(() => _plantingDate = d),
                    ),
                  ),
                  right: _Field(
                    label: 'EXPECTED HARVEST',
                    child: _DateField(
                      value: _expectedHarvest,
                      enabled: !_submitting,
                      format: dateFmt,
                      hint: '— pick date —',
                      onPick: (d) => setState(() => _expectedHarvest = d),
                    ),
                  ),
                ),
                if (_ageHint() != null || _countdownHint() != null) ...[
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(left: 2),
                    child: Text(
                      [
                        if (_ageHint() != null) 'Age · ${_ageHint()}',
                        if (_countdownHint() != null)
                          'Harvest · ${_countdownHint()}',
                      ].join('   ·   '),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF7A7A7A),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                _TwoCol(
                  left: _Field(
                    label: 'SOIL TYPE',
                    child: DropdownButtonFormField<String>(
                      initialValue: _soilType,
                      isExpanded: true,
                      decoration: _decoration(hint: '— select —'),
                      items: [
                        for (final s in _soilTypes)
                          DropdownMenuItem(value: s, child: Text(s)),
                      ],
                      onChanged: _submitting
                          ? null
                          : (v) => setState(() => _soilType = v),
                    ),
                  ),
                  right: _Field(
                    label: 'IRRIGATION TYPE',
                    child: DropdownButtonFormField<String>(
                      initialValue: _irrigationType,
                      isExpanded: true,
                      decoration: _decoration(),
                      items: [
                        for (final s in _irrigationTypes)
                          DropdownMenuItem(value: s, child: Text(s)),
                      ],
                      onChanged: _submitting
                          ? null
                          : (v) =>
                              setState(() => _irrigationType = v ?? 'Rain-fed'),
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
                  label: 'NOTES / ACTIONS',
                  child: TextFormField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: _decoration(
                      hint:
                          "e.g. 'Top-dress at week 4', 'Monitor avocado spacing', "
                          "'Irrigate weekly'…",
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      onPressed: _submitting ? null : _submit,
                      icon: const Icon(Icons.check, size: 16),
                      label: _submitting
                          ? const Text('Saving…')
                          : const Text('Register Block'),
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
// Local copies of the layout primitives from crop_issue_dialog. Kept
// private so the two dialogs stay independent — the duplication is tiny
// and lets us evolve each form's spacing without coupling.
// =====================================================================

// Re-export Uint8ListPicked for callers that need it (e.g. RegisterHarvestDialog).
typedef PickedPhoto = Uint8ListPicked;

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

class _DateField extends StatelessWidget {
  const _DateField({
    required this.value,
    required this.format,
    required this.onPick,
    required this.enabled,
    required this.hint,
  });
  final DateTime? value;
  final DateFormat format;
  final ValueChanged<DateTime> onPick;
  final bool enabled;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled
          ? () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: value ?? now,
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
          value == null ? hint : format.format(value!),
          style: TextStyle(
            fontSize: 14,
            color: value == null ? const Color(0xFF999999) : Colors.black87,
          ),
        ),
      ),
    );
  }
}
