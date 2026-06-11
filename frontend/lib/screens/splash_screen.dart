// Multi-stage Mwirigi Farm splash. Four green panels slide off the
// edges in sequence, revealing the brand lockup that fades + scales
// in. After a short hold the screen replaces itself with /onboarding.
//
// Theme palette (matches the rest of the app):
//   Primary green   #27500A — dark farm green, used by KpiCard,
//                              FilledButtons, header titles
//   Accent green    #639922 — "Live" pulse dot, secondary accent
//   Cream surface   #FAFBF6 — same warm cream as the app background
//   Soft border     #EAF3DE — drawer / chip neutrals

import 'package:flutter/material.dart';

import '../core/service/api_service.dart';
import '../widgets/brand_logo.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Mwirigi palette.
  static const _primary = Color(0xFF27500A);
  static const _accent = Color(0xFF639922);
  static const _surface = Color(0xFFFAFBF6);

  late final AnimationController _panelTopLeft;
  late final AnimationController _panelTopRight;
  late final AnimationController _panelBottomLeft;
  late final AnimationController _panelBottomRight;
  late final AnimationController _logoController;

  late final Animation<Offset> _slideTopLeft;
  late final Animation<Offset> _slideTopRight;
  late final Animation<Offset> _slideBottomLeft;
  late final Animation<Offset> _slideBottomRight;
  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;

  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runSequence());
  }

  void _initAnimations() {
    AnimationController panel() => AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 520),
        );
    _panelTopLeft = panel();
    _panelTopRight = panel();
    _panelBottomLeft = panel();
    _panelBottomRight = panel();

    Animation<Offset> slide(AnimationController c, Offset target) =>
        Tween<Offset>(begin: Offset.zero, end: target).animate(
          CurvedAnimation(parent: c, curve: Curves.easeInOutCubic),
        );
    _slideTopLeft = slide(_panelTopLeft, const Offset(-1.2, -1.2));
    _slideTopRight = slide(_panelTopRight, const Offset(1.2, -1.2));
    _slideBottomLeft = slide(_panelBottomLeft, const Offset(-1.2, 1.2));
    _slideBottomRight = slide(_panelBottomRight, const Offset(1.2, 1.2));

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _logoFade = CurvedAnimation(
      parent: _logoController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
    );
    _logoScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutBack),
    );
  }

  Future<void> _runSequence() async {
    // Diagonal-pair reveal: top-left + bottom-right first, then the
    // remaining corners. Reads more naturally than going clockwise.
    _panelTopLeft.forward();
    _panelBottomRight.forward();
    await Future.delayed(const Duration(milliseconds: 220));
    _panelTopRight.forward();
    _panelBottomLeft.forward();

    // Start the logo halfway through the panel slide so the screen
    // doesn't feel empty mid-animation.
    await Future.delayed(const Duration(milliseconds: 260));
    if (!mounted) return;
    _logoController.forward();

    // Hold the finished frame so the brand lands before we transition.
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted || _navigated) return;
    _navigated = true;
    final token = await ApiService.readToken();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(
      token != null ? '/dashboard' : '/onboarding',
    );
  }

  @override
  void dispose() {
    _panelTopLeft.dispose();
    _panelTopRight.dispose();
    _panelBottomLeft.dispose();
    _panelBottomRight.dispose();
    _logoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    // Each panel covers a quadrant of the screen.
    final panelW = size.width / 2 + 1; // +1 to hide subpixel seams
    final panelH = size.height / 2 + 1;

    return Scaffold(
      backgroundColor: _surface,
      body: Stack(
        children: [
          // Subtle radial wash behind the logo — matches the cream
          // background used elsewhere with a hint of green at center.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.9,
                  colors: [
                    _surface,
                    _surface.withValues(alpha: 0.6),
                  ],
                ),
              ),
            ),
          ),

          // Four animated panels — primary dark green + lighter accent
          // for the bottom pair so the reveal has visual depth.
          _Panel(
            slide: _slideTopLeft,
            width: panelW,
            height: panelH,
            alignment: Alignment.topLeft,
            color: _primary,
          ),
          _Panel(
            slide: _slideTopRight,
            width: panelW,
            height: panelH,
            alignment: Alignment.topRight,
            color: _primary,
          ),
          _Panel(
            slide: _slideBottomLeft,
            width: panelW,
            height: panelH,
            alignment: Alignment.bottomLeft,
            color: _accent,
          ),
          _Panel(
            slide: _slideBottomRight,
            width: panelW,
            height: panelH,
            alignment: Alignment.bottomRight,
            color: _accent,
          ),

          // Brand lockup — fades + scales in after the panels start
          // sliding. Uses the BrandLogo widget so it gracefully falls
          // back to the text wordmark if logo.png is not yet on disk.
          Center(
            child: FadeTransition(
              opacity: _logoFade,
              child: ScaleTransition(
                scale: _logoScale,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: BrandLogo(
                    height: (size.shortestSide * 0.32).clamp(110, 200),
                    maxWidth: 360,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.slide,
    required this.width,
    required this.height,
    required this.alignment,
    required this.color,
  });

  final Animation<Offset> slide;
  final double width;
  final double height;
  final Alignment alignment;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: slide,
      child: Align(
        alignment: alignment,
        child: Container(width: width, height: height, color: color),
      ),
    );
  }
}
