import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 큰 숫자 하나를 보여주는 칸.
///
/// 대시보드의 기본 단위다. 숫자를 크게, 이름을 작게. 설명은 넣지 않는다 —
/// 한 칸에 문장이 들어가기 시작하면 대시보드가 아니라 보고서가 된다.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    required this.emoji,
    required this.tint,
    this.suffix,
  });

  final String label;
  final String value;

  /// 값 뒤에 작게 붙는 단위.
  final String? suffix;

  final String emoji;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Color.alphaBlend(tint.withValues(alpha: 0.12), scheme.surface),
        border: Border.all(color: tint.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: tint,
                      ),
                ),
                if (suffix != null) ...[
                  const SizedBox(width: 3),
                  Text(
                    suffix!,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 비율 하나를 고리로 보여준다.
///
/// 막대보다 자리를 덜 먹으면서 "얼마나 찼는가"가 한눈에 들어온다.
class StatRing extends StatelessWidget {
  const StatRing({
    super.key,
    required this.ratio,
    required this.center,
    required this.label,
    required this.tint,
    this.size = 108,
  });

  /// 0.0 ~ 1.0.
  final double ratio;

  /// 고리 한가운데 적을 글자.
  final String center;

  final String label;
  final Color tint;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _RingPainter(
              ratio: ratio.clamp(0, 1),
              tint: tint,
              track: scheme.surfaceContainerHighest,
            ),
            child: Center(
              child: Text(
                center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: tint,
                    ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.ratio, required this.tint, required this.track});

  final double ratio;
  final Color tint;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 11.0;
    final rect = Rect.fromLTWH(0, 0, size.width, size.height)
        .deflate(stroke / 2 + 1);

    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = track;
    canvas.drawArc(rect, 0, math.pi * 2, false, base);

    if (ratio <= 0) return;

    // 12시에서 시작해 시계 방향으로 감는다. 시계와 같은 방향이라야 자연스럽다.
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * ratio,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: -math.pi / 2,
          endAngle: math.pi * 1.5,
          colors: [tint.withValues(alpha: 0.55), tint],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.ratio != ratio || old.tint != tint || old.track != track;
}

/// 이름 · 막대 · 값이 한 줄로 놓인 가로 막대.
class StatBar extends StatelessWidget {
  const StatBar({
    super.key,
    required this.label,
    required this.value,
    required this.ratio,
    required this.tint,
    this.note,
  });

  final String label;

  /// 막대 오른쪽에 적을 값.
  final String value;

  /// 이름 아래 작게 붙는 설명.
  final String? note;

  final double ratio;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                value,
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(color: tint, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: ratio.clamp(0, 1),
              minHeight: 8,
              backgroundColor: scheme.surfaceContainerHighest,
              color: tint,
            ),
          ),
          if (note != null) ...[
            const SizedBox(height: 3),
            Text(note!, style: Theme.of(context).textTheme.labelSmall),
          ],
        ],
      ),
    );
  }
}

/// 대시보드 안의 한 구획. 제목 + 내용.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: scheme.surfaceContainerLow,
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
