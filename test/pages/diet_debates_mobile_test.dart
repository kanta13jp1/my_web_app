import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_web_app/data/diet_debate_notes.dart';
import 'package:my_web_app/pages/diet_debates_page.dart';
import 'package:my_web_app/services/diet_debate_search.dart';
import 'package:my_web_app/services/diet_reader_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _width = 390.0;

Future<void> _openMobile(
  WidgetTester tester, {
  DietDebateSearch? service,
}) async {
  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = const Size(1170, 2532);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final owner = ValueNotifier<String?>('mobile-reader');
  final preferences = DietReaderPreferences();
  addTearDown(owner.dispose);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: const TextScaler.linear(1.3),
        ),
        child: child!,
      ),
      home: DietDebatesPage(
        account: owner,
        searchService: service,
        preferences: preferences,
      ),
    ),
  );
  await tester.pumpAndSettle();
  final context = tester.element(find.byType(DietDebatesPage));
  expect(MediaQuery.sizeOf(context), const Size(_width, 844));
  expect(MediaQuery.textScalerOf(context).scale(20), closeTo(26, 0.01));
  await tester.tap(find.byTooltip('本文の文字サイズ'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('特大'));
  await tester.pumpAndSettle();
  final prefs = await SharedPreferences.getInstance();
  expect(prefs.getDouble('diet_debates.font_size'), 24.0);
  expect(tester.takeException(), isNull);
}

Finder _verticalList() {
  final list = find
      .byWidgetPredicate(
        (widget) =>
            widget is ScrollView && widget.scrollDirection == Axis.vertical,
      )
      .hitTestable();
  expect(list, findsOneWidget);
  return find
      .descendant(
        of: list,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        ),
      )
      .first;
}

Future<void> _reveal(
  WidgetTester tester,
  Finder target, {
  double delta = 260,
}) async {
  if (target.hitTestable().evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      target,
      delta,
      scrollable: _verticalList(),
      maxScrolls: 65,
    );
    await tester.pumpAndSettle();
  }
  expect(target.hitTestable(), findsOneWidget);
  final bounds = tester.getRect(target);
  expect(bounds.left, greaterThanOrEqualTo(-0.1));
  expect(bounds.right, lessThanOrEqualTo(_width + 0.1));
  expect(tester.takeException(), isNull);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('390px・拡大文字で検索し、画面外の次ページへ移動できる', (tester) async {
    final starts = <int>[];
    var now = DateTime.utc(2026, 11, 9);
    const issue = '000000000X00020000101';
    final service = DietDebateSearch(
      now: () => now,
      createClient: () => MockClient((request) async {
        final query = request.url.queryParameters;
        expect(query['any'], '子育て');
        final start = int.parse(query['startRecord']!);
        starts.add(start);
        final end = start + 9;
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'numberOfRecords': 20,
              if (start == 1) 'nextRecordPosition': 11,
              'speechRecord': [
                for (var i = start; i <= end; i++)
                  {
                    'issueID': issue,
                    'speechOrder': i,
                    'speechID': '${issue}_${i.toString().padLeft(3, '0')}',
                    'speechURL': 'https://kokkai.ndl.go.jp/txt/$issue/$i',
                    'speaker': '架空の発言者$i',
                    'date': '2000-01-01',
                    'nameOfHouse': '参議院',
                    'nameOfMeeting': '長い会議名の折り返しを確認するための架空の委員会',
                    'speech': '子育て',
                  },
              ],
            }),
          ),
          200,
        );
      }),
    );
    void expectPageStart(int start) {
      final heading = find.text('「子育て」の会議録API検索結果　20件');
      final position = find.text(
        'API取得開始位置　$start件目／このページで出典を確認できた記録　10件',
      );
      expect(heading.hitTestable(), findsOneWidget);
      expect(position.hitTestable(), findsOneWidget);
      final top = tester.getTopLeft(find.byType(CustomScrollView)).dy;
      expect(tester.getTopLeft(heading).dy, closeTo(top, 1));
    }

    await _openMobile(tester, service: service);
    final theme = find.text('子育て');
    await _reveal(tester, theme);
    await tester.tap(theme);
    final search = find.byIcon(Icons.search);
    await _reveal(tester, search);
    await tester.tap(search);
    await tester.pumpAndSettle();
    expect(starts, [1]);
    expectPageStart(1);
    final next = find.text('次の10件');
    expect(next.hitTestable(), findsNothing);
    await _reveal(tester, next);
    expect(
      tester.state<ScrollableState>(_verticalList()).position.pixels,
      greaterThan(0),
    );
    now = now.add(const Duration(seconds: 6));
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(starts, [1, 11]);
    expectPageStart(11);
    final back = find.text('前の10件');
    await _reveal(tester, back);
    await tester.tap(back);
    await tester.pumpAndSettle();
    expectPageStart(1);
    expect(starts, [1, 11]); // The first page is served from cache.
  });

  testWidgets('390px・拡大文字で要約を検索し、原文リンクと既読に到達できる', (tester) async {
    await _openMobile(tester);
    final tab = find.text('要約・法案メモ');
    expect(tab.hitTestable(), findsOneWidget);
    await tester.tap(tab);
    await tester.pumpAndSettle();
    final group = find.text('質問した議員別');
    await _reveal(tester, group);
    await tester.tap(group);
    await tester.pumpAndSettle();
    final note = DietDebateNote.entries.first;
    final article = find.byKey(ValueKey(note.articleId));
    Finder inArticle(Finder target) =>
        find.descendant(of: article, matching: target);
    final field = inArticle(find.widgetWithText(TextField, 'この記事内を検索'));
    await _reveal(tester, field);
    await tester.enterText(field, '資料');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await _reveal(tester, inArticle(find.text('この記事内の一致　1件')));
    final answer = find.ancestor(
      of: inArticle(find.text('答弁の原文')),
      matching: find.byWidgetPredicate((widget) => widget is TextButton),
    );
    await _reveal(tester, answer);
    expect(tester.widget<TextButton>(answer).onPressed, isNotNull);
    final question = inArticle(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text && widget.textSpan?.toPlainText() == note.question,
      ),
    );
    expect(tester.widget<Text>(question).style?.fontSize, 24.0);
    expect(
      tester.state<ScrollableState>(_verticalList()).position.pixels,
      greaterThan(0),
    );

    final unread = inArticle(find.text('要約を既読にする'));
    await _reveal(tester, unread, delta: -240);
    await tester.tap(unread);
    await tester.pumpAndSettle();
    await _reveal(tester, inArticle(find.text('要約は既読・未読に戻す')));
    expect(tester.takeException(), isNull);
  });
}
