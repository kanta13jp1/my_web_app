/// 4レーン比較におけるクリア区分（モデル単体 vs 探索補助あり）。
enum JevMarioClearMode {
  modelOnly('model_only'),
  searchAssisted('search_assisted');

  const JevMarioClearMode(this.wireName);

  final String wireName;

  static JevMarioClearMode? fromWireName(String? raw) {
    final normalized = (raw ?? '').trim().toLowerCase();
    for (final mode in JevMarioClearMode.values) {
      if (mode.wireName == normalized) {
        return mode;
      }
    }
    return null;
  }
}

/// 4レーン比較のレーン定義。
enum JevMarioComparisonLane {
  lane1Baseline('lane_1_baseline'),
  lane2Prediction('lane_2_prediction'),
  lane3CompactLossless('lane_3_compact_lossless'),
  lane4SearchAssisted('lane_4_search_assisted');

  const JevMarioComparisonLane(this.wireName);

  final String wireName;

  static JevMarioComparisonLane? fromWireName(String? raw) {
    final normalized = (raw ?? '').trim().toLowerCase();
    for (final lane in JevMarioComparisonLane.values) {
      if (lane.wireName == normalized) {
        return lane;
      }
    }
    return null;
  }
}

/// 可逆圧縮された地形入力と元入力の長さ比較結果。
class CompactTerrainEncodingResult {
  const CompactTerrainEncodingResult({
    required this.encoded,
    required this.rawLength,
    required this.encodedLength,
    required this.isInvertible,
  });

  final String encoded;
  final int rawLength;
  final int encodedLength;
  final bool isInvertible;

  double get compressionRatio =>
      rawLength <= 0 ? 1.0 : encodedLength / rawLength;
}

/// 4レーン比較 1 実行分の不変契約レコード。
class JevMarioLaneRunRecord {
  const JevMarioLaneRunRecord({
    required this.runId,
    required this.lane,
    required this.clearMode,
    required this.cleared,
    required this.assistanceDisclosed,
    this.assistanceDescription = '',
    required this.terrainRows,
    required this.compactTerrainEncoded,
    required this.rawModelOutput,
    required this.rawLogLines,
    required this.truncationCount,
    required this.frozenBenchmarkSha,
    required this.expectedFrozenBenchmarkSha,
    required this.elapsedMs,
  });

  final String runId;
  final JevMarioComparisonLane lane;
  final JevMarioClearMode clearMode;
  final bool cleared;
  final bool assistanceDisclosed;
  final String assistanceDescription;
  final List<String> terrainRows;
  final String compactTerrainEncoded;
  final String rawModelOutput;
  final List<String> rawLogLines;
  final int truncationCount;
  final String frozenBenchmarkSha;
  final String expectedFrozenBenchmarkSha;
  final double elapsedMs;
}

class JevMarioValidationResult {
  const JevMarioValidationResult({required this.errors});

  final List<String> errors;

  bool get isValid => errors.isEmpty;
}

class JevMarioFourLaneSummary {
  const JevMarioFourLaneSummary({
    required this.totalRuns,
    required this.distinctLanesCount,
    required this.modelOnlyClearCount,
    required this.searchAssistedClearCount,
    required this.totalTruncationCount,
    required this.allFrozenBenchmarkUnchanged,
    required this.allValid,
  });

  final int totalRuns;
  final int distinctLanesCount;
  final int modelOnlyClearCount;
  final int searchAssistedClearCount;
  final int totalTruncationCount;
  final bool allFrozenBenchmarkUnchanged;
  final bool allValid;
}

/// Issue #5506 Part 1: 4レーン比較・可逆地形入力・クリア区分・実ログ/打ち切り数保全・
/// 凍結ベンチマークゲーム不変性ガードを提供する純粋 Dart サービス。
class JevMarioCompactService {
  const JevMarioCompactService();

  static final RegExp _sha40Pattern = RegExp(r'^[0-9a-f]{40}$');
  static final RegExp _terrainCellPattern = RegExp(r'^[A-Za-z0-9_.?#\-]+$');
  static final RegExp _rleRunPattern = RegExp(r'(\d*)([A-Za-z0-9_.?#\-])');

