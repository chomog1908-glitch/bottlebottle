import 'package:bottlebottle/model/game_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('부을 수 있는 조건', () {
    test('빈 병에는 부을 수 있다', () {
      final g = GameState([
        [0, 0],
        [],
      ]);
      expect(g.canPour(0, 1), isTrue);
    });

    test('맨 위 색이 같으면 부을 수 있다', () {
      final g = GameState([
        [1, 0],
        [2, 0],
      ]);
      expect(g.canPour(0, 1), isTrue);
    });

    test('맨 위 색이 다르면 부을 수 없다', () {
      final g = GameState([
        [1, 0],
        [2, 3],
      ]);
      expect(g.canPour(0, 1), isFalse);
    });

    test('가득 찬 병에는 부을 수 없다', () {
      final g = GameState([
        [0],
        [0, 0, 0, 0],
      ]);
      expect(g.canPour(0, 1), isFalse);
    });

    test('빈 병에서는 따라낼 수 없다', () {
      final g = GameState([
        [],
        [0],
      ]);
      expect(g.canPour(0, 1), isFalse);
    });

    test('같은 병에는 부을 수 없다', () {
      final g = GameState([
        [0, 0],
      ]);
      expect(g.canPour(0, 0), isFalse);
    });
  });

  group('붓는 양', () {
    test('맨 위 같은 색 덩어리가 통째로 옮겨진다', () {
      final g = GameState([
        [1, 0, 0, 0],
        [],
      ]);
      expect(g.pourAmount(0, 1), 3);
      g.pour(0, 1);
      expect(g.bottleAt(0), [1]);
      expect(g.bottleAt(1), [0, 0, 0]);
    });

    test('받는 병의 남은 자리만큼만 옮겨진다', () {
      final g = GameState([
        [0, 0, 0, 0],
        [1, 1, 0],
      ]);
      expect(g.pourAmount(0, 1), 1);
      g.pour(0, 1);
      expect(g.bottleAt(0), [0, 0, 0]);
      expect(g.bottleAt(1), [1, 1, 0, 0]);
    });

    test('색이 끊기면 그 위까지만 옮겨진다', () {
      final g = GameState([
        [0, 0, 1, 1],
        [],
      ]);
      expect(g.pourAmount(0, 1), 2);
      g.pour(0, 1);
      expect(g.bottleAt(0), [0, 0]);
      expect(g.bottleAt(1), [1, 1]);
    });

    test('부을 수 없으면 0이고 상태가 바뀌지 않는다', () {
      final g = GameState([
        [0],
        [1],
      ]);
      expect(g.pourAmount(0, 1), 0);
      expect(g.pour(0, 1), isNull);
      expect(g.bottleAt(0), [0]);
      expect(g.bottleAt(1), [1]);
      expect(g.moveCount, 0);
    });
  });

  group('승리 판정', () {
    test('모든 병이 한 색으로 가득 차면 승리', () {
      final g = GameState([
        [0, 0, 0, 0],
        [1, 1, 1, 1],
        [],
      ]);
      expect(g.isSolved, isTrue);
    });

    test('덜 찬 병이 있으면 아직 승리가 아니다', () {
      final g = GameState([
        [0, 0, 0],
        [1, 1, 1, 1],
        [0],
      ]);
      expect(g.isSolved, isFalse);
    });

    test('색이 섞인 병이 있으면 승리가 아니다', () {
      final g = GameState([
        [0, 0, 0, 1],
        [1, 1, 1, 0],
      ]);
      expect(g.isSolved, isFalse);
    });

    test('전부 빈 보드는 승리로 친다', () {
      expect(GameState([[], []]).isSolved, isTrue);
    });
  });

  group('되돌리기', () {
    test('한 수를 되돌리면 직전 상태로 정확히 복원된다', () {
      final g = GameState([
        [1, 0, 0],
        [0],
      ]);
      final before = g.toString();
      g.pour(0, 1);
      expect(g.toString(), isNot(before));
      g.undo();
      expect(g.toString(), before);
      expect(g.moveCount, 0);
    });

    test('여러 수를 끝까지 되돌리면 시작 상태로 돌아온다', () {
      final g = GameState([
        [0, 1, 0, 1],
        [1, 0, 1, 0],
        [],
        [],
      ]);
      final before = g.toString();
      g.pour(0, 2);
      g.pour(1, 3);
      g.pour(0, 1);
      while (g.undo() != null) {}
      expect(g.toString(), before);
      expect(g.moveCount, 0);
    });

    test('되돌릴 수가 없으면 null을 준다', () {
      final g = GameState([
        [0],
      ]);
      expect(g.undo(), isNull);
    });

    test('일부만 옮겨진 수도 정확히 되돌아온다', () {
      // 3칸을 들었지만 자리가 1칸뿐이라 1칸만 옮겨지는 경우.
      final g = GameState([
        [0, 0, 0],
        [1, 1, 1],
      ]);
      final before = g.toString();
      final m = g.pour(0, 1);
      expect(m, isNull); // 색이 달라 애초에 부을 수 없다
      expect(g.toString(), before);
    });
  });

  group('둘 수 있는 수 목록', () {
    test('완성된 병에서는 따라내지 않는다', () {
      final g = GameState([
        [0, 0, 0, 0],
        [1, 1],
        [],
      ]);
      expect(g.legalMoves().any((m) => m.from == 0), isFalse);
    });

    test('단색 병을 빈 병으로 옮기는 제자리걸음은 제외한다', () {
      final g = GameState([
        [0, 0],
        [],
      ]);
      expect(g.legalMoves(), isEmpty);
    });

    test('합칠 수 있는 수는 빠짐없이 나온다', () {
      final g = GameState([
        [1, 0],
        [0],
        [],
      ]);
      final moves = g.legalMoves();
      expect(moves.any((m) => m.from == 0 && m.to == 1), isTrue);
      expect(moves.any((m) => m.from == 1 && m.to == 2), isFalse); // 단색→빈 병
    });
  });

  group('정규화 키', () {
    test('병 순서만 다른 상태는 같은 키를 가진다', () {
      final a = GameState([
        [0, 1],
        [1, 0],
        [],
      ]);
      final b = GameState([
        [],
        [1, 0],
        [0, 1],
      ]);
      expect(a.canonicalKey(), b.canonicalKey());
    });

    test('내용이 다르면 키도 다르다', () {
      final a = GameState([
        [0, 1],
        [],
      ]);
      final b = GameState([
        [1, 0],
        [],
      ]);
      expect(a.canonicalKey(), isNot(b.canonicalKey()));
    });
  });

  group('색 조각 수', () {
    test('한 병 안의 연속 덩어리를 센다', () {
      expect(GameState([[0, 0, 1, 0]]).segmentCount(), 3);
      expect(GameState([[0, 0, 0, 0]]).segmentCount(), 1);
      expect(GameState([[0, 1, 2, 3]]).segmentCount(), 4);
    });

    test('빈 병은 세지 않는다', () {
      expect(GameState([[], [], [0, 0]]).segmentCount(), 1);
    });

    test('다 푼 판의 조각 수는 색 가짓수와 같다', () {
      final g = GameState([
        [0, 0, 0, 0],
        [1, 1, 1, 1],
        [],
      ]);
      expect(g.segmentCount(), 2);
    });

    test('물을 부어 합치면 조각 수가 준다', () {
      final g = GameState([
        [1, 0],
        [0],
      ]);
      final before = g.segmentCount();
      g.pour(0, 1);
      expect(g.segmentCount(), lessThan(before));
    });
  });

  test('용량을 넘는 병은 만들 수 없다', () {
    expect(() => GameState([[0, 0, 0, 0, 0]]), throwsArgumentError);
  });

  test('복제본을 조작해도 원본은 그대로다', () {
    final g = GameState([
      [1, 0],
      [0],
    ]);
    final before = g.toString();
    final c = g.copy();
    c.pour(0, 1);
    expect(g.toString(), before);
  });
}
