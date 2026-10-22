import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:viewer_app/services/secure_store.dart';

void main() {
  test('iOS keychain items stay on this device and are never synced', () {
    final ios = appSecureStorage.iOptions.toMap();
    expect(ios['accessibility'], 'first_unlock_this_device');
    expect(ios['synchronizable'], 'false');
  });

  test('Android values use EncryptedSharedPreferences', () {
    final android = appSecureStorage.aOptions.toMap();
    expect(android['encryptedSharedPreferences'], 'true');
  });

  test('no other file builds a secure storage with the default options', () {
    final offenders = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => !f.path.endsWith('secure_store.dart'))
        .where((f) => f.readAsStringSync().contains('FlutterSecureStorage('))
        .map((f) => f.path)
        .toList();
    expect(offenders, isEmpty);
  });
}
