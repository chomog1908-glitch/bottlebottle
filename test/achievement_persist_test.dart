import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bottlebottle/logic/achievements.dart';
import 'package:bottlebottle/services/achievement_tracker.dart';
import 'package:bottlebottle/services/storage.dart';

/// 한 번 드린 도전과제는 도로 가져가지 않는다.
///
/// 도전과제는 기록에서 계산해 켠다. 계산만으로 판단하면, 나중에 목표를 손대는
/// 순간(예: "50판"을 "60판"으로) **이미 드린 것이 조용히 취소된다.**
/// 어머니가 427판을 푸시며 모으신 것을 내 사정으로 없애는 셈이다.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('목표가 올라가도 이미 얻은 것은 그대로 남는다', () {
    // "50판 클리어"를 딴 상태. 그런데 지금 기록은 40판뿐이라고 하자.
    // (목표를 60판으로 올렸거나, 세는 방식을 바꿨거나 — 어느 쪽이든 같은 일이다.)
    const stats = PlayStats(clearedCount: 40);
    final target = Achievements.all.firstWhere((a) => a.id == 'clear_50');

    // 계산만으로는 꺼진다.
    expect(target.isEarnedBy(stats), isFalse);

    // 하지만 얻어 둔 것으로 치면 켜져 있어야 한다.
    expect(Achievements.isEarned(target, stats, {'clear_50'}), isTrue);
    expect(Achievements.earnedIds(stats, {'clear_50'}), contains('clear_50'));
  });

  test('얻지 않은 것이 저절로 켜지지는 않는다', () {
    const stats = PlayStats(clearedCount: 3);
    final far = Achievements.all.firstWhere((a) => a.id == 'clear_150');
    expect(Achievements.isEarned(far, stats, {'clear_50'}), isFalse);
  });

  test('축하는 두 번 띄우지 않는다', () {
    const before = PlayStats(clearedCount: 49);
    const after = PlayStats(clearedCount: 50);

    // 처음 넘을 때는 새로 얻은 것으로 잡힌다.
    expect([for (final a in Achievements.newlyEarned(before, after)) a.id],
        contains('clear_50'));

    // 이미 얻어 둔 것이면 다시 잡히지 않는다.
    final again = Achievements.newlyEarned(before, after, {'clear_50'});
    expect([for (final a in again) a.id], isNot(contains('clear_50')));
  });

  test('날짜가 적힌 것은 불러올 때 얻은 것으로 살아난다', () async {
    final storage = Storage();
    await storage.recordAchievements(['clear_50'], '2026-08-15');
    // 기록은 그 목표에 못 미친다.
    await storage.saveStats(const PlayStats(clearedCount: 40));

    final tracker = AchievementTracker(storage);
    await tracker.load();

    expect(tracker.earnedIds, contains('clear_50'));
    expect(tracker.earnedCount, greaterThan(0));
    expect(tracker.earnedOn['clear_50'], '2026-08-15',
        reason: '이미 적힌 날짜를 덮어썼다');
  });

  test('예전 저장에서 날짜가 빠진 것은 불러올 때 채워진다', () async {
    // 계산으로만 켜지던 시절의 저장에는 날짜가 없다. 지금 적어 두어야
    // 나중에 목표를 손대도 남는다.
    final storage = Storage();
    await storage.saveStats(const PlayStats(clearedCount: 427, distinctLevelsCleared: 427));

    final tracker = AchievementTracker(storage);
    tracker.now = () => DateTime(2026, 9, 8);
    await tracker.load();

    expect(tracker.earnedIds, contains('clear_50'));
    // 저장소에도 남아야 다음에 켤 때 살아난다.
    final saved = await storage.loadAchievementDates();
    expect(saved.containsKey('clear_50'), isTrue,
        reason: '날짜를 저장하지 않아 다음에 켜면 또 계산에 의존한다');
  });

  test('어머니 기록 24개가 목표를 손대도 살아남는다', () async {
    final storage = Storage();
    const ids = [
      'first_clear', 'no_hint_1', 'flawless_1', 'thrifty_1', 'clear_10',
      'no_undo_10', 'flawless_25', 'no_hint_30', 'reach_50', 'clear_50',
      'moves_1000', 'days_3', 'colors_12', 'depth_5', 'distinct_100',
      'clear_150', 'thrifty_20', 'reach_200', 'depth_6', 'colors_15',
      'days_10', 'depth_7', 'moves_10000', 'depth_8',
    ];
    await storage.recordAchievements(ids, '2026-08-15');
    // 기록이 통째로 비어 있어도(최악의 경우) 얻은 것은 남아야 한다.
    final earned = Achievements.earnedIds(const PlayStats(), ids.toSet());
    expect(earned.length, ids.length);
  });
}
