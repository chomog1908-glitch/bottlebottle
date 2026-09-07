import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:bottlebottle/controller/settings_controller.dart';
import 'package:bottlebottle/logic/level_config.dart';
import 'package:bottlebottle/logic/rule_notes.dart';
import 'package:bottlebottle/services/audio.dart';
import 'package:bottlebottle/ui/screens/game_screen.dart';
import 'package:bottlebottle/model/rule_set.dart';
import 'package:bottlebottle/ui/widgets/board_layout.dart';
import 'package:bottlebottle/ui/widgets/bottle_widget.dart';

void main() {
  group('규칙이 격자를 정하면 화면도 그 격자를 따른다', () {
    // 이게 어긋나면 바로 옆 병에 못 붓는 일이 생긴다. 그건 버그로 보인다.
    test('폰 크기가 달라도 한 줄 병 수는 그대로다', () {
      const sizes = [
        Size(320, 560), // 작은 폰
        Size(400, 800),
        Size(800, 1200), // 태블릿
      ];
      for (final s in sizes) {
        final m = computeBoardMetrics(
          available: s, bottleCount: 16, capacity: 7, fixedPerRow: 5,
        );
        expect(m.perRow, 5, reason: '$s에서 한 줄 병 수가 달라졌다');
      }
    });

    test('격자를 정하지 않으면 예전처럼 화면에 맞춰 고른다', () {
      final m = computeBoardMetrics(
        available: const Size(400, 800), bottleCount: 16, capacity: 7,
      );
      expect(m.perRow, greaterThan(0));
      expect(m.rows * m.perRow, greaterThanOrEqualTo(16));
    });

    test('고정 격자에서도 병은 화면 안에 들어간다', () {
      final m = computeBoardMetrics(
        available: const Size(320, 560), bottleCount: 16, capacity: 7,
        fixedPerRow: 5,
      );
      expect(m.bottleWidth * m.perRow, lessThanOrEqualTo(320 + 1));
    });
  });

  group('안내 문구', () {
    test('규칙이 없으면 안내도 없다 — ⓘ 단추가 뜨지 않는 근거', () {
      expect(RuleNotes.forRules(RuleSet.classic), isEmpty);
    });

    test('붙은 규칙마다 하나씩 나온다', () {
      expect(RuleNotes.forRules(const RuleSet.reach(3, 3)).length, 1);
      expect(
          RuleNotes.forRules(const RuleSet(claimEmpties: true, claimMono: true))
              .length,
          2);
      final all = RuleNotes.forRules(const RuleSet(
          reachX: 3, reachY: 3, claimEmpties: true, lockEmptyOrigin: true));
      expect(all.length, 3);
    });

    test('안내마다 이름이 다르다 — 본 것을 기억하려면 이름이 겹치면 안 된다', () {
      final ids = <String>{};
      for (final r in [
        const RuleSet.reach(3, 3),
        const RuleSet.reach(1, 1),
        const RuleSet(claimEmpties: true),
        const RuleSet(claimMono: true),
        const RuleSet(lockEmptyOrigin: true),
      ]) {
        for (final n in RuleNotes.forRules(r)) {
          ids.add(n.id);
        }
      }
      // ±3과 ±1은 서로 다른 안내다.
      expect(ids.contains('reach_3_3'), isTrue);
      expect(ids.contains('reach_1_1'), isTrue);
      expect(ids.length, 5);
    });
  });

  group('병 그리기', () {
    Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

    testWidgets('닿지 않는 병은 흐려지되 사라지지는 않는다', (tester) async {
      // 완전히 감추면 무엇이 들었는지 알 수 없어 다음 수를 생각할 수 없다.
      await tester.pumpWidget(wrap(BottleWidget(
        contents: const [0, 1], capacity: 4, onTap: () {}, unreachable: true,
      )));
      await tester.pumpAndSettle();
      final o = tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity));
      expect(o.opacity, greaterThan(0));
      expect(o.opacity, lessThan(1));
    });

    testWidgets('붓는 중인 병은 완전히 감춘다', (tester) async {
      await tester.pumpWidget(wrap(BottleWidget(
        contents: const [0, 1], capacity: 4, onTap: () {}, dimmed: true,
      )));
      await tester.pumpAndSettle();
      expect(tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity, 0);
    });

    testWidgets('평소 병은 또렷하다', (tester) async {
      await tester.pumpWidget(wrap(BottleWidget(
        contents: const [0, 1], capacity: 4, onTap: () {},
      )));
      await tester.pumpAndSettle();
      expect(tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity, 1);
    });
  });
  group('규칙이 붙은 판을 실제로 열어 본다', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Widget screen(int level) => MaterialApp(
          home: GameScreen(
            settings: SettingsController(),
            audio: AudioService(),
            startLevel: level,
          ),
        );

    testWidgets('레벨 800에 들어가면 안내가 뜨고, 닫으면 판을 만질 수 있다', (tester) async {
      await tester.pumpWidget(screen(800));
      await tester.pumpAndSettle();
      // 안내는 판이 그려진 뒤 잠시 있다가 뜬다. 그 시간을 넘겨 준다.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.text('새로운 규칙'), findsOneWidget);
      expect(find.text('가까운 병끼리만'), findsOneWidget);

      await tester.tap(find.text('알겠습니다'));
      await tester.pumpAndSettle();
      expect(find.text('새로운 규칙'), findsNothing);

      expect(find.byType(BottleWidget),
          findsNWidgets(LevelConfig.forLevel(800).bottleCount));
    });

    testWidgets('레벨 1에는 ⓘ 단추가 없다 — 설명할 규칙이 없다', (tester) async {
      await tester.pumpWidget(screen(1));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.info_outline), findsNothing);
    });

    testWidgets('병을 집으면 닿지 않는 병이 흐려진다', (tester) async {
      await tester.pumpWidget(screen(800));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await tester.tap(find.text('알겠습니다'));
      await tester.pumpAndSettle();

      // 아무것도 집지 않았을 때는 흐린 병이 없어야 한다.
      // 판 전체가 어두우면 무엇이 문제인지가 아니라 화면이 고장 난 것처럼 보인다.
      expect(
        tester
            .widgetList<BottleWidget>(find.byType(BottleWidget))
            .where((b) => b.unreachable)
            .length,
        0,
        reason: '집기 전인데 흐린 병이 있다',
      );

      final all =
          tester.widgetList<BottleWidget>(find.byType(BottleWidget)).toList();
      final filled = all.indexWhere((b) => b.contents.isNotEmpty);
      await tester.tap(find.byType(BottleWidget).at(filled));
      await tester.pumpAndSettle();

      // ±3에 격자 5칸이므로 닿지 않는 병이 반드시 생긴다.
      expect(
        tester
            .widgetList<BottleWidget>(find.byType(BottleWidget))
            .where((b) => b.unreachable)
            .length,
        greaterThan(0),
        reason: '이웃 제한이 걸린 판인데 흐려진 병이 하나도 없다',
      );
    });
  });

  group('어둡게 하는 것은 새 규칙 때문일 때뿐이다', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    testWidgets('색이 안 맞아 못 붓는 병까지 어두워지지는 않는다', (tester) async {
      // 색 안 맞음·가득 참은 이 게임이 처음부터 가진 규칙이고, 700판을 푸신
      // 분은 이미 몸으로 아신다. 그것까지 어둡게 하면 못 두는 수를 전부
      // 지워버리는 셈이라, 정작 새 규칙이 무엇인지 보이지 않는다.
      //
      // 실제로 그랬다. 병 하나를 집었을 때 멀어서 어두운 병 3개에 다른 이유로
      // 어두운 병 12개가 섞여, 판 전체가 꺼진 것처럼 보였다.
      await tester.pumpWidget(MaterialApp(
        home: GameScreen(
          settings: SettingsController(),
          audio: AudioService(),
          startLevel: 800,
        ),
      ));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await tester.tap(find.text('알겠습니다'));
      await tester.pumpAndSettle();

      final all =
          tester.widgetList<BottleWidget>(find.byType(BottleWidget)).toList();
      final filled = all.indexWhere((b) => b.contents.isNotEmpty);
      await tester.tap(find.byType(BottleWidget).at(filled));
      await tester.pumpAndSettle();

      final after =
          tester.widgetList<BottleWidget>(find.byType(BottleWidget)).toList();
      final dim = after.where((b) => b.unreachable).length;

      // 닿지 않는 병은 있어야 하지만, 판 전체가 꺼져서는 안 된다.
      expect(dim, greaterThan(0), reason: '이웃 제한 판인데 어두운 병이 없다');
      expect(dim, lessThan(after.length - 1),
          reason: '집은 병 말고 전부 어두워졌다 — 새 규칙이 보이지 않는다');
    });
  });

}
