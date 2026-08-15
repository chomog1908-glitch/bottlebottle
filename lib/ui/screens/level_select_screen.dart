import 'package:flutter/material.dart';

import '../../logic/level_groups.dart';

/// 중분류 하나를 열었을 때 나오는 레벨 격자.
///
/// 레벨을 고르면 그 번호를 돌려주며 화면을 닫는다.
class LevelSelectScreen extends StatelessWidget {
  const LevelSelectScreen({
    super.key,
    required this.group,
    required this.accent,
    required this.cleared,
    required this.currentLevel,
  });

  final LevelGroup group;
  final Color accent;

  /// 이미 클리어한 레벨 번호들. **표시용일 뿐 잠금에는 쓰지 않는다.**
  final Set<int> cleared;

  final int currentLevel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(group.title),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(26),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(group.subtitle,
                style: Theme.of(context).textTheme.bodySmall),
          ),
        ),
      ),
      body: SafeArea(
        child: GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 84,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1,
          ),
          itemCount: group.levelCount,
          itemBuilder: (context, i) => _levelTile(context, group.firstLevel + i),
        ),
      ),
    );
  }

  Widget _levelTile(BuildContext context, int level) {
    final scheme = Theme.of(context).colorScheme;
    final isCleared = cleared.contains(level);
    final isCurrent = level == currentLevel;

    return Material(
      color: isCleared ? accent.withValues(alpha: 0.20) : scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).pop(level),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isCurrent ? accent : scheme.outlineVariant,
              width: isCurrent ? 2.5 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$level',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 2),
              // 클리어 표시. 안 한 레벨에는 아무 표시도 하지 않는다.
              // 빈 자리를 X나 자물쇠로 채우면 못 한 것을 세는 화면이 된다.
              SizedBox(
                height: 16,
                child: isCleared
                    ? Icon(Icons.check_circle, size: 15, color: accent)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
