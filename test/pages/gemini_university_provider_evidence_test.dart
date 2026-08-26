import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('01.AI provider overview keeps time-bounded API evidence', () {
    final source = File(
      'lib/pages/gemini_university_v2_page.dart',
    ).readAsStringSync();
    final match = RegExp(
      r"'01ai': '''([\s\S]*?)\n''',",
    ).firstMatch(source);

    expect(match, isNotNull);
    final overview = match!.group(1)!;

    expect(overview, contains('公式ドキュメント確認日: 2026-08-26'));
    expect(overview, contains('https://platform.01.ai/docs'));
    expect(overview, contains('OpenAI SDKと互換性のある呼び出し形式'));
    expect(overview, contains('認証後にモデル一覧'));
    expect(overview, contains('仕様・モデル提供状況は変更される可能性'));
    expect(overview, isNot(contains('GPT-4o同等')));
    expect(overview, isNot(contains(r'$0.14/100万token')));
    expect(overview, isNot(contains('OpenAI API完全互換')));
  });
}
