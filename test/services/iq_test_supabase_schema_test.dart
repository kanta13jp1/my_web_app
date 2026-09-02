import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/iq_test.dart';

const _migrationPath =
    'supabase/migrations/20260727120000_create_iq_test_tables.sql';

/// マイグレーションと Dart 側の書き込みキーが食い違うと、本番でだけ
/// 「列がない」で落ちる。ローカルDBなしでその齟齬を検出する。
void main() {
  late String sql;

  setUpAll(() {
    sql = File(_migrationPath)
        .readAsStringSync()
        .replaceAll('\r\n', '\n')
        .toLowerCase();
  });

  group('テーブル定義', () {
    test('必要な5テーブルを作成する', () {
      for (final table in [
        'iq_tests',
        'iq_category_scores',
        'iq_answers',
        'iq_training_plans',
        'iq_training_sessions',
      ]) {
        expect(
          sql,
          contains('create table if not exists $table'),
          reason: '$table が作られていない',
        );
      }
    });

    test('iq_tests が結果保存に必要な列を持つ', () {
      final block = _createTableBlock(sql, 'iq_tests');
      for (final column in [
        'user_id',
        'started_at',
        'completed_at',
        'is_completed',
        'total_iq',
        'percentile',
        'weighted_accuracy',
        'correct_count',
        'question_count',
        'duration_seconds',
        'question_seed',
      ]) {
        expect(block, contains(column), reason: 'iq_tests.$column が無い');
      }
    });

    test('IqAnswerRecord.toJson のキーが iq_answers の列に存在する', () {
      final block = _createTableBlock(sql, 'iq_answers');
      const record = IqAnswerRecord(
        questionKey: 'logic-01',
        category: IqCategory.logic,
        difficulty: 1,
        selectedIndex: 0,
        isCorrect: true,
        responseMs: 100,
      );

      for (final key in record.toJson().keys) {
        expect(block, contains(key), reason: 'iq_answers.$key が無い');
      }
    });

    test('IqCategoryScore.toJson のキーが iq_category_scores の列に存在する', () {
      final block = _createTableBlock(sql, 'iq_category_scores');
      const score = IqCategoryScore(
        category: IqCategory.logic,
        correctCount: 3,
        questionCount: 5,
        weightedAccuracy: 0.5,
        iq: 100,
        standardError: 5,
      );

      for (final key in score.toJson().keys) {
        expect(block, contains(key), reason: 'iq_category_scores.$key が無い');
      }
    });

    test('iq_training_plans / iq_training_sessions が必要な列を持つ', () {
      final plans = _createTableBlock(sql, 'iq_training_plans');
      for (final column in [
        'user_id',
        'source_test_id',
        'baseline_iq',
        'targets',
        'is_active',
      ]) {
        expect(
          plans,
          contains(column),
          reason: 'iq_training_plans.$column が無い',
        );
      }

      final sessions = _createTableBlock(sql, 'iq_training_sessions');
      for (final column in [
        'plan_id',
        'user_id',
        'category',
        'level',
        'correct_count',
        'question_count',
        'duration_seconds',
        'completed_at',
      ]) {
        expect(
          sessions,
          contains(column),
          reason: 'iq_training_sessions.$column が無い',
        );
      }
    });
  });

  group('upsert の競合キー', () {
    // サービス側の onConflict に対応する UNIQUE が無いと upsert が落ちる。
    test('iq_answers は (test_id, question_key) が一意', () {
      expect(
        _createTableBlock(sql, 'iq_answers'),
        contains('unique (test_id, question_key)'),
      );
    });

    test('iq_category_scores は (test_id, category) が一意', () {
      expect(
        _createTableBlock(sql, 'iq_category_scores'),
        contains('unique (test_id, category)'),
      );
    });
  });

  group('列挙値の制約', () {
    test('category の CHECK が IqCategory の全キーを網羅する', () {
      // enum に領域を足して SQL を直し忘れると、その領域だけ保存に失敗する。
      for (final category in IqCategory.values) {
        expect(
          sql,
          contains("'${category.key}'"),
          reason: 'category CHECK に ${category.key} が無い',
        );
      }
    });

    test('difficulty と level の範囲が 1..5 に制限されている', () {
      expect(sql, contains('difficulty between 1 and 5'));
      expect(sql, contains('level between 1 and 5'));
    });
  });

  group('RLS', () {
    test('全テーブルで RLS を有効化する', () {
      for (final table in [
        'iq_tests',
        'iq_category_scores',
        'iq_answers',
        'iq_training_plans',
        'iq_training_sessions',
      ]) {
        expect(
          sql,
          contains('alter table $table enable row level security'),
          reason: '$table の RLS が無効',
        );
      }
    });

    test('ユーザー所有テーブルは auth.uid() で絞る', () {
      for (final table in [
        'iq_tests',
        'iq_training_plans',
        'iq_training_sessions',
      ]) {
        final policies = _policiesFor(sql, table);
        expect(policies, isNotEmpty, reason: '$table のポリシーが無い');
        for (final policy in policies) {
          expect(
            policy,
            contains('auth.uid()'),
            reason: '$table に所有者チェックの無いポリシーがある:\n$policy',
          );
        }
      }
    });

    test('子テーブルは親テストの所有者経由で絞る', () {
      for (final table in ['iq_answers', 'iq_category_scores']) {
        final policies = _policiesFor(sql, table);
        expect(policies, isNotEmpty, reason: '$table のポリシーが無い');
        for (final policy in policies) {
          expect(
            policy,
            contains('select id from iq_tests where user_id = auth.uid()'),
            reason: '$table に所有者チェックの無いポリシーがある:\n$policy',
          );
        }
      }
    });

    test('全ユーザーに開放された SELECT ポリシーが無い', () {
      // 個人の認知スコアなので、問題テーブルのような公開読み取りは存在しないこと。
      expect(sql, isNot(contains('using (true)')));
    });

    test('子テーブルの INSERT は親の所有者も検証する', () {
      // user_id だけを見る WITH CHECK では、自分名義のまま他人の親IDを指す行を
      // 挿入できてしまう。親テーブルへの所有者サブクエリが必要。
      const parentRefs = {
        'iq_training_plans': ['source_test_id', 'iq_tests'],
        'iq_training_sessions': ['plan_id', 'iq_training_plans'],
      };

      for (final entry in parentRefs.entries) {
        final child = entry.key;
        final column = entry.value[0];
        final parent = entry.value[1];

        final inserts = _policiesFor(sql, child)
            .where((p) => p.contains('for insert'))
            .toList();
        expect(inserts, isNotEmpty, reason: '$child の INSERT ポリシーが無い');

        for (final policy in inserts) {
          expect(
            policy,
            contains('auth.uid() = user_id'),
            reason: '$child の INSERT に user_id チェックが無い:\n$policy',
          );
          expect(
            policy.replaceAll(RegExp(r'\s+'), ' '),
            contains(
              '$column in (select id from $parent where user_id = auth.uid())',
            ),
            reason: '$child.$column の所有者チェックが無い '
                '(他人の $parent を指す行を挿入できる):\n$policy',
          );
        }
      }
    });
  });
}

/// `create table if not exists <name> ( ... )` の中身を取り出す。
String _createTableBlock(String sql, String table) {
  final marker = 'create table if not exists $table';
  final start = sql.indexOf(marker);
  expect(start, isNot(-1), reason: '$table の CREATE TABLE が見つからない');

  final open = sql.indexOf('(', start);
  var depth = 0;
  for (var i = open; i < sql.length; i++) {
    if (sql[i] == '(') depth++;
    if (sql[i] == ')') {
      depth--;
      if (depth == 0) return sql.substring(open + 1, i);
    }
  }
  fail('$table の CREATE TABLE が閉じていない');
}

/// 指定テーブルに対する CREATE POLICY 文をすべて返す。
List<String> _policiesFor(String sql, String table) {
  final policies = <String>[];
  for (final match in RegExp(r'create policy[\s\S]*?;').allMatches(sql)) {
    final body = match.group(0)!;
    if (RegExp('\\son $table\\s').hasMatch(body)) {
      policies.add(body);
    }
  }
  return policies;
}
