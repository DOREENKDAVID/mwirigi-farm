// Add / Edit dialogs for the Piggery registers — Sow, Boar, Litter,
// Nursery, Fatten Pen. Each follows the same compact layout pattern
// used by the Log Farrowing dialog: rounded inputs, primary green save
// button, outlined cancel. The dialogs are intentionally lean — heavier
// flows (medical history, lineage) belong in their own pills.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/piggery.dart';
import '../../core/service/api_service.dart';

const _primary = Color(0xFF27500A);
const _txt2 = Color(0xFF6B7770);
const _txt3 = Color(0xFF99A39B);

InputDecoration _input({String? hint}) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _txt3),
      isDense: true,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0x33000000)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0x33000000)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _primary, width: 1.5),
      ),
    );

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          color: _txt2,
        ),
      );
}

class _PrimaryBtn extends StatelessWidget {
  const _PrimaryBtn({required this.onPressed, required this.label});
  final VoidCallback? onPressed;
  final String label;
  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: _primary,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        textStyle:
            const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
      ),
      child: onPressed == null
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            )
          : Text(label),
    );
  }
}

class _CancelBtn extends StatelessWidget {
  const _CancelBtn({required this.onPressed});
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: _txt2,
        side: const BorderSide(color: Color(0x33000000)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: const Text('Cancel',
          style: TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

Widget _shell({
  required BuildContext context,
  required String title,
  required String subtitle,
  required Widget child,
}) {
  return Dialog(
    backgroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560, maxHeight: 680),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(subtitle,
                style: const TextStyle(fontSize: 12, color: _txt2)),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    ),
  );
}

// =====================================================================
// SOW — Add (the existing edit_sow_dialog.dart handles edit)
// =====================================================================

class AddSowDialog extends StatefulWidget {
  const AddSowDialog({super.key, this.houses = const []});
  final List<PigHouse> houses;
  @override
  State<AddSowDialog> createState() => _AddSowDialogState();
}

class _AddSowDialogState extends State<AddSowDialog> {
  final _formKey = GlobalKey<FormState>();
  final _tagController = TextEditingController();
  final _penController = TextEditingController();
  final _noteController = TextEditingController();
  String? _house;
  PigStatus _status = PigStatus.dry;
  DateTime? _serviceDate;
  DateTime? _expFarrow;
  bool _submitting = false;

