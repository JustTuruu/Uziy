import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewer_app/services/auto_refresher.dart';

void main() {
  const interval = Duration(seconds: 10);

  testWidgets('polls every interval only while polling is on', (tester) async {
    var loads = 0;
    final r = AutoRefresher(onRefresh: () async => loads++, interval: interval);

    await tester.pump(interval * 3);
    expect(loads, 0, reason: 'not polling yet');

    r.polling = true;
    expect(r.isPolling, isTrue);
    await tester.pump(interval);
    await tester.pump(interval);
    expect(loads, 2);

    r.polling = false;
    expect(r.isPolling, isFalse);
    await tester.pump(interval * 3);
    expect(loads, 2);
    r.dispose();
  });

  testWidgets('stops in the background, reloads at once on return',
      (tester) async {
    var loads = 0;
    final r = AutoRefresher(onRefresh: () async => loads++, interval: interval);
    r.polling = true;

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    expect(r.isPolling, isFalse);
    await tester.pump(interval * 3);
    expect(loads, 0);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(loads, 1, reason: 'reloads as soon as the app is back');
    expect(r.isPolling, isTrue);
    await tester.pump(interval);
    expect(loads, 2);
    r.dispose();
  });

  testWidgets('a reload already in flight is not started twice',
      (tester) async {
    var started = 0;
    final r = AutoRefresher(
      onRefresh: () async {
        started++;
        await Future<void>.delayed(const Duration(seconds: 1));
      },
    );
    final first = r.refresh();
    await r.refresh();
    expect(started, 1);
    await tester.pump(const Duration(seconds: 1));
    await first;
    r.dispose();
  });

  testWidgets('after dispose nothing runs', (tester) async {
    var loads = 0;
    final r = AutoRefresher(onRefresh: () async => loads++, interval: interval);
    r.polling = true;
    r.dispose();
    await tester.pump(interval * 2);
    await r.refresh();
    expect(loads, 0);
  });
}
