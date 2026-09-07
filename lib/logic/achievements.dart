import 'dart:math';

/// 한 판을 끝냈을 때의 요약.
///
/// 도전과제 판정에 필요한 것만 담는다. 보드 내용은 이미 지나간 일이라 필요 없다.
class ClearRecord {
  final int level;

  /// 그 판에서 둔 수.
  final int moves;

  /// 그 판에서 힌트를 누른 횟수.
  final int hintsUsed;

  /// 그 판에서 되돌린 횟수.
  final int undosUsed;

  /// 그 판을 푸는 동안 **동시에** 점유했던 빈 병 수의 최대값.
  final int peakEmptiesUsed;

  /// 그 판이 처음에 준 빈 병 수.
  final int emptyBudget;

  /// 병 깊이.
  final int capacity;

  /// 색 가짓수.
  final int colorCount;

  const ClearRecord({
    required this.level,
    required this.moves,
    required this.hintsUsed,
    required this.undosUsed,
    required this.peakEmptiesUsed,
    required this.emptyBudget,
    required this.capacity,
    required this.colorCount,
  });
}

/// 지금까지 쌓인 기록.
///
/// **불변이다.** 기록을 더할 때마다 새 객체를 만든다.
/// 이렇게 해야 "이번 판으로 새로 얻은 도전과제"를 이전 기록과 비교해 알아낼 수 있다.
class PlayStats {
  /// 클리어한 판의 수. 같은 레벨을 두 번 풀면 두 번 센다.
  final int clearedCount;

  /// 서로 다른 레벨을 몇 개나 클리어했는가.
  final int distinctLevelsCleared;

  /// 도달한 최고 레벨.
  final int maxLevel;

  /// 지금까지 둔 수의 총합.
  final int totalMoves;

  final int hintCount;
  final int undoCount;
  final int restartCount;
  final int skipCount;

  /// 힌트를 한 번도 안 누르고 끝낸 판의 수.
  final int noHintClears;

  /// 되돌리기를 한 번도 안 하고 끝낸 판의 수.
  final int noUndoClears;

  /// 빈 병을 **한 개도** 쓰지 않고 끝낸 판의 수.
  final int zeroEmptyClears;

  /// 받은 빈 병보다 **적게** 쓰고 끝낸 판의 수.
  final int thriftyClears;

  /// 클리어해 본 가장 깊은 병.
  final int deepestCleared;

  /// 클리어해 본 가장 많은 색.
  final int mostColorsCleared;

  /// 한 판에서 힌트도 되돌리기도 없이 끝낸 판의 수.
  final int flawlessClears;

  /// 게임을 한 날짜들(`YYYY-MM-DD`). 며칠에 걸쳐 즐겼는지를 센다.
  final Set<String> playedDays;

  const PlayStats({
    this.clearedCount = 0,
    this.distinctLevelsCleared = 0,
    this.maxLevel = 1,
    this.totalMoves = 0,
    this.hintCount = 0,
    this.undoCount = 0,
    this.restartCount = 0,
    this.skipCount = 0,
    this.noHintClears = 0,
    this.noUndoClears = 0,
    this.zeroEmptyClears = 0,
    this.thriftyClears = 0,
    this.deepestCleared = 0,
    this.mostColorsCleared = 0,
    this.flawlessClears = 0,
    this.playedDays = const {},
  });

  int get daysPlayed => playedDays.length;

  PlayStats copyWith({
    int? clearedCount,
    int? distinctLevelsCleared,
    int? maxLevel,
    int? totalMoves,
    int? hintCount,
    int? undoCount,
    int? restartCount,
    int? skipCount,
    int? noHintClears,
    int? noUndoClears,
    int? zeroEmptyClears,
    int? thriftyClears,
    int? deepestCleared,
    int? mostColorsCleared,
    int? flawlessClears,
    Set<String>? playedDays,
  }) =>
      PlayStats(
        clearedCount: clearedCount ?? this.clearedCount,
        distinctLevelsCleared:
            distinctLevelsCleared ?? this.distinctLevelsCleared,
        maxLevel: maxLevel ?? this.maxLevel,
        totalMoves: totalMoves ?? this.totalMoves,
        hintCount: hintCount ?? this.hintCount,
        undoCount: undoCount ?? this.undoCount,
        restartCount: restartCount ?? this.restartCount,
        skipCount: skipCount ?? this.skipCount,
        noHintClears: noHintClears ?? this.noHintClears,
        noUndoClears: noUndoClears ?? this.noUndoClears,
        zeroEmptyClears: zeroEmptyClears ?? this.zeroEmptyClears,
        thriftyClears: thriftyClears ?? this.thriftyClears,
        deepestCleared: deepestCleared ?? this.deepestCleared,
        mostColorsCleared: mostColorsCleared ?? this.mostColorsCleared,
        flawlessClears: flawlessClears ?? this.flawlessClears,
        playedDays: playedDays ?? this.playedDays,
      );

