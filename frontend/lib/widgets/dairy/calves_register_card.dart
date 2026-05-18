// Calves register — "🐮 Calves register" pill on the Dairy page.
//
// Mirrors the v4.2 HTML mockup: tracked separately from cows until weaning.
// Columns: Tag · Name · Sex · DOB · Age · Dam · Sire · Birth wt · House ·
// Worker · Stage · Notes. The data source is /api/dairy/calves which joins
// each CALVING reproduction record with its dam (and the calf cow row,
// when the calf has been registered into the herd as well).

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/dairy_ops.dart';
import '../../core/service/api_service.dart';
import 'calf_disposition_dialog.dart';

class CalvesRegisterCard extends StatefulWidget {
  const CalvesRegisterCard({super.key});

  @override
  State<CalvesRegisterCard> createState() => _CalvesRegisterCardState();
}

class _CalvesRegisterCardState extends State<CalvesRegisterCard> {
  static const _primary = Color(0xFF27500A);
  static const _txt2 = Color(0xFF6B7770);
  static const _txt3 = Color(0xFF99A39B);

  late Future<List<CalfRecord>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<CalfRecord>> _load() async {
    final raw = await ApiService.getDairyCalves();
    return raw
        .whereType<Map>()
        .map((m) => CalfRecord.fromJson(m.cast<String, dynamic>()))
        .toList();
  }

  Future<void> _reload() async {
    setState(() {
      _future = _load();
    });
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
      child: FutureBuilder<List<CalfRecord>>(
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
          final rows = (snap.data ?? const <CalfRecord>[])
            ..sort((a, b) => b.eventDate.compareTo(a.eventDate));
          final preWeanCount =
              rows.where((r) => r.ageDays < 90).length;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '🐮  Calves register',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.05,
                        color: _primary,
                      ),
                    ),
                  ),
                  Text(
                    '${rows.length} calves · $preWeanCount pre-wean',
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
                'Tracked separately from cows until weaning/transfer.',
                style: TextStyle(
                  fontSize: 12,
                  color: _txt3,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'A calf joins this register when born and stays here until '
                'weaned (~3 months). Females typically graduate into the '
                'breeding herd; males are tagged into the feedlot 26-series '
                'and move to the feedlot register.',
                style: TextStyle(fontSize: 12, color: _txt2, height: 1.5),
              ),
              const SizedBox(height: 12),
              if (rows.isEmpty)
                _EmptyState(onRefresh: _reload)
              else
                _CalvesTable(rows: rows, onReleased: _reload),
            ],
          );
        },
      ),
    );
  }
}

class _CalvesTable extends StatelessWidget {
  const _CalvesTable({required this.rows, required this.onReleased});
  final List<CalfRecord> rows;
  final VoidCallback onReleased;

