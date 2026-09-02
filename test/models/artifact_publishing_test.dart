import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/artifact_publishing.dart';

void main() {
  test('candidate parses nested provenance, product, and hard-gate readiness',
      () {
    final candidate = ArtifactCandidate.fromRow({
      'id': 'candidate-1',
      'title': 'Human-edited template',
      'artifact_sha256':
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      'mime_type': 'application/zip',
      'file_size_bytes': 1024,
      'artifact_kind': 'template',
      'stage': 'staged',
      'updated_at': '2026-08-22T08:00:00Z',
      'product_id': 'product-1',
      'shop_products': {
        'id': 'product-1',
        'name_ja': 'テンプレート商品',
        'is_active': false,
      },
      'artifact_provenance': [
        {'source_tool': 'codex'},
        {'source_tool': 'chatgpt'},
      ],
      'artifact_checks': [
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
          {
            'check_key': key,
            'check_kind': 'human',
            'is_hard_gate': true,
            'status': key == 'face_voice_consent' ? 'not_applicable' : 'pass',
            'evidence_summary': 'reviewed',
          },
      ],
    });

    expect(candidate.sourceTools, ['chatgpt', 'codex']);
    expect(candidate.productName, 'テンプレート商品');
    expect(candidate.productActive, isFalse);
    expect(candidate.hardGateCount, 9);
    expect(candidate.satisfiedHardGateCount, 9);
    expect(candidate.allHardGatesSatisfied, isTrue);
  });

  test('transition targets include explicit reject retry and rollback paths',
      () {
    expect(
      ArtifactStage.rejected.transitionTargets,
      [ArtifactStage.intake],
    );
    expect(
      ArtifactStage.ready.transitionTargets,
      [ArtifactStage.published, ArtifactStage.staged],
    );
    expect(ArtifactStage.published.canReject, isFalse);
  });

  test('checks are editable only at their evidence stage', () {
    const automated = ArtifactCheck(
      key: 'secret_scan',
      kind: 'automated',
      status: ArtifactCheckStatus.pending,
      isHardGate: true,
      evidenceSummary: '',
    );
    const human = ArtifactCheck(
      key: 'human_contribution',
      kind: 'human',
      status: ArtifactCheckStatus.pending,
      isHardGate: true,
      evidenceSummary: '',
    );
    const staged = ArtifactCheck(
      key: 'private_object',
      kind: 'external_evidence',
      status: ArtifactCheckStatus.pending,
      isHardGate: true,
      evidenceSummary: '',
    );

    expect(automated.canEditAt(ArtifactStage.automatedChecks), isTrue);
    expect(automated.canEditAt(ArtifactStage.humanReview), isFalse);
    expect(human.canEditAt(ArtifactStage.humanReview), isTrue);
    expect(human.canEditAt(ArtifactStage.approved), isFalse);
    expect(staged.canEditAt(ArtifactStage.staged), isTrue);
    expect(staged.canEditAt(ArtifactStage.ready), isFalse);
  });
}
