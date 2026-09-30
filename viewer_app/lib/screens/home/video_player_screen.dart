import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../models/campaign.dart';
import '../../routes/app_router.dart';
import '../../widgets/ui.dart';
import 'video_widgets.dart';

class VideoPlayerScreen extends StatefulWidget {
  const VideoPlayerScreen({
    super.key,
    required this.campaignId,
    this.campaign,
  });
  final String campaignId;

  /// Passed via router `extra` from the feed. Null for deep links — we
  /// fall back to a mock lookup so the player can still render.
  final Campaign? campaign;

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late final Campaign _campaign;
  Timer? _ticker;
  double _elapsed = 0; // seconds
  bool _paused = false;

  // While playing, the play/pause medallion fades away so it does not sit on
  // the sponsor's video; each tap brings it back for a moment.
  bool _controlsRevealed = true;
  Timer? _hideControls;
  static const _hideAfterStart = Duration(milliseconds: 1500);
  static const _hideAfterTap = Duration(seconds: 2);

  // Keep the stage, top bar and panel (and everything stateful inside them)
  // alive when a rotation swaps the portrait Column for the landscape Row.
  // When the real player lands, keep its VideoPlayerController in this State
  // too, not inside _Stage, so rotation never disposes it.
  final _topBarKey = GlobalKey();
  final _stageKey = GlobalKey();
  final _panelKey = GlobalKey();

  // The user cannot skip to the survey until the video finishes playing.
  // Spec: full-watch requirement guards the reward eligibility.
  bool get _fullyWatched => _elapsed >= _campaign.durationSeconds;

