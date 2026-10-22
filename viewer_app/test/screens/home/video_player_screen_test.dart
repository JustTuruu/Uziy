import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewer_app/models/campaign.dart';
import 'package:viewer_app/screens/home/video_playback.dart';
import 'package:viewer_app/screens/home/video_player_screen.dart';
import 'package:viewer_app/screens/home/video_widgets.dart';
import 'package:viewer_app/widgets/ui.dart';

const _campaign = Campaign(
  id: 29,
  companyName: 'MobiCom',
  videoUrl: 'https://media.w3.org/2010/05/bunny/trailer.mp4',
  title: 'Анхны сэтгэгдэл',
  durationSeconds: 33,
  rewardPerUser: 500,
);

/// A player the test moves by hand.
class FakePlayback extends ChangeNotifier implements VideoPlayback {
  FakePlayback({this.failToLoad = false});

  final bool failToLoad;
  PlaybackState _state = const PlaybackState();
  int plays = 0;
  int pauses = 0;
  final List<Duration> seeks = [];
  bool disposed = false;

  @override
  PlaybackState get state => _state;

  void emit(PlaybackState next) {
    _state = next;
    notifyListeners();
  }

  void at(int seconds, {bool completed = false, bool buffering = false}) =>
      emit(PlaybackState(
        position: Duration(seconds: seconds),
        isReady: true,
        isPlaying: !completed,
        isBuffering: buffering,
        isCompleted: completed,
        aspectRatio: 9 / 16,
      ));

  @override
  Future<void> initialize() async =>
      emit(PlaybackState(isReady: !failToLoad, hasError: failToLoad));

  @override
  Future<void> play() async => plays++;

  @override
  Future<void> pause() async => pauses++;

  @override
  Future<void> seekTo(Duration position) async {
    seeks.add(position);
    emit(PlaybackState(
      position: position,
      isReady: true,
      isPlaying: _state.isPlaying,
      aspectRatio: _state.aspectRatio,
    ));
  }

  @override
  Widget? buildView() =>
      const ColoredBox(key: ValueKey('fake-video'), color: Color(0xFF000000));

  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}

