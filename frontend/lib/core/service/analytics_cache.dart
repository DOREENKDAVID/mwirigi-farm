// =====================================================================
// Analytics cache + debouncer
// =====================================================================
//
// Tiny in-memory layer between the period/house pills and the API.
// Two jobs:
//
//   1. Skip re-fetches when the user lands on the same filter selection
//      they were already viewing (cache hit by signature).
//   2. Debounce rapid pill taps — if the user clicks Today → Yesterday
//      → Today in under 250ms we only fire one request, for the final
//      selection.
//
// Per-key, not global, so concurrent modules (Layers + Dairy) don't
// step on each other's debounce timers. Entries are pruned by a tiny
// LRU bound — analytics responses can be ~50KB and we don't want to
// hoard them.

import 'dart:async';

class AnalyticsCache {
  AnalyticsCache({
    this.debounceMs = 200,
    this.maxEntries = 24,
  });

  final int debounceMs;
  final int maxEntries;

  // Keyed by the caller-supplied signature (typically
  // "endpoint|period|houseId|start|end"). LinkedHashMap order =
  // insertion order, which gives us LRU eviction for free.
  final Map<String, dynamic> _entries = <String, dynamic>{};
  final Map<String, Timer> _pending = <String, Timer>{};

  /// Returns the cached response for [key] when present, else `null`.
  /// Touching a key moves it to the end of the LRU window.
  dynamic peek(String key) {
    if (!_entries.containsKey(key)) return null;
    final v = _entries.remove(key);
    _entries[key] = v;
    return v;
  }

  /// Insert / overwrite the value for [key]. Evicts the oldest entry
  /// when the cache exceeds [maxEntries].
  void put(String key, dynamic value) {
    if (_entries.containsKey(key)) _entries.remove(key);
    _entries[key] = value;
    while (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first);
    }
  }

  /// Fetch-or-cache with debounce. Behaviour:
  ///   * If [key] is in cache, returns immediately (cache hit).
  ///   * Otherwise, schedules [fetch] after [debounceMs]. If a newer
  ///     call to `run(key, ...)` arrives in that window it replaces
  ///     the pending fetch — only the last one runs.
  ///   * The returned Future resolves with the **most recent**
  ///     fetch's result for [key], so consumers can `await` it safely
  ///     and always get fresh data.
  Future<T> run<T>(String key, Future<T> Function() fetch) {
    final hit = peek(key);
    if (hit != null) return Future.value(hit as T);

    // Drop any scheduled-but-not-yet-fired fetch for this key.
    _pending[key]?.cancel();

    final completer = Completer<T>();
    _pending[key] = Timer(Duration(milliseconds: debounceMs), () async {
      _pending.remove(key);
      try {
        final value = await fetch();
        put(key, value);
        if (!completer.isCompleted) completer.complete(value);
      } catch (e, st) {
        if (!completer.isCompleted) completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  /// Drop everything. Useful for "Refresh" pull-to-reload buttons
  /// where the user wants fresh data even when the signature matches.
  void clear() {
    _entries.clear();
    for (final t in _pending.values) {
      t.cancel();
    }
    _pending.clear();
  }
}
