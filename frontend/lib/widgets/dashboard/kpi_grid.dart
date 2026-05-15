// Reusable responsive grid for KPI / stat cards. Every module's
// "_KpiRow" widget delegates to this so the cross-module experience
// stays consistent and adjustments (breakpoints, spacing) happen in
// one place.
//
// Default breakpoints:
//   < 320 dp        → 1 col   (legacy tiny phones)
//   320 – 719 dp    → 2 cols  (all modern phones, portrait)
//   720 – 1023 dp   → 3 cols  (small tablets / landscape phones)
//   ≥ 1024 dp       → 4 cols  (large tablets, laptops, web)
//
// Callers pass an unconstrained `List<Widget>` of KPI cards. The grid
// computes the column count from the parent's `maxWidth` and sizes
// every cell equally — Wrap then handles odd counts by aligning the
// trailing card(s) to the start of the last row.

import 'package:flutter/material.dart';

class KpiGrid extends StatelessWidget {
  const KpiGrid({
    super.key,
    required this.children,
    this.spacing = 12,
    this.runSpacing = 12,
  });

  final List<Widget> children;
  final double spacing;
  final double runSpacing;

  /// Default breakpoints. Override by passing [colsFor] if a module
  /// needs different behavior (e.g. always 2-up regardless of width).
  static int defaultColsFor(double maxWidth) {
    if (maxWidth >= 1024) return 4;
    if (maxWidth >= 720) return 3;
    if (maxWidth >= 320) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, c) {
        // Guard against zero/unbounded width (e.g. inside a horizontally
        // scrolling parent) — fall back to 2-up which is the most useful
        // default for KPI cards on a phone form factor.
        final maxW = c.maxWidth.isFinite && c.maxWidth > 0
            ? c.maxWidth
            : MediaQuery.sizeOf(context).width;
        final cols = defaultColsFor(maxW).clamp(1, children.length);
        final cellW = (maxW - spacing * (cols - 1)) / cols;
        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: [
            for (final card in children) SizedBox(width: cellW, child: card),
          ],
        );
      },
    );
  }
}
