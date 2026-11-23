import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/chat_background_job.dart';
import 'package:my_web_app/models/chat_subsession.dart';
import 'package:my_web_app/services/chat_background_job_center.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ChatBackgroundJobCenter & ChatSubsessionStore (#2800 / #2801)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(const <String, Object>{});
    });

    test('tracks job start, completion, failure, dismiss, and fail-open stream',
        () async {
      final center = ChatBackgroundJobCenter();
      addTearDown(center.dispose);

      final job1 = center.startJob(
        id: 'job_1',
        title: 'AI要約生成',
        source: 'ai-hub',
        now: DateTime.utc(2026, 11, 23, 14, 0),
      );
      expect(job1.status, ChatBackgroundJobStatus.running);
      expect(center.jobs.length, 1);

      center.updateJobStatus(
        'job_1',
        status: ChatBackgroundJobStatus.running,
        progress: 0.6,
        summary: '中間集計を処理中',
      );
      expect(center.jobs.first.progress, 0.6);

      center.completeJob(
        'job_1',
        summary: '要約が完了しました',
        resultDetail: '3件のハイライトを抽出',
      );
      expect(center.jobs.first.status, ChatBackgroundJobStatus.completed);
      expect(center.jobs.first.status.isTerminal, isTrue);
      expect(center.jobs.first.resultDetail, '3件のハイライトを抽出');

      final controller = StreamController<ChatBackgroundJob>();
      addTearDown(controller.close);
      center.bindStatusStream(controller.stream);

      controller.add(
        ChatBackgroundJob(
          id: 'job_2',
          title: 'Edge同期',
          source: 'edge-realtime',
          status: ChatBackgroundJobStatus.failed,
          summary: '同期タイムアウト',
          errorMessage: '504 Gateway Timeout',
          startedAt: DateTime.utc(2026, 11, 23, 14, 1),
          updatedAt: DateTime.utc(2026, 11, 23, 14, 2),
        ),
      );
      controller.addError(StateError('realtime disconnected'));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(center.jobs.length, 2);
      expect(center.jobs.first.id, 'job_2');
      expect(center.jobs.first.errorMessage, '504 Gateway Timeout');

      center.dismissJob('job_2');
      expect(center.jobs.length, 1);
      expect(center.jobs.first.id, 'job_1');
    });

    test(
        'creates child subsession inheriting parent messages/context and persists',
        () async {
      const store = ChatSubsessionStore();
      final root = ChatSubsession(
        id: 'root',
        title: 'メインセッション',
        inheritedContextIds: const <String>['ctx_1', 'ctx_2'],
        inheritedContextTitles: const <String>['月次レポート', 'タスク設計'],
        messages: const <ChatSubsessionMessage>[
          ChatSubsessionMessage(role: 'user', content: '方針を比較したい'),
          ChatSubsessionMessage(role: 'assistant', content: '2案あります'),
        ],
        createdAt: DateTime.utc(2026, 11, 23, 14, 0),
        updatedAt: DateTime.utc(2026, 11, 23, 14, 0),
      );

      final child = store.createChildSubsession(
        parent: root,
        childOrdinal: 1,
        now: DateTime.utc(2026, 11, 23, 14, 5),
      );
      expect(child.parentSessionId, 'root');
      expect(child.isChildSession, isTrue);
      expect(child.inheritedContextIds, const <String>['ctx_1', 'ctx_2']);
      expect(child.messages.length, 2);
      expect(child.messages.first.content, '方針を比較したい');

      await store.saveSessions(<ChatSubsession>[root, child]);
      final restored = await store.loadSessions();
      expect(restored.length, 2);
      expect(restored[1].parentSessionId, 'root');
      expect(restored[1].inheritedContextTitles,
          const <String>['月次レポート', 'タスク設計']);
    });
  });
}
