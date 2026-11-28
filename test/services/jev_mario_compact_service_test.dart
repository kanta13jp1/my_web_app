import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/jev_mario_compact_service.dart';

void main() {
  const service = JevMarioCompactService();
  const frozenSha = '0123456789abcdef0123456789abcdef01234567';
  const sampleTerrain = <String>[
    '................',
    '.....???........',
    '..BB.....PP.....',
    '#########PP#####',
  ];

  test('encodes and decodes terrain losslessly with shorter representation',
      () {
    final result = service.encodeAndVerifyRoundTrip(sampleTerrain);
    expect(result.isInvertible, isTrue);
    expect(result.encodedLength, lessThan(result.rawLength));
    expect(
      service.decodeLosslessTerrain(result.encoded),
      equals(sampleTerrain),
    );
  });

  test('handles digit tokens in terrain without ambiguity on round-trip', () {
    const digitTerrain = <String>[
      '..1122..',
      '##0000##',
    ];
    final result = service.encodeAndVerifyRoundTrip(digitTerrain);
    expect(result.isInvertible, isTrue);
    expect(
      service.decodeLosslessTerrain(result.encoded),
      equals(digitTerrain),
    );
  });

  test('rejects invalid terrain encodings and mismatched round-trips', () {
    expect(
      () => service.decodeLosslessTerrain(''),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => service.decodeLosslessTerrain('4.;3.'),
      throwsA(isA<FormatException>()),
    );
  });

  test(
      'distinguishes modelOnly vs searchAssisted clears and requires disclosure',
      () {
    final encoded = service.encodeLosslessTerrain(sampleTerrain);

    final undisclosedSearch = JevMarioLaneRunRecord(
      runId: 'run-4',
      lane: JevMarioComparisonLane.lane4SearchAssisted,
      clearMode: JevMarioClearMode.searchAssisted,
      cleared: true,
      assistanceDisclosed: false,
      assistanceDescription: '',
      terrainRows: sampleTerrain,
      compactTerrainEncoded: encoded,
      rawModelOutput: '{"controller":"right_jump"}',
      rawLogLines: const <String>['[lane4] step=1 right_jump'],
      truncationCount: 0,
      frozenBenchmarkSha: frozenSha,
      expectedFrozenBenchmarkSha: frozenSha,
      elapsedMs: 120.5,
    );
    expect(
      service.validateRun(undisclosedSearch).errors,
      containsAll(<String>[
        'search_assisted_requires_disclosed_assistance',
        'search_assisted_requires_assistance_description',
      ]),
    );
  });

  test(
      'preserves truncation counts, raw logs, and enforces frozen benchmark SHA',
      () {
    final encoded = service.encodeLosslessTerrain(sampleTerrain);

    final modifiedBenchmark = JevMarioLaneRunRecord(
      runId: 'run-bad-sha',
      lane: JevMarioComparisonLane.lane1Baseline,
      clearMode: JevMarioClearMode.modelOnly,
      cleared: false,
      assistanceDisclosed: false,
      terrainRows: sampleTerrain,
      compactTerrainEncoded: encoded,
      rawModelOutput: '{"controller":"right"}',
      rawLogLines: const <String>['[lane1] step=1 right'],
      truncationCount: 2,
      frozenBenchmarkSha: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      expectedFrozenBenchmarkSha: frozenSha,
      elapsedMs: 95.0,
    );
    expect(
      service.validateRun(modifiedBenchmark).errors,
      contains('frozen_benchmark_game_modified_or_unpinned'),
    );

    final fourRuns = <JevMarioLaneRunRecord>[
      JevMarioLaneRunRecord(
        runId: 'run-1',
        lane: JevMarioComparisonLane.lane1Baseline,
        clearMode: JevMarioClearMode.modelOnly,
        cleared: false,
        assistanceDisclosed: false,
        terrainRows: sampleTerrain,
        compactTerrainEncoded: encoded,
        rawModelOutput: '{"controller":"right"}',
        rawLogLines: const <String>['[lane1] raw output'],
        truncationCount: 1,
        frozenBenchmarkSha: frozenSha,
        expectedFrozenBenchmarkSha: frozenSha,
        elapsedMs: 140.0,
      ),
      JevMarioLaneRunRecord(
        runId: 'run-2',
        lane: JevMarioComparisonLane.lane2Prediction,
        clearMode: JevMarioClearMode.modelOnly,
        cleared: false,
        assistanceDisclosed: false,
        terrainRows: sampleTerrain,
        compactTerrainEncoded: encoded,
        rawModelOutput: '{"controller":"right_run"}',
        rawLogLines: const <String>['[lane2] raw output'],
        truncationCount: 0,
        frozenBenchmarkSha: frozenSha,
        expectedFrozenBenchmarkSha: frozenSha,
        elapsedMs: 132.0,
      ),
      JevMarioLaneRunRecord(
        runId: 'run-3',
        lane: JevMarioComparisonLane.lane3CompactLossless,
        clearMode: JevMarioClearMode.modelOnly,
        cleared: true,
        assistanceDisclosed: false,
        terrainRows: sampleTerrain,
        compactTerrainEncoded: encoded,
        rawModelOutput: '{"controller":"right_jump"}',
        rawLogLines: const <String>['[lane3] raw output'],
        truncationCount: 2,
        frozenBenchmarkSha: frozenSha,
        expectedFrozenBenchmarkSha: frozenSha,
        elapsedMs: 110.0,
      ),
      JevMarioLaneRunRecord(
        runId: 'run-4',
        lane: JevMarioComparisonLane.lane4SearchAssisted,
        clearMode: JevMarioClearMode.searchAssisted,
        cleared: true,
        assistanceDisclosed: true,
        assistanceDescription: 'BFS lookahead assistance disclosed',
        terrainRows: sampleTerrain,
        compactTerrainEncoded: encoded,
        rawModelOutput: '{"controller":"right_jump"}',
        rawLogLines: const <String>['[lane4] raw output'],
        truncationCount: 0,
        frozenBenchmarkSha: frozenSha,
        expectedFrozenBenchmarkSha: frozenSha,
        elapsedMs: 185.0,
      ),
    ];

    final summary = service.summarizeFourLanes(fourRuns);
    expect(summary.totalRuns, 4);
    expect(summary.distinctLanesCount, 4);
    expect(summary.modelOnlyClearCount, 1);
    expect(summary.searchAssistedClearCount, 1);
    expect(summary.totalTruncationCount, 3);
    expect(summary.allFrozenBenchmarkUnchanged, isTrue);
    expect(summary.allValid, isTrue);
  });
}
