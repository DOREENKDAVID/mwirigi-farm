import 'package:flutter/material.dart';

import '../widgets/brand_logo.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_OnboardingSlide> _slides = const [
    _OnboardingSlide(
      titleStart: 'All-In-One ',
      titleHighlight: 'Farm Management',
      titleEnd: '',
      subtitle:
          'Monitor your farm, track performance and manage everything from '
          'one powerful dashboard.',
      icon: Icons.dashboard_rounded,
      imageAsset: 'assets/branding/onboarding/onboarding_1.png',
      imageAssetSecondary: 'assets/branding/onboarding/onboarding_1b.png',
      imageAssetTertiary: 'assets/branding/onboarding/onboarding_1c.png',
      cardColor: Color(0xFFEAF3DE),
    ),
    _OnboardingSlide(
      titleStart: 'Manage Livestock ',
      titleHighlight: 'With Ease',
      titleEnd: '',
      subtitle:
          'Track all your animals, feeds, breeding, and production in '
          'one place.',
      icon: Icons.pets_rounded,
      imageAsset: 'assets/branding/onboarding/onboarding_2.png',
      imageAssetSecondary: 'assets/branding/onboarding/onboarding_2b.png',
      imageAssetTertiary: 'assets/branding/onboarding/onboarding_2c.png',
      cardColor: Color(0xFFF2F7EA),
    ),
    _OnboardingSlide(
      titleStart: 'Work Together ',
      titleHighlight: 'Seamlessly',
      titleEnd: '',
      subtitle:
          'Assign tasks, set reminders, and keep your team aligned every '
          'day.',
      icon: Icons.groups_rounded,
      imageAsset: 'assets/branding/onboarding/onboarding_3.png',
      imageAssetSecondary: 'assets/branding/onboarding/onboarding_3b.png',
      imageAssetTertiary: 'assets/branding/onboarding/onboarding_3c.png',
      cardColor: Color(0xFFE7F0DA),
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToAuth() {
    Navigator.pushReplacementNamed(context, '/auth');
  }

  void _next() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
      );
      return;
    }
    _goToAuth();
  }

  void _previous() {
    if (_currentPage == 0) return;
    _pageController.previousPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF27500A);
    const textMuted = Color(0xFF667085);
    const screenBg = Color(0xFFF7F8F5);
    final isLastPage = _currentPage == _slides.length - 1;

    return Scaffold(
      backgroundColor: screenBg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 410;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    children: [
                      const BrandWordmark(height: 28),
                      const Spacer(),
                      TextButton(
                        onPressed: _goToAuth,
                        style: TextButton.styleFrom(
                          foregroundColor: textMuted,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: const Text('Skip'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _slides.length,
                    onPageChanged: (index) {
                      setState(() => _currentPage = index);
                    },
                    itemBuilder: (context, index) {
                      return _buildSlide(_slides[index], compact);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _slides.length,
                          (index) => _buildDot(index == _currentPage),
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (!isLastPage)
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _currentPage == 0 ? null : _previous,
                                style: OutlinedButton.styleFrom(
                                  minimumSize: Size(0, compact ? 48 : 52),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  side: const BorderSide(color: Color(0xFFCFE0B9)),
                                ),
                                child: const Text('Back'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton(
                                onPressed: _next,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primary,
                                  foregroundColor: Colors.white,
                                  minimumSize: Size(0, compact ? 48 : 52),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: const Text('Continue'),
                              ),
                            ),
                          ],
                        )
                      else
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _next,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primary,
                              foregroundColor: Colors.white,
                              minimumSize: Size(0, compact ? 50 : 54),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text('Get Started'),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSlide(_OnboardingSlide slide, bool compact) {
    const titleBase = TextStyle(
      fontSize: 29,
      fontWeight: FontWeight.w800,
      color: Color(0xFF1D2D14),
      height: 1.15,
    );

    const titleHighlight = TextStyle(
      fontSize: 29,
      fontWeight: FontWeight.w800,
      color: Color(0xFF27500A),
      height: 1.15,
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(compact ? 20 : 30, 10, compact ? 20 : 30, 0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: double.infinity,
            constraints: BoxConstraints(maxHeight: compact ? 230 : 260),
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                colors: [Color(0xFFF4F8ED), Color(0xFFFFFFFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: const Color(0xFFE3ECD8)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Align(
                  alignment: Alignment.bottomRight,
                  child: Icon(
                    Icons.eco_rounded,
                    size: compact ? 90 : 110,
                    color: const Color(0xFFDBEAC8),
                  ),
                ),
                // Back-left peek card — tilted counter-clockwise,
                // pushed out enough to clear the front card so it
                // actually peeks visibly (not hidden behind it).
                if (slide.imageAssetSecondary != null)
                  _StackPreviewCard(
                    asset: slide.imageAssetSecondary!,
                    rotationRad: -0.22,
                    offset: Offset(compact ? -90 : -110, compact ? 4 : 8),
                    scale: 0.78,
                  ),
                // Back-right peek card — tilted clockwise, mirrors
                // the left peek.
                if (slide.imageAssetTertiary != null)
                  _StackPreviewCard(
                    asset: slide.imageAssetTertiary!,
                    rotationRad: 0.22,
                    offset: Offset(compact ? 90 : 110, compact ? 4 : 8),
                    scale: 0.78,
                  ),
                // Front card — the primary hero image.
                if (slide.imageAsset != null)
                  Positioned.fill(
                    child: Image.asset(
                      slide.imageAsset!,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) =>
                          _IconHero(slide: slide, compact: compact),
                    ),
                  )
                else
                  _IconHero(slide: slide, compact: compact),
              ],
            ),
          ),
          const SizedBox(height: 26),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: titleBase.copyWith(fontSize: compact ? 25 : 29),
              children: [
                TextSpan(text: slide.titleStart),
                TextSpan(
                  text: slide.titleHighlight,
                  style: titleHighlight.copyWith(fontSize: compact ? 25 : 29),
                ),
                TextSpan(text: slide.titleEnd),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            slide.subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xFF667085),
              fontSize: compact ? 14 : 15,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(bool selected) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      height: 8,
      width: selected ? 24 : 8,
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF27500A) : const Color(0xFFD4DECA),
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }
}

/// Tilted preview card rendered behind the primary hero image. Gives
/// the slide a card-stack look like the reference mockup. Silently
/// degrades to an empty SizedBox if the asset is missing so missing
/// PNGs never break the layout.
class _StackPreviewCard extends StatelessWidget {
  const _StackPreviewCard({
    required this.asset,
    required this.rotationRad,
    required this.offset,
    required this.scale,
  });

  final String asset;
  final double rotationRad;
  final Offset offset;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: offset,
      child: Transform.rotate(
        angle: rotationRad,
        child: Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: 0.85,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE3ECD8)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 18,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset(
                asset,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Centered icon-on-rounded-card hero. Used as the default rendering
/// when a slide has no [imageAsset], and as the graceful fallback when
/// the asset fails to load.
class _IconHero extends StatelessWidget {
  const _IconHero({required this.slide, required this.compact});
  final _OnboardingSlide slide;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: Container(
        width: compact ? 128 : 150,
        height: compact ? 128 : 150,
        decoration: BoxDecoration(
          color: slide.cardColor,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Icon(
          slide.icon,
          size: compact ? 64 : 72,
          color: const Color(0xFF27500A),
        ),
      ),
    );
  }
}

class _OnboardingSlide {
  final String titleStart;
  final String titleHighlight;
  final String titleEnd;
  final String subtitle;
  final IconData icon;
  final Color cardColor;
  /// Primary hero image. When present it replaces the [icon]; if it's
  /// missing or fails to load, the slide falls back to the icon so
  /// onboarding never renders empty.
  final String? imageAsset;
  /// Optional secondary image rendered as a tilted "preview" card
  /// behind the primary hero on the LEFT — gives the slide a
  /// card-stack feel.
  final String? imageAssetSecondary;
  /// Optional tertiary image rendered as a tilted "preview" card on
  /// the RIGHT side, mirroring [imageAssetSecondary]. Together they
  /// give the slide a three-card layered look like the v4.5 mockup.
  final String? imageAssetTertiary;

  const _OnboardingSlide({
    required this.titleStart,
    required this.titleHighlight,
    required this.titleEnd,
    required this.subtitle,
    required this.icon,
    required this.cardColor,
    this.imageAsset,
    this.imageAssetSecondary,
    this.imageAssetTertiary,
  });
}
