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

  test('Adept provider overview separates history from current availability',
      () {
    final source = File(
      'lib/pages/gemini_university_v2_page.dart',
    ).readAsStringSync();
    final match = RegExp(
      r"'adept': '''([\s\S]*?)\n''',",
    ).firstMatch(source);

    expect(match, isNotNull);
    final overview = match!.group(1)!;

    expect(overview, contains('公式情報確認日: 2026-08-26'));
    expect(overview, contains('2022-09-14 — ACT-1'));
    expect(overview, contains('2023-10-17 — Fuyu-8B'));
    expect(overview, contains('2024-06-28 — 戦略更新'));
    expect(overview, contains('2024-08-23 — AWL'));
    expect(overview, contains('https://www.adept.ai/blog/adept-update/'));
    expect(overview, contains('技術ライセンスと人員の参加'));
    expect(overview, contains('公式サイトで再確認'));
    expect(overview, isNot(contains('ACT-1 / ACT-2')));
    expect(overview, isNot(contains('Amazon連携を含む')));
  });
}
