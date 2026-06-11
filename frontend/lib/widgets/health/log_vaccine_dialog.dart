import 'package:flutter/material.dart';

import '../../core/models/health.dart';
import '../../core/service/api_service.dart';

/// "Log Vaccination" modal — matches the HTML modal field-for-field:
///   Vaccine name (dropdown of registered protocols) · Unit (read-only,
///   filled from selected protocol) · Animals · Date done · Next due
///
/// The HTML mockup shows a free-text vaccine name input, but the
/// backend requires a `protocolId` so the schedule view stays correct.
/// Switching to a dropdown of registered protocols matches the API
/// contract — same UX intent, no foot-gun.
class LogVaccineDialog extends StatefulWidget {
  const LogVaccineDialog({super.key});

  @override
  State<LogVaccineDialog> createState() => _LogVaccineDialogState();
}

class _LogVaccineDialogState extends State<LogVaccineDialog> {
  final _formKey = GlobalKey<FormState>();
  final _animalsController = TextEditingController();

  Future<List<VaccineProtocol>>? _protocolsFuture;
  VaccineProtocol? _selected;
  DateTime _dateDone = DateTime.now();
  DateTime? _nextDueOverride;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _protocolsFuture = _loadProtocols();
  }

  @override
  void dispose() {
    _animalsController.dispose();
    super.dispose();
  }

  Future<List<VaccineProtocol>> _loadProtocols() async {
    final raw = await ApiService.getHealthProtocols();
    return raw
        .whereType<Map>()
        .map((m) => VaccineProtocol.fromJson(m.cast<String, dynamic>()))
        .toList();
  }

  Future<void> _pickDate({required bool isNextDue}) async {
    final initial = isNextDue ? (_nextDueOverride ?? _dateDone) : _dateDone;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isNextDue) {
        _nextDueOverride = picked;
      } else {
        _dateDone = picked;
      }
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selected == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a vaccine protocol')),
      );
      return;
    }

    final animalCount = int.tryParse(_animalsController.text.trim()) ?? 0;
    setState(() => _submitting = true);
    try {
      await ApiService.createHealthVaccination({
        'protocolId': _selected!.id,
        'unit': _selected!.unit,
        'animalCount': animalCount,
        'administeredAt': _dateDone.toIso8601String(),
        if (_nextDueOverride != null)
          'nextDueOverride': _nextDueOverride!.toIso8601String(),
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
    const primary = Color(0xFF27500A);

    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Text(
        'Log Vaccination',
        style: TextStyle(
          color: primary,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: FutureBuilder<List<VaccineProtocol>>(
          future: _protocolsFuture,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snap.hasError) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Could not load protocols: ${snap.error}',
                  style:
                      const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              );
            }
            final protocols = snap.data ?? const [];
            return _Form(
              formKey: _formKey,
              protocols: protocols,
              selected: _selected,
              onSelect: (p) {
                setState(() => _selected = p);
              },
              animalsController: _animalsController,
              dateDone: _dateDone,
              nextDueOverride: _nextDueOverride,
              onPickDateDone: () => _pickDate(isNextDue: false),
              onPickNextDue: () => _pickDate(isNextDue: true),
              submitting: _submitting,
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          style: FilledButton.styleFrom(backgroundColor: primary),
          child: _submitting
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
      ],
    );
  }
}

class _Form extends StatelessWidget {
  const _Form({
    required this.formKey,
    required this.protocols,
    required this.selected,
    required this.onSelect,
    required this.animalsController,
    required this.dateDone,
    required this.nextDueOverride,
    required this.onPickDateDone,
    required this.onPickNextDue,
    required this.submitting,
  });

  final GlobalKey<FormState> formKey;
  final List<VaccineProtocol> protocols;
  final VaccineProtocol? selected;
  final ValueChanged<VaccineProtocol?> onSelect;
  final TextEditingController animalsController;
  final DateTime dateDone;
  final DateTime? nextDueOverride;
  final VoidCallback onPickDateDone;
  final VoidCallback onPickNextDue;
  final bool submitting;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Record a completed vaccination',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<VaccineProtocol>(
                    initialValue: selected,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Vaccine name *',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final p in protocols)
                        DropdownMenuItem(
                          value: p,
                          child: Text(
                            '${p.name} · ${p.unit}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: submitting ? null : onSelect,
                    validator: (v) =>
                        v == null ? 'Pick a vaccine protocol' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Unit',
                      border: OutlineInputBorder(),
                    ),
                    child: Text(
                      selected?.unit ?? '—',
                      style: TextStyle(
                        fontSize: 13,
                        color: selected == null
                            ? Colors.black38
                            : Colors.black87,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Animals — full width so it never gets squeezed on phone.
            TextFormField(
              controller: animalsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Animals *',
                hintText: '200',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final v = value?.trim() ?? '';
                final n = int.tryParse(v);
                if (n == null || n <= 0) return 'Enter > 0';
                return null;
              },
            ),
            const SizedBox(height: 14),
            // Date done + Next due share a row — two fields each get
            // roughly half the dialog width, which is comfortable on phone.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: InkWell(
                    onTap: submitting ? null : onPickDateDone,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Date done *',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_month, size: 18),
                      ),
                      child: Text(
                        _formatDate(dateDone),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: submitting ? null : onPickNextDue,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Next due',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_month, size: 18),
                      ),
                      child: Text(
                        nextDueOverride == null
                            ? 'dd/mm/yyyy'
                            : _formatDate(nextDueOverride!),
                        style: TextStyle(
                          fontSize: 13,
                          color: nextDueOverride == null
                              ? Colors.black38
                              : Colors.black87,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
