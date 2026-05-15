import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/piggery.dart';
import '../../core/service/api_service.dart';

/// "Log Farrowing Record" modal — mirrors the v4.2 HTML mockup field-for-
/// field.
///
///   Sow tag *  (added — backend requires a sow link)
///   Farrowing date *      | Service date   (auto-fills 114 days back)
///   Expectant sows        | Day of farrowing  (typical: 114)
///   ── Litter categories ──
///   Winners | Fatteners | Beaconners *
///   Total alive (auto)    | Dead piglets
///   Remarks
///   ✓ Save Farrowing Record   Cancel
///
/// Backend body sent:
///   sowId, date, service?, pigletsBorn (alive+dead), pigletsAlive
///   (winners+fatteners+beaconners), pigletsDead, winners, fatteners,
///   beaconners, remarks
class LogFarrowingDialog extends StatefulWidget {
  const LogFarrowingDialog({super.key, required this.sows});

  final List<Sow> sows;

  @override
  State<LogFarrowingDialog> createState() => _LogFarrowingDialogState();
}

class _LogFarrowingDialogState extends State<LogFarrowingDialog> {
  static const _primary = Color(0xFF27500A);
  static const _txt2 = Color(0xFF6B7770);
  static const _txt3 = Color(0xFF99A39B);
  static const _winColor = Color(0xFF7A2E00);
  static const _fatColor = Color(0xFF854F0B);
  static const _beaColor = Color(0xFF27500A);

  final _formKey = GlobalKey<FormState>();
  final _expController = TextEditingController();
  final _dofController = TextEditingController(text: '114');
  final _winController = TextEditingController();
  final _fatController = TextEditingController();
  final _beaController = TextEditingController();
  final _deadController = TextEditingController(text: '0');
  final _remarksController = TextEditingController();

