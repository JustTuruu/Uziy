import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../routes/app_router.dart';
import '../widgets/ui.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  /// Hero tag shared with the auth screens so the logo can fly across the
  /// splash -> login handoff.
  static const String logoHeroTag = 'uziy-logo';

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // Minimum splash time so the logo has time to breathe. Everyone lands on
    // Home: a guest browses there and is asked to sign in only when they
    // try to watch (the stored token was already restored in main()).
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    context.go(Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    // Logo only: no title, tagline or spinner on the splash.
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: AmbientBackground(
        variant: AmbientVariant.gold,
        child: SizedBox.expand(
          child: Center(child: _SplashMark()),
        ),
      ),
    );
  }
}

/// The animated splash logo: the tile scales in (0.85 -> 1, easeOutBack)
/// while fading up, a thin gold ring pings outward once, and a soft gold
/// halo slowly breathes behind it. Reduce-motion shows the settled state
/// with no animation at all.
class _SplashMark extends StatefulWidget {
  const _SplashMark();

  static const double logoSize = 120;
  static const double haloSize = 300;

  /// Entrance: logo in over the first ~60%, ring ping over the rest.
  static const Duration introDuration = Duration(milliseconds: 1100);

  /// One half-cycle of the breathing glow (it runs forward and back).
  static const Duration breathDuration = Duration(milliseconds: 2400);

  /// Half-cycles to breathe (~10 s). Far longer than the splash is shown;
  /// after that the halo rests, so it can never animate forever.
  static const int breathCycles = 4;

  @override
  State<_SplashMark> createState() => _SplashMarkState();
}

class _SplashMarkState extends State<_SplashMark>
    with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: _SplashMark.introDuration,
  );
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: _SplashMark.breathDuration,
  );

  late final Animation<double> _logoFade = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0, 0.4, curve: AppMotion.standard),
  );
  late final Animation<double> _logoScale = Tween<double>(
    begin: 0.85,
    end: 1,
  ).animate(
    CurvedAnimation(
      parent: _intro,
      curve: const Interval(0, 0.6, curve: AppMotion.emphasized),
    ),
  );
  late final Animation<double> _ring = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.3, 1, curve: AppMotion.standard),
  );
  late final Animation<double> _glow = CurvedAnimation(
    parent: _breath,
    curve: Curves.easeInOutSine,
  );
  bool _breathStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  /// Start the animations, or freeze them in their settled state when the
  /// OS asks for reduced motion (also if that changes while showing).
  void _syncMotion() {
    if (AppMotion.reduced(context)) {
      _intro.value = 1;
      _breath.value = 0.5;
      return;
    }
    if (_intro.value < 1 && !_intro.isAnimating) _intro.forward();
    if (!_breathStarted) {
      _breathStarted = true;
      _breath.repeat(reverse: true, count: _SplashMark.breathCycles);
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const logo = _SplashMark.logoSize;
    return SizedBox.square(
      dimension: _SplashMark.haloSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: ExcludeSemantics(
              child: CustomPaint(
                painter: _HaloPainter(fade: _logoFade, breath: _glow),
              ),
            ),
          ),
          ExcludeSemantics(
            child: AnimatedBuilder(
              animation: _ring,
              builder: (context, _) {
                final t = _ring.value;
                if (t <= 0 || t >= 1) return const SizedBox.shrink();
                return Opacity(
                  opacity: (1 - t) * 0.6,
                  child: Transform.scale(
                    scale: 1 + 0.75 * t,
                    child: Container(
                      width: logo,
                      height: logo,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(logo * 0.25),
                        border: Border.all(
                          color: AppColors.primaryLight,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          FadeTransition(
            opacity: _logoFade,
            child: ScaleTransition(
              scale: _logoScale,
              child: const UziyLogo(
                size: logo,
                heroTag: SplashScreen.logoHeroTag,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Soft gold radial halo behind the logo. Repaints on its animations
/// without rebuilding any widgets.
class _HaloPainter extends CustomPainter {
  _HaloPainter({required this.fade, required this.breath})
      : super(repaint: Listenable.merge([fade, breath]));

  final Animation<double> fade;
  final Animation<double> breath;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final b = breath.value;
    final a = fade.value;
    if (a <= 0) return;
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 * (0.84 + 0.16 * b);
    final alpha = a * (0.22 + 0.16 * b);
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.primary.withValues(alpha: alpha),
            AppColors.primaryDeep.withValues(alpha: alpha * 0.4),
            AppColors.primaryDeep.withValues(alpha: 0),
          ],
          stops: const [0, 0.45, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_HaloPainter oldDelegate) =>
      oldDelegate.fade != fade || oldDelegate.breath != breath;
}
