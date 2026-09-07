import 'package:bottlebottle/model/game_state.dart';
import 'package:bottlebottle/model/rule_set.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('기본 규칙은 예전 그대로다', () {
    test('제한도 잠금도 없다', () {
      expect(RuleSet.classic.hasReachLimit, isFalse);
      expect(RuleSet.classic.hasLocks, isFalse);
      expect(RuleSet.classic.reaches(0, 99), isTrue);
    });

    test('멀리 있는 병에도 부을 수 있다', () {
      final s = GameState([
        [0], [], [], [], [], [], [], [], [], [],
      ], capacity: 4);
      expect(s.canPour(0, 9), isTrue);
    });
  });

  group('이웃 제한', () {
    // 한 줄 4개짜리 격자로 본다. 0 1 2 3 / 4 5 6 7
    const r = RuleSet(reachX: 1, reachY: 1, gridPerRow: 4);

    test('가로로 한 칸까지만 닿는다', () {
      expect(r.reaches(1, 2), isTrue);
      expect(r.reaches(1, 0), isTrue);
      expect(r.reaches(1, 3), isFalse, reason: '두 칸 떨어져 있다.');
    });

    test('세로로 한 줄까지만 닿는다', () {
      expect(r.reaches(1, 5), isTrue, reason: '바로 아래 줄이다.');
      expect(r.reaches(1, 9), isFalse, reason: '두 줄 아래다.');
    });

    test('줄이 바뀌면 가로 거리도 함께 본다', () {
      // 3번(0번째 줄 끝)과 4번(1번째 줄 처음)은 번호는 이웃이지만
      // 격자에서는 가로로 세 칸 떨어져 있다.
      expect(r.reaches(3, 4), isFalse,
          reason: '번호가 이웃이라고 화면에서도 이웃인 것은 아니다.');
    });

    test('닿지 않는 병에는 부을 수 없다', () {
      final s = GameState([
        [0], [], [], [], [], [], [], [],
      ], capacity: 4, rules: r);
      expect(s.canPour(0, 1), isTrue);
      expect(s.canPour(0, 3), isFalse);
    });
  });

  group('트릭 A — 빈 병은 처음 담은 색 전용', () {
    const r = RuleSet(claimEmpties: true);

    test('빈 병에 담으면 그 색으로 굳는다', () {
      final s = GameState([
        [0], [1], [],
      ], capacity: 4, rules: r);
      expect(s.claimedColor(2), isNull);

      s.pour(0, 2);
      expect(s.claimedColor(2), 0, reason: '색 0 전용이 되어야 한다.');
      expect(s.canPour(1, 2), isFalse, reason: '다른 색은 못 받는다.');
    });

    test('비워도 잠금이 풀리지 않는다', () {
      final s = GameState([
        [0], [1], [],
      ], capacity: 4, rules: r);
      s.pour(0, 2);
      s.pour(2, 0); // 도로 뺀다
      expect(s.claimedColor(2), 0, reason: '비어도 색은 정해져 있다.');
      expect(s.canPour(1, 2), isFalse);
    });

    test('원래 색이 있던 병은 굳지 않는다', () {
      final s = GameState([
        [0, 0], [1], [],
      ], capacity: 4, rules: r);
      expect(s.claimedColor(0), isNull, reason: '빈 병 출신이 아니다.');
    });
  });

  group('트릭 B — 한 색만 남으면 그 색 전용', () {
    const r = RuleSet(claimMono: true);

    test('한 색만 남으면 굳고, 비우면 풀린다', () {
      final s = GameState([
        [1, 0], [0], [],
      ], capacity: 4, rules: r);
      expect(s.claimedColor(1), 0, reason: '처음부터 한 색뿐이다.');

      s.pour(1, 2); // 1번을 비운다
      expect(s.claimedColor(1), isNull, reason: '비우면 풀린다.');
    });
  });

  group('트릭 C — 빈 병에서 시작한 병은 되돌릴 수 없다', () {
    const r = RuleSet(lockEmptyOrigin: true);

    test('가득 차기 전에는 못 따라낸다', () {
      final s = GameState([
        [0, 0], [],
      ], capacity: 4, rules: r);
      s.pour(0, 1);
      expect(s.canPour(1, 0), isFalse, reason: '빈 병 출신이고 아직 안 찼다.');
    });

    test('가득 차면 따라낼 수 있다', () {
      // 완성 상태에서 되감을 수 있어야 생성기가 판을 만들 수 있다.
      final s = GameState([
        [0, 0, 0, 0], [],
      ], capacity: 4, rules: r);
      expect(s.canPour(0, 1), isTrue, reason: '가득 찬 병은 예외다.');
    });
  });

  group('탐색 키', () {
    test('제한이 없으면 병 순서를 무시한다', () {
      final a = GameState([[0], [1], []], capacity: 4);
      final b = GameState([[1], [], [0]], capacity: 4);
      expect(a.canonicalKey(), b.canonicalKey(),
          reason: '위치가 의미 없으면 같은 상태다.');
    });

    test('이웃 제한이 있으면 병 순서를 구분한다', () {
      const r = RuleSet(reachX: 1, reachY: 1, gridPerRow: 4);
      final a = GameState([[0], [1], []], capacity: 4, rules: r);
      final b = GameState([[1], [], [0]], capacity: 4, rules: r);
      expect(a.canonicalKey(), isNot(b.canonicalKey()),
          reason: '위치가 의미를 가지면 다른 상태다.');
    });
  });
}
