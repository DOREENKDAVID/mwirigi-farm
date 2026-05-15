// Bottom sheet showing the history (issues + harvests + meta) recorded
// against a single crop block. Reads from the block's `notes` field
// where the issue and harvest dialogs encode each entry as a JSON line.
//
// Each line is expected to look like:
//   [YYYY-MM-DD HH:mm] {"kind":"ISSUE", ...}
// Anything that can't be parsed is rendered as a free-form note line.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/ngushish.dart';
import '../../core/service/api_service.dart';

class CropActivitySheet extends StatefulWidget {
  const CropActivitySheet({super.key, required this.crop});
  final CropView crop;

  @override
  State<CropActivitySheet> createState() => _CropActivitySheetState();
}

class _CropActivitySheetState extends State<CropActivitySheet> {
  static const _primary = Color(0xFF27500A);
  static const _txt2 = Color(0xFF6B7770);
  static const _red = Color(0xFFC4393B);
  static const _amber = Color(0xFF8A5A0A);

  late Future<_ActivityBundle> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_ActivityBundle> _load() async {
    // The crop record holds the notes (issues + meta). Harvest entries
    // live on /ngushish/harvests, scoped by cropId.
    final details = await ApiService.getNgushishCropById(widget.crop.id);
    final cd = CropDetails.fromJson(details);
    final notes = (cd.crop.notes ?? '').trim();

    final issues = <_Entry>[];
    final meta = <_Entry>[];
    final raw = <String>[];

    for (final line in notes.split('\n')) {
      final s = line.trim();
      if (s.isEmpty) continue;
      // Match: [stamp] {json}
      final match = RegExp(r'^\[([^\]]+)\]\s*(\{.*\})\s*$').firstMatch(s);
      if (match != null) {
        try {
          final stamp = match.group(1)!;
          final json = jsonDecode(match.group(2)!) as Map<String, dynamic>;
          final kind = (json['kind'] ?? '').toString();
          if (kind == 'ISSUE') {
            issues.add(_Entry(stamp: stamp, data: json));
          } else if (kind == 'META') {
            meta.add(_Entry(stamp: stamp, data: json));
          } else {
            raw.add(s);
          }
        } catch (_) {
          raw.add(s);
        }
      } else {
        raw.add(s);
      }
    }

    return _ActivityBundle(
      issues: issues.reversed.toList(),
      harvests: cd.harvests.reversed.toList(),
      dispatches: cd.dispatches.reversed.toList(),
      irrigation: cd.irrigation.reversed.toList(),
      meta: meta,
      rawNotes: raw,
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scroll) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0x33000000),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 12, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Block ${widget.crop.block ?? "—"} · ${widget.crop.name}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: _primary,
                            ),
                          ),
                          Text(
                            'Activity & logs',
                            style: TextStyle(
                              fontSize: 12,
                              color: _txt2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: FutureBuilder<_ActivityBundle>(
                  future: _future,
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snap.hasError) {
                      return Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          snap.error.toString().replaceFirst('Exception: ', ''),
                          style: const TextStyle(color: _red),
                        ),
                      );
                    }
                    final b = snap.data!;
                    return ListView(
                      controller: scroll,
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                      children: [
                        if (b.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 40),
                            child: Center(
                              child: Text(
                                'No activity recorded yet.',
                                style: TextStyle(color: _txt2),
                              ),
                            ),
                          ),
                        if (b.issues.isNotEmpty) ...[
                          const _SectionLabel('🌿 ISSUES'),
                          for (final e in b.issues) _IssueCard(entry: e),
                          const SizedBox(height: 14),
                        ],
                        if (b.harvests.isNotEmpty) ...[
                          const _SectionLabel('🌾 HARVESTS'),
                          for (final h in b.harvests) _HarvestRow(log: h),
                          const SizedBox(height: 14),
                        ],
                        if (b.dispatches.isNotEmpty) ...[
                          const _SectionLabel('🚚 DISPATCHES'),
                          for (final d in b.dispatches) _DispatchRow(log: d),
                          const SizedBox(height: 14),
                        ],
                        if (b.irrigation.isNotEmpty) ...[
                          const _SectionLabel('💧 IRRIGATION'),
                          for (final i in b.irrigation) _IrrigationRow(log: i),
                          const SizedBox(height: 14),
                        ],
                        if (b.rawNotes.isNotEmpty) ...[
                          const _SectionLabel('📝 NOTES'),
                          for (final r in b.rawNotes)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(
                                r,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ActivityBundle {
  _ActivityBundle({
    required this.issues,
    required this.harvests,
    required this.dispatches,
    required this.irrigation,
    required this.meta,
    required this.rawNotes,
  });
  final List<_Entry> issues;
  final List<HarvestLog> harvests;
  final List<DispatchLog> dispatches;
  final List<IrrigationLogEntry> irrigation;
  final List<_Entry> meta;
  final List<String> rawNotes;

  bool get isEmpty =>
      issues.isEmpty &&
      harvests.isEmpty &&
      dispatches.isEmpty &&
      irrigation.isEmpty &&
      rawNotes.isEmpty;
}

class _Entry {
  _Entry({required this.stamp, required this.data});
  final String stamp;
  final Map<String, dynamic> data;
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          color: Colors.black54,
        ),
      ),
    );
  }
}

