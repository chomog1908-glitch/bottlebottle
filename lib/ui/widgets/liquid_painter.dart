import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/palette.dart';

/// 병 하나(유리 + 액체)를 직접 그린다.
///
/// 이미지 에셋을 쓰지 않고 그리는 이유: 어떤 해상도에서도 선명하고,
/// 색이 12가지나 되는데 색마다 그림을 준비할 필요가 없다.
class BottlePainter extends CustomPainter {
  BottlePainter({
    required this.contents,
    required this.capacity,
    required this.glassColor,
    required this.outlineColor,
    required this.outlineWidth,
    required this.showSymbols,
    required this.symbolColorOf,
  });

  /// 병의 내용물. **인덱스 0이 바닥**이다.
  final List<int> contents;
  final int capacity;

  /// 빈 유리 부분의 색.
  final Color glassColor;

  final Color outlineColor;
  final double outlineWidth;

  final bool showSymbols;

  /// 색 인덱스 → 그 위에 얹을 기호의 색.
  final Color Function(int) symbolColorOf;

  /// 병 바깥 윤곽. 바닥은 둥글고 입구 쪽은 살짝만 둥글다.
  ///
  /// 진짜 병처럼 바닥을 둥글게 해두면 액체가 아래에서 차오르는 느낌이 산다.
  static Path bottleShape(Size size) {
    final r = size.width / 2;
    return Path()
      ..addRRect(
        RRect.fromRectAndCorners(
          Offset.zero & size,
          topLeft: const Radius.circular(6),
          topRight: const Radius.circular(6),
          bottomLeft: Radius.circular(r),
          bottomRight: Radius.circular(r),
        ),
      );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final shape = bottleShape(size);

    // 1) 빈 유리
    canvas.drawPath(shape, Paint()..color = glassColor);

    // 2) 액체. 병 모양 안으로 잘라내고 그린다.
    //    이래야 둥근 바닥을 액체가 정확히 따라간다.
    canvas.save();
    canvas.clipPath(shape);
    _paintLiquid(canvas, size);
    _paintGlassHighlight(canvas, size);
    canvas.restore();

    // 3) 테두리는 잘라내기 밖에서 그린다. 안쪽에서 그리면 선의 절반이 잘려 얇아 보인다.
    canvas.drawPath(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = outlineWidth
        ..color = outlineColor,
    );
  }

  void _paintLiquid(Canvas canvas, Size size) {
    final unit = size.height / capacity;

    for (var i = 0; i < contents.length; i++) {
      // i번째 칸은 바닥에서 i칸 위에 있다.
      final top = size.height - unit * (i + 1);
      final rect = Rect.fromLTWH(0, top, size.width, unit);
      final colorIndex = contents[i];

      // 위쪽을 아주 살짝 밝게 해 액체에 두께감을 준다.
      final base = Palette.liquid(colorIndex);
      canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.lerp(base, Colors.white, 0.14)!,
              base,
            ],
          ).createShader(rect),
      );

      // 칸 경계에 얇은 그늘을 넣어 같은 색이 몇 칸인지 셀 수 있게 한다.
      // 이게 없으면 같은 색 4칸이 한 덩어리로 보여 남은 칸을 못 센다.
      if (i > 0) {
        canvas.drawLine(
          Offset(0, top + unit),
          Offset(size.width, top + unit),
          Paint()
            ..color = Colors.black.withValues(alpha: 0.10)
            ..strokeWidth = 1,
        );
      }

      if (showSymbols) _paintSymbol(canvas, rect, colorIndex);
    }
  }

  void _paintSymbol(Canvas canvas, Rect rect, int colorIndex) {
    final tp = TextPainter(
      text: TextSpan(
        text: Palette.symbol(colorIndex),
        style: TextStyle(
          color: symbolColorOf(colorIndex),
          fontSize: rect.height * 0.5,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(rect.center.dx - tp.width / 2, rect.center.dy - tp.height / 2),
    );
  }

  /// 유리에 비친 빛. 왼쪽에 세로로 흐릿한 띠 하나면 충분히 유리처럼 보인다.
  void _paintGlassHighlight(Canvas canvas, Size size) {
    final w = size.width * 0.16;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.16, size.height * 0.06, w, size.height * 0.82),
      Radius.circular(w / 2),
    );
    canvas.drawRRect(rect, Paint()..color = Colors.white.withValues(alpha: 0.18));
  }

  @override
  bool shouldRepaint(BottlePainter old) =>
      !listEquals(old.contents, contents) ||
      old.capacity != capacity ||
      old.glassColor != glassColor ||
      old.outlineColor != outlineColor ||
      old.outlineWidth != outlineWidth ||
      old.showSymbols != showSymbols;
}
