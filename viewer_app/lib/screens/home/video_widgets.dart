import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../../widgets/ui.dart';

// Presentational pieces of the video player screen.
//
// Kept apart from video_player_screen.dart so they can be widget-tested
// without importing the router (app_router.dart imports every screen). This
// file must never import app_router.dart, directly or transitively.

// --- Layout constants ----------------------------------------------------------

/// Aspect ratio the stage frame uses until the real player reports one
/// (TV-style 16:9 sponsor spots are the common case).
const double kDefaultVideoAspect = 16 / 9;

/// Widest the video frame gets. The top bar and the info panel content use
/// the same cap, so on tablets all three share one column edge.
const double kStageMaxWidth = 720;

/// Below this top-bar content width the sponsor avatar and the
/// 'Ивээн тэтгэгч' caption are hidden so the company name keeps its room
/// (roughly screens narrower than 360 pt).
const double kSponsorDetailsMinWidth = 320;

/// Width over which the locked CTA's gold fill brightens at its leading
/// edge.
const double kChargeEdgeWidth = 12;

// --- Pure helpers ------------------------------------------------------------

/// Player clock label, same as the kit's [formatClock] so every time on the
/// screen reads alike.
///
/// * `0` -> `'0:00'`, `5` -> `'0:05'`, `59` -> `'0:59'`
/// * `60` -> `'1:00'`, `61` -> `'1:01'`, `125` -> `'2:05'`
///
/// Fractions are truncated (`12.75` -> `'0:12'`). Negative / non-finite
/// input is treated as 0.
String formatPlaybackTime(num seconds) => formatClock(seconds);

/// Duration as screen readers should say it: `'3 сек'`, `'2 мин'`,
/// `'2 мин 5 сек'`. Fractions are truncated; negative / non-finite is 0.
String spokenDuration(num seconds) {
  final total = (seconds.isFinite && seconds > 0) ? seconds.truncate() : 0;
  final m = total ~/ 60;
  final s = total % 60;
  if (m == 0) return '$s сек';
  if (s == 0) return '$m мин';
  return '$m мин $s сек';
}

/// Watched fraction in `[0, 1]`. A video with no length counts as fully
/// watched (1.0), matching the full-watch gate (`elapsed >= duration`).
double watchProgressFraction(double elapsedSeconds, int durationSeconds) {
  if (durationSeconds <= 0) return 1.0;
  if (!elapsedSeconds.isFinite) return 0.0;
  return (elapsedSeconds / durationSeconds).clamp(0.0, 1.0);
}

/// Whole seconds still to watch, rounded UP so the countdown never shows 0
/// while the gate is still closed. Never negative.
int remainingWatchSeconds(double elapsedSeconds, int durationSeconds) {
  final left = durationSeconds - elapsedSeconds;
  if (!left.isFinite || left <= 0) return 0;
  return left.ceil();
}

/// Largest frame of [aspect] (width / height) that fits [space], at most
/// [maxWidth] wide.
///
/// The screen passes [kDefaultVideoAspect] for now; once video_player is
/// wired it passes the controller's `value.aspectRatio`, so a 9:16 vertical
/// ad fills a tall stage and a 16:9 spot is never cropped or letterboxed.
///
/// An invalid [aspect] falls back to 16:9. An unbounded height gives the
/// width-limited frame; zero, negative or NaN space gives [Size.zero].
Size stageFrameSize(
  Size space, {
  double aspect = kDefaultVideoAspect,
  double maxWidth = kStageMaxWidth,
}) {
  final a = (aspect.isFinite && aspect > 0) ? aspect : kDefaultVideoAspect;
  final w = math.min(space.width, maxWidth);
  final h = space.height;
  if (!(w > 0) || !w.isFinite || !(h > 0)) return Size.zero;
  if (!h.isFinite) return Size(w, w / a);
  return w / h > a ? Size(h * a, h) : Size(w, w / a);
}

/// Landscape of any size (rotated phones, split screen, tablets) puts the
/// info panel beside the stage instead of under it.
bool useSidePanel(Size screen) => screen.width > screen.height;

/// Width of the landscape side panel: 42% of the screen within 260..400,
/// but never more than half the screen so the stage keeps its share.
double sidePanelWidth(double screenWidth) {
  if (!(screenWidth > 0)) return 0;
  final preferred = (screenWidth * 0.42).clamp(260.0, 400.0);
  return math.min(preferred, screenWidth / 2);
}

