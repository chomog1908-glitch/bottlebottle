import 'level_config.dart';

/// 난이도 한 칸의 진행 상황.
class DifficultyProgress {
  /// 난이도 이름. [LevelConfig.difficultyLabel]과 같은 값이다.
  final String label;

  final int firstLevel;

  /// 이 난이도의 마지막 레벨. 끝이 없는 난이도면 null.
  final int? lastLevel;

  /// 이 난이도에서 클리어한 레벨 수.
  final int cleared;

  /// 분모. 끝이 없는 난이도에서는 **도달한 곳까지**를 분모로 삼는다.
  final int total;

  const DifficultyProgress({
    required this.label,
    required this.firstLevel,
    required this.lastLevel,
    required this.cleared,
    required this.total,
  });

  bool get isEndless => lastLevel == null;

  double get ratio => total == 0 ? 0 : cleared / total;

  /// `레벨 21~55` 또는 `레벨 311~`.
  String get range => '레벨 $firstLevel~${lastLevel ?? ''}';
}

/// 저장된 숫자들을 화면이 그리기 좋은 모양으로 바꾼다.
///
/// **화면에서 계산하지 않는다.** 여기서 하면 화면 없이 시험할 수 있고,
/// "끝이 없는 난이도의 분모는 무엇인가" 같은 판단이 한 곳에만 남는다.
class StatsSummary {
  /// 난이도별로 몇 판이나 끝냈는지.
  ///
  /// 난이도 경계를 손으로 적지 않고 [LevelConfig]에 물어 만든다.
  /// 표와 화면이 어긋날 일이 없다.
  static List<DifficultyProgress> byDifficulty(
    Set<int> clearedLevels,
    int maxLevel,
  ) {
    // 마지막 난이도는 끝이 없으므로, 도달한 곳(또는 그 난이도가 시작하는 곳)까지만 본다.
    final horizon = [maxLevel, 320, if (clearedLevels.isNotEmpty) clearedLevels.reduce((a, b) => a > b ? a : b)]
        .reduce((a, b) => a > b ? a : b);

    final result = <DifficultyProgress>[];
    var start = 1;
    var label = LevelConfig.forLevel(1).difficultyLabel;
    var cleared = 0;
    var total = 0;

    void flush(int endLevel, {required bool endless}) {
      result.add(DifficultyProgress(
        label: label,
        firstLevel: start,
        lastLevel: endless ? null : endLevel,
        cleared: cleared,
        total: total,
      ));
    }

    for (var lv = 1; lv <= horizon; lv++) {
      final name = LevelConfig.forLevel(lv).difficultyLabel;
      if (name != label) {
        flush(lv - 1, endless: false);
        start = lv;
        label = name;
        cleared = 0;
        total = 0;
      }
      total++;
      if (clearedLevels.contains(lv)) cleared++;
    }
    // 마지막 난이도는 레벨이 무한히 이어지므로 끝을 적지 않는다.
    flush(horizon, endless: true);

    return result;
  }

  /// 최근 [days]일의 출석. 오늘이 마지막 칸이다.
  ///
  /// `true`인 날은 게임을 한 날이다. 빈칸이 있다고 나무라는 화면이 아니라,
  /// 지난 두 주가 어땠는지 한눈에 보는 용도다.
  static List<bool> recentActivity(
    Set<String> playedDays,
    DateTime today, {
    int days = 14,
  }) =>
      [
        for (var i = days - 1; i >= 0; i--)
          playedDays.contains(dayKey(today.subtract(Duration(days: i)))),
      ];

  /// `YYYY-MM-DD`. 저장에 쓰는 형식과 같아야 한다.
  static String dayKey(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  /// 클리어한 판 중 힌트도 되돌리기도 없이 끝낸 판의 비율.
  ///
  /// 한 판도 안 끝냈으면 0. 나누기 전에 분모를 확인한다.
  static double soloRatio({required int clearedCount, required int flawlessClears}) =>
      clearedCount == 0 ? 0 : flawlessClears / clearedCount;
}
