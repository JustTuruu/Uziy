import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/format.dart';

/// Deterministic brand gradient ([bright, mid, deep]) for a campaign.
///
/// Same [seed] -> same palette on every device. Any int works, including
/// negatives and huge values (Dart's `%` is always non-negative for a
/// positive divisor). Consecutive ids get different palettes.
List<Color> campaignPalette(int seed) {
  const palettes = AppGradients.campaignPalettes;
  return palettes[seed % palettes.length];
}

/// Fill-the-parent artwork for a campaign card / player backdrop.
///
/// Does not impose an aspect ratio — wrap it in `AspectRatio(16 / 9)` (or
/// any box). If it is placed where a dimension is unbounded (e.g. straight
/// into a Column or ListView) it falls back to 16:9 of the available width
/// instead of throwing. With a non-empty [thumbnailUrl] the network image
/// fades in over the generated art, which stays underneath as the loading
/// placeholder and as the fallback if the image fails; the image is decoded
/// at (roughly) display size to keep feed memory low. Generated art =
/// [campaignPalette] gradient + a big faded company monogram + a subtle
/// pattern (diagonal lines for video, dots for survey-only) + a soft glow.
/// Purely decorative (no semantics) and isolated in its own repaint
/// boundary, so press-scale / entrance animations on the card stay cheap.
class CampaignArt extends StatelessWidget {
  const CampaignArt({
    super.key,
    required this.campaignId,
    required this.companyName,
    this.thumbnailUrl,
    this.hasVideo = true,
    this.borderRadius,
  });

  final int campaignId;
  final String companyName;
  final String? thumbnailUrl;
  final bool hasVideo;
  final BorderRadius? borderRadius;

  /// Aspect ratio used when the parent leaves a dimension unbounded, and
  /// assumed for thumbnails when choosing the decode size.
  static const double fallbackAspectRatio = 16 / 9;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.hasBoundedWidth && constraints.hasBoundedHeight) {
          return _art(context, constraints.biggest);
        }
        // Misuse guard: no bounded box -> 16:9 of whatever is bounded.
        final w = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : constraints.hasBoundedHeight
                ? constraints.maxHeight * fallbackAspectRatio
                : 320.0;
        final h = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : w / fallbackAspectRatio;
        final size = constraints.constrain(Size(w, h));
        return SizedBox.fromSize(size: size, child: _art(context, size));
      },
    );
  }

  Widget _art(BuildContext context, Size size) {
    final palette = campaignPalette(campaignId);
    final url = thumbnailUrl?.trim() ?? '';
    final h = size.height.isFinite && size.height > 0 ? size.height : 180.0;

    // Decode near display size. `cover` needs the larger of the box width
    // and the width a 16:9 image needs to cover the box height. Image never
    // upscales past the source, so over-asking is harmless.
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 2.0;
    final coverWidth = math.max(size.width, h * fallbackAspectRatio);
    final cacheWidth = (coverWidth * dpr).round();

    final art = Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: palette,
              stops: const [0.0, 0.55, 1.0],
            ),
          ),
        ),
        CustomPaint(painter: _PatternPainter(dots: !hasVideo)),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-0.75, -0.9),
              radius: 1.1,
              colors: [Color(0x2EFFFFFF), Color(0x00FFFFFF)],
            ),
          ),
        ),
        Align(
          alignment: const Alignment(0.92, 0.6),
          child: Text(
            monogramOf(companyName),
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.visible,
            // Artwork, not reading text: sized from the box, never from the
            // OS text-size setting.
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              fontSize: h * 0.95,
              height: 1.0,
              fontWeight: FontWeight.w900,
              letterSpacing: -4,
              color: Colors.white.withValues(alpha: 0.11),
            ),
          ),
        ),
        if (url.isNotEmpty)
          Image.network(
            url,
            fit: BoxFit.cover,
            excludeFromSemantics: true,
            cacheWidth: cacheWidth > 0 ? cacheWidth : null,
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded) return child;
              return AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: AppMotion.duration(context, AppDurations.medium),
                curve: Curves.easeOut,
                child: child,
              );
            },
            // Fall back to the generated art underneath.
            errorBuilder: (context, error, stack) => const SizedBox.shrink(),
          ),
      ],
    );

    return ExcludeSemantics(
      child: RepaintBoundary(
        child: borderRadius == null
            ? ClipRect(child: art)
            : ClipRRect(borderRadius: borderRadius!, child: art),
      ),
    );
  }
}

class _PatternPainter extends CustomPainter {
  _PatternPainter({required this.dots});

  final bool dots;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.05);
    if (dots) {
      const step = 16.0;
      for (var y = step / 2; y < size.height; y += step) {
        for (var x = step / 2; x < size.width; x += step) {
          canvas.drawCircle(Offset(x, y), 1.1, paint);
        }
      }
    } else {
      paint
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke;
      const step = 18.0;
      for (var x = -size.height; x < size.width; x += step) {
        canvas.drawLine(
          Offset(x, size.height),
          Offset(x + size.height, 0),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_PatternPainter oldDelegate) => oldDelegate.dots != dots;
}