  /// 판 하나를 끝낸 결과를 반영한다.
  ///
  /// [firstTime]은 그 레벨을 **처음** 클리어했는지 여부다.
  /// 같은 레벨을 다시 풀어도 총 클리어 수는 늘지만, "서로 다른 레벨" 수는 늘지 않는다.
  PlayStats afterClear(ClearRecord r, {required bool firstTime}) => copyWith(
        clearedCount: clearedCount + 1,
        distinctLevelsCleared:
            firstTime ? distinctLevelsCleared + 1 : distinctLevelsCleared,
        maxLevel: max(maxLevel, r.level),
        noHintClears: r.hintsUsed == 0 ? noHintClears + 1 : noHintClears,
        noUndoClears: r.undosUsed == 0 ? noUndoClears + 1 : noUndoClears,
        flawlessClears: r.hintsUsed == 0 && r.undosUsed == 0
            ? flawlessClears + 1
            : flawlessClears,
        zeroEmptyClears:
            r.peakEmptiesUsed == 0 ? zeroEmptyClears + 1 : zeroEmptyClears,
        thriftyClears: r.peakEmptiesUsed < r.emptyBudget
            ? thriftyClears + 1
            : thriftyClears,
        deepestCleared: max(deepestCleared, r.capacity),
        mostColorsCleared: max(mostColorsCleared, r.colorCount),
      );

  /// 한 수를 두었다.
  PlayStats afterMove() => copyWith(totalMoves: totalMoves + 1);

  PlayStats afterHint() => copyWith(hintCount: hintCount + 1);

  PlayStats afterUndo() => copyWith(undoCount: undoCount + 1);

  PlayStats afterRestart() => copyWith(restartCount: restartCount + 1);

  PlayStats afterSkip() => copyWith(skipCount: skipCount + 1);

  /// 레벨에 발을 들였다. 클리어하지 않아도 도달 기록은 남는다.
  PlayStats afterReach(int level) => copyWith(maxLevel: max(maxLevel, level));

  /// [day]는 `YYYY-MM-DD` 형식.
  PlayStats afterPlayOn(String day) =>
      playedDays.contains(day) ? this : copyWith(playedDays: {...playedDays, day});

  Map<String, dynamic> toJson() => {
        'cleared': clearedCount,
        'distinct': distinctLevelsCleared,
        'maxLevel': maxLevel,
        'moves': totalMoves,
        'hints': hintCount,
        'undos': undoCount,
        'restarts': restartCount,
        'skips': skipCount,
        'noHint': noHintClears,
        'noUndo': noUndoClears,
        'zeroEmpty': zeroEmptyClears,
        'thrifty': thriftyClears,
        'deepest': deepestCleared,
        'colors': mostColorsCleared,
        'flawless': flawlessClears,
        'days': playedDays.toList()..sort(),
      };

  /// 저장이 깨졌거나 예전 형식이어도 **읽을 수 있는 만큼만** 읽는다.
  ///
  /// 기록 하나 때문에 게임이 안 켜지는 일은 없어야 한다.
  factory PlayStats.fromJson(Map<String, dynamic> j) {
    int n(String key) => j[key] is int ? j[key] as int : 0;
    return PlayStats(
      clearedCount: n('cleared'),
      distinctLevelsCleared: n('distinct'),
      maxLevel: max(1, n('maxLevel')),
      totalMoves: n('moves'),
      hintCount: n('hints'),
      undoCount: n('undos'),
      restartCount: n('restarts'),
      skipCount: n('skips'),
      noHintClears: n('noHint'),
      noUndoClears: n('noUndo'),
      zeroEmptyClears: n('zeroEmpty'),
      thriftyClears: n('thrifty'),
      deepestCleared: n('deepest'),
      mostColorsCleared: n('colors'),
      flawlessClears: n('flawless'),
      playedDays: {
        for (final d in (j['days'] is List ? j['days'] as List : const []))
          if (d is String) d,
      },
    );
  }
}

