import 'package:flutter/material.dart';

import '../../logic/rule_notes.dart';

/// 새 규칙을 처음 만났을 때 뜨는 안내, 그리고 ⓘ로 다시 볼 때 쓰는 화면.
///
/// **규칙이 바뀌는데 말해주지 않으면 그건 버그로 느껴진다.**
/// 빈 병이 갑자기 잠기는데 이유를 모르면 앱이 고장 났다고 생각하시게 된다.
///
/// 카드는 처음 한 번만 저절로 뜨고, 그 뒤로는 ⓘ 단추로만 연다.
/// 매번 뜨면 잔소리가 되고, 잔소리는 읽지 않고 닫게 된다.
class RuleNoteSheet extends StatelessWidget {
  const RuleNoteSheet({
    super.key,
    required this.notes,
    this.title = '이 판의 규칙',
  });

  final List<RuleNote> notes;
  final String title;

  /// 안내를 띄운다. 닫으면 완료된다.
  static Future<void> show(
    BuildContext context,
    List<RuleNote> notes, {
    String title = '이 판의 규칙',
  }) {
    if (notes.isEmpty) return Future<void>.value();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => RuleNoteSheet(notes: notes, title: title),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            // 규칙이 여럿일 수 있다. 작은 화면에서도 다 읽히도록 스크롤을 둔다.
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final n in notes) ...[
                      _NoteBlock(note: n),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: scheme.primary,
              ),
              child: const Text('알겠습니다', style: TextStyle(fontSize: 17)),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoteBlock extends StatelessWidget {
  const _NoteBlock({required this.note});

  final RuleNote note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(note.emoji, style: const TextStyle(fontSize: 32)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(note.title,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(note.summary, style: theme.textTheme.bodyLarge),
                const SizedBox(height: 8),
                Text(
                  note.detail,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: scheme.onSurfaceVariant, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
