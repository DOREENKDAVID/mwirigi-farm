// "💉 Vaccination" pill for the Dairy module.
//
// Pure consumer of the Health module's unified schedule
// (`GET /api/health/vaccinations?unit=Dairy`). When a vet logs a
// vaccination over in the Health module, it shows up here on the next
// reload — Dairy never owns the vaccination data itself.
//
// Three sections:
//   • Overdue   (statuses OVERDUE / DUE_NOW / DUE_WINDOW_OPEN)
//   • Upcoming  (statuses DUE_SOON / UPCOMING)
//   • Done      (status DONE)
//
// Visual style matches the Layers vaccination timeline (left accent
// border, status pill on the right) so the cross-module experience
// feels consistent.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/service/api_service.dart';

class DairyVaccinationCard extends StatefulWidget {
  const DairyVaccinationCard({super.key});

  @override
  State<DairyVaccinationCard> createState() => _DairyVaccinationCardState();
}

class _DairyVaccinationCardState extends State<DairyVaccinationCard> {
  static const _primary = Color(0xFF27500A);
  static const _txt2 = Color(0xFF6B7770);
  static const _txt3 = Color(0xFF99A39B);

  late Future<List<_VaccRow>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<_VaccRow>> _load() async {
    final raw = await ApiService.getHealthVaccinations(unit: 'Dairy');
    return raw
        .whereType<Map>()
        .map((m) => _VaccRow.fromJson(m.cast<String, dynamic>()))
        .toList();
  }

  Future<void> _reload() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x14000000)),
      ),
      padding: const EdgeInsets.all(16),
      child: FutureBuilder<List<_VaccRow>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snap.hasError) {
            return _ErrorState(
              message: snap.error.toString(),
              onRetry: _reload,
            );
          }
          final rows = snap.data ?? const <_VaccRow>[];
          final overdue =
              rows.where((r) => r.bucket == _Bucket.overdue).toList();
          final upcoming =
              rows.where((r) => r.bucket == _Bucket.upcoming).toList();
          final done = rows.where((r) => r.bucket == _Bucket.done).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '💉  Vaccination',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _primary,
                        letterSpacing: 0.04,
                      ),
                    ),
                  ),
                  Text(
                    '${overdue.length} overdue · ${upcoming.length} upcoming · ${done.length} done',
                    style: const TextStyle(fontSize: 11, color: _txt3),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 18),
                    onPressed: _reload,
                    tooltip: 'Refresh',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Synced from Health module.',
                style: TextStyle(
                  fontSize: 12,
                  color: _txt3,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Recorded by the vet in the Health module — done items '
                'appear here automatically once logged.',
                style: TextStyle(fontSize: 12, color: _txt2, height: 1.45),
              ),
              const SizedBox(height: 14),
              if (rows.isEmpty)
                _Empty(onRefresh: _reload)
              else ...[
                if (overdue.isNotEmpty) ...[
                  _Section(title: 'Overdue', rows: overdue),
                  const SizedBox(height: 14),
                ],
                if (upcoming.isNotEmpty) ...[
                  _Section(title: 'Upcoming', rows: upcoming),
                  const SizedBox(height: 14),
                ],
                if (done.isNotEmpty) _Section(title: 'Done', rows: done),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.rows});
  final String title;
  final List<_VaccRow> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 2),
          child: Row(
            children: [
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF6B7770),
                  letterSpacing: 0.05,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '(${rows.length})',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF99A39B),
                ),
              ),
            ],
          ),
        ),
        for (var i = 0; i < rows.length; i++) ...[
          _VaccRowTile(row: rows[i]),
          if (i != rows.length - 1) const SizedBox(height: 6),
        ],
      ],
    );
  }
}

class _VaccRowTile extends StatelessWidget {
  const _VaccRowTile({required this.row});
  final _VaccRow row;

