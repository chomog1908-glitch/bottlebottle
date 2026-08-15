import 'package:flutter/material.dart';

import '../../logic/achievements.dart';
import '../../logic/stats_summary.dart';
import '../widgets/achievement_tile.dart';
import '../widgets/stat_widgets.dart';

/// 통계 대시보드.
///
/// **숫자만 보여준다. 목표를 주지 않는다.** 여기 있는 어떤 값도 잘하고 못하고를
/// 가르지 않는다. 힌트를 많이 쓴 것은 이 게임이 자랑하는 기능을 편히 쓰신 것이지
/// 부끄러운 기록이 아니다.
class StatsScreen extends StatelessWidget {
  const StatsScreen({
    super.key,
    required this.stats,
    required this.clearedLevels,
    required this.maxLevel,
    this.earnedOn = const {},
    this.today,
  });

  final PlayStats stats;

  /// 클리어한 레벨 번호들. 난이도별 진행을 그리는 데 쓴다.
  final Set<int> clearedLevels;

  final int maxLevel;

  /// `도전과제 id → 얻은 날짜`.
  final Map<String, String> earnedOn;

  /// 오늘. 테스트에서 날짜를 고정할 때만 넘긴다.
  final DateTime? today;

  static const Color _blue = Color(0xFF1E88E5);
  static const Color _green = Color(0xFF43A047);
  static const Color _amber = Color(0xFFF9A825);
  static const Color _purple = Color(0xFF8E24AA);
  static const Color _teal = Color(0xFF00897B);

