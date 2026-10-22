import 'package:flutter_test/flutter_test.dart';
import 'package:viewer_app/models/campaign.dart';
import 'package:viewer_app/screens/home/video_playback.dart';

Campaign _campaign(String url) => Campaign(
      id: 1,
      companyName: 'MobiCom',
      videoUrl: url,
      title: 't',
      durationSeconds: 3,
      rewardPerUser: 500,
    );

void main() {
  group('playbackFor', () {
    test('a campaign with a file gets the real network player', () {
      final p = playbackFor(
          _campaign('https://media.w3.org/2010/05/bunny/trailer.mp4'));
      expect(p, isA<NetworkVideoPlayback>());
      p.dispose();
    });

    test('a campaign without a usable file falls back to the clock', () {
      for (final url in ['', '  ', 'not a url', '/relative.mp4']) {
        final p = playbackFor(_campaign(url));
        expect(p, isA<TimedPlayback>(), reason: url);
        expect((p as TimedPlayback).duration, const Duration(seconds: 3));
        p.dispose();
      }
    });
  });

  // testWidgets runs on a fake clock, so tester.pump(d) moves time by d.
  group('TimedPlayback', () {
    testWidgets('plays to the end, then reports completed and stops',
        (tester) async {
      final p = TimedPlayback(const Duration(seconds: 1));
      var updates = 0;
      p.addListener(() => updates++);
      await p.initialize();
      expect(p.state.isReady, isTrue);

      await p.play();
      await tester.pump(const Duration(milliseconds: 500));
      expect(p.state.position, const Duration(milliseconds: 500));
      expect(p.state.isPlaying, isTrue);
      expect(p.state.isCompleted, isFalse);

      await tester.pump(const Duration(seconds: 2));
      expect(p.state.position, const Duration(seconds: 1));
      expect(p.state.isCompleted, isTrue);
      expect(p.state.isPlaying, isFalse);
      expect(updates, greaterThan(3));
      p.dispose();
    });

    testWidgets('pause holds the position until play again', (tester) async {
      final p = TimedPlayback(const Duration(seconds: 5));
      await p.initialize();
      await p.play();
      await tester.pump(const Duration(milliseconds: 750));
      await p.pause();
      await tester.pump(const Duration(seconds: 3));
      expect(p.state.position, const Duration(milliseconds: 750));
      expect(p.state.isPlaying, isFalse);
      await p.play();
      await tester.pump(const Duration(milliseconds: 250));
      expect(p.state.position, const Duration(seconds: 1));
      p.dispose();
    });

    test('a zero-length video is complete at once', () {
      final p = TimedPlayback(Duration.zero)..initialize();
      expect(p.state.isCompleted, isTrue);
      p.dispose();
    });
  });

  group('allowedSeek', () {
    const furthest = Duration(seconds: 20);

    test('going back is allowed as it is', () {
      expect(allowedSeek(const Duration(seconds: 5), furthest),
          const Duration(seconds: 5));
      expect(allowedSeek(furthest, furthest), furthest);
    });

    test('going past what was watched stops at the furthest point', () {
      expect(allowedSeek(const Duration(seconds: 30), furthest), furthest);
    });

    test('never below zero', () {
      expect(allowedSeek(const Duration(seconds: -4), furthest), Duration.zero);
    });
  });

  testWidgets('TimedPlayback rewound from the end plays again', (tester) async {
    final p = TimedPlayback(const Duration(seconds: 1));
    await p.initialize();
    await p.play();
    await tester.pump(const Duration(seconds: 2));
    expect(p.state.isCompleted, isTrue);

    await p.seekTo(const Duration(milliseconds: 250));
    expect(p.state.isCompleted, isFalse);
    expect(p.state.position, const Duration(milliseconds: 250));

    await p.play();
    await tester.pump(const Duration(milliseconds: 500));
    expect(p.state.position, const Duration(milliseconds: 750));
    p.dispose();
  });
}