/// 도전과제 묶음. 화면에서 칸을 나누는 데 쓴다.
enum AchievementGroup {
  journey('여정'),
  depth('깊은 병'),
  thrift('아껴 쓰기'),
  solo('스스로'),
  habit('꾸준함');

  const AchievementGroup(this.label);

  final String label;
}

/// 도전과제의 급. 화면에서 색이 달라진다.
enum AchievementTier { bronze, silver, gold, rainbow }

/// 도전과제 하나.
///
/// 판정은 **누적 기록만 보고** 한다. 그래야 언제 계산해도 같은 답이 나오고,
/// 저장된 목록이 날아가도 기록만 있으면 그대로 복원된다.
class Achievement {
  final String id;
  final String name;

  /// 무엇을 하면 되는지 한 줄로. 아직 못 얻었을 때 보여준다.
  final String description;

  /// 얻고 나면 보여줄 칭찬 한마디.
  final String praise;

  final String emoji;
  final AchievementGroup group;
  final AchievementTier tier;

  /// 목표 수치.
  final int target;

  /// 기록에서 지금까지의 수치를 꺼낸다.
  final int Function(PlayStats) measure;

  const Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.praise,
    required this.emoji,
    required this.group,
    required this.tier,
    required this.target,
    required this.measure,
  });

  /// 지금까지의 진행도. 목표를 넘어가도 목표에서 멈춘 값을 준다.
  int progress(PlayStats s) => min(measure(s), target);

  bool isEarnedBy(PlayStats s) => measure(s) >= target;

  /// 0.0 ~ 1.0. 진행 막대에 쓴다.
  double ratio(PlayStats s) => target == 0 ? 1 : progress(s) / target;
}

