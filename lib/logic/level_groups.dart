import 'level_config.dart';

/// 중분류 — 병 개수와 층수가 **일정한** 레벨 구간.
///
/// 난이도표의 한 단계가 그대로 한 묶음이 된다. 표와 화면이 어긋날 수 없다.
class LevelGroup {
  final int firstLevel;
  final int lastLevel;
  final int colorCount;
  final int capacity;
  final int emptyBottles;

  const LevelGroup({
    required this.firstLevel,
    required this.lastLevel,
    required this.colorCount,
    required this.capacity,
    required this.emptyBottles,
  });

  int get bottleCount => colorCount + emptyBottles;

  int get levelCount => lastLevel - firstLevel + 1;

  List<int> get levels => [for (var l = firstLevel; l <= lastLevel; l++) l];

  bool contains(int level) => level >= firstLevel && level <= lastLevel;

  /// 목록에 보이는 이름. 이 묶음이 무엇인지가 곧 이름이다.
  String get title => '병 $bottleCount개 · $capacity층';

  /// 한 줄 설명.
  String get subtitle => '레벨 $firstLevel~$lastLevel · 빈 병 $emptyBottles개';

  @override
  String toString() => '$title (레벨 $firstLevel~$lastLevel)';
}

/// 대분류 — 난이도 이름이 같은 중분류들의 묶음.
class DifficultyBand {
  final String name;
  final List<LevelGroup> groups;

  /// 띠마다 다른 색을 주기 위한 값.
  final int accent;

  const DifficultyBand({
    required this.name,
    required this.groups,
    required this.accent,
  });

  int get firstLevel => groups.first.firstLevel;

  int get lastLevel => groups.last.lastLevel;

  int get levelCount => groups.fold(0, (n, g) => n + g.levelCount);

  List<int> get levels => [for (final g in groups) ...g.levels];

  bool contains(int level) => level >= firstLevel && level <= lastLevel;

  /// 이 난이도에서 병이 몇 개까지, 몇 층까지 가는지.
  String get subtitle {
    final bottles = groups.map((g) => g.bottleCount).toList()..sort();
    final depths = groups.map((g) => g.capacity).toSet().toList()..sort();
    final b = bottles.first == bottles.last
        ? '병 ${bottles.first}개'
        : '병 ${bottles.first}~${bottles.last}개';
    final d = depths.length == 1 ? '${depths.first}층' : '${depths.first}~${depths.last}층';
    return '$b · $d';
  }

  @override
  String toString() => '$name (레벨 $firstLevel~$lastLevel)';
}

/// 레벨을 난이도 → 병 구성 → 레벨의 3단으로 묶는다.
///
/// 묶음 경계를 손으로 적지 않고 [LevelConfig]에서 **그대로 읽어 만든다.**
/// 난이도표를 고치면 화면도 저절로 따라오므로 둘이 어긋날 수가 없다.
///
/// **어떤 묶음도 잠기지 않는다.** 첫 판부터 마지막까지 언제든 열 수 있다.
/// 잠금은 실력이 아니라 인내심을 시험하는 장치다. 이 게임은 그런 걸 두지 않는다.
class LevelGroups {
  /// 레벨이 무한하므로 끝없는 구간은 이만큼씩 끊어 보여준다.
  static const int endlessBlock = 50;

  /// 어디까지 펼쳐 둘지. 도달한 곳보다 넉넉히 앞까지 만들어 둔다.
  static int _horizon(int reachedLevel) =>
      reachedLevel + 150 > 700 ? reachedLevel + 150 : 700;

  /// [reachedLevel]까지 도달한 사람에게 보여줄 난이도 목록.
  static List<DifficultyBand> bands(int reachedLevel) {
    final groups = _buildGroups(_horizon(reachedLevel));

    final bands = <DifficultyBand>[];
    var current = <LevelGroup>[];
    String? currentName;

    for (final g in groups) {
      final name = LevelConfig.forLevel(g.firstLevel).difficultyLabel;
      if (currentName != null && name != currentName) {
        bands.add(DifficultyBand(
          name: currentName,
          groups: current,
          accent: bands.length,
        ));
        current = [];
      }
      currentName = name;
      current.add(g);
    }
    if (currentName != null && current.isNotEmpty) {
      bands.add(DifficultyBand(
        name: currentName,
        groups: current,
        accent: bands.length,
      ));
    }
    return bands;
  }

  /// 레벨 1부터 [horizon]까지를 "구성이 같은 구간"으로 끊는다.
  static List<LevelGroup> _buildGroups(int horizon) {
    final groups = <LevelGroup>[];

    var start = 1;
    var config = LevelConfig.forLevel(1);

    for (var lv = 2; lv <= horizon + 1; lv++) {
      final next = lv <= horizon ? LevelConfig.forLevel(lv) : null;

      // 구성이 바뀌거나, 한 묶음이 너무 길어지거나, 끝에 다다르면 여기서 끊는다.
      // 너무 길어지면 레벨 격자가 한 화면을 훌쩍 넘어 고르기 불편해진다.
      final changed = next == null ||
          next.colorCount != config.colorCount ||
          next.capacity != config.capacity ||
          next.emptyBottles != config.emptyBottles ||
          next.difficultyLabel != config.difficultyLabel;
      final tooLong = lv - start >= endlessBlock;

      if (changed || tooLong) {
        groups.add(LevelGroup(
          firstLevel: start,
          lastLevel: lv - 1,
          colorCount: config.colorCount,
          capacity: config.capacity,
          emptyBottles: config.emptyBottles,
        ));
        if (next == null) break;
        start = lv;
        config = next;
      }
    }
    return groups;
  }

  /// [level]이 속한 중분류.
  static LevelGroup groupForLevel(int level) {
    if (level < 1) throw ArgumentError('레벨은 1 이상이어야 합니다: $level');
    for (final b in bands(level)) {
      for (final g in b.groups) {
        if (g.contains(level)) return g;
      }
    }
    throw StateError('레벨 $level이 어느 묶음에도 속하지 않습니다.');
  }

  /// [level]이 속한 대분류.
  static DifficultyBand bandForLevel(int level) {
    if (level < 1) throw ArgumentError('레벨은 1 이상이어야 합니다: $level');
    for (final b in bands(level)) {
      if (b.contains(level)) return b;
    }
    throw StateError('레벨 $level이 어느 난이도에도 속하지 않습니다.');
  }
}
