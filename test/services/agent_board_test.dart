import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/agent_board_models.dart';
import 'package:my_web_app/pages/agent_board_page.dart';
import 'package:my_web_app/services/agent_board_service.dart';

/// Supabase を初期化せずに分岐を検証するためのフェイク。
class _FakeBoardService extends AgentBoardService {
  _FakeBoardService({
    this.signedIn = true,
    this.rows = const <Map<String, dynamic>>[],
  }) : super();

  final bool signedIn;
  final List<Map<String, dynamic>> rows;

  @override
  bool get isSignedIn => signedIn;

  @override
  Future<List<Map<String, dynamic>>> fetchRows() async => rows;

  @override
  void subscribe(void Function() onChange) {
    // テストではタイマー/購読を張らない。
  }

  @override
  Future<void> dispose() async {}
}

// 固定 now: 2026-07-26T12:00:00Z
final DateTime kNow = DateTime.parse('2026-07-26T12:00:00Z');

/// 固定 now でスナップショットを組む (呼び出しを短くするためのヘルパー)。
BoardSnapshot snapOf(List<Map<String, dynamic>> rows) =>
    buildBoardSnapshot(rows, kNow);

Map<String, dynamic> row({
  String id = 't1',
  String title = 'タスク',
  String status = 'in_progress',
  String instance = 'claude',
  String? ownerInstance,
  int progress = 50,
  String priority = 'medium',
  DateTime? updatedAt,
  int? issueNumber,
  String issueUrl = '',
}) {
  return <String, dynamic>{
    'id': id,
    'title': title,
    'status': status,
    'progress': progress,
    'priority': priority,
    'category_icon': '🛠',
    'instance': instance,
    'owner_instance': ownerInstance,
    'updated_at': (updatedAt ?? kNow).toIso8601String(),
    'github_issue_number': issueNumber,
    'github_issue_url': issueUrl,
  };
}