/// 도전과제 목록과 판정.
///
/// **어떤 도전과제도 보상을 주지 않는다.** 레벨을 열어주지도, 힌트를 주지도 않는다.
/// 순전히 지나온 길을 돌아보는 용도다. 이 게임에는 압박이 될 만한 장치를 두지 않는다.
///
/// 같은 이유로 **"힌트를 쓰지 마라"는 식의 도전과제는 넣지 않았다.**
/// 스스로 푼 판을 칭찬할 뿐, 힌트를 쓴 판을 깎지 않는다. 힌트는 얼마든지 써도 된다.
class Achievements {
  static final List<Achievement> all = [
    // ── 여정 ───────────────────────────────────────────────
    Achievement(
      id: 'first_clear',
      name: '첫 완성',
      description: '한 판을 끝까지 맞춘다',
      praise: '여기서 시작했습니다.',
      emoji: '🌱',
      group: AchievementGroup.journey,
      tier: AchievementTier.bronze,
      target: 1,
      measure: (s) => s.clearedCount,
    ),
    Achievement(
      id: 'clear_10',
      name: '열 판',
      description: '열 판을 완성한다',
      praise: '손에 익었습니다.',
      emoji: '🫙',
      group: AchievementGroup.journey,
      tier: AchievementTier.bronze,
      target: 10,
      measure: (s) => s.clearedCount,
    ),
    Achievement(
      id: 'clear_50',
      name: '쉰 판',
      description: '쉰 판을 완성한다',
      praise: '한 선반을 다 채웠습니다.',
      emoji: '🧊',
      group: AchievementGroup.journey,
      tier: AchievementTier.silver,
      target: 50,
      measure: (s) => s.clearedCount,
    ),
    Achievement(
      id: 'clear_150',
      name: '백쉰 판',
      description: '백쉰 판을 완성한다',
      praise: '이쯤이면 전문가입니다.',
      emoji: '🏺',
      group: AchievementGroup.journey,
      tier: AchievementTier.gold,
      target: 150,
      measure: (s) => s.clearedCount,
    ),
    Achievement(
      id: 'reach_50',
      name: '레벨 50',
      description: '레벨 50에 닿는다',
      praise: '색이 제법 늘었습니다.',
      emoji: '🚩',
      group: AchievementGroup.journey,
      tier: AchievementTier.bronze,
      target: 50,
      measure: (s) => s.maxLevel,
    ),
    Achievement(
      id: 'reach_200',
      name: '레벨 200',
      description: '레벨 200에 닿는다',
      praise: '병이 깊어지는 구간을 넘었습니다.',
      emoji: '⛰️',
      group: AchievementGroup.journey,
      tier: AchievementTier.silver,
      target: 200,
      measure: (s) => s.maxLevel,
    ),
    Achievement(
      id: 'reach_500',
      name: '마지막 선반',
      description: '레벨 500에 닿는다',
      praise: '정해진 선반의 끝까지 왔습니다.',
      emoji: '🏔️',
      group: AchievementGroup.journey,
      tier: AchievementTier.gold,
      target: 500,
      measure: (s) => s.maxLevel,
    ),
    Achievement(
      id: 'reach_endless',
      name: '끝없는 선반',
      description: '레벨 501에 발을 들인다',
      praise: '여기서부터는 끝이 없습니다.',
      emoji: '♾️',
      group: AchievementGroup.journey,
      tier: AchievementTier.rainbow,
      target: 501,
      measure: (s) => s.maxLevel,
    ),
    Achievement(
      id: 'moves_1000',
      name: '천 수',
      description: '누적 천 수를 둔다',
      praise: '물을 참 많이도 옮기셨습니다.',
      emoji: '💧',
      group: AchievementGroup.journey,
      tier: AchievementTier.silver,
      target: 1000,
      measure: (s) => s.totalMoves,
    ),
    Achievement(
      id: 'moves_10000',
      name: '만 수',
      description: '누적 만 수를 둔다',
      praise: '이 정도면 물길을 낸 셈입니다.',
      emoji: '🌊',
      group: AchievementGroup.journey,
      tier: AchievementTier.gold,
      target: 10000,
      measure: (s) => s.totalMoves,
    ),

    // ── 깊은 병 ────────────────────────────────────────────
    Achievement(
      id: 'depth_5',
      name: '다섯 칸',
      description: '깊이 5칸짜리 판을 완성한다',
      praise: '한 칸 더 깊어졌습니다.',
      emoji: '🥄',
      group: AchievementGroup.depth,
      tier: AchievementTier.bronze,
      target: 5,
      measure: (s) => s.deepestCleared,
    ),
    Achievement(
      id: 'depth_6',
      name: '여섯 칸',
      description: '깊이 6칸짜리 판을 완성한다',
      praise: '바닥이 멀어졌습니다.',
      emoji: '🪣',
      group: AchievementGroup.depth,
      tier: AchievementTier.silver,
      target: 6,
      measure: (s) => s.deepestCleared,
    ),
    Achievement(
      id: 'depth_7',
      name: '일곱 칸',
      description: '깊이 7칸짜리 판을 완성한다',
      praise: '이제 멀리 내다보십니다.',
      emoji: '🕳️',
      group: AchievementGroup.depth,
      tier: AchievementTier.gold,
      target: 7,
      measure: (s) => s.deepestCleared,
    ),
    Achievement(
      id: 'depth_8',
      name: '여덟 칸',
      description: '깊이 8칸짜리 판을 완성한다',
      praise: '가장 깊은 병까지 비웠습니다.',
      emoji: '🗼',
      group: AchievementGroup.depth,
      tier: AchievementTier.rainbow,
      target: 8,
      measure: (s) => s.deepestCleared,
    ),
    Achievement(
      id: 'colors_12',
      name: '열두 빛깔',
      description: '색 12가지짜리 판을 완성한다',
      praise: '눈이 밝으십니다.',
      emoji: '🎨',
      group: AchievementGroup.depth,
      tier: AchievementTier.silver,
      target: 12,
      measure: (s) => s.mostColorsCleared,
    ),
    Achievement(
      id: 'colors_15',
      name: '열다섯 빛깔',
      description: '색 15가지짜리 판을 완성한다',
      praise: '이 게임의 모든 색을 다뤘습니다.',
      emoji: '🌈',
      group: AchievementGroup.depth,
      tier: AchievementTier.rainbow,
      target: 15,
      measure: (s) => s.mostColorsCleared,
    ),

    // ── 아껴 쓰기 ──────────────────────────────────────────
    Achievement(
      id: 'thrifty_1',
      name: '아껴 쓴 한 판',
      description: '받은 빈 병보다 적게 쓰고 완성한다',
      praise: '빈 병은 이 게임의 진짜 자원입니다.',
      emoji: '🪶',
      group: AchievementGroup.thrift,
      tier: AchievementTier.bronze,
      target: 1,
      measure: (s) => s.thriftyClears,
    ),
    Achievement(
      id: 'thrifty_20',
      name: '알뜰한 손',
      description: '빈 병을 아껴 스무 판을 완성한다',
      praise: '한 번 아낀 게 우연이 아니었습니다.',
      emoji: '🧵',
      group: AchievementGroup.thrift,
      tier: AchievementTier.silver,
      target: 20,
      measure: (s) => s.thriftyClears,
    ),
    Achievement(
      id: 'zero_empty_1',
      name: '빈 병 없이',
      description: '빈 병을 한 개도 쓰지 않고 완성한다',
      praise: '숨 쉴 곳 없이도 길을 찾으셨습니다.',
      emoji: '🎯',
      group: AchievementGroup.thrift,
      tier: AchievementTier.gold,
      target: 1,
      measure: (s) => s.zeroEmptyClears,
    ),
    Achievement(
      id: 'zero_empty_10',
      name: '빈 병 없이 열 판',
      description: '빈 병을 한 개도 쓰지 않고 열 판을 완성한다',
      praise: '이건 운이 아닙니다.',
      emoji: '💎',
      group: AchievementGroup.thrift,
      tier: AchievementTier.rainbow,
      target: 10,
      measure: (s) => s.zeroEmptyClears,
    ),

    // ── 스스로 ─────────────────────────────────────────────
    Achievement(
      id: 'no_hint_1',
      name: '혼자 힘으로',
      description: '힌트 없이 한 판을 완성한다',
      praise: '힌트는 언제든 쓰셔도 됩니다. 다만 오늘은 안 쓰셨네요.',
      emoji: '🧭',
      group: AchievementGroup.solo,
      tier: AchievementTier.bronze,
      target: 1,
      measure: (s) => s.noHintClears,
    ),
    Achievement(
      id: 'no_hint_30',
      name: '길눈이 밝다',
      description: '힌트 없이 서른 판을 완성한다',
      praise: '길을 외우신 게 아니라 읽으시는 겁니다.',
      emoji: '🔭',
      group: AchievementGroup.solo,
      tier: AchievementTier.silver,
      target: 30,
      measure: (s) => s.noHintClears,
    ),
    Achievement(
      id: 'no_undo_10',
      name: '무르지 않기',
      description: '되돌리기 없이 열 판을 완성한다',
      praise: '한 수 한 수를 신중히 두셨습니다.',
      emoji: '🪨',
      group: AchievementGroup.solo,
      tier: AchievementTier.silver,
      target: 10,
      measure: (s) => s.noUndoClears,
    ),
    Achievement(
      id: 'flawless_1',
      name: '단번에',
      description: '힌트도 되돌리기도 없이 한 판을 완성한다',
      praise: '처음부터 끝까지 스스로.',
      emoji: '✨',
      group: AchievementGroup.solo,
      tier: AchievementTier.gold,
      target: 1,
      measure: (s) => s.flawlessClears,
    ),
    Achievement(
      id: 'flawless_25',
      name: '단번에 스물다섯 판',
      description: '힌트도 되돌리기도 없이 스물다섯 판을 완성한다',
      praise: '이제 판이 눈에 먼저 보이시는군요.',
      emoji: '👑',
      group: AchievementGroup.solo,
      tier: AchievementTier.rainbow,
      target: 25,
      measure: (s) => s.flawlessClears,
    ),

    // ── 꾸준함 ─────────────────────────────────────────────
    Achievement(
      id: 'days_3',
      name: '사흘',
      description: '사흘에 걸쳐 게임을 한다',
      praise: '또 켜 주셨습니다.',
      emoji: '🌤️',
      group: AchievementGroup.habit,
      tier: AchievementTier.bronze,
      target: 3,
      measure: (s) => s.daysPlayed,
    ),
    Achievement(
      id: 'days_10',
      name: '열흘',
      description: '열흘에 걸쳐 게임을 한다',
      praise: '이 앱이 하는 일을 하고 있습니다.',
      emoji: '📅',
      group: AchievementGroup.habit,
      tier: AchievementTier.silver,
      target: 10,
      measure: (s) => s.daysPlayed,
    ),
    Achievement(
      id: 'days_30',
      name: '서른 날',
      description: '서른 날에 걸쳐 게임을 한다',
      praise: '만들길 잘했습니다.',
      emoji: '🗓️',
      group: AchievementGroup.habit,
      tier: AchievementTier.gold,
      target: 30,
      measure: (s) => s.daysPlayed,
    ),
    Achievement(
      id: 'distinct_100',
      name: '백 개의 문',
      description: '서로 다른 레벨 100개를 완성한다',
      praise: '같은 판을 다시 푼 게 아니라, 백 개의 판을 푸셨습니다.',
      emoji: '🚪',
      group: AchievementGroup.habit,
      tier: AchievementTier.gold,
      target: 100,
      measure: (s) => s.distinctLevelsCleared,
    ),
  ];

