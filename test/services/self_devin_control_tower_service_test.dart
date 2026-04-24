import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/self_devin_control_tower_service.dart';

void main() {
  group('SelfDevinControlTowerService.buildSnapshot', () {
    test('aggregates four lanes and automation loops', () {
      final snapshot = SelfDevinControlTowerService.buildSnapshot(
        now: DateTime(2026, 4, 24, 12),
        rawTasks: <Map<String, dynamic>>[
          <String, dynamic>{
            'title': '[追加要望] VSCode lane task',
            'category': 'ユーザー要望',
            'instance': 'vscode',
            'owner_instance': 'vscode',
            'status': 'in_progress',
            'progress': 60,
            'end_date': '2026-04-25',
            'priority': 'high',
            'updated_at': '2026-04-24T09:00:00Z',
          },
          <String, dynamic>{
            'title': 'WEB blocked task',
            'category': 'AI戦略',
            'instance': 'web',
            'owner_instance': 'web',
            'status': 'blocked',
            'progress': 30,
            'end_date': '2026-04-23',
            'priority': 'high',
            'updated_at': '2026-04-20T09:00:00Z',
          },
          <String, dynamic>{
            'title': 'PowerShell task A',
            'category': '運用・自動化',
            'instance': 'ps3',
            'owner_instance': 'ps3',
            'status': 'in_progress',
            'progress': 80,
            'end_date': '2026-04-26',
            'priority': 'medium',
            'updated_at': '2026-04-24T07:00:00Z',
          },
          <String, dynamic>{
            'title': 'PowerShell task B',
            'category': '運用・自動化',
            'instance': 'ps5',
            'owner_instance': 'ps5',
            'status': 'completed',
            'progress': 100,
            'end_date': '2026-04-22',
            'priority': 'medium',
            'updated_at': '2026-04-22T07:00:00Z',
          },
        ],
        rawRuns: <Map<String, dynamic>>[
          <String, dynamic>{
            'task_id': 'cs-check',
            'status': 'success',
            'started_at': '2026-04-24T11:15:00Z',
            'summary': 'hourly check clean',
            'error_message': null,
          },
          <String, dynamic>{
            'task_id': 'github-issue-fix',
            'status': 'error',
            'started_at': '2026-04-24T01:00:00Z',
            'summary': null,
            'error_message': 'branch bootstrap failed',
          },
          <String, dynamic>{
            'task_id': 'ci-auto-fix',
            'status': 'skipped',
            'started_at': '2026-04-23T23:00:00Z',
            'summary': 'no CI failure',
            'error_message': null,
          },
        ],
      );

      expect(snapshot.openFeatureRequestCount, 1);
      expect(snapshot.blockedTaskCount, 1);
      expect(snapshot.activeLaneCount, 3);
      expect(snapshot.healthyLoopCount, 2);
      expect(snapshot.totalLoopCount, 5);
      expect(snapshot.nextActionTitle, contains('WEB'));

      final webLane = snapshot.lanes.firstWhere((lane) => lane.id == 'web');
      expect(webLane.blockedTasks, 1);
      expect(webLane.overdueTasks, 1);
      expect(webLane.healthLabel, 'Rescue');

      final psLane =
          snapshot.lanes.firstWhere((lane) => lane.id == 'powershell');
      expect(psLane.activeTasks, 1);
      expect(psLane.averageProgress, 80);

      final issueFixLoop = snapshot.loops.firstWhere(
        (loop) => loop.id == 'github-issue-fix',
      );
      expect(issueFixLoop.status, 'error');

      final selfDevinLoop = snapshot.loops.firstWhere(
        (loop) => loop.id == 'self-devin-schedule',
      );
      expect(selfDevinLoop.status, 'configured');

      final infraLoop = snapshot.loops.firstWhere(
        (loop) => loop.id == 'infra-health-check',
      );
      expect(infraLoop.status, 'configured');
    });
  });
}
