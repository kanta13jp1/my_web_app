// IQテストのサービスクラス。
//
// 責務: テストの開始 / 回答の保存 / 採点結果の永続化 / 履歴取得。
// 採点そのものは iq_scoring.dart (純粋関数) が持ち、ここは I/O に徹する。

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/iq_test.dart';
import 'iq_scoring.dart';

class IqTestService {
  final SupabaseClient _supabase = Supabase.instance.client;

  String get _userId {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw StateError('IQテストの利用にはログインが必要です');
    }
    return user.id;
  }

  /// テストを開始し、テストIDを返す。
  ///
  /// [questionSeed] は選択肢シャッフルに使った値。結果の再現用に保存する。
  Future<IqTestResult> startTest({required int questionSeed}) async {
    try {
      final response = await _supabase
          .from('iq_tests')
          .insert({
            'user_id': _userId,
            'started_at': DateTime.now().toIso8601String(),
            'is_completed': false,
            'question_seed': questionSeed,
          })
          .select()
          .single();

      return IqTestResult.fromJson(response);
    } catch (e) {
      debugPrint('Error starting IQ test: $e');
      rethrow;
    }
  }

  /// 回答を保存する。同じ問題への再回答は上書き。
  Future<void> saveAnswer({
    required int testId,
    required IqAnswerRecord answer,
  }) async {
    try {
      await _supabase.from('iq_answers').upsert(
        {
          'test_id': testId,
          ...answer.toJson(),
          'answered_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'test_id,question_key',
      );
    } catch (e) {
      debugPrint('Error saving IQ answer: $e');
      rethrow;
    }
  }

  /// 採点してテストを完了させる。
  ///
  /// 採点は [IqScoring.summarize] で行い、ここでは書き込みだけを担当する。
  Future<IqTestResult> completeTest({
    required int testId,
    required List<IqAnswerRecord> answers,
    required int durationSeconds,
  }) async {
    try {
      final summary = IqScoring.summarize(answers);
      final completedAt = DateTime.now();

      final response = await _supabase
          .from('iq_tests')
          .update({
            'is_completed': true,
            'completed_at': completedAt.toIso8601String(),
            'total_iq': summary.totalIq,
            'percentile': summary.percentile,
            'weighted_accuracy': summary.weightedAccuracy,
            'correct_count': summary.correctCount,
            'question_count': summary.questionCount,
            'attempted_count': summary.attemptedCount,
            'duration_seconds': durationSeconds,
            'updated_at': completedAt.toIso8601String(),
          })
          .eq('id', testId)
          .select()
          .single();

      // 領域別スコアを保存
      if (summary.categoryScores.isNotEmpty) {
        await _supabase.from('iq_category_scores').upsert(
          [
            for (final score in summary.categoryScores)
              {'test_id': testId, ...score.toJson()},
          ],
          onConflict: 'test_id,category',
        );
      }

      return IqTestResult.fromJson(
        response,
        categoryScores: summary.categoryScores,
      );
    } catch (e) {
      debugPrint('Error completing IQ test: $e');
      rethrow;
    }
  }

  /// 領域別スコア込みでテスト結果を取得する。
  Future<IqTestResult?> getTestResult(int testId) async {
    try {
      final testRows =
          await _supabase.from('iq_tests').select().eq('id', testId).limit(1);
      if ((testRows as List).isEmpty) return null;

      final scoreRows = await _supabase
          .from('iq_category_scores')
          .select()
          .eq('test_id', testId);

      final scores = (scoreRows as List)
          .map((e) => IqCategoryScore.fromJson(e as Map<String, dynamic>))
          .toList();

      return IqTestResult.fromJson(
        testRows.first,
        categoryScores: scores,
      );
    } catch (e) {
      debugPrint('Error fetching IQ test result: $e');
      rethrow;
    }
  }

  /// テストの全回答を取得する。結果画面の振り返り表示に使う。
  ///
  /// 問題本体は DB に無いので、呼び出し側で question_seed から
  /// [IqQuestionBank.standardTest] を再構成して突き合わせる。
  Future<List<IqAnswerRecord>> getAnswers(int testId) async {
    try {
      final rows = await _supabase
          .from('iq_answers')
          .select()
          .eq('test_id', testId)
          // 一意な id をタイエブレーカにして並びを安定させる
          .order('id', ascending: true)
          .limit(200);

      return (rows as List)
          .map((e) => IqAnswerRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching IQ answers: $e');
      rethrow;
    }
  }

  /// 最新の完了済みテストを取得する。未受験なら null。
  Future<IqTestResult?> getLatestResult() async {
    try {
      final rows = await _supabase
          .from('iq_tests')
          .select()
          .eq('user_id', _userId)
          .eq('is_completed', true)
          .order('completed_at', ascending: false)
          // 同時刻の並びを安定させるためのタイブレーカ
          .order('id', ascending: false)
          .limit(1);

      if ((rows as List).isEmpty) return null;

      final test = rows.first;
      final scoreRows = await _supabase
          .from('iq_category_scores')
          .select()
          .eq('test_id', test['id'] as int);

      return IqTestResult.fromJson(
        test,
        categoryScores: (scoreRows as List)
            .map((e) => IqCategoryScore.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    } catch (e) {
      debugPrint('Error fetching latest IQ result: $e');
      rethrow;
    }
  }

  /// 推移グラフ用の履歴。古い順に返す。
  ///
  /// 件数上限を明示的に指定する (PostgREST の暗黙 1000 行打ち切りを避ける)。
  Future<List<IqTestResult>> getHistory({int limit = 50}) async {
    try {
      final rows = await _supabase
          .from('iq_tests')
          .select()
          .eq('user_id', _userId)
          .eq('is_completed', true)
          .order('completed_at', ascending: false)
          .order('id', ascending: false)
          .limit(limit);

      final results = (rows as List)
          .map((e) => IqTestResult.fromJson(e as Map<String, dynamic>))
          .toList();

      // 表示は古い→新しい順
      return results.reversed.toList();
    } catch (e) {
      debugPrint('Error fetching IQ history: $e');
      rethrow;
    }
  }

  /// 完了しなかったテストを破棄する (中断時)。
  Future<void> abandonTest(int testId) async {
    try {
      await _supabase
          .from('iq_tests')
          .delete()
          .eq('id', testId)
          .eq('is_completed', false);
    } catch (e) {
      debugPrint('Error abandoning IQ test: $e');
      // 中断処理の失敗はユーザー操作を妨げないので握る (孤児レコードが残るだけ)
    }
  }
}
