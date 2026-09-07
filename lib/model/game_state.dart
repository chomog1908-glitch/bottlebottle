import 'move.dart';
import 'rule_set.dart';

/// 물병 정렬 퍼즐의 보드 상태.
///
/// Flutter에 전혀 의존하지 않는 순수 Dart 클래스다.
/// 게임의 모든 규칙이 여기에 있으므로, 화면 없이 테스트로 정확성을 검증할 수 있다.
///
/// 각 병은 `List<int>`이며 **인덱스 0이 바닥, 마지막 원소가 맨 위**다.
/// 정수는 색 인덱스이고, 실제 색상값은 UI 계층의 팔레트가 정한다.
class GameState {
  /// 병 하나에 담기는 최대 칸 수. 원작과 동일하게 4.
  static const int defaultCapacity = 4;

  final int capacity;
  final List<List<int>> _bottles;
  final List<Move> _history = [];

  /// 이 판의 규칙. 레벨 700까지는 [RuleSet.classic]이다.
  final RuleSet rules;

  /// 처음에 비어 있던 병인가. 트릭 A·C가 이걸 본다.
  ///
  /// **판이 시작될 때 정해지고 그 뒤로 바뀌지 않는다.** 나중에 비워진 병과
  /// 처음부터 비어 있던 병은 다른 것으로 취급해야 규칙이 흔들리지 않는다.
  final List<bool> _startedEmpty;

  /// 이 병이 전용으로 굳은 색. 잠기지 않았으면 null.
  final List<int?> _claimed;

  GameState._(this._bottles, this.capacity, this.rules, this._startedEmpty,
      this._claimed);

  /// 병의 내용물 목록으로 상태를 만든다. 입력은 복사되므로 이후 변경에 영향받지 않는다.
  factory GameState(
    List<List<int>> bottles, {
    int capacity = defaultCapacity,
    RuleSet rules = RuleSet.classic,
  }) {
    for (final b in bottles) {
      if (b.length > capacity) {
        throw ArgumentError('병에 용량($capacity)보다 많은 ${b.length}칸이 들어있습니다.');
      }
    }
    final state = GameState._(
      [for (final b in bottles) List<int>.of(b)],
      capacity,
      rules,
      [for (final b in bottles) b.isEmpty],
      List<int?>.filled(bottles.length, null),
    );
    state._relock();
    return state;
  }

  /// 빈 병 출신을 **직접 지정해서** 상태를 만든다.
  ///
  /// 기본 생성자는 "지금 비어 있는 병"을 빈 병 출신으로 본다. 시작 판에서는 그게 맞다.
  /// 하지만 레벨 생성기는 판을 섞는 **도중의** 보드로 규칙을 시험해 봐야 하는데,
  /// 그 순간 비어 있는 병은 시작 판의 빈 병과 다르다. 그때 이 생성자를 쓴다.
  factory GameState.withOrigins(
    List<List<int>> bottles, {
    required int capacity,
    required RuleSet rules,
    required List<bool> startedEmpty,
  }) {
    final state = GameState._(
      [for (final b in bottles) List<int>.of(b)],
      capacity,
      rules,
      List<bool>.of(startedEmpty),
      List<int?>.filled(bottles.length, null),
    );
    state._relock();
    return state;
  }

  /// 이 병이 전용으로 굳은 색. 잠기지 않았으면 null. 화면이 테두리 색에 쓴다.
  int? claimedColor(int i) => _claimed[i];

  /// 이 병이 처음부터 비어 있었는가.
  bool startedEmpty(int i) => _startedEmpty[i];

  /// 한 색으로만 이루어져 있는가. (비어 있으면 false)
  bool isMonochrome(int i) {
    final b = _bottles[i];
    if (b.isEmpty) return false;
    for (final v in b) {
      if (v != b.first) return false;
    }
    return true;
  }

  /// 수를 둔 뒤 잠금을 다시 계산한다.
  ///
  /// 규칙이 없으면 아무 일도 하지 않으므로, 레벨 700까지는 비용이 0이다.
  void _relock() {
    if (!rules.hasLocks) return;
    for (var i = 0; i < _bottles.length; i++) {
      if (_bottles[i].isEmpty) {
        // 비면 잠금이 풀린다. 단 트릭 A의 빈 병 출신은 영구다.
        if (!(rules.claimEmpties && _startedEmpty[i])) _claimed[i] = null;
      } else if (isMonochrome(i)) {
        if (rules.claimEmpties && _startedEmpty[i]) {
          _claimed[i] ??= _bottles[i].first;
        }
        if (rules.claimMono) _claimed[i] = _bottles[i].first;
      }
    }
  }