  @override
  void dispose() {
    _tagController.dispose();
    _penController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDate(DateTime? initial) async {
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 2),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    try {
      await ApiService.createPig({
        'tag': _tagController.text.trim(),
        'category': 'SOW',
        'status': _status.wire,
        if (_house != null) 'house': _house,
        if (_penController.text.trim().isNotEmpty)
          'pen': _penController.text.trim(),
        if (_serviceDate != null)
          'serviceDate': _serviceDate!.toIso8601String(),
        if (_expFarrow != null) 'expFarrow': _expFarrow!.toIso8601String(),
        if (_noteController.text.trim().isNotEmpty)
          'note': _noteController.text.trim(),
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
    return _shell(
      context: context,
      title: 'Add Sow',
      subtitle: 'Register a new sow into the master register',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Label('Tag *'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _tagController,
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              decoration: _input(hint: '156'),
              validator: (v) =>
                  (v?.trim().isEmpty ?? true) ? 'Tag is required' : null,
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Label('House'),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _house,
                        decoration: _input(),
                        items: [
                          const DropdownMenuItem(
                              value: null, child: Text('—')),
                          for (final h in widget.houses)
                            DropdownMenuItem(
                                value: h.code, child: Text(h.code)),
                        ],
                        onChanged: (v) => setState(() => _house = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Label('Pen'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _penController,
                        decoration: _input(hint: 'A12'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const _Label('Status'),
            const SizedBox(height: 6),
            DropdownButtonFormField<PigStatus>(
              initialValue: _status,
              decoration: _input(),
              items: [
                for (final s in PigStatus.values)
                  DropdownMenuItem(value: s, child: Text(s.label)),
              ],
              onChanged: (v) => setState(() => _status = v ?? _status),
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _DateRow(
                    label: 'Service date',
                    value: _serviceDate,
                    onTap: () async {
                      final d = await _pickDate(_serviceDate);
                      if (d != null) setState(() => _serviceDate = d);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DateRow(
                    label: 'Expected farrow',
                    value: _expFarrow,
                    onTap: () async {
                      final d = await _pickDate(_expFarrow);
                      if (d != null) setState(() => _expFarrow = d);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const _Label('Note'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _noteController,
              minLines: 2,
              maxLines: 3,
              decoration: _input(hint: 'Observations, special handling…'),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: _PrimaryBtn(
                    onPressed: _submitting ? null : _submit,
                    label: 'Save Sow',
                  ),
                ),
                const SizedBox(width: 10),
                _CancelBtn(
                  onPressed:
                      _submitting ? null : () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// BOAR — Add + Edit
// =====================================================================

class AddBoarDialog extends StatefulWidget {
  const AddBoarDialog({super.key, this.houses = const []});
  final List<PigHouse> houses;
  @override
  State<AddBoarDialog> createState() => _AddBoarDialogState();
}

class _AddBoarDialogState extends State<AddBoarDialog> {
  final _formKey = GlobalKey<FormState>();
  final _tagController = TextEditingController();
  final _penController = TextEditingController();
  final _breedController = TextEditingController();
  final _ageController = TextEditingController();
  final _roleController = TextEditingController();
  String? _house;
  bool _submitting = false;

  @override
  void dispose() {
    _tagController.dispose();
    _penController.dispose();
    _breedController.dispose();
    _ageController.dispose();
    _roleController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    try {
      await ApiService.createPig({
        'tag': _tagController.text.trim(),
        'category': 'BOAR',
        if (_house != null) 'house': _house,
        if (_penController.text.trim().isNotEmpty)
          'pen': _penController.text.trim(),
        if (_breedController.text.trim().isNotEmpty)
          'breed': _breedController.text.trim(),
        if (_ageController.text.trim().isNotEmpty)
          'age': _ageController.text.trim(),
        if (_roleController.text.trim().isNotEmpty)
          'role': _roleController.text.trim(),
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
    return _shell(
      context: context,
      title: 'Add Boar',
      subtitle: 'Register a boar (BR-prefix tag) into the boar register',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Label('Tag *'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _tagController,
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              decoration: _input(hint: 'BR08'),
              validator: (v) =>
                  (v?.trim().isEmpty ?? true) ? 'Tag is required' : null,
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Label('House'),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _house,
                        decoration: _input(),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('—')),
                          for (final h in widget.houses)
                            DropdownMenuItem(
                                value: h.code, child: Text(h.code)),
                        ],
                        onChanged: (v) => setState(() => _house = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Label('Pen'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _penController,
                        decoration: _input(hint: 'B4'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Label('Breed'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _breedController,
                        decoration: _input(hint: 'Duroc · TBC'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Label('Age'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _ageController,
                        decoration: _input(hint: '~5mo · Mature'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const _Label('Role'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _roleController,
              minLines: 2,
              maxLines: 3,
              decoration:
                  _input(hint: 'Active service boar · Young · CASTRATED…'),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: _PrimaryBtn(
                    onPressed: _submitting ? null : _submit,
                    label: 'Save Boar',
                  ),
                ),
                const SizedBox(width: 10),
                _CancelBtn(
                  onPressed:
                      _submitting ? null : () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class EditBoarDialog extends StatefulWidget {
  const EditBoarDialog({super.key, required this.boar, this.houses = const []});
  final Boar boar;
  final List<PigHouse> houses;
  @override
  State<EditBoarDialog> createState() => _EditBoarDialogState();
}

class _EditBoarDialogState extends State<EditBoarDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _penController;
  late final TextEditingController _breedController;
  late final TextEditingController _ageController;
  late final TextEditingController _roleController;
  String? _house;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _house = widget.boar.house;
    _penController = TextEditingController(text: widget.boar.pen ?? '');
    _breedController = TextEditingController(text: widget.boar.breed ?? '');
    _ageController = TextEditingController(text: widget.boar.age ?? '');
    _roleController = TextEditingController(text: widget.boar.role ?? '');
  }

  @override
  void dispose() {
    _penController.dispose();
    _breedController.dispose();
    _ageController.dispose();
    _roleController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    try {
      await ApiService.updatePig(widget.boar.id, {
        'house': _house,
        'pen': _penController.text.trim().isEmpty
            ? null
            : _penController.text.trim(),
        'breed': _breedController.text.trim().isEmpty
            ? null
            : _breedController.text.trim(),
        'age': _ageController.text.trim().isEmpty
            ? null
            : _ageController.text.trim(),
        'role': _roleController.text.trim().isEmpty
            ? null
            : _roleController.text.trim(),
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
    return _shell(
      context: context,
      title: 'Edit ${widget.boar.tag}',
      subtitle: 'Update boar location, breed, age, or role',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Label('House'),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _house,
                        decoration: _input(),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('—')),
                          for (final h in widget.houses)
                            DropdownMenuItem(
                                value: h.code, child: Text(h.code)),
                        ],
                        onChanged: (v) => setState(() => _house = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Label('Pen'),
                      const SizedBox(height: 6),
                      TextFormField(
                          controller: _penController, decoration: _input()),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Label('Breed'),
                      const SizedBox(height: 6),
                      TextFormField(
                          controller: _breedController, decoration: _input()),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Label('Age'),
                      const SizedBox(height: 6),
                      TextFormField(
                          controller: _ageController, decoration: _input()),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const _Label('Role'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _roleController,
              minLines: 2,
              maxLines: 3,
              decoration: _input(),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: _PrimaryBtn(
                    onPressed: _submitting ? null : _submit,
                    label: 'Save changes',
                  ),
                ),
                const SizedBox(width: 10),
                _CancelBtn(
                  onPressed:
                      _submitting ? null : () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// LITTER — Add + Edit
// =====================================================================

class AddLitterDialog extends StatefulWidget {
  const AddLitterDialog({super.key, required this.sows});
  final List<Sow> sows;
  @override
  State<AddLitterDialog> createState() => _AddLitterDialogState();
}

class _AddLitterDialogState extends State<AddLitterDialog> {
  final _formKey = GlobalKey<FormState>();
  final _litterIdController = TextEditingController();
  final _countController = TextEditingController(text: '0');
  final _noteController = TextEditingController();
  String? _sowId;
  DateTime _born = DateTime.now();
  bool _submitting = false;

  @override
  void dispose() {
    _litterIdController.dispose();
    _countController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _autoSuggestLitterId() {
    if (_sowId == null) return;
    final sow = widget.sows.firstWhere((s) => s.id == _sowId);
    final yy = DateFormat('yy').format(_born);
    final mm = DateFormat('MM').format(_born);
    _litterIdController.text = 'L-${sow.tag}-$yy$mm';
  }

  Future<void> _pickBorn() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _born,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
    );
    if (d != null && mounted) setState(() => _born = d);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_sowId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Pick a sow')));
      return;
    }
    setState(() => _submitting = true);
    try {
      await ApiService.createPiggeryLitter({
        'litterId': _litterIdController.text.trim(),
        'sowId': _sowId,
        'born': _born.toIso8601String(),
        'count': int.tryParse(_countController.text.trim()) ?? 0,
        if (_noteController.text.trim().isNotEmpty)
          'note': _noteController.text.trim(),
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
    return _shell(
      context: context,
      title: 'Add Litter',
      subtitle:
          'Register a litter. Convention: L-[sow tag]-[YYMM] (e.g. L-089-2606)',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Label('Sow *'),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _sowId,
              decoration: _input(),
              items: [
                for (final s in widget.sows)
                  DropdownMenuItem(
                    value: s.id,
                    child:
                        Text(s.pen != null ? '${s.tag}  (${s.pen})' : s.tag),
                  ),
              ],
              onChanged: (v) {
                setState(() => _sowId = v);
                if (_litterIdController.text.isEmpty) _autoSuggestLitterId();
              },
              validator: (v) => v == null ? 'Pick a sow' : null,
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Label('Litter ID *'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _litterIdController,
                        decoration: _input(hint: 'L-089-2606'),
                        validator: (v) => (v?.trim().isEmpty ?? true)
                            ? 'Litter ID is required'
                            : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DateRow(
                    label: 'Born',
                    value: _born,
                    onTap: _pickBorn,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const _Label('Piglets alive'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _countController,
              keyboardType: TextInputType.number,
              decoration: _input(hint: '0'),
              validator: (v) {
                final n = int.tryParse(v?.trim() ?? '');
                if (n == null || n < 0 || n > 30) {
                  return 'Must be 0..30';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            const _Label('Note'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _noteController,
              minLines: 2,
              maxLines: 3,
              decoration: _input(hint: 'Special observations…'),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: _PrimaryBtn(
                    onPressed: _submitting ? null : _submit,
                    label: 'Save Litter',
                  ),
                ),
                const SizedBox(width: 10),
                _CancelBtn(
                  onPressed:
                      _submitting ? null : () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class EditLitterDialog extends StatefulWidget {
  const EditLitterDialog({super.key, required this.litter});
  final Litter litter;
  @override
  State<EditLitterDialog> createState() => _EditLitterDialogState();
}

class _EditLitterDialogState extends State<EditLitterDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _countController;
  late final TextEditingController _noteController;
  late DateTime _born;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _countController =
        TextEditingController(text: '${widget.litter.count}');
    _noteController = TextEditingController(text: widget.litter.note ?? '');
    _born = widget.litter.born ?? DateTime.now();
  }

  @override
  void dispose() {
    _countController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickBorn() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _born,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
    );
    if (d != null && mounted) setState(() => _born = d);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    try {
      await ApiService.updatePiggeryLitter(widget.litter.id, {
        'born': _born.toIso8601String(),
        'count': int.tryParse(_countController.text.trim()) ?? 0,
        'note': _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
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
    return _shell(
      context: context,
      title: 'Edit ${widget.litter.litterId}',
      subtitle: widget.litter.sowTag == null
          ? 'Update piglet count, born date, or note'
          : 'Sow ${widget.litter.sowTag} · pen ${widget.litter.pen ?? '—'}',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DateRow(label: 'Born', value: _born, onTap: _pickBorn),
            const SizedBox(height: 14),
            const _Label('Piglets alive'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _countController,
              keyboardType: TextInputType.number,
              decoration: _input(),
              validator: (v) {
                final n = int.tryParse(v?.trim() ?? '');
                if (n == null || n < 0 || n > 30) return 'Must be 0..30';
                return null;
              },
            ),
            const SizedBox(height: 14),
            const _Label('Note'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _noteController,
              minLines: 2,
              maxLines: 3,
              decoration: _input(),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: _PrimaryBtn(
                    onPressed: _submitting ? null : _submit,
                    label: 'Save changes',
                  ),
                ),
                const SizedBox(width: 10),
                _CancelBtn(
                  onPressed:
                      _submitting ? null : () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// NURSERY — Add + Edit
// =====================================================================

class AddNurseryDialog extends StatefulWidget {
  const AddNurseryDialog({super.key});
  @override
  State<AddNurseryDialog> createState() => _AddNurseryDialogState();
}

class _AddNurseryDialogState extends State<AddNurseryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _penController = TextEditingController();
  final _countController = TextEditingController(text: '0');
  final _ageController = TextEditingController();
  final _breedController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime? _born;
  bool _submitting = false;

  @override
  void dispose() {
    _penController.dispose();
    _countController.dispose();
    _ageController.dispose();
    _breedController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickBorn() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _born ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
    );
    if (d != null && mounted) setState(() => _born = d);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    try {
      await ApiService.createPiggeryNursery({
        'pen': _penController.text.trim(),
        'count': int.tryParse(_countController.text.trim()) ?? 0,
        if (_ageController.text.trim().isNotEmpty)
          'age': _ageController.text.trim(),
        if (_born != null) 'born': _born!.toIso8601String(),
        if (_breedController.text.trim().isNotEmpty)
          'breed': _breedController.text.trim(),
        if (_noteController.text.trim().isNotEmpty)
          'note': _noteController.text.trim(),
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
    return _shell(
      context: context,
      title: 'Add Nursery Group',
      subtitle: 'Pen-level group of weaned piglets (typically in House C)',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Label('Pen *'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _penController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: _input(hint: 'C5'),
                        validator: (v) => (v?.trim().isEmpty ?? true)
                            ? 'Pen is required'
                            : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Label('Count *'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _countController,
                        keyboardType: TextInputType.number,
                        decoration: _input(hint: '9'),
                        validator: (v) {
                          final n = int.tryParse(v?.trim() ?? '');
                          if (n == null || n < 0 || n > 500) {
                            return 'Must be 0..500';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Label('Age'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _ageController,
                        decoration: _input(hint: '~1.5mo'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DateRow(
                    label: 'Born',
                    value: _born,
                    onTap: _pickBorn,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const _Label('Breed'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _breedController,
              decoration: _input(hint: 'Large White…'),
            ),
            const SizedBox(height: 14),
            const _Label('Note'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _noteController,
              minLines: 2,
              maxLines: 3,
              decoration: _input(hint: 'Source litter, special handling…'),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: _PrimaryBtn(
                    onPressed: _submitting ? null : _submit,
                    label: 'Save Group',
                  ),
                ),
                const SizedBox(width: 10),
                _CancelBtn(
                  onPressed:
                      _submitting ? null : () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class EditNurseryDialog extends StatefulWidget {
  const EditNurseryDialog({super.key, required this.group});
  final NurseryGroup group;
  @override
  State<EditNurseryDialog> createState() => _EditNurseryDialogState();
}

class _EditNurseryDialogState extends State<EditNurseryDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _penController;
  late final TextEditingController _countController;
  late final TextEditingController _ageController;
  late final TextEditingController _breedController;
  late final TextEditingController _noteController;
  late DateTime? _born;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _penController = TextEditingController(text: widget.group.pen);
    _countController =
        TextEditingController(text: '${widget.group.count}');
    _ageController = TextEditingController(text: widget.group.age ?? '');
    _breedController = TextEditingController(text: widget.group.breed ?? '');
    _noteController = TextEditingController(text: widget.group.note ?? '');
    _born = widget.group.born;
  }

  @override
  void dispose() {
    _penController.dispose();
    _countController.dispose();
    _ageController.dispose();
    _breedController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickBorn() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _born ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
    );
    if (d != null && mounted) setState(() => _born = d);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    try {
      await ApiService.updatePiggeryNursery(widget.group.id, {
        'pen': _penController.text.trim(),
        'count': int.tryParse(_countController.text.trim()) ?? 0,
        'age': _ageController.text.trim().isEmpty
            ? null
            : _ageController.text.trim(),
        'born': _born?.toIso8601String(),
        'breed': _breedController.text.trim().isEmpty
            ? null
            : _breedController.text.trim(),
        'note': _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
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
    return _shell(
      context: context,
      title: 'Edit nursery — ${widget.group.pen}',
      subtitle: 'Update count, age, breed, or note',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Label('Pen *'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _penController,
                        decoration: _input(),
                        validator: (v) => (v?.trim().isEmpty ?? true)
                            ? 'Pen required'
                            : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Label('Count *'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _countController,
                        keyboardType: TextInputType.number,
                        decoration: _input(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Label('Age'),
                      const SizedBox(height: 6),
                      TextFormField(
                          controller: _ageController, decoration: _input()),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DateRow(
                    label: 'Born',
                    value: _born,
                    onTap: _pickBorn,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const _Label('Breed'),
            const SizedBox(height: 6),
            TextFormField(
                controller: _breedController, decoration: _input()),
            const SizedBox(height: 14),
            const _Label('Note'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _noteController,
              minLines: 2,
              maxLines: 3,
              decoration: _input(),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: _PrimaryBtn(
                    onPressed: _submitting ? null : _submit,
                    label: 'Save changes',
                  ),
                ),
                const SizedBox(width: 10),
                _CancelBtn(
                  onPressed:
                      _submitting ? null : () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// FATTEN PEN — Add + Edit (Fattening = House E, Finishing = House F)
// =====================================================================

class AddPenDialog extends StatefulWidget {
  const AddPenDialog({super.key, required this.house});
  /// 'E' for Fattening, 'F' for Finishing.
  final String house;
  @override
  State<AddPenDialog> createState() => _AddPenDialogState();
}

class _AddPenDialogState extends State<AddPenDialog> {
  final _formKey = GlobalKey<FormState>();
  final _penController = TextEditingController();
  final _countController = TextEditingController(text: '0');
  final _ageController = TextEditingController();
  final _saleWindowController = TextEditingController();
  bool _saleReady = false;
  bool _submitting = false;

  @override
  void dispose() {
    _penController.dispose();
    _countController.dispose();
    _ageController.dispose();
    _saleWindowController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    try {
      await ApiService.createPiggeryPen({
        'pen': _penController.text.trim(),
        'house': widget.house,
        'count': int.tryParse(_countController.text.trim()) ?? 0,
        if (_ageController.text.trim().isNotEmpty)
          'age': _ageController.text.trim(),
        'saleReady': _saleReady,
        if (_saleWindowController.text.trim().isNotEmpty)
          'saleWindow': _saleWindowController.text.trim(),
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
    final isFinishing = widget.house == 'F';
    return _shell(
      context: context,
      title: 'Add pen — House ${widget.house}',
      subtitle: isFinishing
          ? 'Finishing pen (Sam Bwira) — final stage before FC delivery'
          : 'Fattening pen (David) — Beaconners building weight',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Label('Pen *'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _penController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: _input(
                            hint: '${widget.house}21'),
                        validator: (v) => (v?.trim().isEmpty ?? true)
                            ? 'Pen is required'
                            : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Label('Count *'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _countController,
                        keyboardType: TextInputType.number,
                        decoration: _input(hint: '7'),
                        validator: (v) {
                          final n = int.tryParse(v?.trim() ?? '');
                          if (n == null || n < 0 || n > 200) {
                            return 'Must be 0..200';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const _Label('Age'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _ageController,
              decoration: _input(hint: '5-6mo · 3mo · 2mo'),
            ),
            if (isFinishing) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Switch(
                    value: _saleReady,
                    onChanged: (v) => setState(() => _saleReady = v),
                    activeThumbColor: _primary,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Sale-ready (5-6 mo)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _primary,
                    ),
                  ),
                ],
              ),
              if (!_saleReady) ...[
                const SizedBox(height: 8),
                const _Label('Sale window'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _saleWindowController,
                  decoration: _input(hint: 'Aug-Sep 2026'),
                ),
              ],
            ],
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: _PrimaryBtn(
                    onPressed: _submitting ? null : _submit,
                    label: 'Save Pen',
                  ),
                ),
                const SizedBox(width: 10),
                _CancelBtn(
                  onPressed:
                      _submitting ? null : () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class EditPenDialog extends StatefulWidget {
  const EditPenDialog({super.key, required this.pen});
  final FattenPen pen;
  @override
  State<EditPenDialog> createState() => _EditPenDialogState();
}

class _EditPenDialogState extends State<EditPenDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _countController;
  late final TextEditingController _ageController;
  late final TextEditingController _saleWindowController;
  late bool _saleReady;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _countController = TextEditingController(text: '${widget.pen.count}');
    _ageController = TextEditingController(text: widget.pen.age ?? '');
    _saleWindowController =
        TextEditingController(text: widget.pen.saleWindow ?? '');
    _saleReady = widget.pen.saleReady;
  }

  @override
  void dispose() {
    _countController.dispose();
    _ageController.dispose();
    _saleWindowController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    try {
      await ApiService.updatePiggeryPen(widget.pen.id, {
        'count': int.tryParse(_countController.text.trim()) ?? 0,
        'age': _ageController.text.trim().isEmpty
            ? null
            : _ageController.text.trim(),
        'saleReady': _saleReady,
        'saleWindow': _saleWindowController.text.trim().isEmpty
            ? null
            : _saleWindowController.text.trim(),
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
    final isFinishing = widget.pen.house == 'F';
    return _shell(
      context: context,
      title: 'Edit pen ${widget.pen.pen}',
      subtitle: 'House ${widget.pen.house} · '
          '${isFinishing ? 'Finishing' : 'Fattening'}',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Label('Count *'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _countController,
                        keyboardType: TextInputType.number,
                        decoration: _input(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Label('Age'),
                      const SizedBox(height: 6),
                      TextFormField(
                          controller: _ageController, decoration: _input()),
                    ],
                  ),
                ),
              ],
            ),
            if (isFinishing) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Switch(
                    value: _saleReady,
                    onChanged: (v) => setState(() => _saleReady = v),
                    activeThumbColor: _primary,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Sale-ready (5-6 mo)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _primary,
                    ),
                  ),
                ],
              ),
              if (!_saleReady) ...[
                const SizedBox(height: 8),
                const _Label('Sale window'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _saleWindowController,
                  decoration: _input(hint: 'Aug-Sep 2026'),
                ),
              ],
            ],
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: _PrimaryBtn(
                    onPressed: _submitting ? null : _submit,
                    label: 'Save changes',
                  ),
                ),
                const SizedBox(width: 10),
                _CancelBtn(
                  onPressed:
                      _submitting ? null : () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// Date row helper (reused across dialogs)
// =====================================================================

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.label,
    required this.value,
    required this.onTap,
  });
  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(label),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0x33000000)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value == null
                        ? '—'
                        : DateFormat('dd/MM/yyyy').format(value!),
                    style: TextStyle(
                      fontSize: 14,
                      color: value == null ? _txt3 : Colors.black87,
                    ),
                  ),
                ),
                const Icon(Icons.calendar_today, size: 16, color: _txt2),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
