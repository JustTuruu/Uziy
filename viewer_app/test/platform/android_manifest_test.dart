import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final manifest =
      File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

  test('the app opts out of Android backups (the session token stays here)',
      () {
    expect(manifest, contains('android:allowBackup="false"'));
    expect(manifest, contains('android:fullBackupContent="false"'));
  });

  test('release builds keep clear-text traffic off', () {
    expect(manifest, contains('android:usesCleartextTraffic="false"'));
  });
}