  int get bottleCount => _bottles.length;

  /// 읽기 전용 뷰. UI가 그릴 때 사용한다.
  List<List<int>> get bottles => [for (final b in _bottles) List<int>.unmodifiable(b)];

  /// [i]번 병의 내용물 (바닥 → 위 순서). 읽기 전용.
  List<int> bottleAt(int i) => List<int>.unmodifiable(_bottles[i]);

  /// 지금까지 둔 수의 기록. 되돌리기와 통계에 쓴다.
  List<Move> get history => List<Move>.unmodifiable(_history);

  int get moveCount => _history.length;

  bool isEmptyBottle(int i) => _bottles[i].isEmpty;

  bool isFull(int i) => _bottles[i].length == capacity;

  /// [i]번 병의 맨 위 색. 비어 있으면 null.
  int? topColor(int i) => _bottles[i].isEmpty ? null : _bottles[i].last;

  /// [i]번 병 맨 위에 같은 색이 연속으로 몇 칸 쌓여 있는지.
  int topRunLength(int i) {
    final b = _bottles[i];
    if (b.isEmpty) return 0;
    final c = b.last;
    var n = 1;
    while (n < b.length && b[b.length - 1 - n] == c) {
      n++;
    }
    return n;
  }

  /// 한 가지 색으로 가득 찬 병인지. (완성된 병)
  bool isComplete(int i) {
    final b = _bottles[i];
    return b.length == capacity && topRunLength(i) == capacity;
  }

  /// 모든 병이 비었거나 한 색으로 가득 찼으면 승리.
  bool get isSolved {
    for (var i = 0; i < _bottles.length; i++) {
      if (_bottles[i].isEmpty) continue;
      if (!isComplete(i)) return false;
    }
    return true;
  }

  /// [from]에서 [to]로 부을 수 있는가.
  ///
  /// 조건: 서로 다른 병, 따라낼 물이 있고, 받을 자리가 있고,
  /// 받는 병이 비었거나 맨 위 색이 같을 것.
  bool canPour(int from, int to) {
    if (from == to) return false;
    final src = _bottles[from];
    final dst = _bottles[to];
    if (src.isEmpty) return false;
    if (dst.length >= capacity) return false;
    if (dst.isNotEmpty && dst.last != src.last) return false;

    // 여기부터는 특별 규칙. 없으면 곧바로 통과한다.
    if (!rules.hasReachLimit && !rules.hasLocks) return true;

    if (!rules.reaches(from, to)) return false;

    // 트릭 C — 빈 병에서 출발한 병은 가득 차기 전까지 못 따라낸다.
    if (rules.lockEmptyOrigin &&
        _startedEmpty[from] &&
        src.length < capacity) {
      return false;
    }

    // 잠긴 병은 그 색만 받는다.
    final lock = _claimed[to];
    if (lock != null && lock != src.last) return false;

    return true;
  }

  /// [from]에서 [to]로 실제로 옮겨질 칸 수. 부을 수 없으면 0.
  ///
  /// 맨 위 같은 색 덩어리를 통째로 옮기되, 받는 병의 남은 자리만큼만 간다.
  int pourAmount(int from, int to) {
    if (!canPour(from, to)) return 0;
    final room = capacity - _bottles[to].length;
    final run = topRunLength(from);
    return run < room ? run : room;
  }

  /// 물을 붓는다. 성공하면 실행된 [Move], 부을 수 없으면 null.
  Move? pour(int from, int to) {
    final n = pourAmount(from, to);
    if (n == 0) return null;
    final color = _bottles[from].last;
    for (var i = 0; i < n; i++) {
      _bottles[from].removeLast();
      _bottles[to].add(color);
    }
    final move = Move(from: from, to: to, count: n, color: color);
    _history.add(move);
    _relock();
    return move;
  }

  /// 마지막 수를 되돌린다. 되돌릴 수가 없으면 null.
  ///
  /// 옮긴 칸 수를 정확히 기록해두었으므로 항상 직전 상태로 정확히 복원된다.
  Move? undo() {
    if (_history.isEmpty) return null;
    final m = _history.removeLast();
    for (var i = 0; i < m.count; i++) {
      _bottles[m.to].removeLast();
      _bottles[m.from].add(m.color);
    }
    _relock();
    return m;
  }

