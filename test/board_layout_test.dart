import 'dart:ui';

import 'package:bottlebottle/logic/level_config.dart';
import 'package:bottlebottle/ui/widgets/board_layout.dart';
import 'package:flutter_test/flutter_test.dart';

/// 흔한 폰 화면들. 게임판에 쓸 수 있는 세로 공간만 대충 뺀 값이다.
const _phones = <String, Size>{
  '작은 폰': Size(320, 480),
  '보통 폰': Size(390, 620),
  '큰 폰': Size(430, 700),
};

void main() {
  test('레벨이 오르면 병이 작아져서라도 화면에 들어간다', () {
    for (final entry in _phones.entries) {
      for (final lv in [1, 50, 100, 200, 300, 400, 500, 1000]) {
        final config = LevelConfig.forLevel(lv);
        final m = computeBoardMetrics(
          available: entry.value,
          bottleCount: config.bottleCount,
          capacity: config.capacity,
        );

        final usedWidth = m.perRow * (m.bottleWidth + 4);
        final usedHeight = m.rows * (m.bottleHeight(config.capacity) + 4);

        expect(usedWidth, lessThanOrEqualTo(entry.value.width + 1),
            reason: '${entry.key} 레벨 $lv: 가로가 넘칩니다.');
        expect(usedHeight, lessThanOrEqualTo(entry.value.height + 1),
            reason: '${entry.key} 레벨 $lv: 세로가 넘칩니다.');
      }
    }
  });

  test('모든 병이 빠짐없이 배치된다', () {
    for (final lv in [1, 100, 300, 500]) {
      final config = LevelConfig.forLevel(lv);
      final m = computeBoardMetrics(
        available: const Size(390, 620),
        bottleCount: config.bottleCount,
        capacity: config.capacity,
      );
      expect(m.rows * m.perRow, greaterThanOrEqualTo(config.bottleCount),
          reason: '레벨 $lv: 자리가 모자랍니다.');
    }
  });

  test('공간이 빠듯하면 병이 많을수록 작게 그린다', () {
    // 넉넉한 화면에서는 둘 다 최대 크기로 그려지는 게 정상이므로
    // 작은 화면으로 비교해야 이 성질이 드러난다.
    const screen = Size(320, 480);
    final few = computeBoardMetrics(available: screen, bottleCount: 6, capacity: 4);
    final many = computeBoardMetrics(available: screen, bottleCount: 17, capacity: 8);
    expect(few.unitHeight, greaterThan(many.unitHeight));
  });

  test('병이 적을 때 지나치게 커지지는 않는다', () {
    final m = computeBoardMetrics(
      available: const Size(1200, 900),
      bottleCount: 6,
      capacity: 4,
    );
    expect(m.bottleWidth, lessThanOrEqualTo(58));
    expect(m.unitHeight, lessThanOrEqualTo(34));
  });

  test('터무니없이 작은 화면에서도 값을 돌려주고 죽지 않는다', () {
    final m = computeBoardMetrics(
      available: const Size(80, 80),
      bottleCount: 17,
      capacity: 8,
    );
    expect(m.bottleWidth, greaterThan(0));
    expect(m.unitHeight, greaterThan(0));
    expect(m.perRow, greaterThan(0));
  });

  test('가로로 긴 화면에서는 줄 수를 줄인다', () {
    final wide = computeBoardMetrics(
      available: const Size(900, 320),
      bottleCount: 14,
      capacity: 4,
    );
    final tall = computeBoardMetrics(
      available: const Size(320, 900),
      bottleCount: 14,
      capacity: 4,
    );
    expect(wide.rows, lessThanOrEqualTo(tall.rows));
  });
}