  static const _txt2 = Color(0xFF6B7770);
  static const _txt3 = Color(0xFF99A39B);
  static const _hdr = Color(0xFFEEF3E8);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: MediaQuery.of(context).size.width - 80,
        ),
        child: DataTable(
          headingRowHeight: 36,
          dataRowMinHeight: 44,
          dataRowMaxHeight: 56,
          columnSpacing: 18,
          horizontalMargin: 8,
          headingRowColor:
              WidgetStateProperty.resolveWith((_) => _hdr),
          headingTextStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: _txt2,
            letterSpacing: 0.05,
          ),
          columns: const [
            DataColumn(label: Text('Tag')),
            DataColumn(label: Text('Name')),
            DataColumn(label: Text('Sex')),
            DataColumn(label: Text('DOB')),
            DataColumn(label: Text('Age')),
            DataColumn(label: Text('Dam')),
            DataColumn(label: Text('Sire')),
            DataColumn(label: Text('Birth wt')),
            DataColumn(label: Text('House')),
            DataColumn(label: Text('Worker')),
            DataColumn(label: Text('Stage')),
            DataColumn(label: Text('Notes')),
            DataColumn(label: Text('Actions')),
          ],
          rows: rows.map((r) => _buildRow(context, r)).toList(),
        ),
      ),
    );
  }

  DataRow _buildRow(BuildContext context, CalfRecord r) {
    final dobText = DateFormat('d MMM yy').format(r.eventDate);
    final stageColor = _stageColor(r.ageDays);
    final tagText = (r.calf?.tag ?? r.calfTag ?? '—').toString();
    final nameText = r.calf?.nickname ?? '—';
    final sex = r.calfSex == null
        ? '—'
        : (r.calfSex == 'F' ? '♀' : '♂');
    final damText = r.dam?.displayName ?? '—';
    final sireText = r.sireCode ?? '—';
    final birthWt =
        r.calfBirthWeightKg == null ? '—' : '${r.calfBirthWeightKg} kg';
    final houseText =
        r.calf?.houseName ?? r.dam?.houseName ?? '—';
    final workerText =
        r.calf?.workerName ?? r.dam?.workerName ?? '—';
    final isOnMilk = r.ageDays < 90;
    // disposeCalf writes calvingFate as "Sold (cash) (YYYY-MM-DD)" etc.
    // — detect those prefixes so we disable the Release button once a
    // disposition has been recorded.
    final alreadyDisposed = RegExp(
      r'^(Sold|Died|Transferred|Lost|Disposed)',
    ).hasMatch(r.calvingFate ?? '');

    return DataRow(cells: [
      DataCell(_TagPill(tagText)),
      DataCell(Text(
        nameText,
        style: TextStyle(
          fontSize: 12,
          color: nameText == '—' ? _txt3 : Colors.black87,
        ),
      )),
      DataCell(Text(sex, style: const TextStyle(fontSize: 13))),
      DataCell(Text(dobText, style: const TextStyle(fontSize: 12))),
      DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
        Text('${r.ageDays}d',
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(width: 4),
        Text(
          '(${r.stage})',
          style: TextStyle(
            fontSize: 10,
            color: stageColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ])),
      DataCell(Text(damText, style: const TextStyle(fontSize: 12))),
      DataCell(Text(sireText, style: const TextStyle(fontSize: 12))),
      DataCell(Text(birthWt, style: const TextStyle(fontSize: 12))),
      DataCell(Text(houseText, style: const TextStyle(fontSize: 12))),
      DataCell(Text(workerText, style: const TextStyle(fontSize: 12))),
      DataCell(_StageTag(isOnMilk: isOnMilk)),
      DataCell(SizedBox(
        width: 200,
        child: Text(
          r.calvingFate ?? r.notes ?? '',
          style: const TextStyle(fontSize: 11, color: _txt2),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      )),
      DataCell(_ReleaseButton(
        calf: r,
        disabled: alreadyDisposed,
        onDisposed: onReleased,
      )),
    ]);
  }

  Color _stageColor(int ageDays) {
    if (ageDays < 7) return const Color(0xFFC4393B);   // r400
    if (ageDays < 90) return const Color(0xFFAC7B0F);  // a600
    return const Color(0xFF27500A);                    // g600
  }
}

class _TagPill extends StatelessWidget {
  const _TagPill(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFE7F0DD),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFB6CFA0)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF27500A),
        ),
      ),
    );
  }
}

class _ReleaseButton extends StatelessWidget {
  const _ReleaseButton({
    required this.calf,
    required this.disabled,
    required this.onDisposed,
  });

  final CalfRecord calf;
  final bool disabled;
  final VoidCallback onDisposed;

  Future<void> _open(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CalfDispositionDialog(calf: calf),
    );
    if (ok == true) onDisposed();
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: disabled ? null : () => _open(context),
      icon: const Text('🏷', style: TextStyle(fontSize: 12)),
      label: Text(disabled ? 'Released' : 'Release'),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF8A5A0A),
        side: const BorderSide(color: Color(0xFFE6C58A)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _StageTag extends StatelessWidget {
  const _StageTag({required this.isOnMilk});
  final bool isOnMilk;

  @override
  Widget build(BuildContext context) {
    final bg = isOnMilk ? const Color(0xFFFCEDC8) : const Color(0xFFE7F0DD);
    final fg = isOnMilk ? const Color(0xFF8A5A0A) : const Color(0xFF27500A);
    final text = isOnMilk ? 'On milk' : 'Weaned';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onRefresh});
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
            'No calves recorded yet.',
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7770)),
          ),
          const SizedBox(height: 6),
          const Text(
            'Add a calving record from the cow registration dialog '
            '(Calving History → + Add calving) to populate this register.',
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFCEDC8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFAC7B0F)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Could not load calves register.\n$message',
              style: const TextStyle(fontSize: 12, color: Color(0xFF8A5A0A)),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
