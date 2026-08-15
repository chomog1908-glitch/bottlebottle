import 'package:bottlebottle/controller/game_controller.dart';
import 'package:bottlebottle/logic/achievements.dart';
import 'package:bottlebottle/model/move.dart';
import 'package:bottlebottle/services/storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('저장한 적이 없으면 null을 준다', () async {
    expect(await Storage().loadGame(), isNull);
  });

  test('저장했다 불러오면 판이 정확히 복원된다', () async {
    final storage = Storage();

    final a = GameController(startLevel: 7);
    // 아무 수나 몇 개 둔다.
    for (var i = 0; i < 5 && !a.isSolved; i++) {
      a.requestHint();
      final h = a.hintMove;
      if (h == null) break;
      a.tapBottle(h.from);
      a.tapBottle(h.to);
    }
    await storage.saveGame(a.level, a.state.history);

    final saved = await storage.loadGame();
    expect(saved, isNotNull);

    final b = GameController();
    b.restore(saved!.level, saved.moves);

    expect(b.level, a.level);
    expect(b.state.toString(), a.state.toString(), reason: '보드가 달라졌습니다.');
    expect(b.moveCount, a.moveCount, reason: '수 개수가 달라졌습니다.');
    expect(b.peakEmptiesUsed, a.peakEmptiesUsed, reason: '빈 병 기록이 달라졌습니다.');
  });

  test('복원 후에도 되돌리기가 끝까지 동작한다', () async {
    final storage = Storage();
    final a = GameController(startLevel: 3);
    // 병을 누르는 순간 힌트 표시가 사라지므로 수를 먼저 붙잡아 둔다.
    for (var i = 0; i < 2; i++) {
      a.requestHint();
      final h = a.hintMove!;
      a.tapBottle(h.from);
      a.tapBottle(h.to);
    }
    await storage.saveGame(a.level, a.state.history);

    final saved = await storage.loadGame();
    final b = GameController()..restore(saved!.level, saved.moves);
    expect(b.moveCount, 2);

    b.undo();
    b.undo();
    expect(b.moveCount, 0);
    expect(b.canUndo, isFalse);
    // 시작 판으로 정확히 돌아왔는지 확인한다.
    expect(b.state.toString(), GameController(startLevel: 3).state.toString());
  });

  test('저장이 깨져 있어도 게임이 죽지 않는다', () async {
    SharedPreferences.setMockInitialValues({'saved_game_v1': '이건 JSON이 아닙니다'});
    expect(await Storage().loadGame(), isNull);
  });

  test('둘 수 없는 수가 섞여 있으면 거기까지만 복원한다', () {
    final c = GameController(startLevel: 2);
    // 첫 수는 유효하고 두 번째는 말이 안 되는 수다.
    c.requestHint();
    final good = c.hintMove!;
    c.restore(2, [
      [good.from, good.to],
      [999, 999],
    ]);
    expect(c.moveCount, 1, reason: '유효한 수까지만 복원돼야 합니다.');
  });

  test('최고 레벨은 올라가기만 하고 내려가지 않는다', () async {
    final s = Storage();
    await s.saveMaxLevel(12);
    expect(await s.loadMaxLevel(), 12);
    await s.saveMaxLevel(5);
    expect(await s.loadMaxLevel(), 12, reason: '낮은 레벨로 덮어쓰면 안 됩니다.');
  });

  test('색약 모드는 기본이 꺼짐이고 저장된다', () async {
    final s = Storage();
    expect(await s.loadShowSymbols(), isFalse);
    await s.saveShowSymbols(true);
    expect(await s.loadShowSymbols(), isTrue);
  });

  group('기록 내보내기 · 불러오기', () {
    test('뽑아낸 글자를 그대로 불러오면 기록이 살아난다', () async {
      final s = Storage();
      await s.saveGame(7, const [Move(from: 0, to: 1, count: 2, color: 3)]);
      await s.saveMaxLevel(42);
      await s.addClearedLevel(7);
      await s.saveStats(const PlayStats(clearedCount: 3, totalMoves: 120));
      await s.recordAchievements(['first_clear'], '2026-08-15');
      await s.saveLargeText(true);

      final backup = await s.exportAll();

      // 기기를 바꾼 셈 치고 저장소를 비운다.
      SharedPreferences.setMockInitialValues({});
      final fresh = Storage();
      expect(await fresh.loadMaxLevel(), 1, reason: '비워진 게 맞는지 먼저 확인한다.');

      expect(await fresh.importAll(backup), isTrue);

      expect(await fresh.loadMaxLevel(), 42);
      expect((await fresh.loadGame())!.level, 7);
      expect(await fresh.loadClearedLevels(), {7});
      expect((await fresh.loadStats()).clearedCount, 3);
      expect((await fresh.loadStats()).totalMoves, 120);
      expect((await fresh.loadAchievementDates())['first_clear'], '2026-08-15');
      expect(await fresh.loadLargeText(), isTrue);
    });

    test('엉뚱한 글자는 거절하고 지금 기록을 건드리지 않는다', () async {
      final s = Storage();
      await s.saveMaxLevel(30);

      expect(await s.importAll('안녕하세요'), isFalse);
      expect(await s.importAll('{"app":"other","data":{}}'), isFalse);
      expect(await s.loadMaxLevel(), 30, reason: '실패한 불러오기가 기록을 지우면 안 됩니다.');
    });

    test('백업에 없는 항목은 그대로 둔다', () async {
      // 예전 형식으로 뽑은 백업에는 나중에 생긴 항목이 없을 수 있다.
      final s = Storage();
      await s.saveMaxLevel(15);

      expect(await s.importAll('{"app":"bottlebottle","data":{}}'), isTrue);
      expect(await s.loadMaxLevel(), 15);
    });
  });
}