void main() {
  group('laneFromStatus', () {
    test('実 status をそのまま 4 列へ写像する', () {
      expect(laneFromStatus('not_started'), BoardLane.notStarted);
      expect(laneFromStatus('in_progress'), BoardLane.inProgress);
      expect(laneFromStatus('blocked'), BoardLane.blocked);
      expect(laneFromStatus('completed'), BoardLane.completed);
    });

    test('未知の status は未着手へ寄せる', () {
      expect(laneFromStatus('pending'), BoardLane.notStarted);
      expect(laneFromStatus(''), BoardLane.notStarted);
    });
  });

  group('normalizeAgentId', () {
    test('別名を正規の ID へ束ねる', () {
      expect(normalizeAgentId('codex1'), 'codex');
      expect(normalizeAgentId('cx'), 'codex');
      expect(normalizeAgentId('co-pilot'), 'copilot');
      expect(normalizeAgentId('ps3'), 'ps');
      expect(normalizeAgentId('human'), 'user');
      expect(normalizeAgentId('CLAUDE'), 'claude');
    });

    test('未知の値はそのまま ID になる (新エージェント追従)', () {
      expect(normalizeAgentId('antigravity'), 'antigravity');
      expect(agentDisplayName('antigravity'), 'Antigravity');
    });

    test('空文字は unknown', () {
      expect(normalizeAgentId('  '), 'unknown');
    });
  });

  group('cardFromRow', () {
    test('owner_instance を優先し、無ければ instance を使う', () {
      final a = cardFromRow(row(instance: 'codex', ownerInstance: 'claude'));
      expect(a.agentId, 'claude');
      final b = cardFromRow(row(instance: 'gemini'));
      expect(b.agentId, 'gemini');
    });

    test('progress は 0-100 にクランプされる', () {
      expect(cardFromRow(row(progress: 150)).progress, 100);
      expect(cardFromRow(row(progress: -5)).progress, 0);
    });
  });

  group('buildBoardSnapshot', () {
    test('未着手/進行中/ブロックは全件残る', () {
      final snapshot = snapOf(<Map<String, dynamic>>[
        row(id: 'a', status: 'not_started'),
        row(id: 'b', status: 'in_progress'),
        row(id: 'c', status: 'blocked'),
      ]);

      expect(snapshot.cardsOf(BoardLane.notStarted), hasLength(1));
      expect(snapshot.cardsOf(BoardLane.inProgress), hasLength(1));
      expect(snapshot.cardsOf(BoardLane.blocked), hasLength(1));
      expect(snapshot.totalTasks, 3);
    });

    test('完了は直近24時間ぶんだけ残る', () {
      final snapshot = snapOf(<Map<String, dynamic>>[
        row(
          id: 'recent',
          status: 'completed',
          updatedAt: kNow.subtract(const Duration(hours: 3)),
        ),
        row(
          id: 'old',
          status: 'completed',
          updatedAt: kNow.subtract(const Duration(hours: 30)),
        ),
      ]);

      final done = snapshot.cardsOf(BoardLane.completed);
      expect(done, hasLength(1));
      expect(done.single.id, 'recent');
    });

    test('未着手は上限で打ち切り、超過数を hiddenNotStarted に出す', () {
      final rows = <Map<String, dynamic>>[
        for (int i = 0; i < notStartedLimit + 5; i++)
          row(id: 'n$i', status: 'not_started'),
      ];
      final snapshot = buildBoardSnapshot(rows, kNow);

      final shown = snapshot.cardsOf(BoardLane.notStarted);
      expect(shown, hasLength(notStartedLimit));
      expect(snapshot.hiddenNotStarted, 5);
    });

    test('未着手は優先度順に並ぶ', () {
      final snapshot = snapOf(<Map<String, dynamic>>[
        row(id: 'low', status: 'not_started', priority: 'low'),
        row(id: 'critical', status: 'not_started', priority: 'critical'),
        row(id: 'medium', status: 'not_started', priority: 'medium'),
      ]);

      final ids =
          snapshot.cardsOf(BoardLane.notStarted).map((c) => c.id).toList();
      expect(ids, <String>['critical', 'medium', 'low']);
    });

    test('進行中は最近更新が上に来る', () {
      final snapshot = snapOf(<Map<String, dynamic>>[
        row(
          id: 'older',
          status: 'in_progress',
          updatedAt: kNow.subtract(const Duration(hours: 2)),
        ),
        row(
          id: 'newer',
          status: 'in_progress',
          updatedAt: kNow.subtract(const Duration(minutes: 5)),
        ),
      ]);

      expect(snapshot.cardsOf(BoardLane.inProgress).first.id, 'newer');
    });

    test('空入力でも壊れない', () {
      final snapshot = snapOf(<Map<String, dynamic>>[]);
      expect(snapshot.totalTasks, 0);
      expect(snapshot.agents, isEmpty);
      expect(snapshot.hiddenNotStarted, 0);
    });
  });

  group('summarizeAgents', () {
    test('実データに現れたエージェントだけを返し、稼働中を上にする', () {
      final snapshot = snapOf(<Map<String, dynamic>>[
        row(id: 'a', status: 'not_started', instance: 'gemini'),
        row(id: 'b', status: 'in_progress', instance: 'claude'),
        row(id: 'c', status: 'in_progress', instance: 'claude'),
        row(id: 'd', status: 'in_progress', instance: 'codex'),
      ]);

      final ids = snapshot.agents.map((a) => a.agentId).toList();
      // claude(進行中2) → codex(進行中1) → gemini(待機)
      expect(ids, <String>['claude', 'codex', 'gemini']);
      expect(snapshot.agents.first.inProgress, 2);
      expect(snapshot.agents.first.isActive, isTrue);
      expect(snapshot.agents.last.isActive, isFalse);
    });

    test('現在のタスク名は進行中で最も新しいものになる', () {
      final snapshot = snapOf(<Map<String, dynamic>>[
        row(
          id: 'x',
          title: '古い作業',
          status: 'in_progress',
          instance: 'claude',
          updatedAt: kNow.subtract(const Duration(hours: 1)),
        ),
        row(
          id: 'y',
          title: '最新の作業',
          status: 'in_progress',
          instance: 'claude',
          updatedAt: kNow.subtract(const Duration(minutes: 1)),
        ),
      ]);

      expect(snapshot.agents.single.currentTaskTitle, '最新の作業');
    });
  });

  group('formatElapsed', () {
    test('経過に応じた表記になる', () {
      expect(formatElapsed(kNow, kNow), 'たった今');
      expect(
        formatElapsed(kNow.subtract(const Duration(minutes: 3)), kNow),
        '3分前',
      );
      expect(
        formatElapsed(kNow.subtract(const Duration(hours: 5)), kNow),
        '5時間前',
      );
      expect(
        formatElapsed(kNow.subtract(const Duration(days: 2)), kNow),
        '2日前',
      );
      expect(formatElapsed(null, kNow), '');
    });
  });

  group('AgentBoardPage', () {
    testWidgets('未ログインはログイン導線のみ表示し、盤面を出さない', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AgentBoardPage(service: _FakeBoardService(signedIn: false)),
        ),
      );
      await tester.pump();

      expect(find.text('この機能はログインが必要です'), findsOneWidget);
      expect(find.text('ログインする'), findsOneWidget);
      expect(find.text('未着手'), findsNothing);
      expect(find.text('進行中'), findsNothing);
    });

    testWidgets('ログイン済みは盤面とカードを表示する', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AgentBoardPage(
            service: _FakeBoardService(
              rows: <Map<String, dynamic>>[
                row(id: 'a', title: 'カンバン実装', status: 'in_progress'),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      expect(find.text('この機能はログインが必要です'), findsNothing);
      expect(find.text('未着手'), findsOneWidget);
      expect(find.text('進行中'), findsOneWidget);
      expect(find.text('ブロック'), findsOneWidget);
      expect(find.text('完了'), findsOneWidget);
      // タイトルはカードと、エージェント一覧の「現在のタスク名」の 2 箇所に出る。
      expect(find.text('カンバン実装'), findsNWidgets(2));
      expect(find.text('Claude Code'), findsWidgets);
    });
  });
}