void main() {
  late List<FakePlayback> made;

  Future<FakePlayback> pump(WidgetTester tester,
      {bool failFirst = false}) async {
    made = [];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: VideoPlayerScreen(
          campaignId: '29',
          campaign: _campaign,
          playbackFactory: (c) {
            final p = FakePlayback(failToLoad: failFirst && made.isEmpty);
            made.add(p);
            return p;
          },
        ),
      ),
    );
    await tester.pump();
    return made.single;
  }

  WatchProgressButton button(WidgetTester tester) =>
      tester.widget<WatchProgressButton>(find.byType(WatchProgressButton));

  testWidgets('loads the video and starts playing it', (tester) async {
    final player = await pump(tester);

    expect(player.plays, 1);
    expect(find.byKey(const ValueKey('fake-video')), findsOneWidget);
    expect(button(tester).unlocked, isFalse);
  });

  testWidgets('the gate opens only when the video has played to the end',
      (tester) async {
    final player = await pump(tester);

    player.at(20);
    await tester.pump();
    expect(button(tester).unlocked, isFalse);
    expect(button(tester).remainingSeconds, 13);

    player.at(33, completed: true);
    await tester.pump();
    expect(button(tester).unlocked, isTrue);
    expect(button(tester).onPressed, isNotNull);

    // A later report (e.g. a rebuffer) does not close it again.
    player.at(32, buffering: true);
    await tester.pump();
    expect(button(tester).unlocked, isTrue);
  });

  testWidgets('at the end the timeline shows the full length', (tester) async {
    final player = await pump(tester);
    player.emit(const PlaybackState(
      position: Duration(milliseconds: 32900),
      isReady: true,
      isCompleted: true,
    ));
    await tester.pump();
    expect(find.text('0:33'), findsNWidgets(2)); // elapsed + total
  });

  testWidgets('a tap pauses and a second tap resumes', (tester) async {
    final player = await pump(tester);
    player.at(5);
    await tester.pump();

    await tester.tap(find.bySemanticsLabel('Түр зогсоох'));
    await tester.pump();
    expect(player.pauses, 1);

    await tester.tap(find.bySemanticsLabel('Үргэлжлүүлэх'));
    await tester.pump();
    expect(player.plays, 2);
  });

  testWidgets('a spinner shows while the video is buffering', (tester) async {
    final player = await pump(tester);
    player.at(5, buffering: true);
    await tester.pump();
    expect(find.byKey(const ValueKey('video-loading')), findsOneWidget);

    player.at(6);
    await tester.pump();
    expect(find.byKey(const ValueKey('video-loading')), findsNothing);
  });

  testWidgets('leaving the app pauses the video until the viewer taps',
      (tester) async {
    final player = await pump(tester);
    player.at(5);
    await tester.pump();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(player.pauses, 1);
    expect(player.plays, 1);
    expect(find.bySemanticsLabel('Үргэлжлүүлэх'), findsOneWidget);
  });

  testWidgets('a video that cannot load offers a retry with a new player',
      (tester) async {
    final broken = await pump(tester, failFirst: true);

    expect(find.text(kVideoLoadError), findsOneWidget);
    // Reachable by screen readers too, not hidden inside the stage's node.
    expect(find.bySemanticsLabel(kVideoRetry), findsOneWidget);
    expect(broken.plays, 0);
    expect(button(tester).unlocked, isFalse);

    await tester.tap(find.text(kVideoRetry));
    await tester.pump();

    expect(broken.disposed, isTrue);
    expect(made, hasLength(2));
    expect(made.last.plays, 1);
    expect(find.text(kVideoLoadError), findsNothing);
  });

  testWidgets('closing the screen disposes the player', (tester) async {
    final player = await pump(tester);
    await tester.pumpWidget(const SizedBox());
    expect(player.disposed, isTrue);
  });

  group('rewind only', () {
    Finder rewind() => find.bySemanticsLabel(RewindButton.semanticLabel);

    testWidgets('there is nothing to rewind before anything has played',
        (tester) async {
      await pump(tester);
      expect(find.byType(RewindButton), findsNothing);
    });

    testWidgets('the rewind button jumps back ten seconds, never below zero',
        (tester) async {
      final player = await pump(tester);
      player.at(15);
      await tester.pump();

      await tester.tap(rewind());
      await tester.pump();
      expect(player.seeks.last, const Duration(seconds: 5));

      await tester.tap(rewind());
      await tester.pump();
      expect(player.seeks.last, Duration.zero);
    });

    testWidgets('the timeline goes back but never past what was watched',
        (tester) async {
      final player = await pump(tester);
      player.at(20);
      await tester.pump();
      final track = find.byKey(const ValueKey('watch-timeline-track'));
      final box = tester.getRect(track);

      // Near the very end of a 33 s video: clamped to the 20 s watched.
      await tester.tapAt(Offset(box.right - 1, box.center.dy));
      await tester.pump();
      expect(player.seeks.last, const Duration(seconds: 20));
      expect(button(tester).unlocked, isFalse);

      // A quarter in: allowed as it is.
      await tester.tapAt(Offset(box.left + box.width / 4, box.center.dy));
      await tester.pump();
      expect(player.seeks.last.inMilliseconds, closeTo(8250, 100));
    });

    testWidgets('dragging forward stops at the furthest watched point',
        (tester) async {
      final player = await pump(tester);
      player.at(10);
      await tester.pump();
      final box =
          tester.getRect(find.byKey(const ValueKey('watch-timeline-track')));

      await tester.dragFrom(
          Offset(box.left + 4, box.center.dy), Offset(box.width - 8, 0));
      await tester.pump();

      expect(player.seeks, isNotEmpty);
      expect(
          player.seeks.every((d) => d <= const Duration(seconds: 10)), isTrue);
    });

    testWidgets('after the end a rewind plays again and the gate stays open',
        (tester) async {
      final player = await pump(tester);
      player.at(33, completed: true);
      await tester.pump();
      expect(button(tester).unlocked, isTrue);
      final playsBefore = player.plays;

      await tester.tap(rewind());
      await tester.pump();

      expect(player.seeks.last, const Duration(seconds: 23));
      expect(player.plays, playsBefore + 1);
      expect(button(tester).unlocked, isTrue);
      expect(find.bySemanticsLabel('Түр зогсоох'), findsOneWidget);
    });

    testWidgets('a paused viewer stays paused after going back',
        (tester) async {
      final player = await pump(tester);
      player.at(15);
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Түр зогсоох'));
      await tester.pump();
      final playsBefore = player.plays;

      await tester.tap(rewind());
      await tester.pump();

      expect(player.seeks.last, const Duration(seconds: 5));
      expect(player.plays, playsBefore);
    });
  });
}
