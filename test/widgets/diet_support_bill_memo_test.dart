import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/diet_support_bill_memo.dart';

void main() {
  testWidgets('提出時案の2つの読み方と審議状況、未確定点、一次資料を表示する', (tester) async {
    final opened = <Uri>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              DietSupportBillMemo(
                fontSize: 20,
                source: (label, uri) => TextButton(
                  onPressed: () => opened.add(uri),
                  child: Text(label),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('法案メモ　飲食料品の消費税と働く人への支援金'));
    await tester.pumpAndSettle();
    expect(find.textContaining('第222回国会・閣法第1号　提出時案'), findsOneWidget);
    expect(find.textContaining('2026年11月9日確認'), findsOneWidget);
    final plain = find.textContaining('地方分と合わせて1％');
    final legal = find.textContaining('国税の消費税率を0.78％');
    final status = find.textContaining('同日に参議院が受理');
    expect(plain, findsOneWidget);
    expect(legal, findsNothing);
    expect(status, findsOneWidget);
    await tester.tap(find.text('法律用語版'));
    await tester.pumpAndSettle();
    expect(plain, findsNothing);
    expect(legal, findsOneWidget);
    expect(find.textContaining('配偶者所得要件を適用せず'), findsOneWidget);
    expect(status, findsOneWidget);
    expect(find.textContaining('具体額はこの資料では確定できません'), findsOneWidget);
    expect(find.textContaining('個別の質問と答弁の対応は未確認'), findsOneWidget);
    await tester.tap(find.text('やわらか版'));
    await tester.pumpAndSettle();
    expect(plain, findsOneWidget);
    expect(legal, findsNothing);

    for (final label in [
      '税率についての大臣説明（10月9日）',
      '衆議院・提出時の法案本文',
      '衆議院・この法案の審議経過',
      '衆議院審議中継・田中議員の発言開始位置',
    ]) {
      final target = find.text(label);
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      await tester.tap(target);
    }
    expect(
      opened.map((uri) => uri.toString()).toList(),
      [
        'https://www.fsa.go.jp/common/conference/minister/2026b/20261009-1.html',
        'https://www.shugiin.go.jp/internet/itdb_gian.nsf/html/gian/honbun/houan/g22209001.htm',
        'https://www.shugiin.go.jp/internet/itdb_gian.nsf/html/gian/keika/1DE342E.htm',
        'https://www.shugiintv.go.jp/jp/index.php?ex=VL&deli_id=56466&time=22942.4',
      ],
    );
    expect(tester.takeException(), isNull);
  });
}
