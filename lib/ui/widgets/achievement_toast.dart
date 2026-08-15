import 'dart:async';

import 'package:flutter/material.dart';

import '../../logic/achievements.dart';
import 'achievement_tile.dart';

/// 새로 얻은 도전과제를 화면 위쪽에 잠깐 띄운다.
///
/// 눌러서 닫을 필요가 없고, 게임을 가리지도 않는다.
/// 판을 막 끝낸 참이라 화면 아래쪽은 완성 배너가 쓰고 있으므로 **위**로 띄운다.
Future<void> showAchievementToasts(
  BuildContext context,
  List<Achievement> achievements,
) async {
  for (final a in achievements) {
    if (!context.mounted) return;
    await _showOne(context, a);
  }
}

Future<void> _showOne(BuildContext context, Achievement achievement) {
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return Future.value();

  final done = Completer<void>();
  late OverlayEntry entry;
  var removed = false;

  // 두 번 불려도 안전해야 한다. 토스트가 스스로 끝날 때도,
  // 화면이 먼저 사라져 버릴 때도 같은 함수가 불리기 때문이다.
  // 여기서 완료를 보장하지 않으면 기다리던 쪽이 영영 깨어나지 못한다.
  void finish() {
    if (!removed) {
      removed = true;
      entry.remove();
    }
    if (!done.isCompleted) done.complete();
  }

  entry = OverlayEntry(
    builder: (_) => _AchievementToast(
      achievement: achievement,
      onFinished: finish,
    ),
  );
  overlay.insert(entry);
  return done.future;
}

class _AchievementToast extends StatefulWidget {
  const _AchievementToast({required this.achievement, required this.onFinished});

  final Achievement achievement;
  final VoidCallback onFinished;

  @override
  State<_AchievementToast> createState() => _AchievementToastState();
}

class _AchievementToastState extends State<_AchievementToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void initState() {
    super.initState();
    _play();
  }

  /// 들어왔다가, 읽을 시간을 두고, 나간다.
  ///
  /// 한 번 재생하고 끝난다. 끝나지 않는 애니메이션을 쓰면 위젯 테스트의
  /// `pumpAndSettle`이 영영 끝나지 않는다.
  Future<void> _play() async {
    await _c.forward();
    await Future<void>.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;
    await _c.reverse();
    if (mounted) widget.onFinished();
  }

  @override
  void dispose() {
    // 화면이 먼저 사라져 재생을 끝맺지 못한 경우에도 끝났다고 알려야 한다.
    // 안 그러면 축하를 기다리던 쪽이 영영 멈춰 서고, 다음 도전과제도 안 뜬다.
    widget.onFinished();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = achievementTierColor(widget.achievement.tier);
    final curve = CurvedAnimation(parent: _c, curve: Curves.easeOutBack);

    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      left: 16,
      right: 16,
      child: IgnorePointer(
        child: FadeTransition(
          opacity: _c,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, -0.6),
              end: Offset.zero,
            ).animate(curve),
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: Color.alphaBlend(
                    tint.withValues(alpha: 0.16),
                    scheme.surfaceContainerHigh,
                  ),
                  border: Border.all(color: tint, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: tint.withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient:
                            achievementTierGradient(widget.achievement.tier),
                      ),
                      child: Text(
                        widget.achievement.emoji,
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '도전과제 달성',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: tint, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            widget.achievement.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            widget.achievement.praise,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
