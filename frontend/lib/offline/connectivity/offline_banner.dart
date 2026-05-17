import 'dart:async';

import 'package:flutter/material.dart';

import '../sync/sync_queue.dart';
import 'connectivity_service.dart';

/// Thin global banner shown above the app body. Three states:
///   * Offline      — amber, "You are offline. Changes are queued."
///   * Syncing      — green, "Syncing N change(s)…"
///   * Pending only — neutral, "N change(s) waiting to sync."
/// Hidden entirely when fully online with zero queued actions.
class OfflineBanner extends StatefulWidget {
  const OfflineBanner({super.key, required this.child});
  final Widget child;

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  StreamSubscription<bool>? _connSub;
  StreamSubscription<SyncQueueState>? _queueSub;
  bool _online = ConnectivityService.instance.isOnline;
  SyncQueueState _queue = SyncQueue.instance.state;

  @override
  void initState() {
    super.initState();
    _connSub = ConnectivityService.instance.stream.listen((v) {
      if (mounted) setState(() => _online = v);
    });
    _queueSub = SyncQueue.instance.stateStream.listen((v) {
      if (mounted) setState(() => _queue = v);
    });
  }

  @override
  void dispose() {
    _connSub?.cancel();
    _queueSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final banner = _bannerFor(_online, _queue);
    return Column(
      children: [
        if (banner != null) banner,
        Expanded(child: widget.child),
      ],
    );
  }

  Widget? _bannerFor(bool online, SyncQueueState q) {
    if (!online) {
      return _Bar(
        color: const Color(0xFFFAEEDA),
        textColor: const Color(0xFF854F0B),
        icon: Icons.cloud_off,
        text: q.pending == 0
            ? 'You are offline. Changes will sync when you reconnect.'
            : 'Offline — ${q.pending} change${q.pending == 1 ? '' : 's'} queued.',
      );
    }
    if (q.syncing) {
      return _Bar(
        color: const Color(0xFFEAF3DE),
        textColor: const Color(0xFF27500A),
        icon: Icons.sync,
        text: 'Syncing ${q.inFlight} change${q.inFlight == 1 ? '' : 's'}…',
        animateIcon: true,
      );
    }
    if (q.pending > 0 || q.failed > 0) {
      final parts = <String>[];
      if (q.pending > 0) {
        parts.add('${q.pending} pending');
      }
      if (q.failed > 0) {
        parts.add('${q.failed} failed');
      }
      return _Bar(
        color: const Color(0xFFEFEDE6),
        textColor: const Color(0xFF222222),
        icon: q.failed > 0 ? Icons.error_outline : Icons.cloud_queue,
        text: parts.join(' · '),
      );
    }
    return null;
  }
}

class _Bar extends StatefulWidget {
  const _Bar({
    required this.color,
    required this.textColor,
    required this.icon,
    required this.text,
    this.animateIcon = false,
  });
  final Color color;
  final Color textColor;
  final IconData icon;
  final String text;
  final bool animateIcon;

  @override
  State<_Bar> createState() => _BarState();
}

class _BarState extends State<_Bar> with SingleTickerProviderStateMixin {
  late final AnimationController _spin;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    if (widget.animateIcon) _spin.repeat();
  }

  @override
  void didUpdateWidget(covariant _Bar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animateIcon && !_spin.isAnimating) _spin.repeat();
    if (!widget.animateIcon && _spin.isAnimating) _spin.stop();
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: widget.color,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              if (widget.animateIcon)
                RotationTransition(
                  turns: _spin,
                  child: Icon(widget.icon, size: 16, color: widget.textColor),
                )
              else
                Icon(widget.icon, size: 16, color: widget.textColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.text,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: widget.textColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
