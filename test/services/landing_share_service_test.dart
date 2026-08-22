// AgentOrgPage transitively imports browser-only package:web APIs.
@TestOn('browser')

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/agent_memory_entry.dart';
import 'package:my_web_app/models/agent_message.dart';
import 'package:my_web_app/models/agent_profile.dart';
import 'package:my_web_app/models/agent_relationship.dart';
import 'package:my_web_app/models/agent_task.dart';
import 'package:my_web_app/pages/agent_org_page.dart';
import 'package:my_web_app/pages/landing_page.dart';
import 'package:my_web_app/services/agent_org_service.dart';
import 'package:my_web_app/services/task_clarity_service.dart';
import 'package:my_web_app/services/asset_watchlist_service.dart';
import 'package:my_web_app/services/growth_mission_service.dart';
import 'package:my_web_app/services/landing_conversion_experiment_service.dart';
import 'package:my_web_app/services/landing_oauth_callback_failure.dart';
import 'package:my_web_app/services/landing_page_adapter.dart';
import 'package:my_web_app/services/landing_share_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeLandingPageAdapter implements LandingPageAdapter {
  int loadShareSnapshotCallCount = 0;
  int loadLpViewStatsCallCount = 0;
  int recordLpViewCallCount = 0;
  final List<String> sharedChannels = <String>[];
  final List<String> conversionEvents = <String>[];

  LandingShareSnapshot shareSnapshot = const LandingShareSnapshot(
    todayCount: 2,
    totalCount: 5,
    channelCounts: <String, int>{
      LandingShareService.channelX: 2,
      LandingShareService.channelCopy: 1,
    },
    lastChannel: LandingShareService.channelX,
  );

  LandingPageViewStats lpViewStats = LandingPageViewStats(
    todayViews: 3,
    monthViews: 7,
    totalViews: 11,
    series: <LandingPageViewPoint>[
      LandingPageViewPoint(date: DateTime(2026, 3, 1), count: 3),
      LandingPageViewPoint(date: DateTime(2026, 3, 2), count: 4),
    ],
  );

  LandingSocialProofStats socialProofStats = const LandingSocialProofStats(
    totalUsers: 38,
    publicMemoCount: 12,
  );

  @override
  Stream<AuthState> authStateChanges() => const Stream<AuthState>.empty();

  @override
  Future<LandingShareSnapshot> loadShareSnapshot() async {
    loadShareSnapshotCallCount += 1;
    return shareSnapshot;
  }

  @override
  Future<LandingPageViewStats> loadLpViewStats() async {
    loadLpViewStatsCallCount += 1;
    return lpViewStats;
  }

  @override
  Future<LandingSocialProofStats> loadSocialProofStats() async {
    return socialProofStats;
  }

  @override
  Future<void> recordLpView() async {
    recordLpViewCallCount += 1;
  }

  @override
  Future<String> improveTrialPrompt({
    required String prompt,
  }) async {
    return 'ACTION: Test action\nREASON: Test reason';
  }

  @override
  Future<LandingShareSnapshot> shareLandingPage({
    required String channel,
  }) async {
    sharedChannels.add(channel);
    shareSnapshot = LandingShareSnapshot(
      todayCount: shareSnapshot.todayCount + 1,
      totalCount: shareSnapshot.totalCount + 1,
      channelCounts: <String, int>{
        ...shareSnapshot.channelCounts,
        channel: shareSnapshot.countFor(channel) + 1,
      },
      lastChannel: channel,
    );
    return shareSnapshot;
  }

  @override
  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) =>
      Future<AuthResponse>.error(
        UnsupportedError('signInWithPassword is not used in this test'),
      );

  @override
  Future<bool> signInWithGoogle({
    String? redirectTo,
  }) =>
      Future<bool>.value(true);

  @override
  Future<void> recordGoogleOAuthCallbackFailure({
    required LandingOAuthCallbackFailureCategory category,
  }) async {}

  @override
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? emailRedirectTo,
  }) =>
      Future<AuthResponse>.error(
        UnsupportedError('signUp is not used in this test'),
      );

  @override
  Future<void> sendMagicLink({
    required String email,
    String? emailRedirectTo,
    bool shouldCreateUser = true,
  }) =>
      Future<void>.value();

  @override
  Future<void> recordInboxOpen() async {}

  @override
  Future<void> recordSaveCta() async {}

  @override
  Future<void> recordTrialRun() async {}

  @override
  Future<void> recordConversionEvent({
    required String eventKey,
    required String visitorId,
  }) async {
    conversionEvents.add(eventKey);
  }
}