  /// 지금 둘 수 있는 모든 수.
  ///
  /// 결과가 달라지지 않는 무의미한 수는 제외한다:
  /// - 이미 완성된 병에서 따라내기
  /// - 한 색으로만 채워진 병을 통째로 다른 빈 병에 옮기기 (상태가 사실상 동일)
  List<Move> legalMoves() {
    final moves = <Move>[];
    for (var from = 0; from < _bottles.length; from++) {
      final src = _bottles[from];
      if (src.isEmpty) continue;
      if (isComplete(from)) continue;
      // 한 색으로만 이루어진 병은 빈 병으로 옮겨봐야 제자리걸음이다.
      final uniform = topRunLength(from) == src.length;
      for (var to = 0; to < _bottles.length; to++) {
        if (from == to) continue;
        if (uniform && _bottles[to].isEmpty) continue;
        final n = pourAmount(from, to);
        if (n == 0) continue;
        moves.add(Move(from: from, to: to, count: n, color: src.last));
      }
    }
    return moves;
  }

  /// 지금 비어 있는 병의 수.
  ///
  /// 색을 하나 완성해 병을 통째로 비우면 이 값이 시작할 때보다 **늘어날 수도** 있다.
  int emptyBottleCount() {
    var n = 0;
    for (final b in _bottles) {
      if (b.isEmpty) n++;
    }
    return n;
  }

  /// 보드 전체의 색 조각 수.
  ///
  /// 조각이란 한 병 안에서 같은 색이 연속된 한 덩어리다.
  /// 예를 들어 `[0,0,1,0]`은 조각 3개(`00`, `1`, `0`)다.
  ///
  /// 이 값이 색 가짓수와 같으면 이미 다 풀린 상태이고, 클수록 헝클어져 있다.
  /// 해답 길이보다 훨씬 안정적인 난이도 지표라 레벨 생성 검증에 쓴다.
  /// (색 하나를 모으려면 그 색 조각 수보다 최소 1 적은 만큼은 부어야 하므로,
  /// 조각 수는 필요한 수의 하한을 직접 말해준다.)
  int segmentCount() {
    var total = 0;
    for (final b in _bottles) {
      if (b.isEmpty) continue;
      total++;
      for (var i = 1; i < b.length; i++) {
        if (b[i] != b[i - 1]) total++;
      }
    }
    return total;
  }

  /// 규칙상 가능한 **모든** 수. [legalMoves]와 달리 아무것도 걸러내지 않는다.
  ///
  /// 레벨 생성기가 완성 상태를 흐트러뜨릴 때 쓴다. 그 단계에서는
  /// "단색 병을 빈 병에 옮기기"처럼 탐색에는 무의미한 수가 오히려 필수적이다.
  /// (완성 상태에서 둘 수 있는 수는 그것뿐이다.)
  List<Move> allPourMoves() {
    final moves = <Move>[];
    for (var from = 0; from < _bottles.length; from++) {
      for (var to = 0; to < _bottles.length; to++) {
        final n = pourAmount(from, to);
        if (n == 0) continue;
        moves.add(Move(from: from, to: to, count: n, color: _bottles[from].last));
      }
    }
    return moves;
  }

  /// 기록을 뺀 보드만 복제한다. 탐색기가 상태를 굴릴 때 사용한다.
  GameState copy() => GameState._(
        [for (final b in _bottles) List<int>.of(b)],
        capacity,
        rules,
        _startedEmpty,
        List<int?>.of(_claimed),
      );

  /// 중복 상태 판별용 키.
  ///
  /// 병의 **순서는 게임 규칙상 의미가 없으므로** 정렬해서 같은 상태로 취급한다.
  /// 이 정규화 덕분에 탐색 공간이 크게 줄어든다.
  ///
  /// **단, 이웃 제한이 붙으면 위치가 의미를 갖는다.** 그때 정렬하면 서로 다른
  /// 상태를 같다고 잘못 판단해 탐색기가 없는 해답을 있다고 하거나 그 반대가 된다.
  /// 그래서 제한이 있으면 순서를 그대로 둔다. 잠금도 마찬가지로 키에 넣는다.
  /// (실측: 이웃 제한이 걸리면 가지 수가 줄어 정규화를 잃은 손해를 메우고도 남는다.)
  String canonicalKey() {
    final parts = [for (final b in _bottles) b.join(',')];
    if (!rules.hasReachLimit && !rules.hasLocks) {
      parts.sort();
      return parts.join('|');
    }
    final locks = [for (final c in _claimed) c ?? -1].join(',');
    return '${parts.join('|')}#$locks';
  }

  @override
  String toString() => _bottles.map((b) => b.join('')).join(' / ');
}
