import 'package:flutter/material.dart';

import '../../logic/achievements.dart';
import '../widgets/achievement_tile.dart';
import '../widgets/stat_widgets.dart';

/// 도전과제 대시보드.
///
/// **자랑용일 뿐이다.** 여기서 얻는 것으로 레벨이 열리거나 힌트가 생기지 않는다.
/// 지나온 길을 돌아보는 화면이지, 다음에 할 일을 시키는 화면이 아니다.
class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({
    super.key,
    required this.stats,
    this.earnedOn = const {},
  });

  final PlayStats stats;

  /// `도전과제 id → 얻은 날짜`.
  final Map<String, String> earnedOn;

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  /// 지금 보고 있는 묶음. null이면 전부.
  AchievementGroup? _filter;

  /// 얻은 것을 숨기고 남은 것만 볼지.
  bool _onlyRemaining = false;

  PlayStats get _stats => widget.stats;

  @override
  Widget build(BuildContext context) {
    final all = Achievements.all;
    final earned = Achievements.earnedIn(_stats);

    final shown = [
      for (final a in all)
        if ((_filter == null || a.group == _filter) &&
            !(_onlyRemaining && a.isEarnedBy(_stats)))
          a,
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('도전과제')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _hero(context, earned.length, all.length),
            const SizedBox(height: 16),
            _tierBreakdown(context),
            const SizedBox(height: 16),
            if (earned.length < all.length) ...[
              _almostThere(context),
              const SizedBox(height: 16),
            ],
            _groupProgress(context),
            const SizedBox(height: 16),
            _filters(context),
            const SizedBox(height: 12),
            if (shown.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    '이 묶음은 전부 모으셨습니다.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              )
            else
              for (final a in shown) ...[
                AchievementTile(
                  achievement: a,
                  stats: _stats,
                  earnedOn: widget.earnedOn[a.id],
                ),
                const SizedBox(height: 10),
              ],
          ],
        ),
      ),
    );
  }

  /// 맨 위의 큰 고리. 이 화면에서 가장 먼저 눈에 들어와야 하는 숫자다.
  Widget _hero(BuildContext context, int earned, int total) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primaryContainer, scheme.tertiaryContainer],
        ),
      ),
      child: Row(
        children: [
          StatRing(
            ratio: total == 0 ? 0 : earned / total,
            center: '$earned',
            label: '/ $total 개',
            tint: scheme.primary,
            size: 116,
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  earned == 0
                      ? '아직 시작 전'
                      : earned == total
                          ? '전부 모으셨습니다'
                          : '$earned개 달성',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: scheme.onPrimaryContainer,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  // 남은 개수를 재촉하지 않는다. 이미 한 것만 말한다.
                  earned == 0
                      ? '한 판만 끝내도 첫 도전과제가 열립니다.'
                      : earned == total
                          ? '더 드릴 게 없네요.'
                          : '천천히 하셔도 됩니다. 사라지는 건 없습니다.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onPrimaryContainer,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 급별로 몇 개씩 모았는지. 무지개 하나가 동메달 다섯보다 무겁다.
  Widget _tierBreakdown(BuildContext context) {
    const names = {
      AchievementTier.bronze: '동',
      AchievementTier.silver: '은',
      AchievementTier.gold: '금',
      AchievementTier.rainbow: '무지개',
    };

    return StatCard(
      title: '급별',
      child: Row(
        children: [
          for (final tier in AchievementTier.values) ...[
            Expanded(child: _tierChip(context, tier, names[tier]!)),
            if (tier != AchievementTier.values.last) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _tierChip(BuildContext context, AchievementTier tier, String name) {
    final items = [for (final a in Achievements.all) if (a.tier == tier) a];
    final done = items.where((a) => a.isEarnedBy(_stats)).length;
    final tint = achievementTierColor(tier);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: tint.withValues(alpha: done == 0 ? 0.07 : 0.16),
        border: Border.all(
          color: tint.withValues(alpha: done == 0 ? 0.25 : 0.7),
        ),
      ),
      child: Column(
        children: [
          Text(
            '$done',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold, color: tint),
          ),
          Text('$name · ${items.length}',
              style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }

  /// 가장 가까이 온 것 세 개.
  ///
  /// 아직 손도 안 댄 것(진행도 0)은 넣지 않는다. 그건 목표가 아니라 목록일 뿐이라,
  /// 여기 올리면 "해야 할 일"처럼 보인다.
  Widget _almostThere(BuildContext context) {
    final close = [
      for (final a in Achievements.all)
        if (!a.isEarnedBy(_stats) && a.progress(_stats) > 0) a,
    ]..sort((a, b) => b.ratio(_stats).compareTo(a.ratio(_stats)));

    if (close.isEmpty) return const SizedBox.shrink();

    return StatCard(
      title: '거의 다 왔습니다',
      child: Column(
        children: [
          for (final a in close.take(3))
            StatBar(
              label: '${a.emoji}  ${a.name}',
              value: '${a.progress(_stats)} / ${a.target}',
              ratio: a.ratio(_stats),
              tint: achievementTierColor(a.tier),
              note: a.description,
            ),
        ],
      ),
    );
  }

  Widget _groupProgress(BuildContext context) {
    final groups = Achievements.byGroup();
    const tints = [
      Color(0xFF1E88E5),
      Color(0xFF00897B),
      Color(0xFFF9A825),
      Color(0xFF43A047),
      Color(0xFF8E24AA),
    ];

    return StatCard(
      title: '묶음별 진행',
      child: Column(
        children: [
          for (var i = 0; i < AchievementGroup.values.length; i++)
            _groupRow(
              context,
              AchievementGroup.values[i],
              groups[AchievementGroup.values[i]]!,
              tints[i % tints.length],
            ),
        ],
      ),
    );
  }

  Widget _groupRow(
    BuildContext context,
    AchievementGroup group,
    List<Achievement> items,
    Color tint,
  ) {
    final done = items.where((a) => a.isEarnedBy(_stats)).length;
    // 막대를 누르면 그 묶음만 본다. 목록이 29개라 훑기만 해서는 길다.
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => setState(
        () => _filter = _filter == group ? null : group,
      ),
      child: StatBar(
        label: group.label,
        value: '$done / ${items.length}',
        ratio: items.isEmpty ? 0 : done / items.length,
        tint: tint,
        note: _filter == group ? '이 묶음만 보는 중 · 다시 누르면 전체' : null,
      ),
    );
  }

  Widget _filters(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          label: const Text('전체'),
          selected: _filter == null,
          onSelected: (_) => setState(() => _filter = null),
        ),
        for (final g in AchievementGroup.values)
          ChoiceChip(
            label: Text(g.label),
            selected: _filter == g,
            onSelected: (_) => setState(() => _filter = g),
          ),
        FilterChip(
          label: const Text('남은 것만'),
          selected: _onlyRemaining,
          onSelected: (v) => setState(() => _onlyRemaining = v),
        ),
      ],
    );
  }
}
