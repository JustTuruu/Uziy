import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewer_app/widgets/ui.dart';

Future<void> _pump(
  WidgetTester tester, {
  bool reduceMotion = false,
  int count = 14,
  Widget? child,
}) {
  tester.view.physicalSize = const Size(390, 844) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark(),
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: app!,
      ),
      home: Scaffold(body: FallingCoins(count: count, child: child)),
    ),
  );
}

double _topOfFirstCoin(WidgetTester tester) =>
    tester.getTopLeft(find.byType(CoinIcon).first).dy;

void main() {
  const spec = CoinSpec(
    x: 0.5,
    size: 20,
    opacity: 0.3,
    periodSeconds: 20,
    phase: 0,
    swayPixels: 10,
    swayCycles: 2,
    spinCycles: 2,
  );

  group('coinPlacement', () {
    test('starts just above the top edge and ends just below the bottom', () {
      expect(coinPlacement(spec, 0, 800).dy, -spec.size);
      final nearEnd = coinPlacement(spec, 19.999, 800).dy;
      expect(nearEnd, closeTo(800 + spec.size, 1));
    });

    test('falls steadily: later is lower', () {
      final a = coinPlacement(spec, 4, 800).dy;
      final b = coinPlacement(spec, 8, 800).dy;
      expect(b, greaterThan(a));
    });

    test('repeats every period', () {
      final a = coinPlacement(spec, 3, 800);
      final b = coinPlacement(spec, 3.0 + spec.periodSeconds, 800);
      expect(b.dy, closeTo(a.dy, 1e-6));
      expect(b.dx, closeTo(a.dx, 1e-6));
    });

    test('is invisible at the very top and bottom, at full strength between',
        () {
      expect(coinPlacement(spec, 0, 800).opacity, 0);
      expect(coinPlacement(spec, 19.999, 800).opacity, closeTo(0, 0.01));
      expect(coinPlacement(spec, 10, 800).opacity, spec.opacity);
    });

    test('a late phase starts the coin part-way down', () {
      const late = CoinSpec(
        x: 0.5,
        size: 20,
        opacity: 0.3,
        periodSeconds: 20,
        phase: 0.5,
        swayPixels: 0,
        swayCycles: 1,
        spinCycles: 1,
      );
      expect(coinPlacement(late, 0, 800).dy, closeTo(400, 1));
    });

    test('drift stays within the sway amplitude', () {
      for (var t = 0.0; t < 20; t += 0.5) {
        expect(
            coinPlacement(spec, t, 800).dx.abs(), lessThanOrEqualTo(10.0001));
      }
    });

    test('the flip never squeezes the coin below a quarter width', () {
      for (var t = 0.0; t < 20; t += 0.25) {
        final f = coinPlacement(spec, t, 800).flip;
        expect(f, inInclusiveRange(0.25, 1.0));
      }
    });
  });

  group('buildCoinSpecs', () {
    test('is deterministic for a seed', () {
      final a = buildCoinSpecs(count: 8, seed: 3);
      final b = buildCoinSpecs(count: 8, seed: 3);
      expect(a.map((s) => s.x), b.map((s) => s.x));
      expect(a.map((s) => s.periodSeconds), b.map((s) => s.periodSeconds));
    });

    test('makes the requested number of coins, all faint and in range', () {
      final specs = buildCoinSpecs(count: 14);
      expect(specs, hasLength(14));
      for (final s in specs) {
        expect(s.x, inInclusiveRange(0, 1));
        expect(s.opacity, inInclusiveRange(0.1, 0.35));
        expect(s.size, inInclusiveRange(14, 36));
      }
    });

    test('every period divides the loop so it repeats without a jump', () {
      for (final s in buildCoinSpecs(count: 40)) {
        expect(kCoinLoopSeconds % s.periodSeconds, 0);
      }
    });
  });

  group('FallingCoins', () {
    testWidgets('draws every coin behind the child', (tester) async {
      await _pump(tester, child: const Center(child: Text('content')));

      expect(find.byType(CoinIcon), findsNWidgets(14));
      expect(find.text('content'), findsOneWidget);
    });

    testWidgets('never takes touches from the screen above it', (tester) async {
      var taps = 0;
      await _pump(
        tester,
        child: Center(
          child: TextButton(onPressed: () => taps++, child: const Text('tap')),
        ),
      );

      await tester.tap(find.text('tap'));

      expect(taps, 1);
    });

    testWidgets('the coins move while time passes', (tester) async {
      await _pump(tester);
      final before = _topOfFirstCoin(tester);

      await tester.pump(const Duration(seconds: 3));

      expect(_topOfFirstCoin(tester), isNot(before));
    });

    testWidgets('under reduce-motion the coins stay where they are',
        (tester) async {
      await _pump(tester, reduceMotion: true);
      final before = _topOfFirstCoin(tester);

      await tester.pump(const Duration(seconds: 3));

      expect(_topOfFirstCoin(tester), before);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('has no semantics of its own', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester);

      expect(find.bySemanticsLabel(RegExp('.+')), findsNothing);
      handle.dispose();
    });
  });
}
