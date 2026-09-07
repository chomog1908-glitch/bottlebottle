import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../controller/game_controller.dart';
import '../../controller/settings_controller.dart';
import '../../logic/rule_notes.dart';
import '../../model/rule_set.dart';
import '../../services/achievement_tracker.dart';
import '../../services/audio.dart';
import '../../services/storage.dart';
import '../theme/palette.dart';
import '../widgets/achievement_toast.dart';
import '../widgets/board_layout.dart';
import '../widgets/bottle_widget.dart';
import '../widgets/confetti.dart';
import '../widgets/pour_overlay.dart';
import '../widgets/rule_note_card.dart';
import 'achievements_screen.dart';
import 'difficulty_screen.dart';
import 'settings_screen.dart';

/// 메인 게임 화면.
class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.settings,
    required this.audio,
    this.startLevel,
  });

  final SettingsController settings;
  final AudioService audio;

  /// 이 레벨로 시작한다. 없으면 **저장된 판을 이어서** 한다.
  final int? startLevel;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  final Storage _storage = Storage();

  /// 저장된 판을 불러오기 전까지는 null이다.
  GameController? _controller;

  late final AchievementTracker _achievements = AchievementTracker(_storage);

  /// 붓기 연출.
  late final AnimationController _pourCtl = AnimationController(
    vsync: this,
    duration: PourAnim.perUnit,
  );
  PourAnim? _pour;

  /// 부을 수 없는 병을 눌렀을 때의 흔들림.
  late final AnimationController _shakeCtl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );
  int _shownRejectTick = 0;
  int? _shakingBottle;

  /// 완성 색종이.
  bool _confetti = false;

  int? _shownSelected;

  /// 병이 화면 어디에 그려졌는지 알아내기 위한 키들.
  /// 물줄기를 그리려면 따라내는 병과 받는 병의 좌표가 필요하다.
  final GlobalKey _boardKey = GlobalKey();
  List<GlobalKey> _bottleKeys = [];

  /// 이미 보여준 규칙 안내의 이름들. 같은 안내를 두 번 띄우지 않는다.
  Set<String> _seenNotes = {};

  /// 안내를 마지막으로 확인한 규칙. 레벨이 바뀌어도 규칙이 같으면 다시 보지 않는다.
  RuleSet? _notedRules;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  /// 저장된 판과 기록을 불러와 게임을 준비한다.
  Future<void> _boot() async {
    // 레벨을 지정해 들어왔으면 저장된 판은 읽지 않는다.
    // 홈에서 "레벨 고르기"로 들어온 경우가 여기다.
    final saved = widget.startLevel == null ? await _storage.loadGame() : null;
    await _achievements.load();
    _seenNotes = await _storage.loadSeenRuleNotes();

    final c = GameController(startLevel: widget.startLevel ?? 1);
    // 복원은 **기록에 넣지 않는다.** 이미 세어 둔 수를 다시 세게 된다.
    // 그래서 사건을 듣기 시작하는 것은 복원이 끝난 뒤다.
    if (saved != null) {
      c.restore(saved.level, saved.moves, board: saved.board);
    }
    c.onEvent = _onGameEvent;
    c.addListener(_onControllerChanged);

    if (!mounted) return;
    setState(() {
      _controller = c;
      _shownSelected = c.selected;
    });
    _maybeShowRuleNotes(c);
  }

  /// 이 판에 처음 보는 규칙이 있으면 안내를 한 번 띄운다.
  ///
  /// 레벨이 아니라 **규칙**을 기준으로 기억한다. 같은 규칙이 150레벨 이어지는데
  /// 레벨마다 띄우면 잔소리가 된다. 규칙이 새로 붙을 때만 뜬다.
  Future<void> _maybeShowRuleNotes(GameController c) async {
    final rules = c.state.rules;
    if (rules == _notedRules) return;
    _notedRules = rules;

    final unseen = [
      for (final n in RuleNotes.forRules(rules))
        if (!_seenNotes.contains(n.id)) n,
    ];
    if (unseen.isEmpty) return;

    // 판이 그려진 뒤에 띄운다. 화면이 뜨기도 전에 덮으면 무엇에 대한 말인지 모른다.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;

    for (final n in unseen) {
      _seenNotes.add(n.id);
      await _storage.markRuleNoteSeen(n.id);
    }
    if (!mounted) return;
    await RuleNoteSheet.show(context, unseen, title: '새로운 규칙');
  }

  @override
  void dispose() {
    _controller?.removeListener(_onControllerChanged);
    _controller?.dispose();
    _pourCtl.dispose();
    _shakeCtl.dispose();
    super.dispose();
  }

  // ── 저장과 기록 ──────────────────────────────────────────────────────

  void _persist() {
    final c = _controller;
    if (c == null) return;
    // 시작 보드를 함께 남긴다. 생성기가 바뀌어도 두시던 판이 살아남는다.
    _storage.saveGame(c.level, c.state.history, board: c.startingBoard);
    _storage.saveMaxLevel(c.level);
    // 다 푼 레벨은 폴더 화면에 완성 표시로 남는다.
    if (c.isSolved) _storage.addClearedLevel(c.level);
  }

  /// 게임에서 일어난 일을 기록으로 옮기고, 새로 얻은 도전과제가 있으면 축하한다.
  Future<void> _onGameEvent(GameEvent event) async {
    final c = _controller;
    if (c == null) return;

    // 연출은 기록과 상관없이 바로 시작한다. 저장을 기다리게 하면 손맛이 죽는다.
    switch (event) {
      case GameEvent.move:
        _startPour();
      case GameEvent.solved:
        _celebrate();
      case GameEvent.hint:
      case GameEvent.undo:
      case GameEvent.restart:
      case GameEvent.skip:
        break;
    }

    final fresh = await _achievements.handle(event, c);
    if (fresh.isEmpty || !mounted) return;

    // 완성 배너와 색종이가 먼저 지나가고 나서 축하가 얹히도록 한 박자 둔다.
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    await showAchievementToasts(context, fresh);
  }

  // ── 연출 ────────────────────────────────────────────────────────────

  void _onControllerChanged() {
    final c = _controller!;

    // 레벨이 바뀌어 새 규칙이 붙었으면 안내를 띄운다.
    // (다음 레벨로 가거나 레벨을 골라 들어온 경우가 여기다.)
    if (c.state.rules != _notedRules) _maybeShowRuleNotes(c);

    // 병을 새로 집었으면 집는 소리를 낸다.
    if (c.selected != null && c.selected != _shownSelected) {
      widget.audio.play(Sfx.pick);
    }
    _shownSelected = c.selected;

    // 부을 수 없는 곳을 눌렀으면 그 병을 흔든다.
    if (c.rejectTick != _shownRejectTick) {
      _shownRejectTick = c.rejectTick;
      _shakingBottle = c.rejected;
      widget.audio.play(Sfx.wrong);
      HapticFeedback.selectionClick();
      _shakeCtl.forward(from: 0);
    }

    _persist();
    setState(() {});
  }

  void _celebrate() {
    _confetti = true;
    widget.audio.play(Sfx.clear);
    HapticFeedback.mediumImpact();
    // 색종이는 한 번 떨어지고 끝난다. 계속 흩날리면 다음 판 버튼이 거슬린다.
    Future.delayed(const Duration(milliseconds: 2400), () {
      if (mounted) setState(() => _confetti = false);
    });
  }

  /// 방금 둔 수에 맞춰 붓기 연출을 시작한다.
  ///
  /// 게임 상태는 이미 부어진 뒤다. 연출은 그것을 **되감아서** 보여준다.
  /// 규칙을 애니메이션에 맞춰 늦추면 규칙 코드가 화면 사정에 오염된다.
  void _startPour() {
    final c = _controller;
    if (c == null || c.state.history.isEmpty) return;

    final m = c.state.history.last;
    final anim = PourAnim(
      from: m.from,
      to: m.to,
      count: m.count,
      color: m.color,
    );
    _pour = anim;
    _pourCtl.duration = anim.total;
    widget.audio.playPour();

    _pourCtl.forward(from: 0).then((_) {
      widget.audio.stopPour();
      if (mounted) setState(() => _pour = null);
    });
  }

  /// 화면에 그릴 병 내용물. 붓는 중에는 중간 모습을 만들어 준다.
  List<int> _visualContents(GameController c, int index) {
    final anim = _pour;
    if (anim == null) return c.state.bottleAt(index);

    final remaining = anim.remainingAt(_pourCtl.value);
    if (remaining == 0) return c.state.bottleAt(index);

    if (index == anim.from) {
      // 아직 안 넘어간 만큼을 도로 얹는다.
      return [
        ...c.state.bottleAt(index),
        ...List.filled(remaining, anim.color),
      ];
    }
    if (index == anim.to) {
      // 아직 안 받은 만큼을 덜어낸다.
      final b = c.state.bottleAt(index);
      return b.sublist(0, b.length - remaining);
    }
    return c.state.bottleAt(index);
  }

  /// 병이 화면 어디에 그려졌는지. 아직 배치되기 전이면 null.
  Rect? _bottleRect(int index) {
    if (index >= _bottleKeys.length) return null;
    final box =
        _bottleKeys[index].currentContext?.findRenderObject() as RenderBox?;
    final board = _boardKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || board == null || !box.hasSize || !board.hasSize) {
      return null;
    }
    return box.localToGlobal(Offset.zero, ancestor: board) & box.size;
  }

  double _shakeOffsetFor(int index) {
    if (_shakingBottle != index || !_shakeCtl.isAnimating) return 0;
    final v = _shakeCtl.value;
    // 점점 잦아드는 좌우 흔들림. 끝으로 갈수록 폭이 줄어 자연스럽게 멈춘다.
    return sin(v * pi * 6) * 7 * (1 - v);
  }

  // ── 화면 ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (c == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_bottleKeys.length != c.state.bottleCount) {
      _bottleKeys = [for (var i = 0; i < c.state.bottleCount; i++) GlobalKey()];
    }

    return Scaffold(
      appBar: AppBar(
        // 뒤로 가기 화살표 대신 집 모양을 둔다. 어디로 가는지가 그림에 그대로 보인다.
        // 두던 판은 이미 저장돼 있으므로 언제 나가도 그대로 이어진다.
        leading: IconButton(
          onPressed: _goHome,
          icon: const Icon(Icons.home_outlined),
          tooltip: '홈',
        ),
        title: Text('레벨 ${c.level}  ·  ${c.config.difficultyLabel}'),
        actions: [
          // 규칙이 붙은 판에서만 나타난다. 설명할 것이 없으면 단추도 없다.
          if (RuleNotes.forRules(c.state.rules).isNotEmpty)
            IconButton(
              onPressed: () => RuleNoteSheet.show(
                  context, RuleNotes.forRules(c.state.rules)),
              icon: const Icon(Icons.info_outline),
              tooltip: '이 판의 규칙',
            ),
          IconButton(
            onPressed: _openAchievements,
            icon: const Icon(Icons.emoji_events_outlined),
            tooltip: '도전과제',
          ),
          IconButton(
            onPressed: _openChapters,
            icon: const Icon(Icons.folder_outlined),
            tooltip: '레벨 고르기',
          ),
          IconButton(
            onPressed: _openSettings,
            icon: const Icon(Icons.settings_outlined),
            tooltip: '설정',
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(child: _board(c)),
                if (c.isSolved) _winBanner(c) else _controls(c),
              ],
            ),
            if (_confetti) const Positioned.fill(child: Confetti()),
          ],
        ),
      ),
    );
  }

  /// 지금 들고 있는 병에서 [i]로 부을 수 없는가.
  ///
  /// 아무것도 안 들고 있으면 어둡게 하지 않는다. 판 전체가 어두워지면
  /// 무엇이 문제인지가 아니라 화면이 고장 난 것처럼 보인다.
  bool _isUnreachable(GameController c, int i) {
    final from = c.selected;
    if (from == null || from == i) return false;
    if (!c.state.rules.hasReachLimit && !c.state.rules.hasLocks) return false;
    return !c.state.canPour(from, i);
  }

  /// [i]번 병이 전용으로 굳은 색. 잠기지 않았으면 null.
  Color? _lockedColorOf(GameController c, int i) {
    final locked = c.state.claimedColor(i);
    return locked == null ? null : Palette.liquid(locked);
  }

  Widget _board(GameController c) {
    // 병 개수와 깊이는 레벨마다 다르므로 남은 공간에 맞춰 크기를 정한다.
    return LayoutBuilder(
      builder: (context, constraints) {
        final metrics = computeBoardMetrics(
          available: Size(
            constraints.maxWidth - 16,
            constraints.maxHeight - 16,
          ),
          bottleCount: c.state.bottleCount,
          capacity: c.state.capacity,
          // 규칙이 격자를 정한 판은 그 줄 수를 그대로 쓴다.
          // 그래야 "가까운 병"이 눈에 보이는 그대로가 된다.
          fixedPerRow:
              c.state.rules.hasReachLimit ? c.state.rules.gridPerRow : null,
        );

        // 계산한 줄 수대로 병을 나눠 담는다.
        final rows = <List<int>>[];
        for (var i = 0; i < c.state.bottleCount; i += metrics.perRow) {
          rows.add([
            for (
              var j = i;
              j < i + metrics.perRow && j < c.state.bottleCount;
              j++
            )
              j,
          ]);
        }

        return AnimatedBuilder(
          animation: Listenable.merge([_pourCtl, _shakeCtl]),
          builder: (context, _) => Stack(
            key: _boardKey,
            children: [
              Positioned.fill(
                child: SingleChildScrollView(
                  // 스크롤뷰는 자식에게 높이를 무한으로 준다. 그대로 두면 그 안의
                  // 가운데 정렬이 아무 일도 하지 않아 병이 늘 화면 위쪽에 몰린다.
                  // 최소 높이를 화면만큼 잡아 줘야 세로 가운데에 놓인다.
                  // (넘칠 때는 이 값보다 커지므로 스크롤은 그대로 된다.)
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (final row in rows)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                for (final i in row)
                                  BottleWidget(
                                    paintKey: _bottleKeys[i],
                                    contents: _visualContents(c, i),
                                    capacity: c.state.capacity,
                                    width: metrics.bottleWidth,
                                    unitHeight: metrics.unitHeight,
                                    selected: c.selected == i,
                                    hinted: c.isHinted(i),
                                    showSymbols: widget.settings.showSymbols,
                                    shakeOffset: _shakeOffsetFor(i),
                                    // 붓는 동안 이 자리의 병은 감춘다.
                                    // 기울어진 사본이 대신 그려지기 때문이다.
                                    dimmed: _pour?.from == i,
                                    // 병을 들고 있을 때, 그 병에서 부을 수 없는
                                    // 병은 어둡게 한다. 눌러 보고 안 되는 것보다
                                    // 누르기 전에 보이는 편이 낫다.
                                    unreachable: _isUnreachable(c, i),
                                    // 전용으로 굳은 병은 그 색으로 테두리를 두른다.
                                    lockedColor: _lockedColorOf(c, i),
                                    onTap: () => _tap(c, i),
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              ..._pourOverlay(c, metrics),
            ],
          ),
        );
      },
    );
  }

  void _tap(GameController c, int index) {
    // 붓는 중에는 입력을 받지 않는다. 연출과 상태가 어긋나 보이는 것을 막는다.
    if (_pour != null) return;
    c.tapBottle(index);
  }

  /// 기울어진 병과 물줄기. 붓는 중이 아니면 빈 목록.
  List<Widget> _pourOverlay(GameController c, BoardMetrics metrics) {
    final anim = _pour;
    if (anim == null) return const [];

    final src = _bottleRect(anim.from);
    final dst = _bottleRect(anim.to);
    // 아직 위치를 모르면 이번 프레임은 건너뛴다. 다음 프레임에 그려진다.
    if (src == null || dst == null) return const [];

    final t = _pourCtl.value;
    final tilt = anim.tiltAt(t);

    // 받는 병의 어느 쪽에 설지. 원래 있던 쪽에 서야 움직임이 짧고 자연스럽다.
    final side = src.center.dx <= dst.center.dx ? -1.0 : 1.0;

    final pourPos = Offset(
      dst.center.dx + side * dst.width * 0.9 - src.width / 2,
      dst.top - src.height * 0.5,
    );
    final pos = Offset.lerp(src.topLeft, pourPos, tilt)!;

    // 병 입이 받는 병 쪽으로 기울도록 방향을 잡는다.
    final angle = -side * 0.95 * tilt;

    final widgets = <Widget>[];

    if (anim.streamVisibleAt(t)) {
      // 회전한 병의 입 위치를 직접 계산한다.
      final center = pos + Offset(src.width / 2, src.height / 2);
      final mouth =
          center +
          Offset(sin(angle) * src.height / 2, -cos(angle) * src.height / 2);

      // 받는 병의 지금 수면 높이. 물이 차오르는 곳으로 정확히 떨어져야 한다.
      final filled = _visualContents(c, anim.to).length;
      final surface = Offset(
        dst.center.dx,
        dst.bottom - filled * metrics.unitHeight,
      );

      widgets.add(
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: PourStreamPainter(
                mouth: mouth,
                target: surface,
                colorIndex: anim.color,
                width: metrics.bottleWidth * 0.2,
              ),
            ),
          ),
        ),
      );
    }

    widgets.add(
      Positioned(
        left: pos.dx,
        top: pos.dy,
        width: src.width,
        height: src.height,
        child: IgnorePointer(
          child: Transform.rotate(
            angle: angle,
            child: BottleWidget(
              contents: _visualContents(c, anim.from),
              capacity: c.state.capacity,
              width: metrics.bottleWidth,
              unitHeight: metrics.unitHeight,
              showSymbols: widget.settings.showSymbols,
              onTap: () {},
            ),
          ),
        ),
      ),
    );

    return widgets;
  }

  Widget _controls(GameController c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 수 개수와 함께 빈 병을 몇 개나 쓰고 있는지 보여준다.
          // 빈 병은 이 게임의 진짜 자원이라, 아껴 쓰는 것 자체가 실력이다.
          Text(
            '${c.moveCount}수   ·   빈 병 ${c.emptiesInUse}/${c.emptyBottleBudget} 사용 중',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              // 되돌리기와 힌트에는 어떤 제한도 없다. 이 게임의 취지다.
              FilledButton.tonalIcon(
                onPressed: c.canUndo ? c.undo : null,
                icon: const Icon(Icons.undo),
                label: const Text('되돌리기'),
              ),
              FilledButton.tonalIcon(
                onPressed: c.requestHint,
                icon: const Icon(Icons.lightbulb_outline),
                label: const Text('힌트'),
              ),
              FilledButton.tonalIcon(
                onPressed: c.restart,
                icon: const Icon(Icons.refresh),
                label: const Text('다시'),
              ),
              // 정 안 풀리면 그냥 넘어가도 된다. 벌칙 없음.
              FilledButton.tonalIcon(
                onPressed: c.nextLevel,
                icon: const Icon(Icons.skip_next),
                label: const Text('건너뛰기'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 빈 병을 얼마나 아꼈는지에 대한 한 줄 평.
  ///
  /// 못한 것을 지적하지 않는다. 아꼈으면 칭찬하고, 다 썼으면 담담히 사실만 적는다.
  /// 잘해야 한다는 압박을 주는 순간 이 게임의 취지가 무너진다.
  String _emptyUseRemark(GameController c) {
    final used = c.peakEmptiesUsed;
    final budget = c.emptyBottleBudget;
    if (used == 0) return '빈 병을 한 개도 쓰지 않았습니다!';
    if (used < budget) return '빈 병 $budget개 중 $used개만 쓰고 완성!';
    return '빈 병 $budget개를 모두 썼습니다';
  }

  Widget _winBanner(GameController c) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      color: scheme.primaryContainer,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '완성!  ${c.moveCount}수',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: scheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _emptyUseRemark(c),
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: scheme.onPrimaryContainer),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: c.nextLevel,
            icon: const Icon(Icons.arrow_forward),
            label: Text('레벨 ${c.level + 1}로'),
          ),
        ],
      ),
    );
  }

  // ── 다른 화면으로 ────────────────────────────────────────────────────

  /// 도전과제 화면을 연다. 여기서 무언가 열리거나 주어지지는 않는다.
  void _openAchievements() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AchievementsScreen(
          stats: _achievements.stats,
          earnedOn: _achievements.earnedOn,
        ),
      ),
    );
  }

  /// 홈으로 돌아간다.
  ///
  /// 중간에 어떤 화면을 거쳐 왔든 첫 화면까지 한 번에 간다.
  /// 뒤로 가기를 여러 번 누르게 만들지 않는다.
  void _goHome() => Navigator.of(context).popUntil((r) => r.isFirst);

  /// 폴더 화면을 열고, 고른 레벨로 옮겨 간다.
  Future<void> _openChapters() async {
    final c = _controller;
    if (c == null) return;

    final picked = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) => DifficultyScreen(currentLevel: c.level),
      ),
    );
    if (picked != null && mounted) c.loadLevel(picked);
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(settings: widget.settings),
      ),
    );
    if (mounted) setState(() {});
  }
}