  /// 地形行（ASCIIグリッド）を短い可逆 RLE 形式（行区切り `;`）へエンコードする。
  /// 数字を含まない一般地形トークンに加え、明示長を保持するため完全可逆。
  String encodeLosslessTerrain(List<String> rows) {
    if (rows.isEmpty) {
      throw const FormatException('terrain_rows_empty');
    }
    final expectedWidth = rows.first.length;
    if (expectedWidth == 0) {
      throw const FormatException('terrain_row_empty');
    }
    final encodedRows = <String>[];
    for (final row in rows) {
      if (row.length != expectedWidth) {
        throw const FormatException('terrain_rows_width_mismatch');
      }
      if (!_terrainCellPattern.hasMatch(row)) {
        throw const FormatException('terrain_row_invalid_character');
      }
      final buffer = StringBuffer();
      var i = 0;
      while (i < row.length) {
        final ch = row[i];
        var count = 1;
        while (i + count < row.length && row[i + count] == ch) {
          count++;
        }
        // 数字文字そのものが地形トークンに来ない前提でなく、
        // 数字の場合は必ず `1<digit>` と明示して曖昧さを排除する。
        final isDigit = ch.codeUnitAt(0) >= 48 && ch.codeUnitAt(0) <= 57;
        if (count > 1 || isDigit) {
          buffer.write(count);
        }
        buffer.write(ch);
        i += count;
      }
      encodedRows.add(buffer.toString());
    }
    return encodedRows.join(';');
  }

  /// `encodeLosslessTerrain` で生成した文字列を元の地形行へ完全復元する。
  List<String> decodeLosslessTerrain(String encoded) {
    if (encoded.trim().isEmpty) {
      throw const FormatException('encoded_terrain_empty');
    }
    final rowParts = encoded.split(';');
    final decoded = <String>[];
    int? expectedWidth;

    for (final part in rowParts) {
      if (part.isEmpty) {
        throw const FormatException('encoded_row_empty');
      }
      final buffer = StringBuffer();
      var cursor = 0;
      for (final match in _rleRunPattern.allMatches(part)) {
        if (match.start != cursor) {
          throw const FormatException('encoded_row_invalid_token');
        }
        cursor = match.end;
        final countRaw = match.group(1) ?? '';
        final ch = match.group(2) ?? '';
        final count = countRaw.isEmpty ? 1 : int.parse(countRaw);
        if (count < 1 || count > 10000) {
          throw const FormatException('encoded_run_count_out_of_range');
        }
        buffer.write(ch * count);
      }
      if (cursor != part.length) {
        throw const FormatException('encoded_row_trailing_characters');
      }
      final row = buffer.toString();
      expectedWidth ??= row.length;
      if (row.length != expectedWidth) {
        throw const FormatException('decoded_rows_width_mismatch');
      }
      decoded.add(row);
    }

    return List<String>.unmodifiable(decoded);
  }

  /// 可逆性（encode -> decode == 元入力）と圧縮長を検証する。
  CompactTerrainEncodingResult encodeAndVerifyRoundTrip(List<String> rows) {
    final encoded = encodeLosslessTerrain(rows);
    final decoded = decodeLosslessTerrain(encoded);
    var invertible = decoded.length == rows.length;
    if (invertible) {
      for (var i = 0; i < rows.length; i++) {
        if (decoded[i] != rows[i]) {
          invertible = false;
          break;
        }
      }
    }
    final rawLength = rows.join('\n').length;
    return CompactTerrainEncodingResult(
      encoded: encoded,
      rawLength: rawLength,
      encodedLength: encoded.length,
      isInvertible: invertible,
    );
  }

  /// 凍結ベンチマークゲームの SHA が期待値と一致するか検証する。
  bool isFrozenBenchmarkGameUnchanged({
    required String actualSha,
    required String expectedSha,
  }) {
    final normalizedActual = actualSha.trim().toLowerCase();
    final normalizedExpected = expectedSha.trim().toLowerCase();
    return _sha40Pattern.hasMatch(normalizedActual) &&
        _sha40Pattern.hasMatch(normalizedExpected) &&
        normalizedActual == normalizedExpected;
  }

