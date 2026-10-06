import 'package:flutter_test/flutter_test.dart';
import 'package:viewer_app/services/push/push_runtime.dart';

void main() {
  test('uninitialised runtime (no Firebase) is a silent no-op', () async {
    await PushRuntime.instance.onHomeReached();
    await PushRuntime.instance.onLogout();
  });
}
