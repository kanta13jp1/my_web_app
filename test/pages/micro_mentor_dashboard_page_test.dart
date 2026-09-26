import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/micro_mentor.dart';
import 'package:my_web_app/pages/micro_mentor_dashboard_page.dart';
import 'package:my_web_app/services/micro_mentor_service.dart';

void main() {
  testWidgets('shows parallel mentor proposals and accepts a focus request', (
    tester,
  ) async {
    final service = _FakeMicroMentorService(_snapshot());
    await _pumpPage(tester, service);

    expect(find.text('健康コーチ'), findsWidgets);
    expect(find.text('学習コーチ'), findsWidgets);

    await tester.enterText(
      find.byKey(const Key('micro-mentor-focus')),
      '来週の生活を整えたい',
    );
    await tester.tap(find.byKey(const Key('generate-mentor-proposals')));
    await tester.pumpAndSettle();

    expect(service.generatedFocus, '来週の生活を整えたい');
    await tester.scrollUntilVisible(
      find.text('振り返り時間を確保する'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('朝に20分歩く'), findsOneWidget);
    expect(find.text('振り返り時間を確保する'), findsOneWidget);
  });

  testWidgets('creates a mentor from role, tone, and value settings', (
    tester,
  ) async {
    final service = _FakeMicroMentorService(
      const MicroMentorDashboardSnapshot.empty(),
    );
    await _pumpPage(tester, service);

    await tester.tap(find.text('メンターを追加').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('mentor-name-field')), '家計コーチ');
    await tester.enterText(find.byKey(const Key('mentor-domain-field')), '家計');
    await tester.enterText(
      find.byKey(const Key('mentor-role-field')),
      '固定費を見直す提案を作る',
    );
    await tester.enterText(
      find.byKey(const Key('mentor-values-field')),
      '安心、継続',
    );
    await tester.tap(find.byKey(const Key('save-mentor')));
    await tester.pumpAndSettle();

    expect(service.savedDraft?.name, '家計コーチ');
    expect(service.savedDraft?.role, '固定費を見直す提案を作る');
    expect(service.savedDraft?.tone, '穏やか');
    expect(service.savedDraft?.values, <String>['安心', '継続']);
    expect(find.text('家計コーチ'), findsWidgets);
  });

  testWidgets('lets the user edit and reject a proposal', (tester) async {
    final service = _FakeMicroMentorService(_snapshot());
    await _pumpPage(tester, service);

    await tester.scrollUntilVisible(
      find.byKey(const Key('edit-proposal-proposal-1')),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('edit-proposal-proposal-1')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('proposal-description-field')),
      '昼休みに15分歩く',
    );
    await tester.tap(find.byKey(const Key('save-proposal')));
    await tester.pumpAndSettle();

    expect(service.updatedDescription, '昼休みに15分歩く');
    expect(find.text('昼休みに15分歩く'), findsOneWidget);

    await tester.tap(find.byKey(const Key('reject-proposal-proposal-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('却下する'));
    await tester.pumpAndSettle();

    expect(
      service.statusUpdates['proposal-1'],
      MicroMentorProposalStatus.rejected,
    );
    expect(find.text('却下'), findsOneWidget);
  });

  testWidgets('renders the dashboard on a narrow viewport without overflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpPage(tester, _FakeMicroMentorService(_snapshot()));

    expect(find.byType(MicroMentorDashboardPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpPage(
  WidgetTester tester,
  MicroMentorServiceContract service,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: MicroMentorDashboardPage(service: service),
    ),
  );
  await tester.pumpAndSettle();
}

MicroMentorDashboardSnapshot _snapshot() {
  final createdAt = DateTime.utc(2026, 7, 22);
  return MicroMentorDashboardSnapshot(
    mentors: <MicroMentor>[
      MicroMentor(
        id: 'mentor-1',
        userId: 'user-1',
        slug: 'health',
        name: '健康コーチ',
        domain: '健康',
        role: '無理のない健康習慣を提案する',
        tone: '穏やか',
        values: const <String>['安全', '継続'],
        enabled: true,
        createdAt: createdAt,
        updatedAt: createdAt,
      ),
      MicroMentor(
        id: 'mentor-2',
        userId: 'user-1',
        slug: 'learning',
        name: '学習コーチ',
        domain: '学習',
        role: '復習計画を分解する',
        tone: '率直',
        values: const <String>['理解'],
        enabled: true,
        createdAt: createdAt,
        updatedAt: createdAt,
      ),
    ],
    proposals: <MicroMentorProposal>[
      MicroMentorProposal(
        id: 'proposal-1',
        userId: 'user-1',
        mentorId: 'mentor-1',
        focus: '来週の生活',
        type: MicroMentorProposalType.task,
        title: '朝に20分歩く',
        description: '朝食の前に近所を20分歩く',
        rationale: '先に体を動かすと一日のリズムを作りやすい',
        status: MicroMentorProposalStatus.proposed,
        originalPayload: const <String, dynamic>{},
        createdAt: createdAt,
        updatedAt: createdAt,
      ),
    ],
  );
}

class _FakeMicroMentorService implements MicroMentorServiceContract {
  MicroMentorDashboardSnapshot snapshot;
  MicroMentorDraft? savedDraft;
  String? generatedFocus;
  String? updatedDescription;
  final Map<String, MicroMentorProposalStatus> statusUpdates =
      <String, MicroMentorProposalStatus>{};

  _FakeMicroMentorService(this.snapshot);

  @override
  Future<MicroMentorDashboardSnapshot> loadDashboard() async => snapshot;

  @override
  Future<MicroMentor> saveMentor({
    String? mentorId,
    required MicroMentorDraft draft,
  }) async {
    savedDraft = draft;
    final mentor = MicroMentor(
      id: mentorId ?? 'mentor-new',
      userId: 'user-1',
      slug: 'mentor-new',
      name: draft.name,
      domain: draft.domain,
      role: draft.role,
      tone: draft.tone,
      values: normalizeMicroMentorValues(draft.values),
      enabled: true,
      createdAt: DateTime.utc(2026, 7, 22),
      updatedAt: DateTime.utc(2026, 7, 22),
    );
    snapshot = MicroMentorDashboardSnapshot(
      mentors: <MicroMentor>[
        ...snapshot.mentors.where((item) => item.id != mentor.id),
        mentor,
      ],
      proposals: snapshot.proposals,
    );
    return mentor;
  }

  @override
  Future<void> setMentorEnabled(String mentorId, bool enabled) async {}

  @override
  Future<MicroMentorGenerationResult> generateProposals(String focus) async {
    generatedFocus = focus;
    final proposal = MicroMentorProposal(
      id: 'proposal-new',
      userId: 'user-1',
      mentorId: 'mentor-2',
      focus: focus,
      type: MicroMentorProposalType.schedule,
      title: '振り返り時間を確保する',
      description: '金曜の夜に15分振り返る',
      rationale: '次週の調整材料を残せる',
      status: MicroMentorProposalStatus.proposed,
      originalPayload: const <String, dynamic>{},
      createdAt: DateTime.utc(2026, 7, 22),
      updatedAt: DateTime.utc(2026, 7, 22),
    );
    snapshot = MicroMentorDashboardSnapshot(
      mentors: snapshot.mentors,
      proposals: <MicroMentorProposal>[proposal, ...snapshot.proposals],
    );
    return MicroMentorGenerationResult(
      proposals: <MicroMentorProposal>[proposal],
      failedMentorCount: 0,
    );
  }

  @override
  Future<MicroMentorProposal> updateProposal({
    required String proposalId,
    required String title,
    required String description,
    required MicroMentorProposalType type,
    DateTime? scheduledFor,
  }) async {
    updatedDescription = description;
    final current = snapshot.proposals.firstWhere(
      (item) => item.id == proposalId,
    );
    final updated = current.copyWith(
      title: title,
      description: description,
      type: type,
      scheduledFor: scheduledFor,
      clearScheduledFor: type == MicroMentorProposalType.task,
    );
    snapshot = MicroMentorDashboardSnapshot(
      mentors: snapshot.mentors,
      proposals: snapshot.proposals
          .map((item) => item.id == proposalId ? updated : item)
          .toList(),
    );
    return updated;
  }

  @override
  Future<void> setProposalStatus(
    String proposalId,
    MicroMentorProposalStatus status,
  ) async {
    statusUpdates[proposalId] = status;
    snapshot = MicroMentorDashboardSnapshot(
      mentors: snapshot.mentors,
      proposals: snapshot.proposals
          .map(
            (item) =>
                item.id == proposalId ? item.copyWith(status: status) : item,
          )
          .toList(),
    );
  }
}
