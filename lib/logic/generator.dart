import 'dart:math';

import '../model/game_state.dart';
import 'level_config.dart';
import 'solver.dart';

/// 생성된 레벨 하나.
class GeneratedLevel {
  final LevelConfig config;

  /// 시작 보드.
  final GameState state;

  /// 탐색기가 찾아낸 해답의 길이. 난이도 표시와 검증에 쓴다.
  final int solutionLength;

  /// 이 판을 만들기까지 시도한 횟수. 생성기 성능 확인용.
  final int attempts;

  const GeneratedLevel({
    required this.config,
    required this.state,
    required this.solutionLength,
    required this.attempts,
  });
}

/// 레벨 생성기.
///
/// **레벨 번호가 곧 시드다.** 같은 레벨은 몇 번을 다시 켜도 항상 같은 판이 나온다.
/// 재시작해도 문제가 바뀌지 않으므로, 어제 풀다 만 판을 오늘 이어서 고민할 수 있다.
///
/// ## 왜 무작위로 뿌리지 않는가
///
/// 색을 병에 무작위로 나눠 담는 방식은 빈 병이 넉넉할 때만 통한다.
/// 빈 병이 1개뿐인 최고 난이도에서는 무작위 배치가 거의 항상 풀 수 없는 판이 되어,
/// 수백 번을 다시 뽑아도 쓸 만한 판이 나오지 않는다.
///
/// 그래서 **완성된 상태에서 출발해 유효한 수를 무작위로 두며 흐트러뜨린다.**
/// 이렇게 만든 판은 완성 상태에서 도달 가능한 상태이고, 채택 전에 탐색기로 한 번 더
/// 확인하므로 **풀 수 없는 판은 게임에 나올 수 없다.**
class LevelGenerator {
  /// 한 레벨을 만들기 위한 최대 시도 횟수.
  static const int maxAttempts = 150;

  /// [level]번 레벨을 생성한다. 색 수와 병 깊이는 레벨 번호가 정한다.
  static GeneratedLevel generate(int level) {
    final config = LevelConfig.forLevel(level);

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final rng = Random(_seedFor(level, attempt));
      final state = _shuffleFromSolved(config, rng);

      if (!_isInterestingStart(state)) continue;
      if (!_hasPromisedEmptyBottles(state, config)) continue;
      if (state.segmentCount() < _minimumSegments(config)) continue;

      final result = Solver.solve(state);
      if (!result.solved) continue;

      return GeneratedLevel(
        config: config,
        state: state,
        solutionLength: result.moves.length,
        attempts: attempt + 1,
      );
    }

