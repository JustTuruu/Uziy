import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewer_app/screens/home/video_widgets.dart';
import 'package:viewer_app/widgets/ui.dart';

/// Pumps [child] in the real app theme. [reduceMotion] emulates the OS
/// "reduce motion" setting.
Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  bool reduceMotion = false,
  double width = 360,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark(),
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: app!,
      ),
      home: Scaffold(
        body: Center(child: SizedBox(width: width, child: child)),
      ),
    ),
  );
}

/// Records `HapticFeedback.*` calls sent over the platform channel.
List<String> _recordHaptics(WidgetTester tester) {
  final calls = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        calls.add(call.arguments as String);
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null),
  );
  return calls;
}

Widget _button({
  required bool unlocked,
  VoidCallback? onPressed,
  double progress = 0.4,
  int remaining = 12,
}) =>
    WatchProgressButton(
      progress: progress,
      remainingSeconds: remaining,
      unlocked: unlocked,
      onPressed: onPressed,
    );

void main() {
  group('formatPlaybackTime', () {
    test('formats whole seconds as m:ss', () {
      expect(formatPlaybackTime(0), '0:00');
      expect(formatPlaybackTime(5), '0:05');
      expect(formatPlaybackTime(59), '0:59');
      expect(formatPlaybackTime(60), '1:00');
      expect(formatPlaybackTime(61), '1:01');
      expect(formatPlaybackTime(125), '2:05');
    });

    test('truncates fractions (player elapsed ticks by 0.25 s)', () {
      expect(formatPlaybackTime(12.75), '0:12');
      expect(formatPlaybackTime(59.99), '0:59');
    });

    test('treats negative and non-finite input as zero', () {
      expect(formatPlaybackTime(-3), '0:00');
      expect(formatPlaybackTime(double.nan), '0:00');
      expect(formatPlaybackTime(double.infinity), '0:00');
    });

    test('rolls over into hours', () {
      expect(formatPlaybackTime(3600), '1:00:00');
    });
  });

  group('watchProgressFraction', () {
    test('is elapsed / duration clamped to [0, 1]', () {
      expect(watchProgressFraction(0, 45), 0);
      expect(watchProgressFraction(22.5, 45), 0.5);
      expect(watchProgressFraction(45, 45), 1);
      expect(watchProgressFraction(50, 45), 1);
      expect(watchProgressFraction(-1, 45), 0);
    });

    test('a zero-length video counts as fully watched', () {
      expect(watchProgressFraction(0, 0), 1);
    });

    test('non-finite elapsed is 0', () {
      expect(watchProgressFraction(double.nan, 45), 0);
    });
  });

  group('remainingWatchSeconds', () {
    test('rounds up so the countdown never shows 0 early', () {
      expect(remainingWatchSeconds(0, 45), 45);
      expect(remainingWatchSeconds(44.25, 45), 1);
      expect(remainingWatchSeconds(32.75, 45), 13);
    });

    test('is 0 once watched and never negative', () {
      expect(remainingWatchSeconds(45, 45), 0);
      expect(remainingWatchSeconds(60, 45), 0);
      expect(remainingWatchSeconds(double.nan, 45), 0);
    });
  });

  group('WatchProgressButton', () {
    test('remainingLabel uses the short duration format', () {
      expect(WatchProgressButton.remainingLabel(12), '12 сек');
      expect(WatchProgressButton.remainingLabel(90), '1:30');
      expect(WatchProgressButton.remainingLabel(-4), '0 сек');
    });

    testWidgets('locked: shows remaining time and ignores taps',
        (tester) async {
      var taps = 0;
      await _pump(tester, _button(unlocked: false, onPressed: () => taps++));
      await tester.pumpAndSettle();

      expect(find.text(WatchProgressButton.lockedTitle), findsOneWidget);
      expect(find.textContaining('12 сек'), findsOneWidget);
      expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
      expect(find.text('Судалгаа руу үргэлжлүүлэх'), findsNothing);

      await tester.tap(find.byType(WatchProgressButton));
      await tester.pumpAndSettle();
      expect(taps, 0);
    });

    testWidgets('locked: announced as a disabled button with the countdown',
        (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, _button(unlocked: false, onPressed: () {}));
      await tester.pumpAndSettle();

      expect(
        tester.getSemantics(find.byType(Pressable)),
        matchesSemantics(
          label: 'Видеог бүтэн үзнэ үү, 12 сек үлдсэн',
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
        ),
      );
      handle.dispose();
    });

    testWidgets('unlocked: shows the CTA and fires onPressed', (tester) async {
      var taps = 0;
      await _pump(
        tester,
        _button(unlocked: true, onPressed: () => taps++),
        reduceMotion: true,
      );
      await tester.pumpAndSettle();

      expect(find.text('Судалгаа руу үргэлжлүүлэх'), findsOneWidget);
      expect(find.byIcon(Icons.lock_rounded), findsNothing);
      expect(find.textContaining('сек'), findsNothing);

      await tester.tap(find.byType(WatchProgressButton));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('unlocked with a null onPressed stays disabled',
        (tester) async {
      await _pump(tester, _button(unlocked: true), reduceMotion: true);
      await tester.pumpAndSettle();
      final pressable = tester.widget<Pressable>(find.byType(Pressable));
      expect(pressable.onTap, isNull);
    });

    testWidgets(
        'fires mediumImpact exactly once on the locked -> unlocked '
        'transition, then its pulse settles', (tester) async {
      final haptics = _recordHaptics(tester);
      var taps = 0;
      void onPressed() => taps++;

      await _pump(tester, _button(unlocked: false, onPressed: onPressed));
      await tester.pumpAndSettle();
      expect(haptics, isEmpty);

      await _pump(tester, _button(unlocked: true, onPressed: onPressed));
      await tester.pump();
      expect(haptics, ['HapticFeedbackType.mediumImpact']);

      // Rebuilding while still unlocked must not buzz again.
      await _pump(
        tester,
        _button(unlocked: true, onPressed: onPressed, progress: 1),
      );
      // The pulse runs a fixed number of cycles, so it settles.
      await tester.pumpAndSettle();
      expect(haptics, ['HapticFeedbackType.mediumImpact']);

      await tester.tap(find.byType(WatchProgressButton));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('mounting already unlocked does not buzz', (tester) async {
      final haptics = _recordHaptics(tester);
      await _pump(tester, _button(unlocked: true, onPressed: () {}));
      await tester.pumpAndSettle();
      expect(haptics, isEmpty);
    });

    testWidgets('fits an iPhone SE width at 1.3x text without overflow',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 568),
              textScaler: TextScaler.linear(1.3),
            ),
            child: Scaffold(
              body: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Center(
                  child: _button(
                    unlocked: false,
                    onPressed: () {},
                    remaining: 45,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // The countdown is never ellipsized away.
      expect(find.textContaining('45 сек'), findsOneWidget);
    });

    testWidgets('does not throw in an unbounded-width parent', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: Row(
              children: [_button(unlocked: false, onPressed: () {})],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('PlayPauseMedallion', () {
    testWidgets('playing shows a pause glyph and no label', (tester) async {
      await _pump(tester, const PlayPauseMedallion(paused: false));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
      expect(find.text(PlayPauseMedallion.pausedLabel), findsNothing);
    });

    testWidgets('paused shows a play glyph and the pause label',
        (tester) async {
      await _pump(tester, const PlayPauseMedallion(paused: true));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(find.text('Түр зогссон'), findsOneWidget);
    });

    testWidgets('completed wins over paused', (tester) async {
      await _pump(
        tester,
        const PlayPauseMedallion(paused: true, completed: true),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(find.text(PlayPauseMedallion.completedLabel), findsOneWidget);
      expect(find.text(PlayPauseMedallion.pausedLabel), findsNothing);
    });

    testWidgets('switches glyph when toggled', (tester) async {
      // The disc glyph is large; the label chip may carry a small icon.
      Finder glyph(IconData icon) => find.byWidgetPredicate(
            (w) => w is Icon && w.icon == icon && (w.size ?? 0) > 20,
          );

      await _pump(tester, const PlayPauseMedallion(paused: false));
      await tester.pumpAndSettle();
      expect(glyph(Icons.pause_rounded), findsOneWidget);

      await _pump(tester, const PlayPauseMedallion(paused: true));
      await tester.pumpAndSettle();
      expect(glyph(Icons.play_arrow_rounded), findsOneWidget);
      expect(glyph(Icons.pause_rounded), findsNothing);
    });
  });

  group('WatchTimeline', () {
    testWidgets('shows elapsed and total as m:ss', (tester) async {
      await _pump(
        tester,
        const WatchTimeline(
          progress: 0.5,
          elapsedSeconds: 22.75,
          totalSeconds: 45,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('0:22'), findsOneWidget);
      expect(find.text('0:45'), findsOneWidget);
    });

    testWidgets('exposes progress to screen readers', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        const WatchTimeline(
          progress: 1.0,
          elapsedSeconds: 125,
          totalSeconds: 125,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsLabel(WatchTimeline.semanticLabel),
        findsOneWidget,
      );
      expect(
        tester.getSemantics(find.byType(WatchTimeline)),
        matchesSemantics(
          label: WatchTimeline.semanticLabel,
          value: '2 мин 5 сек, нийт 2 мин 5 сек',
        ),
      );
      handle.dispose();
    });
  });

  group('RewardHintRow', () {
    testWidgets('before the end: watch fully to earn the reward',
        (tester) async {
      await _pump(tester, const RewardHintRow(amount: 700, completed: false));
      await tester.pumpAndSettle();
      expect(
        find.text('Бүтэн үзээд +700 ₮ аваарай', findRichText: true),
        findsOneWidget,
      );
      expect(find.byType(CoinIcon), findsOneWidget);
    });

    testWidgets('after the end: answer the survey to earn it', (tester) async {
      await _pump(tester, const RewardHintRow(amount: 700, completed: true));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Судалгаанд хариулаад +700 ₮ аваарай',
          findRichText: true,
        ),
        findsOneWidget,
      );
    });
  });

  group('SponsorAvatar', () {
    testWidgets('shows the company monogram', (tester) async {
      await _pump(
        tester,
        const SponsorAvatar(campaignId: 2, companyName: 'голомт'),
      );
      expect(find.text('Г'), findsOneWidget);
    });
  });
}
