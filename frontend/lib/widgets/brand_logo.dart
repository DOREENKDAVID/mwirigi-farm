// Reusable Mwirigi Farm brand mark. Renders the logo at `assets/branding/
// logo.png` when available, and falls back to the previous text/icon
// treatment if the asset is missing or fails to decode — so the app
// keeps working before the file is dropped into place.

import 'package:flutter/material.dart';

const String _logoPath = 'assets/branding/logo.png';
const Color _brandPrimary = Color(0xFF27500A);

/// Wide horizontal logo — full "mwirigi FARM · MANAGE · GROW · PROSPER"
/// lockup. Use on splash / login / onboarding hero areas.
class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.height = 72,
    this.maxWidth = 280,
    this.fit = BoxFit.contain,
  });

  /// Target rendered height. Width is determined by [fit] + the asset's
  /// natural aspect ratio (capped at [maxWidth]).
  final double height;
  final double maxWidth;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Image.asset(
        _logoPath,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => _FallbackHero(height: height),
      ),
    );
  }
}

/// Compact horizontal lockup — logo image scaled down for AppBars,
/// drawer headers, badges, etc. Falls back to a text wordmark.
class BrandWordmark extends StatelessWidget {
  const BrandWordmark({
    super.key,
    this.height = 24,
    this.color,
  });

  final double height;
  /// Tint for the text fallback. The image asset is rendered as-is.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      _logoPath,
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => _FallbackWordmark(
        height: height,
        color: color ?? _brandPrimary,
      ),
    );
  }
}

/// Square mark — just a leaf-style avatar for tight chrome (drawer tile,
/// app-bar tap target). Falls back to "MF" monogram.
class BrandMark extends StatelessWidget {
  const BrandMark({
    super.key,
    this.size = 40,
    this.background = const Color(0xFFEAF3DE),
  });

  final double size;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(size * 0.22),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: Image.asset(
        _logoPath,
        width: size * 1.4,
        height: size * 1.4,
        // Crop the full lockup to roughly the leaf+"m" portion so the
        // mark feels balanced inside a square. Falls back to "MF".
        fit: BoxFit.cover,
        alignment: Alignment.centerLeft,
        errorBuilder: (_, __, ___) => _FallbackMark(size: size),
      ),
    );
  }
}

// ----------------- Fallbacks (used when logo.png is missing) ---------

class _FallbackHero extends StatelessWidget {
  const _FallbackHero({required this.height});
  final double height;
  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: EdgeInsets.symmetric(horizontal: height * 0.3),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF3DE),
        borderRadius: BorderRadius.circular(height * 0.25),
      ),
      // FittedBox lets the natural row size scale down when the
      // parent constraint is narrower than the icon + wordmark want
      // to be (e.g. the login card's 232px column).
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.park_rounded,
                size: height * 0.5, color: _brandPrimary),
            SizedBox(width: height * 0.18),
            Text(
              'mwirigi FARM',
              style: TextStyle(
                fontSize: height * 0.4,
                fontWeight: FontWeight.w800,
                color: _brandPrimary,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FallbackWordmark extends StatelessWidget {
  const _FallbackWordmark({required this.height, required this.color});
  final double height;
  final Color color;
  @override
  Widget build(BuildContext context) {
    // FittedBox so the compact wordmark also collapses cleanly when the
    // parent (e.g. the drawer header) is narrower than its natural size.
    return SizedBox(
      height: height,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.park_rounded, size: height * 0.7, color: color),
            SizedBox(width: height * 0.25),
            Text(
              'mwirigi FARM',
              style: TextStyle(
                fontSize: height * 0.55,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FallbackMark extends StatelessWidget {
  const _FallbackMark({required this.size});
  final double size;
  @override
  Widget build(BuildContext context) {
    return Text(
      'MF',
      style: TextStyle(
        fontSize: size * 0.42,
        fontWeight: FontWeight.w900,
        color: _brandPrimary,
        letterSpacing: 0.5,
      ),
    );
  }
}
