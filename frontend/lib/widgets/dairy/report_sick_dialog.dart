import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/service/api_service.dart';

/// "Report Sick Animal" dialog. Mirrors the v4.1 mockup:
///
///   Unit *               | Animal tag / pen *
///   Severity *           | Reported by
///   Symptoms / observations *
///   Onset
///   [Send to Vet] [Cancel]
///
/// Submits to POST /api/health/treatments with:
///   * tag         ← Animal tag/pen
///   * unit        ← Unit dropdown (HealthUnit)
///   * diagnosis   ← Symptoms (the backend needs a non-empty value;
///                   we feed the symptom text in)
///   * medication  ← "Pending vet review" by default — the vet will
///                   patch it once they triage the case
///   * notes       ← `[Severity] reported_by` so the queue list still
///                   surfaces severity at a glance
///   * startDate   ← Onset
///
/// The backend has no dedicated `severity` column today; we encode it
/// in `notes` so adding the column later is purely additive.
class ReportSickDialog extends StatefulWidget {
  const ReportSickDialog({
    super.key,
    this.defaultUnit = 'Dairy',
    this.tagSuggestion,
  });

  /// Initial unit value — caller usually passes the current section
  /// (e.g. dairy page passes 'Dairy', layers page 'Layers'). Falls
  /// back to 'Dairy' which is the most common case.
  final String defaultUnit;

  /// Pre-fills the tag field (e.g. when launching from a row action
  /// on a specific cow).
  final String? tagSuggestion;

  @override
  State<ReportSickDialog> createState() => _ReportSickDialogState();
}

class _ReportSickDialogState extends State<ReportSickDialog> {
  static const _primary = Color(0xFF27500A);

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _tag;
  late final TextEditingController _reportedBy;
  late final TextEditingController _symptoms;

  // Matches the backend HealthUnit enum: Dairy / Piggery / Layers /
  // Doopers / Feedlot. Stored as a string so we can drop it straight
  // into the API payload.
  static const _units = ['Dairy', 'Layers', 'Piggery', 'Doopers', 'Feedlot'];
  late String _unit;

  // Severity is UI-only for now (no backend column). Encoded into
  // notes on submit. Three steps mirror the design mock.
  static const _severities = [
    ('MILD', '🟢 Mild — monitor only'),
    ('MODERATE', '🟡 Moderate — vet attention soon'),
    ('SEVERE', '🔴 Severe — urgent'),
  ];
  String _severity = 'MODERATE';

  DateTime _onset = DateTime.now();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _unit = _units.contains(widget.defaultUnit) ? widget.defaultUnit : 'Dairy';
    _tag = TextEditingController(text: widget.tagSuggestion ?? '');
    _reportedBy = TextEditingController();
    _symptoms = TextEditingController();
  }

  @override
  void dispose() {
    _tag.dispose();
    _reportedBy.dispose();
    _symptoms.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    setState(() => _submitting = true);
    try {
      final reportedBy = _reportedBy.text.trim();
      final notes = StringBuffer('[$_severity]');
      if (reportedBy.isNotEmpty) notes.write(' reported by $reportedBy');
      await ApiService.createHealthTreatment({
        'tag': _tag.text.trim(),
        'unit': _unit,
        // Backend requires diagnosis + medication >= 2 chars. We pass
        // the symptom text as diagnosis (vet refines later) and a
        // sentinel medication value the vet patches via PATCH.
        'diagnosis': _symptoms.text.trim(),
        'medication': 'Pending vet review',
        'startDate': _onset.toIso8601String(),
        if (reportedBy.isNotEmpty) 'attendingVet': reportedBy,
        'notes': notes.toString(),
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
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Text('🩺', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Report Sick Animal',
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
                RichText(
                  text: const TextSpan(
                    style: TextStyle(fontSize: 13, color: Color(0xFF7A7A7A)),
                    children: [
                      TextSpan(text: "Goes straight to the "),
                      TextSpan(
                        text: 'vet',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      TextSpan(text: " queue for review."),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                _TwoCol(
                  left: _Field(
                    label: 'UNIT *',
                    child: DropdownButtonFormField<String>(
                      initialValue: _unit,
                      decoration: _decoration(),
                      isExpanded: true,
                      items: [
                        for (final u in _units)
                          DropdownMenuItem(value: u, child: Text(u)),
                      ],
                      onChanged: _submitting
                          ? null
                          : (v) => setState(() => _unit = v ?? _unit),
                    ),
                  ),
                  right: _Field(
                    label: 'ANIMAL TAG / PEN *',
                    child: TextFormField(
                      controller: _tag,
                      decoration: _decoration(
                        hint: 'e.g. MW-047 or A6 or House A',
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Tag is required'
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _TwoCol(
                  left: _Field(
                    label: 'SEVERITY *',
                    child: DropdownButtonFormField<String>(
                      initialValue: _severity,
                      decoration: _decoration(),
                      isExpanded: true,
                      items: [
                        for (final (wire, label) in _severities)
                          DropdownMenuItem(value: wire, child: Text(label)),
                      ],
                      onChanged: _submitting
                          ? null
                          : (v) => setState(() => _severity = v ?? _severity),
                    ),
                  ),
                  right: _Field(
                    label: 'REPORTED BY',
                    child: TextFormField(
                      controller: _reportedBy,
                      decoration: _decoration(hint: 'e.g. Dr. Mwirigi'),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _Field(
                  label: 'SYMPTOMS / OBSERVATIONS *',
                  child: TextFormField(
                    controller: _symptoms,
                    maxLines: 3,
                    decoration: _decoration(
                      hint:
                          "What did you notice? E.g. 'off feed since morning', "
                          "'lameness on right hind', 'milk drop 30%', 'diarrhea', "
                          "'isolated from group'…",
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
                  label: 'ONSET',
                  child: InkWell(
                    onTap: _submitting
                        ? null
                        : () async {
                            final now = DateTime.now();
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _onset,
                              firstDate: DateTime(now.year - 1),
                              lastDate: now,
                            );
                            if (picked != null && mounted) {
                              setState(() => _onset = picked);
                            }
                          },
                    borderRadius: BorderRadius.circular(8),
                    child: InputDecorator(
                      decoration: _decoration().copyWith(
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
                        dateFmt.format(_onset),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: _submitting ? null : _submit,
                      icon: const Icon(Icons.send_outlined, size: 16),
                      label: const Text('Send to Vet'),
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
