import 'dart:math';
import 'dart:ui';

/// 병들을 어떻게 늘어놓을지에 대한 계산 결과.
class BoardMetrics {
  /// 병을 몇 줄로 늘어놓을지.
  final int rows;

  /// 한 줄에 최대 몇 개.
  final int perRow;

  final double bottleWidth;

  /// 액체 한 칸의 높이. 병 전체 높이는 이 값 × 깊이다.
  final double unitHeight;

  const BoardMetrics({
    required this.rows,
    required this.perRow,
    required this.bottleWidth,
    required this.unitHeight,
  });

  /// 깊이 [capacity]칸짜리 병의 전체 높이.
  double bottleHeight(int capacity) => unitHeight * capacity;
}

/// 화면 크기에 맞춰 병 크기와 줄 수를 정한다.
///
/// 레벨이 올라가면 병이 6개에서 17개까지 늘고 깊이도 4칸에서 8칸까지 깊어진다.
/// 크기를 고정해 두면 후반부에 화면 밖으로 나가버리므로, **남은 공간에 맞춰 줄인다.**
///
/// 순수 함수로 떼어 둔 이유: 화면 없이 여러 조합을 시험할 수 있어야
/// "레벨 500을 작은 폰에서 열면 병이 잘리는가" 같은 걸 테스트로 확인할 수 있다.
BoardMetrics computeBoardMetrics({
  required Size available,
  required int bottleCount,
  required int capacity,
  double horizontalGap = 12,
  double verticalGap = 16,
  double maxBottleWidth = 58,
  double maxUnitHeight = 34,
  double minBottleWidth = 16,
  double minUnitHeight = 7,
}) {
  BoardMetrics? best;

  // 줄 수를 하나씩 늘려 보며 가장 크게 그릴 수 있는 배치를 고른다.
  // 줄이 늘면 한 줄에 들어갈 병이 줄어 넓어지지만, 대신 병 높이가 낮아진다.
  for (var rows = 1; rows <= 5; rows++) {
    final perRow = (bottleCount / rows).ceil();
    if (perRow < 1) continue;

    final width = min(available.width / perRow - horizontalGap, maxBottleWidth);
    final height = available.height / rows - verticalGap;
    final unit = min(height / capacity, maxUnitHeight);

    if (width < minBottleWidth || unit < minUnitHeight) continue;

    final candidate = BoardMetrics(
      rows: rows,
      perRow: perRow,
      bottleWidth: width,
      unitHeight: unit,
    );

    // 액체 칸이 큰 쪽이 좋다. 같으면 병이 넓은 쪽이 손가락으로 누르기 편하다.
    if (best == null ||
        candidate.unitHeight > best.unitHeight ||
        (candidate.unitHeight == best.unitHeight &&
            candidate.bottleWidth > best.bottleWidth)) {
      best = candidate;
    }
  }

  // 어떤 배치로도 최소 크기를 못 맞추는 아주 작은 화면이라면,
  // 가장 여유로운 5줄 배치에 최소 크기를 적용한다. 화면이 스크롤되어 넘친 부분을 볼 수 있다.
  return best ??
      BoardMetrics(
        rows: 5,
        perRow: (bottleCount / 5).ceil(),
        bottleWidth: minBottleWidth,
        unitHeight: minUnitHeight,
      );
}
