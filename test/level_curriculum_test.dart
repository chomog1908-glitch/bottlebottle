import 'package:flutter_test/flutter_test.dart';

import 'package:bottlebottle/logic/generator.dart';
import 'package:bottlebottle/logic/level_config.dart';
import 'package:bottlebottle/logic/level_groups.dart';
import 'package:bottlebottle/logic/solver.dart';
import 'package:bottlebottle/model/rule_set.dart';

/// 난이도표가 701~2800을 실제로 담는가.
///
/// 표를 적어두는 것과 그 표대로 판이 만들어지는 것은 다른 일이다.
/// 실제로 레벨 1001~1150 구간은 표를 적은 뒤 전부 생성에 실패했다.
/// 그래서 표를 고칠 때마다 이 시험이 돌아야 한다.
void main() {
  group('난이도표는 2800까지 빈틈이 없다', () {
    test('모든 구간 경계에서 설정이 나온다', () {
      for (var lv = 701; lv <= 2900; lv++) {
        expect(() => LevelConfig.forLevel(lv), returnsNormally,
            reason: '레벨 $lv의 설정이 없다');
      }
    });

    test('700까지는 규칙이 붙지 않는다 — 이미 나간 레벨은 그대로다', () {
      for (final lv in [1, 100, 432, 500, 650, 700]) {
        expect(LevelConfig.forLevel(lv).rules, RuleSet.classic,
            reason: '레벨 $lv에 규칙이 붙었다');
      }
    });

    test('701부터는 반드시 규칙이 붙는다', () {
      for (final lv in [701, 900, 1200, 1500, 1800, 2100, 2500, 2800]) {
        expect(LevelConfig.forLevel(lv).rules, isNot(RuleSet.classic),
            reason: '레벨 $lv에 규칙이 없다');
      }
    });
  });

  group('구간마다 판이 실제로 만들어지고 풀린다', () {
    // 구간 경계 바로 안쪽을 고른다. 경계가 깨지면 여기서 잡힌다.
    for (final lv in [701, 850, 851, 1000, 1001, 1150, 1151, 1300, 1301,
                      1500, 1601, 1900, 1901, 2200, 2201, 2600, 2601]) {
      test('레벨 $lv', () {
        final g = LevelGenerator.generate(lv);
        expect(g.state.isSolved, isFalse);
        expect(g.state.emptyBottleCount(), g.config.emptyBottles);
        expect(g.state.rules, g.config.rules);

        // 생성기를 믿지 않고 규칙을 그대로 들고 다시 푼다.
        expect(Solver.solve(g.state).solved, isTrue,
            reason: '레벨 $lv이 그 규칙 아래에서 풀리지 않는다');
      }, timeout: const Timeout(Duration(seconds: 60)));
    }
  });

  test('규칙 구간도 한 판 만드는 데 오래 걸리지 않는다', () {
    // 레벨을 넘길 때마다 몇 초씩 멈추면 게임이 못 쓰게 된다.
    //
    // 이건 실제로 걸렸다. ±2 구간을 색14 깊이7로 두었더니 한 판에 최대 3.8초가
    // 걸렸고, 10판 중 2판은 아예 안 만들어졌다. 규칙이 조여들 때 판을 한 단계
    // 낮추면(색13 깊이6) 평균 0.19초로 떨어진다.
    for (final lv in [750, 900, 1050, 1200, 1450, 1750, 2050, 2500]) {
      final sw = Stopwatch()..start();
      LevelGenerator.generate(lv);
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(2000),
          reason: '레벨 $lv 생성에 ${sw.elapsedMilliseconds}ms 걸렸습니다.');
    }
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('규칙 구간의 판은 충분히 헝클어져 있다', () {
    // 규칙만 어렵고 판은 싱거우면 규칙이 장식이 된다.
    // (실제로 ±3을 색15 깊이8에 그대로 걸었더니 8판 중 2판이 기준 미달이었다.)
    for (final lv in [800, 950, 1100, 1250, 1450, 1750, 2050, 2350]) {
      final g = LevelGenerator.generate(lv);
      final c = g.config;
      final floor = (c.totalUnits * (c.emptyBottles >= 2 ? 0.45 : 0.38)).round();
      expect(g.state.segmentCount(), greaterThanOrEqualTo(floor),
          reason: '레벨 $lv이 싱겁다 (${c.rules})');
    }
  }, timeout: const Timeout(Duration(seconds: 120)));
  group('레벨 목록이 새 레벨을 감춘다면 없는 것과 같다', () {
    // 실제로 겪었다. 레벨 431에서 목록을 열었더니 700까지밖에 보이지 않아,
    // 새로 만든 2100레벨이 통째로 숨어 있었다.
    test('레벨 1에서도 끝까지 보인다', () {
      final bands = LevelGroups.bands(1);
      expect(bands.last.lastLevel, greaterThanOrEqualTo(LevelConfig.lastLevel),
          reason: '목록이 중간에서 끊긴다');
    });

    test('규칙 구간의 난이도 이름이 모두 목록에 나온다', () {
      final names = LevelGroups.bands(1).map((b) => b.name).toSet();
      for (final n in ['이웃 제한', '전용 병', '굳는 병', '못 비우는 병', '모든 규칙']) {
        expect(names, contains(n), reason: '$n 구간이 목록에 없다');
      }
    });

    test('묶음이 빈틈없이 이어진다', () {
      var expected = 1;
      for (final b in LevelGroups.bands(1)) {
        for (final g in b.groups) {
          expect(g.firstLevel, expected, reason: '레벨 $expected 앞뒤가 어긋난다');
          expected = g.lastLevel + 1;
        }
      }
      expect(expected - 1, greaterThanOrEqualTo(LevelConfig.lastLevel));
    });

    test('끝에 다다라도 길이 막히지 않는다', () {
      // 마지막 구간은 계속 이어진다. 2800을 넘겨도 목록이 나와야 한다.
      final bands = LevelGroups.bands(LevelConfig.lastLevel + 100);
      expect(bands.last.lastLevel,
          greaterThan(LevelConfig.lastLevel));
      expect(() => LevelGroups.groupForLevel(LevelConfig.lastLevel + 50),
          returnsNormally);
    });

    test('목록을 만드는 데 오래 걸리지 않는다', () {
      // 2800레벨을 통째로 펼치므로 느려지면 화면이 멈춘다.
      final sw = Stopwatch()..start();
      LevelGroups.bands(431);
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(500));
    });
  });

  test('격자는 병 수를 나누어떨어지게 잡는다', () {
    // 병 16개를 한 줄 5개로 놓으면 마지막 줄에 한 개만 덩그러니 남는다.
    // 규칙은 그 격자로 거리를 재므로, 외톨이 병은 화면에서 보이는 자리와
    // 규칙이 세는 자리가 어긋나 "바로 옆인데 못 붓는" 일이 생긴다.
    // (실제로 레벨 701이 5·5·5·1로 놓여 그렇게 보였다.)
    for (var lv = 701; lv <= 2800; lv += 7) {
      final c = LevelConfig.forLevel(lv);
      if (!c.rules.hasReachLimit) continue;
      expect(c.bottleCount % c.rules.gridPerRow, 0,
          reason: '레벨 $lv: 병 ${c.bottleCount}개를 한 줄 '
              '${c.rules.gridPerRow}개로 놓으면 줄이 어긋난다');
    }
  });

  test('이웃 제한은 실제로 무언가를 막아야 한다', () {
    // 규칙을 적어 놓는 것과 규칙이 실제로 막는 것은 다르다.
    // 병 16개를 4×4로 놓고 ±3을 걸면 어느 병에서든 모든 병에 닿는다.
    // 막히는 짝이 0개 — 규칙이 이름만 있고 아무 일도 하지 않는다.
    // (레벨 701~850과 2201~이 실제로 그랬다.)
    for (var lv = 701; lv <= 2800; lv += 11) {
      final c = LevelConfig.forLevel(lv);
      if (!c.rules.hasReachLimit) continue;
      final n = c.bottleCount;
      var blocked = 0;
      for (var a = 0; a < n; a++) {
        for (var b = 0; b < n; b++) {
          if (a != b && !c.rules.reaches(a, b)) blocked++;
        }
      }
      expect(blocked, greaterThan(0),
          reason: '레벨 $lv: ${c.rules}이라고 적혀 있지만 막히는 짝이 하나도 없다');
    }
  });

  test('이웃 제한은 구간이 갈수록 조여든다', () {
    // 막히는 짝의 비율로 잰다. 뒤 구간이 앞 구간보다 헐거우면 곡선이 뒤집힌다.
    double blockedRatio(int lv) {
      final c = LevelConfig.forLevel(lv);
      final n = c.bottleCount;
      var blocked = 0, total = 0;
      for (var a = 0; a < n; a++) {
        for (var b = 0; b < n; b++) {
          if (a == b) continue;
          total++;
          if (!c.rules.reaches(a, b)) blocked++;
        }
      }
      return blocked / total;
    }

    final bands = [701, 851, 1001, 1151];
    for (var i = 1; i < bands.length; i++) {
      expect(blockedRatio(bands[i]),
          greaterThanOrEqualTo(blockedRatio(bands[i - 1]) - 0.02),
          reason: '레벨 ${bands[i]}이 ${bands[i - 1]}보다 헐겁다');
    }
    // 마지막 이웃 구간은 첫 구간보다 확실히 빡빡해야 한다.
    expect(blockedRatio(1151), greaterThan(blockedRatio(701) + 0.15));
  });

}
