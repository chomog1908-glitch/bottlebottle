import 'package:flutter/foundation.dart';

import '../logic/achievements.dart';
import '../logic/generator.dart';
import '../logic/level_config.dart';
import '../logic/solver.dart';
import '../model/game_state.dart';
import '../model/move.dart';

/// 화면 밖(기록·도전과제)에서 알아야 하는 사건들.
///
/// 컨트롤러는 기록을 직접 세지 않는다. 무슨 일이 있었는지 알리기만 하고,
/// 그걸 어떻게 쌓을지는 듣는 쪽이 정한다. 게임 규칙과 기록을 섞지 않기 위함이다.
enum GameEvent {
  /// 한 수를 두었다.
  move,

  /// 힌트를 눌렀다.
  hint,

  /// 한 수 되돌렸다.
  undo,

  /// 이 판을 처음부터 다시 시작했다.
  restart,

  /// 풀지 않은 채 다음 레벨로 건너뛰었다.
  skip,

  /// 판을 다 풀었다.
  solved,
}

/// 화면과 게임 로직을 잇는 계층.
///
/// 규칙 자체는 [GameState]가 전부 알고 있다. 여기서는 **선택 상태**처럼
/// 화면에만 있는 개념과, 레벨 넘기기 같은 흐름만 다룬다.
/// 규칙 판단을 여기에 복사해 두면 두 곳이 어긋나므로 반드시 [GameState]에 물어본다.
class GameController extends ChangeNotifier {
  GameController({int startLevel = 1}) {
    loadLevel(startLevel);
  }

  /// 사건이 일어날 때마다 불린다. 기록을 쌓는 쪽이 여기에 붙는다.
  void Function(GameEvent event)? onEvent;

  void _emit(GameEvent event) => onEvent?.call(event);

  /// 이 판에서 힌트를 누른 횟수. 레벨을 옮기거나 다시 시작하면 0으로 돌아간다.
  int hintsThisLevel = 0;

  /// 이 판에서 되돌린 횟수.
  int undosThisLevel = 0;

  late GeneratedLevel _generated;

  /// 현재 판. 화면은 이 상태만 보고 그린다.
  late GameState state;

  /// 지금 물을 들고 있는 병. 아무것도 안 들었으면 null.
  int? selected;

  /// 방금 시도했다가 거절당한 병. 화면에서 흔들어 보여주는 데 쓴다.
  int? rejected;

  /// 거절이 일어날 때마다 1씩 오른다.
  ///
  /// 같은 병을 연달아 잘못 눌렀을 때도 화면이 매번 반응해야 하는데,
  /// [rejected] 값만 보면 두 번째부터는 값이 안 바뀌어 흔들림이 나지 않는다.
  int rejectTick = 0;

  /// 힌트로 제시된 수. 화면에서 해당 병 두 개를 강조한다.
  Move? hintMove;

  /// 힌트가 들고 있는 남은 수순. 앞에서부터 하나씩 내준다.
  List<Move> _plan = [];

  /// 이 판에서 지금까지 **동시에** 점유했던 빈 병 수의 최대값.
  int _peakEmptiesUsed = 0;

  /// 되돌리기를 위해 수마다 직전 최대값을 쌓아 둔다.
  /// 이렇게 해야 되돌렸을 때 기록도 함께 정확히 되돌아간다.
  final List<int> _peakHistory = [];

  LevelConfig get config => _generated.config;

  int get level => config.level;

  bool get isSolved => state.isSolved;

  bool get canUndo => state.moveCount > 0;

  int get moveCount => state.moveCount;

  /// 이 판이 처음에 준 빈 병 수. 빈 병 사용량의 분모다.
  int get emptyBottleBudget => config.emptyBottles;

  /// 지금 이 순간 점유 중인 빈 병 수.
  ///
  /// 색을 완성해 병을 비우면 시작보다 빈 병이 많아질 수 있는데,
  /// 그건 "빚을 다 갚고 남은 여유"이지 마이너스 사용량이 아니므로 0에서 끊는다.
  int get emptiesInUse =>
      (emptyBottleBudget - state.emptyBottleCount()).clamp(0, emptyBottleBudget);