    // 여기 도달하면 까다로움 조건이 지나치게 빡빡했다는 뜻이다.
    // 게임이 멈추는 것보다는 조건을 풀어서라도 풀 수 있는 판을 내주는 편이 낫다.
    return _generateRelaxed(config);
  }

  /// 조건을 완화한 최후 수단. "풀리고, 아직 안 풀려 있다"만 보장한다.
  static GeneratedLevel _generateRelaxed(LevelConfig config) {
    for (var attempt = 0; attempt < maxAttempts * 4; attempt++) {
      final rng = Random(_seedFor(config.level, maxAttempts + attempt));
      final state = _shuffleFromSolved(config, rng);
      if (state.isSolved) continue;
      // 조건을 완화해도 이것만은 지킨다. 약속한 빈 병 개수는 난이도의 근간이다.
      if (!_hasPromisedEmptyBottles(state, config)) continue;
      final result = Solver.solve(state);
      if (result.solved) {
        return GeneratedLevel(
          config: config,
          state: state,
          solutionLength: result.moves.length,
          attempts: maxAttempts + attempt + 1,
        );
      }
    }
    throw StateError('레벨 ${config.level} 생성 실패. 난이도 설정을 확인하세요.');
  }

  static int _seedFor(int level, int attempt) => level * 1000003 + attempt;

  /// 완성된 상태에서 **수를 거꾸로 되감으며** 흐트러뜨린다.
  ///
  /// 앞으로 두는 수로 섞으려 하면 안 된다. 완성된 상태에서 둘 수 있는 수는
  /// "가득 찬 병을 통째로 빈 병에 옮기기"뿐이라, 병의 자리만 바뀌고 색은 영영 안 섞인다.
  ///
  /// 그래서 되감기 연산을 쓴다. 되감기 한 번은 이런 뜻이다:
  /// *"직전에 누군가 [s]에서 [d]로 [k]칸을 부었다고 치고, 그걸 원상복구한다."*
  /// 즉 [d]의 맨 위 [k]칸을 떼어 [s]로 옮긴다.
  ///
  /// 이 되감기가 **정확히 한 수로 되돌아올 수 있으려면** 두 조건이 필요하다.
  /// 두 조건 모두 "떼어낸 k칸이 앞으로 두는 수로 그대로 다시 부어지는가"를 보장한다:
  ///
  /// 1. 받는 병 [s]는 비었거나 맨 위 색이 [c]와 **달라야** 한다.
  ///    그래야 되돌릴 때 [s]에서 들리는 덩어리가 정확히 k칸이 된다.
  ///    (이미 같은 색이 쌓여 있으면 k칸보다 많이 들려서 원래 자리로 못 돌아간다.)
  /// 2. k칸을 떼고 난 [d]는 같은 색 [c]가 남아 있거나 **완전히 비어야** 한다.
  ///    그래야 되돌릴 때 [d]가 물을 받아줄 수 있다.
  ///
  /// 이 규칙만 지키면 흐트러뜨린 판은 되감은 횟수만큼의 수순으로 반드시 원상복구된다.
  /// 즉 **풀 수 있음이 구조적으로 보장된다.**
  /// 진단용 통로. 시험 도구에서만 쓴다.
  static GameState debugShuffle(LevelConfig config, Random rng) =>
      _shuffleFromSolved(config, rng);

  static GameState _shuffleFromSolved(LevelConfig config, Random rng) {
    final cap = config.capacity;

    // 언제부터 빈 병을 지킬지. 시도마다 다르게 잡는다.
    //
    // 이 값이 이 생성기의 유일한 저울이다. 일찍 지키면 빈 병은 남지만 판이 덜 섞이고,
    // 늦게 지키면 잘 섞이지만 빈 병을 못 되찾는다. 어느 한쪽으로 고정하면
    // 반드시 어느 레벨에선가 걸린다. (일찍 고정 → 레벨 500이 조각 미달,
    // 늦게 고정 → 레벨 432가 빈 병을 못 맞춤.) 그래서 고르지 않고 **흔든다.**
    // 시도를 거듭하며 이 지점이 바뀌므로, 어느 레벨이든 맞는 지점을 만나게 된다.
    final b = <List<int>>[
      for (var c = 0; c < config.colorCount; c++) [for (var k = 0; k < cap; k++) c],
      for (var i = 0; i < config.emptyBottles; i++) <int>[],
    ];

    int topRun(List<int> x) {
      if (x.isEmpty) return 0;
      final c = x.last;
      var n = 1;
      while (n < x.length && x[x.length - 1 - n] == c) {
        n++;
      }
      return n;
    }

    // 섞는 도중 조건을 만족하는 순간을 잡아 두었다가 그걸 판으로 쓴다.
    //
    // 마지막 상태를 그냥 쓰면 안 된다. 되감기는 빈 병을 즐겨 채우기 때문에,
    // "빈 병 2개짜리 판"이라면서 시작부터 한 개가 차 있는 판이 나온다.
    // 실제로 그런 판이 나왔다. 시작하자마자 "빈 병 1/2 사용 중"으로 뜬다.
    List<List<int>>? accepted;
    final minSegments = _minimumSegments(config);

    void considerCurrent() {
      // 약속한 개수만큼 빈 병이 정확히 남아 있어야 한다.
      var empties = 0;
      for (final x in b) {
        if (x.isEmpty) empties++;
      }
      if (empties != config.emptyBottles) return;

      // 충분히 헝클어졌는지도 여기서 함께 본다.
      var segments = 0;
      for (final x in b) {
        if (x.isEmpty) continue;
        segments++;
        for (var i = 1; i < x.length; i++) {
          if (x[i] != x[i - 1]) segments++;
        }
        // 단색으로만 찬 병은 거저 주는 것이나 마찬가지라 받지 않는다.
        if (topRun(x) == x.length) return;
      }
      if (segments < minSegments) return;

      // 뒤로 갈수록 더 섞여 있으므로 나중 것으로 계속 덮어쓴다.
      accepted = [for (final x in b) List<int>.of(x)];
    }

    final steps = config.colorCount * cap * 5;
    final guardFrom = steps * (2 + rng.nextInt(7)) ~/ 10;
    for (var step = 0; step < steps; step++) {
      // (덜어낼 병 d, 칸 수 k, 받을 병 s) 후보를 모은다.
      final candidates = <List<int>>[];
      for (var d = 0; d < b.length; d++) {
        if (b[d].isEmpty) continue;
        final c = b[d].last;
        final run = topRun(b[d]);
        for (var k = 1; k <= run; k++) {
          // 조건 2: 다 떼어낼 거면 병이 완전히 비어야 한다.
          if (k == run && run != b[d].length) continue;
          for (var s = 0; s < b.length; s++) {
            if (s == d) continue;
            if (b[s].length + k > cap) continue;
            // 조건 1: 같은 색 위에 얹으면 안 된다.
            if (b[s].isNotEmpty && b[s].last == c) continue;
            candidates.add([d, k, s]);
          }
        }
      }
      if (candidates.isEmpty) break;

      // 빈 병을 그대로 남겨두는 쪽보다, 다른 색 위에 얹어 켜켜이 쌓는 쪽을 선호한다.
      // 그래야 실제로 헝클어진 판이 된다.
      //
      // 다만 **약속한 빈 병 수는 지켜야 한다.** 되감기는 빈 병을 즐겨 채우는데,
      // 병이 깊을수록 그 경향이 심해져 빈 병이 하나도 안 남는 상태로 굳어버린다.
      // (깊이 8칸에서는 200번 섞어 빈 병 2개가 남은 적이 0~7번뿐이었다.
      //  그래서 레벨 432는 750번을 시도하고도 판을 못 만들어 예외를 던졌다.)
      //
      // 그래서 빈 병이 약속한 수보다 적어지면, 그때부터는 **빈 병을 채우지 않는 수**를
      // 우선한다. 빈 병을 비우는 수(병 전체를 옮겨 d가 비는 수)는 오히려 반긴다.
      var emptyNow = 0;
      for (final x in b) {
        if (x.isEmpty) emptyNow++;
      }
      // 빈 병을 지키는 것과 판을 헝클어뜨리는 것은 서로 반대 방향으로 당긴다.
      // 처음부터 빈 병을 지키면 액체가 퍼지지 못해 판이 덜 섞인 채로 굳는다.
      // (실제로 그렇게 만들었더니 레벨 500이 조각 41개로 기준 미달이 났다.)
      //
      // 그래서 **먼저 섞고, 나중에 지킨다.** 앞부분에서는 마음껏 흐트러뜨리고,
      // 뒷부분에 들어서야 빈 병을 되찾도록 유도한다. 스냅숏은 뒤로 갈수록
      // 좋은 것으로 덮어쓰므로, 마지막에 조건을 맞추면 그게 채택된다.
      final guardEmpties = step >= guardFrom && emptyNow <= config.emptyBottles;

      // 빈 병을 쓰지 않는 수 = 받는 병 s가 이미 차 있는 수. 이게 판을 헝클어뜨린다.
      final stacking = candidates.where((t) => b[t[2]].isNotEmpty).toList();

      // 빈 병이 모자랄 때는 **빈 병을 더 쓰지 않는 수**만 둔다.
      // 빈 병을 새로 만드는 수까지 강제하면 판이 빈 병 수에 붙들려
      // 헝클어지지 못한 채 굳는다. 막지만 말고, 흐르게 둔다.
      final pool = guardEmpties && stacking.isNotEmpty
          ? stacking
          : (stacking.isNotEmpty && rng.nextInt(5) > 0 ? stacking : candidates);

      final pick = pool[rng.nextInt(pool.length)];
      final d = pick[0], k = pick[1], s = pick[2];
      final c = b[d].last;
      for (var i = 0; i < k; i++) {
        b[d].removeLast();
        b[s].add(c);
      }

      considerCurrent();
    }

    // 조건을 만족한 순간이 한 번도 없었다면 마지막 상태를 넘긴다.
    // 바깥에서 어차피 한 번 더 거르므로, 여기서 실패를 알릴 필요는 없다.
    return GameState(accepted ?? b, capacity: cap);
  }

  /// 시작부터 김이 빠지는 판을 걸러낸다.
  ///
  /// - 이미 풀려 있으면 안 된다.
  /// - 처음부터 완성된 병이 있으면 안 된다. 공짜로 주어진 색은 재미를 깎는다.
  /// - 단색으로만 이루어진 병도 거의 완성이나 마찬가지라 걸러낸다.
  static bool _isInterestingStart(GameState state) {
    if (state.isSolved) return false;
    for (var i = 0; i < state.bottleCount; i++) {
      final b = state.bottleAt(i);
      if (b.isEmpty) continue;
      if (state.topRunLength(i) == b.length) return false;
    }
    return true;
  }

  /// 약속한 개수만큼 빈 병이 실제로 비어 있는가.
  ///
  /// 난이도표에 "빈 병 2개"라고 적어 놓고 시작부터 하나가 차 있으면 거짓말이 된다.
  /// 화면의 "빈 병 0/2 사용 중" 표시도 시작하자마자 1/2로 뜨게 되어 말이 안 맞는다.
  static bool _hasPromisedEmptyBottles(GameState state, LevelConfig config) =>
      state.emptyBottleCount() == config.emptyBottles;

  /// 이 난이도라면 최소 이만큼은 헝클어져 있어야 한다는 하한선.
  ///
  /// **전체 칸 수에 비례해서** 잡는다. 색 개수만 기준으로 삼으면
  /// 병이 깊어졌을 때 덜 섞인 판이 그대로 통과한다.
  /// (실제로 그런 일이 있었다. 깊이 8칸짜리 판이 27수 만에 끝났다.)
  ///
  /// 대략 두 칸에 한 번은 색이 바뀌어야 한다는 뜻이다.
  ///
  /// 해답 길이 대신 이 값을 쓰는 이유: 탐색기는 최단 해답을 보장하지 않으므로
  /// 해답 길이는 판의 어려움이 아니라 탐색기의 운을 재게 된다. 조각 수는 판 자체의 성질이다.
  /// 빈 병이 하나뿐이면 섞을 여지 자체가 좁아지므로 기준을 조금 낮춘다.
  /// 낮추지 않으면 조건을 못 맞춰 완화 경로로 떨어지고, 오히려 더 싱거운 판이 나온다.
  static int _minimumSegments(LevelConfig config) =>
      (config.totalUnits * (config.emptyBottles >= 2 ? 0.45 : 0.38)).round();
}