class _FakeAgentOrgService extends Fake implements AgentOrgService {
  _FakeAgentOrgService(this.snapshot);

  AgentOrgSnapshot snapshot;
  final List<Map<String, String>> boardPosts = <Map<String, String>>[];
  final List<Map<String, String>> delegatedTasks = <Map<String, String>>[];
  final List<Map<String, String>> boardReactions = <Map<String, String>>[];

  @override
  Future<AgentOrgSnapshot> loadSnapshot() async => snapshot;

  @override
  Future<AgentTask> delegateTask({
    required String supervisorAgentId,
    required String assigneeAgentId,
    required String title,
    String description = '',
    String priority = 'high',
    String taskType = 'delegated_action',
    String source = 'manual_delegate',
    String messageKind = 'directive',
    String? conversationId,
    bool createMessage = true,
    String? actorAgentId,
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) async {
    delegatedTasks.add(<String, String>{
      'supervisorAgentId': supervisorAgentId,
      'assigneeAgentId': assigneeAgentId,
      'title': title,
      'description': description,
      'priority': priority,
      'taskType': taskType,
      'source': source,
    });

    final now = DateTime(2026, 3, 18, 10, 00);
    final task = AgentTask(
      id: 'task-${delegatedTasks.length}',
      userId: 'user-1',
      supervisorAgentId: supervisorAgentId,
      assigneeAgentId: assigneeAgentId,
      title: title,
      description: description,
      status: 'queued',
      priority: priority,
      taskType: taskType,
      source: source,
      createdAt: now,
      updatedAt: now,
      metadata: metadata,
    );

    final nextTaskCounts = <String, int>{
      ...snapshot.openTaskCountsByAgent,
      assigneeAgentId:
          (snapshot.openTaskCountsByAgent[assigneeAgentId] ?? 0) + 1,
    };

    snapshot = AgentOrgSnapshot(
      agents: snapshot.agents,
      tasks: <AgentTask>[task, ...snapshot.tasks],
      recentMemories: snapshot.recentMemories,
      relationships: snapshot.relationships,
      recentMessages: snapshot.recentMessages,
      openTaskCountsByAgent: nextTaskCounts,
      memoryCountsByAgent: snapshot.memoryCountsByAgent,
    );

    return task;
  }

  @override
  Future<AgentTask> updateTaskClarity({
    required String taskId,
    required Map<String, dynamic> clarity,
  }) async {
    final current = snapshot.tasks.firstWhere((task) => task.id == taskId);
    final updated = AgentTask.fromJson(<String, dynamic>{
      ...current.toJson(),
      'metadata': <String, dynamic>{
        ...current.metadata,
        'clarity': clarity,
      },
    });
    snapshot = AgentOrgSnapshot(
      agents: snapshot.agents,
      tasks: snapshot.tasks
          .map((task) => task.id == taskId ? updated : task)
          .toList(growable: false),
      recentMemories: snapshot.recentMemories,
      relationships: snapshot.relationships,
      recentMessages: snapshot.recentMessages,
      openTaskCountsByAgent: snapshot.openTaskCountsByAgent,
      memoryCountsByAgent: snapshot.memoryCountsByAgent,
    );
    return updated;
  }

  @override
  Future<AgentMessage?> postBoardMessage({
    required String fromAgentId,
    required String channel,
    required String summary,
    String status = 'sent',
    Map<String, dynamic> payload = const <String, dynamic>{},
    String? actorAgentId,
  }) async {
    boardPosts.add(<String, String>{
      'fromAgentId': fromAgentId,
      'channel': channel,
      'summary': summary,
    });

    final now = DateTime(2026, 3, 18, 9, 45);
    final message = AgentMessage(
      id: 'board-${boardPosts.length}',
      userId: 'user-1',
      fromAgentId: fromAgentId,
      toAgentId: fromAgentId,
      conversationId: 'board:$channel',
      messageKind: 'board',
      summary: summary,
      payload: payload,
      status: status,
      createdAt: now,
      updatedAt: now,
      metadata: <String, dynamic>{
        'channel': channel,
        'source': 'board_channel',
      },
    );

    snapshot = AgentOrgSnapshot(
      agents: snapshot.agents,
      tasks: snapshot.tasks,
      recentMemories: snapshot.recentMemories,
      relationships: snapshot.relationships,
      recentMessages: <AgentMessage>[message, ...snapshot.recentMessages],
      openTaskCountsByAgent: snapshot.openTaskCountsByAgent,
      memoryCountsByAgent: snapshot.memoryCountsByAgent,
    );
    return message;
  }

  @override
  Future<AgentMessage?> toggleBoardReaction({
    required String messageId,
    required String emoji,
    required String actorAgentId,
  }) async {
    boardReactions.add(<String, String>{
      'messageId': messageId,
      'emoji': emoji,
      'actorAgentId': actorAgentId,
    });

    AgentMessage? updatedMessage;
    final nextMessages = snapshot.recentMessages.map((message) {
      if (message.id != messageId) {
        return message;
      }
      final nextMetadata = _toggleReactionMetadata(
        message.metadata,
        emoji: emoji,
        actorAgentId: actorAgentId,
      );
      updatedMessage = AgentMessage(
        id: message.id,
        userId: message.userId,
        fromAgentId: message.fromAgentId,
        toAgentId: message.toAgentId,
        linkedTaskId: message.linkedTaskId,
        conversationId: message.conversationId,
        messageKind: message.messageKind,
        summary: message.summary,
        payload: message.payload,
        status: message.status,
        acknowledgedAt: message.acknowledgedAt,
        resolvedAt: message.resolvedAt,
        createdAt: message.createdAt,
        updatedAt: message.updatedAt,
        metadata: nextMetadata,
      );
      return updatedMessage!;
    }).toList();

    snapshot = AgentOrgSnapshot(
      agents: snapshot.agents,
      tasks: snapshot.tasks,
      recentMemories: snapshot.recentMemories,
      relationships: snapshot.relationships,
      recentMessages: nextMessages,
      openTaskCountsByAgent: snapshot.openTaskCountsByAgent,
      memoryCountsByAgent: snapshot.memoryCountsByAgent,
    );
    return updatedMessage;
  }
}

AgentProfile _agent({
  required String id,
  required String slug,
  required String displayName,
  required String department,
  String status = 'active',
}) {
  final now = DateTime(2026, 3, 18, 9);
  return AgentProfile(
    id: id,
    userId: 'user-1',
    slug: slug,
    displayName: displayName,
    roleTitle: displayName,
    department: department,
    status: status,
    identityPrompt: '$displayName owns $department decisions.',
    permissionsSummary: '$displayName can coordinate work.',
    createdAt: now,
    updatedAt: now,
    lastActiveAt: now,
  );
}

AgentMessage _boardMessage({
  required String id,
  required String fromAgentId,
  required String channel,
  required String summary,
  Map<String, dynamic> metadata = const <String, dynamic>{},
}) {
  final now = DateTime(2026, 3, 18, 9, 30);
  return AgentMessage(
    id: id,
    userId: 'user-1',
    fromAgentId: fromAgentId,
    toAgentId: fromAgentId,
    conversationId: 'board:$channel',
    messageKind: 'board',
    summary: summary,
    payload: const <String, dynamic>{},
    status: 'sent',
    createdAt: now,
    updatedAt: now,
    metadata: <String, dynamic>{
      'channel': channel,
      ...metadata,
    },
  );
}

Map<String, dynamic> _toggleReactionMetadata(
  Map<String, dynamic> metadata, {
  required String emoji,
  required String actorAgentId,
}) {
  final nextMetadata = <String, dynamic>{...metadata};
  final reactionActorIds = <String, List<String>>{};
  final rawReactionActorIds = metadata['reaction_actor_ids'];
  if (rawReactionActorIds is Map) {
    for (final entry in rawReactionActorIds.entries) {
      final value = entry.value;
      if (value is! List) {
        continue;
      }
      reactionActorIds[entry.key.toString()] = value
          .map((item) => item?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty)
          .toList();
    }
  }

  final nextActors = List<String>.from(reactionActorIds[emoji] ?? const []);
  if (nextActors.contains(actorAgentId)) {
    nextActors.remove(actorAgentId);
  } else {
    nextActors.add(actorAgentId);
    nextActors.sort();
  }

  if (nextActors.isEmpty) {
    reactionActorIds.remove(emoji);
  } else {
    reactionActorIds[emoji] = nextActors;
  }

  if (reactionActorIds.isEmpty) {
    nextMetadata.remove('reaction_actor_ids');
  } else {
    nextMetadata['reaction_actor_ids'] = reactionActorIds;
  }
  return nextMetadata;
}

AgentOrgSnapshot _snapshotWithMessages(List<AgentMessage> messages) {
  return AgentOrgSnapshot(
    agents: <AgentProfile>[
      _agent(
        id: 'ceo-1',
        slug: 'ceo',
        displayName: 'CEO',
        department: 'Executive',
      ),
      _agent(
        id: 'cfo-1',
        slug: 'cfo',
        displayName: 'CFO',
        department: 'Finance',
      ),
      _agent(
        id: 'cmo-1',
        slug: 'cmo',
        displayName: 'CMO',
        department: 'Growth',
      ),
    ],
    tasks: const <AgentTask>[],
    recentMemories: const <AgentMemoryEntry>[],
    relationships: const <AgentRelationship>[],
    recentMessages: messages,
    openTaskCountsByAgent: const <String, int>{},
    memoryCountsByAgent: const <String, int>{},
  );
}

class _FixedTaskClarityEvaluator implements TaskClarityEvaluator {
  final TaskClarityEvaluation evaluation;