  @override
  Widget build(BuildContext context) {
    final now = today ?? DateTime.now();

    return Scaffold(
      appBar: AppBar(title: const Text('통계')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _tiles(context),
            const SizedBox(height: 16),
            _rings(context),
            const SizedBox(height: 16),
            _byDifficulty(context),
            const SizedBox(height: 16),
            _tools(context),
            const SizedBox(height: 16),
            _activity(context, now),
            const SizedBox(height: 16),
            _recentAchievements(context),
          ],
        ),
      ),
    );
  }

  /// 큰 숫자 넷. 대시보드를 열자마자 눈에 들어와야 하는 것들이다.
  Widget _tiles(BuildContext context) {
    final tiles = [
      StatTile(
        label: '완성한 판',
        value: '${stats.clearedCount}',
        suffix: '판',
        emoji: '🫙',
        tint: _blue,
      ),
      StatTile(
        label: '가장 멀리',
        value: '${stats.maxLevel}',
        suffix: '레벨',
        emoji: '🚩',
        tint: _green,
      ),
      StatTile(
        label: '지금까지 둔 수',
        value: '${stats.totalMoves}',
        suffix: '수',
        emoji: '💧',
        tint: _teal,
      ),
      StatTile(
        label: '게임을 한 날',
        value: '${stats.daysPlayed}',
        suffix: '일',
        emoji: '📅',
        tint: _amber,
      ),
    ];

    // 좁은 화면에서도 두 칸씩 놓이도록 비율을 넉넉히 잡는다.
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.55,
      children: tiles,
    );
  }

  Widget _rings(BuildContext context) {
    final earned = Achievements.earnedIn(stats).length;
    final total = Achievements.all.length;
    final solo = StatsSummary.soloRatio(
      clearedCount: stats.clearedCount,
      flawlessClears: stats.flawlessClears,
    );

    return StatCard(
      title: '한눈에',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          StatRing(
            ratio: total == 0 ? 0 : earned / total,
            center: '$earned/$total',
            label: '도전과제',
            tint: _purple,
          ),
          StatRing(
            ratio: solo,
            center: '${(solo * 100).round()}%',
            label: '스스로 푼 판',
            tint: _green,
          ),
          StatRing(
            ratio: stats.clearedCount == 0
                ? 0
                : stats.thriftyClears / stats.clearedCount,
            center: '${stats.thriftyClears}',
            label: '빈 병 아낀 판',
            tint: _blue,
          ),
        ],
      ),
    );
  }

  Widget _byDifficulty(BuildContext context) {
    final rows = StatsSummary.byDifficulty(clearedLevels, maxLevel);
    const tints = [_green, _blue, _teal, _amber, Color(0xFFE65100), _purple];

    return StatCard(
      title: '난이도별 진행',
      trailing: Text(
        '${clearedLevels.length}개 레벨 완성',
        style: Theme.of(context).textTheme.labelMedium,
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            StatBar(
              label: rows[i].label,
              value: rows[i].isEndless
                  ? '${rows[i].cleared}판'
                  : '${rows[i].cleared} / ${rows[i].total}',
              ratio: rows[i].ratio,
              tint: tints[i % tints.length],
              note: rows[i].isEndless
                  // 끝이 없는 난이도는 분모가 없다. 100%가 될 수 없는 막대에
                  // 비율을 적으면 영영 안 채워지는 것처럼 보인다.
                  ? '${rows[i].range} · 끝이 없습니다'
                  : rows[i].range,
            ),
        ],
      ),
    );
  }

  Widget _tools(BuildContext context) {
    final rows = <(String, int, Color, String)>[
      ('힌트', stats.hintCount, _amber, '얼마든지 쓰셔도 됩니다'),
      ('되돌리기', stats.undoCount, _blue, '무를 수 있는 게 이 게임의 규칙입니다'),
      ('다시 시작', stats.restartCount, _teal, '같은 판이 그대로 다시 나옵니다'),
      ('건너뛰기', stats.skipCount, _purple, '넘어가도 벌칙은 없습니다'),
    ];
    // 가장 많이 쓴 것을 가득 찬 막대로 두고 나머지를 견준다.
    // 절대 기준이 없는 값이라, 서로 견주는 것 말고는 그릴 방법이 없다.
    final peak = rows.fold(0, (m, r) => r.$2 > m ? r.$2 : m);

    return StatCard(
      title: '편의 기능을 얼마나 쓰셨나',
      child: Column(
        children: [
          for (final (label, count, tint, note) in rows)
            StatBar(
              label: label,
              value: '$count번',
              ratio: peak == 0 ? 0 : count / peak,
              tint: tint,
              note: note,
            ),
        ],
      ),
    );
  }

  Widget _activity(BuildContext context, DateTime now) {
    final days = StatsSummary.recentActivity(stats.playedDays, now);
    final scheme = Theme.of(context).colorScheme;
    final playedInFortnight = days.where((d) => d).length;

    return StatCard(
      title: '최근 2주',
      trailing: Text(
        '$playedInFortnight일',
        style: Theme.of(context).textTheme.labelMedium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var i = 0; i < days.length; i++) ...[
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: days[i]
                            ? _teal.withValues(alpha: 0.85)
                            : scheme.surfaceContainerHighest,
                        border: i == days.length - 1
                            ? Border.all(color: _teal, width: 2)
                            : null,
                      ),
                    ),
                  ),
                ),
                if (i != days.length - 1) const SizedBox(width: 4),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('2주 전', style: Theme.of(context).textTheme.labelSmall),
              Text('오늘', style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ],
      ),
    );
  }

  /// 마지막에 얻은 도전과제 몇 개.
  ///
  /// 날짜를 모르는 것은 뒤로 보낸다. 예전 저장에는 날짜가 없을 수 있다.
  Widget _recentAchievements(BuildContext context) {
    final earned = Achievements.earnedIn(stats);
    if (earned.isEmpty) {
      return StatCard(
        title: '최근 도전과제',
        child: Text(
          '아직 없습니다. 한 판만 끝내도 첫 도전과제가 열립니다.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    final sorted = [...earned]..sort((a, b) {
        final da = earnedOn[a.id] ?? '';
        final db = earnedOn[b.id] ?? '';
        return db.compareTo(da);
      });

    return StatCard(
      title: '최근 도전과제',
      trailing: Text(
        '${earned.length}개 달성',
        style: Theme.of(context).textTheme.labelMedium,
      ),
      child: Column(
        children: [
          for (final a in sorted.take(3)) ...[
            AchievementTile(achievement: a, stats: stats, earnedOn: earnedOn[a.id]),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}
