import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/autonomous_ops_console_page.dart';
import 'package:my_web_app/services/autonomous_ops_service.dart';

/// テスト用のフェイクサービス。Supabase を初期化せずに
/// isSignedIn / fetch を差し替える (コンストラクタは client に触れない)。
class _FakeOpsService extends AutonomousOpsService {
  _FakeOpsService(this._result, {this.signedIn = true}) : super();

  final OpsSnapshotDto? _result;
  final bool signedIn;

  @override
  bool get isSignedIn => signedIn;

  @override
  Future<OpsSnapshotDto?> fetch() async => _result;
}

OpsSnapshotDto _liveSnapshot() => const OpsSnapshotDto(
      configured: true,
      live: true,
      tasks: <OpsTaskDto>[
        OpsTaskDto(
          code: 'OW-901',
          dept: '品質',
          title: '実データタスクX',
          valueYen: 50000,
          lane: 'progress',
          agentId: 'K',
        ),
      ],
      activities: <OpsActivityDto>[
        OpsActivityDto(
          text: 'KANNA が「実データタスクX」を実行中',
          time: '12:00:00',
          agentId: 'K',
        ),
      ],
      completedToday: 7,
      automatedHours: 3.5,
      revenueImpact: 161000,
      slaCompliance: 98,
      throughput: 5,
      throughputHistory: <double>[1, 2, 3],
    );

void main() {
  group('OpsSnapshotDto.fromJson', () {
    test('完全な JSON を型安全にパースする', () {
      final dto = OpsSnapshotDto.fromJson(
        <String, dynamic>{
          'live': true,
          'tasks': <dynamic>[
            <String, dynamic>{
              'code': 'OW-1',
              'dept': '開発',
              'title': 'ビルド',
              'valueYen': 42000,
              'lane': 'done',
              'agentId': 'H',
            },
          ],
          'activities': <dynamic>[
            <String, dynamic>{
              'text': 'HAYATE が「ビルド」を完了',
              'time': '01:02:03',
              'agentId': 'H',
            },
          ],
          'kpis': <String, dynamic>{
            'completedToday': 12,
            'automatedHours': 4.2,
            'revenueImpact': 276000,
            'slaCompliance': 99.1,
            'throughput': 8,
          },
          'throughputHistory': <dynamic>[1, 2.5, 3],
        },
        configured: true,
      );

      expect(dto.live, isTrue);
      expect(dto.configured, isTrue);
      expect(dto.tasks, hasLength(1));
      expect(dto.tasks.first.title, 'ビルド');
      expect(dto.tasks.first.agentId, 'H');
      expect(dto.activities.first.text, contains('完了'));
      expect(dto.completedToday, 12);
      expect(dto.automatedHours, 4.2);
      expect(dto.revenueImpact, 276000);
      expect(dto.throughput, 8);
      expect(dto.throughputHistory, <double>[1, 2.5, 3]);
    });

    test('欠損・型不一致でも防御的に既定値へフォールバックする', () {
      final dto = OpsSnapshotDto.fromJson(
        <String, dynamic>{
          'tasks': 'not-a-list',
          'kpis': 'not-a-map',
        },
        configured: false,
      );

      expect(dto.live, isFalse);
      expect(dto.configured, isFalse);
      expect(dto.tasks, isEmpty);
      expect(dto.activities, isEmpty);
      expect(dto.completedToday, 0);
      expect(dto.slaCompliance, 0);
      expect(dto.throughputHistory, isEmpty);
    });
  });

  group('AutonomousOpsConsolePage データソース分岐', () {
    testWidgets('ログイン済みオーナー + live データ → 実データモード', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AutonomousOpsConsolePage(service: _FakeOpsService(_liveSnapshot())),
        ),
      );
      // 初回フェッチ (async) を解決させる。
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      expect(find.text('実データ · GitHub Actions'), findsOneWidget);
      expect(find.text('実データタスクX'), findsWidgets);

      // 後片付け: ページを外して periodic timer を解放。
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('オーナーだがトークン未構成 → シミュレーション + ヒント', (tester) async {
      final unconfigured = OpsSnapshotDto.fromJson(
        const <String, dynamic>{'live': false},
        configured: false,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: AutonomousOpsConsolePage(
            service: _FakeOpsService(unconfigured),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      expect(find.text('シミュレーション · トークン未設定'), findsOneWidget);
      expect(find.text('実データ · GitHub Actions'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('未ログイン → シミュレーション表示のまま', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AutonomousOpsConsolePage(
            service: _FakeOpsService(null, signedIn: false),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      expect(find.text('シミュレーション'), findsOneWidget);
      expect(find.text('実データ · GitHub Actions'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
