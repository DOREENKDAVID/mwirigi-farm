import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/models/ngushish.dart';
import '../../core/service/api_service.dart';

/// PATCH-only dialog for an existing crop, laid out as a 2-column form
/// matching the design mock:
///
///   Crop *           |  Acreage *
///   Date Planted     |  Expected Harvest
///   Status           |  Destination
///   [Save]  [Cancel]
///
/// Builds a diff-based payload — only fields the user actually changed
/// are sent on the wire. Date fields can be cleared (sends null) which
/// is distinct from leaving them unchanged. Other crop properties not
/// shown here (perennial flag, notes, irrigation, harvest frequency)
/// stay untouched on the server.
class EditCropDialog extends StatefulWidget {
  const EditCropDialog({super.key, required this.crop});
  final CropView crop;

  @override
  State<EditCropDialog> createState() => _EditCropDialogState();
}

// Tri-state for nullable patch fields:
//   - unchanged: don't include in the payload
//   - clear:     send `null` to remove the value
//   - value:     send the new value
class _Nullable<T> {
  const _Nullable.unchanged()
      : changed = false,
        value = null;
  const _Nullable.set(T this.value) : changed = true;
  const _Nullable.clear()
      : changed = true,
        value = null;
  final bool changed;
  final T? value;
}

// Preset destination options shown in the dropdown. Backend stores the
// field as free-text `String?` — if the existing crop's destination
// isn't one of these, we surface it as an extra item so it isn't lost
// on edit.
const _destinationPresets = <String>[
  'Main farm feeds',
  'Stopover shop',
  'Silage / factory',
  'Market',
];

