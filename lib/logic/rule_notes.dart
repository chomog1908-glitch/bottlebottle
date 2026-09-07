/// 레벨마다 붙는 특별 규칙과, 그것을 사람 말로 옮긴 설명.
///
/// **규칙이 바뀌는데 말해주지 않으면 그건 버그로 느껴진다.** 빈 병이 갑자기
/// 잠기는데 이유를 모르면, 어머니는 앱이 고장 났다고 생각하신다.
/// 그래서 규칙마다 설명을 짝지어 두고, 처음 만나는 판에서 한 번 보여준 뒤
/// 화면 위 ⓘ 단추로 언제든 다시 볼 수 있게 한다.
library;

import '../model/rule_set.dart';

/// 특별 규칙 하나에 대한 안내.
class RuleNote {
  /// 안내 카드를 한 번 보여줬는지 기억할 때 쓰는 이름.
  final String id;

  /// 카드 제목.
  final String title;

  /// 무엇이 달라지는지 한 줄로.
  final String summary;

  /// 왜 그런지, 어떻게 하면 되는지. 두세 줄.
  final String detail;

  /// 카드에 얹을 그림 문자.
  final String emoji;

  const RuleNote({
    required this.id,
    required this.title,
    required this.summary,
    required this.detail,
    required this.emoji,
  });
}

/// 안내 문구 모음.
///
/// 글을 짧게 쓴다. 규칙 설명이 길면 읽지 않으시고, 읽지 않으면 없는 것과 같다.
/// 겁주지 않는다 — "어려워집니다"가 아니라 "이렇게 하시면 됩니다"로 적는다.
class RuleNotes {
  /// 이웃 제한 — 닿는 거리가 정해진다.
  static RuleNote reach(int dx, int dy) => RuleNote(
        id: 'reach_${dx}_$dy',
        emoji: '📏',
        title: '가까운 병끼리만',
        summary: '이제 가까이 있는 병으로만 물을 옮길 수 있습니다.',
        detail: '병을 집으면 부을 수 있는 병만 밝게 보입니다. '
            '어두운 병은 너무 멀어서 지금은 닿지 않습니다.\n'
            '어디에 무엇을 두는지가 중요해집니다.',
      );

  /// 트릭 A — 빈 병은 처음 담은 색 전용이 된다.
  static const RuleNote emptyClaimed = RuleNote(
    id: 'trick_a',
    emoji: '🫙',
    title: '빈 병은 한 색만',
    summary: '빈 병에 한 번 물을 담으면, 그 병은 그 색 전용이 됩니다.',
    detail: '나중에 그 병을 비워도 색은 그대로 정해져 있습니다.\n'
        '어느 빈 병에 어떤 색을 담을지 먼저 정하고 시작하시면 편합니다.',
  );

  /// 트릭 B — 한 색만 남은 병도 그 색 전용. 비우면 풀린다.
  static const RuleNote monoLocked = RuleNote(
    id: 'trick_b',
    emoji: '🎨',
    title: '한 색만 남으면 그 색 전용',
    summary: '병에 한 가지 색만 남으면, 그 병은 그 색만 받습니다.',
    detail: '그 병을 완전히 비우면 다시 아무 색이나 담을 수 있습니다.\n'
        '색을 섞어 두는 것이 오히려 자유로울 때가 있습니다.',
  );

  /// [rules]에 해당하는 안내를 모아 준다. 규칙이 없으면 빈 목록.
  ///
  /// 순서가 곧 읽는 순서다. 이웃 제한을 먼저 두는 이유: 그건 어디로 부을 수
  /// 있는지에 대한 것이라 판을 보는 방식 자체를 바꾼다. 잠금은 그 다음이다.
  static List<RuleNote> forRules(RuleSet rules) => [
        if (rules.hasReachLimit) reach(rules.reachX, rules.reachY),
        if (rules.claimEmpties) emptyClaimed,
        if (rules.claimMono) monoLocked,
        if (rules.lockEmptyOrigin) noTakeBack,
      ];

  /// 트릭 C — 빈 병 출신은 가득 차기 전까지 되뺄 수 없다.
  static const RuleNote noTakeBack = RuleNote(
    id: 'trick_c',
    emoji: '🔒',
    title: '빈 병에 담으면 되돌릴 수 없습니다',
    summary: '빈 병에서 시작한 병은, 가득 찰 때까지 물을 도로 뺄 수 없습니다.',
    detail: '가득 채워 완성하면 다시 쓸 수 있습니다.\n'
        '빈 병에 물을 담기 전에 한 번 더 생각해 보세요.\n'
        '되돌리기는 언제든 쓰실 수 있습니다.',
  );
}
