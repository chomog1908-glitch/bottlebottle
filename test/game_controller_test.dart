import 'package:bottlebottle/controller/game_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('병 누르기', () {
    test('비어 있지 않은 병을 누르면 들린다', () {
      final c = GameController();
      final full = _firstNonEmpty(c);
      c.tapBottle(full);
      expect(c.selected, full);
    });

    test('빈 병을 먼저 누르면 아무 일도 없다', () {
      final c = GameController();
      final empty = _firstEmpty(c);
      c.tapBottle(empty);
      expect(c.selected, isNull);
    });

    test('같은 병을 다시 누르면 내려놓는다', () {
      final c = GameController();
      final full = _firstNonEmpty(c);
      c.tapBottle(full);
      c.tapBottle(full);
      expect(c.selected, isNull);
    });

    test('부을 수 있는 병을 누르면 물이 옮겨진다', () {
      final c = GameController();
      final from = _firstNonEmpty(c);
      final to = _firstEmpty(c);
      final before = c.state.bottleAt(to).length;

      c.tapBottle(from);
      c.tapBottle(to);

      expect(c.state.bottleAt(to).length, greaterThan(before));
      expect(c.selected, isNull, reason: '부은 뒤에는 손이 비어야 합니다.');
      expect(c.moveCount, 1);
    });

    test('부을 수 없는 병을 누르면 거절하고 그 병을 대신 든다', () {
      final c = GameController();
      // 서로 부을 수 없는 두 병을 찾는다.
      int? a, b;
      for (var i = 0; i < c.state.bottleCount && b == null; i++) {
        if (c.state.isEmptyBottle(i)) continue;
        for (var j = 0; j < c.state.bottleCount; j++) {
          if (i == j || c.state.isEmptyBottle(j)) continue;
          if (!c.state.canPour(i, j)) {
            a = i;
            b = j;
            break;
          }
        }
      }
      expect(b, isNotNull, reason: '시험할 조합을 찾지 못했습니다.');

      c.tapBottle(a!);
      c.tapBottle(b!);

      expect(c.moveCount, 0, reason: '수가 두어지면 안 됩니다.');
      expect(c.rejected, b, reason: '거절을 화면에 알려야 합니다.');
      expect(c.selected, b, reason: '다시 누르는 수고를 덜어주기 위해 대신 들어야 합니다.');
    });

    test('다 푼 판에서는 눌러도 반응하지 않는다', () {
      final c = GameController();
      _solve(c);
      expect(c.isSolved, isTrue);
      final moves = c.moveCount;
      c.tapBottle(0);
      expect(c.moveCount, moves);
      expect(c.selected, isNull);
    });
  });

  group('되돌리기와 다시하기', () {
    test('되돌리면 수가 줄고 손이 비워진다', () {
      final c = GameController();
      c.tapBottle(_firstNonEmpty(c));
      c.tapBottle(_firstEmpty(c));
      expect(c.canUndo, isTrue);

      c.undo();
      expect(c.moveCount, 0);
      expect(c.canUndo, isFalse);
      expect(c.selected, isNull);
    });

    test('둘 수가 없으면 되돌리기가 꺼져 있다', () {
      expect(GameController().canUndo, isFalse);
    });

    test('다시하기는 정확히 같은 판으로 돌아간다', () {
      final c = GameController();
      final before = c.state.toString();
      c.tapBottle(_firstNonEmpty(c));
      c.tapBottle(_firstEmpty(c));
      c.restart();
      expect(c.state.toString(), before);
      expect(c.moveCount, 0);
    });
  });

  group('레벨 이동', () {
    test('다음 레벨로 가면 판이 초기화된다', () {
      final c = GameController();
      c.tapBottle(_firstNonEmpty(c));
      c.nextLevel();
      expect(c.level, 2);
      expect(c.moveCount, 0);
      expect(c.selected, isNull);
    });

    test('클리어하지 않아도 건너뛸 수 있다', () {
      final c = GameController();
      expect(c.isSolved, isFalse);
      c.nextLevel();
      expect(c.level, 2);
    });

    test('레벨 1에서는 이전으로 갈 수 없다', () {
      final c = GameController();
      c.previousLevel();
      expect(c.level, 1);
    });

    test('갔던 레벨로 돌아오면 같은 판이 나온다', () {
      final c = GameController();
      final lv1 = c.state.toString();
      c.nextLevel();
      c.previousLevel();
      expect(c.state.toString(), lv1);
    });
  });

  group('빈 병 사용량', () {
    test('시작할 때는 하나도 쓰지 않은 상태다', () {
      // 여러 레벨에서 확인한다. 시작부터 1/2로 뜨는 판이 하나라도 있으면 안 된다.
      for (final lv in [1, 4, 15, 60, 150, 300, 600]) {
        final c = GameController(startLevel: lv);
        expect(c.emptiesInUse, 0, reason: '레벨 $lv: 시작부터 빈 병을 쓴 것으로 나옵니다.');
        expect(c.peakEmptiesUsed, 0, reason: '레벨 $lv');
        expect(c.emptyBottleBudget, c.config.emptyBottles);
      }
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('빈 병에 부으면 사용량이 오른다', () {
      final c = GameController();
      c.tapBottle(_firstNonEmpty(c));
      c.tapBottle(_firstEmpty(c));
      expect(c.emptiesInUse, 1);
      expect(c.peakEmptiesUsed, 1);
    });

    test('되돌리면 기록도 함께 되돌아간다', () {
      final c = GameController();
      c.tapBottle(_firstNonEmpty(c));
      c.tapBottle(_firstEmpty(c));
      expect(c.peakEmptiesUsed, 1);

      c.undo();
      expect(c.peakEmptiesUsed, 0, reason: '되돌렸으면 기록도 되돌아가야 합니다.');
      expect(c.emptiesInUse, 0);
    });

    test('한 번 최대값을 찍으면 나중에 비워도 기록은 남는다', () {
      final c = GameController();
      c.tapBottle(_firstNonEmpty(c));
      c.tapBottle(_firstEmpty(c));
      final peak = c.peakEmptiesUsed;
      expect(peak, 1);

      // 되돌리지 않고 계속 풀어 나가면 기록은 유지된다.
      _solve(c);
      expect(c.peakEmptiesUsed, greaterThanOrEqualTo(peak));
    });

    test('사용량이 준 빈 병 수를 넘지 않는다', () {
      final c = GameController();
      _solve(c);
      expect(c.peakEmptiesUsed, lessThanOrEqualTo(c.emptyBottleBudget));
      expect(c.emptiesInUse, greaterThanOrEqualTo(0));
    });

    test('다시하기를 하면 기록이 초기화된다', () {
      final c = GameController();
      c.tapBottle(_firstNonEmpty(c));
      c.tapBottle(_firstEmpty(c));
      c.restart();
      expect(c.peakEmptiesUsed, 0);
    });
  });

  group('힌트', () {
    test('힌트는 실제로 둘 수 있는 수를 가리킨다', () {
      final c = GameController();
      c.requestHint();
      expect(c.hintMove, isNotNull);
      expect(c.state.canPour(c.hintMove!.from, c.hintMove!.to), isTrue);
      expect(c.isHinted(c.hintMove!.from), isTrue);
      expect(c.isHinted(c.hintMove!.to), isTrue);
    });

    test('수를 두면 힌트 표시가 사라진다', () {
      final c = GameController();
      c.requestHint();
      final h = c.hintMove!;
      c.tapBottle(h.from);
      c.tapBottle(h.to);
      expect(c.hintMove, isNull);
    });

    test('힌트만 따라 눌러도 판이 풀린다', () {
      final c = GameController();
      _solve(c);
      expect(c.isSolved, isTrue);
    });
  });

  group('힌트는 반드시 판을 끝낸다', () {
    // 탐색기는 최단 해답을 보장하지 않는다. 그래서 힌트를 누를 때마다 새로 찾으면
    // 서로 다른 해답의 첫 수를 오가며 영원히 왕복할 수 있다. 실제로 레벨 1에서
    // 0→3, 3→0을 무한히 반복해 힌트만으로는 판이 끝나지 않았다.
    // 컨트롤러가 한 번 찾은 수순을 들고 가는지를 여기서 지킨다.
    for (final level in [1, 2, 3, 40, 120, 432]) {
      test('레벨 $level은 힌트만 따라가도 끝난다', () {
        final c = GameController(startLevel: level);
        // 넉넉히 잡되 무한은 아니다. 왕복에 빠지면 여기서 걸린다.
        final limit = c.state.bottleCount * c.state.capacity * 12;

        var guard = 0;
        while (!c.isSolved) {
          c.requestHint();
          final h = c.hintMove;
          expect(h, isNotNull, reason: '레벨 $level에서 힌트가 끊겼습니다.');
          c.tapBottle(h!.from);
          c.tapBottle(h.to);
          expect(++guard, lessThan(limit),
              reason: '레벨 $level에서 힌트가 같은 자리를 맴돕니다.');
        }
      });
    }

    test('중간에 다른 수를 둬도 힌트가 이어서 판을 끝낸다', () {
      // 사용자가 수순을 벗어나면 들고 있던 계획은 버리고 새로 찾아야 한다.
      final c = GameController(startLevel: 3);
      var guard = 0;
      var detoured = false;

      while (!c.isSolved) {
        c.requestHint();
        final h = c.hintMove!;
        if (!detoured) {
          // 딱 한 번, 힌트와 다른 수를 둔다.
          for (var i = 0; i < c.state.bottleCount && !detoured; i++) {
            for (var j = 0; j < c.state.bottleCount; j++) {
              if ((i == h.from && j == h.to) || !c.state.canPour(i, j)) continue;
              c.tapBottle(i);
              c.tapBottle(j);
              detoured = true;
              break;
            }
          }
          if (detoured) continue;
        }
        c.tapBottle(h.from);
        c.tapBottle(h.to);
        expect(++guard, lessThan(600), reason: '힌트가 판을 끝내지 못했습니다.');
      }
      expect(detoured, isTrue, reason: '다른 길로 새는 수를 두지 못했습니다.');
    });
  });
}

int _firstNonEmpty(GameController c) {
  for (var i = 0; i < c.state.bottleCount; i++) {
    if (!c.state.isEmptyBottle(i)) return i;
  }
  throw StateError('내용물이 있는 병이 없습니다.');
}

int _firstEmpty(GameController c) {
  for (var i = 0; i < c.state.bottleCount; i++) {
    if (c.state.isEmptyBottle(i)) return i;
  }
  throw StateError('빈 병이 없습니다.');
}

/// 힌트를 눌러가며 끝까지 푼다. 힌트 기능과 입력 처리를 동시에 검증한다.
void _solve(GameController c) {
  var guard = 0;
  while (!c.isSolved) {
    c.requestHint();
    final h = c.hintMove;
    if (h == null) throw StateError('아직 안 풀렸는데 힌트가 없습니다.');
    c.tapBottle(h.from);
    c.tapBottle(h.to);
    if (++guard > 500) throw StateError('힌트를 따라갔는데 끝나지 않습니다.');
  }
}
