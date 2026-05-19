import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/farmers_choice_delivery.dart';
import '../../core/service/api_service.dart';
import 'log_fc_dispatch_dialog.dart';

/// Farmers Choice dispatch log. Renders one row per truck-load with
/// the audit-trail fields, and an "Add" action that opens
/// [LogFcDispatchDialog].
class FcDispatchLogCard extends StatefulWidget {
  const FcDispatchLogCard({super.key});

  @override
  State<FcDispatchLogCard> createState() => _FcDispatchLogCardState();
}

class _FcDispatchLogCardState extends State<FcDispatchLogCard> {
  static const _primary = Color(0xFF27500A);
  static const _txt3 = Color(0xFF99A39B);

  late Future<List<FcDelivery>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<FcDelivery>> _load() async {
    final raw = await ApiService.getFcDeliveries();
    return raw
        .whereType<Map>()
        .map((m) => FcDelivery.fromJson(m.cast<String, dynamic>()))
        .toList();
  }

  Future<void> _reload() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _openLogDialog() async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const LogFcDispatchDialog(),
    );
    if (saved == true) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x14000000)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: FutureBuilder<List<FcDelivery>>(
        future: _future,
        builder: (context, snap) {
          final loading = snap.connectionState != ConnectionState.done;
          final error = snap.hasError;
          final rows = (snap.data ?? const <FcDelivery>[])
            ..sort((a, b) => b.date.compareTo(a.date));

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '🚚  FARMERS CHOICE DISPATCH LOG',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: _primary,
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: loading ? null : _openLogDialog,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Log dispatch'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                rows.isEmpty
                    ? 'No FC deliveries logged yet.'
                    : '${rows.length} deliver${rows.length == 1 ? "y" : "ies"} '
                        '· ${rows.fold<int>(0, (s, r) => s + r.count)} head moved',
                style: const TextStyle(fontSize: 11, color: _txt3),
              ),
              const SizedBox(height: 12),

              if (loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (error)
                _ErrorBlock(
                  message: snap.error.toString(),
                  onRetry: _reload,
                )
              else if (rows.isEmpty)
                _EmptyBlock(onCreate: _openLogDialog)
              else
                _Table(rows: rows),
            ],
          );
        },
      ),
    );
  }
}

class _Table extends StatelessWidget {
  const _Table({required this.rows});
  final List<FcDelivery> rows;

  static const _hdr = Color(0xFFEEF3E8);
  static const _txt2 = Color(0xFF6B7770);

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('d MMM yy');
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: MediaQuery.of(context).size.width - 80,
        ),
        child: DataTable(
          headingRowHeight: 34,
          dataRowMinHeight: 40,
          dataRowMaxHeight: 56,
          columnSpacing: 16,
          horizontalMargin: 6,
          headingRowColor: WidgetStateProperty.resolveWith((_) => _hdr),
          headingTextStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: _txt2,
            letterSpacing: 0.05,
          ),
          columns: const [
            DataColumn(label: Text('Date')),
            DataColumn(label: Text('Reference')),
            DataColumn(label: Text('Pens')),
            DataColumn(label: Text('Count')),
            DataColumn(label: Text('Category')),
            DataColumn(label: Text('Age')),
            DataColumn(label: Text('Driver')),
            DataColumn(label: Text('Notes')),
          ],
          rows: [
            for (final r in rows)
              DataRow(cells: [
                DataCell(Text(df.format(r.date),
                    style: const TextStyle(fontSize: 12))),
                DataCell(_RefPill(text: r.ref, paid: r.hasRevenue)),
                DataCell(
                  Text(r.pens, style: const TextStyle(fontSize: 12)),
                ),
                DataCell(Text(
                  '${r.count}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF27500A),
                  ),
                )),
                DataCell(Text(r.category,
                    style: const TextStyle(fontSize: 12))),
                DataCell(Text(r.ageRange ?? '—',
                    style: const TextStyle(fontSize: 12, color: _txt2))),
                DataCell(Text(r.driver,
                    style: const TextStyle(fontSize: 12))),
                DataCell(SizedBox(
                  width: 220,
                  child: Text(
                    r.notes ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: _txt2),
                  ),
                )),
              ]),
          ],
        ),
      ),
    );
  }
}

class _RefPill extends StatelessWidget {
  const _RefPill({required this.text, required this.paid});
  final String text;
  final bool paid;
  @override
  Widget build(BuildContext context) {
    final bg = paid ? const Color(0xFFE7F0DD) : const Color(0xFFFCEDC8);
    final border = paid ? const Color(0xFFB6CFA0) : const Color(0xFFE6C58A);
    final fg = paid ? const Color(0xFF27500A) : const Color(0xFF8A5A0A);
    return Tooltip(
      message: paid
          ? 'Linked to a Revenue row in the finance ledger.'
          : 'No revenue linked yet — amount was not entered at save time.',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: border),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: fg,
          ),
        ),
      ),
    );
  }
}

class _EmptyBlock extends StatelessWidget {
  const _EmptyBlock({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8F4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'No FC deliveries logged yet.',
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7770)),
          ),
          const SizedBox(height: 4),
          const Text(
            'Log a dispatch when a truck leaves for FC so the finance '
            'ledger and the pen-clear audit trail update together.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Color(0xFF99A39B)),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add, size: 14),
            label: const Text('Log first dispatch'),
          ),
        ],
      ),
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({required this.message, required this.onRetry});
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
              'Could not load FC deliveries.\n'
              '${message.replaceFirst('Exception: ', '')}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF8A5A0A)),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
