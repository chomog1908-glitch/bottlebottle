import 'package:bottlebottle/controller/game_controller.dart';
import 'package:bottlebottle/logic/achievements.dart';
import 'package:bottlebottle/services/achievement_tracker.dart';
import 'package:bottlebottle/services/storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 컨트롤러에 추적기를 붙인다. 화면이 하는 일과 같은 배선이다.
Future<(GameController, AchievementTracker, List<Achievement>)> _wire({
  int startLevel = 1,
  DateTime? today,
}) async {
  final tracker = AchievementTracker(Storage());
  if (today != null) tracker.now = () => today;
  await tracker.load();

  final earned = <Achievement>[];
  final c = GameController(startLevel: startLevel);
  c.onEvent = (e) async => earned.addAll(await tracker.handle(e, c));
  return (c, tracker, earned);
}

/// 힌트를 눌러가며 끝까지 푼다.
void _solve(GameController c) {
  var guard = 0;
  while (!c.isSolved) {
    c.requestHint();
    final h = c.hintMove!;
    c.tapBottle(h.from);
    c.tapBottle(h.to);
    if (++guard > 500) throw StateError('힌트를 따라갔는데 끝나지 않습니다.');
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('힌트로 한 판을 끝내면 첫 완성이 열리고, 스스로 푼 판으로는 세지 않는다', () async {
    final (c, tracker, earned) = await _wire();

    _solve(c);
    // onEvent가 비동기라 기록이 반영될 틈을 준다.
    await Future<void>.delayed(Duration.zero);

    expect(tracker.stats.clearedCount, 1);
    expect(tracker.stats.hintCount, greaterThan(0));
    expect(tracker.stats.noHintClears, 0, reason: '힌트를 쓴 판이다.');
    expect(tracker.stats.totalMoves, c.moveCount);
    expect([for (final a in earned) a.id], contains('first_clear'));
  });

  test('되돌리기와 건너뛰기가 기록에 남는다', () async {
    final (c, tracker, _) = await _wire();

    // 아무 수나 한 번 둔 뒤 되돌린다.
    c.requestHint();
    final h = c.hintMove!;
    c.tapBottle(h.from);
    c.tapBottle(h.to);
    c.undo();
    c.nextLevel();
    await Future<void>.delayed(Duration.zero);

    expect(tracker.stats.undoCount, 1);
    expect(tracker.stats.skipCount, 1, reason: '안 풀고 넘어갔으므로 건너뛰기다.');
    expect(tracker.stats.maxLevel, 2);
  });

  test('다 풀고 다음 레벨로 가는 것은 건너뛰기가 아니다', () async {
    final (c, tracker, _) = await _wire();

    _solve(c);
    c.nextLevel();
    await Future<void>.delayed(Duration.zero);

    expect(tracker.stats.skipCount, 0);
  });

  test('기록은 저장되고, 다음에 켤 때 이어진다', () async {
    final (c, _, _) = await _wire();
    _solve(c);
    await Future<void>.delayed(Duration.zero);

    // 같은 저장소를 새 추적기로 다시 읽는다. 앱을 껐다 켠 것과 같다.
    final again = AchievementTracker(Storage());
    await again.load();

    expect(again.stats.clearedCount, 1);
    expect(again.earnedCount, greaterThan(0));
    expect(again.earnedOn['first_clear'], isNotNull);
  });

  test('불러오기 전에는 아무것도 세지 않는다', () async {
    // 빈 기록을 저장해 지난 기록을 덮어쓰는 사고를 막는다.
    final tracker = AchievementTracker(Storage());
    final c = GameController();

    final got = await tracker.handle(GameEvent.move, c);

    expect(got, isEmpty);
    expect(tracker.stats.totalMoves, 0);
  });

  test('같은 레벨을 두 번 풀어도 서로 다른 레벨 수는 하나다', () async {
    final (c, tracker, _) = await _wire();

    _solve(c);
    c.restart();
    _solve(c);
    await Future<void>.delayed(Duration.zero);

    expect(tracker.stats.clearedCount, 2);
    expect(tracker.stats.distinctLevelsCleared, 1);
  });

  test('게임을 한 날이 날짜별로 쌓인다', () async {
    final (c1, _, _) = await _wire(today: DateTime(2026, 8, 15));
    c1.requestHint();
    await Future<void>.delayed(Duration.zero);

    final (c2, tracker2, _) = await _wire(today: DateTime(2026, 8, 16));
    c2.requestHint();
    await Future<void>.delayed(Duration.zero);

    expect(tracker2.stats.daysPlayed, 2);
  });
}
