import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bottlebottle/logic/achievements.dart';
import 'package:bottlebottle/services/storage.dart';

/// 어머니 폰에서 실제로 뽑은 기록이 그대로 들어오는가.
///
/// 만든 사람이 지어낸 자료가 아니라 **진짜 쓰이고 있는 자료**로 시험한다.
/// 형식을 조금 고쳤을 때 이미 쌓인 기록이 깨지는지는 이걸로만 알 수 있다.
void main() {
  // 2026-09-07에 뽑은 실제 기록. 길어서 필요한 부분만 담았다.
  const real = '{"app":"bottlebottle","format":1,'
      '"exportedAt":"2026-09-07T20:00:42.420494","data":{'
      '"saved_game_v1":"{\\"level\\":431,\\"moves\\":[[3,4],[2,4],[15,4]]}",'
      '"max_level_v1":431,'
      '"cleared_levels_v1":["1","2","3","428","429","430","431"],'
      '"play_stats_v1":"{\\"cleared\\":427,\\"distinct\\":427,\\"maxLevel\\":432,'
      '\\"moves\\":13951,\\"hints\\":200,\\"undos\\":1119,\\"restarts\\":61,'
      '\\"skips\\":4,\\"noHint\\":408,\\"noUndo\\":293,\\"zeroEmpty\\":0,'
      '\\"thrifty\\":28,\\"deepest\\":8,\\"colors\\":15,\\"flawless\\":288,'
      '\\"days\\":[\\"2026-08-15\\",\\"2026-09-06\\"]}",'
      '"achievement_dates_v1":"{\\"first_clear\\":\\"2026-08-15\\",'
      '\\"depth_8\\":\\"2026-09-06\\"}",'
      '"show_symbols_v1":null,"sound_on_v1":false,'
      '"large_text_v1":null,"theme_mode_v1":null}}';

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('실제 기록이 통째로 들어온다', () async {
    final storage = Storage();
    expect(await storage.importAll(real), isTrue);

    expect(await storage.loadMaxLevel(), 431);
    expect((await storage.loadClearedLevels()).contains(430), isTrue);

    final stats = await storage.loadStats();
    expect(stats.clearedCount, 427);
    expect(stats.totalMoves, 13951);
    expect(stats.undoCount, 1119);
    expect(stats.deepestCleared, 8);
  });

  test('쌓아 두신 도전과제가 그대로 남는다', () async {
    final storage = Storage();
    await storage.importAll(real);
    final stats = await storage.loadStats();

    // 427판을 푸셨으니 "50판 클리어"류는 당연히 달성이어야 한다.
    final earned = [
      for (final a in Achievements.all)
        if (a.isEarnedBy(stats)) a.id,
    ];
    expect(earned, isNotEmpty);
    expect(earned.length, greaterThan(15),
        reason: '427판을 푸신 분인데 도전과제가 너무 적게 잡힌다');
  });

  test('예전 저장이라 보드가 없어도 게임이 열린다', () async {
    // 어머니 폰의 저장에는 보드가 없다. 새 코드가 그걸 읽을 수 있어야 한다.
    final storage = Storage();
    await storage.importAll(real);
    final saved = await storage.loadGame();
    expect(saved, isNotNull);
    expect(saved!.level, 431);
    expect(saved.board, isNull, reason: '예전 저장에는 보드가 없다');
  });

  test('설정에 null이 들어 있어도 깨지지 않는다', () async {
    // 실제 기록에는 show_symbols_v1 등이 null이다. 건드리지 않고 넘어가야 한다.
    final storage = Storage();
    expect(await storage.importAll(real), isTrue);
    expect(await storage.loadShowSymbols(), isFalse);
  });
}
