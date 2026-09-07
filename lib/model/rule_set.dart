/// 한 판에 적용되는 규칙.
///
/// 레벨 700까지는 규칙이 하나뿐이었다. 그 뒤로 이웃 제한과 잠금이 붙는데,
/// 그때마다 [GameState]에 `if (level > ...)`를 심으면 규칙이 온 코드에 흩어진다.
/// **규칙을 값으로 만들어 상태가 들고 다니게 하면**, 규칙을 아는 곳은 여기 하나뿐이고
/// 생성기·탐색기·화면은 그저 물어보기만 하면 된다.
///
/// 기본값 [RuleSet.classic]은 레벨 1~700의 규칙과 정확히 같다.
class RuleSet {
  /// 가로로 몇 칸까지 닿는가. 음수면 제한 없음.
  final int reachX;

  /// 세로로 몇 줄까지 닿는가. 음수면 제한 없음.
  final int reachY;

  /// 이웃 제한을 잴 때 쓰는 격자의 한 줄 병 수.
  ///
  /// **화면 배치가 아니라 규칙이 격자를 정한다.** 화면은 폰 크기에 따라 줄 수가
  /// 달라지므로(`computeBoardMetrics`), 그걸 규칙에 쓰면 폰마다 규칙이 달라진다.
  final int gridPerRow;

  /// 트릭 A — 빈 병에 한 번 담으면 그 색 전용이 된다. 비워도 풀리지 않는다.
  final bool claimEmpties;

  /// 트릭 B — 한 색만 남은 병도 그 색 전용. 완전히 비우면 풀린다.
  final bool claimMono;

  /// 트릭 C — 빈 병에서 출발한 병은 가득 차기 전까지 따라낼 수 없다.
  ///
  /// "한 색만 남은 병은 못 따라낸다"로 잡으면 완성된 병도 여기 해당해서,
  /// 완성 상태에서 되감을 병이 하나도 없어진다. 규칙 자체가 모순이 된다.
  /// "가득 차기 전까지만"으로 좁혀도 부분 되감기가 곧바로 막혀 색이 안 섞인다.
  /// 그래서 대상을 **빈 병 출신으로** 좁혔다. 실측으로 확인한 유일한 성립 조건이다.
  final bool lockEmptyOrigin;

  const RuleSet({
    this.reachX = -1,
    this.reachY = -1,
    this.gridPerRow = 8,
    this.claimEmpties = false,
    this.claimMono = false,
    this.lockEmptyOrigin = false,
  });

  /// 레벨 1~700의 규칙. 제한도 잠금도 없다.
  static const RuleSet classic = RuleSet();

  /// 이웃 제한만 있는 규칙.
  const RuleSet.reach(int x, int y, {int perRow = 8})
      : reachX = x,
        reachY = y,
        gridPerRow = perRow,
        claimEmpties = false,
        claimMono = false,
        lockEmptyOrigin = false;

  bool get hasReachLimit => reachX >= 0 || reachY >= 0;

  /// 잠금 규칙이 하나라도 있는가. 탐색기가 상태 키를 정할 때 쓴다.
  bool get hasLocks => claimEmpties || claimMono || lockEmptyOrigin;

  /// [a]번 병에서 [b]번 병으로 손이 닿는가.
  bool reaches(int a, int b) {
    if (!hasReachLimit) return true;
    final ax = a % gridPerRow, ay = a ~/ gridPerRow;
    final bx = b % gridPerRow, by = b ~/ gridPerRow;
    if (reachX >= 0 && (ax - bx).abs() > reachX) return false;
    if (reachY >= 0 && (ay - by).abs() > reachY) return false;
    return true;
  }

  @override
  bool operator ==(Object other) =>
      other is RuleSet &&
      other.reachX == reachX &&
      other.reachY == reachY &&
      other.gridPerRow == gridPerRow &&
      other.claimEmpties == claimEmpties &&
      other.claimMono == claimMono &&
      other.lockEmptyOrigin == lockEmptyOrigin;

  @override
  int get hashCode => Object.hash(
      reachX, reachY, gridPerRow, claimEmpties, claimMono, lockEmptyOrigin);

  @override
  String toString() {
    if (this == classic) return '기본 규칙';
    final parts = <String>[
      if (hasReachLimit) '이웃 ±$reachX/±$reachY',
      if (claimEmpties) '빈병전용',
      if (claimMono) '단색전용',
      if (lockEmptyOrigin) '빈병잠금',
    ];
    return parts.join(' + ');
  }
}
