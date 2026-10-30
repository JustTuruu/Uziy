import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../models/campaign.dart';
import '../../routes/app_router.dart';
import '../../widgets/ui.dart';
import 'video_playback.dart';
import 'video_widgets.dart';

class VideoPlayerScreen extends StatefulWidget {
  const VideoPlayerScreen({
    super.key,
    required this.campaignId,
    this.campaign,
    this.playbackFactory = playbackFor,
  });
  final String campaignId;

  /// Builds the player; tests pass a fake.
  final VideoPlaybackFactory playbackFactory;

  /// Passed via router `extra` from the feed. Null for deep links — we
  /// fall back to a mock lookup so the player can still render.
  final Campaign? campaign;

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

/// Full screen turns the phone sideways either way round.
const List<DeviceOrientation> kFullscreenOrientations = [
  DeviceOrientation.landscapeLeft,
  DeviceOrientation.landscapeRight,
];

/// Leaving full screen stands the phone upright again.
const List<DeviceOrientation> kUprightOrientations = [
  DeviceOrientation.portraitUp,
];

/// Copy for a video that cannot be loaded.
const String kVideoLoadError = 'Видеог ачаалж чадсангүй';
const String kVideoRetry = 'Дахин оролдох';

class _VideoPlayerScreenState extends State<VideoPlayerScreen>
    with WidgetsBindingObserver {
  late final Campaign _campaign;
  late VideoPlayback _playback;

  /// What the viewer asked for: a tap pauses or resumes. Leaving the app
  /// pauses too, and only a tap resumes.
  bool _paused = false;

  /// Latched: once the whole video has played, the gate stays open even if
  /// the player later reports otherwise (e.g. a rebuffer at the end).
  bool _watched = false;

  /// The furthest point actually played. Seeking is rewind-only: anything up
  /// to here, never beyond (see [allowedSeek]).
  Duration _furthest = Duration.zero;

  // While playing, the play/pause medallion fades away so it does not sit on
  // the sponsor's video; each tap brings it back for a moment.
  bool _controlsRevealed = true;
  Timer? _hideControls;

  /// The viewer asked for the full-screen sideways video. A phone that is
  /// simply turned sideways shows it too ([useImmersiveVideo]).
  bool _fullscreen = false;

  /// Whether the last frame was full screen, so the system bars are hidden
  /// or shown only when that changes.
  bool _immersiveShown = false;
  static const _hideAfterStart = Duration(milliseconds: 1500);
  static const _hideAfterTap = Duration(seconds: 2);

  // Keep the stage, top bar and panel (and everything stateful inside them)
  // alive when a rotation swaps the portrait Column for the landscape Row.
  // The player lives in this State, not inside _Stage, so rotation never
  // disposes it.
  final _topBarKey = GlobalKey();
  final _stageKey = GlobalKey();
  final _panelKey = GlobalKey();

  PlaybackState get _state => _playback.state;

  // The user cannot skip to the survey until the video finishes playing.
  // Spec: full-watch requirement guards the reward eligibility. Seeking only
  // goes back, so the furthest point grows only by actually playing.
  bool get _fullyWatched => _watched;

  /// The player is sitting at the end (a rewind starts it again).
  bool get _atEnd => _state.isCompleted;

  /// At the end the player may report a hair under the full length
  /// (32.9 s of 33); show the full length then.
  double get _elapsed => _atEnd
      ? _campaign.durationSeconds.toDouble()
      : math.min(_state.positionSeconds, _campaign.durationSeconds.toDouble());

  double get _furthestFraction => watchProgressFraction(
      _furthest.inMicroseconds / Duration.microsecondsPerSecond,
      _campaign.durationSeconds);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _campaign = widget.campaign ??
        Campaign.mockFeed().firstWhere(
          (c) => c.id.toString() == widget.campaignId,
          orElse: () => Campaign.mockFeed().first,
        );
    _openPlayer();
  }

  void _openPlayer() {
    _playback = widget.playbackFactory(_campaign)..addListener(_onPlayback);
    _start(_playback);
  }

  Future<void> _start(VideoPlayback playback) async {
    await playback.initialize();
    if (!mounted || playback != _playback || playback.state.hasError) return;
    if (!_paused) await playback.play();
    _scheduleHideControls(_hideAfterStart);
  }