  @override
  void initState() {
    super.initState();
    _campaign = widget.campaign ??
        Campaign.mockFeed().firstWhere(
          (c) => c.id.toString() == widget.campaignId,
          orElse: () => Campaign.mockFeed().first,
        );
    _startTicker();
    _scheduleHideControls(_hideAfterStart);
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (_paused || !mounted) return;
      setState(() {
        _elapsed += 0.25;
        if (_elapsed >= _campaign.durationSeconds) {
          _elapsed = _campaign.durationSeconds.toDouble();
          _ticker?.cancel();
        }
      });
    });
  }

  void _scheduleHideControls(Duration after) {
    _hideControls?.cancel();
    _hideControls = Timer(after, () {
      if (!mounted || _paused || _fullyWatched) return;
      setState(() => _controlsRevealed = false);
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _hideControls?.cancel();
    super.dispose();
  }

  void _togglePause() {
    // Nothing left to pause once the video has ended.
    if (_fullyWatched) return;
    HapticFeedback.selectionClick();
    setState(() {
      _paused = !_paused;
      _controlsRevealed = true;
    });
    if (_paused) {
      _hideControls?.cancel();
    } else {
      _scheduleHideControls(_hideAfterTap);
    }
  }

  void _goToSurvey() => context.pushReplacement(
        '${Routes.survey}/${_campaign.id}',
        extra: _campaign,
      );

  @override
  Widget build(BuildContext context) {
    final duration = _campaign.durationSeconds;
    final watched = _fullyWatched;
    final progress = watchProgressFraction(_elapsed, duration);
    final remaining = remainingWatchSeconds(_elapsed, duration);

    // Landscape (rotated phones, split screen, tablets): stage on the left,
    // the info panel as a side sheet on the right.
    final screen = MediaQuery.sizeOf(context);
    final side = useSidePanel(screen);

    final topBar = FadeSlideIn(
      key: _topBarKey,
      offset: -12,
      child: _TopBar(campaign: _campaign, onClose: () => context.pop()),
    );
    final stage = _Stage(
      key: _stageKey,
      campaign: _campaign,
      paused: _paused,
      completed: watched,
      showControls: _controlsRevealed || _paused || watched,
      onToggle: _togglePause,
    );
    final panel = _BottomPanel(
      key: _panelKey,
      campaign: _campaign,
      elapsed: _elapsed,
      progress: progress,
      remaining: remaining,
      watched: watched,
      side: side,
      onContinue: watched ? _goToSurvey : null,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.backgroundDeep,
        body: Stack(
          fit: StackFit.expand,
          children: [
            _Backdrop(campaign: _campaign),
            if (side)
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: SafeArea(
                      right: false,
                      child: Column(
                        children: [topBar, Expanded(child: stage)],
                      ),
                    ),
                  ),
                  SizedBox(
                    width: sidePanelWidth(screen.width),
                    child: panel,
                  ),
                ],
              )
            else
              Column(
                children: [
                  SafeArea(bottom: false, child: topBar),
                  Expanded(child: stage),
                  panel,
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Full-bleed brand-tinted glow behind the stage: the campaign palette
/// fading into the deep background. Plain gradients only, so it costs next
/// to nothing while the player ticks.
class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.campaign});

  final Campaign campaign;

  @override
  Widget build(BuildContext context) {
    final palette = campaignPalette(campaign.id);
    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.6),
            radius: 1.2,
            colors: [
              palette[0].withValues(alpha: 0.35),
              palette[2].withValues(alpha: 0.12),
              AppColors.backgroundDeep.withValues(alpha: 0),
            ],
            stops: const [0, 0.45, 1],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.campaign, required this.onClose});

  final Campaign campaign;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppLayout.screenPadding,
        vertical: AppSpacing.sm,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kStageMaxWidth),
          child: LayoutBuilder(
            builder: (context, box) {
              // Narrow bars (under ~360 pt screens, landscape stage column)
              // keep only the company name so it is not cut to 'Мо…'.
              final details = showSponsorDetails(box.maxWidth);
              return Row(
                children: [
                  StageCloseButton(onPressed: onClose),
                  const SizedBox(width: AppSpacing.md),
                  if (details) ...[
                    SponsorAvatar(
                      campaignId: campaign.id,
                      companyName: campaign.companyName,
                    ),
                    const SizedBox(width: AppSpacing.md),
                  ],
                  Expanded(
                    child: MergeSemantics(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            campaign.companyName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.titleSmall.copyWith(
                              color: Colors.white,
                            ),
                          ),
                          if (details)
                            Text(
                              'Ивээн тэтгэгч',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.caption.copyWith(
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  RewardChip(amount: campaign.rewardPerUser, glow: true),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The "screen" area: a crisp frame (16:9 until the real player reports the
/// video's own aspect ratio, see [stageFrameSize]) floating over the
/// backdrop, with the play/pause medallion on top.
///
/// Until the video ends the whole stage is the tap-to-pause target. After
/// that it is inert (no tap, not announced as a button).
class _Stage extends StatelessWidget {
  const _Stage({
    super.key,
    required this.campaign,
    required this.paused,
    required this.completed,
    required this.showControls,
    required this.onToggle,
  });

  final Campaign campaign;
  final bool paused;
  final bool completed;

  /// Whether the medallion is shown. The screen hides it a moment after
  /// playback starts or resumes; it always shows while paused or finished.
  final bool showControls;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final glowColor = campaignPalette(campaign.id).first;
    final dur = AppMotion.duration(context, AppDurations.normal);
    final String semantics = completed
        ? 'Видео дууссан'
        : paused
            ? 'Үргэлжлүүлэх'
            : 'Түр зогсоох';
    final VoidCallback? onTap = completed ? null : onToggle;

    return Semantics(
      container: true,
      button: !completed,
      label: semantics,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppLayout.screenPadding,
            vertical: AppSpacing.md,
          ),
          child: LayoutBuilder(
            builder: (context, box) {
              // With the real player (see the TODO below), pass its
              // value.aspectRatio as `aspect` so vertical ads fill the stage.
              final frame = stageFrameSize(box.biggest);
              if (frame.isEmpty) return const SizedBox.shrink();
              final medallion =
                  (frame.shortestSide * 0.42).clamp(40.0, 84.0).toDouble();
              // Room for the label that hangs below the disc?
              final showLabel = frame.height >= medallion * 2 + 24;
              final nudge = showLabel && (paused || completed);
              return Center(
                child: SizedBox.fromSize(
                  size: frame,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: AppRadii.brLg,
                      boxShadow: [
                        ...AppShadows.glow(
                          glowColor,
                          strength: 0.7,
                          blur: 40,
                          offset: const Offset(0, 12),
                        ),
                        ...AppShadows.floating,
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: AppRadii.brLg,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // TODO: replace placeholder with actual
                          // video_player / chewie playback of
                          // campaign.videoUrl (HLS .m3u8), and drive
                          // _elapsed from the player's position stream
                          // instead of the placeholder ticker.
                          CampaignArt(
                            campaignId: campaign.id,
                            companyName: campaign.companyName,
                            thumbnailUrl: campaign.thumbnailUrl,
                            hasVideo: campaign.hasVideo,
                          ),
                          // Dims the frame only while paused / finished so
                          // the medallion reads as the focus. Playback is
                          // left untouched.
                          AnimatedOpacity(
                            opacity: paused || completed ? 1 : 0,
                            duration: dur,
                            curve: AppMotion.standard,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.38),
                              ),
                            ),
                          ),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: AppRadii.brLg,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                          ),
                          Center(
                            child: AnimatedOpacity(
                              key: const ValueKey('video-controls'),
                              opacity: showControls ? 1 : 0,
                              duration: AppMotion.duration(
                                context,
                                AppDurations.medium,
                              ),
                              curve: AppMotion.standard,
                              child: AnimatedSlide(
                                // Nudged up while a label hangs below the
                                // disc, so disc + label sit centered as a
                                // group.
                                offset: Offset(0, nudge ? -0.2 : 0),
                                duration: dur,
                                curve: AppMotion.standard,
                                child: PlayPauseMedallion(
                                  paused: paused,
                                  completed: completed,
                                  size: medallion,
                                  showLabel: showLabel,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Info panel: title, timeline, reward hint and the full-watch gated CTA.
///
/// Portrait: a bottom sheet capped at 60% of the screen height. Landscape
/// ([side]): a full-height side sheet on the right. The info scrolls when
/// large text needs it; the CTA is pinned below it so it is always on
/// screen. Both layouts share one widget structure, so rotating keeps the
/// entrance animations and the CTA state instead of rebuilding them.
class _BottomPanel extends StatelessWidget {
  const _BottomPanel({
    super.key,
    required this.campaign,
    required this.elapsed,
    required this.progress,
    required this.remaining,
    required this.watched,
    required this.onContinue,
    this.side = false,
  });

  final Campaign campaign;
  final double elapsed;
  final double progress;
  final int remaining;
  final bool watched;
  final VoidCallback? onContinue;
  final bool side;

  static const BorderRadius _sideRadius =
      BorderRadius.horizontal(left: Radius.circular(AppRadii.xl));

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.paddingOf(context);
    final screen = MediaQuery.sizeOf(context);
    final radius = side ? _sideRadius : AppRadii.sheetTop;
    final compact = useCompactPanel(screen);
    final gap = compact ? AppSpacing.md : AppSpacing.lg;

    final padding = side
        ? EdgeInsets.fromLTRB(
            AppSpacing.xxl,
            AppSpacing.xl + insets.top,
            AppLayout.screenPadding + insets.right,
            AppSpacing.xl + insets.bottom,
          )
        : EdgeInsets.fromLTRB(
            AppLayout.screenPadding,
            compact ? AppSpacing.xl : AppSpacing.xxl,
            AppLayout.screenPadding,
            gap + insets.bottom,
          );

    final info = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FadeSlideIn(
          child: Text(
            campaign.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.title,
          ),
        ),
        SizedBox(height: compact ? AppSpacing.lg : AppSpacing.xl),
        FadeSlideIn(
          index: 1,
          child: WatchTimeline(
            progress: progress,
            elapsedSeconds: elapsed,
            totalSeconds: campaign.durationSeconds,
          ),
        ),
        SizedBox(height: gap),
        FadeSlideIn(
          index: 2,
          child: RewardHintRow(
            amount: campaign.rewardPerUser,
            completed: watched,
          ),
        ),
      ],
    );

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        maxHeight: side ? double.infinity : screen.height * 0.6,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.94),
        borderRadius: radius,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.floating,
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: radius,
        gradient: AppGradients.sheen,
      ),
      child: Padding(
        padding: padding,
        child: Align(
          // Side sheet: content centered in the full height. Bottom sheet:
          // hug the content.
          alignment: side ? Alignment.center : Alignment.topCenter,
          heightFactor: side ? null : 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kStageMaxWidth),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Flexible(
                  child: SingleChildScrollView(
                    primary: false,
                    physics: const ClampingScrollPhysics(),
                    child: info,
                  ),
                ),
                SizedBox(height: gap),
                FadeSlideIn(
                  index: 3,
                  child: WatchProgressButton(
                    progress: progress,
                    remainingSeconds: remaining,
                    unlocked: watched,
                    onPressed: onContinue,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