/// Short screens (iPhone SE, landscape phones) get a tighter panel rhythm.
bool useCompactPanel(Size screen) => screen.height < 700;

/// Whether the top bar has room for the sponsor avatar and caption next to
/// the company name. [contentWidth] is the bar's width inside its padding.
bool showSponsorDetails(double contentWidth) =>
    contentWidth >= kSponsorDetailsMinWidth;

/// Gradient stop where the locked CTA's fill starts brightening toward its
/// leading edge: the last [kChargeEdgeWidth] px of a fill [fillWidth] wide.
/// 0 while the fill is narrower than the edge.
double chargeEdgeStop(double fillWidth) {
  if (!(fillWidth > kChargeEdgeWidth)) return 0;
  if (!fillWidth.isFinite) return 1;
  return 1 - kChargeEdgeWidth / fillWidth;
}

/// Opacity of the fill's leading edge. It fades in over the first
/// 3 x [kChargeEdgeWidth] px, so a sliver of progress tucked into the
/// button's rounded corner never reads as a stray gold bar.
double chargeEdgeAlpha(double fillWidth) {
  const base = 0.24;
  const peak = 0.5;
  if (fillWidth.isNaN || fillWidth <= 0) return base;
  if (!fillWidth.isFinite) return peak;
  final t = (fillWidth / (kChargeEdgeWidth * 3)).clamp(0.0, 1.0);
  return base + (peak - base) * t;
}

// --- Sponsor avatar ----------------------------------------------------------

/// Round brand avatar: the campaign palette gradient with the company's
/// monogram. Decorative (the company name is always shown next to it).
class SponsorAvatar extends StatelessWidget {
  const SponsorAvatar({
    super.key,
    required this.campaignId,
    required this.companyName,
    this.size = 36,
  });