  /// 1 レーン分の実行記録を契約検証する。
  JevMarioValidationResult validateRun(JevMarioLaneRunRecord record) {
    final errors = <String>[];
    if (record.runId.trim().isEmpty) {
      errors.add('run_id_required');
    }
    if (!record.elapsedMs.isFinite || record.elapsedMs < 0) {
      errors.add('invalid_elapsed_ms');
    }
    if (record.truncationCount < 0) {
      errors.add('truncation_count_negative');
    }
    if (record.rawModelOutput.trim().isEmpty) {
      errors.add('raw_model_output_required');
    }
    if (record.rawLogLines.isEmpty) {
      errors.add('raw_log_lines_required');
    }

    // クリア区分と補助開示の厳格チェック
    if (record.clearMode == JevMarioClearMode.searchAssisted) {
      if (!record.assistanceDisclosed) {
        errors.add('search_assisted_requires_disclosed_assistance');
      }
      if (record.assistanceDescription.trim().isEmpty) {
        errors.add('search_assisted_requires_assistance_description');
      }
    } else if (record.lane == JevMarioComparisonLane.lane4SearchAssisted) {
      errors.add('lane4_must_use_search_assisted_mode');
    }

    // 凍結ベンチマークゲームの不変性チェック
    if (!isFrozenBenchmarkGameUnchanged(
      actualSha: record.frozenBenchmarkSha,
      expectedSha: record.expectedFrozenBenchmarkSha,
    )) {
      errors.add('frozen_benchmark_game_modified_or_unpinned');
    }

    // 可逆地形入力のラウンドトリップチェック
    try {
      final roundTrip = encodeAndVerifyRoundTrip(record.terrainRows);
      if (!roundTrip.isInvertible) {
        errors.add('terrain_round_trip_not_invertible');
      } else {
        final decodedFromRecord =
            decodeLosslessTerrain(record.compactTerrainEncoded);
        var matchesRecord =
            decodedFromRecord.length == record.terrainRows.length;
        if (matchesRecord) {
          for (var i = 0; i < record.terrainRows.length; i++) {
            if (decodedFromRecord[i] != record.terrainRows[i]) {
              matchesRecord = false;
              break;
            }
          }
        }
        if (!matchesRecord) {
          errors.add('compact_terrain_mismatch_with_raw_rows');
        }
      }
    } on FormatException catch (e) {
      errors.add('terrain_encoding_error:${e.message}');
    }

    return JevMarioValidationResult(errors: List<String>.unmodifiable(errors));
  }

  /// 4レーン比較全体を集計する（modelOnly クリアと searchAssisted クリアを分離集計）。
  JevMarioFourLaneSummary summarizeFourLanes(
    List<JevMarioLaneRunRecord> runs,
  ) {
    final lanes = <JevMarioComparisonLane>{};
    var modelOnlyClears = 0;
    var searchAssistedClears = 0;
    var totalTruncations = 0;
    var allFrozenUnchanged = true;
    var allValid = runs.length >= 4;

    for (final run in runs) {
      lanes.add(run.lane);
      final validation = validateRun(run);
      if (!validation.isValid) {
        allValid = false;
      }
      if (!isFrozenBenchmarkGameUnchanged(
        actualSha: run.frozenBenchmarkSha,
        expectedSha: run.expectedFrozenBenchmarkSha,
      )) {
        allFrozenUnchanged = false;
      }
      if (run.cleared) {
        switch (run.clearMode) {
          case JevMarioClearMode.modelOnly:
            modelOnlyClears++;
            break;
          case JevMarioClearMode.searchAssisted:
            searchAssistedClears++;
            break;
        }
      }
      if (run.truncationCount > 0) {
        totalTruncations += run.truncationCount;
      }
    }

    if (lanes.length != JevMarioComparisonLane.values.length) {
      allValid = false;
    }

    return JevMarioFourLaneSummary(
      totalRuns: runs.length,
      distinctLanesCount: lanes.length,
      modelOnlyClearCount: modelOnlyClears,
      searchAssistedClearCount: searchAssistedClears,
      totalTruncationCount: totalTruncations,
      allFrozenBenchmarkUnchanged: allFrozenUnchanged,
      allValid: allValid,
    );
  }
}
