import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/user_manual_page.dart';

void main() {
  testWidgets('explains supported import formats and archive limitations', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: UserManualPage()));
    await tester.scrollUntilVisible(
      find.textContaining('ZIP を解凍し、中の .csv'),
      500,
      maxScrolls: 30,
    );

    expect(find.textContaining('ZIP を解凍し、中の .csv'), findsOneWidget);
    expect(find.textContaining('「Excel (XLSX)」を選び'), findsOneWidget);
    expect(find.textContaining('「内容」列の値を本文として'), findsOneWidget);
    expect(
      find.textContaining('金額・日付を会計データとして復元する機能ではありません'),
      findsOneWidget,
    );
    expect(find.textContaining('直接インポート未対応'), findsOneWidget);
    expect(find.textContaining('.md または .txt'), findsOneWidget);
    expect(find.textContaining('.tar.gz 形式'), findsOneWidget);
    expect(find.textContaining('ダウンロードした ZIP を選択'), findsNothing);
    expect(find.textContaining('ツイート履歴をノートとして取り込みます'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'discloses paid plans instead of claiming every feature is free',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: UserManualPage()));

      expect(find.textContaining('主要機能は無料で始められます'), findsOneWidget);
      expect(find.textContaining('Pro・Teamなどの有料プラン'), findsOneWidget);
      expect(find.textContaining('料金・対象機能・解約条件'), findsOneWidget);
      expect(find.textContaining('完全無料'), findsNothing);
    },
  );
}
