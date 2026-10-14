import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists only appearance; independent of authentication and logout.
class ThemeController extends ChangeNotifier {
  ThemeController({
    Future<String?> Function()? read,
    Future<void> Function(String)? write,
  })  : _read = read ?? (() => _storage.read(key: _key)),
        _write = write ?? ((value) => _storage.write(key: _key, value: value));

  static final instance = ThemeController();
  static const _storage = FlutterSecureStorage();
  static const _key = 'appearance_mode';
  final Future<String?> Function() _read;
  final Future<void> Function(String) _write;
  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;
  int _revision = 0;
  Future<void> _writes = Future.value();

  Future<void> restore() async {
    final revision = _revision;
    try {
      final value = await _read();
      if (revision != _revision) return;
      _mode = ThemeMode.values.firstWhere((mode) => mode.name == value,
          orElse: () => ThemeMode.system);
      notifyListeners();
    } catch (_) {
      // Unavailable storage must not prevent the app from starting.
    }
  }

  /// Apply immediately and serialize writes so rapid selections persist last.
  Future<bool> setMode(ThemeMode value) async {
    _revision++;
    _mode = value;
    notifyListeners();
    var saved = true;
    _writes = _writes.then((_) async {
      try {
        await _write(value.name);
      } catch (_) {
        saved = false;
      }
    });
    await _writes;
    return saved;
  }

  static String label(ThemeMode mode) => switch (mode) {
        ThemeMode.system => 'Төхөөрөмжийн тохиргоо',
        ThemeMode.light => 'Цайвар',
        ThemeMode.dark => 'Бараан',
      };
}
