/// 레벨 번호 → 난이도 파라미터.
///
/// 난이도를 키우는 축이 셋이다.
/// 1. **색 가짓수** — 병 개수가 함께 늘어난다 (병 수 = 색 수 + 빈 병 수)
/// 2. **병 깊이** — 한 병에 담기는 칸 수. 깊을수록 아래쪽 색을 꺼내기 어렵다
/// 3. **빈 병 수** — 줄어들수록 숨 쉴 곳이 없어진다
///
/// 색만 늘려서 어렵게 만들지 않는 이유: 색이 스무 가지쯤 되면 퍼즐이 아니라 시력 검사가 된다.
/// 그래서 색은 15가지에서 멈추고, 그 뒤로는 **병을 깊게** 해서 난이도를 올린다.
/// 깊은 병은 색을 헷갈리게 만들지 않으면서도 훨씬 멀리 내다봐야 풀린다.
class LevelConfig {
  /// 1부터 시작하는 레벨 번호.
  final int level;

  /// 사용할 색의 가짓수. 색마다 정확히 [capacity]칸씩 존재한다.
  final int colorCount;

  /// 여분의 빈 병 수. 이 값이 작을수록 어렵다.
  final int emptyBottles;

  /// 병 하나의 깊이(칸 수).
  final int capacity;

  const LevelConfig({
    required this.level,
    required this.colorCount,
    required this.emptyBottles,
    required this.capacity,
  });

  /// 화면에 놓이는 전체 병 수.
  int get bottleCount => colorCount + emptyBottles;

  /// 총 액체 칸 수.
  int get totalUnits => colorCount * capacity;

  /// 색으로 쓸 수 있는 최대 가짓수. 팔레트가 준비한 색 수와 같아야 한다.
  static const int maxColors = 15;

  /// 병의 최대 깊이.
  static const int maxCapacity = 8;

  /// 난이도 단계표. `[이 레벨까지, 색 수, 깊이, 빈 병 수]`
  ///
  /// 깊이가 한 칸 늘어나는 구간에서는 색 수를 잠시 줄인다.
  /// 두 축을 동시에 올리면 난이도가 계단이 아니라 절벽이 된다.
  static const List<List<int>> _tiers = [
    // 색을 늘려 가며 병 수를 불린다. 깊이는 4칸 고정.
    [5, 4, 4, 2], // 6병
    [12, 5, 4, 2],
    [20, 6, 4, 2],
    [30, 7, 4, 2],
    [42, 8, 4, 2],
    [55, 9, 4, 2],
    [70, 10, 4, 2],
    [85, 11, 4, 2],
    [100, 12, 4, 2], // 14병

    // 병이 5칸으로 깊어진다.
    [115, 10, 5, 2],
    [135, 11, 5, 2],
    [155, 12, 5, 2],
    [175, 13, 5, 2],
    [200, 14, 5, 2], // 16병

    // 6칸.
    [225, 12, 6, 2],
    [250, 13, 6, 2],
    [280, 14, 6, 2],
    [310, 15, 6, 2], // 17병

    // 7칸.
    [345, 13, 7, 2],
    [380, 14, 7, 2],
    [420, 15, 7, 2],

    // 8칸.
    [460, 14, 8, 2],
    [500, 15, 8, 2],

    // 마지막 단계: 가장 깊고, 색이 가장 많고, 빈 병이 하나뿐이다.
    // 이 뒤로는 더 올리지 않는다. 여기서부터는 매 판이 온전히 어렵다.
    [1 << 30, 15, 8, 1], // 16병
  ];

  factory LevelConfig.forLevel(int level) {
    if (level < 1) throw ArgumentError('레벨은 1 이상이어야 합니다: $level');

    for (final t in _tiers) {
      if (level <= t[0]) {
        return LevelConfig(
          level: level,
          colorCount: t[1],
          capacity: t[2],
          emptyBottles: t[3],
        );
      }
    }
    throw StateError('난이도 단계표가 레벨 $level을 담지 못합니다.');
  }

  /// 사람이 읽을 난이도 이름. 화면 표시에 쓴다.
  String get difficultyLabel {
    if (level <= 20) return '연습';
    if (level <= 55) return '쉬움';
    if (level <= 100) return '보통';
    if (level <= 200) return '어려움';
    if (level <= 310) return '매우 어려움';
    return '최고 난이도';
  }

  @override
  String toString() =>
      'Lv$level(색 $colorCount, 깊이 $capacity칸, 빈 병 $emptyBottles개, 병 $bottleCount개)';
}