  String? _sowId;
  DateTime _date = DateTime.now();
  DateTime _service = DateTime.now().subtract(const Duration(days: 114));
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.sows.length == 1) _sowId = widget.sows.first.id;
    _winController.addListener(_recalc);
    _fatController.addListener(_recalc);
    _beaController.addListener(_recalc);
  }

  @override
  void dispose() {
    _winController.removeListener(_recalc);
    _fatController.removeListener(_recalc);
    _beaController.removeListener(_recalc);
    _expController.dispose();
    _dofController.dispose();
    _winController.dispose();
    _fatController.dispose();
    _beaController.dispose();
    _deadController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  void _recalc() => setState(() {});

  int get _alive {
    final w = int.tryParse(_winController.text.trim()) ?? 0;
    final f = int.tryParse(_fatController.text.trim()) ?? 0;
    final b = int.tryParse(_beaController.text.trim()) ?? 0;
    return w + f + b;
  }

  Future<void> _pickFarrowing() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
    );
    if (picked != null && mounted) {
      setState(() {
        _date = picked;
        // Auto-fill service date 114 (or user-entered) days before.
        final dof = int.tryParse(_dofController.text.trim()) ?? 114;
        _service = picked.subtract(Duration(days: dof));
      });
    }
  }

  Future<void> _pickService() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _service,
      firstDate: DateTime(_date.year - 2),
      lastDate: _date,
    );
    if (picked != null && mounted) setState(() => _service = picked);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_sowId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a sow')),
      );
      return;
    }

    final winners = int.tryParse(_winController.text.trim()) ?? 0;
    final fatteners = int.tryParse(_fatController.text.trim()) ?? 0;
    final beaconners = int.tryParse(_beaController.text.trim()) ?? 0;
    final dead = int.tryParse(_deadController.text.trim()) ?? 0;
    final alive = winners + fatteners + beaconners;
    if (alive == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter at least one piglet count (Winners, Fatteners, or Beaconners)',
          ),
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await ApiService.logFarrowing({
        'sowId': _sowId,
        'date': _date.toIso8601String(),
        'service': _service.toIso8601String(),
        'pigletsBorn': alive + dead,
        'pigletsAlive': alive,
        'pigletsDead': dead,
        'winners': winners,
        'fatteners': fatteners,
        'beaconners': beaconners,
        if (_remarksController.text.trim().isNotEmpty)
          'remarks': _remarksController.text.trim(),
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
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 720),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Log Farrowing Record',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _primary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Categorize the litter into Winners · Fatteners · Beaconners',
                  style: TextStyle(fontSize: 12, color: _txt2),
                ),
                const SizedBox(height: 18),

                // Sow dropdown (required by backend; not in HTML mockup).
                _FieldLabel('Sow tag *'),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _sowId,
                  decoration: _inputDecoration(),
                  items: [
                    for (final s in widget.sows)
                      DropdownMenuItem(
                        value: s.id,
                        child: Text(
                          s.pen != null ? '${s.tag}  (${s.pen})' : s.tag,
                        ),
                      ),
                  ],
                  onChanged: _submitting
                      ? null
                      : (v) => setState(() => _sowId = v),
                  validator: (v) => v == null ? 'Pick a sow' : null,
                ),
                const SizedBox(height: 16),

                // Row 1: Farrowing date | Service date
                _TwoCol(
                  left: _DateField(
                    label: 'Farrowing date *',
                    value: _date,
                    onTap: _submitting ? null : _pickFarrowing,
                  ),
                  right: _DateField(
                    label: 'Service date',
                    value: _service,
                    onTap: _submitting ? null : _pickService,
                    helper: 'Auto-fills 114 days before farrowing',
                  ),
                ),
                const SizedBox(height: 16),

                // Row 2: Expectant sows | Day of farrowing
                _TwoCol(
                  left: _NumberField(
                    label: 'Expectant sows',
                    controller: _expController,
                    hint: '0',
                  ),
                  right: _NumberField(
                    label: 'Day of farrowing',
                    controller: _dofController,
                    hint: '114',
                    helper: 'Typical: 114 (gestation)',
                  ),
                ),

                const SizedBox(height: 22),
                const Text(
                  'LITTER CATEGORIES',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: _primary,
                  ),
                ),
                const SizedBox(height: 4),
                const Divider(height: 1, color: Color(0x14000000)),
                const SizedBox(height: 14),

                // Row 3: Winners | Fatteners | Beaconners *
                LayoutBuilder(
                  builder: (context, c) {
                    final narrow = c.maxWidth < 460;
                    if (narrow) {
                      return Column(
                        children: [
                          _CategoryField(
                            label: 'WINNERS',
                            color: _winColor,
                            controller: _winController,
                          ),
                          const SizedBox(height: 12),
                          _CategoryField(
                            label: 'FATTENERS',
                            color: _fatColor,
                            controller: _fatController,
                          ),
                          const SizedBox(height: 12),
                          _CategoryField(
                            label: 'BEACONNERS *',
                            color: _beaColor,
                            controller: _beaController,
                            helper: 'Target: 100/month',
                          ),
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _CategoryField(
                            label: 'WINNERS',
                            color: _winColor,
                            controller: _winController,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _CategoryField(
                            label: 'FATTENERS',
                            color: _fatColor,
                            controller: _fatController,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _CategoryField(
                            label: 'BEACONNERS *',
                            color: _beaColor,
                            controller: _beaController,
                            helper: 'Target: 100/month',
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Row 4: Total alive (auto) | Dead piglets
                _TwoCol(
                  left: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FieldLabel('Total alive (auto)'),
                      const SizedBox(height: 6),
                      Container(
                        height: 52,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF5E3),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0x14000000)),
                        ),
                        child: Text(
                          _alive == 0 ? '' : '$_alive',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: _primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  right: _NumberField(
                    label: 'Dead piglets',
                    controller: _deadController,
                    hint: '0',
                  ),
                ),
                const SizedBox(height: 16),

                _FieldLabel('Remarks'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _remarksController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: _inputDecoration(
                    hint: 'Observations, health notes, sow tag, etc.',
                  ),
                ),

                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: _submitting ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: _primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        child: _submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('✓  Save Farrowing Record'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: _submitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _txt2,
                        side: const BorderSide(color: Color(0x33000000)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(fontWeight: FontWeight.w700),
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

  static InputDecoration _inputDecoration({String? hint}) => InputDecoration(
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
}

class _FieldLabel extends StatelessWidget {
  // ignore: unused_element_parameter
  const _FieldLabel(this.text, {this.color});
  final String text;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.5,
        color: color ?? const Color(0xFF6B7770),
      ),
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
            const SizedBox(width: 12),
            Expanded(child: right),
          ],
        );
      },
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
    this.helper,
  });
  final String label;
  final DateTime value;
  final VoidCallback? onTap;
  final String? helper;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
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
                    DateFormat('dd/MM/yyyy').format(value),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                const Icon(Icons.calendar_today,
                    size: 16, color: Color(0xFF6B7770)),
              ],
            ),
          ),
        ),
        if (helper != null) ...[
          const SizedBox(height: 6),
          Text(
            helper!,
            style: const TextStyle(fontSize: 11, color: Color(0xFF99A39B)),
          ),
        ],
      ],
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.label,
    required this.controller,
    this.hint,
    this.helper,
  });
  final String label;
  final TextEditingController controller;
  final String? hint;
  final String? helper;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: _LogFarrowingDialogState._inputDecoration(hint: hint),
          validator: (value) {
            final v = value?.trim() ?? '';
            if (v.isEmpty) return null;
            final n = int.tryParse(v);
            if (n == null || n < 0) return 'Non-negative integer';
            if (n > 200) return 'Unrealistic value';
            return null;
          },
        ),
        if (helper != null) ...[
          const SizedBox(height: 6),
          Text(
            helper!,
            style: const TextStyle(fontSize: 11, color: Color(0xFF99A39B)),
          ),
        ],
      ],
    );
  }
}

class _CategoryField extends StatelessWidget {
  const _CategoryField({
    required this.label,
    required this.color,
    required this.controller,
    this.helper,
  });
  final String label;
  final Color color;
  final TextEditingController controller;
  final String? helper;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label, color: color),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: _LogFarrowingDialogState._inputDecoration(hint: '0'),
          validator: (value) {
            final v = value?.trim() ?? '';
            if (v.isEmpty) return null;
            final n = int.tryParse(v);
            if (n == null || n < 0) return 'Non-negative integer';
            if (n > 30) return 'Unrealistic value';
            return null;
          },
        ),
        if (helper != null) ...[
          const SizedBox(height: 6),
          Text(
            helper!,
            style: const TextStyle(fontSize: 11, color: Color(0xFF99A39B)),
          ),
        ],
      ],
    );
  }
}
