import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/palette.dart';

/// 진행 중인 붓기 한 번.
///
/// 게임 상태는 이미 부어진 뒤의 값이다. 이 정보로 **되감아서** 중간 모습을 그린다.
/// 로직을 애니메이션에 맞춰 늦추면 규칙 코드가 화면 사정에 오염되므로,
/// 규칙은 즉시 끝내고 화면만 뒤따라가게 한다.
class PourAnim {
  final int from;
  final int to;

  /// 옮겨진 칸 수.
  final int count;

  /// 옮겨진 색.
  final int color;

  const PourAnim({
    required this.from,
    required this.to,
    required this.count,
    required this.color,
  });

  /// 한 칸을 붓는 데 걸리는 시간.
  static const Duration perUnit = Duration(milliseconds: 130);

  /// 병을 들어 올려 기울이는 시간.
  static const Duration lift = Duration(milliseconds: 170);

  /// 제자리로 돌아오는 시간.
  static const Duration settle = Duration(milliseconds: 150);

  Duration get total => lift + perUnit * count + settle;

  /// 전체 시간 중 기울이기가 끝나는 지점(0~1).
  double get liftEnd => lift.inMilliseconds / total.inMilliseconds;

  /// 전체 시간 중 붓기가 끝나는 지점(0~1).
  double get pourEnd =>
      (lift + perUnit * count).inMilliseconds / total.inMilliseconds;

  /// 전체 진행도 [t]에서, 아직 옮겨지지 않고 **병에 남아 있는** 칸 수.
  ///
  /// 화면은 이 값만큼을 따라내는 병 위에 도로 얹고, 받는 병에서는 덜어낸다.
  /// 그래서 t=0이면 붓기 직전, t=1이면 붓기 직후 모습이 된다.
  int remainingAt(double t) {
    if (t <= liftEnd) return count;
    if (t >= pourEnd) return 0;
    final p = (t - liftEnd) / (pourEnd - liftEnd);
    return (count - (p * count)).ceil().clamp(0, count);
  }

  /// 진행도 [t]에서 병이 기울어진 정도(0~1).
  double tiltAt(double t) {
    if (t <= liftEnd) return Curves.easeOut.transform(t / liftEnd);
    if (t <= pourEnd) return 1;
    final p = (t - pourEnd) / (1 - pourEnd);
    return 1 - Curves.easeIn.transform(p.clamp(0, 1));
  }

  /// 물줄기가 보이는 구간인가.
  bool streamVisibleAt(double t) => t > liftEnd && t < pourEnd;
}

/// 기울어진 병의 입에서 받는 병으로 떨어지는 물줄기.
class PourStreamPainter extends CustomPainter {
  PourStreamPainter({
    required this.mouth,
    required this.target,
    required this.colorIndex,
    required this.width,
  });

  /// 따라내는 병의 입 위치.
  final Offset mouth;

  /// 물이 떨어지는 지점(받는 병의 수면).
  final Offset target;

  final int colorIndex;

  /// 물줄기 굵기.
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final color = Palette.liquid(colorIndex);

    // 물줄기는 곧게 떨어지지 않는다. 병 입에서 옆으로 나왔다가 중력으로 휜다.
    final control = Offset(mouth.dx + (target.dx - mouth.dx) * 0.25, mouth.dy + 6);
    final path = Path()
      ..moveTo(mouth.dx, mouth.dy)
      ..quadraticBezierTo(control.dx, control.dy, target.dx, target.dy);

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..color = color,
    );

    // 물줄기 왼쪽에 밝은 선을 얹으면 둥근 물기둥처럼 보인다.
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width * 0.3
        ..strokeCap = StrokeCap.round
        ..color = Color.lerp(color, Colors.white, 0.45)!.withValues(alpha: 0.7),
    );

    // 떨어지는 자리에 튀는 물방울 몇 개.
    final splash = Paint()..color = color.withValues(alpha: 0.55);
    for (var i = 0; i < 3; i++) {
      final a = pi + pi * (i + 1) / 4;
      canvas.drawCircle(
        target + Offset(cos(a) * width * 1.1, sin(a) * width * 0.5),
        width * 0.22,
        splash,
      );
    }
  }

  @override
  bool shouldRepaint(PourStreamPainter old) =>
      old.mouth != mouth ||
      old.target != target ||
      old.colorIndex != colorIndex ||
      old.width != width;
}
