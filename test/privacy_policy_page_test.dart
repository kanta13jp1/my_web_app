import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/privacy_policy_page.dart';

void main() {
  testWidgets('privacy policy page renders the public policy asset', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: PrivacyPolicyPage(showBackButton: false)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Privacy Policy'), findsWidgets);
    expect(find.text('AIデータ取扱い早見表'), findsOneWidget);
    expect(find.textContaining('AIチャット・文章生成'), findsWidgets);
    expect(find.textContaining('AI分析・提案'), findsWidgets);
    expect(find.textContaining('AI動画生成'), findsWidgets);

    final policy = await rootBundle.loadString(PrivacyPolicyPage.assetPath);
    expect(policy, contains('## 1. 適用範囲'));
    expect(policy, contains('対象サービス'));
    expect(policy, contains('サブスクリプション解約と退会の違い'));
    expect(policy, contains('申請後30日間は同じ画面から取り消せます'));
    expect(policy, contains('決済顧客情報、関連DBデータ、Storage、Supabase Auth'));
    expect(policy, contains('発行済みアクセストークンの失効を最大65分待って'));
    expect(policy, contains('メールアカウントはパスワード'));
    expect(policy, contains('### 2.4 Google ユーザーデータの取扱い'));
    expect(policy, contains('表示名、メールアドレス、プロフィール画像 URL'));
    expect(policy, contains('Gmail、Google カレンダー、Google Drive'));
    expect(policy, contains('Supabase Auth と本サービスのデータベース'));
  });
}
