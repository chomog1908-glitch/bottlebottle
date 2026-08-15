import 'package:flutter/material.dart';

import '../theme/palette.dart';
import 'liquid_painter.dart';

/// 병 하나를 그리고 터치를 받는다.
///
/// 실제 그림은 [BottlePainter]가 맡는다. 여기서는 크기·터치 영역·떠오르는 움직임만 다룬다.
class BottleWidget extends StatelessWidget {
  const BottleWidget({
    super.key,
    required this.contents,
    required this.capacity,
    required this.onTap,
    this.selected = false,
    this.hinted = false,
    this.showSymbols = false,
    this.unitHeight = 34,
    this.width = 56,
    this.paintKey,
    this.shakeOffset = 0,
    this.dimmed = false,
  });

  /// 병이 화면 어디에 그려졌는지 알아내기 위한 키.
  /// 붓기 애니메이션이 두 병의 위치를 알아야 물줄기를 그릴 수 있다.
  final GlobalKey? paintKey;

  /// 좌우로 흔들리는 정도(픽셀). 부을 수 없는 병을 눌렀을 때 쓴다.
  final double shakeOffset;

  /// 흐리게 그린다. 붓는 동안 원래 자리의 병을 감추는 데 쓴다.
  final bool dimmed;

  /// 병의 내용물. **인덱스 0이 바닥**이다.
  final List<int> contents;
  final int capacity;
  final VoidCallback onTap;

  /// 지금 물을 들고 있는 병인가. 살짝 떠오르게 그린다.
  final bool selected;

  /// 힌트로 지목된 병인가. 테두리를 강조한다.
  final bool hinted;

  /// 색약 모드. 각 칸에 기호를 함께 표시한다.
  final bool showSymbols;

  final double unitHeight;
  final double width;

  /// 테두리 굵기는 강조 여부와 관계없이 항상 같다.
  /// 굵기를 바꾸면 강조될 때마다 병 크기가 들썩인다. 굵기는 두고 **색만** 바꾼다.
  static const double _outlineWidth = 3;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final size = Size(width, unitHeight * capacity);

    final outline = hinted
        ? scheme.tertiary
        : selected
            ? scheme.primary
            : scheme.outlineVariant;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        // 들고 있는 병은 위로 떠오른다. 무엇을 들었는지 한눈에 보이게.
        // 병이 작을 때 18픽셀이나 띄우면 윗줄을 침범하므로 크기에 맞춰 줄인다.
        transform: Matrix4.translationValues(
          shakeOffset,
          selected ? -(unitHeight * 0.5).clamp(6.0, 18.0) : 0,
          0,
        ),
        // 손가락이 닿는 영역은 병보다 넉넉하게 잡는다. 잘못 눌러 짜증나는 일을 줄인다.
        // 병이 작아지는 후반 레벨에서는 여백도 함께 줄여야 화면에 다 들어간다.
        padding: EdgeInsets.symmetric(
          horizontal: (width * 0.12).clamp(2.0, 6.0),
          vertical: (unitHeight * 0.2).clamp(3.0, 8.0),
        ),
        child: Opacity(
          // 붓는 동안에는 이 자리의 병을 감춘다. 기울어진 사본이 대신 그려진다.
          opacity: dimmed ? 0 : 1,
          child: CustomPaint(
            key: paintKey,
            size: size,
            painter: BottlePainter(
              contents: contents,
              capacity: capacity,
              glassColor: scheme.surfaceContainerHighest,
              outlineColor: outline,
              outlineWidth: _outlineWidth,
              showSymbols: showSymbols,
              symbolColorOf: Palette.onLiquid,
            ),
          ),
        ),
      ),
    );
  }
}
