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

  /// 빈 병의 높이. null이면 [capacity]와 같다(= 모든 병이 같은 높이).
  ///
  /// **빈 병을 줄이는 대신 좁힌다.** 빈 병 개수를 2개에서 1개로 떨어뜨리면
  /// 난이도가 계단이 아니라 절벽이 된다. 실제로 어머니가 레벨 500 언저리에서
  /// 막히셨다. 개수는 2개로 두고 높이만 8칸 → 6칸 → 4칸으로 좁히면
  /// 같은 축을 훨씬 촘촘한 계단으로 쓸 수 있다.
  ///
  /// 두 빈 병의 높이를 다르게 줄 수도 있다(큰 것 하나 + 작은 것 하나).
  final List<int>? emptyCapacities;

  /// 색 병의 높이들. null이면 전부 [capacity]다.
  ///
  /// **색 하나가 병 하나를 정확히 채운다**는 약속은 그대로다. 그래서 이 목록이
  /// 곧 색별 칸 수이기도 하다. 5칸 병에 담을 색은 5칸, 3칸 병에 담을 색은 3칸.
  /// 그래야 "가득 차면 완성"이 성립한다.
  ///
  /// 길이가 [colorCount]보다 짧으면 앞에서부터 돌려 쓴다.
  final List<int>? colorCapacities;

  /// [i]번째 색이 차지하는 칸 수 (= 그 색을 담을 병의 높이).
  ///
  /// **같은 높이끼리 모여 있도록** 나눈다. 4,5,4,5…처럼 번갈아 놓으면 판이
  /// 들쭉날쭉해 보여 어지럽다. 4,4,4,5,5,5처럼 모아 두면 계단 모양이 되어
  /// 정돈돼 보이고, "이 색은 낮은 병"이라는 것도 자리로 기억하실 수 있다.
  ///
  /// 색 수가 높이 가짓수로 나누어떨어지지 않으면 앞쪽(낮은 병)에 한 개씩 더 준다.
  int capacityOfColor(int i) {
    final caps = colorCapacities;
    if (caps == null) return capacity;
    final groups = caps.length;
    final base = colorCount ~/ groups;
    final extra = colorCount % groups;
    var start = 0;
    for (var g = 0; g < groups; g++) {
      final count = base + (g < extra ? 1 : 0);
      if (i < start + count) return caps[g];
      start += count;
    }
    return caps.last;
  }

  /// 병마다의 높이. 앞쪽이 색 병, 뒤쪽이 빈 병이다.
  ///
  /// 색 병은 낮은 것부터, 빈 병도 낮은 것부터 놓는다. 그래야 판이 계단처럼
  /// 보이고 어지럽지 않다.
  List<int> get bottleCapacities {
    final empties = [
      for (var i = 0; i < emptyBottles; i++)
        emptyCapacities == null
            ? capacity
            : emptyCapacities![i % emptyCapacities!.length],
    ]..sort();
    return [
      for (var i = 0; i < colorCount; i++) capacityOfColor(i),
      ...empties,
    ];
  }

  /// 병마다 높이가 다른 판인가.
  bool get hasMixedCapacities {
    final caps = bottleCapacities;
    for (final c in caps) {
      if (c != caps.first) return true;
    }
    return false;
  }

  const LevelConfig({
    required this.level,
    required this.colorCount,
    required this.emptyBottles,
    required this.capacity,
    this.rules = RuleSet.classic,
    this.emptyCapacities,
    this.colorCapacities,
  });

  /// 화면에 놓이는 전체 병 수.
  int get bottleCount => colorCount + emptyBottles;

  /// 총 액체 칸 수. 빈 병은 비어 있으므로 세지 않는다.
  ///
  /// 색마다 칸 수가 다를 수 있으므로 곱셈이 아니라 합으로 센다.
  int get totalUnits {
    if (colorCapacities == null) return colorCount * capacity;
    var n = 0;
    for (var i = 0; i < colorCount; i++) {
      n += capacityOfColor(i);
    }
    return n;
  }

  /// 색으로 쓸 수 있는 최대 가짓수. 팔레트가 준비한 색 수와 같아야 한다.
  static const int maxColors = 19;

  /// 병의 최대 깊이.
  static const int maxCapacity = 8;

  /// 마지막 레벨.
  ///
  /// 레벨은 원리상 끝없이 만들 수 있지만, **끝이 없으면 레벨 목록을 그릴 수 없다.**
  /// 예전에는 도달한 곳보다 150레벨 앞까지만 펼쳐 보여줬는데, 그 뒤로는 어차피
  /// 같은 난이도가 반복될 뿐이라 보여줄 것도 없었기 때문이다.
  ///
  /// 이제는 701부터 규칙이 계속 바뀌므로 **앞에 무엇이 있는지가 보여야 한다.**
  /// 어머니가 레벨 431에서 목록을 여셨을 때 700까지밖에 안 보였다.
  /// 그래서 끝을 정하고, 목록은 처음부터 끝까지 통째로 보여준다.
  static const int lastLevel = 2800;

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
    //
    // **빈 병 1개 구간은 여기 없다.** 예전에는 501~700이 빈 병 1개였는데,
    // 2개에서 1개로 떨어지는 것이 계단이 아니라 절벽이었다. 실제로 어머니가
    // 그 언저리에서 막히셨다. 그 구간은 [_lastBandStart] 뒤로 옮겼다.
    // 없앤 것이 아니라 **가장 어려운 곳**으로 자리를 바꾼 것이다.
  ];

  /// 501~700 — 병마다 높이가 다른 구간.
  ///
  /// `[이 레벨까지, 색 수, 기준 깊이, 색 병 높이들, 빈 병 높이들]`
  ///
  /// 색과 깊이는 500에서 천장에 닿았는데, 예전에는 거기서 **빈 병을 2개에서
  /// 1개로** 줄여 난이도를 올렸다. 그게 계단이 아니라 절벽이라 어머니가
  /// 그 언저리에서 막히셨다. 그 구간은 2801~로 옮겼다.
  ///
  /// 대신 여기서는 **병 높이를 섞는다.** 색 하나가 제 병을 정확히 채운다는
  /// 약속은 그대로이므로, 병 높이가 곧 그 색의 칸 수다. 4칸 병에 담을 색은
  /// 4칸, 6칸 병에 담을 색은 6칸이다.
  ///
  /// 색은 19가지로 늘렸고 병도 18개에서 21개로 늘어난다. 500(색15 병17)에서
  /// 판이 작아지지 않는다. **줄어든 것처럼 보이면 퇴행으로 느껴지기 때문이다.**
  /// 난이도는 조각 수로 잰다 — 501에서 44, 700에서 62로 오른다.
  /// (해답 길이는 탐색기의 운을 재는 값이라 쓰지 않는다.)
  static const List<List<Object>> _mixedTiers = [
    // 병 높이를 낮춰 쉽게 만들 수도 있었지만, 그러면 병이 뭉툭해져 보기에
    // 나쁘다. 높이는 유지하고 **색 수와 병 개수**로 난이도를 잡는다.
    // 501은 색12(2줄)로 시작해 580부터 색18(3줄)로 늘어난다.
    // 빈 병은 **가장 큰 높이**로 준다. 작은 빈 병으로 시작하면 처음부터
    // 숨 쉴 곳이 좁아, 뒤에서 좁혀 갈 여지가 없어진다.
    [540, 12, 7, [6, 7], [7, 7]], //  501~ 540  병14 조각38
    [580, 12, 8, [6, 7, 8], [8, 8]], //  541~ 580  병14 조각40
    [620, 18, 7, [5, 6, 7], [7, 7]], //  581~ 620  병20 조각55
    [660, 18, 8, [6, 7, 8], [8, 8]], //  621~ 660  병20 조각59
    // 마지막 구간은 빈 병 하나가 작아진다. 큰 것 하나 + 작은 것 하나가
    // 중간 두 개보다 어렵다(같은 빈칸 총량으로 네 번 비교해 모두 그랬다).
    // 큰 병을 아껴 써야 하므로 빈 병 하나하나가 서로 다른 자원이 된다.
    [700, 18, 8, [6, 7, 8], [8, 6]], //  661~ 700  병20 조각59
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
  ///
  /// ## 격자는 병 수를 나누어떨어지게 잡는다
  ///
  /// 병 16개를 한 줄 5개로 놓으면 마지막 줄에 한 개만 덩그러니 남는다.
  /// 규칙은 이 격자로 거리를 재므로, 그 외톨이 병은 화면에서 보이는 위치와
  /// 규칙이 세는 위치가 어긋나 **바로 옆인데 못 붓는** 일이 생긴다.
  /// (실제로 레벨 701이 5·5·5·1로 놓여 그렇게 보였다.)
  /// 그래서 격자는 반드시 병 수의 약수로 잡는다. 시험이 이걸 지킨다.
  static const List<List<int>> _ruleTiers = [
    // 이웃 제한. 격자를 좁혀 가며 조인다. 판 크기는 그대로.
    [850, 13, 6, 2, 5, _rReach22], //  701~ 850  막히는 짝 26%
    // 규칙이 조여들면 판을 한 단계 낮춘다. 낮추지 않으면 판이 잘 안 만들어지고,
    // 만들어져도 오래 걸린다. (색14 깊이7로 두었더니 10판 중 8판만 나오고
    //  한 판에 최대 3.8초가 걸렸다. 레벨을 넘길 때마다 그만큼 멈춘다는 뜻이다.
    //  색13 깊이6에서는 10판 전부, 평균 0.19초에 나온다.)
    [1000, 10, 5, 2, 4, _rReach21], //  851~1000  막히는 짝 35%
    // 세로만 한 줄로 조인다. 가로가 넉넉해 병이 고립되지 않는다.
    [1150, 10, 5, 2, 3, _rReach21], // 1001~1150  막히는 짝 41%
    // 가장 좁은 이웃. 여기서만 판을 줄인다.
    //
    // ±1/±1은 쓰지 않는다. 어떤 격자로도 열 판 중 두 판이 안 만들어지거나
    // (격자 4), 만들어져도 절반이 싱거웠다(격자 3·6). 가로를 한 칸 넓힌
    // ±2/±1은 열 판 전부, 싱거운 판 없이, 20ms에 나온다.
    // 규칙을 조이는 것이 목적이지 판을 못 만드는 것이 목적이 아니다.
    [1300, 10, 4, 2, 4, _rReach11], // 1151~1300  막히는 짝 56%

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
    [2400, 10, 5, 2, 4, _rReach21A], // 2201~2400
    [2600, 10, 5, 2, 4, _rReach21AB],
    [2800, 10, 5, 2, 4, _rReach21AC], // 2601~2800

    // 옛 501~700이 여기로 왔다. 빈 병이 **하나뿐인** 구간이다.
    //
    // 규칙도 이웃 제한도 없는 순수한 판인데, 숨 쉴 곳이 하나라 가장 어렵다.
    // 다 지나오신 분을 위한 자리다.
    [1 << 30, 15, 8, 1, 0, _rNone], // 2801~  16병
  ];

  /// 마지막 구간(옛 501~700)이 시작하는 레벨.
  static const int _lastBandStart = 2801;

  // 규칙코드. 표를 const로 두려면 RuleSet을 직접 넣을 수 없어 번호로 적는다.
  /// 규칙 없음. 기본 규칙 그대로다.
  static const int _rNone = 0;
  static const int _rReach32 = 1;
  static const int _rReach22 = 2;
  static const int _rReach21 = 3;
  static const int _rReach11 = 4;
  static const int _rA = 5;
  static const int _rAB = 6;
  static const int _rAC = 7;
  static const int _rReach21A = 8;
  static const int _rReach21AB = 9;
  static const int _rReach21AC = 10;

  static RuleSet _rulesFor(int code, int perRow) {
    switch (code) {
      case _rReach32:
        return RuleSet.reach(3, 2, perRow: perRow);
      case _rReach22:
        return RuleSet.reach(2, 2, perRow: perRow);
      case _rReach21:
        return RuleSet.reach(2, 1, perRow: perRow);
      case _rReach11:
        return RuleSet.reach(1, 1, perRow: perRow);
      case _rA:
        return const RuleSet(claimEmpties: true);
      case _rAB:
        return const RuleSet(claimEmpties: true, claimMono: true);
      case _rAC:
        return const RuleSet(claimEmpties: true, lockEmptyOrigin: true);
      case _rReach21A:
        return RuleSet(
            reachX: 2, reachY: 1, gridPerRow: perRow, claimEmpties: true);
      case _rReach21AB:
        return RuleSet(
            reachX: 2,
            reachY: 1,
            gridPerRow: perRow,
            claimEmpties: true,
            claimMono: true);
      case _rReach21AC:
        return RuleSet(
            reachX: 2,
            reachY: 1,
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

    for (final t in _mixedTiers) {
      if (level <= (t[0] as int)) {
        return LevelConfig(
          level: level,
          colorCount: t[1] as int,
          capacity: t[2] as int,
          emptyBottles: (t[4] as List<int>).length,
          colorCapacities: t[3] as List<int>,
          emptyCapacities: t[4] as List<int>,
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
    if (level <= 500) return '최고 난이도';
    if (level <= 700) return '들쭉날쭉';
    if (level <= 700) return '최고 난이도';
    if (level <= 1300) return '이웃 제한';
    if (level <= 1600) return '전용 병';
    if (level <= 1900) return '굳는 병';
    if (level <= 2200) return '못 비우는 병';
    if (level < _lastBandStart) return '모든 규칙';
    return '빈 병 하나';
  }

  @override
  String toString() =>
      'Lv$level(색 $colorCount, 깊이 $capacity칸, 빈 병 $emptyBottles개, 병 $bottleCount개)';
}
