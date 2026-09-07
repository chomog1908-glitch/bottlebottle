import 'package:flutter_test/flutter_test.dart';

import 'package:bottlebottle/logic/generator.dart';
import 'package:bottlebottle/logic/level_config.dart';
import 'package:bottlebottle/logic/solver.dart';
import 'package:bottlebottle/model/rule_set.dart';

/// 규칙이 붙은 판도 만들어지고, 만든 판은 그 규칙 아래에서 풀린다.
///
/// 이게 이 단계의 전부다. 생성기가 규칙을 무시하면 "풀 수 있음"이 거짓말이 된다.
void main() {
  /// [rules]를 씌운 판을 만들어 규칙대로 풀리는지 확인한다.
  void checkBand(String name, LevelConfig config) {
    test('$name — 만들어지고, 그 규칙 아래에서 풀린다', () {
      final level = LevelGenerator.generateWith(config);

      expect(level.state.rules, config.rules, reason: '판이 규칙을 들고 있어야 한다');
      expect(level.state.isSolved, isFalse);
      expect(level.state.emptyBottleCount(), config.emptyBottles);

      // 규칙을 그대로 들고 다시 풀어본다. 생성 때 쓴 결과를 믿지 않는다.
      final again = Solver.solve(level.state);
      expect(again.solved, isTrue,
          reason: '규칙이 붙은 판이 풀리지 않았다: ${config.rules}');
    });
  }

  group('이웃 제한', () {
    // 격자의 한 줄 병 수(perRow)가 이웃 제한의 진짜 손잡이다.
    //
    // 줄이 넓으면 ±1은 병을 고립시킨다. 8칸 격자에서 ±1은 어떤 판도 만들지 못했고,
    // 5칸으로 좁히자 곧바로 만들어졌다. 병 수나 깊이를 줄이는 것보다 **격자를 좁히는
    // 쪽이 판의 크기를 지키면서 규칙만 조인다.** 그래서 이웃 구간은 격자를 좁힌다.
    checkBand(
      '가로±3 세로±3 — 판을 줄이지 않고 규칙만 조인다',
      const LevelConfig(
        level: 800, colorCount: 15, emptyBottles: 2, capacity: 8,
        rules: RuleSet.reach(3, 3, perRow: 5),
      ),
    );
    checkBand(
      '가로±2 세로±2',
      const LevelConfig(
        level: 900, colorCount: 14, emptyBottles: 2, capacity: 7,
        rules: RuleSet.reach(2, 2, perRow: 5),
      ),
    );
  });

  group('트릭', () {
    checkBand(
      'A — 빈 병은 그 색 전용',
      const LevelConfig(
        level: 1200, colorCount: 8, emptyBottles: 2, capacity: 5,
        rules: RuleSet(claimEmpties: true),
      ),
    );
    checkBand(
      'A+B — 단색 병도 전용',
      const LevelConfig(
        level: 1400, colorCount: 8, emptyBottles: 2, capacity: 5,
        rules: RuleSet(claimEmpties: true, claimMono: true),
      ),
    );
    checkBand(
      'A+C — 빈 병 출신은 가득 차야 따라낸다',
      const LevelConfig(
        level: 1600, colorCount: 8, emptyBottles: 2, capacity: 5,
        rules: RuleSet(claimEmpties: true, lockEmptyOrigin: true),
      ),
    );
  });

  test('규칙이 붙어도 시작 판의 모든 수는 규칙을 지킨다', () {
    final level = LevelGenerator.generateWith(const LevelConfig(
      level: 900, colorCount: 14, emptyBottles: 2, capacity: 7,
      rules: RuleSet.reach(2, 2, perRow: 5),
    ));
    for (final m in level.state.legalMoves()) {
      expect(level.state.rules.reaches(m.from, m.to), isTrue,
          reason: '닿지 않는 병 사이의 수가 legalMoves에 들어 있다: $m');
    }
  });
}
