import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/artifact_publishing.dart';
import 'package:my_web_app/pages/admin_artifact_publishing_page.dart';
import 'package:my_web_app/services/artifact_publishing_service.dart';

void main() {
  testWidgets('non-admin sees no publishing candidate data', (tester) async {
    final gateway = _FakeGateway(authorized: false, candidates: [_candidate()]);

    await tester.pumpWidget(
      MaterialApp(home: AdminArtifactPublishingPage(gateway: gateway)),
    );
    await tester.pumpAndSettle();

    expect(find.text('管理者のみ利用できます'), findsOneWidget);
    expect(find.text('draft-template.zip'), findsNothing);
    expect(gateway.fetchCount, 0);
  });

  testWidgets('admin sees visual loop, hard gates, and safe stage action', (
    tester,
  ) async {
    final gateway = _FakeGateway(authorized: true, candidates: [_candidate()]);
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(home: AdminArtifactPublishingPage(gateway: gateway)),
    );
    await tester.pumpAndSettle();

    expect(find.text('公開ループ'), findsOneWidget);
    expect(find.text('明示取込'), findsOneWidget);
    expect(find.text('人手レビュー'), findsOneWidget);
    expect(find.text('明示公開'), findsOneWidget);
    expect(find.text('draft-template.zip'), findsOneWidget);
    expect(find.text('必須 2/9'), findsOneWidget);
    expect(find.text('秘密情報: 合格'), findsOneWidget);

    final action = find.text('自動検査へ進む');
    await tester.ensureVisible(action);
    await tester.tap(action);
    await tester.pumpAndSettle();

    expect(gateway.lastTarget, ArtifactStage.automatedChecks);
    expect(find.text('ステージを更新しました。'), findsOneWidget);
  });

  testWidgets('approval records human contribution before moving forward', (
    tester,
  ) async {
    final candidate = _candidate(stage: ArtifactStage.humanReview);
    final gateway = _FakeGateway(authorized: true, candidates: [candidate]);

    await tester.pumpWidget(
      MaterialApp(home: AdminArtifactPublishingPage(gateway: gateway)),
    );
    await tester.pumpAndSettle();

    final approveAction = find.text('人手承認を記録');
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    await tester.tap(approveAction);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      '構成、編集、校正、権利確認と最終検証を人間が担当しました。',
    );
    await tester.pump();
    await tester.tap(find.text('寄与を記録して承認'));
    await tester.pumpAndSettle();

    expect(gateway.lastTarget, ArtifactStage.approved);
    expect(gateway.lastHumanContribution, contains('最終検証'));
  });

  testWidgets('staging records inactive product price and private path', (
    tester,
  ) async {
    final candidate = _candidate(stage: ArtifactStage.approved);
    final gateway = _FakeGateway(authorized: true, candidates: [candidate]);

    await tester.pumpWidget(
      MaterialApp(home: AdminArtifactPublishingPage(gateway: gateway)),
    );
    await tester.pumpAndSettle();

    final stageAction = find.text('商品ステージへ進む');
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    await tester.tap(stageAction);
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'template-product');
    await tester.enterText(fields.at(1), '1200');
    await tester.enterText(fields.at(2), 'template-product/v1.zip');
    await tester.pump();
    await tester.tap(find.text('照合情報を保存してステージ'));
    await tester.pumpAndSettle();

    expect(gateway.lastTarget, ArtifactStage.staged);
    expect(gateway.lastProductId, 'template-product');
    expect(gateway.lastPrice, 1200);
    expect(gateway.lastStoragePath, 'template-product/v1.zip');
  });
}

ArtifactCandidate _candidate({ArtifactStage stage = ArtifactStage.intake}) =>
    ArtifactCandidate(
      id: 'candidate-1',
      title: 'draft-template.zip',
      sha256:
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      mimeType: 'application/zip',
      fileSizeBytes: 2048,
      kind: 'template',
      stage: stage,
      checks: [
        for (final key in const [
          'secret_scan',
          'pii_scan',
          'third_party_license',
          'face_voice_consent',
          'chatgpt_voice_output',
          'human_contribution',
          'price_match',
          'private_object',
          'content_integrity',
        ])
          ArtifactCheck(
            key: key,
            kind: key.endsWith('scan') ? 'automated' : 'human',
            status: key.endsWith('scan')
                ? ArtifactCheckStatus.passed
                : ArtifactCheckStatus.pending,
            isHardGate: true,
            evidenceSummary: key.endsWith('scan') ? 'local scan passed' : '',
          ),
      ],
      sourceTools: const ['codex'],
      productId: null,
      productName: null,
      productActive: false,
      intendedPriceJpy: null,
      proposedStorageBucket: null,
      proposedStoragePath: null,
      humanContributionSummary: '',
      rejectionReason: '',
      updatedAt: DateTime.utc(2026, 8, 22),
    );

class _FakeGateway implements ArtifactPublishingGateway {
  _FakeGateway({required this.authorized, required this.candidates});

  final bool authorized;
  final List<ArtifactCandidate> candidates;
  int fetchCount = 0;
  ArtifactStage? lastTarget;
  String? lastHumanContribution;
  String? lastProductId;
  int? lastPrice;
  String? lastStoragePath;

  @override
  Future<List<ArtifactCandidate>> fetchCandidates() async {
    fetchCount += 1;
    return candidates;
  }

  @override
  Future<bool> isCurrentUserAdmin() async => authorized;

  @override
  Future<void> reviewCheck({
    required String candidateId,
    required String checkKey,
    required ArtifactCheckStatus status,
    String? evidenceSummary,
  }) async {}

  @override
  Future<void> transitionStage({
    required String candidateId,
    required ArtifactStage expectedStage,
    required ArtifactStage targetStage,
    String? rejectionReason,
    String? humanContributionSummary,
    String? productId,
    int? intendedPriceJpy,
    String? proposedStoragePath,
  }) async {
    lastTarget = targetStage;
    lastHumanContribution = humanContributionSummary;
    lastProductId = productId;
    lastPrice = intendedPriceJpy;
    lastStoragePath = proposedStoragePath;
  }
}
