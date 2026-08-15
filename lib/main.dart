import 'package:flutter/material.dart';

import 'controller/settings_controller.dart';
import 'services/audio.dart';
import 'ui/screens/home_screen.dart';

void main() {
  runApp(const BottleBottleApp());
}

class BottleBottleApp extends StatefulWidget {
  const BottleBottleApp({super.key});

  @override
  State<BottleBottleApp> createState() => _BottleBottleAppState();
}

class _BottleBottleAppState extends State<BottleBottleApp> {
  /// 설정은 앱 전체가 하나를 본다. 여기서 만들어 아래로 내려보낸다.
  /// 그래야 설정을 바꾼 순간 모든 화면이 함께 바뀐다.
  final SettingsController _settings = SettingsController();
  final AudioService _audio = AudioService();

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    await _settings.load();
    await _audio.init();
    // 소리를 낼지 말지는 설정이 정한다. 설정을 읽은 뒤에 알려준다.
    _audio.enabled = _settings.soundOn;
    _settings.addListener(_applySettings);
    if (mounted) setState(() {});
  }

  void _applySettings() {
    _audio.enabled = _settings.soundOn;
    setState(() {});
  }

  @override
  void dispose() {
    _settings.removeListener(_applySettings);
    _audio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '물병 정렬',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF4FC3F7),
        brightness: Brightness.light,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF4FC3F7),
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      themeMode: _settings.themeMode,
      // 큰 글씨 모드는 앱 전체에 한 번에 건다.
      // 화면마다 글자 크기를 손대면 어딘가는 반드시 빠뜨린다.
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        minScaleFactor: _settings.textScale,
        maxScaleFactor: _settings.textScale,
        child: child!,
      ),
      home: HomeScreen(settings: _settings, audio: _audio),
    );
  }
}
