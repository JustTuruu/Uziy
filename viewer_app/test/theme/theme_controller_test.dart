import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewer_app/theme/theme_controller.dart';

/// In-memory stand-in for secure storage.
class _Store {
  String? value;
  final writes = <String>[];
  bool failWrites = false;
  bool failReads = false;

  Future<String?> read() async {
    if (failReads) throw Exception('storage unavailable');
    return value;
  }

  Future<void> write(String v) async {
    if (failWrites) throw Exception('storage unavailable');
    writes.add(v);
    value = v;
  }
}

ThemeController _controller(_Store s) =>
    ThemeController(read: s.read, write: s.write);

void main() {
  test('a one-tap toggle goes to the opposite of the look on screen', () {
    expect(ThemeController.oppositeOf(Brightness.light), ThemeMode.dark);
    expect(ThemeController.oppositeOf(Brightness.dark), ThemeMode.light);
  });

  test('starts by following the device', () {
    expect(_controller(_Store()).mode, ThemeMode.system);
  });

  group('restore', () {
    test('loads the saved mode and notifies', () async {
      final store = _Store()..value = 'dark';
      final c = _controller(store);
      var notified = 0;
      c.addListener(() => notified++);

      await c.restore();

      expect(c.mode, ThemeMode.dark);
      expect(notified, 1);
    });

    test('an unknown or missing value falls back to the device setting',
        () async {
      final c = _controller(_Store()..value = 'sepia');
      await c.restore();
      expect(c.mode, ThemeMode.system);

      final empty = _controller(_Store());
      await empty.restore();
      expect(empty.mode, ThemeMode.system);
    });

    test('unavailable storage never stops the app starting', () async {
      final c = _controller(_Store()..failReads = true);
      await c.restore();
      expect(c.mode, ThemeMode.system);
    });

    test('a choice made while restoring is not overwritten by the old value',
        () async {
      final read = Completer<String?>();
      final c = ThemeController(read: () => read.future, write: (_) async {});

      final restoring = c.restore();
      await c.setMode(ThemeMode.light);
      read.complete('dark');
      await restoring;

      expect(c.mode, ThemeMode.light);
    });
  });

  group('setMode', () {
    test('applies at once, notifies and saves the mode name', () async {
      final store = _Store();
      final c = _controller(store);
      var notified = 0;
      c.addListener(() => notified++);

      final saved = await c.setMode(ThemeMode.dark);

      expect(saved, isTrue);
      expect(c.mode, ThemeMode.dark);
      expect(notified, 1);
      expect(store.value, 'dark');
    });

    test('rapid choices are saved in order, so the last one wins', () async {
      final store = _Store();
      final c = _controller(store);

      await Future.wait([
        c.setMode(ThemeMode.dark),
        c.setMode(ThemeMode.light),
        c.setMode(ThemeMode.system),
      ]);

      expect(store.writes, ['dark', 'light', 'system']);
      expect(store.value, 'system');
      expect(c.mode, ThemeMode.system);
    });

    test('a failed save still switches the look but reports false', () async {
      final c = _controller(_Store()..failWrites = true);

      final saved = await c.setMode(ThemeMode.dark);

      expect(saved, isFalse);
      expect(c.mode, ThemeMode.dark);
    });
  });

  test('every mode has a Mongolian label', () {
    expect(ThemeController.label(ThemeMode.system), 'Төхөөрөмжийн тохиргоо');
    expect(ThemeController.label(ThemeMode.light), 'Цайвар');
    expect(ThemeController.label(ThemeMode.dark), 'Бараан');
  });
}
