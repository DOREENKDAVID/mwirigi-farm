// Responsive layout helpers used across the Mwirigi Farm app.
//
// Conventions:
//   • mobile     — width <  600 dp
//   • tablet     — width >= 600 dp and < 1024 dp
//   • desktop    — width >= 1024 dp
//
// These match the Material 3 breakpoint guidance and the existing
// LayoutBuilder thresholds already used by the dashboard / piggery /
// feedlot pages. Helpers are intentionally pure functions so they can be
// called from inside build() without `BuildContext` if a width is
// already known.

import 'dart:math';

import 'package:flutter/material.dart';

/// Width breakpoints (dp).
class Breakpoints {
  static const double mobile = 600;
  static const double tablet = 1024;
}

/// True when the device's shortest side is at least 600 dp. Matches
/// MediaQuery convention for "this is a tablet form factor regardless
/// of current orientation". Use this for decisions that should not
/// flip when the user rotates the device (navigation pattern, sidebar
/// visibility, etc.).
bool isTabletForm(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  return size.shortestSide >= Breakpoints.mobile;
}

/// True when the available width is at least 600 dp. Use this for
/// layout decisions that should adapt on rotation (column count,
/// row vs. column for paired widgets).
bool isWide(BuildContext context, [double threshold = Breakpoints.mobile]) {
  return MediaQuery.sizeOf(context).width >= threshold;
}

/// Standard bottom padding for module pages. Leaves room for the
/// system gesture bar and any future bottom nav without hiding content.
const double kPageBottomPadding = 80;

/// Standard top/horizontal page padding.
const EdgeInsets kPagePadding =
    EdgeInsets.fromLTRB(20, 20, 20, kPageBottomPadding);

/// Compact variant for narrow phones — collapses horizontal padding to
/// 16 so cards keep some breathing room without crowding the edge.
EdgeInsets pagePadding(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  final hPad = w < 360 ? 12.0 : (w < 480 ? 16.0 : 20.0);
  return EdgeInsets.fromLTRB(hPad, 20, hPad, kPageBottomPadding);
}

/// Choose a chart height that scales gently with the viewport so charts
/// don't dominate landscape phones or feel cramped on tablets.
///
///   base   — the "design" height (e.g. 200 from the HTML mockup).
///   minPx  — never go below this (default 140).
///   maxPx  — never exceed this (default 360 on tablets / 280 on phones).
double chartHeight(
  BuildContext context, {
  required double base,
  double minPx = 140,
  double? maxPx,
}) {
  final mq = MediaQuery.sizeOf(context);
  final cap = maxPx ?? (mq.shortestSide >= Breakpoints.mobile ? 360 : 280);
  // Allow ~40% of the viewport height for a chart so it doesn't push
  // every other section below the fold on short landscape phones.
  final byViewport = mq.height * 0.4;
  return max(minPx, min(cap, min(base, byViewport)));
}

/// Compute a column count from a target tile width. Use when you want
/// roughly the same tile size across phone / tablet rather than a
/// fixed crossAxisCount.
///
///   GridView.count(crossAxisCount: gridColumns(c.maxWidth, target: 180))
int gridColumns(double availableWidth,
    {required double target, int minCols = 1, int maxCols = 6}) {
  final cols = (availableWidth / target).floor();
  return cols.clamp(minCols, maxCols);
}

/// Clamp the system text scaler so accessibility users with extreme
/// font scaling don't break fixed-height widgets, while still giving
/// users a reasonable boost. Returns a MediaQuery with the clamped
/// scaler — wire it in via MaterialApp.builder.
Widget clampedTextScaler(BuildContext context, Widget? child) {
  final mq = MediaQuery.of(context);
  final scaler = mq.textScaler.clamp(minScaleFactor: 0.85, maxScaleFactor: 1.3);
  return MediaQuery(
    data: mq.copyWith(textScaler: scaler),
    child: child ?? const SizedBox.shrink(),
  );
}
