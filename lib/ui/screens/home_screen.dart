import 'package:flutter/material.dart';

import '../../controller/settings_controller.dart';
import '../../logic/achievements.dart';
import '../../logic/level_config.dart';
import '../../services/audio.dart';
import '../../services/storage.dart';
import '../theme/palette.dart';
import 'achievements_screen.dart';
import 'difficulty_screen.dart';
import 'game_screen.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';

/// 첫 화면.
///
/// **가장 큰 버튼은 언제나 "이어서 하기"다.** 앱을 켜는 이유의 대부분이 그것이기 때문에,
/// 나머지 기능은 그 아래에 조용히 놓는다. 켤 때마다 메뉴를 읽게 만들지 않는다.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.settings, required this.audio});

  final SettingsController settings;
  final AudioService audio;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Storage _storage = Storage();

  int _level = 1;
  int _maxLevel = 1;
  PlayStats _stats = const PlayStats();
  Map<String, String> _earnedOn = const {};
  Set<int> _cleared = const {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// 저장된 것들을 읽어 온다. 게임에서 돌아올 때마다 다시 읽는다.
  Future<void> _load() async {
    final saved = await _storage.loadGame();
    final maxLevel = await _storage.loadMaxLevel();
    final stats = await _storage.loadStats();
    final earnedOn = await _storage.loadAchievementDates();
    final cleared = await _storage.loadClearedLevels();

    if (!mounted) return;
    setState(() {
      _level = saved?.level ?? 1;
      _maxLevel = maxLevel;
      _stats = stats;
      _earnedOn = earnedOn;
      _cleared = cleared;
      _loading = false;
    });
  }

  /// 게임을 시작한다. [level]이 없으면 두던 판을 이어서 한다.
  Future<void> _play({int? level}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          settings: widget.settings,
          audio: widget.audio,
          startLevel: level,
        ),
      ),
    );
    // 돌아오면 기록이 달라져 있다. 홈의 숫자도 함께 갱신한다.
    await _load();
  }

  Future<void> _openLevelPicker() async {
    final picked = await Navigator.of(context).push<int>(
      MaterialPageRoute(builder: (_) => DifficultyScreen(currentLevel: _level)),
    );
    if (picked != null && mounted) await _play(level: picked);
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Container(
        // 홈만은 배경을 깔아 준다. 게임 화면은 병이 주인공이라 조용해야 하지만,
        // 첫 화면까지 조용하면 앱이 밋밋하게 시작한다.
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.primaryContainer,
              scheme.surface,
              scheme.tertiaryContainer,
            ],
          ),
        ),
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                  children: [
                    _title(context),
                    const SizedBox(height: 24),
                    _continueCard(context),
                    const SizedBox(height: 16),
                    _menu(context),
                    const SizedBox(height: 20),
                    _summaryStrip(context),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _title(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        // 앱의 얼굴. 병 세 개를 색만으로 그려 둔다.
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < 3; i++) ...[
              _miniBottle(Palette.liquid(i * 3), 3 - (i - 1).abs()),
              if (i != 2) const SizedBox(width: 8),
            ],
          ],
        ),
        const SizedBox(height: 14),
        Text(
          '물병 정렬',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: scheme.onSurface,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          '광고도, 하트도, 끝도 없습니다',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }

  /// 제목 옆에 놓는 장식용 병. 아래에서 [filled]칸만큼 차 있다.
  Widget _miniBottle(Color color, int filled) {
    return Container(
      width: 26,
      height: 62,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.35),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(5),
          bottom: Radius.circular(13),
        ),
        border: Border.all(color: color.withValues(alpha: 0.55), width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(height: 62 * filled / 4, color: color),
        ],
      ),
    );
  }

  /// 가장 큰 버튼. 여기만 눌러도 게임이 된다.
  Widget _continueCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final config = LevelConfig.forLevel(_level);
    final fresh = _level == 1 && _stats.clearedCount == 0;

    return Material(
      color: scheme.primary,
      borderRadius: BorderRadius.circular(24),
      elevation: 3,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => _play(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
          child: Row(
            children: [
              Icon(Icons.play_arrow_rounded, size: 42, color: scheme.onPrimary),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fresh ? '시작하기' : '이어서 하기',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: scheme.onPrimary,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Lv $_level · ${config.difficultyLabel} · '
                      '병 ${config.bottleCount}개 · ${config.capacity}층',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: scheme.onPrimary.withValues(alpha: 0.85),
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menu(BuildContext context) {
    final items = <(IconData, String, String, Color, VoidCallback)>[
      (
        Icons.grid_view_rounded,
        '레벨 고르기',
        '어느 레벨이든 열려 있습니다',
        const Color(0xFF1E88E5),
        _openLevelPicker,
      ),
      (
        Icons.emoji_events_outlined,
        '도전과제',
        '${Achievements.earnedIn(_stats, _earnedOn.keys.toSet()).length} / ${Achievements.all.length} 달성',
        const Color(0xFFF9A825),
        () => _open(AchievementsScreen(stats: _stats, earnedOn: _earnedOn)),
      ),
      (
        Icons.insights_rounded,
        '통계',
        '지나온 길을 숫자로',
        const Color(0xFF00897B),
        () => _open(StatsScreen(
              stats: _stats,
              clearedLevels: _cleared,
              maxLevel: _maxLevel,
              earnedOn: _earnedOn,
            )),
      ),
      (
        Icons.settings_outlined,
        '설정',
        '글씨 크기 · 소리 · 색약 모드',
        const Color(0xFF8E24AA),
        () => _open(SettingsScreen(settings: widget.settings)),
      ),
    ];

    return Column(
      children: [
        for (final (icon, title, subtitle, tint, onTap) in items) ...[
          _menuCard(context, icon, title, subtitle, tint, onTap),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _menuCard(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    Color tint,
    VoidCallback onTap,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: tint),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  /// 홈 맨 아래에 놓는 숫자 세 개. 자세한 건 통계 화면에 있다.
  Widget _summaryStrip(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final items = <(String, String)>[
      ('완성한 판', '${_stats.clearedCount}'),
      ('가장 멀리', 'Lv $_maxLevel'),
      ('게임을 한 날', '${_stats.daysPlayed}일'),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: scheme.surface.withValues(alpha: 0.7),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final (label, value) in items)
            Column(
              children: [
                Text(
                  value,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(label, style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
        ],
      ),
    );
  }
}
