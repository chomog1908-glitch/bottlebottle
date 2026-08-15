import 'package:flutter/material.dart';

import '../../logic/level_groups.dart';
import '../theme/palette.dart';
import '../widgets/folder_card.dart';
import 'level_select_screen.dart';

/// 중분류 화면 — 난이도 하나를 열면 나오는 "병 몇 개 · 몇 층" 목록.
class GroupScreen extends StatelessWidget {
  const GroupScreen({
    super.key,
    required this.band,
    required this.cleared,
    required this.currentLevel,
  });

  final DifficultyBand band;

  /// 클리어한 레벨. **표시용일 뿐 잠금에는 쓰지 않는다.**
  final Set<int> cleared;

  final int currentLevel;

  @override
  Widget build(BuildContext context) {
    final accent = Palette.chapterAccent(band.accent);

    return Scaffold(
      appBar: AppBar(
        title: Text(band.name),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(26),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '레벨 ${band.firstLevel}~${band.lastLevel}  ·  ${band.subtitle}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: band.groups.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final group = band.groups[i];
            final done = group.levels.where(cleared.contains).length;
            return FolderCard(
              accent: accent,
              // 병이 깊어질수록 아이콘도 길쭉한 것으로 바뀐다.
              icon: group.capacity >= 6 ? Icons.science_outlined : Icons.local_drink,
              title: group.title,
              subtitle: group.subtitle,
              done: done,
              total: group.levelCount,
              highlighted: group.contains(currentLevel),
              onTap: () => _openGroup(context, group, accent),
            );
          },
        ),
      ),
    );
  }

  Future<void> _openGroup(
      BuildContext context, LevelGroup group, Color accent) async {
    final navigator = Navigator.of(context);
    final picked = await navigator.push<int>(
      MaterialPageRoute(
        builder: (_) => LevelSelectScreen(
          group: group,
          accent: accent,
          cleared: cleared,
          currentLevel: currentLevel,
        ),
      ),
    );
    if (picked != null) navigator.pop(picked);
  }
}