class _EditCropDialogState extends State<EditCropDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _acreage;

  late CropStatus _status;
  late String? _destination;

  late _Nullable<DateTime> _planted;
  late _Nullable<DateTime> _expectedHarvest;

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final c = widget.crop;
    _name = TextEditingController(text: c.name);
    _acreage = TextEditingController(text: _fmtAcreage(c.acreage));

    _status = c.status;
    _destination =
        (c.destination != null && c.destination!.trim().isNotEmpty)
            ? c.destination
            : null;

    _planted = c.plantedDate == null
        ? const _Nullable.unchanged()
        : _Nullable.set(c.plantedDate!);
    _expectedHarvest = c.expectedHarvest == null
        ? const _Nullable.unchanged()
        : _Nullable.set(c.expectedHarvest!);
  }

  @override
  void dispose() {
    _name.dispose();
    _acreage.dispose();
    super.dispose();
  }

  String _fmtAcreage(double a) =>
      a == a.roundToDouble() ? a.toStringAsFixed(1) : a.toStringAsFixed(2);

  // Status options for the dropdown — matches the design mock's order
  // (Planted, Growing, Maturing, Ready soon, Active first). Tasseling /
  // Harvested / Failed are still surfaced so existing crops in those
  // states can be edited without errors.
  List<CropStatus> get _statusOptions => CropStatus.values;

  // Destination options: the 4 presets, plus the existing value if it's
  // not one of them (so we don't strip free-text destinations on edit).
  List<String> get _destinationOptions {
    final opts = [..._destinationPresets];
    if (_destination != null && !opts.contains(_destination)) {
      opts.insert(0, _destination!);
    }
    return opts;
  }

  Future<void> _pickDate({required bool planted}) async {
    final now = DateTime.now();
    final current = planted ? _planted.value : _expectedHarvest.value;
    final initial = current ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null && mounted) {
      setState(() {
        if (planted) {
          _planted = _Nullable.set(picked);
        } else {
          _expectedHarvest = _Nullable.set(picked);
        }
      });
    }
  }

  Map<String, dynamic> _buildPatch() {
    final c = widget.crop;
    final patch = <String, dynamic>{};

    final name = _name.text.trim();
    if (name.isNotEmpty && name != c.name) patch['name'] = name;

    final acreage = double.tryParse(_acreage.text.trim());
    if (acreage != null && acreage != c.acreage) patch['acreage'] = acreage;

    if (_status != c.status) patch['status'] = _status.wire;

    if (_planted.changed) {
      final next = _planted.value;
      if (next == null) {
        patch['plantedDate'] = null;
      } else if (next != c.plantedDate) {
        patch['plantedDate'] = next.toIso8601String();
      }
    }

    if (_expectedHarvest.changed) {
      final next = _expectedHarvest.value;
      if (next == null) {
        patch['expectedHarvest'] = null;
      } else if (next != c.expectedHarvest) {
        patch['expectedHarvest'] = next.toIso8601String();
      }
    }

    final dest = _destination?.trim();
    final cDest = (c.destination ?? '').trim();
    final destNorm = (dest == null || dest.isEmpty) ? null : dest;
    final cDestNorm = cDest.isEmpty ? null : cDest;
    if (destNorm != cDestNorm) {
      patch['destination'] = destNorm;
    }

    return patch;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final patch = _buildPatch();
    if (patch.isEmpty) {
      Navigator.of(context).pop(false);
      return;
    }

    setState(() => _submitting = true);
    try {
      await ApiService.updateNgushishCrop(widget.crop.id, patch);
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
    final dateFmt = DateFormat('d MMM yyyy');

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
                const Text(
                  'Edit Crop',
                  style: TextStyle(
                    color: primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Log a new crop or planting batch',
                  style: TextStyle(fontSize: 13, color: Color(0xFF7A7A7A)),
                ),
                const SizedBox(height: 22),

                // Row 1: Crop + Acreage
                _TwoCol(
                  left: _Field(
                    label: 'CROP *',
                    child: TextFormField(
                      controller: _name,
                      decoration: _inputDeco(),
                      validator: (v) {
                        final s = v?.trim() ?? '';
                        if (s.isEmpty) return 'Crop name is required';
                        if (s.length > 80) return 'Max 80 characters';
                        return null;
                      },
                    ),
                  ),
                  right: _Field(
                    label: 'ACREAGE *',
                    child: TextFormField(
                      controller: _acreage,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d*'),
                        ),
                      ],
                      decoration: _inputDeco(suffixText: 'ac'),
                      validator: (v) {
                        final n = double.tryParse(v?.trim() ?? '');
                        if (n == null || n <= 0) return 'Enter acreage > 0';
                        if (n > 10000) return 'Acreage too large';
                        return null;
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Row 2: Date Planted + Expected Harvest
                _TwoCol(
                  left: _Field(
                    label: 'DATE PLANTED',
                    child: _DateField(
                      value: _planted.value,
                      format: dateFmt,
                      onTap: _submitting
                          ? null
                          : () => _pickDate(planted: true),
                      onClear: _planted.value == null
                          ? null
                          : () => setState(
                                () => _planted = const _Nullable.clear(),
                              ),
                    ),
                  ),
                  right: _Field(
                    label: 'EXPECTED HARVEST',
                    child: _DateField(
                      value: _expectedHarvest.value,
                      format: dateFmt,
                      onTap: _submitting
                          ? null
                          : () => _pickDate(planted: false),
                      onClear: _expectedHarvest.value == null
                          ? null
                          : () => setState(
                                () => _expectedHarvest =
                                    const _Nullable.clear(),
                              ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Row 3: Status + Destination
                _TwoCol(
                  left: _Field(
                    label: 'STATUS',
                    child: DropdownButtonFormField<CropStatus>(
                      initialValue: _status,
                      decoration: _inputDeco(),
                      items: [
                        for (final s in _statusOptions)
                          DropdownMenuItem(value: s, child: Text(s.label)),
                      ],
                      onChanged: _submitting
                          ? null
                          : (v) => setState(() => _status = v ?? _status),
                    ),
                  ),
                  right: _Field(
                    label: 'DESTINATION',
                    child: DropdownButtonFormField<String>(
                      initialValue: _destination,
                      decoration: _inputDeco(),
                      isExpanded: true,
                      items: [
                        for (final d in _destinationOptions)
                          DropdownMenuItem(value: d, child: Text(d)),
                      ],
                      onChanged: _submitting
                          ? null
                          : (v) => setState(() => _destination = v),
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Save + Cancel — inline at bottom-left, matching the mock.
                Row(
                  children: [
                    FilledButton(
                      onPressed: _submitting ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 14,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
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

  // Shared input decoration so every field has the same border, padding,
  // and corner radius as the screenshot.
  InputDecoration _inputDeco({String? suffixText}) {
    return InputDecoration(
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
        borderSide: BorderSide(color: Color(0xFF27500A), width: 1.6),
      ),
      suffixText: suffixText,
    );
  }
}

// Two-column row that collapses to a single column on narrow screens
// (so the dialog doesn't spill on small phones).
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
            children: [left, const SizedBox(height: 18), right],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            const SizedBox(width: 18),
            Expanded(child: right),
          ],
        );
      },
    );
  }
}

// Field wrapper: small upper-case label + the input widget below it.
// Matches the screenshot exactly — labels sit OUTSIDE the field, not as
// a Material `labelText` floating inside the border.
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

// Tappable read-only date field. Renders "dd/mm/yyyy" placeholder when
// empty (matching the screenshot) and shows a calendar icon on the
// right; toggles to a clear icon once a date is set.
class _DateField extends StatelessWidget {
  const _DateField({
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
            color: value == null
                ? const Color(0xFF999999)
                : Colors.black87,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