  /// 이 판을 푸는 동안 동시에 점유했던 빈 병 수의 최대값.
  ///
  /// **빈 병을 얼마나 아꼈는가**를 보여주는 값이다. 수 개수보다 실력을 잘 드러낸다.
  /// 빈 병 2개를 받고도 1개만으로 풀었다면 훨씬 잘 푼 것이다.
  int get peakEmptiesUsed => _peakEmptiesUsed;

  /// 지금 판의 결과 요약. 도전과제 판정에 넘긴다.
  ///
  /// 다 풀지 않은 판에 대해서도 값은 만들어지므로, 부르는 쪽이 [isSolved]를
  /// 확인한 뒤에 쓴다.
  ClearRecord get clearRecord => ClearRecord(
        level: level,
        moves: moveCount,
        hintsUsed: hintsThisLevel,
        undosUsed: undosThisLevel,
        peakEmptiesUsed: peakEmptiesUsed,
        emptyBudget: emptyBottleBudget,
        capacity: state.capacity,
        colorCount: config.colorCount,
      );

  /// [level]번 레벨을 불러온다.
  void loadLevel(int level) {
    _generated = LevelGenerator.generate(level);
    _resetBoard();
    notifyListeners();
  }

  /// 저장해 둔 수순을 재생해 판을 복원한다.
  ///
  /// 레벨 생성이 결정적이므로 같은 레벨 위에 같은 수를 순서대로 두면
  /// 보드는 물론 되돌리기 기록과 빈 병 사용 기록까지 그대로 살아난다.
  ///
  /// 저장이 손상돼 둘 수 없는 수가 나오면 **거기까지만 복원하고 멈춘다.**
  /// 게임을 못 켜게 하는 것보다 조금 덜 복원되는 편이 낫다.
  void restore(int level, List<List<int>> moves) {
    loadLevel(level);
    for (final m in moves) {
      if (m.length < 2) break;
      if (!state.canPour(m[0], m[1])) break;
      state.pour(m[0], m[1]);
      _recordPeak();
    }
    notifyListeners();
  }

  void _resetBoard() {
    // 생성된 원본은 그대로 두고 사본으로 논다. 그래야 재시작이 정확히 같은 판이 된다.
    state = _generated.state.copy();
    selected = null;
    rejected = null;
    hintMove = null;
    _peakEmptiesUsed = 0;
    _peakHistory.clear();
    _plan = [];
    // 힌트·되돌리기 횟수는 판마다 따로 센다. 다시 시작하면 깨끗한 판으로 친다.
    hintsThisLevel = 0;
    undosThisLevel = 0;
  }

  /// 병을 눌렀을 때의 처리. 화면에서 오는 유일한 입력이다.
  ///
  /// 규칙: 처음 누르면 물을 들고, 다시 누르면 붓는다.
  /// 같은 병을 두 번 누르면 취소. 부을 수 없는 병을 누르면 그 병을 대신 든다.
  void tapBottle(int index) {
    if (isSolved) return;

    rejected = null;
    hintMove = null;

    final from = selected;

    // 1) 아무것도 안 들고 있으면 → 들기
    if (from == null) {
      if (!state.isEmptyBottle(index)) selected = index;
      notifyListeners();
      return;
    }

    // 2) 같은 병을 다시 누르면 → 내려놓기
    if (from == index) {
      selected = null;
      notifyListeners();
      return;
    }

    // 3) 부을 수 있으면 → 붓기
    if (state.canPour(from, index)) {
      state.pour(from, index);
      _advancePlan(from, index);
      _recordPeak();
      selected = null;
      _emit(GameEvent.move);
      // 이 수로 판이 끝났는지는 규칙이 판단한다. 여기서 다시 세지 않는다.
      if (isSolved) _emit(GameEvent.solved);
      notifyListeners();
      return;
    }

    // 4) 부을 수 없으면 → 거절을 알리고, 누른 병이 비어 있지 않으면 그 병을 대신 든다.
    //    매번 선택이 풀리면 다시 누르는 수고가 생기므로 이어서 들게 해 준다.
    rejected = index;
    rejectTick++;
    selected = state.isEmptyBottle(index) ? null : index;
    notifyListeners();
  }

