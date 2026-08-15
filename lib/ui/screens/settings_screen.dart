import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../controller/settings_controller.dart';
import '../../services/storage.dart';
import '../theme/palette.dart';

/// 설정 화면.
///
/// 항목이 적다. 고를 것이 많으면 그것대로 부담이 되기 때문에,
/// 실제로 도움이 되는 것만 남겼다.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.settings});

  final SettingsController settings;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('설정')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              _section(context, '보기'),
              SwitchListTile(
                value: settings.largeText,
                onChanged: settings.setLargeText,
                secondary: const Icon(Icons.format_size),
                title: const Text('큰 글씨'),
                subtitle: const Text('글자를 크게 키웁니다'),
              ),
              SwitchListTile(
                value: settings.showSymbols,
                onChanged: settings.setShowSymbols,
                secondary: const Icon(Icons.category_outlined),
                title: const Text('색마다 기호 표시'),
                subtitle: const Text('색이 헷갈릴 때 도형으로 함께 구분합니다'),
              ),
              if (settings.showSymbols) _symbolPreview(context),
              ListTile(
                leading: const Icon(Icons.brightness_6_outlined),
                title: const Text('화면 밝기'),
                subtitle: Text(_themeLabel(settings.themeMode)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text('기기 설정'),
                      icon: Icon(Icons.smartphone),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      label: Text('밝게'),
                      icon: Icon(Icons.light_mode),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      label: Text('어둡게'),
                      icon: Icon(Icons.dark_mode),
                    ),
                  ],
                  selected: {settings.themeMode},
                  onSelectionChanged: (s) => settings.setThemeMode(s.first),
                ),
              ),
              const Divider(),
              _section(context, '소리'),
              SwitchListTile(
                value: settings.soundOn,
                onChanged: settings.setSoundOn,
                secondary: const Icon(Icons.volume_up_outlined),
                title: const Text('효과음'),
                subtitle: const Text('물 붓는 쪼르륵 소리와 완성 소리'),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(
                  '배경 음악은 넣지 않았습니다. 오래 하면 피로해서요.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              const Divider(),
              _section(context, '기록 옮기기'),
              ListTile(
                leading: const Icon(Icons.ios_share),
                title: const Text('기록 내보내기'),
                subtitle: const Text('진행도·도전과제·설정을 글자로 복사합니다'),
                onTap: () => _export(context),
              ),
              ListTile(
                leading: const Icon(Icons.download_outlined),
                title: const Text('기록 불러오기'),
                subtitle: const Text('복사해 둔 글자를 붙여넣어 되살립니다'),
                onTap: () => _import(context),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(
                  '폰을 바꾸실 때 쓰세요. 내보낸 글자를 메모장이나 문자로 옮겨 두었다가,\n'
                  '새 폰에서 불러오기로 붙여넣으면 그대로 이어집니다.\n'
                  '인터넷으로 보내는 것이 아니라 이 기기 안에서만 오갑니다.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              const Divider(),
              const ListTile(
                leading: Icon(Icons.favorite_outline),
                title: Text('이 앱에 없는 것'),
                subtitle: Text(
                  '광고 · 결제 · 하트 · 로그인 · 인터넷 연결\n'
                  '앞으로도 넣지 않습니다.',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 저장된 모든 것을 글자로 뽑아 클립보드에 넣고, 눈으로도 보여준다.
  ///
  /// 클립보드에만 넣으면 정말 복사됐는지 확인할 길이 없어 불안하다.
  Future<void> _export(BuildContext context) async {
    final text = await Storage().exportAll();
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('복사했습니다'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('아래 글자가 복사되어 있습니다. 메모장이나 문자에 붙여넣어 보관하세요.'),
              const SizedBox(height: 12),
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    text,
                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  /// 붙여넣은 글자로 기록을 되살린다.
  ///
  /// 클립보드에 이미 들어 있으면 미리 채워 둔다. 붙여넣기를 손으로 하게 만들면
  /// 그 한 단계에서 막히시는 분이 반드시 생긴다.
  Future<void> _import(BuildContext context) async {
    final clip = await Clipboard.getData(Clipboard.kTextPlain);
    if (!context.mounted) return;

    final controller = TextEditingController(text: clip?.text ?? '');
    final go = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('기록 불러오기'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('지금 기기의 기록을 덮어씁니다. 되돌릴 수 없습니다.'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 5,
              style: const TextStyle(fontSize: 11),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '내보내기로 복사해 둔 글자를 붙여넣으세요',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('그만두기'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('불러오기'),
          ),
        ],
      ),
    );

    if (go != true || !context.mounted) return;

    final ok = await Storage().importAll(controller.text.trim());
    // 설정도 함께 들어 있으므로 지금 화면이 보고 있는 값을 다시 읽는다.
    if (ok) await settings.load();
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? '불러왔습니다. 홈으로 돌아가면 기록이 반영되어 있습니다.'
              : '읽을 수 없는 글자입니다. 내보내기로 복사한 전체를 붙여넣어 주세요.',
        ),
      ),
    );
  }

  Widget _section(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(
          title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
        ),
      );

  /// 켰을 때 어떤 모양이 나오는지 바로 보여준다.
  /// 설정을 켠 뒤 게임 화면까지 가서야 확인하게 만들 이유가 없다.
  Widget _symbolPreview(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(72, 0, 16, 12),
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var i = 0; i < 8; i++)
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Palette.liquid(i),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  Palette.symbol(i),
                  style: TextStyle(color: Palette.onLiquid(i), fontSize: 16),
                ),
              ),
          ],
        ),
      );

  static String _themeLabel(ThemeMode mode) => switch (mode) {
        ThemeMode.light => '항상 밝게',
        ThemeMode.dark => '항상 어둡게',
        ThemeMode.system => '기기 설정을 따릅니다',
      };
}
