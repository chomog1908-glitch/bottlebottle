import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bottlebottle/controller/game_controller.dart';
import 'package:bottlebottle/services/storage.dart';

/// 생성기가 바뀌어도 두시던 판이 살아남는가.
///
/// 이건 실제로 겪은 일이다. 레벨 432가 열리지 않던 것을 고치면서 셔플이 난수를
/// 한 번 더 뽑게 되었고, 그 한 번이 난수 흐름을 밀어 레벨 1~700 중 699개의 판이
/// 바뀌었다. 저장된 수순은 첫 수부터 재생되지 않았다.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('시작 보드를 저장하면 판이 달라져도 그대로 복원된다', () async {
    final storage = Storage();

    // 어머니가 레벨 5를 몇 수 두셨다고 하자.
    final c = GameController(startLevel: 5);
    final before = c.state.bottles;
    var played = 0;
    for (final m in c.state.legalMoves().take(3)) {
      if (c.state.pour(m.from, m.to) != null) played++;
    }
    expect(played, greaterThan(0), reason: '둘 수 있는 수가 있어야 한다');
    final boardAfter = c.state.bottles;

    await storage.saveGame(5, c.state.history, board: c.startingBoard);

    // 저장된 보드를 쓰므로 생성기의 변화와 무관하게 복원되어야 한다.
    final saved = await storage.loadGame();
    expect(saved, isNotNull);
    expect(saved!.board, isNotNull, reason: '보드가 저장되지 않았다');

    final restored = GameController(startLevel: 5);
    restored.restore(saved.level, saved.moves, board: saved.board);

    expect(restored.state.bottles, boardAfter, reason: '보드가 복원되지 않았다');
    expect(restored.state.moveCount, played, reason: '수순이 복원되지 않았다');
    // 시작 보드도 그대로여야 "다시 시작"이 같은 판으로 간다.
    expect(restored.startingBoard, before);
  });

  test('생성기가 만들지 않는 판을 저장해도 그대로 열린다', () async {
    // 앞 시험은 같은 생성기를 쓰므로 "판이 바뀌어도 살아남는다"를 증명하지 못한다.
    // 여기서는 생성기가 절대 만들지 않을 판을 직접 넣어, 저장된 보드가
    // 정말로 쓰이는지 확인한다. 생성기를 고쳐도 이 시험은 그대로 통과한다.
    final storage = Storage();
    // 레벨 1은 색 4개 · 깊이 4칸 · 병 6개다. 그 규격에 맞는 아무 판이나 짓는다.
    const handmade = [
      [0, 1, 2, 3],
      [3, 2, 1, 0],
      [0, 0, 1, 1],
      [2, 2, 3, 3],
      <int>[],
      <int>[],
    ];
    await storage.saveGame(1, const [], board: handmade);

    final saved = await storage.loadGame();
    final c = GameController(startLevel: 1);
    c.restore(saved!.level, saved.moves, board: saved.board);

    expect(c.state.bottles, handmade, reason: '저장해 둔 판이 아니라 새로 만든 판이 열렸다');
    // 다시 시작을 눌러도 저장해 둔 판으로 돌아가야 한다.
    c.restart();
    expect(c.state.bottles, handmade, reason: '다시 시작하니 다른 판이 되었다');
  });

  test('저장된 보드로 복원해도 되돌리기가 살아 있다', () async {
    // 지금 보드만 저장하면 보드와 되돌리기가 따로 놀아 여기서 깨진다.
    final storage = Storage();
    final c = GameController(startLevel: 7);
    final start = c.state.bottles;
    for (final m in c.state.legalMoves().take(2)) {
      c.state.pour(m.from, m.to);
    }
    await storage.saveGame(7, c.state.history, board: c.startingBoard);

    final saved = await storage.loadGame();
    final restored = GameController(startLevel: 7);
    restored.restore(saved!.level, saved.moves, board: saved.board);

    // 둔 수를 전부 되돌리면 시작 보드로 정확히 돌아와야 한다.
    while (restored.state.moveCount > 0) {
      expect(restored.state.undo(), isNotNull);
    }
    expect(restored.state.bottles, start);
  });

  test('예전 저장(보드 없음)도 그대로 읽힌다', () async {
    // 어머니 폰에 이미 들어 있는 저장에는 보드가 없다. 그것도 열려야 한다.
    SharedPreferences.setMockInitialValues({
      'saved_game_v1': '{"level":3,"moves":[]}',
    });
    final saved = await Storage().loadGame();
    expect(saved, isNotNull);
    expect(saved!.level, 3);
    expect(saved.board, isNull);

    final c = GameController(startLevel: 3);
    c.restore(saved.level, saved.moves, board: saved.board);
    expect(c.level, 3);
  });

  test('손상된 보드는 무시하고 생성된 판으로 연다', () async {
    // 저장이 깨져도 게임은 켜져야 한다.
    final c = GameController(startLevel: 4);
    final normal = c.state.bottles;

    final broken = GameController(startLevel: 4);
    broken.restore(4, const [], board: const [
      [0, 0, 0, 0, 0, 0, 0, 0, 0, 0], // 용량을 넘는 병
    ]);
    expect(broken.state.bottles, normal, reason: '손상된 보드를 받아들였다');
  });
}