  /// 방금 둔 수가 들고 있던 수순의 첫 수였다면 한 칸 전진시킨다.
  /// 아니면 사용자가 다른 길로 간 것이므로 수순을 버린다.
  void _advancePlan(int from, int to) {
    if (_plan.isEmpty) return;
    final m = _plan.first;
    if (m.from == from && m.to == to) {
      _plan.removeAt(0);
    } else {
      _plan.clear();
    }
  }

  /// 한 수를 둔 뒤 빈 병 사용 기록을 갱신한다.
  void _recordPeak() {
    _peakHistory.add(_peakEmptiesUsed);
    final now = emptiesInUse;
    if (now > _peakEmptiesUsed) _peakEmptiesUsed = now;
  }

  /// 마지막 수를 되돌린다. **횟수 제한 없음.**
  void undo() {
    if (state.undo() == null) return;
    if (_peakHistory.isNotEmpty) _peakEmptiesUsed = _peakHistory.removeLast();
    selected = null;
    rejected = null;
    hintMove = null;
    // 되돌리면 판이 수순보다 뒤로 갔으므로 들고 있던 수순은 버린다.
    _plan.clear();
    undosThisLevel++;
    _emit(GameEvent.undo);
    notifyListeners();
  }

  /// 현재 레벨을 처음부터 다시. 같은 문제가 그대로 나온다.
  void restart() {
    _resetBoard();
    _emit(GameEvent.restart);
    notifyListeners();
  }

  /// 다음 레벨로. 클리어하지 않아도 넘어갈 수 있다(건너뛰기). **벌칙 없음.**
  ///
  /// 다 풀고 넘어가는 것과 안 풀고 넘어가는 것은 기록에서만 구분된다.
  /// 어느 쪽이든 화면에서 막거나 나무라지 않는다.
  void nextLevel() {
    if (!isSolved) _emit(GameEvent.skip);
    loadLevel(level + 1);
  }

  /// 이전 레벨로 돌아간다. 레벨 1에서는 아무 일도 하지 않는다.
  void previousLevel() {
    if (level > 1) loadLevel(level - 1);
  }

  /// 다음에 둘 만한 수를 찾아 표시한다. **횟수 제한 없음.**
  ///
  /// 대신 둬 주지는 않는다. 직접 두는 재미를 남겨두기 위함이다.
  ///
  /// 한 번 찾은 **수순 전체를 들고 있다가 앞에서부터 하나씩 내준다.**
  /// 매번 새로 찾으면 안 된다 — 탐색기는 최단 해답을 보장하지 않으므로
  /// 같은 판에서도 호출할 때마다 다른 해답을 내놓을 수 있고, 그러면
  /// 방금 둔 수를 되돌리는 수를 알려주며 두 수 사이를 영원히 왕복한다.
  /// (레벨 1에서 실제로 그랬다. 힌트만 눌러서는 판이 끝나지 않았다.)
  void requestHint() {
    if (isSolved) return;
    hintMove = _nextPlannedMove();
    selected = null;
    rejected = null;
    hintsThisLevel++;
    _emit(GameEvent.hint);
    notifyListeners();
  }

  /// 들고 있는 수순에서 다음 한 수를 꺼낸다. 쓸 수 없으면 새로 찾는다.
  Move? _nextPlannedMove() {
    // 들고 있던 수순이 지금 판에서 그대로 통하면 그걸 쓴다.
    while (_plan.isNotEmpty) {
      final m = _plan.first;
      if (state.canPour(m.from, m.to)) return m;
      // 사용자가 다른 길로 갔다면 남은 수순은 의미가 없다.
      _plan.clear();
    }

    final result = Solver.solve(state);
    if (!result.solved) return null;
    _plan = List<Move>.of(result.moves);
    return _plan.isEmpty ? null : _plan.first;
  }

  /// 이 병이 힌트에 관련되어 있는가. 화면 강조에 쓴다.
  bool isHinted(int index) =>
      hintMove != null && (hintMove!.from == index || hintMove!.to == index);
}
