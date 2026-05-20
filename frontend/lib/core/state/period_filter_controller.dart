// =====================================================================
// PeriodFilterController — global analytics-filter state
// =====================================================================
// One source of truth for the time-period + house selection that
// drives the CEO Overview scope strip, the Layers Production
// analytics, and the Dairy Milk analytics section.
//
// Exposed via Provider at the app root so navigating between tabs
// preserves the selection (per the Phase 2 spec "select Last Month,
// switch from Overview → Milk, period remains selected"). State is
// in-memory only — picks reset on cold start. If we ever want
// persistence we can add SharedPreferences here; the controller is
// the right seam for that.

import 'package:flutter/foundation.dart';

import '../util/period.dart';

class PeriodFilterController extends ChangeNotifier {
  PeriodFilterController({
    PeriodPreset initialPeriod = PeriodPreset.thisMonth,
  }) : _period = initialPeriod;

  PeriodPreset _period;
  DateTime? _customStart;
  DateTime? _customEnd;
  String? _houseId;

  /// Active preset. Defaults to "This Month" — same default the
  /// CEO Overview already uses so an unconfigured controller doesn't
  /// surprise anyone.
  PeriodPreset get period => _period;

  /// Custom range. Only meaningful when [period] == PeriodPreset.custom.
  DateTime? get customStart => _customStart;
  DateTime? get customEnd => _customEnd;

  /// Active house filter. `null` means "All houses". The string is the
  /// House.id from the backend — callers thread it as-is into their
  /// analytics requests.
  String? get houseId => _houseId;

  /// True when [period] requires a non-null `startDate` + `endDate` to
  /// actually fetch. Callers use this to decide whether to skip the
  /// fetch (avoid 400s) until the user picks both dates.
  bool get isReady {
    if (_period != PeriodPreset.custom) return true;
    return _customStart != null && _customEnd != null;
  }

  void setPeriod(PeriodPreset next) {
    if (next == _period) return;
    _period = next;
    notifyListeners();
  }

  /// Set both halves of the custom range atomically. Also flips
  /// [period] to `custom` so a single call captures the full intent.
  void setCustomRange(DateTime start, DateTime end) {
    _customStart = start;
    _customEnd = end;
    _period = PeriodPreset.custom;
    notifyListeners();
  }

  /// Tap-active-to-reset behaviour — if the caller passes the
  /// currently-selected id, clear the filter (null = "All houses").
  void setHouseId(String? next) {
    final resolved = next == _houseId ? null : next;
    if (resolved == _houseId) return;
    _houseId = resolved;
    notifyListeners();
  }

  /// One-shot reset used by tests and the (future) "Clear filters" UI.
  /// Doesn't notify when nothing actually changes.
  void reset() {
    final changed = _period != PeriodPreset.thisMonth ||
        _customStart != null ||
        _customEnd != null ||
        _houseId != null;
    _period = PeriodPreset.thisMonth;
    _customStart = null;
    _customEnd = null;
    _houseId = null;
    if (changed) notifyListeners();
  }
}
