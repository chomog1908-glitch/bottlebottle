import 'package:bottlebottle/logic/level_config.dart';
import 'package:bottlebottle/logic/level_groups.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('중분류 — 병 개수와 층수가 같은 구간', () {
    test('한 묶음 안에서는 병 개수와 층수가 변하지 않는다', () {
      for (final band in LevelGroups.bands(1)) {
        for (final g in band.groups) {
          for (final lv in g.levels) {
            final c = LevelConfig.forLevel(lv);
            expect(c.bottleCount, g.bottleCount, reason: '$g 레벨 $lv: 병 개수가 다릅니다.');
            expect(c.capacity, g.capacity, reason: '$g 레벨 $lv: 층수가 다릅니다.');
            expect(c.emptyBottles, g.emptyBottles, reason: '$g 레벨 $lv');
          }
        }
      }
    });

    test('묶음 이름이 병 개수와 층수를 그대로 말해 준다', () {
      final g = LevelGroups.groupForLevel(1);
      expect(g.title, '병 ${g.bottleCount}개 · ${g.capacity}층');
    });

    test('한 묶음이 지나치게 길지 않다', () {
      // 레벨 격자가 한 화면을 훌쩍 넘으면 고르기 불편하다.
      for (final band in LevelGroups.bands(1000)) {
        for (final g in band.groups) {
          expect(g.levelCount, lessThanOrEqualTo(LevelGroups.endlessBlock),
              reason: '$g가 너무 깁니다.');
        }
      }
    });
  });

  group('대분류 — 난이도', () {
    test('레벨 1부터 빈틈없이 이어진다', () {
      final bands = LevelGroups.bands(1);
      expect(bands.first.firstLevel, 1);
      for (var i = 1; i < bands.length; i++) {
        expect(bands[i].firstLevel, bands[i - 1].lastLevel + 1,
            reason: '${bands[i]} 앞에 빈틈이 있습니다.');
      }
    });

    test('중분류도 빈틈없이 이어진다', () {
      final groups = [for (final b in LevelGroups.bands(1)) ...b.groups];
      expect(groups.first.firstLevel, 1);
      for (var i = 1; i < groups.length; i++) {
        expect(groups[i].firstLevel, groups[i - 1].lastLevel + 1,
            reason: '${groups[i]} 앞에 빈틈이 있습니다.');
      }
    });

    test('한 난이도 안의 레벨은 모두 같은 난이도 이름을 가진다', () {
      for (final band in LevelGroups.bands(1)) {
        for (final lv in band.levels) {
          expect(LevelConfig.forLevel(lv).difficultyLabel, band.name,
              reason: '$band 레벨 $lv');
        }
      }
    });

    test('난이도 이름이 중복되지 않는다', () {
      final names = LevelGroups.bands(1).map((b) => b.name).toList();
      expect(names.toSet().length, names.length, reason: '같은 이름의 난이도가 둘 있습니다.');
    });

    test('모든 레벨이 정확히 한 난이도와 한 묶음에 속한다', () {
      for (var lv = 1; lv <= 650; lv++) {
        expect(LevelGroups.bandForLevel(lv).contains(lv), isTrue, reason: '레벨 $lv');
        expect(LevelGroups.groupForLevel(lv).contains(lv), isTrue, reason: '레벨 $lv');
      }
    });
  });

  group('무한 레벨', () {
    test('멀리 간 사람에게는 목록이 더 길게 펼쳐진다', () {
      final near = LevelGroups.bands(1).last.lastLevel;
      final far = LevelGroups.bands(2000).last.lastLevel;
      expect(far, greaterThan(near));
      expect(far, greaterThanOrEqualTo(2000));
    });

    test('아직 안 간 곳도 미리 보여준다', () {
      // 레벨 1인 사람에게도 최고 난이도 폴더가 보여야 한다. 잠그지 않기 때문이다.
      final bands = LevelGroups.bands(1);
      expect(bands.last.lastLevel, greaterThanOrEqualTo(700));
      expect(bands.map((b) => b.name), contains('최고 난이도'));
    });
  });

  test('레벨 0 이하는 거부한다', () {
    expect(() => LevelGroups.groupForLevel(0), throwsArgumentError);
    expect(() => LevelGroups.bandForLevel(0), throwsArgumentError);
  });
}
