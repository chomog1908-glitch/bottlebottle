import 'package:bottlebottle/ui/widgets/pour_overlay.dart';
import 'package:flutter_test/flutter_test.dart';

/// 붓기 연출의 시간 계산.
///
/// 화면 없이 확인할 수 있는 부분이라 여기서 못을 박아 둔다.
/// 이게 틀리면 물이 병에 닿기 전에 차오르거나, 다 부은 뒤에도 물줄기가 남는다.
void main() {
  const one = PourAnim(from: 0, to: 1, count: 1, color: 0);
  const four = PourAnim(from: 0, to: 1, count: 4, color: 0);

  group('붓는 양에 따라 길이가 달라진다', () {
    test('많이 부을수록 오래 걸린다', () {
      expect(four.total, greaterThan(one.total));
    });

    test('칸 수에 비례해 늘어난다', () {
      final extra = four.total - one.total;
      expect(extra, PourAnim.perUnit * 3);
    });
  });

  group('남은 칸 수', () {
    test('시작 직후에는 하나도 안 넘어갔다', () {
      expect(four.remainingAt(0), 4);
      // 기울이는 동안에는 아직 붓기 전이다.
      expect(four.remainingAt(four.liftEnd * 0.5), 4);
    });

    test('붓기가 끝나면 전부 넘어갔다', () {
      expect(four.remainingAt(four.pourEnd), 0);
      expect(four.remainingAt(1), 0);
    });

    test('붓는 동안 점점 줄어들 뿐 늘지 않는다', () {
      var prev = 4;
      for (var i = 0; i <= 100; i++) {
        final r = four.remainingAt(i / 100);
        expect(r, lessThanOrEqualTo(prev), reason: '진행 중에 되레 늘었습니다.');
        expect(r, inInclusiveRange(0, 4));
        prev = r;
      }
    });
  });

  group('병 기울기', () {
    test('시작할 때는 세워져 있고, 다 기울면 1이 된다', () {
      expect(four.tiltAt(0), 0);
      expect(four.tiltAt(four.liftEnd), 1);
    });

    test('붓는 내내 기울어진 채로 있다', () {
      expect(four.tiltAt((four.liftEnd + four.pourEnd) / 2), 1);
      expect(four.tiltAt(four.pourEnd), 1);
    });

    test('끝나면 제자리로 돌아온다', () {
      expect(four.tiltAt(1), closeTo(0, 0.001));
    });

    test('기울기는 항상 0과 1 사이다', () {
      for (var i = 0; i <= 100; i++) {
        expect(four.tiltAt(i / 100), inInclusiveRange(0, 1));
      }
    });
  });

  group('물줄기', () {
    test('기울이는 동안에는 아직 안 나온다', () {
      expect(four.streamVisibleAt(0), isFalse);
      expect(four.streamVisibleAt(four.liftEnd * 0.9), isFalse);
    });

    test('붓는 동안에만 보인다', () {
      expect(four.streamVisibleAt((four.liftEnd + four.pourEnd) / 2), isTrue);
    });

    test('다 붓고 나면 사라진다', () {
      expect(four.streamVisibleAt(four.pourEnd), isFalse);
      expect(four.streamVisibleAt(1), isFalse);
    });

    test('물줄기가 보이는 동안에는 병이 완전히 기울어 있다', () {
      // 세워진 병에서 물이 나오면 말이 안 된다.
      for (var i = 0; i <= 100; i++) {
        final t = i / 100;
        if (four.streamVisibleAt(t)) {
          expect(four.tiltAt(t), 1, reason: '진행도 $t에서 안 기울고 물이 나옵니다.');
        }
      }
    });
  });
}