  static Achievement byId(String id) => all.firstWhere((a) => a.id == id);

  /// [stats] 기준으로 얻은 도전과제들.
  ///
  /// [alreadyEarned]에 든 것은 지금 기준을 못 넘어도 **얻은 것으로 친다.**
  /// 한 번 드린 것을 도로 가져가지 않기 위해서다. 자세한 이유는 [isEarned] 참고.
  static List<Achievement> earnedIn(PlayStats stats,
          [Set<String> alreadyEarned = const {}]) =>
      [for (final a in all) if (isEarned(a, stats, alreadyEarned)) a];

  /// 이 도전과제를 얻었는가.
  ///
  /// 기록으로 계산한 결과 **또는** 예전에 얻어 둔 것. 둘 중 하나면 얻은 것이다.
  ///
  /// 계산만으로 판단하면, 나중에 목표를 손대는 순간(예: "50판"을 "60판"으로)
  /// **이미 드린 도전과제가 조용히 취소된다.** 날짜는 남아 있는데 배지만 꺼진다.
  /// 어머니가 427판을 푸시며 모으신 것을 내 사정으로 도로 가져가는 셈이다.
  ///
  /// 그래서 얻은 것은 저장해 두고, 계산 결과와 **합집합**으로 본다.
  /// 목표를 낮추면 새로 얻고, 올려도 이미 얻은 것은 그대로 남는다.
  static bool isEarned(
    Achievement a,
    PlayStats stats, [
    Set<String> alreadyEarned = const {},
  ]) =>
      alreadyEarned.contains(a.id) || a.isEarnedBy(stats);

  static Set<String> earnedIds(PlayStats stats,
          [Set<String> alreadyEarned = const {}]) =>
      {for (final a in earnedIn(stats, alreadyEarned)) a.id};

  /// [before]에서 [after]로 오면서 **새로 얻은** 것들.
  ///
  /// 화면에 축하를 띄우는 데 쓴다. 목록 순서를 유지해 항상 같은 순서로 보여준다.
  /// [alreadyEarned]에 든 것은 새로 얻은 것이 아니다. 축하를 두 번 띄우지 않는다.
  static List<Achievement> newlyEarned(
    PlayStats before,
    PlayStats after, [
    Set<String> alreadyEarned = const {},
  ]) =>
      [
        for (final a in all)
          if (!isEarned(a, before, alreadyEarned) && a.isEarnedBy(after)) a,
      ];

  /// 그룹별로 나눈 목록. 화면에서 칸을 나누는 데 쓴다.
  static Map<AchievementGroup, List<Achievement>> byGroup() {
    final map = <AchievementGroup, List<Achievement>>{
      for (final g in AchievementGroup.values) g: [],
    };
    for (final a in all) {
      map[a.group]!.add(a);
    }
    return map;
  }
}
