import '../controller/game_controller.dart';
import '../logic/achievements.dart';
import 'storage.dart';

/// 게임에서 일어난 일을 기록으로 옮기고, 새로 얻은 도전과제를 알려준다.
///
/// 화면과 컨트롤러 사이에 이걸 끼워 두는 이유: 컨트롤러는 규칙만 알아야 하고,
/// 화면은 무엇을 축하할지만 알면 된다. **무엇을 세는지**는 이 한 곳에만 있다.
class AchievementTracker {
  AchievementTracker(this._storage);

  final Storage _storage;

  /// 지금까지 쌓인 기록. 불러오기 전에는 빈 기록이다.
  PlayStats stats = const PlayStats();

  /// 도전과제를 얻은 날짜. `id → YYYY-MM-DD`.
  Map<String, String> earnedOn = const {};

  /// 이미 클리어해 본 레벨. "서로 다른 레벨"을 세는 데 쓴다.
  Set<int> _cleared = {};

  /// 오늘 날짜를 대신 정해 준다. 테스트에서 날짜를 고정하는 데 쓴다.
  DateTime Function() now = DateTime.now;

  bool _loaded = false;

  /// 저장된 기록을 불러온다. 화면이 뜰 때 한 번 부른다.
  Future<void> load() async {
    stats = await _storage.loadStats();
    earnedOn = await _storage.loadAchievementDates();
    _cleared = await _storage.loadClearedLevels();
    _loaded = true;

    // 기록상 이미 넘어선 것 가운데 날짜가 없는 것을 채워 둔다.
    //
    // 예전 저장에는 계산으로만 켜지던 것들이 있어 날짜가 비어 있다. 지금 적어
    // 두어야 나중에 목표를 손대도 그대로 남는다. 날짜는 오늘로 적을 수밖에
    // 없지만, 배지가 꺼지는 것보다는 날짜가 늦은 편이 낫다.
    final missing = [
      for (final a in Achievements.all)
        if (a.isEarnedBy(stats) && !earnedOn.containsKey(a.id)) a.id,
    ];
    if (missing.isNotEmpty) {
      final day = _today();
      await _storage.recordAchievements(missing, day);
      earnedOn = {...earnedOn, for (final id in missing) id: day};
    }
  }

  /// 이미 얻어 둔 도전과제의 이름들.
  ///
  /// 날짜가 적혀 있다는 것이 곧 그때 얻었다는 뜻이다. 따로 목록을 두지 않고
  /// 이걸 쓴다 — 두 곳에 적으면 언젠가 서로 어긋난다.
  Set<String> get earnedIds => earnedOn.keys.toSet();

  /// 얻은 도전과제 수 / 전체 수.
  int get earnedCount => Achievements.earnedIn(stats, earnedIds).length;

  int get totalCount => Achievements.all.length;

  /// 사건 하나를 기록에 반영하고, **이번에 새로 얻은** 도전과제를 돌려준다.
  ///
  /// 저장이 아직 안 불러와졌다면 아무것도 세지 않는다.
  /// 빈 기록 위에 덮어써서 지난 기록을 날리는 것이 최악이기 때문이다.
  Future<List<Achievement>> handle(GameEvent event, GameController game) async {
    if (!_loaded) return const [];

    final before = stats;
    var next = stats.afterPlayOn(_today());

    switch (event) {
      case GameEvent.move:
        next = next.afterMove();
      case GameEvent.hint:
        next = next.afterHint();
      case GameEvent.undo:
        next = next.afterUndo();
      case GameEvent.restart:
        next = next.afterRestart();
      case GameEvent.skip:
        next = next.afterSkip().afterReach(game.level + 1);
      case GameEvent.solved:
        final record = game.clearRecord;
        next = next
            .afterClear(record, firstTime: !_cleared.contains(record.level))
            .afterReach(record.level + 1);
        _cleared.add(record.level);
    }

    stats = next;
    await _storage.saveStats(stats);

    final fresh = Achievements.newlyEarned(before, stats, earnedIds);
    if (fresh.isNotEmpty) {
      final day = _today();
      await _storage.recordAchievements([for (final a in fresh) a.id], day);
      earnedOn = {
        ...earnedOn,
        for (final a in fresh) a.id: earnedOn[a.id] ?? day,
      };
    }
    return fresh;
  }

  /// `YYYY-MM-DD`. 날짜만 쓰므로 시간대 변환은 하지 않는다.
  String _today() {
    final d = now();
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }
}
