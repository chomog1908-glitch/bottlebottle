import 'package:flutter/material.dart';

import '../../logic/level_groups.dart';
import '../../services/storage.dart';
import '../theme/palette.dart';
import '../widgets/folder_card.dart';
import 'group_screen.dart';

/// 대분류 화면 — 난이도별 폴더 목록.
///
/// 여기서 난이도를 고르면 그 안에서 "병 몇 개 · 몇 층"으로 한 번 더 나뉜다.
class DifficultyScreen extends StatefulWidget {
  const DifficultyScreen({super.key, required this.currentLevel});

  /// 지금 하고 있는 레벨. 그 폴더에 표시를 해 준다.
  final int currentLevel;

  @override
  State<DifficultyScreen> createState() => _DifficultyScreenState();
}

class _DifficultyScreenState extends State<DifficultyScreen> {
  final Storage _storage = Storage();

  Set<int> _cleared = const {};
  int _reached = 1;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cleared = await _storage.loadClearedLevels();
    final reached = await _storage.loadMaxLevel();
    if (!mounted) return;
    setState(() {
      _cleared = cleared;
      _reached = reached;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final bands = LevelGroups.bands(_reached);

    return Scaffold(
      appBar: AppBar(title: const Text('난이도 고르기')),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: bands.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final band = bands[i];
            final done = band.levels.where(_cleared.contains).length;
            return FolderCard(
              accent: Palette.chapterAccent(band.accent),
              icon: Icons.folder,
              title: band.name,
              subtitle: '레벨 ${band.firstLevel}~${band.lastLevel}  ·  ${band.subtitle}',
              done: done,
              total: band.levelCount,
              highlighted: band.contains(widget.currentLevel),
              highlightLabel: '지금 여기',
              onTap: () => _openBand(i),
            );
          },
        ),
      ),
    );
  }

  Future<void> _openBand(int index) async {
    final band = LevelGroups.bands(_reached)[index];
    final picked = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) => GroupScreen(
          band: band,
          cleared: _cleared,
          currentLevel: widget.currentLevel,
        ),
      ),
    );
    // 고른 레벨을 게임 화면까지 그대로 올려보낸다.
    if (picked != null && mounted) Navigator.of(context).pop(picked);
  }
}
