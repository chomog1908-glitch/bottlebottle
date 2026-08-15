import 'move.dart';

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

  GameState._(this._bottles, this.capacity);

  /// 병의 내용물 목록으로 상태를 만든다. 입력은 복사되므로 이후 변경에 영향받지 않는다.
  factory GameState(List<List<int>> bottles, {int capacity = defaultCapacity}) {
    for (final b in bottles) {
      if (b.length > capacity) {
        throw ArgumentError('병에 용량($capacity)보다 많은 ${b.length}칸이 들어있습니다.');
      }
    }
    return GameState._([for (final b in bottles) List<int>.of(b)], capacity);
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
    return dst.isEmpty || dst.last == src.last;
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
      );

  /// 중복 상태 판별용 정규화 키.
  ///
  /// 병의 **순서는 게임 규칙상 의미가 없으므로** 정렬해서 같은 상태로 취급한다.
  /// 이 정규화 덕분에 탐색 공간이 크게 줄어든다.
  String canonicalKey() {
    final parts = [for (final b in _bottles) b.join(',')]..sort();
    return parts.join('|');
  }

  @override
  String toString() => _bottles.map((b) => b.join('')).join(' / ');
}