class _IssueCard extends StatelessWidget {
  const _IssueCard({required this.entry});
  final _Entry entry;
  @override
  Widget build(BuildContext context) {
    final d = entry.data;
    final severity = (d['severity'] ?? '').toString();
    final accent = switch (severity) {
      'CRITICAL' => _CropActivitySheetState._red,
      'HIGH' => _CropActivitySheetState._amber,
      'MEDIUM' => const Color(0xFF8A5A0A),
      _ => _CropActivitySheetState._primary,
    };
    final photoData = d['photo']?.toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x14000000)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 14,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  (d['issueType'] ?? 'Issue').toString(),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF222222),
                  ),
                ),
              ),
              Text(
                severity,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: accent,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            entry.stamp,
            style: const TextStyle(fontSize: 11, color: Color(0xFF7A7A7A)),
          ),
          const SizedBox(height: 6),
          if ((d['notes'] ?? '').toString().isNotEmpty)
            Text(
              d['notes'].toString(),
              style: const TextStyle(fontSize: 12, color: Colors.black87),
            ),
          if ((d['actionRequired'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Action: ${d['actionRequired']}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF222222),
              ),
            ),
          ],
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              if ((d['status'] ?? '').toString().isNotEmpty)
                _Pill(label: 'Status · ${d['status']}'),
              if ((d['assignedWorker'] ?? '').toString().isNotEmpty)
                _Pill(label: '👤 ${d['assignedWorker']}'),
            ],
          ),
          if (photoData != null && photoData.startsWith('data:image/')) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                base64Decode(photoData.split(',').last),
                height: 140,
                fit: BoxFit.cover,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HarvestRow extends StatelessWidget {
  const _HarvestRow({required this.log});
  final HarvestLog log;
  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM yyyy');
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🌾  ', style: TextStyle(fontSize: 12)),
          Expanded(
            child: Text(
              '${log.quantityKg.toStringAsFixed(0)} units · ${fmt.format(log.harvestDate)}'
              '${log.qualityGrade != null ? " · ${log.qualityGrade}" : ""}',
              style: const TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}

class _DispatchRow extends StatelessWidget {
  const _DispatchRow({required this.log});
  final DispatchLog log;
  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM yyyy');
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        '${log.quantityKg.toStringAsFixed(0)} → ${log.destination} · '
        '${fmt.format(log.dispatchDate)} · KSh ${log.revenue.toStringAsFixed(0)}',
        style: const TextStyle(fontSize: 12, color: Colors.black87),
      ),
    );
  }
}

class _IrrigationRow extends StatelessWidget {
  const _IrrigationRow({required this.log});
  final IrrigationLogEntry log;
  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM yyyy');
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        '${fmt.format(log.irrigationDate)}'
        '${log.durationMinutes != null ? " · ${log.durationMinutes} min" : ""}'
        '${log.waterSource != null ? " · ${log.waterSource}" : ""}',
        style: const TextStyle(fontSize: 12, color: Colors.black87),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          color: Color(0xFF555555),
        ),
      ),
    );
  }
}
