import 'package:bottlebottle/logic/level_config.dart';
import 'package:bottlebottle/main.dart';
import 'package:bottlebottle/ui/widgets/bottle_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    // 저장소를 매 시험마다 비운다. 앞 시험의 진행도가 넘어오면 안 된다.
    SharedPreferences.setMockInitialValues({});
  });

  /// 앱을 띄우고 **홈을 지나** 첫 판이 그려질 때까지 기다린다.
  ///
  /// 앱의 첫 화면은 홈이므로, 게임 화면을 시험하려면 한 번 들어가 줘야 한다.
  /// 저장된 판과 기록을 읽는 동안 로딩 화면이 떠 있어 그냥 pump로는 부족하다.
  Future<void> boot(WidgetTester tester) async {
    await tester.pumpWidget(const BottleBottleApp());
    await tester.pumpAndSettle();

    // 처음 켜면 '시작하기', 두던 판이 있으면 '이어서 하기'다.
    final start = find.text('시작하기').evaluate().isNotEmpty
        ? find.text('시작하기')
        : find.text('이어서 하기');
    await tester.tap(start);
    await tester.pumpAndSettle();
  }

  /// 내용물이 있는 첫 병과 비어 있는 첫 병의 위치를 찾는다.
  /// 병의 순서는 레벨마다 다르므로 위치를 넘겨짚지 않는다.
  ({int filled, int empty}) findBottles(WidgetTester tester) {
    final widgets = tester.widgetList<BottleWidget>(find.byType(BottleWidget)).toList();
    final filled = widgets.indexWhere((b) => b.contents.isNotEmpty);
    final empty = widgets.indexWhere((b) => b.contents.isEmpty);
    expect(filled, isNonNegative, reason: '내용물이 있는 병을 찾지 못했습니다.');
    expect(empty, isNonNegative, reason: '빈 병을 찾지 못했습니다.');
    return (filled: filled, empty: empty);
  }

  testWidgets('앱이 뜨고 레벨 1의 병이 전부 그려진다', (tester) async {
    await boot(tester);

    expect(find.textContaining('레벨 1'), findsOneWidget);
    expect(
      find.byType(BottleWidget),
      findsNWidgets(LevelConfig.forLevel(1).bottleCount),
    );
  });

  testWidgets('병을 누르면 들리고, 부으면 수가 늘어난다', (tester) async {
    await boot(tester);

    final at = findBottles(tester);
    final bottles = find.byType(BottleWidget);

    await tester.tap(bottles.at(at.filled));
    await tester.pumpAndSettle();
    expect(
      tester.widget<BottleWidget>(bottles.at(at.filled)).selected,
      isTrue,
      reason: '누른 병이 들려 있어야 합니다.',
    );

    await tester.tap(bottles.at(at.empty));
    await tester.pumpAndSettle();
    expect(find.textContaining('1수'), findsOneWidget);
    // 빈 병에 부었으므로 사용량도 함께 올라야 한다.
    expect(find.textContaining('빈 병 1/'), findsOneWidget);
  });

  testWidgets('되돌리기는 처음엔 꺼져 있고, 한 수 두면 켜진다', (tester) async {
    await boot(tester);

    final undo = find.widgetWithText(FilledButton, '되돌리기');
    expect(tester.widget<FilledButton>(undo).onPressed, isNull);

    final at = findBottles(tester);
    await tester.tap(find.byType(BottleWidget).at(at.filled));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BottleWidget).at(at.empty));
    await tester.pumpAndSettle();

    expect(tester.widget<FilledButton>(undo).onPressed, isNotNull);

    await tester.tap(undo);
    await tester.pumpAndSettle();
    expect(find.textContaining('0수'), findsOneWidget);
    expect(find.textContaining('빈 병 0/'), findsOneWidget);
  });

  testWidgets('힌트를 누르면 두 병이 강조된다', (tester) async {
    await boot(tester);

    await tester.tap(find.widgetWithText(FilledButton, '힌트'));
    await tester.pumpAndSettle();

    final hinted = tester
        .widgetList<BottleWidget>(find.byType(BottleWidget))
        .where((b) => b.hinted)
        .length;
    expect(hinted, 2);
  });

  testWidgets('건너뛰기를 누르면 레벨 2로 간다', (tester) async {
    await boot(tester);

    await tester.tap(find.widgetWithText(FilledButton, '건너뛰기'));
    await tester.pumpAndSettle();

    expect(find.textContaining('레벨 2'), findsOneWidget);
  });

  testWidgets('난이도 → 병 구성 → 레벨 순으로 골라 들어간다', (tester) async {
    await boot(tester);

    // 1단계: 난이도 목록
    await tester.tap(find.byIcon(Icons.folder_outlined));
    await tester.pumpAndSettle();
    expect(find.text('난이도 고르기'), findsOneWidget);
    expect(find.text('연습'), findsOneWidget);

    // 2단계: 그 난이도 안의 "병 N개 · M층" 목록
    await tester.tap(find.text('연습'));
    await tester.pumpAndSettle();
    expect(find.textContaining('층'), findsWidgets);

    // 3단계: 레벨 격자
    await tester.tap(find.textContaining('병 ').first);
    await tester.pumpAndSettle();
    expect(find.text('3'), findsOneWidget);

    // 레벨을 고르면 게임 화면으로 돌아와 그 레벨이 열린다.
    await tester.tap(find.text('3'));
    await tester.pumpAndSettle();
    expect(find.textContaining('레벨 3'), findsOneWidget);
  });

  testWidgets('어떤 난이도도 잠겨 있지 않다', (tester) async {
    // 진행도가 전혀 없는 상태에서도 최고 난이도를 열 수 있어야 한다.
    await boot(tester);

    await tester.tap(find.byIcon(Icons.folder_outlined));
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('최고 난이도'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('최고 난이도'));
    await tester.pumpAndSettle();

    // 8층짜리 묶음이 보이면 제대로 열린 것이다.
    expect(find.textContaining('8층'), findsWidgets);
  });

  testWidgets('깊은 병이 나오는 고레벨도 화면 밖으로 넘치지 않는다', (tester) async {
    // 레벨 500은 색 15 · 깊이 8 · 병 17개로 이 게임에서 가장 빡빡한 화면이다.
    SharedPreferences.setMockInitialValues({
      'saved_game_v1': '{"level":500,"moves":[]}',
    });
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await boot(tester);

    final config = LevelConfig.forLevel(500);
    expect(find.byType(BottleWidget), findsNWidgets(config.bottleCount));
    // 넘침이 있으면 Flutter가 시험을 실패시키므로, 여기까지 왔다면 다 들어간 것이다.
  });
}
