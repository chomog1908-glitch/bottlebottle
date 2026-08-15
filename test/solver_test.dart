import 'package:bottlebottle/logic/solver.dart';
import 'package:bottlebottle/model/game_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// 수순대로 실제로 두어 정말 이기는지 확인한다.
/// 탐색기가 "풀었다"고 말하는 것만 믿지 않고, 규칙 위에서 재생해 본다.
void expectSolutionWorks(GameState start, List<dynamic> moves) {
  final g = start.copy();
  for (final m in moves) {
    final applied = g.pour(m.from, m.to);
    expect(applied, isNotNull, reason: '수순 중 둘 수 없는 수가 있습니다: $m');
    expect(applied!.count, m.count, reason: '옮겨진 칸 수가 예상과 다릅니다: $m');
  }
  expect(g.isSolved, isTrue, reason: '수순을 다 뒀는데 이기지 못했습니다.');
}

void main() {
  test('이미 이긴 판은 빈 수순으로 푼다', () {
    final g = GameState([
      [0, 0, 0, 0],
      [],
    ]);
    final r = Solver.solve(g);
    expect(r.solved, isTrue);
    expect(r.moves, isEmpty);
  });

  test('한 수로 끝나는 판', () {
    final g = GameState([
      [0, 0, 0],
      [0],
      [1, 1, 1, 1],
    ]);
    final r = Solver.solve(g);
    expect(r.solved, isTrue);
    expectSolutionWorks(g, r.moves);
  });

  test('색 3개짜리 판을 푼다', () {
    final g = GameState([
      [0, 1, 2, 0],
      [1, 2, 0, 1],
      [2, 0, 1, 2],
      [],
      [],
    ]);
    final r = Solver.solve(g);
    expect(r.solved, isTrue);
    expectSolutionWorks(g, r.moves);
  });

  test('풀 수 없는 판을 확실히 풀 수 없다고 판정한다', () {
    // 빈 병이 없고 모든 병의 맨 위 색이 서로 달라 아무 수도 둘 수 없다.
    final g = GameState([
      [1, 1, 1, 0],
      [0, 0, 0, 1],
    ]);
    final r = Solver.solve(g);
    expect(r.solved, isFalse);
    expect(r.provenUnsolvable, isTrue,
        reason: '예산 초과가 아니라 탐색을 끝까지 마친 결과여야 합니다.');
  });

  test('예산이 모자라면 풀 수 없다가 아니라 모르겠다로 답한다', () {
    final g = GameState([
      [0, 1, 2, 3],
      [1, 2, 3, 0],
      [2, 3, 0, 1],
      [3, 0, 1, 2],
      [],
    ]);
    final r = Solver.solve(g, nodeBudget: 1);
    expect(r.solved, isFalse);
    expect(r.exhausted, isTrue);
    expect(r.provenUnsolvable, isFalse);
  });

  group('힌트', () {
    test('힌트로 준 수는 실제로 둘 수 있는 수다', () {
      final g = GameState([
        [0, 1, 2, 0],
        [1, 2, 0, 1],
        [2, 0, 1, 2],
        [],
        [],
      ]);
      final h = Solver.hint(g);
      expect(h, isNotNull);
      expect(g.canPour(h!.from, h.to), isTrue);
    });

    test('힌트를 계속 따라 두면 반드시 이긴다', () {
      final g = GameState([
        [0, 1, 2, 0],
        [1, 2, 0, 1],
        [2, 0, 1, 2],
        [],
        [],
      ]);
      var guard = 0;
      while (!g.isSolved) {
        final h = Solver.hint(g);
        expect(h, isNotNull, reason: '아직 안 이겼는데 힌트가 없습니다.');
        g.pour(h!.from, h.to);
        expect(++guard, lessThan(500), reason: '힌트를 따라갔는데 끝나지 않습니다.');
      }
      expect(g.isSolved, isTrue);
    });

    test('이미 이긴 판에는 힌트가 없다', () {
      final g = GameState([
        [0, 0, 0, 0],
      ]);
      expect(Solver.hint(g), isNull);
    });
  });

  test('중간까지 둔 판에서도 이어서 푼다', () {
    final g = GameState([
      [0, 1, 2, 0],
      [1, 2, 0, 1],
      [2, 0, 1, 2],
      [],
      [],
    ]);
    g.pour(0, 3);
    g.pour(1, 4);
    final r = Solver.solve(g);
    expect(r.solved, isTrue);
    expectSolutionWorks(g, r.moves);
  });
}
