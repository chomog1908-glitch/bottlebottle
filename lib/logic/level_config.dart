import '../model/rule_set.dart';

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

  /// 이 레벨에 적용되는 규칙. 레벨 700까지는 [RuleSet.classic]이다.
  final RuleSet rules;

  const LevelConfig({
    required this.level,
    required this.colorCount,
    required this.emptyBottles,
    required this.capacity,
    this.rules = RuleSet.classic,
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

    // 색과 깊이로 올릴 수 있는 데까지 올렸다. 여기가 기본 규칙의 천장이다.
    [700, 15, 8, 1], // 16병
  ];

  /// 규칙 구간표. `[이 레벨까지, 색 수, 깊이, 빈 병 수, 격자, 규칙코드]`
  ///
  /// 색과 깊이는 700에서 천장에 닿았다. 그 위로는 **규칙**으로 난이도를 올린다.
  ///
  /// ## 이웃 제한 구간에서 판을 줄이지 않는 이유
  ///
  /// 이웃 제한의 손잡이는 병 수나 깊이가 아니라 **격자의 한 줄 병 수**다.
  /// 한 줄이 넓으면 같은 ±N이라도 병이 서로 멀어져 고립된다.
  /// (실측: 8칸 격자의 ±3은 색15 깊이8에서 판을 하나도 못 만들었다.
  ///  5칸으로 좁히자 같은 크기에서 조각 60·해답 62수가 나왔다.
  ///  기본 규칙 최고 난이도가 조각 46이니 오히려 더 어렵다.)
  ///
  /// 그래서 이웃 구간은 판을 크게 줄이지 않고 격자로 조인다.
  ///
  /// 다만 색15 깊이8 그대로는 조각이 기준에 못 미치는 판이 8판 중 2판 나왔다.
  /// 한 칸만 낮춘 색14 깊이7에서는 8판 전부 기준을 넘겼다(조각 46/44).
  /// 천장 바로 아래가 가장 잘 도는 자리다.
  ///
  /// ## ±1에서만 판을 줄이는 이유
  ///
  /// ±1은 격자를 좁혀도 큰 판이 안 나온다. 5판 중 0~2판만 만들어지고
  /// 그마저 해답 9수짜리 싱거운 판이었다. 반면 색10 깊이5로 줄이면
  /// 5판 전부, 싱거운 판 없이(조각 27/23) 나온다.
  /// 여기서만 판을 줄였다가 트릭 구간에서 다시 키운다.
  static const List<List<int>> _ruleTiers = [
    // 이웃 제한. 격자를 좁혀 가며 조인다. 판 크기는 그대로.
    [850, 14, 7, 2, 5, _rReach33], //  701~ 850  가로±3 세로±3
    // 규칙이 조여들면 판을 한 단계 낮춘다. 낮추지 않으면 판이 잘 안 만들어지고,
    // 만들어져도 오래 걸린다. (색14 깊이7로 두었더니 10판 중 8판만 나오고
    //  한 판에 최대 3.8초가 걸렸다. 레벨을 넘길 때마다 그만큼 멈춘다는 뜻이다.
    //  색13 깊이6에서는 10판 전부, 평균 0.19초에 나온다.)
    [1000, 13, 6, 2, 5, _rReach22], //  851~1000  가로±2 세로±2
    // 세로만 한 줄로 조인다. 가로가 넉넉해 병이 고립되지 않는다.
    [1150, 13, 6, 2, 5, _rReach31], // 1001~1150  가로±3 세로±1
    // 가장 좁은 이웃. 여기서만 판을 줄인다.
    [1300, 10, 5, 2, 4, _rReach11], // 1151~1300  가로±1 세로±1

    // 트릭 A. 판을 다시 키워 간다.
    [1400, 8, 5, 2, 8, _rA], // 1301~1400
    [1500, 10, 5, 2, 8, _rA], // 1401~1500
    [1600, 11, 6, 2, 8, _rA], // 1501~1600

    // 트릭 A+B.
    [1700, 8, 5, 2, 8, _rAB], // 1601~1700
    [1800, 10, 5, 2, 8, _rAB],
    [1900, 11, 6, 2, 8, _rAB],

    // 트릭 A+C.
    [2000, 8, 5, 2, 8, _rAC], // 1901~2000
    [2100, 10, 5, 2, 8, _rAC],
    [2200, 11, 6, 2, 8, _rAC],

    // 마지막 구간: 이웃 제한과 트릭이 함께 걸린다.
    [2400, 10, 5, 2, 5, _rReach33A], // 2201~2400
    [2600, 10, 5, 2, 5, _rReach33AB],
    [1 << 30, 10, 5, 2, 5, _rReach33AC], // 2601~
  ];

  // 규칙코드. 표를 const로 두려면 RuleSet을 직접 넣을 수 없어 번호로 적는다.
  static const int _rReach33 = 1;
  static const int _rReach22 = 2;
  static const int _rReach31 = 3;
  static const int _rReach11 = 4;
  static const int _rA = 5;
  static const int _rAB = 6;
  static const int _rAC = 7;
  static const int _rReach33A = 8;
  static const int _rReach33AB = 9;
  static const int _rReach33AC = 10;

  static RuleSet _rulesFor(int code, int perRow) {
    switch (code) {
      case _rReach33:
        return RuleSet.reach(3, 3, perRow: perRow);
      case _rReach22:
        return RuleSet.reach(2, 2, perRow: perRow);
      case _rReach31:
        return RuleSet.reach(3, 1, perRow: perRow);
      case _rReach11:
        return RuleSet.reach(1, 1, perRow: perRow);
      case _rA:
        return const RuleSet(claimEmpties: true);
      case _rAB:
        return const RuleSet(claimEmpties: true, claimMono: true);
      case _rAC:
        return const RuleSet(claimEmpties: true, lockEmptyOrigin: true);
      case _rReach33A:
        return RuleSet(
            reachX: 3, reachY: 3, gridPerRow: perRow, claimEmpties: true);
      case _rReach33AB:
        return RuleSet(
            reachX: 3,
            reachY: 3,
            gridPerRow: perRow,
            claimEmpties: true,
            claimMono: true);
      case _rReach33AC:
        return RuleSet(
            reachX: 3,
            reachY: 3,
            gridPerRow: perRow,
            claimEmpties: true,
            lockEmptyOrigin: true);
      default:
        return RuleSet.classic;
    }
  }

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

    for (final t in _ruleTiers) {
      if (level <= t[0]) {
        return LevelConfig(
          level: level,
          colorCount: t[1],
          capacity: t[2],
          emptyBottles: t[3],
          rules: _rulesFor(t[5], t[4]),
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
    if (level <= 700) return '최고 난이도';
    if (level <= 1300) return '이웃 제한';
    if (level <= 1600) return '전용 병';
    if (level <= 1900) return '굳는 병';
    if (level <= 2200) return '못 비우는 병';
    return '모든 규칙';
  }

  @override
  String toString() =>
      'Lv$level(색 $colorCount, 깊이 $capacity칸, 빈 병 $emptyBottles개, 병 $bottleCount개)';
}
