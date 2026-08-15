import 'package:bottlebottle/logic/achievements.dart';
import 'package:flutter_test/flutter_test.dart';

/// 시험용 클리어 기록 하나. 필요한 값만 바꿔 쓴다.
ClearRecord clear({
  int level = 1,
  int moves = 20,
  int hintsUsed = 0,
  int undosUsed = 0,
  int peakEmptiesUsed = 1,
  int emptyBudget = 2,
  int capacity = 4,
  int colorCount = 4,
}) =>
    ClearRecord(
      level: level,
      moves: moves,
      hintsUsed: hintsUsed,
      undosUsed: undosUsed,
      peakEmptiesUsed: peakEmptiesUsed,
      emptyBudget: emptyBudget,
      capacity: capacity,
      colorCount: colorCount,
    );

void main() {
  group('기록 쌓기', () {
    test('빈 기록에서는 어떤 도전과제도 얻지 않았다', () {
      expect(Achievements.earnedIn(const PlayStats()), isEmpty);
    });

    test('한 판을 끝내면 첫 완성이 열린다', () {
      final after = const PlayStats().afterClear(clear(), firstTime: true);
      expect(Achievements.earnedIds(after), contains('first_clear'));
    });

    test('같은 레벨을 다시 풀면 총 클리어 수만 늘고 서로 다른 레벨 수는 그대로다', () {
      var s = const PlayStats().afterClear(clear(level: 3), firstTime: true);
      s = s.afterClear(clear(level: 3), firstTime: false);

      expect(s.clearedCount, 2);
      expect(s.distinctLevelsCleared, 1);
    });

    test('힌트와 되돌리기를 안 쓴 판만 스스로 푼 판으로 센다', () {
      var s = const PlayStats().afterClear(clear(), firstTime: true);
      expect(s.flawlessClears, 1);

      s = s.afterClear(clear(hintsUsed: 1), firstTime: true);
      expect(s.noHintClears, 1, reason: '힌트를 쓴 판은 세지 않는다.');
      expect(s.flawlessClears, 1);

      s = s.afterClear(clear(undosUsed: 2), firstTime: true);
      expect(s.noUndoClears, 2);
      expect(s.flawlessClears, 1);
    });

    test('빈 병을 아낀 판과 하나도 안 쓴 판을 구분해 센다', () {
      var s = const PlayStats()
          .afterClear(clear(peakEmptiesUsed: 0), firstTime: true);
      expect(s.zeroEmptyClears, 1);
      expect(s.thriftyClears, 1, reason: '0개는 배정보다 적게 쓴 것이기도 하다.');

      s = s.afterClear(clear(peakEmptiesUsed: 2, emptyBudget: 2), firstTime: true);
      expect(s.zeroEmptyClears, 1);
      expect(s.thriftyClears, 1, reason: '다 쓴 판은 아낀 것이 아니다.');
    });

    test('가장 깊은 병과 가장 많은 색은 최고 기록으로 남는다', () {
      var s = const PlayStats()
          .afterClear(clear(capacity: 8, colorCount: 15), firstTime: true);
      s = s.afterClear(clear(capacity: 4, colorCount: 4), firstTime: true);

      expect(s.deepestCleared, 8, reason: '쉬운 판을 풀었다고 기록이 내려가면 안 된다.');
      expect(s.mostColorsCleared, 15);
    });

    test('최고 레벨은 뒤로 가지 않는다', () {
      final s = const PlayStats().afterReach(70).afterReach(10);
      expect(s.maxLevel, 70);
    });

    test('같은 날 여러 번 해도 하루로 센다', () {
      final s = const PlayStats()
          .afterPlayOn('2026-08-15')
          .afterPlayOn('2026-08-15')
          .afterPlayOn('2026-08-16');
      expect(s.daysPlayed, 2);
    });
  });

  group('도전과제 판정', () {
    test('새로 얻은 것만 골라낸다', () {
      final before = const PlayStats();
      final after = before.afterClear(clear(), firstTime: true);

      final fresh = Achievements.newlyEarned(before, after);
      final ids = [for (final a in fresh) a.id];

      expect(ids, contains('first_clear'));
      expect(ids, contains('no_hint_1'));
      expect(ids, contains('flawless_1'));
      // 이미 얻은 것을 두 번 알리면 안 된다.
      expect(Achievements.newlyEarned(after, after), isEmpty);
    });

    test('진행도는 목표를 넘지 않는다', () {
      final s = const PlayStats().copyWith(clearedCount: 999);
      final a = Achievements.byId('clear_10');

      expect(a.progress(s), 10);
      expect(a.ratio(s), 1.0);
      expect(a.isEarnedBy(s), isTrue);
    });

    test('아직 못 얻은 도전과제도 진행도를 보여준다', () {
      final s = const PlayStats().copyWith(clearedCount: 5);
      final a = Achievements.byId('clear_10');

      expect(a.isEarnedBy(s), isFalse);
      expect(a.progress(s), 5);
      expect(a.ratio(s), 0.5);
    });

    test('도전과제 id가 겹치지 않는다', () {
      final ids = {for (final a in Achievements.all) a.id};
      expect(ids.length, Achievements.all.length);
    });

    test('모든 도전과제가 어느 묶음엔가 정확히 한 번 들어간다', () {
      final grouped = Achievements.byGroup();
      final total = grouped.values.fold(0, (n, list) => n + list.length);
      expect(total, Achievements.all.length);
    });

    test('목표가 0인 도전과제는 없다', () {
      // 목표가 0이면 시작하자마자 얻은 것이 되어, 축하가 의미를 잃는다.
      for (final a in Achievements.all) {
        expect(a.target, greaterThan(0), reason: '${a.id}의 목표가 0이다.');
      }
    });
  });

  group('저장과 복원', () {
    test('기록을 저장했다 불러오면 그대로다', () {
      final s = const PlayStats()
          .afterClear(clear(capacity: 6, colorCount: 12), firstTime: true)
          .afterHint()
          .afterUndo()
          .afterSkip()
          .afterMove()
          .afterPlayOn('2026-08-15');

      final back = PlayStats.fromJson(s.toJson());

      expect(back.toJson(), s.toJson());
      expect(Achievements.earnedIds(back), Achievements.earnedIds(s));
    });

    test('저장이 깨져 있어도 읽히는 만큼만 읽고 죽지 않는다', () {
      final back = PlayStats.fromJson({'cleared': '엉망', 'days': 3});

      expect(back.clearedCount, 0);
      expect(back.daysPlayed, 0);
      expect(back.maxLevel, 1);
    });
  });
}
