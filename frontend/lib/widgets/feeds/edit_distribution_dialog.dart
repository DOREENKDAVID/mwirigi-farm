// Edit one row of the daily distribution table — the kg/day that goes
// to a single livestock unit. Mirrors the v4.1 design language: rounded
// inputs, primary green save button, three side-by-side feed-type
// fields. Submits via POST /feeds/distribution which upserts on
// `livestockUnit`.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/feeds.dart';
import '../../core/service/api_service.dart';

class EditDistributionDialog extends StatefulWidget {
  const EditDistributionDialog({super.key, required this.entry});
  final FeedDistribution entry;

  @override
  State<EditDistributionDialog> createState() =>
      _EditDistributionDialogState();
}

class _EditDistributionDialogState extends State<EditDistributionDialog> {
  static const _primary = Color(0xFF27500A);
  static const _txt2 = Color(0xFF6B7770);
  static const _txt3 = Color(0xFF99A39B);

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _concentrate;
  late final TextEditingController _silage;
  late final TextEditingController _napier;
  late final TextEditingController _animals;

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _concentrate =
        TextEditingController(text: _seed(widget.entry.concentrateKg));
    _silage = TextEditingController(text: _seed(widget.entry.silageKg));
    _napier = TextEditingController(text: _seed(widget.entry.napierKg));
    _animals = TextEditingController(text: '${widget.entry.animalCount}');
  }

  @override
  void dispose() {
    _concentrate.dispose();
    _silage.dispose();
    _napier.dispose();
    _animals.dispose();
    super.dispose();
  }

  static String _seed(double v) {
    if (v == 0) return '';
    return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    try {
      await ApiService.upsertFeedDistribution({
        'livestockUnit': widget.entry.livestockUnit,
        'concentrateKg':
            double.tryParse(_concentrate.text.trim()) ?? 0,
        'silageKg': double.tryParse(_silage.text.trim()) ?? 0,
        'napierKg': double.tryParse(_napier.text.trim()) ?? 0,
        'animalCount': int.tryParse(_animals.text.trim()) ??
            widget.entry.animalCount,
      });
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 640),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Edit daily distribution',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.entry.unitLabel,
                  style: const TextStyle(fontSize: 12, color: _txt2),
                ),
                const SizedBox(height: 18),

                _FieldLabel('Concentrate (kg/day)'),
                const SizedBox(height: 6),
                _NumberField(
                  controller: _concentrate,
                  hint: '0',
                ),
                const SizedBox(height: 14),

                _FieldLabel('Silage (kg/day)'),
                const SizedBox(height: 6),
                _NumberField(
                  controller: _silage,
                  hint: '0',
                ),
                const SizedBox(height: 14),

                _FieldLabel('Napier (kg/day)'),
                const SizedBox(height: 6),
                _NumberField(
                  controller: _napier,
                  hint: '0',
                ),
                const SizedBox(height: 14),

                _FieldLabel('Animal count'),
                const SizedBox(height: 6),
                _NumberField(
                  controller: _animals,
                  hint: '${widget.entry.animalCount}',
                  integerOnly: true,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Used by the unit label and per-animal calculations '
                  '(e.g. "Dairy (42 milking)").',
                  style: TextStyle(fontSize: 11, color: _txt3),
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
                          textStyle: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w800),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
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
                            : const Text('Save'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: _submitting
                          ? null
                          : () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _txt2,
                        side: const BorderSide(color: Color(0x33000000)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Cancel',
                          style: TextStyle(fontWeight: FontWeight.w700)),
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
}

class _FieldLabel extends StatelessWidget {
  // ignore: unused_element_parameter
  const _FieldLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.5,
        color: Color(0xFF6B7770),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.hint,
    this.integerOnly = false,
  });
  final TextEditingController controller;
  final String hint;
  final bool integerOnly;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: !integerOnly),
      inputFormatters: integerOnly
          ? [FilteringTextInputFormatter.digitsOnly]
          : [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF99A39B)),
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
          borderSide:
              const BorderSide(color: Color(0xFF27500A), width: 1.5),
        ),
      ),
      validator: (value) {
        final v = value?.trim() ?? '';
        if (v.isEmpty) return null; // 0 is OK
        if (integerOnly) {
          final n = int.tryParse(v);
          if (n == null || n < 0) return 'Non-negative integer';
          if (n > 100000) return 'Unrealistic value';
        } else {
          final n = double.tryParse(v);
          if (n == null || n < 0) return 'Non-negative number';
          if (n > 100000) return 'Unrealistic value';
        }
        return null;
      },
    );
  }
}
