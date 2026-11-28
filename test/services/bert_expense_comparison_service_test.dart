import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/bert_expense_comparison_service.dart';

Map<String, double> _buildTwelveScores({
  String topCategory = 'food',
  double topScore = 0.89,
}) {
  final remaining = (1.0 - topScore) / (BertExpenseCategories.all.length - 1);
  return <String, double>{
    for (final category in BertExpenseCategories.all)
      category: category == topCategory ? topScore : remaining,
  };
}

void main() {
  const service = BertExpenseComparisonService();
  const validProvenance = BertModelProvenance(
    modelId: 'typed-decision-bert',
    weightRevision: 'rev-2026-11-28',
    pinnedSha: '0123456789abcdef0123456789abcdef01234567',
    runtimeKind: 'cpu_inference',
  );

  test('validates canonical 12 expense categories', () {
    expect(BertExpenseCategories.all.length, 12);
    expect(
      BertExpenseCategories.isValidCategorySet(BertExpenseCategories.all),
      isTrue,
    );
    expect(
      BertExpenseCategories.isValidCategorySet(
        BertExpenseCategories.all.take(11),
      ),
      isFalse,
    );
    expect(
      BertExpenseCategories.isValidCategorySet(
        <String>[...BertExpenseCategories.all.take(11), 'food'],
      ),
      isFalse,
    );
  });

  test('validates provenance and rejects fake/mock runtimes and unpinned SHA',
      () {
    expect(validProvenance.validate(), isEmpty);

    const badProvenance = BertModelProvenance(
      modelId: '',
      weightRevision: '',
      pinnedSha: 'main',
      runtimeKind: 'mock_cpu',
    );
    expect(
      badProvenance.validate(),
      containsAll(<String>[
        'model_id_required',
        'weight_revision_required',
        'pinned_sha_must_be_40_hex',
        'fake_or_mock_runtime_forbidden',
      ]),
    );
  });

  test('validates verified record and separates uncalibrated scores from rule',
      () {
    final record = BertSyntheticSampleRecord(
      sampleId: 'syn-001',
      syntheticMemo: '合成サンプル: スーパーで野菜を購入',
      isSyntheticOnly: true,
      ruleCandidateCategory: 'food',
      status: BertMeasurementStatus.verified,
      provenance: validProvenance,
      modelCandidateCategory: 'food',
      uncalibratedScores: _buildTwelveScores(
        topCategory: 'food',
        topScore: 0.89,
      ),
      cpuInferenceMs: 42.5,
      httpRoundTripMs: 118.0,
      iterations: 3,
    );

    expect(service.validateRecord(record).isValid, isTrue);

    final badScoreSum = BertSyntheticSampleRecord(
      sampleId: 'syn-002',
      syntheticMemo: '合成サンプル: 電車移動',
      isSyntheticOnly: true,
      ruleCandidateCategory: 'transport',
      status: BertMeasurementStatus.verified,
      provenance: validProvenance,
      modelCandidateCategory: 'transport',
      uncalibratedScores: <String, double>{
        for (final category in BertExpenseCategories.all) category: 0.2,
      },
      cpuInferenceMs: 40.0,
    );
    expect(
      service.validateRecord(badScoreSum).errors,
      contains('uncalibrated_scores_must_sum_to_one'),
    );
  });

  test('enforces synthetic-only guard and rejects secret markers in memo', () {
    const nonSynthetic = BertSyntheticSampleRecord(
      sampleId: 'real-001',
      syntheticMemo: '実家計メモ',
      isSyntheticOnly: false,
      ruleCandidateCategory: 'food',
      status: BertMeasurementStatus.notMeasured,
      provenance: validProvenance,
    );
    expect(
      service.validateRecord(nonSynthetic).errors,
      contains('synthetic_only_required'),
    );

    const disallowedMarkerRecord = BertSyntheticSampleRecord(
      sampleId: 'syn-marker',
      syntheticMemo: 'memo containing JEV_' 'API_KEY marker',
      isSyntheticOnly: true,
      ruleCandidateCategory: 'other',
      status: BertMeasurementStatus.notMeasured,
      provenance: validProvenance,
    );
    expect(
      service.validateRecord(disallowedMarkerRecord).errors,
      contains('secret_marker_in_memo_forbidden'),
    );
  });

  test('preserves failed and not_measured states without fabricating timings',
      () {
    final parsed = service.parseSavedRecords(<Map<String, Object?>>[
      <String, Object?>{
        'sample_id': 'syn-fail',
        'synthetic_memo': '合成サンプル: タイムアウト',
        'is_synthetic_only': true,
        'rule_candidate_category': 'cafe_snack',
        'status': 'failed',
        'model_candidate_category': 'cafe_snack',
        'cpu_inference_ms': 12.3,
        'error_code': 'upstream_timeout',
        'provenance': <String, Object?>{
          'model_id': 'typed-decision-bert',
          'weight_revision': 'rev-2026-11-28',
          'pinned_sha': '0123456789abcdef0123456789abcdef01234567',
          'runtime_kind': 'cpu_inference',
        },
      },
      <String, Object?>{
        'sample_id': 'syn-pending',
        'synthetic_memo': '合成サンプル: 未計測',
        'is_synthetic_only': true,
        'rule_candidate_category': 'convenience',
        'status': 'not_measured',
        'provenance': <String, Object?>{
          'model_id': 'typed-decision-bert',
          'weight_revision': 'rev-2026-11-28',
          'pinned_sha': '0123456789abcdef0123456789abcdef01234567',
          'runtime_kind': 'cpu_inference',
        },
      },
    ]);

    expect(parsed.length, 2);
    expect(parsed[0].status, BertMeasurementStatus.failed);
    expect(parsed[0].cpuInferenceMs, isNull);
    expect(parsed[0].modelCandidateCategory, isNull);
    expect(parsed[1].status, BertMeasurementStatus.notMeasured);
    expect(parsed[1].cpuInferenceMs, isNull);

    final summary = service.summarize(parsed);
    expect(summary.verifiedCount, 0);
    expect(summary.failedCount, 1);
    expect(summary.notMeasuredCount, 1);
    expect(summary.meanCpuInferenceMs, isNull);
    expect(summary.allValid, isTrue);

    final report = service.formatReadOnlyReport(parsed);
    expect(report, contains('検証済0 / 失敗1 / 未計測1'));
    expect(report, contains('平均CPU推論: 未計測'));
    expect(report, contains('[failed] syn-fail'));
    expect(report, contains('[not_measured] syn-pending'));
  });
}