  final int campaignId;
  final String companyName;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = campaignPalette(campaignId);
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [palette[0], palette[1]],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
          boxShadow: AppShadows.soft,
        ),
        child: Text(
          monogramOf(companyName),
          maxLines: 1,
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            fontSize: size * 0.44,
            height: 1.0,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

// --- Close button ------------------------------------------------------------

/// Round close control for the player's top bar.
///
/// A lighter glass than the kit's `AppIconButtonVariant.glass` (white 12%
/// fill, white 16% ring) so it stays visible over the dark stage backdrop.
/// 44 pt tap target, announced as 'Хаах'.
class StageCloseButton extends StatelessWidget {
  const StageCloseButton({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  static const semanticLabel = 'Хаах';

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onPressed,
      scale: 0.92,
      semanticLabel: semanticLabel,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: AppLayout.minTapTarget,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
          ),
          child: const Icon(
            Icons.close_rounded,
            size: 20,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

// --- Play / pause medallion --------------------------------------------------

enum _MedallionState { playing, paused, completed }

/// The big round control in the middle of the stage.
///
/// * playing: small, dimmed glass disc with a pause glyph.
/// * paused: gold disc with a play glyph, gold glow, and a 'Түр зогссон'
///   label underneath.
/// * completed: glass disc with a gold ring and check, 'Бүтэн үзлээ' label.
///
/// Glyph changes cross-fade with a small scale pop. Purely visual: the
/// screen owns the tap target, its semantics and when it is shown. Pass
/// `showLabel: false` where there is no room for the label under the disc.
class PlayPauseMedallion extends StatelessWidget {
  const PlayPauseMedallion({
    super.key,
    required this.paused,
    this.completed = false,
    this.size = 76,
    this.showLabel = true,
  });

  final bool paused;
  final bool completed;
  final double size;
  final bool showLabel;

  static const pausedLabel = 'Түр зогссон';
  static const completedLabel = 'Бүтэн үзлээ';

  _MedallionState get _state => completed
      ? _MedallionState.completed
      : paused
          ? _MedallionState.paused
          : _MedallionState.playing;

  static LinearGradient _solid(Color c) => LinearGradient(colors: [c, c]);

  @override
  Widget build(BuildContext context) {
    final state = _state;
    final dur = AppMotion.duration(context, AppDurations.normal);
    final glass = Colors.black.withValues(alpha: 0.4);

    final (Gradient gradient, Color border, List<BoxShadow> shadows) =
        switch (state) {
      _MedallionState.playing => (
          _solid(glass),
          Colors.white.withValues(alpha: 0.16),
          AppShadows.soft,
        ),
      _MedallionState.paused => (
          AppGradients.gold,
          Colors.white.withValues(alpha: 0.3),
          AppShadows.glow(AppColors.primary, blur: 28),
        ),
      _MedallionState.completed => (
          _solid(glass),
          AppColors.primary,
          AppShadows.glow(AppColors.primary, strength: 0.6, blur: 28),
        ),
    };

    final (IconData icon, Color iconColor) = switch (state) {
      _MedallionState.playing => (Icons.pause_rounded, Colors.white),
      _MedallionState.paused => (Icons.play_arrow_rounded, AppColors.onPrimary),
      _MedallionState.completed => (Icons.check_rounded, AppColors.primary),
    };

    final disc = AnimatedScale(
      scale: state == _MedallionState.playing ? 0.86 : 1.0,
      duration: dur,
      curve: AppMotion.emphasized,
      child: AnimatedOpacity(
        opacity: state == _MedallionState.playing ? 0.78 : 1.0,
        duration: dur,
        curve: AppMotion.standard,
        child: AnimatedContainer(
          duration: dur,
          curve: AppMotion.standard,
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: gradient,
            border: Border.all(
              color: border,
              width: state == _MedallionState.completed ? 2 : 1.2,
            ),
            boxShadow: shadows,
          ),
          alignment: Alignment.center,
          child: AnimatedSwitcher(
            duration: dur,
            switchInCurve: AppMotion.emphasized,
            switchOutCurve: AppMotion.exit,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.6, end: 1).animate(animation),
                child: child,
              ),
            ),
            child: Icon(
              icon,
              key: ValueKey(state),
              size: size * 0.5,
              color: iconColor,
            ),
          ),
        ),
      ),
    );

    final String? label = !showLabel
        ? null
        : switch (state) {
            _MedallionState.playing => null,
            _MedallionState.paused => pausedLabel,
            _MedallionState.completed => completedLabel,
          };

    // The label hangs below the disc without moving it, so the disc stays
    // optically centered on the stage in every state.
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            disc,
            Positioned(
              top: size + AppSpacing.md,
              left: -size,
              right: -size,
              child: Center(
                child: AnimatedSwitcher(
                  duration: dur,
                  switchInCurve: AppMotion.standard,
                  switchOutCurve: AppMotion.exit,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, -0.25),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: label == null
                      ? const SizedBox.shrink(key: ValueKey('none'))
                      : TagChip(
                          key: ValueKey(label),
                          label: label,
                          icon: state == _MedallionState.completed
                              ? Icons.check_circle_rounded
                              : Icons.pause_rounded,
                          tone: state == _MedallionState.completed
                              ? TagTone.gold
                              : TagTone.glass,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Timeline ----------------------------------------------------------------

/// Thin gold progress track with a glowing fill and knob, plus `m:ss`
/// elapsed / total labels. The fill glides between the player's 250 ms ticks
/// (instant under reduce-motion).
class WatchTimeline extends StatelessWidget {
  const WatchTimeline({
    super.key,
    required this.progress,
    required this.elapsedSeconds,
    required this.totalSeconds,
  });

  /// Watched fraction, 0..1.
  final double progress;
  final num elapsedSeconds;
  final int totalSeconds;

  static const semanticLabel = 'Үзсэн хугацаа';

  /// What screen readers say after [semanticLabel]:
  /// `'3 сек, нийт 45 сек'`.
  static String spokenValue(num elapsedSeconds, int totalSeconds) =>
      '${spokenDuration(elapsedSeconds)}, нийт ${spokenDuration(totalSeconds)}';

  @override
  Widget build(BuildContext context) {
    final p = progress.isFinite ? progress.clamp(0.0, 1.0) : 0.0;
    final elapsed = formatPlaybackTime(elapsedSeconds);
    final total = formatPlaybackTime(totalSeconds);
    final timeStyle = AppTextStyles.caption.copyWith(
      fontWeight: FontWeight.w600,
      fontFeatures: AppTextStyles.tabular,
    );

    return Semantics(
      label: semanticLabel,
      value: spokenValue(elapsedSeconds, totalSeconds),
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 14,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(end: p),
              duration: AppMotion.duration(
                context,
                const Duration(milliseconds: 260),
              ),
              builder: (context, value, _) => CustomPaint(
                painter: _TimelinePainter(progress: value),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Text(
                elapsed,
                style: timeStyle.copyWith(color: AppColors.textPrimary),
              ),
              const Spacer(),
              Text(total, style: timeStyle),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimelinePainter extends CustomPainter {
  _TimelinePainter({required this.progress});

  final double progress;

  static const double _track = 4;
  static const double _knob = 5;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0) return;
    final cy = size.height / 2;
    const radius = Radius.circular(_track / 2);

    canvas.drawRRect(
      RRect.fromLTRBR(
        0,
        cy - _track / 2,
        size.width,
        cy + _track / 2,
        radius,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.12),
    );

    final w = size.width * progress;
    if (w > 0) {
      final fill = RRect.fromLTRBR(
        0,
        cy - _track / 2,
        w,
        cy + _track / 2,
        radius,
      );
      canvas.drawRRect(
        fill,
        Paint()
          ..color = AppColors.primary.withValues(alpha: 0.55)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      canvas.drawRRect(
        fill,
        Paint()
          ..shader = const LinearGradient(
            colors: [
              AppColors.primaryDeep,
              AppColors.primary,
              AppColors.primaryLight,
            ],
          ).createShader(Rect.fromLTWH(0, 0, w, size.height)),
      );
    }

    // Knob, kept inside the track so it never clips at either end. A track
    // too narrow to hold it gets none (clamp bounds would cross).
    if (size.width < _knob * 2) return;
    final kx = w.clamp(_knob, size.width - _knob);
    final knob = Offset(kx, cy);
    canvas.drawCircle(
      knob,
      _knob + 3,
      Paint()
        ..color = AppColors.primary.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(knob, _knob, Paint()..color = AppColors.primaryLight);
  }

  @override
  bool shouldRepaint(_TimelinePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// --- Reward hint ---------------------------------------------------------------

/// `[coin] Бүтэн үзээд +700 ₮ аваарай`, switching to the survey nudge once
/// the video is fully watched.
///
/// On platforms without announcement support (Android) it is a polite live
/// region, so TalkBack reads the switch when the survey unlocks. Elsewhere
/// [WatchProgressButton] announces the unlock itself, so nothing is said
/// twice.
class RewardHintRow extends StatelessWidget {
  const RewardHintRow({
    super.key,
    required this.amount,
    required this.completed,
  });

  final num amount;
  final bool completed;

  static String lead(bool completed) =>
      completed ? 'Судалгаанд хариулаад ' : 'Бүтэн үзээд ';
  static const trail = ' аваарай';

  /// The full sentence, as shown and announced.
  static String text(num amount, bool completed) =>
      '${lead(completed)}${formatTugrik(amount, withSign: true)}$trail';

  @override
  Widget build(BuildContext context) {
    final dur = AppMotion.duration(context, AppDurations.normal);
    final announces = MediaQuery.maybeSupportsAnnounceOf(context) ?? false;
    return Semantics(
      container: true,
      liveRegion: !announces,
      label: text(amount, completed),
      excludeSemantics: true,
      child: AnimatedSwitcher(
        duration: dur,
        switchInCurve: AppMotion.standard,
        switchOutCurve: AppMotion.exit,
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.centerLeft,
          children: [...previous, if (current != null) current],
        ),
        child: Row(
          key: ValueKey(completed),
          children: [
            const CoinIcon(size: 20),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: lead(completed)),
                    TextSpan(
                      text: formatTugrik(amount, withSign: true),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontFeatures: AppTextStyles.tabular,
                      ),
                    ),
                    const TextSpan(text: trail),
                  ],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Watch progress button ---------------------------------------------------

/// The survey CTA doubling as a progress indicator for the full-watch gate.
///
/// Locked: muted surface slowly filling with gold in step with [progress],
/// a lock glyph and 'Видеог бүтэн үзнэ үү · 12 сек'. Taps are ignored and
/// it is announced as a disabled button.
///
/// Unlocked: morphs into the gold primary CTA ([label] + arrow). On the
/// locked -> unlocked transition it fires `HapticFeedback.mediumImpact`
/// once, tells screen readers ([unlockedAnnouncement]) where the platform
/// supports announcements, and pulses its glow with a light sweep three
/// times, then rests. Reduce motion: no morph animation, no pulse.
///
/// At least 54 high. Up to [wrapTextScale] OS text scale the label stays on
/// one line (shrinking only if the width is too small); above it the label
/// wraps and the button grows instead, so large text is honored.
///
/// [onPressed] only fires while [unlocked]; a null [onPressed] keeps it
/// disabled either way.
class WatchProgressButton extends StatefulWidget {
  const WatchProgressButton({
    super.key,
    required this.progress,
    required this.remainingSeconds,
    required this.unlocked,
    required this.onPressed,
    this.label = 'Судалгаа руу үргэлжлүүлэх',
  });

  /// Watched fraction, 0..1 (drives the locked fill).
  final double progress;

  /// Seconds left before the gate opens (shown while locked).
  final int remainingSeconds;
  final bool unlocked;
  final VoidCallback? onPressed;
  final String label;

  static const lockedTitle = 'Видеог бүтэн үзнэ үү';
  static const unlockedAnnouncement =
      'Видео дууслаа. Судалгаа руу үргэлжлүүлэх боломжтой';

  /// The countdown suffix shown next to [lockedTitle]: `'12 сек'`, `'1:30'`.
  static String remainingLabel(int seconds) =>
      formatDurationShort(seconds < 0 ? 0 : seconds);

  static const double minHeight = 54;
  static const double wrapTextScale = 1.3;

  static const int pulseCount = 3;
  static const Duration pulsePeriod = Duration(milliseconds: 2000);

  @override
  State<WatchProgressButton> createState() => _WatchProgressButtonState();
}

class _WatchProgressButtonState extends State<WatchProgressButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: WatchProgressButton.pulsePeriod,
  );
  bool _pulseChecked = false;

  static const LinearGradient _lockedGradient = LinearGradient(
    colors: [AppColors.surfaceElevated, AppColors.surfaceElevated],
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Mounted already unlocked (e.g. zero-length video): pulse, no haptic.
    if (!_pulseChecked) {
      _pulseChecked = true;
      if (widget.unlocked) _startPulse();
    }
  }

  @override
  void didUpdateWidget(covariant WatchProgressButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.unlocked && widget.unlocked) {
      HapticFeedback.mediumImpact();
      _announceUnlocked();
      _startPulse();
    } else if (oldWidget.unlocked && !widget.unlocked) {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  void _announceUnlocked() {
    // Android has deprecated announcements; there RewardHintRow's live
    // region carries the news instead.
    if (!(MediaQuery.maybeSupportsAnnounceOf(context) ?? false)) return;
    final view = View.maybeOf(context);
    if (view == null) return;
    SemanticsService.sendAnnouncement(
      view,
      WatchProgressButton.unlockedAnnouncement,
      Directionality.maybeOf(context) ?? TextDirection.ltr,
    );
  }

  void _startPulse() {
    if (AppMotion.reduced(context)) return;
    _pulse.repeat(count: WatchProgressButton.pulseCount);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Widget _content({required bool unlocked, required bool wrap}) {
    final remaining = WatchProgressButton.remainingLabel(
      widget.remainingSeconds,
    );
    final buttonStyle = AppTextStyles.button.copyWith(
      color: AppColors.onPrimary,
    );
    final titleStyle = AppTextStyles.label.copyWith(
      color: AppColors.textPrimary,
    );
    final countdownStyle = AppTextStyles.label.copyWith(
      color: AppColors.primary,
      fontFeatures: AppTextStyles.tabular,
    );
    const arrow = Icon(
      Icons.arrow_forward_rounded,
      size: 20,
      color: AppColors.onPrimary,
    );
    const lock = Icon(Icons.lock_rounded, size: 18, color: AppColors.primary);

    if (unlocked) {
      if (wrap) {
        return Row(
          key: const ValueKey('unlocked'),
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                widget.label,
                textAlign: TextAlign.center,
                style: buttonStyle,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            arrow,
          ],
        );
      }
      // One line that scales down (instead of ellipsizing) when a narrow
      // screen leaves too little room.
      return FittedBox(
        key: const ValueKey('unlocked'),
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.label, maxLines: 1, style: buttonStyle),
            const SizedBox(width: AppSpacing.sm),
            arrow,
          ],
        ),
      );
    }

    if (wrap) {
      // Large text: title on line 1, countdown on line 2.
      return Column(
        key: const ValueKey('locked'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              lock,
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  WatchProgressButton.lockedTitle,
                  textAlign: TextAlign.center,
                  style: titleStyle,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(remaining, textAlign: TextAlign.center, style: countdownStyle),
        ],
      );
    }
    return FittedBox(
      key: const ValueKey('locked'),
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          lock,
          const SizedBox(width: AppSpacing.sm),
          Text(
            WatchProgressButton.lockedTitle,
            maxLines: 1,
            style: titleStyle,
          ),
          Text(' · $remaining', maxLines: 1, style: countdownStyle),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unlocked = widget.unlocked;
    final enabled = unlocked && widget.onPressed != null;
    final dur = AppMotion.duration(context, AppDurations.medium);
    final remaining = WatchProgressButton.remainingLabel(
      widget.remainingSeconds,
    );
    final progress = unlocked
        ? 1.0
        : (widget.progress.isFinite ? widget.progress.clamp(0.0, 1.0) : 0.0);
    final fontSize = AppTextStyles.button.fontSize!;
    final textScale =
        (MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling)
                .scale(fontSize) /
            fontSize;
    final wrap = textScale > WatchProgressButton.wrapTextScale;

    final inner = Stack(
      alignment: Alignment.center,
      children: [
        // Locked: gold "charging" fill proportional to the watched fraction,
        // brightening softly toward its leading edge.
        Positioned.fill(
          child: AnimatedOpacity(
            opacity: unlocked ? 0 : 1,
            duration: dur,
            child: LayoutBuilder(
              builder: (context, box) => TweenAnimationBuilder<double>(
                tween: Tween<double>(end: progress),
                duration: AppMotion.duration(
                  context,
                  const Duration(milliseconds: 260),
                ),
                builder: (context, value, _) {
                  final fillWidth = box.maxWidth * value;
                  return FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: value,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withValues(alpha: 0.06),
                            AppColors.primary.withValues(alpha: 0.24),
                            AppColors.primary.withValues(
                              alpha: chargeEdgeAlpha(fillWidth),
                            ),
                          ],
                          stops: [0, chargeEdgeStop(fillWidth), 1],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        // Unlocked: light sweep that rides along with the glow pulse.
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (context, _) {
              if (!unlocked || !_pulse.isAnimating) {
                return const SizedBox.shrink();
              }
              return IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: const Alignment(-1, -0.6),
                      end: const Alignment(1, 0.6),
                      colors: [
                        Colors.white.withValues(alpha: 0),
                        Colors.white.withValues(alpha: 0.32),
                        Colors.white.withValues(alpha: 0),
                      ],
                      stops: const [0.4, 0.5, 0.6],
                      transform: _SlideGradientTransform(_pulse.value),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        // Sizes the button: at least minHeight, taller when wrapped text
        // needs it.
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: wrap ? AppSpacing.md : AppSpacing.sm,
          ),
          child: AnimatedSwitcher(
            duration: dur,
            switchInCurve: AppMotion.standard,
            switchOutCurve: AppMotion.exit,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.92, end: 1).animate(animation),
                child: child,
              ),
            ),
            child: _content(unlocked: unlocked, wrap: wrap),
          ),
        ),
      ],
    );

    final button = TweenAnimationBuilder<double>(
      tween: Tween<double>(end: unlocked ? 1 : 0),
      duration: dur,
      curve: AppMotion.standard,
      child: ClipRRect(borderRadius: AppRadii.brMd, child: inner),
      builder: (context, t, child) => AnimatedBuilder(
        animation: _pulse,
        child: child,
        builder: (context, child) {
          final wave =
              _pulse.isAnimating ? math.sin(math.pi * _pulse.value).abs() : 0.0;
          return Transform.scale(
            scale: 1 + 0.014 * wave,
            child: Container(
              constraints: const BoxConstraints(
                minHeight: WatchProgressButton.minHeight,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient.lerp(
                  _lockedGradient,
                  AppGradients.gold,
                  t,
                ),
                borderRadius: AppRadii.brMd,
                border: Border.all(
                  color: Color.lerp(
                    AppColors.borderStrong,
                    Colors.white.withValues(alpha: 0.24),
                    t,
                  )!,
                ),
                boxShadow: t == 0
                    ? null
                    : AppShadows.glow(
                        AppColors.primary,
                        strength: t * (0.85 + 0.5 * wave),
                        blur: 22 + 12 * wave,
                      ),
              ),
              child: child,
            ),
          );
        },
      ),
    );

    return Pressable(
      onTap: enabled ? widget.onPressed : null,
      semanticLabel: unlocked
          ? widget.label
          : '${WatchProgressButton.lockedTitle}, $remaining үлдсэн',
      excludeSemantics: true,
      // Fills a bounded width; falls back to 320 where the width is
      // unbounded instead of throwing.
      child: FillWidth(fallbackWidth: 320, child: button),
    );
  }
}

/// Slides a gradient horizontally: t = 0 puts its middle one width to the
/// left of the box, t = 1 one width to the right.
class _SlideGradientTransform extends GradientTransform {
  const _SlideGradientTransform(this.t);

  final double t;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * (t * 2 - 1), 0, 0);
}
