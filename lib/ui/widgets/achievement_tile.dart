import 'package:flutter/material.dart';

import '../../logic/achievements.dart';

/// 도전과제 급마다 다른 색. 한눈에 무게가 다르다는 걸 알 수 있게.
Color achievementTierColor(AchievementTier tier) => switch (tier) {
      AchievementTier.bronze => const Color(0xFFB07A4B),
      AchievementTier.silver => const Color(0xFF7E93A6),
      AchievementTier.gold => const Color(0xFFD9A404),
      AchievementTier.rainbow => const Color(0xFF9C4DCC),
    };

/// 최고 급만 무지개 띠를 두른다. 나머지는 단색이다.
///
/// 전부 화려하게 하면 무엇이 더 어려운 것인지 구분이 사라진다.
LinearGradient achievementTierGradient(AchievementTier tier) =>
    tier == AchievementTier.rainbow
        ? const LinearGradient(
            colors: [
              Color(0xFFE53935),
              Color(0xFFFB8C00),
              Color(0xFFFDD835),
              Color(0xFF43A047),
              Color(0xFF1E88E5),
              Color(0xFF8E24AA),
            ],
          )
        : LinearGradient(
            colors: [
              achievementTierColor(tier),
              achievementTierColor(tier).withValues(alpha: 0.55),
            ],
          );

/// 도전과제 하나를 보여주는 칸.
///
/// **못 얻은 것도 숨기지 않는다.** 무엇을 하면 되는지 적어 두고, 얼마나 왔는지도 보여준다.
/// 가려 두면 궁금증이 아니라 답답함이 된다.
class AchievementTile extends StatelessWidget {
  const AchievementTile({
    super.key,
    required this.achievement,
    required this.stats,
    this.earnedOn,
  });

  final Achievement achievement;
  final PlayStats stats;

  /// 얻은 날짜(`YYYY-MM-DD`). 모르면 null.
  final String? earnedOn;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final earned = achievement.isEarnedBy(stats);
    final tint = achievementTierColor(achievement.tier);
    final progress = achievement.progress(stats);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: earned
            ? Color.alphaBlend(tint.withValues(alpha: 0.14), scheme.surface)
            : scheme.surfaceContainerLow,
        border: Border.all(
          color: earned ? tint : scheme.outlineVariant,
          width: earned ? 2 : 1,
        ),
        // 얻은 것만 은은하게 떠 보이게 한다.
        boxShadow: earned
            ? [
                BoxShadow(
                  color: tint.withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _medal(earned, tint),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        achievement.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: earned ? null : scheme.onSurfaceVariant,
                            ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (earned) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.verified, size: 18, color: tint),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  // 얻은 뒤에는 할 일이 아니라 칭찬을 보여준다.
                  earned ? achievement.praise : achievement.description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 8),
                if (earned)
                  Text(
                    earnedOn == null ? '완료' : '$earnedOn 달성',
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: tint, fontWeight: FontWeight.bold),
                  )
                else
                  _progressBar(context, progress, scheme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 얻기 전에는 그림이 흐릿하다. 색이 아니라 **선명함**으로 구분한다.
  /// 회색으로만 칠하면 무엇이었는지조차 안 보인다.
  Widget _medal(bool earned, Color tint) => Container(
        width: 52,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: earned ? achievementTierGradient(achievement.tier) : null,
          color: earned ? null : tint.withValues(alpha: 0.10),
        ),
        child: Opacity(
          opacity: earned ? 1 : 0.45,
          child: Text(achievement.emoji, style: const TextStyle(fontSize: 26)),
        ),
      );

  Widget _progressBar(BuildContext context, int progress, ColorScheme scheme) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: achievement.ratio(stats),
              minHeight: 6,
              backgroundColor: scheme.surfaceContainerHighest,
              color: achievementTierColor(achievement.tier),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$progress / ${achievement.target}',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      );
}
