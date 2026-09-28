import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/campaign.dart';
import '../../routes/app_router.dart';
import '../../theme/app_theme.dart';

class VideoPlayerScreen extends StatefulWidget {
  const VideoPlayerScreen({super.key, required this.campaignId});
  final String campaignId;

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late final Campaign _campaign;
  Timer? _ticker;
  double _elapsed = 0; // seconds
  bool _paused = false;

  // The user cannot skip to the survey until the video finishes playing.
  // Spec: full-watch requirement guards the reward eligibility.
  bool get _fullyWatched => _elapsed >= _campaign.durationSeconds;

  @override
  void initState() {
    super.initState();
    _campaign = Campaign.mockFeed().firstWhere(
      (c) => c.id.toString() == widget.campaignId,
      orElse: () => Campaign.mockFeed().first,
    );
    _startTicker();
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

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _campaign.durationSeconds == 0
        ? 0.0
        : (_elapsed / _campaign.durationSeconds).clamp(0.0, 1.0);
    final remaining =
        (_campaign.durationSeconds - _elapsed).clamp(0, double.infinity);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '+${_campaign.rewardPerUser.toInt()} ₮',
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _paused = !_paused),
                child: Container(
                  color: Colors.black,
                  alignment: Alignment.center,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // TODO: replace placeholder with actual video_player /
                      // chewie playback of _campaign.videoUrl (HLS .m3u8).
                      Container(
                        decoration: const BoxDecoration(
                          gradient: RadialGradient(
                            radius: 0.8,
                            colors: [
                              Color(0xFF2A2A38),
                              Colors.black,
                            ],
                          ),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _paused
                                ? Icons.play_circle_fill
                                : Icons.pause_circle_filled,
                            color: Colors.white.withOpacity(0.85),
                            size: 88,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            _campaign.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _campaign.companyName,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        _fullyWatched
                            ? 'Дууссан'
                            : '${remaining.toStringAsFixed(0)} сек үлдсэн',
                        style: TextStyle(
                          color: _fullyWatched
                              ? AppColors.success
                              : Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_elapsed.toStringAsFixed(0)} / ${_campaign.durationSeconds}s',
                        style: const TextStyle(color: Colors.white54),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: Colors.white12,
                      valueColor:
                          const AlwaysStoppedAnimation(AppColors.primary),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _fullyWatched
                        ? () => context.pushReplacement(
                              '${Routes.survey}/${_campaign.id}',
                            )
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _fullyWatched
                          ? AppColors.primary
                          : AppColors.surfaceElevated,
                      foregroundColor:
                          _fullyWatched ? Colors.black : Colors.white38,
                    ),
                    child: Text(
                      _fullyWatched
                          ? 'Судалгаа руу үргэлжлүүлэх'
                          : 'Видеог бүтэн үзнэ үү',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
