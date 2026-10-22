import 'package:flutter_test/flutter_test.dart';
import 'package:viewer_app/services/debug_log.dart';

void main() {
  test('prints the message when enabled (debug builds)', () {
    final lines = <String?>[];
    debugLog(() => '[push] failed: x', enabled: true, printer: lines.add);
    expect(lines, ['[push] failed: x']);
  });

  test('prints nothing and builds nothing when disabled (release)', () {
    final lines = <String?>[];
    var built = false;
    debugLog(
      () {
        built = true;
        return 'secret';
      },
      enabled: false,
      printer: lines.add,
    );
    expect(lines, isEmpty);
    expect(built, isFalse);
  });
}
