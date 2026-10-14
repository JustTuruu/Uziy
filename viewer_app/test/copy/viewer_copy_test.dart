import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Text the viewer can read never mentions the platform's staff as "админ"
/// (owner, 2026-10-14): checks happen, but who does them is not the
/// viewer's concern. Comments may still say admin; string literals may not.
void main() {
  test('no "админ" in the viewer app copy', () {
    final word = RegExp('[Аа]дмин');
    final offenders = <String>[];
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    for (final file in files) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final code = lines[i].trimLeft();
        if (code.startsWith('//')) continue;
        if (word.hasMatch(code)) offenders.add('${file.path}:${i + 1}');
      }
    }
    expect(offenders, isEmpty);
  });
}
