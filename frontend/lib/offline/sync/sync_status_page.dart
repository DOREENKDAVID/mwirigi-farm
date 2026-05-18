import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../database/local_database.dart';
import 'sync_queue.dart';

/// Admin-facing inspector for the offline queue. Shows pending /
/// in-flight / failed counts at the top, last successful sync time,
/// and a per-action list with payload + retry / discard buttons.
///
/// Listens to [SyncQueue.stateStream] so it rebuilds whenever the
/// queue progresses — no manual refresh button needed (though a
/// "Retry failed" button is still useful for one-shot prods).
class SyncStatusPage extends StatefulWidget {
  const SyncStatusPage({super.key});

  @override
  State<SyncStatusPage> createState() => _SyncStatusPageState();
}

class _SyncStatusPageState extends State<SyncStatusPage> {
  late StreamSubscription<SyncQueueState> _sub;
  SyncQueueState _state = SyncQueue.instance.state;
  List<PendingSyncActionData> _rows = const [];

  @override
  void initState() {
    super.initState();
    _sub = SyncQueue.instance.stateStream.listen((s) {
      if (mounted) {
        setState(() => _state = s);
        _refreshRows();
      }
    });
    _refreshRows();
  }

  Future<void> _refreshRows() async {
    final rows = await SyncQueue.instance.listAll();
    if (mounted) setState(() => _rows = rows);
  }

  Future<void> _confirmDiscardFailed() async {
    final n = _state.failed;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard failed?'),
        content: Text(
          'Permanently remove $n failed action${n == 1 ? '' : 's'} from the queue. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB42318),
            ),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final removed = await SyncQueue.instance.discardFailed();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Removed $removed failed action${removed == 1 ? '' : 's'}')),
    );
    await _refreshRows();
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final last = _state.lastSyncedAt;
    final lastLabel = last == null
        ? 'Never synced yet'
        : 'Last synced ${DateFormat('d MMM • HH:mm').format(last)}';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync status'),
        actions: [
          IconButton(
            tooltip: 'Retry failed',
            icon: const Icon(Icons.refresh),
            onPressed: _state.failed == 0
                ? null
                : () async {
                    await SyncQueue.instance.retryFailed();
                  },
          ),
          IconButton(
            tooltip: 'Discard all failed',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: _state.failed == 0 ? null : _confirmDiscardFailed,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: const Color(0xFFFAF9F4),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _Counter(
                      label: 'Pending',
                      value: _state.pending,
                      color: const Color(0xFF854F0B),
                    ),
                    const SizedBox(width: 12),
                    _Counter(
                      label: 'In-flight',
                      value: _state.inFlight,
                      color: const Color(0xFF27500A),
                    ),
                    const SizedBox(width: 12),
                    _Counter(
                      label: 'Failed',
                      value: _state.failed,
                      color: const Color(0xFFB42318),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  lastLabel,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _rows.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Nothing queued. Everything is in sync.',
                        style: TextStyle(color: Colors.black54),
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: _rows.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) => _ActionTile(
                      action: _rows[i],
                      onDiscard: () async {
                        await SyncQueue.instance.discard(_rows[i].id);
                        await _refreshRows();
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Counter extends StatelessWidget {
  const _Counter({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0x14000000)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value.toString(),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.action, required this.onDiscard});
  final PendingSyncActionData action;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final pretty = _prettyPayload(action.payload);
    final statusColor = switch (action.syncStatus) {
      'PENDING' => const Color(0xFF854F0B),
      'IN_FLIGHT' => const Color(0xFF27500A),
      'FAILED' => const Color(0xFFB42318),
      _ => Colors.black54,
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  action.syncStatus,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${action.method} ${action.endpoint}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Discard',
                icon: const Icon(Icons.delete_outline, size: 18),
                color: const Color(0xFFB42318),
                onPressed: onDiscard,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 0, top: 4),
            child: Text(
              pretty,
              style: const TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                color: Colors.black54,
              ),
            ),
          ),
          if (action.lastError != null && action.lastError!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Error: ${action.lastError}',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFFB42318),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Queued ${DateFormat('d MMM • HH:mm:ss').format(action.createdAt)}'
              ' · retries ${action.retryCount}'
              '${action.actorId != null ? " · by ${action.actorId!.substring(0, 6)}…" : ""}',
              style: const TextStyle(fontSize: 10, color: Colors.black45),
            ),
          ),
        ],
      ),
    );
  }

  String _prettyPayload(String raw) {
    if (raw.isEmpty || raw == '{}') return '—';
    try {
      final decoded = jsonDecode(raw);
      // Truncate so we don't blow out a row with a giant blob.
      final s = const JsonEncoder.withIndent('  ').convert(decoded);
      return s.length > 240 ? '${s.substring(0, 240)}…' : s;
    } catch (_) {
      return raw.length > 240 ? '${raw.substring(0, 240)}…' : raw;
    }
  }
}
