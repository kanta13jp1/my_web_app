import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_web_app/data/diet_debate_notes.dart';
import 'package:my_web_app/pages/diet_debates_page.dart';
import 'package:my_web_app/services/diet_debate_search.dart';
import 'package:my_web_app/services/diet_reader_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> open(
    WidgetTester tester, {
    DietDebateSearch? service,
    ValueNotifier<String?>? account,
    DietReaderPreferences? preferences,
  }) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: DietDebatesPage(
          searchService: service,
          preferences: preferences ?? DietReaderPreferences(),
          account: account ?? ValueNotifier<String?>('reader-a'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('記事内検索と既読・文字サイズの端末保存', (tester) async {
    final preferences = DietReaderPreferences();
    await open(tester, preferences: preferences);
    await tester.tap(find.text('要約・法案メモ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('質問した議員別'));
    await tester.pumpAndSettle();
    expect(find.text('伊藤孝恵'), findsOneWidget);

    final search = find.widgetWithText(TextField, 'この記事内を検索').first;
    await tester.enterText(search, '資料');
    await tester.pumpAndSettle();
    expect(find.text('この記事内の一致　1件'), findsOneWidget);
    await tester.enterText(search, '.*');
    await tester.pumpAndSettle();
    expect(find.text('この記事内の一致　0件'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getKeys().where((key) => key.startsWith('diet_debates.v1.read.')),
      isEmpty,
    );
    await tester.tap(find.text('要約を既読にする').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('本文の文字サイズ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('特大'));
    await tester.pumpAndSettle();
    expect(prefs.getDouble('diet_debates.font_size'), 24.0);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      MaterialApp(
        home: DietDebatesPage(
          account: ValueNotifier<String?>('reader-a'),
          preferences: preferences,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('要約・法案メモ'));
    await tester.pumpAndSettle();
    expect(find.text('要約は既読・未読に戻す'), findsOneWidget);
    final menu = tester
        .widget<PopupMenuButton<double>>(find.byType(PopupMenuButton<double>));
    expect(menu.initialValue, 24.0);
    await tester.tap(find.text('要約は既読・未読に戻す'));
    await tester.pumpAndSettle();
    expect(
      prefs.getKeys().where((key) => key.startsWith('diet_debates.v1.read.')),
      isEmpty,
    );
  });

  testWidgets('保存中に利用者が変わっても既読は前の利用者に限り、ゲストでは保存しない', (tester) async {
    final account = ValueNotifier<String?>('reader-a');
    final started = Completer<void>();
    final release = Completer<void>();
    final store = DietReaderPreferences(
      write: (prefs, key, value) async {
        started.complete();
        await release.future;
        return prefs.setBool(key, value as bool);
      },
    );
    final articleId = DietDebateNote.entries.first.articleId;
    final article = find.byKey(ValueKey(articleId));
    Finder withinArticle(String label) =>
        find.descendant(of: article, matching: find.text(label));

    Future<void> showArticle() async {
      await tester.tap(find.text('要約・法案メモ'));
      await tester.pumpAndSettle();
      final list = find.byType(ListView).hitTestable();
      expect(list, findsOneWidget);
      final vertical = find
          .descendant(
            of: list,
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down,
            ),
          )
          .first;
      await tester.scrollUntilVisible(article, 250, scrollable: vertical);
      await tester.pumpAndSettle();
      expect(article, findsOneWidget);
    }

    await open(tester, account: account, preferences: store);
    await showArticle();
    final unread = withinArticle('要約を既読にする');
    final read = withinArticle('要約は既読・未読に戻す');
    expect(unread, findsOneWidget, reason: 'Aの初期設定を読み終え、対象記事が未読である');
    await tester.ensureVisible(unread);
    expect(unread.hitTestable(), findsOneWidget);
    await tester.tap(unread);
    await tester.pump();
    expect(started.isCompleted, isTrue);
    final prefs = await SharedPreferences.getInstance();
    final key = 'diet_debates.v1.read.reader-a.note:$articleId';
    expect(prefs.getBool(key), isNull);

    account.value = 'reader-b';
    await tester.pumpAndSettle();
    await showArticle();
    expect(withinArticle('既読状態を読み込み中'), findsOneWidget);
    expect(read, findsNothing);

    release.complete();
    await tester.pumpAndSettle();
    expect(unread, findsOneWidget, reason: '先行するAの保存完了後もBの記事は未読');
    expect(read, findsNothing);
    expect(prefs.getBool(key), isTrue);
    final bKeys = prefs.getKeys().where(
          (key) => key.startsWith('diet_debates.v1.read.reader-b.'),
        );
    expect(bKeys, isEmpty);

    account.value = null;
    await tester.pumpAndSettle();
    await showArticle();
    expect(unread, findsNothing);
    expect(read, findsNothing);
    expect(withinArticle('要約の既読保存はログイン後に利用できます'), findsOneWidget);
    account.value = 'reader-a';
    await tester.pumpAndSettle();
    await showArticle();
    expect(read, findsOneWidget);
  });

  testWidgets('Aの保存完了を待ってA→B→Aの既読を復元する', (tester) async {
    final account = ValueNotifier<String?>('reader-a');
    final release = Completer<void>();
    var enteredWrite = false;
    final preferences = DietReaderPreferences(
      write: (prefs, key, value) async {
        enteredWrite = true;
        await release.future;
        return prefs.setBool(key, value as bool);
      },
    );
    await open(tester, account: account, preferences: preferences);

    Future<void> viewNotes() async {
      await tester.tap(find.text('要約・法案メモ'));
      await tester.pumpAndSettle();
    }

    await viewNotes();
    await tester.tap(find.text('要約を既読にする').first);
    await tester.pump();
    expect(enteredWrite, isTrue);
    expect(find.textContaining('端末への保存中です'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getKeys().where((key) => key.startsWith('diet_debates.v1.read.')),
      isEmpty,
    );
    account.value = 'reader-b';
    await tester.pumpAndSettle();
    await viewNotes();
    expect(find.text('要約は既読・未読に戻す'), findsNothing);
    expect(find.text('既読状態を読み込み中'), findsWidgets);
    expect(find.textContaining('先に開始した保存'), findsOneWidget);
    expect(find.text('設定を読み直す'), findsNothing);
    account.value = 'reader-a';
    await tester.pumpAndSettle();
    await viewNotes();
    expect(find.text('既読状態を読み込み中'), findsWidgets);
    expect(find.text('要約を既読にする'), findsNothing);
    release.complete();
    await tester.pumpAndSettle();
    expect(find.text('要約は既読・未読に戻す'), findsOneWidget);
    account.value = 'reader-b';
    await tester.pumpAndSettle();
    await viewNotes();
    expect(find.text('要約は既読・未読に戻す'), findsNothing);
    expect(find.text('要約を既読にする'), findsWidgets);
  });

  testWidgets('利用者切替後の文字サイズは先の保存を待ち、最後に選んだ値を復元する', (tester) async {
    final account = ValueNotifier<String?>('reader-a');
    final release = Completer<void>();
    final writes = <double>[];
    final preferences = DietReaderPreferences(
      write: (prefs, key, value) async {
        final size = value as double;
        writes.add(size);
        if (size == 24.0) await release.future;
        return prefs.setDouble(key, size);
      },
    );
    await open(tester, account: account, preferences: preferences);
    PopupMenuButton<double> menu() => tester
        .widget<PopupMenuButton<double>>(find.byType(PopupMenuButton<double>));
    await tester.tap(find.byTooltip('本文の文字サイズ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('特大'));
    await tester.pumpAndSettle();
    expect(writes, [24.0]);
    account.value = 'reader-b';
    await tester.pumpAndSettle();
    expect(menu().enabled, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble('diet_debates.font_size'), isNull);
    release.complete();
    await tester.pumpAndSettle();
    expect(menu().initialValue, 24.0);
    expect(menu().enabled, isTrue);
    await tester.tap(find.byTooltip('本文の文字サイズ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('大'));
    await tester.pumpAndSettle();
    account.value = 'reader-a';
    await tester.pumpAndSettle();
    expect(writes, [24.0, 20.0]);
    expect(menu().initialValue, 20.0);
    expect(prefs.getDouble('diet_debates.font_size'), 20.0);
  });

  testWidgets('保存結果不明は画面を開き直しても明示し、未読の手動設定で解除する', (tester) async {
    final account = ValueNotifier<String?>('reader-a');
    var loseReply = true;
    final preferences = DietReaderPreferences(
      write: (prefs, key, value) async {
        if (value == null) return prefs.remove(key);
        final saved = await prefs.setBool(key, value as bool);
        if (loseReply) throw StateError('response lost');
        return saved;
      },
    );
    await open(tester, account: account, preferences: preferences);
    await tester.tap(find.text('要約・法案メモ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('要約を既読にする').first);
    await tester.pumpAndSettle();
    expect(find.text('要約の既読保存状態は不明です。'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      MaterialApp(
        home: DietDebatesPage(account: account, preferences: preferences),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('要約・法案メモ'));
    await tester.pumpAndSettle();
    expect(find.text('要約の既読保存状態は不明です。'), findsOneWidget);
    loseReply = false;
    await tester.tap(find.text('未読に設定'));
    await tester.pumpAndSettle();
    expect(find.text('要約の既読保存状態は不明です。'), findsNothing);
    expect(find.text('要約は既読・未読に戻す'), findsNothing);
  });

  testWidgets('端末設定の読込失敗と再試行中は文字サイズを変更できない', (tester) async {
    SharedPreferences.setMockInitialValues({'diet_debates.font_size': 20.0});
    var attempts = 0;
    final retry = Completer<void>();
    final written = <Object?>[];
    final preferences = DietReaderPreferences(
      openPreferences: () async {
        attempts++;
        if (attempts == 1) throw StateError('initial read failed');
        if (attempts == 2) await retry.future;
        return SharedPreferences.getInstance();
      },
      write: (prefs, key, value) async {
        written.add(value);
        return prefs.setDouble(key, value as double);
      },
    );
    await open(tester, preferences: preferences);
    PopupMenuButton<double> menu() => tester
        .widget<PopupMenuButton<double>>(find.byType(PopupMenuButton<double>));
    expect(menu().enabled, isFalse);
    expect(find.textContaining('文字サイズと既読の変更には再読み込みが必要'), findsOneWidget);
    await tester.tap(find.text('設定を読み直す'));
    await tester.pump();
    expect(attempts, 2);
    expect(menu().enabled, isFalse);
    expect(written, isEmpty);
    retry.complete();
    await tester.pumpAndSettle();
    expect(menu().enabled, isTrue);
    expect(menu().initialValue, 20.0);
    await tester.tap(find.byTooltip('本文の文字サイズ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('特大'));
    await tester.pumpAndSettle();
    expect(written, [24.0]);
    expect(menu().initialValue, 24.0);
    expect(
      (await SharedPreferences.getInstance())
          .getDouble('diet_debates.font_size'),
      24.0,
    );
  });

  testWidgets('現在ページだけを発言者別・テーマ別に分類し検索する', (tester) async {
    var calls = 0;
    const issue = '121115104X01220230516';
    final service = DietDebateSearch(
      createClient: () => MockClient((_) async {
        calls++;
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'numberOfRecords': 14,
              'nextRecordPosition': 11,
              'speechRecord': [
                {'speechID': 'invalid'},
                {
                  'issueID': issue,
                  'speechOrder': 999,
                  'speechID': '${issue}_999',
                  'speechURL': 'https://kokkai.ndl.go.jp/txt/$issue/999',
                  'speaker': '発言者甲',
                  'date': '2023-05-16',
                  'nameOfHouse': '参議院',
                  'nameOfMeeting': '委員会',
                  'speakerGroup': '会派甲',
                },
              ],
            }),
          ),
          200,
        );
      }),
    );
    await open(tester, service: service);
    await tester.tap(find.text('子育て'));
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    expect(find.textContaining('会議録API検索結果　14件'), findsOneWidget);
    expect(find.textContaining('このページで出典を確認できた記録　1件'), findsOneWidget);
    expect(find.text('テーマ未分類（1件）'), findsOneWidget);
    await tester.tap(find.text('議員・答弁者別'));
    await tester.pumpAndSettle();
    expect(find.text('発言者甲（1件）'), findsOneWidget);
    final filter = find.widgetWithText(TextField, 'このページの表示項目を検索');
    await tester.enterText(filter, '見つからない語');
    await tester.pumpAndSettle();
    expect(find.text('このページ内に一致する記録はありません。'), findsOneWidget);
    await tester.enterText(filter, '会派甲');
    await tester.pumpAndSettle();
    expect(find.text('発言者甲（1件）'), findsOneWidget);
    expect(calls, 1);
  });
}
