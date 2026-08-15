import '../model/game_state.dart';
import '../model/move.dart';

/// 탐색 결과.
class SolveResult {
  /// 해답을 찾았는가.
  final bool solved;

  /// 시작 상태부터 승리까지의 수순. [solved]가 false면 비어 있다.
  final List<Move> moves;

  /// 탐색한 상태 수. 성능 확인용.
  final int nodesExplored;

  /// 탐색 예산을 다 써서 중단됐는가.
  ///
  /// true이면 "풀 수 없다"가 아니라 **"모르겠다"**는 뜻이다. 이 둘을 혼동하면
  /// 풀 수 있는 레벨을 버리게 되므로 반드시 구분한다.
  final bool exhausted;

  const SolveResult({
    required this.solved,
    required this.moves,
    required this.nodesExplored,
    required this.exhausted,
  });

  /// 해답의 길이(수). 못 찾았으면 null.
  int? get moveCount => solved ? moves.length : null;

  /// 확실히 풀 수 없다고 판정된 경우에만 true.
  bool get provenUnsolvable => !solved && !exhausted;
}

/// 물병 정렬 퍼즐 탐색기.
///
/// 힌트 제공과 레벨 생성 검증에 쓴다.
///
/// 방식: 방문 상태 집합을 둔 깊이 우선 탐색(DFS) + 수 정렬 휴리스틱.
/// 병 순서를 정규화해 중복 상태를 제거하므로, 도달 가능한 상태는 정확히 한 번씩만 펼쳐진다.
/// 따라서 해답이 존재하면 예산 안에서 반드시 찾는다.
///
/// 최단 해답을 보장하지는 않는다. 힌트는 "정답으로 가는 한 수"면 충분하고,
/// 최단성을 위해 BFS를 쓰면 색 12개 규모에서 메모리가 감당되지 않는다.
class Solver {
  /// 기본 탐색 예산(상태 수). 최대 난이도에서도 대개 이보다 훨씬 적게 든다.
  static const int defaultNodeBudget = 400000;

  /// [start]에서 승리까지의 수순을 찾는다.
  static SolveResult solve(GameState start, {int nodeBudget = defaultNodeBudget}) {
    final visited = <String>{};
    final path = <Move>[];
    var nodes = 0;
    var exhausted = false;

    bool dfs(GameState s) {
      if (s.isSolved) return true;
      if (nodes >= nodeBudget) {
        exhausted = true;
        return false;
      }
      nodes++;

      final moves = s.legalMoves();
      _sortByPromise(s, moves);

      for (final m in moves) {
        final next = s.copy();
        next.pour(m.from, m.to);
        if (!visited.add(next.canonicalKey())) continue;

        path.add(m);
        if (dfs(next)) return true;
        path.removeLast();

        if (exhausted) return false;
      }
      return false;
    }

    final root = start.copy();
    visited.add(root.canonicalKey());
    final ok = dfs(root);

    return SolveResult(
      solved: ok,
      moves: ok ? List<Move>.of(path) : const [],
      nodesExplored: nodes,
      exhausted: exhausted && !ok,
    );
  }

  /// 현재 상태에서 둘 만한 다음 한 수. 해답이 없거나 이미 이겼으면 null.
  static Move? hint(GameState state, {int nodeBudget = defaultNodeBudget}) {
    if (state.isSolved) return null;
    final r = solve(state, nodeBudget: nodeBudget);
    return r.solved && r.moves.isNotEmpty ? r.moves.first : null;
  }

  /// 풀 수 있는지만 확인한다.
  static bool isSolvable(GameState state, {int nodeBudget = defaultNodeBudget}) =>
      solve(state, nodeBudget: nodeBudget).solved;

  /// 유망한 수를 먼저 시도하도록 정렬한다.
  ///
  /// 이 순서 하나로 탐색량이 수십 배 차이난다. 좋은 수부터 보면
  /// 대부분의 판은 되돌아오는 일 없이 곧장 풀린다.
  static void _sortByPromise(GameState s, List<Move> moves) {
    int score(Move m) {
      var v = 0;
      final dstLen = s.bottleAt(m.to).length;
      final srcLen = s.bottleAt(m.from).length;

      // 1순위: 이 수로 병 하나가 완성된다.
      if (dstLen + m.count == s.capacity && (dstLen == 0 || s.topColor(m.to) == m.color)) {
        final dstUniform = dstLen == 0 || s.topRunLength(m.to) == dstLen;
        if (dstUniform) v += 1000;
      }
      // 2순위: 따라낸 병이 완전히 비워진다. 빈 병은 그 자체로 자원이다.
      if (srcLen == m.count) v += 500;
      // 3순위: 빈 병을 쓰지 않고 같은 색 위에 합친다. 빈 병은 아껴야 한다.
      if (dstLen > 0) v += 100;
      // 4순위: 같은 값이면 많이 옮기는 쪽.
      v += m.count;
      return v;
    }

    final cache = {for (final m in moves) m: score(m)};
    moves.sort((a, b) => cache[b]!.compareTo(cache[a]!));
  }
}