  const _FixedTaskClarityEvaluator(this.evaluation);

  @override
  Future<TaskClarityEvaluation> evaluate({
    required String title,
    String description = '',
  }) async {
    return evaluation;
  }
}

void main() {
  const watchlistService = AssetWatchlistService();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('buildShareUrl keeps the base params and adds tracking', () {
    final shareUrl =
        LandingShareService.buildShareUrl(LandingShareService.channelX);
    final uri = Uri.parse(shareUrl);

    expect(uri.queryParameters['v'], 'test2025');
    expect(uri.queryParameters['src'], 'x_share');
    expect(uri.queryParameters['utm_source'], 'x_share');
    expect(uri.queryParameters['utm_medium'], 'social');
    expect(uri.queryParameters['utm_campaign'], 'share_boost');
  });

  test('recordShareAction stores local counters and resets daily count',
      () async {
    final first = await LandingShareService.recordShareAction(
      channel: LandingShareService.channelX,
      now: DateTime(2026, 3, 3, 9),
    );
    final second = await LandingShareService.recordShareAction(
      channel: LandingShareService.channelCopy,
      now: DateTime(2026, 3, 3, 10),
    );
    final nextDay = await LandingShareService.loadSnapshot(
      now: DateTime(2026, 3, 4, 8),
    );

    expect(first.todayCount, 1);
    expect(first.totalCount, 1);
    expect(first.countFor(LandingShareService.channelX), 1);

    expect(second.todayCount, 2);
    expect(second.totalCount, 2);
    expect(second.countFor(LandingShareService.channelX), 1);
    expect(second.countFor(LandingShareService.channelCopy), 1);
    expect(second.lastChannel, LandingShareService.channelCopy);

    expect(nextDay.todayCount, 0);
    expect(nextDay.totalCount, 2);
    expect(nextDay.countFor(LandingShareService.channelX), 1);
    expect(nextDay.countFor(LandingShareService.channelCopy), 1);
  });

  test('resolveIncomingSource maps supported share sources', () {
    expect(
      LandingShareService.resolveIncomingSource(<String, String>{'src': 'x'}),
      'x_share',
    );
    expect(
      LandingShareService.resolveIncomingSource(
        <String, String>{'src': 'facebook'},
      ),
      'facebook',
    );
    expect(
      LandingShareService.resolveIncomingSource(
        <String, String>{'src': 'copy'},
      ),
      'copy_link',
    );
    expect(
      LandingShareService.resolveIncomingSource(
        <String, String>{'src': 'unknown'},
      ),
      isNull,
    );
  });

  testWidgets('AssetWatchlistService loads grouped items before ungrouped ones',
      (WidgetTester tester) async {
    final prefs = await SharedPreferences.getInstance();

    await watchlistService.saveEntry(
      AssetWatchlistEntry(
        assetType: 'cash',
        group: '',
        memo: 'keep a buffer',
        addedAt: DateTime(2026, 3, 19, 8),
      ),
      prefs: prefs,
    );
    await watchlistService.saveEntry(
      AssetWatchlistEntry(
        assetType: 'nisa',
        group: 'invest',
        memo: 'check weekly contribution',
        addedAt: DateTime(2026, 3, 19, 9),
      ),
      prefs: prefs,
    );

    final entries = await watchlistService.loadEntries(prefs: prefs);

    expect(
      entries.map((entry) => entry.assetType).toList(),
      <String>['nisa', 'cash'],
    );
    expect(entries.first.group, 'invest');
    expect(entries.last.memo, 'keep a buffer');
  });

  testWidgets(
      'AssetWatchlistService updates the same asset instead of duplicating',
      (WidgetTester tester) async {
    final prefs = await SharedPreferences.getInstance();

    await watchlistService.saveEntry(
      AssetWatchlistEntry(
        assetType: 'card',
        group: 'fixed',
        memo: 'review due date',
        addedAt: DateTime(2026, 3, 18, 12),
      ),
      prefs: prefs,
    );
    await watchlistService.saveEntry(
      AssetWatchlistEntry(
        assetType: 'card',
        group: 'fixed',
        memo: 'review this month statement',
        addedAt: DateTime(2026, 3, 18, 12),
      ),
      prefs: prefs,
    );

    final entries = await watchlistService.loadEntries(prefs: prefs);

    expect(entries, hasLength(1));
    expect(entries.single.assetType, 'card');
    expect(entries.single.memo, 'review this month statement');
  });

  testWidgets('AssetWatchlistService removes a watched asset cleanly',
      (WidgetTester tester) async {
    final prefs = await SharedPreferences.getInstance();

    await watchlistService.saveEntry(
      AssetWatchlistEntry(
        assetType: 'cash',
        group: 'living',
        memo: 'maintain runway',
        addedAt: DateTime(2026, 3, 19),
      ),
      prefs: prefs,
    );
    await watchlistService.saveEntry(
      AssetWatchlistEntry(
        assetType: 'loan',
        group: 'debt',
        memo: 'candidate for extra payment',
        addedAt: DateTime(2026, 3, 19, 9),
      ),
      prefs: prefs,
    );

    final entries = await watchlistService.removeEntry(
      'cash',
      prefs: prefs,
    );

    expect(
      entries.map((entry) => entry.assetType).toList(),
      <String>['loan'],
    );
  });

  testWidgets('LandingPage uses injected adapter for initial load and sharing',
      (WidgetTester tester) async {
    final adapter = _FakeLandingPageAdapter();
    final assignment = LandingExperimentAssignment(
      hypothesis: LandingConversionExperimentService.hypotheses.first,
      variant: LandingExperimentVariant.treatment,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: LandingPage(
          adapter: adapter,
          experimentAssignment: assignment,
          showUnverifiedMarketingForQa: true,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('landing_page_scaffold')), findsOneWidget);
    expect(find.byKey(const Key('landing_hero_section')), findsOneWidget);
    expect(find.byKey(const Key('landing_trial_section')), findsOneWidget);
    expect(find.byKey(const Key('landing_auth_section')), findsOneWidget);
    expect(find.byKey(const Key('landing_social_proof_stats')), findsOneWidget);
    expect(find.byKey(const Key('landing_editorial_prologue')), findsOneWidget);
    for (var chapter = 1; chapter <= 4; chapter++) {
      expect(
        find.byKey(Key('landing_editorial_chapter_$chapter')),
        findsOneWidget,
      );
    }
    expect(
      find.byKey(const Key('landing_editorial_archive_toggle')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('landing_migration_guide')), findsNothing);
    expect(find.byKey(const Key('landing_comparison_links')), findsNothing);

    final archiveToggle = find.byKey(
      const Key('landing_editorial_archive_toggle'),
    );
    await tester.ensureVisible(archiveToggle);
    await tester.pump();
    await tester.tap(archiveToggle);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('landing_migration_guide')), findsOneWidget);
    expect(find.byKey(const Key('landing_comparison_links')), findsOneWidget);
    expect(adapter.loadShareSnapshotCallCount, 0);
    expect(adapter.loadLpViewStatsCallCount, 0);
    // LP View 計測 (increment_lp_view + 流入元帰属) は初期表示で1回だけ走る。
    expect(adapter.recordLpViewCallCount, 1);
    expect(adapter.conversionEvents, contains('lp_exp_h01_treatment_view'));
  });

  testWidgets(
      'LandingPage shows referral invite context when a code is pending',
      (WidgetTester tester) async {
    final adapter = _FakeLandingPageAdapter();
    const growthService = GrowthMissionService();
    await growthService.capturePendingReferralFromUri(
      currentUri: Uri.parse('https://example.com/referral?ref=invite42'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: LandingPage(
          adapter: adapter,
          growthService: growthService,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.byKey(const Key('landing_referral_invite_section')),
      findsOneWidget,
    );
    expect(find.textContaining('INVITE42'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
    expect(find.text('See import flow'), findsOneWidget);
  });

  testWidgets('AgentOrgPage filters board timeline by channel',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final service = _FakeAgentOrgService(
      _snapshotWithMessages(<AgentMessage>[
        _boardMessage(
          id: 'message-1',
          fromAgentId: 'ceo-1',
          channel: 'executive',
          summary: 'CEO weekly alignment note',
        ),
        _boardMessage(
          id: 'message-2',
          fromAgentId: 'cfo-1',
          channel: 'finance',
          summary: 'CFO budget checkpoint',
        ),
      ]),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AgentOrgPage(service: service),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const Key('agent_org_board_section')), findsOneWidget);
    expect(find.text('CEO weekly alignment note'), findsOneWidget);
    expect(find.text('CFO budget checkpoint'), findsNothing);

    final scrollable = find.byType(Scrollable).first;
    final financeChip =
        find.byKey(const Key('agent_org_board_channel_finance'));
    await tester.scrollUntilVisible(financeChip, 200, scrollable: scrollable);
    await tester.tap(financeChip);
    await tester.pump();

    expect(find.text('CEO weekly alignment note'), findsNothing);
    expect(find.text('CFO budget checkpoint'), findsOneWidget);
  });

  testWidgets('AgentOrgPage posts board updates through the injected service',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final service = _FakeAgentOrgService(
      _snapshotWithMessages(<AgentMessage>[
        _boardMessage(
          id: 'message-1',
          fromAgentId: 'ceo-1',
          channel: 'executive',
          summary: 'CEO weekly alignment note',
        ),
      ]),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AgentOrgPage(service: service),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.enterText(
      find.byKey(const Key('agent_org_board_message_field')),
      'Need a launch readiness summary by noon.',
    );
    final scrollable = find.byType(Scrollable).first;
    final postButton = find.byKey(const Key('agent_org_board_post_button'));
    await tester.scrollUntilVisible(postButton, 200, scrollable: scrollable);
    tester.widget<FilledButton>(postButton).onPressed?.call();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(service.boardPosts, hasLength(1));
    expect(service.boardPosts.single['channel'], 'executive');
    expect(
      service.boardPosts.single['summary'],
      'Need a launch readiness summary by noon.',
    );
    expect(
      find.text('Need a launch readiness summary by noon.'),
      findsOneWidget,
    );
  });

  testWidgets(
      'AgentOrgPage applies Chatwork-style task templates before delegating',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final service = _FakeAgentOrgService(
      _snapshotWithMessages(const <AgentMessage>[]),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AgentOrgPage(service: service),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final scrollable = find.byType(Scrollable).first;
    final templateChip =
        find.byKey(const Key('agent_org_task_template_estimate-request'));
    await tester.scrollUntilVisible(templateChip, 200, scrollable: scrollable);
    await tester.tap(templateChip);
    await tester.pump();

    final titleField = tester.widget<TextField>(
      find.byKey(const Key('agent_org_task_title_field')),
    );
    final descriptionField = tester.widget<TextField>(
      find.byKey(const Key('agent_org_task_description_field')),
    );

    expect(titleField.controller?.text, 'Prepare estimate response');
    expect(
      descriptionField.controller?.text,
      'Outline scope, pricing assumptions, open questions, and a proposed response plan for the customer.',
    );

    final submitButton =
        find.byKey(const Key('agent_org_delegation_submit_button'));
    await tester.scrollUntilVisible(submitButton, 200, scrollable: scrollable);
    await tester.tap(submitButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(service.delegatedTasks, hasLength(1));
    expect(service.delegatedTasks.single['assigneeAgentId'], 'cfo-1');
    expect(service.delegatedTasks.single['title'], 'Prepare estimate response');
    expect(
      service.delegatedTasks.single['description'],
      'Outline scope, pricing assumptions, open questions, and a proposed response plan for the customer.',
    );
    expect(find.text('Prepare estimate response'), findsOneWidget);
  });

  testWidgets(
      'AgentOrgPage clarifies a vague task before returning to the dashboard',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final service = _FakeAgentOrgService(
      _snapshotWithMessages(const <AgentMessage>[]),
    );
    final evaluator = _FixedTaskClarityEvaluator(
      TaskClarityEvaluation(
        score: 3,
        threshold: 6,
        status: 'needs_clarification',
        source: 'test',
        questions: const <String>['いつまでに完了しますか？'],
        ambiguities: const <String>['期限が未指定です'],
        evaluatedAt: DateTime.utc(2026, 7, 20),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AgentOrgPage(
          service: service,
          clarityEvaluator: evaluator,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.enterText(
      find.byKey(const Key('agent_org_task_title_field')),
      '売上を改善する',
    );
    final scrollable = find.byType(Scrollable).first;
    final submitButton =
        find.byKey(const Key('agent_org_delegation_submit_button'));
    await tester.scrollUntilVisible(submitButton, 200, scrollable: scrollable);
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    expect(find.text('タスクの曖昧さを確認'), findsOneWidget);
    expect(service.snapshot.tasks.single.needsClarification, isTrue);

    await tester.enterText(
      find.byKey(const Key('task_clarity_answer_0')),
      '7月31日まで',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('task_clarity_submit_button')));
    await tester.pumpAndSettle();

    expect(
      service.snapshot.tasks.single.clarityStatus,
      'clarified',
    );
    expect(find.text('明確化済み 3/10'), findsOneWidget);
  });

  testWidgets(
      'AgentOrgPage supports Slack-style quick reactions on board posts',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final service = _FakeAgentOrgService(
      _snapshotWithMessages(<AgentMessage>[
        _boardMessage(
          id: 'message-1',
          fromAgentId: 'cfo-1',
          channel: 'executive',
          summary: 'Please confirm budget sign-off today.',
        ),
      ]),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AgentOrgPage(service: service),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final scrollable = find.byType(Scrollable).first;
    final reactionChip =
        find.byKey(const Key('agent_org_board_reaction_message-1_thumbs_up'));
    await tester.scrollUntilVisible(reactionChip, 200, scrollable: scrollable);
    tester.widget<FilterChip>(reactionChip).onSelected?.call(true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(service.boardReactions, hasLength(1));
    expect(service.boardReactions.single['messageId'], 'message-1');
    expect(service.boardReactions.single['emoji'], '👍');
    expect(service.boardReactions.single['actorAgentId'], 'ceo-1');

    final chipWidget = tester.widget<FilterChip>(reactionChip);
    expect(chipWidget.selected, isTrue);
    expect(find.text('👍 1'), findsOneWidget);
  });
}
