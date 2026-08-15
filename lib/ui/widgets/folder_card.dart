import 'package:flutter/material.dart';

/// 폴더 하나를 보여주는 카드.
///
/// 대분류(난이도)와 중분류(병 구성)가 같은 모양을 쓴다.
/// 두 화면의 생김새가 같아야 "폴더를 한 겹 더 열었다"는 게 자연스럽게 읽힌다.
class FolderCard extends StatelessWidget {
  const FolderCard({
    super.key,
    required this.accent,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.done,
    required this.total,
    required this.onTap,
    this.highlighted = false,
    this.highlightLabel = '지금 여기',
  });

  final Color accent;
  final IconData icon;
  final String title;
  final String subtitle;

  /// 완성한 레벨 수 / 전체 레벨 수.
  final int done;
  final int total;

  /// 지금 하고 있는 레벨이 이 폴더에 있는가.
  final bool highlighted;
  final String highlightLabel;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final complete = total > 0 && done == total;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: highlighted ? 3 : 0,
      color: highlighted ? scheme.surfaceContainerHigh : scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: highlighted ? accent : scheme.outlineVariant,
          width: highlighted ? 2.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // 폴더 아이콘에 색을 입혀 목록에서 눈으로 찾기 쉽게 한다.
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  complete ? Icons.folder_special : icon,
                  color: accent,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (highlighted) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(highlightLabel,
                                style: Theme.of(context).textTheme.labelSmall),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: total == 0 ? 0 : done / total,
                        minHeight: 6,
                        backgroundColor: scheme.surfaceContainerHighest,
                        color: accent,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('$done / $total 완성',
                        style: Theme.of(context).textTheme.labelSmall),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