  @override
  Widget build(BuildContext context) {
    final palette = _palette(row.bucket);
    final dateFmt = DateFormat('d MMM yyyy');
    String? sub;
    if (row.bucket == _Bucket.done && row.lastDoneAt != null) {
      sub = 'Last done ${dateFmt.format(row.lastDoneAt!)} · '
          'next due ${row.nextDueAt != null ? dateFmt.format(row.nextDueAt!) : '—'}';
    } else if (row.nextDueAt != null) {
      sub = 'Due ${dateFmt.format(row.nextDueAt!)}'
          '${row.daysUntilDue != null ? ' · ${_daysLabel(row.daysUntilDue!)}' : ''}';
    } else {
      sub = row.type;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: palette.bg,
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(color: palette.accent, width: 3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: palette.accent,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(palette.icon, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        row.vaccine,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF222222),
                        ),
                      ),
                    ),
                    Text(
                      row.animals > 0
                          ? '${row.animals} ${row.animals == 1 ? 'cow' : 'cows'}'
                          : '',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF6B7770),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  sub,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6B7770),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _StatusPill(label: palette.label, color: palette.accent),
        ],
      ),
    );
  }

  static String _daysLabel(int n) {
    if (n == 0) return 'today';
    if (n == 1) return 'tomorrow';
    if (n == -1) return 'yesterday';
    if (n < 0) return '${-n}d overdue';
    return 'in ${n}d';
  }

  static _Palette _palette(_Bucket b) {
    switch (b) {
      case _Bucket.done:
        return const _Palette(
          accent: Color(0xFF27500A),
          bg: Color(0xFFEFF5E6),
          icon: Icons.check,
          label: 'DONE',
        );
      case _Bucket.overdue:
        return const _Palette(
          accent: Color(0xFFE24B4A),
          bg: Color(0xFFFEEBEB),
          icon: Icons.error_outline,
          label: 'OVERDUE',
        );
      case _Bucket.upcoming:
        return const _Palette(
          accent: Color(0xFFAAAAAA),
          bg: Color(0xFFF1F1F1),
          icon: Icons.circle_outlined,
          label: 'UPCOMING',
        );
    }
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _Palette {
  const _Palette({
    required this.accent,
    required this.bg,
    required this.icon,
    required this.label,
  });
  final Color accent;
  final Color bg;
  final IconData icon;
  final String label;
}

enum _Bucket { done, overdue, upcoming }

class _VaccRow {
  _VaccRow({
    required this.id,
    required this.vaccine,
    required this.type,
    required this.animals,
    required this.bucket,
    required this.rawStatus,
    this.nextDueAt,
    this.lastDoneAt,
    this.daysUntilDue,
  });

  final String id;
  final String vaccine;
  final String type;
  final int animals;
  final _Bucket bucket;
  final String rawStatus;
  final DateTime? nextDueAt;
  final DateTime? lastDoneAt;
  final int? daysUntilDue;

  factory _VaccRow.fromJson(Map<String, dynamic> j) {
    final status = (j['status'] ?? '').toString();
    final bucket = _bucketize(status);
    DateTime? toDate(dynamic v) {
      if (v == null) return null;
      return DateTime.tryParse(v.toString());
    }

    return _VaccRow(
      id: (j['id'] ?? '').toString(),
      vaccine: (j['vaccine'] ?? '').toString(),
      type: (j['type'] ?? '').toString(),
      animals: j['animals'] is num ? (j['animals'] as num).toInt() : 0,
      bucket: bucket,
      rawStatus: status,
      nextDueAt: toDate(j['nextDueAt']),
      lastDoneAt: toDate(j['lastDoneAt']),
      daysUntilDue: j['daysUntilDue'] is num
          ? (j['daysUntilDue'] as num).toInt()
          : null,
    );
  }

  // Map the Health module's six statuses onto the three Dairy buckets.
  static _Bucket _bucketize(String status) {
    switch (status) {
      case 'DONE':
        return _Bucket.done;
      case 'OVERDUE':
      case 'DUE_NOW':
      case 'DUE_WINDOW_OPEN':
        return _Bucket.overdue;
      default:
        return _Bucket.upcoming;
    }
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onRefresh});
  final VoidCallback onRefresh;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8F4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'No dairy vaccinations on file.',
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7770)),
          ),
          const SizedBox(height: 6),
          const Text(
            'Add a Dairy vaccine protocol from the Health module to '
            'populate this view.',
            style: TextStyle(fontSize: 11, color: Color(0xFF99A39B)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFCEDC8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFAC7B0F)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Could not load vaccinations.\n$message',
              style: const TextStyle(fontSize: 12, color: Color(0xFF8A5A0A)),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
