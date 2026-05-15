import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/feeds.dart';
import '../../core/service/api_service.dart';

/// "Edit consumption rates" header dialog. Users adjust quantity-used +
/// duration for any subset of materials in one pass; the new daily-use
/// rate is previewed live per row, and the whole batch is saved atomically
/// via POST /feeds/consumption/bulk.
///
/// Empty rows are skipped — a material with no input simply isn't
/// included in the submitted payload.
class BulkConsumptionDialog extends StatefulWidget {
  const BulkConsumptionDialog({super.key, required this.materials});
  final List<FeedMaterial> materials;

  @override
  State<BulkConsumptionDialog> createState() => _BulkConsumptionDialogState();
}

class _BulkConsumptionDialogState extends State<BulkConsumptionDialog> {
  late final Map<String, TextEditingController> _qty;
  late final Map<String, TextEditingController> _days;

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _qty = {for (final m in widget.materials) m.id: TextEditingController()};
    _days = {for (final m in widget.materials) m.id: TextEditingController()};
  }

  @override
  void dispose() {
    for (final c in _qty.values) {
      c.dispose();
    }
    for (final c in _days.values) {
      c.dispose();
    }
    super.dispose();
  }

  // Returns the entries the user has filled in. Each entry is validated
  // (qty > 0, days > 0). Returns null if any partially-filled row is
  // invalid (qty without days or vice versa).
  List<Map<String, dynamic>>? _collect() {
    final entries = <Map<String, dynamic>>[];
    for (final m in widget.materials) {
      final qStr = _qty[m.id]!.text.trim();
      final dStr = _days[m.id]!.text.trim();
      if (qStr.isEmpty && dStr.isEmpty) continue;
      final q = double.tryParse(qStr);
      final d = int.tryParse(dStr);
      if (q == null || q <= 0 || d == null || d <= 0) return null;
      entries.add({
        'materialId': m.id,
        'quantityUsedKg': q,
        'durationDays': d,
      });
    }
    return entries;
  }

  Future<void> _submit() async {
    final entries = _collect();
    if (entries == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Each row needs both quantity used AND duration (or leave both blank to skip).',
          ),
        ),
      );
      return;
    }
    if (entries.isEmpty) {
      Navigator.of(context).pop(false);
      return;
    }

    setState(() => _submitting = true);
    try {
      final res = await ApiService.createFeedConsumptionBulk(entries);
      if (!mounted) return;
      final n = (res['count'] as num?)?.toInt() ?? entries.length;
      Navigator.of(context).pop(n);
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
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 4),
              child: Text(
                'Edit consumption rates',
                style: TextStyle(
                  color: primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                'Update any number of materials in one pass. Leave both fields blank to skip a row.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
            const Divider(height: 1, color: Color(0x14000000)),
            Flexible(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                itemCount: widget.materials.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final m = widget.materials[i];
                  return _BulkRow(
                    material: m,
                    qtyCtrl: _qty[m.id]!,
                    daysCtrl: _days[m.id]!,
                    onChanged: () => setState(() {}),
                    enabled: !_submitting,
                  );
                },
              ),
            ),
            const Divider(height: 1, color: Color(0x14000000)),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _submitting
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
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
                        : const Text('Save all'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BulkRow extends StatelessWidget {
  const _BulkRow({
    required this.material,
    required this.qtyCtrl,
    required this.daysCtrl,
    required this.onChanged,
    required this.enabled,
  });
  final FeedMaterial material;
  final TextEditingController qtyCtrl;
  final TextEditingController daysCtrl;
  final VoidCallback onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final q = double.tryParse(qtyCtrl.text.trim());
    final d = int.tryParse(daysCtrl.text.trim());
    final preview = (q != null && q > 0 && d != null && d > 0)
        ? '${(q / d).toStringAsFixed(2)} kg/day'
        : null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAF7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  material.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              Text(
                'Now: ${material.dailyUseKg.toStringAsFixed(2)} kg/d',
                style:
                    const TextStyle(fontSize: 11, color: Colors.black54),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: qtyCtrl,
                  enabled: enabled,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                  onChanged: (_) => onChanged(),
                  decoration: const InputDecoration(
                    labelText: 'Qty used',
                    suffixText: 'kg',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: daysCtrl,
                  enabled: enabled,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => onChanged(),
                  decoration: const InputDecoration(
                    labelText: 'Over days',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 110,
                child: Text(
                  preview ?? '—',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: preview == null
                        ? Colors.black38
                        : const Color(0xFF27500A),
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
