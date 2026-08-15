import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/palette.dart';

/// 한 판을 다 맞췄을 때 쏟아지는 색종이.
///
/// 물병 색을 그대로 쓴다. 방금 맞춘 색들이 흩날리는 것이라
/// 화면과 따로 노는 장식이 아니라 결과에 대한 대답처럼 보인다.
class Confetti extends StatefulWidget {
  const Confetti({super.key, this.pieces = 60});

  final int pieces;

  @override
  State<Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<Confetti> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..forward();

  late final List<_Piece> _pieces = _makePieces(widget.pieces);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _ConfettiPainter(_pieces, _controller.value),
          size: Size.infinite,
        ),
      ),
    );
  }

  static List<_Piece> _makePieces(int n) {
    final rng = Random();
    return [
      for (var i = 0; i < n; i++)
        _Piece(
          x: rng.nextDouble(),
          // 조각마다 조금씩 늦게 출발해야 한꺼번에 쏟아지지 않고 흩날린다.
          delay: rng.nextDouble() * 0.35,
          speed: 0.7 + rng.nextDouble() * 0.6,
          drift: (rng.nextDouble() - 0.5) * 0.35,
          size: 5 + rng.nextDouble() * 7,
          spin: (rng.nextDouble() - 0.5) * 12,
          colorIndex: rng.nextInt(Palette.liquids.length),
        ),
    ];
  }
}

class _Piece {
  final double x;
  final double delay;
  final double speed;
  final double drift;
  final double size;
  final double spin;
  final int colorIndex;

  const _Piece({
    required this.x,
    required this.delay,
    required this.speed,
    required this.drift,
    required this.size,
    required this.spin,
    required this.colorIndex,
  });
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.t);

  final List<_Piece> pieces;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in pieces) {
      final local = (t - p.delay) / (1 - p.delay);
      if (local <= 0) continue;

      final fall = local * p.speed;
      final y = fall * size.height * 1.15 - p.size;
      if (y > size.height) continue;

      final x = (p.x + p.drift * fall) * size.width;

      // 끝날 때쯤 서서히 사라진다. 갑자기 없어지면 눈에 거슬린다.
      final fade = local > 0.75 ? (1 - (local - 0.75) / 0.25).clamp(0.0, 1.0) : 1.0;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.spin * fall);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6),
        Paint()..color = Palette.liquid(p.colorIndex).withValues(alpha: fade),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
