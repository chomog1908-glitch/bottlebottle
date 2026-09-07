import 'package:bottlebottle/logic/generator.dart';
import 'package:bottlebottle/logic/level_config.dart';
import 'package:bottlebottle/logic/solver.dart';
import 'package:bottlebottle/ui/theme/palette.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('난이도 곡선', () {
    test('깊이는 절대 얕아지지 않는다 — 규칙이 붙기 전까지', () {
      // 700까지는 깊이가 유일한 난이도 축이므로 되돌아가면 안 된다.
      //
      // 701부터는 다르다. 새 규칙이 들어올 때 판을 잠시 줄였다가 다시 키운다.
      // 규칙과 크기를 한꺼번에 올리면 절벽이 되기 때문이다. 그래서 이 구간의
      // 깊이는 오르내린다. 그건 고장이 아니라 설계다.
      var prev = 0;
      for (var lv = 1; lv <= 700; lv++) {
        final c = LevelConfig.forLevel(lv);
        expect(c.capacity, greaterThanOrEqualTo(prev), reason: '레벨 $lv에서 병이 얕아졌습니다.');
        prev = c.capacity;
      }
    });

    test('새 규칙이 들어올 때는 판이 작아졌다가 다시 커진다', () {
      // 트릭 A가 시작되는 1301에서 판이 작아지고, 구간 안에서 다시 커져야 한다.
      final before = LevelConfig.forLevel(1300);
      final at = LevelConfig.forLevel(1301);
      final later = LevelConfig.forLevel(1600);
      expect(at.totalUnits, lessThan(before.totalUnits),
          reason: '새 규칙이 들어오는데 판이 줄지 않았다');
      expect(later.totalUnits, greaterThan(at.totalUnits),
          reason: '줄어든 판이 다시 커지지 않았다');
    });

    test('총 칸 수는 전반적으로 늘어난다', () {
      expect(LevelConfig.forLevel(500).totalUnits,
          greaterThan(LevelConfig.forLevel(1).totalUnits));
      expect(LevelConfig.forLevel(200).totalUnits,
          greaterThan(LevelConfig.forLevel(50).totalUnits));
    });

    test('깊이가 늘어나는 구간에서는 색을 잠시 줄여 절벽을 만들지 않는다', () {
      // 깊이가 바뀌는 지점을 찾아, 색이 함께 늘지는 않는지 확인한다.
      for (var lv = 2; lv <= 600; lv++) {
        final prev = LevelConfig.forLevel(lv - 1);
        final now = LevelConfig.forLevel(lv);
        if (now.capacity > prev.capacity) {
          expect(now.colorCount, lessThanOrEqualTo(prev.colorCount),
              reason: '레벨 $lv에서 깊이와 색이 동시에 늘었습니다.');
        }
      }
    });

    test('초반에도 병이 너무 적지 않다', () {
      expect(LevelConfig.forLevel(1).bottleCount, greaterThanOrEqualTo(6));
    });

    test('최대 난이도를 넘어서지 않는다', () {
      for (var lv = 1; lv <= 3000; lv++) {
        final c = LevelConfig.forLevel(lv);
        expect(c.colorCount, lessThanOrEqualTo(LevelConfig.maxColors));
        expect(c.capacity, lessThanOrEqualTo(LevelConfig.maxCapacity));
        expect(c.emptyBottles, greaterThanOrEqualTo(1),
            reason: '빈 병이 하나도 없으면 시작부터 막힐 수 있습니다.');
      }
    });

    test('팔레트가 최대 색 수를 감당한다', () {
      expect(Palette.liquids.length, greaterThanOrEqualTo(LevelConfig.maxColors));
      expect(Palette.symbols.length, greaterThanOrEqualTo(LevelConfig.maxColors));
      expect(Palette.maxColors, LevelConfig.maxColors);
    });

    test('레벨 0 이하는 거부한다', () {
      expect(() => LevelConfig.forLevel(0), throwsArgumentError);
    });
  });

  group('레벨 생성', () {
    test('레벨 번호가 같으면 항상 같은 판이 나온다', () {
      for (final lv in [1, 25, 88, 200, 777]) {
        final a = LevelGenerator.generate(lv);
        final b = LevelGenerator.generate(lv);
        expect(a.state.toString(), b.state.toString(), reason: '레벨 $lv이 재현되지 않습니다.');
      }
    });

    test('색깔 개수가 정확히 맞는다', () {
      for (final lv in [1, 15, 50, 100, 250, 400]) {
        final g = LevelGenerator.generate(lv);
        final counts = <int, int>{};
        for (var i = 0; i < g.state.bottleCount; i++) {
          for (final c in g.state.bottleAt(i)) {
            counts[c] = (counts[c] ?? 0) + 1;
          }
        }
        expect(counts.length, g.config.colorCount);
        for (final entry in counts.entries) {
          expect(entry.value, g.config.capacity,
              reason: '레벨 $lv에서 색 ${entry.key}이 ${entry.value}칸입니다.');
        }
      }
    });

    test('시작부터 완성된 병이 없다', () {
      for (var lv = 1; lv <= 60; lv++) {
        final g = LevelGenerator.generate(lv);
        for (var i = 0; i < g.state.bottleCount; i++) {
          expect(g.state.isComplete(i), isFalse, reason: '레벨 $lv의 병 $i이 이미 완성돼 있습니다.');
        }
      }
    });

    test('약속한 개수만큼 빈 병이 실제로 비어 있다', () {
      // 빈 병 2개짜리 판이라면서 시작부터 하나가 차 있으면 거짓말이다.
      // 화면의 "빈 병 0/2 사용 중" 표시도 시작하자마자 1/2로 떠서 말이 안 맞는다.
      for (final lv in [1, 4, 20, 60, 120, 250, 400, 500, 700]) {
        final g = LevelGenerator.generate(lv);
        expect(g.state.emptyBottleCount(), g.config.emptyBottles,
            reason: '레벨 $lv(${g.config}): 시작 빈 병 수가 약속과 다릅니다: ${g.state}');
      }
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('레벨 1~80 전부 약속한 빈 병 수를 지킨다', () {
      for (var lv = 1; lv <= 80; lv++) {
        final g = LevelGenerator.generate(lv);
        expect(g.state.emptyBottleCount(), g.config.emptyBottles,
            reason: '레벨 $lv: ${g.state}');
      }
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('시작 상태가 이미 풀려 있지 않다', () {
      for (var lv = 1; lv <= 60; lv++) {
        expect(LevelGenerator.generate(lv).state.isSolved, isFalse);
      }
    });

    test('전체 칸 수에 비례해 충분히 헝클어져 있다', () {
      // 깊은 병일수록 더 많이 섞여 있어야 한다. 색 개수만 기준으로 삼으면
      // 깊이 8칸짜리 판이 덜 섞인 채로 통과해 몇 수 만에 끝나 버린다.
      for (final lv in [1, 30, 60, 120, 250, 400, 500]) {
        final g = LevelGenerator.generate(lv);
        expect(g.state.segmentCount(),
            greaterThanOrEqualTo((g.config.totalUnits * 0.35).round()),
            reason: '레벨 $lv(${g.config})이 너무 안 섞였습니다: ${g.state}');
      }
    }, timeout: const Timeout(Duration(minutes: 3)));
  });

  group('생성된 레벨은 반드시 풀린다 — 이 게임의 핵심 보장', () {
    test('레벨 1~100 전부 풀린다', () {
      for (var lv = 1; lv <= 100; lv++) {
        final g = LevelGenerator.generate(lv);
        final r = Solver.solve(g.state);
        expect(r.solved, isTrue, reason: '레벨 $lv을 풀 수 없습니다: ${g.state}');

        // 탐색기 말만 믿지 않고 수순을 실제로 재생해 본다.
        final board = g.state.copy();
        for (final m in r.moves) {
          expect(board.pour(m.from, m.to), isNotNull, reason: '레벨 $lv 수순이 잘못됐습니다.');
        }
        expect(board.isSolved, isTrue, reason: '레벨 $lv 수순을 다 뒀는데 안 이겼습니다.');
      }
    }, timeout: const Timeout(Duration(minutes: 5)));

    test('깊은 병 구간을 포함한 고레벨 표본도 풀린다', () {
      // 깊이가 4→5→6→7→8로 바뀌는 모든 구간을 지나도록 표본을 잡았다.
      for (final lv in [110, 150, 200, 230, 300, 350, 400, 450, 500, 700, 1200]) {
        final g = LevelGenerator.generate(lv);
        final r = Solver.solve(g.state);
        expect(r.solved, isTrue,
            reason: '레벨 $lv(${g.config})을 풀 수 없습니다: ${g.state}');
      }
    }, timeout: const Timeout(Duration(minutes: 5)));

    test('깊은 병 레벨은 한 판 만드는 데 오래 걸리지 않는다', () {
      // 레벨을 넘길 때마다 몇 초씩 멈추면 게임이 못 쓰게 된다.
      for (final lv in [300, 500, 700, 1000]) {
        final sw = Stopwatch()..start();
        LevelGenerator.generate(lv);
        sw.stop();
        expect(sw.elapsedMilliseconds, lessThan(2000),
            reason: '레벨 $lv 생성에 ${sw.elapsedMilliseconds}ms 걸렸습니다.');
      }
    }, timeout: const Timeout(Duration(minutes: 5)));
  });

  test('난이도가 오르면 해답도 대체로 길어진다', () {
    final easy = [for (var lv = 1; lv <= 10; lv++) LevelGenerator.generate(lv).solutionLength];
    final hard = [for (var lv = 91; lv <= 100; lv++) LevelGenerator.generate(lv).solutionLength];
    final easyAvg = easy.reduce((a, b) => a + b) / easy.length;
    final hardAvg = hard.reduce((a, b) => a + b) / hard.length;
    expect(hardAvg, greaterThan(easyAvg));
  }, timeout: const Timeout(Duration(minutes: 5)));
}
