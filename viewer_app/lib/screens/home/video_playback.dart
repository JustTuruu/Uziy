import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart';

import '../../models/campaign.dart';
import 'video_widgets.dart' show kDefaultVideoAspect;

/// One read of a player, all the video screen needs to draw itself and to
/// decide whether the full-watch gate is open.
@immutable
class PlaybackState {
  const PlaybackState({
    this.position = Duration.zero,
    this.isReady = false,
    this.isPlaying = false,
    this.isBuffering = false,
    this.isCompleted = false,
    this.hasError = false,
    this.aspectRatio = kDefaultVideoAspect,
  });

  final Duration position;
  final bool isReady;
  final bool isPlaying;
  final bool isBuffering;
  final bool isCompleted;
  final bool hasError;
  final double aspectRatio;

  double get positionSeconds =>
      position.inMicroseconds / Duration.microsecondsPerSecond;
}

/// How far the rewind button jumps back.
const Duration kRewindStep = Duration(seconds: 10);

/// Rewind only (owner, 2026-10-22): a viewer may go back to anything already
/// played, never past the [furthest] point they have actually watched, so the
/// full-watch gate cannot be skipped.
Duration allowedSeek(Duration target, Duration furthest) {
  if (target <= Duration.zero) return Duration.zero;
  return target > furthest ? furthest : target;
}

/// Pattern: Adapter + Strategy — the video screen drives any player through
/// this one small surface: the real network player ([NetworkVideoPlayback])
/// or the stand-in clock for campaigns that have no file yet
/// ([TimedPlayback]). Tests drive the screen with a fake.
abstract class VideoPlayback implements Listenable {
  PlaybackState get state;

  /// Loads the media; never throws — a failure shows up as [PlaybackState.hasError].
  Future<void> initialize();

  Future<void> play();

  Future<void> pause();

  /// Moves to [position]; the screen only ever asks for an [allowedSeek].
  Future<void> seekTo(Duration position);

  /// The picture to draw, or null when there is none (the screen then shows
  /// the campaign art).
  Widget? buildView();

  void dispose();
}

/// Builds the player for a campaign. Injectable so tests never touch the
/// platform video plugin.
typedef VideoPlaybackFactory = VideoPlayback Function(Campaign campaign);

/// A campaign with a file plays it; one without (older dev seeds) falls back
/// to the clock so the screen and the gate still work.
VideoPlayback playbackFor(Campaign campaign) {
  final url = Uri.tryParse(campaign.videoUrl.trim());
  if (url == null || !url.hasScheme || url.host.isEmpty) {
    return TimedPlayback(Duration(seconds: campaign.durationSeconds));
  }
  return NetworkVideoPlayback(url);
}

/// The real player: a progressive MP4 or an HLS `.m3u8` from the CDN.
class NetworkVideoPlayback implements VideoPlayback {
  NetworkVideoPlayback(Uri url)
      : _controller = VideoPlayerController.networkUrl(url);

  final VideoPlayerController _controller;

  @override
  PlaybackState get state {
    final v = _controller.value;
    return PlaybackState(
      position: v.position,
      isReady: v.isInitialized,
      isPlaying: v.isPlaying,
      isBuffering: v.isBuffering,
      isCompleted: v.isCompleted,
      hasError: v.hasError,
      aspectRatio: v.isInitialized ? v.aspectRatio : kDefaultVideoAspect,
    );
  }

  @override
  Future<void> initialize() async {
    try {
      await _controller.initialize();
    } catch (_) {
      // The controller records the error in its value; the screen reads it.
    }
  }

  @override
  Future<void> play() => _controller.play();

  @override
  Future<void> pause() => _controller.pause();

  @override
  Future<void> seekTo(Duration position) => _controller.seekTo(position);

  @override
  Widget? buildView() => VideoPlayer(_controller);

  @override
  void addListener(VoidCallback listener) => _controller.addListener(listener);

  @override
  void removeListener(VoidCallback listener) =>
      _controller.removeListener(listener);

  @override
  void dispose() => _controller.dispose();
}

/// A clock standing in for a video that has no file: it "plays" for
/// [duration], ticking every [tick].
class TimedPlayback extends ChangeNotifier implements VideoPlayback {
  TimedPlayback(this.duration, {this.tick = const Duration(milliseconds: 250)});

  final Duration duration;
  final Duration tick;
  Timer? _timer;
  PlaybackState _state = const PlaybackState();

  @override
  PlaybackState get state => _state;

  @override
  Future<void> initialize() async {
    _set(PlaybackState(isReady: true, isCompleted: duration <= Duration.zero));
  }

  @override
  Future<void> play() async {
    if (_state.isCompleted || _timer != null) return;
    _timer = Timer.periodic(tick, (_) => _advance());
    _set(_copy(isPlaying: true));
  }

  @override
  Future<void> pause() async {
    _stop();
    _set(_copy(isPlaying: false));
  }

  @override
  Future<void> seekTo(Duration position) async {
    final to = position < Duration.zero
        ? Duration.zero
        : (position > duration ? duration : position);
    _set(_copy(position: to, isCompleted: to >= duration));
  }

  void _advance() {
    final next = _state.position + tick;
    if (next >= duration) {
      _stop();
      _set(_copy(position: duration, isPlaying: false, isCompleted: true));
    } else {
      _set(_copy(position: next));
    }
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  PlaybackState _copy({
    Duration? position,
    bool? isPlaying,
    bool? isCompleted,
  }) =>
      PlaybackState(
        position: position ?? _state.position,
        isReady: _state.isReady,
        isPlaying: isPlaying ?? _state.isPlaying,
        isCompleted: isCompleted ?? _state.isCompleted,
      );

  void _set(PlaybackState next) {
    _state = next;
    notifyListeners();
  }

  @override
  Widget? buildView() => null;

  @override
  void dispose() {
    _stop();
    super.dispose();
  }
}
