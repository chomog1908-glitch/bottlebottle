import 'package:flutter/material.dart';

import '../services/storage.dart';

/// 설정값을 들고 있으면서, 바뀔 때마다 저장하고 화면에 알린다.
///
/// 앱 전체가 이 하나를 본다. 테마와 글씨 크기가 여기에 있어야
/// 설정을 바꾼 순간 모든 화면이 함께 바뀐다.
class SettingsController extends ChangeNotifier {
  SettingsController({Storage? storage}) : _storage = storage ?? Storage();

  final Storage _storage;

  /// 색약 모드 — 색 위에 도형 기호를 함께 표시한다. **기본 꺼짐.**
  bool showSymbols = false;

  /// 효과음. **기본 켜짐.**
  bool soundOn = true;

  /// 큰 글씨 모드. **기본 꺼짐.**
  bool largeText = false;

  ThemeMode themeMode = ThemeMode.system;

  /// 큰 글씨 모드일 때의 글자 배율.
  double get textScale => largeText ? 1.3 : 1.0;

  bool _loaded = false;

  bool get loaded => _loaded;

  Future<void> load() async {
    showSymbols = await _storage.loadShowSymbols();
    soundOn = await _storage.loadSoundOn();
    largeText = await _storage.loadLargeText();
    themeMode = _parseTheme(await _storage.loadThemeMode());
    _loaded = true;
    notifyListeners();
  }

  Future<void> setShowSymbols(bool value) async {
    showSymbols = value;
    notifyListeners();
    await _storage.saveShowSymbols(value);
  }

  Future<void> setSoundOn(bool value) async {
    soundOn = value;
    notifyListeners();
    await _storage.saveSoundOn(value);
  }

  Future<void> setLargeText(bool value) async {
    largeText = value;
    notifyListeners();
    await _storage.saveLargeText(value);
  }

  Future<void> setThemeMode(ThemeMode value) async {
    themeMode = value;
    notifyListeners();
    await _storage.saveThemeMode(_themeName(value));
  }

  static ThemeMode _parseTheme(String name) => switch (name) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  static String _themeName(ThemeMode mode) => switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };
}
