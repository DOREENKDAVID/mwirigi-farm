import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// App-wide connectivity state used by the global banner, repositories
/// (to decide local vs remote-first), and the SyncQueue (to decide
/// whether to flush). Singleton — call [ConnectivityService.instance]
/// from anywhere; call [start] once at app boot.
class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  final _controller = StreamController<bool>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _isOnline = true;

  /// Latest observed state. May be optimistic — it only flips once the
  /// platform reports a change. Use [stream] to react to transitions.
  bool get isOnline => _isOnline;
  Stream<bool> get stream => _controller.stream;

  /// Wire up the platform stream. Idempotent; safe to call from main()
  /// even if hot reload re-runs main repeatedly during dev.
  Future<void> start() async {
    if (_sub != null) return;
    final c = Connectivity();
    final initial = await c.checkConnectivity();
    _updateFromResults(initial);
    _sub = c.onConnectivityChanged.listen(_updateFromResults);
  }

  void _updateFromResults(List<ConnectivityResult> results) {
    // Treat any non-none result as "online". The platform reports
    // mobile / wifi / ethernet etc; only `ConnectivityResult.none`
    // is unambiguously offline.
    final online = results.any((r) => r != ConnectivityResult.none);
    if (online == _isOnline) return;
    _isOnline = online;
    _controller.add(online);
    if (kDebugMode) {
      debugPrint('[connectivity] ${online ? "ONLINE" : "OFFLINE"}');
    }
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    await _controller.close();
  }
}