  void _onPlayback() {
    if (!mounted) return;
    final s = _state;
    final reachedEnd =
        s.isCompleted || s.positionSeconds >= _campaign.durationSeconds;
    setState(() {
      if (reachedEnd) _watched = true;
      if (s.position > _furthest) _furthest = s.position;
    });
  }

  void _retry() {
    _playback
      ..removeListener(_onPlayback)
      ..dispose();
    setState(() {
      _paused = false;
      _controlsRevealed = true;
    });
    _openPlayer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed || _paused || _atEnd) return;
    _playback.pause();
    setState(() {
      _paused = true;
      _controlsRevealed = true;
    });
    _hideControls?.cancel();
  }

  void _scheduleHideControls(Duration after) {
    _hideControls?.cancel();
    _hideControls = Timer(after, () {
      if (!mounted || _paused || _atEnd) return;
      setState(() => _controlsRevealed = false);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hideControls?.cancel();
    // The rest of the app turns freely again, with its bars back.
    SystemChrome.setPreferredOrientations(const []);
    if (_immersiveShown) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    _playback
      ..removeListener(_onPlayback)
      ..dispose();
    super.dispose();
  }

  void _togglePause() {
    // Nothing left to pause once the video has ended, or before it loads.
    if (_atEnd || _state.hasError) return;
    HapticFeedback.selectionClick();
    setState(() {
      _paused = !_paused;
      _controlsRevealed = true;
    });
    if (_paused) {
      _playback.pause();
      _hideControls?.cancel();
    } else {
      _playback.play();
      _scheduleHideControls(_hideAfterTap);
    }
  }

  /// Goes back to [target] (clamped to what was watched) and keeps the
  /// viewer's play/pause choice; from the end it plays again.
  Future<void> _seekTo(Duration target) async {
    if (!_state.isReady || _state.hasError) return;
    await _playback.seekTo(allowedSeek(target, _furthest));
    if (!mounted) return;
    setState(() => _controlsRevealed = true);
    if (!_paused) {
      await _playback.play();
      _scheduleHideControls(_hideAfterTap);
    }
  }

  void _rewind() {
    HapticFeedback.selectionClick();
    _seekTo(_state.position - kRewindStep);
  }

  void _seekToFraction(double fraction) => _seekTo(Duration(
      microseconds: (fraction *
              _campaign.durationSeconds *
              Duration.microsecondsPerSecond)
          .round()));

  void _goToSurvey() => context.pushReplacement(
        '${Routes.survey}/${_campaign.id}',
        extra: _campaign,
      );

  /// Full screen turns the phone sideways; leaving it turns it upright and
  /// keeps it there (a phone still held sideways would otherwise go straight
  /// back to full screen). Closing the screen frees the rotation again.
  Future<void> _toggleFullscreen(bool immersive) async {
    HapticFeedback.selectionClick();
    final enter = !immersive;
    setState(() {
      _fullscreen = enter;
      _controlsRevealed = true;
    });
    await SystemChrome.setPreferredOrientations(
        enter ? kFullscreenOrientations : kUprightOrientations);
    if (!_paused) _scheduleHideControls(_hideAfterTap);
  }

  /// Hides the status and navigation bars while the video is full screen.
  void _syncSystemBars(bool immersive) {
    if (immersive == _immersiveShown) return;
    _immersiveShown = immersive;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SystemChrome.setEnabledSystemUIMode(
          immersive ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge);
    });
  }

  @override
  Widget build(BuildContext context) {
    final duration = _campaign.durationSeconds;
    final watched = _fullyWatched;
    final progress = watchProgressFraction(_elapsed, duration);
    final remaining = remainingWatchSeconds(_elapsed, duration);

    // Landscape (rotated phones, split screen, tablets): stage on the left,
    // the info panel as a side sheet on the right.
    final screen = MediaQuery.sizeOf(context);
    final immersive = _fullscreen || useImmersiveVideo(screen);
    final side = useSidePanel(screen);
    _syncSystemBars(immersive);

    final topBar = FadeSlideIn(
      key: _topBarKey,
      offset: -12,
      child: _TopBar(campaign: _campaign, onClose: () => context.pop()),
    );
    final playback = _state;
    final atEnd = _atEnd;
    final canSeek = playback.isReady && !playback.hasError;
    final stage = _Stage(
      key: _stageKey,
      campaign: _campaign,
      video: _playback.buildView(),
      aspect: playback.aspectRatio,
      loading: !atEnd &&
          !playback.hasError &&
          !_paused &&
          (!playback.isReady || playback.isBuffering),
      failed: playback.hasError,
      onRetry: _retry,
      paused: _paused,
      completed: atEnd,
      showControls: _controlsRevealed || _paused || atEnd,
      onToggle: _togglePause,
      onRewind: canSeek && _furthest > Duration.zero ? _rewind : null,
      immersive: immersive,
      onFullscreen: () => _toggleFullscreen(immersive),
    );
    final panel = _BottomPanel(
      key: _panelKey,
      campaign: _campaign,
      elapsed: _elapsed,
      progress: progress,
      furthest: _furthestFraction,
      onSeek: canSeek ? _seekToFraction : null,
      remaining: remaining,
      watched: watched,
      side: side,
      onContinue: watched ? _goToSurvey : null,
    );

    if (immersive) {
      final controlsShown = _controlsRevealed || _paused || atEnd;
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        // Dark controls over the video in either app theme.
        child: Theme(
          data: AppTheme.dark(),
          child: Scaffold(
            backgroundColor: Colors.black,
            body: Stack(
              fit: StackFit.expand,
              children: [
                stage,
                _ImmersiveControls(
                  shown: controlsShown,
                  title: _campaign.title,
                  timeline: WatchTimeline(
                    progress: progress,
                    elapsedSeconds: _elapsed,
                    totalSeconds: duration,
                    furthestProgress: _furthestFraction,
                    onSeek: canSeek ? _seekToFraction : null,
                  ),
                  onRewind: canSeek && _furthest > Duration.zero
                      ? _rewind
                      : null,
                  onExit: () => _toggleFullscreen(immersive),
                  onContinue: watched ? _goToSurvey : null,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: context.colors.backgroundDeep,
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
              context.colors.backgroundDeep.withValues(alpha: 0),
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
                            style: context.textStyles.titleSmall.copyWith(
                              color: Colors.white,
                            ),
                          ),
                          if (details)
                            Text(
                              'Ивээн тэтгэгч',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.textStyles.caption.copyWith(
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  RewardChip(amount: campaign.rewardPerUser),
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
    required this.video,
    required this.aspect,
    required this.loading,
    required this.failed,
    required this.onRetry,
    required this.paused,
    required this.completed,
    required this.showControls,
    required this.onToggle,
    this.onRewind,
    this.immersive = false,
    this.onFullscreen,
  });

  final Campaign campaign;

  /// Jumps back; null hides the button (nothing watched yet, or no player).
  final VoidCallback? onRewind;

  /// Full screen: the video fills the screen edge to edge, without the frame,
  /// and its buttons live in [_ImmersiveControls] instead.
  final bool immersive;
  final VoidCallback? onFullscreen;

  /// The player's picture; null until there is one (the art shows instead).
  final Widget? video;

  /// The video's own width / height, so a vertical ad fills a tall stage.
  final double aspect;

  /// Loading or rebuffering: a spinner replaces the medallion.
  final bool loading;

  /// The video could not be loaded: a message and a retry replace it.
  final bool failed;
  final VoidCallback onRetry;
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
    final VoidCallback? onTap = completed || failed ? null : onToggle;

    return Semantics(
      container: true,
      button: !completed,
      label: semantics,
      onTap: onTap,
      // The picture and the medallion are described by this node; only the
      // real buttons on the stage (rewind, retry) keep their own nodes.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: onTap,
        child: Padding(
          padding: immersive
              ? EdgeInsets.zero
              : const EdgeInsets.symmetric(
                  horizontal: AppLayout.screenPadding,
                  vertical: AppSpacing.md,
                ),
          child: LayoutBuilder(
            builder: (context, box) {
              final frame = stageFrameSize(
                box.biggest,
                aspect: aspect,
                maxWidth: immersive ? double.infinity : kStageMaxWidth,
              );
              final radius = immersive ? BorderRadius.zero : AppRadii.brLg;
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
                      borderRadius: radius,
                      boxShadow: immersive
                          ? null
                          : [
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
                      borderRadius: radius,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // The art is the poster until the first frame.
                          ExcludeSemantics(
                            child: CampaignArt(
                              campaignId: campaign.id,
                              companyName: campaign.companyName,
                              thumbnailUrl: campaign.thumbnailUrl,
                              hasVideo: campaign.hasVideo,
                            ),
                          ),
                          if (video != null) ExcludeSemantics(child: video!),
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
                          if (!immersive)
                            DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: radius,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.1),
                                ),
                              ),
                            ),
                          if (failed)
                            _LoadFailed(onRetry: onRetry)
                          else if (loading)
                            const ExcludeSemantics(
                              child: Center(
                                child: CircularProgressIndicator(
                                  key: ValueKey('video-loading'),
                                  color: Colors.white,
                                ),
                              ),
                            )
                          else
                            ExcludeSemantics(
                              child: Center(
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
                            ),
                          if (!immersive && onRewind != null && !failed)
                            Positioned(
                              left: AppSpacing.sm,
                              bottom: AppSpacing.sm,
                              child: _FadingControl(
                                shown: showControls,
                                child: RewindButton(onPressed: onRewind),
                              ),
                            ),
                          if (!immersive && onFullscreen != null && !failed)
                            Positioned(
                              right: AppSpacing.sm,
                              bottom: AppSpacing.sm,
                              child: _FadingControl(
                                shown: showControls,
                                child: FullscreenButton(
                                  active: false,
                                  onPressed: onFullscreen,
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

/// A control over the video that fades out with the medallion and cannot be
/// tapped while hidden.
class _FadingControl extends StatelessWidget {
  const _FadingControl({required this.shown, required this.child});

  final bool shown;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !shown,
      child: AnimatedOpacity(
        opacity: shown ? 1 : 0,
        duration: AppMotion.duration(context, AppDurations.medium),
        curve: AppMotion.standard,
        child: child,
      ),
    );
  }
}

/// Over the full-screen video: leave full screen and the title at the top;
/// rewind, the timeline and (once watched) the way to the survey at the
/// bottom. Fades with the medallion; the survey button stays once it is open,
/// so the viewer never has to hunt for it.
class _ImmersiveControls extends StatelessWidget {
  const _ImmersiveControls({
    required this.shown,
    required this.title,
    required this.timeline,
    required this.onRewind,
    required this.onExit,
    required this.onContinue,
  });

  final bool shown;
  final String title;
  final Widget timeline;
  final VoidCallback? onRewind;
  final VoidCallback onExit;
  final VoidCallback? onContinue;

  static const continueLabel = 'Судалгаа руу';

  /// The button keeps its label and arrow centred, so it needs a set width.
  static const double continueWidth = 200;

  @override
  Widget build(BuildContext context) {
    final shade = Colors.black.withValues(alpha: 0.55);
    final cont = onContinue;
    return SafeArea(
      minimum: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FadingControl(
            shown: shown,
            child: Row(
              children: [
                FullscreenButton(active: true, onPressed: onExit),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textStyles.titleSmall
                        .copyWith(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: _FadingControl(
                  shown: shown,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: shade,
                      borderRadius: AppRadii.brLg,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      child: Row(
                        children: [
                          if (onRewind != null) ...[
                            RewindButton(onPressed: onRewind),
                            const SizedBox(width: AppSpacing.md),
                          ],
                          Expanded(child: timeline),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (cont != null) ...[
                const SizedBox(width: AppSpacing.md),
                SizedBox(
                  width: continueWidth,
                  child: AppButton(
                    label: continueLabel,
                    onPressed: cont,
                    trailingIcon: AppIcons.next,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Shown on the stage when the video cannot be loaded (no network, a broken
/// file). Overlays fixed dark art, so white ink.
class _LoadFailed extends StatelessWidget {
  const _LoadFailed({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.55),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                kVideoLoadError,
                textAlign: TextAlign.center,
                style: context.textStyles.label.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.md),
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                child: const Text(kVideoRetry),
              ),
            ],
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
    required this.furthest,
    required this.onSeek,
    required this.remaining,
    required this.watched,
    required this.onContinue,
    this.side = false,
  });

  final Campaign campaign;
  final double elapsed;
  final double progress;

  /// Already-watched fraction; the timeline can go back anywhere inside it.
  final double furthest;
  final ValueChanged<double>? onSeek;
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
            style: context.textStyles.title,
          ),
        ),
        SizedBox(height: compact ? AppSpacing.lg : AppSpacing.xl),
        FadeSlideIn(
          index: 1,
          child: WatchTimeline(
            progress: progress,
            elapsedSeconds: elapsed,
            totalSeconds: campaign.durationSeconds,
            furthestProgress: furthest,
            onSeek: onSeek,
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
        color: context.colors.surface.withValues(alpha: 0.94),
        borderRadius: radius,
        border: Border.all(color: context.colors.border),
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
                    progress: watched ? 1 : progress,
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
