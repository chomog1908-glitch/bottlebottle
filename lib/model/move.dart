/// 한 수(手)의 표현.
///
/// 되돌리기를 위해 "무엇을 몇 개 옮겼는지"를 정확히 기록한다.
/// [count]개를 정확히 되돌려 놓으면 항상 직전 상태로 복원된다.
class Move {
  /// 물을 따라낸 병의 인덱스.
  final int from;

  /// 물을 받은 병의 인덱스.
  final int to;

  /// 옮겨진 액체 칸 수 (1 이상).
  final int count;

  /// 옮겨진 액체의 색 인덱스.
  final int color;

  const Move({
    required this.from,
    required this.to,
    required this.count,
    required this.color,
  });

  @override
  bool operator ==(Object other) =>
      other is Move &&
      other.from == from &&
      other.to == to &&
      other.count == count &&
      other.color == color;

  @override
  int get hashCode => Object.hash(from, to, count, color);

  @override
  String toString() => '$from→$to (색$color ×$count)';
}
