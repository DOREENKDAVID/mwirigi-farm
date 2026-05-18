import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/cow.dart';
import '../../core/service/api_service.dart';
import '../../offline/repositories/cow_repository.dart';

/// Modal `m-repro` from the HTML mockup, replicated exactly:
///
///   Row 1:  [ Cow tag ]   [ Event type (dropdown) ]
///   Row 2:  [ Date    ]   [ Semen / Bull          ]
///   Save / Cancel
///
/// Event type options (literal HTML order):
///   - Artificial Insemination → POST /reproduction { eventType: AI }
///   - Natural service         → POST /reproduction { eventType: AI }
///   - Calving                 → POST /reproduction { eventType: CALVING }
///   - Pregnancy confirmed     → POST /reproduction/confirm
///
/// Note: Natural service shares the AI event type because the schema does
/// not distinguish them today. The Semen / Bull field is reused for the
/// bull tag in the NS case (it goes into `sireCode`).
class LogAiCalvingDialog extends StatefulWidget {
  const LogAiCalvingDialog({super.key});

  @override
  State<LogAiCalvingDialog> createState() => _LogAiCalvingDialogState();
}

enum _EventChoice {
  artificialInsemination('Artificial Insemination'),
  naturalService('Natural service'),
  calving('Calving'),
  pregnancyConfirmed('Pregnancy confirmed');

  const _EventChoice(this.label);
  final String label;
}

class _LogAiCalvingDialogState extends State<LogAiCalvingDialog> {
  final _formKey = GlobalKey<FormState>();
  final _tagController = TextEditingController();
  final _bullController = TextEditingController();

  _EventChoice _choice = _EventChoice.artificialInsemination;
  DateTime _date = DateTime.now();
  bool _submitting = false;
  List<Cow> _cows = const [];

  @override
  void initState() {
    super.initState();
    _loadCows();
  }

  Future<void> _loadCows() async {
    // Try the server first so the dropdown is always populated even
    // when the local Drift mirror hasn't been hydrated yet (e.g. the
    // user opened the dialog before visiting the Cows tab). Fall
    // back to the local cache if offline so the dialog still works.
    try {
      final raw = await ApiService.getCows();
      final cows = raw
          .whereType<Map>()
          .map((m) => Cow.fromJson(m.cast<String, dynamic>()))
          .toList();
      if (!mounted) return;
      setState(() => _cows = cows);
      // Opportunistically refresh the local mirror so subsequent
      // offline opens of this dialog show the same list.
      unawaited(CowRepository.instance.refreshFromServer());
    } catch (_) {
      final cows = await CowRepository.instance.listLocal();
      if (!mounted) return;
      setState(() => _cows = cows);
    }
  }

  @override
  void dispose() {
    _tagController.dispose();
    _bullController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _submitting = true);
    try {
      final tag = _tagController.text.trim();
      final bull = _bullController.text.trim();
      final dateIso = _date.toIso8601String();

      switch (_choice) {
        case _EventChoice.artificialInsemination:
        case _EventChoice.naturalService:
          await ApiService.createReproductionRecord({
            'eventType': 'AI',
            'tag': tag,
            'eventDate': dateIso,
            if (bull.isNotEmpty) 'sireCode': bull,
          });
          break;
        case _EventChoice.calving:
          await ApiService.createReproductionRecord({
            'eventType': 'CALVING',
            'tag': tag,
            'eventDate': dateIso,
          });
          break;
        case _EventChoice.pregnancyConfirmed:
          await ApiService.confirmReproductionPregnancy({
            'tag': tag,
            'checkDate': dateIso,
          });
          break;
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

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF27500A);

    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Text(
        'Log AI / Calving Record',
        style: TextStyle(
          color: primary,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Record insemination or calving event',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 18),
                // Two-up on tablets / web, stacked on narrow phones.
                // Side-by-side gave the dropdown label "Cow tag" and
                // the date text "18 May 2026" only ~140dp each, which
                // wrapped to 2-3 lines and looked broken.
                _pair(_buildCowTagField(), _buildEventTypeField()),
                const SizedBox(height: 14),
                _pair(_buildDateField(), _buildBullField()),
              ],
            ),
          ),
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

  /// Renders two form fields side-by-side on tablets / web and
  /// stacked on narrow phones. The 420dp breakpoint matches the
  /// dialog's content max-width of 540dp minus a margin.
  Widget _pair(Widget first, Widget second) {
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth >= 420) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: first),
              const SizedBox(width: 12),
              Expanded(child: second),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            first,
            const SizedBox(height: 12),
            second,
          ],
        );
      },
    );
  }

  Widget _buildCowTagField() {
    return Autocomplete<Cow>(
      optionsBuilder: (text) {
        final q = text.text.trim().toLowerCase();
        if (q.isEmpty) return _cows;
        return _cows.where((c) {
          return c.tag.toLowerCase().contains(q) ||
              (c.nickname ?? '').toLowerCase().contains(q);
        });
      },
      displayStringForOption: (c) => c.tag,
      onSelected: (c) {
        _tagController.text = c.tag;
      },
      fieldViewBuilder: (
        context,
        textController,
        focusNode,
        onFieldSubmitted,
      ) {
        // Keep our own _tagController in sync with the Autocomplete's
        // internal one so _submit() doesn't need to know about it.
        textController.addListener(() {
          if (_tagController.text != textController.text) {
            _tagController.text = textController.text;
          }
        });
        return TextFormField(
          controller: textController,
          focusNode: focusNode,
          textCapitalization: TextCapitalization.characters,
          autocorrect: false,
          decoration: InputDecoration(
            labelText: 'Cow tag',
            hintText: _cows.isEmpty
                ? 'Type or pick…'
                : 'Pick from ${_cows.length} cows',
            border: const OutlineInputBorder(),
            suffixIcon: const Icon(Icons.arrow_drop_down, size: 20),
          ),
          validator: (value) {
            final v = value?.trim() ?? '';
            if (v.isEmpty) return 'Cow tag is required';
            return null;
          },
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final list = options.toList();
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: 260,
                maxWidth: 320,
              ),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final c = list[i];
                  return ListTile(
                    dense: true,
                    title: Text(c.tag),
                    subtitle: c.nickname == null
                        ? null
                        : Text(
                            c.nickname!,
                            style: const TextStyle(fontSize: 11),
                          ),
                    onTap: () => onSelected(c),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEventTypeField() {
    return DropdownButtonFormField<_EventChoice>(
      initialValue: _choice,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Event type',
        border: OutlineInputBorder(),
      ),
      items: [
        for (final c in _EventChoice.values)
          DropdownMenuItem(value: c, child: Text(c.label)),
      ],
      onChanged:
          _submitting ? null : (v) => setState(() => _choice = v ?? _choice),
    );
  }

  Widget _buildDateField() {
    return InkWell(
      onTap: _submitting ? null : _pickDate,
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Date',
          border: OutlineInputBorder(),
          suffixIcon: Icon(Icons.calendar_today, size: 18),
        ),
        child: Text(
          DateFormat('d MMM yyyy').format(_date),
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.visible,
        ),
      ),
    );
  }

  Widget _buildBullField() {
    return TextFormField(
      controller: _bullController,
      enabled: !_submitting,
      decoration: const InputDecoration(
        labelText: 'Semen / Bull',
        hintText: 'Semen code or bull tag',
        border: OutlineInputBorder(),
      ),
    );
  }
}
