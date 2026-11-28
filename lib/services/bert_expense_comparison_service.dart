/// 既存の支出分類（12カテゴリ）と同一の候補集合。
class BertExpenseCategories {
  const BertExpenseCategories._();

  static const List<String> all = <String>[
    'food',
    'cafe_snack',
    'convenience',
    'dining_out',
    'daily_necessities',
    'transport',
    'utilities',
    'telecom',
    'subscription_entertainment',
    'medical',
    'housing',
    'other',
  ];

  static const Map<String, String> labels = <String, String>{
    'food': '食費・食材',
    'cafe_snack': 'カフェ・間食',
    'convenience': 'コンビニ',
    'dining_out': '外食・交際費',
    'daily_necessities': '日用品・消耗品',
    'transport': '交通費',
    'utilities': '水道・光熱費',
    'telecom': '通信費',
    'subscription_entertainment': 'サブスク・娯楽',
    'medical': '医療・健康',
    'housing': '住居・家賃',
    'other': 'その他支出',
  };

  static final Set<String> _allSet = Set<String>.unmodifiable(all);

  static bool contains(String category) => _allSet.contains(category);

  static bool isValidCategorySet(Iterable<String> categories) {
    final list = categories.toList(growable: false);
    if (list.length != all.length) {
      return false;
    }
    final unique = list.toSet();
    return unique.length == all.length && unique.containsAll(_allSet);
  }
}

/// 推論実測に使用したモデルの来歴（ID・重み revision・固定 SHA）。
class BertModelProvenance {
  const BertModelProvenance({
    required this.modelId,
    required this.weightRevision,
    required this.pinnedSha,
    required this.runtimeKind,
  });

  final String modelId;
  final String weightRevision;
  final String pinnedSha;
  final String runtimeKind;

  static final RegExp _sha40Pattern = RegExp(r'^[0-9a-f]{40}$');
  static const Set<String> _disallowedRuntimes = <String>{
    'fake',
    'mock',
    'stub',
    'simulated',
  };

  List<String> validate() {
    final errors = <String>[];
    if (modelId.trim().isEmpty) {
      errors.add('model_id_required');
    }
    if (weightRevision.trim().isEmpty) {
      errors.add('weight_revision_required');
    }
    if (!_sha40Pattern.hasMatch(pinnedSha.trim())) {
      errors.add('pinned_sha_must_be_40_hex');
    }
    final normalizedRuntime = runtimeKind.trim().toLowerCase();
    if (normalizedRuntime.isEmpty) {
      errors.add('runtime_kind_required');
    } else if (_disallowedRuntimes.any(normalizedRuntime.contains)) {
      errors.add('fake_or_mock_runtime_forbidden');
    }
    return List<String>.unmodifiable(errors);
  }
}

enum BertMeasurementStatus {
  notMeasured('not_measured'),
  verified('verified'),
  failed('failed');

  const BertMeasurementStatus(this.wireName);

  final String wireName;

  static BertMeasurementStatus? fromWireName(String? raw) {
    final normalized = (raw ?? '').trim().toLowerCase();
    for (final value in BertMeasurementStatus.values) {
      if (value.wireName == normalized) {
        return value;
      }
    }
    return null;
  }
}

/// 合成サンプル 1 件分の読み取り専用比較レコード。
///
/// ルール候補とモデルの未校正スコア・CPU推論時間・HTTP往復時間を厳密に区別する。
class BertSyntheticSampleRecord {
  const BertSyntheticSampleRecord({
    required this.sampleId,
    required this.syntheticMemo,
    required this.isSyntheticOnly,
    required this.ruleCandidateCategory,
    required this.status,
    required this.provenance,
    this.modelCandidateCategory,
    this.uncalibratedScores = const <String, double>{},
    this.cpuInferenceMs,
    this.httpRoundTripMs,
    this.iterations = 1,
    this.errorCode,
    this.errorMessage,
  });

  final String sampleId;
  final String syntheticMemo;
  final bool isSyntheticOnly;
  final String ruleCandidateCategory;
  final BertMeasurementStatus status;
  final BertModelProvenance provenance;
  final String? modelCandidateCategory;
  final Map<String, double> uncalibratedScores;
  final double? cpuInferenceMs;
  final double? httpRoundTripMs;
  final int iterations;
  final String? errorCode;
  final String? errorMessage;

  double? get topUncalibratedScore {
    final candidate = modelCandidateCategory;
    if (candidate == null) {
      return null;
    }
    return uncalibratedScores[candidate];
  }
}

class BertValidationResult {
  const BertValidationResult({
    required this.errors,
  });

  final List<String> errors;

  bool get isValid => errors.isEmpty;
}

class BertComparisonSummary {
  const BertComparisonSummary({
    required this.totalCount,
    required this.verifiedCount,
    required this.failedCount,
    required this.notMeasuredCount,
    required this.ruleModelAgreementCount,
    required this.meanCpuInferenceMs,
    required this.meanHttpRoundTripMs,
    required this.allValid,
  });

  final int totalCount;
  final int verifiedCount;
  final int failedCount;
  final int notMeasuredCount;
  final int ruleModelAgreementCount;
  final double? meanCpuInferenceMs;
  final double? meanHttpRoundTripMs;
  final bool allValid;
}

/// BERT 支出分類（合成サンプル・読み取り専用）の契約検証と集計を行う純粋サービス。
///
/// 実家計データの送信・自動記帳・モック数値の捏造は一切行わない。
class BertExpenseComparisonService {
  const BertExpenseComparisonService();

  static final List<String> _forbiddenRealDataMarkers = <String>[
    <String>['supabase', 'service', 'role'].join('_'),
    <String>['jev', 'api', 'key'].join('_'),
    'bearer ',
  ];

  BertValidationResult validateRecord(BertSyntheticSampleRecord record) {
    final errors = <String>[];
    if (record.sampleId.trim().isEmpty) {
      errors.add('sample_id_required');
    }
    if (!record.isSyntheticOnly) {
      errors.add('synthetic_only_required');
    }
    final memo = record.syntheticMemo.trim();
    if (memo.isEmpty || memo.length > 500) {
      errors.add('invalid_synthetic_memo');
    }
    final lowerMemo = memo.toLowerCase();
    if (_forbiddenRealDataMarkers.any(lowerMemo.contains)) {
      errors.add('secret_marker_in_memo_forbidden');
    }
    if (!BertExpenseCategories.contains(record.ruleCandidateCategory)) {
      errors.add('invalid_rule_candidate_category');
    }
    if (record.iterations < 1) {
      errors.add('iterations_must_be_positive');
    }
    errors.addAll(record.provenance.validate());

    switch (record.status) {
      case BertMeasurementStatus.notMeasured:
        if (record.cpuInferenceMs != null) {
          errors.add('not_measured_must_not_have_cpu_ms');
        }
        if (record.modelCandidateCategory != null) {
          errors.add('not_measured_must_not_have_model_candidate');
        }
        if (record.uncalibratedScores.isNotEmpty) {
          errors.add('not_measured_must_not_have_scores');
        }
        break;
      case BertMeasurementStatus.failed:
        if ((record.errorCode ?? '').trim().isEmpty) {
          errors.add('failed_record_requires_error_code');
        }
        if (record.cpuInferenceMs != null) {
          errors.add('failed_record_must_not_report_cpu_ms');
        }
        if (record.modelCandidateCategory != null) {
          errors.add('failed_record_must_not_promote_candidate');
        }
        break;
      case BertMeasurementStatus.verified:
        if ((record.errorCode ?? '').trim().isNotEmpty) {
          errors.add('verified_record_must_not_have_error_code');
        }
        final candidate = record.modelCandidateCategory;
        if (candidate == null || !BertExpenseCategories.contains(candidate)) {
          errors.add('invalid_model_candidate_category');
        }
        if (!BertExpenseCategories.isValidCategorySet(
          record.uncalibratedScores.keys,
        )) {
          errors.add('uncalibrated_scores_must_cover_12_categories');
        } else {
          var sum = 0.0;
          var invalidValue = false;
          for (final score in record.uncalibratedScores.values) {
            if (!score.isFinite || score < 0.0 || score > 1.0) {
              invalidValue = true;
              break;
            }
            sum += score;
          }
          if (invalidValue || (sum - 1.0).abs() > 0.01) {
            errors.add('uncalibrated_scores_must_sum_to_one');
          }
        }
        final cpuMs = record.cpuInferenceMs;
        if (cpuMs == null || !cpuMs.isFinite || cpuMs < 0) {
          errors.add('verified_record_requires_finite_cpu_ms');
        }
        final httpMs = record.httpRoundTripMs;
        if (httpMs != null && (!httpMs.isFinite || httpMs < 0)) {
          errors.add('invalid_http_round_trip_ms');
        }
        break;
    }

    return BertValidationResult(errors: List<String>.unmodifiable(errors));
  }

  /// 保存済み JSON 風レコードを検証付きで読み込む。失敗・タイムアウトを成功へ変換しない。
  List<BertSyntheticSampleRecord> parseSavedRecords(
    List<Map<String, Object?>> rawRecords,
  ) {
    final parsed = <BertSyntheticSampleRecord>[];
    for (final raw in rawRecords) {
      final status = BertMeasurementStatus.fromWireName(
            raw['status']?.toString(),
          ) ??
          BertMeasurementStatus.failed;
      final provenanceMap = _asMap(raw['provenance']);
      final provenance = BertModelProvenance(
        modelId: provenanceMap['model_id']?.toString() ?? '',
        weightRevision: provenanceMap['weight_revision']?.toString() ?? '',
        pinnedSha: provenanceMap['pinned_sha']?.toString() ?? '',
        runtimeKind: provenanceMap['runtime_kind']?.toString() ?? '',
      );
      final rawScores = _asMap(raw['uncalibrated_scores']);
      final scores = <String, double>{};
      for (final entry in rawScores.entries) {
        final numVal = _asFiniteDouble(entry.value);
        if (numVal != null) {
          scores[entry.key] = numVal;
        }
      }
      final isFailed = status == BertMeasurementStatus.failed;
      final errorCode = raw['error_code']?.toString();
      parsed.add(
        BertSyntheticSampleRecord(
          sampleId: raw['sample_id']?.toString() ?? '',
          syntheticMemo: raw['synthetic_memo']?.toString() ?? '',
          isSyntheticOnly: raw['is_synthetic_only'] == true,
          ruleCandidateCategory:
              raw['rule_candidate_category']?.toString() ?? '',
          status: status,
          provenance: provenance,
          modelCandidateCategory:
              isFailed ? null : raw['model_candidate_category']?.toString(),
          uncalibratedScores: isFailed ? const <String, double>{} : scores,
          cpuInferenceMs:
              isFailed ? null : _asFiniteDouble(raw['cpu_inference_ms']),
          httpRoundTripMs: _asFiniteDouble(raw['http_round_trip_ms']),
          iterations: _asInt(raw['iterations']) ?? 1,
          errorCode: isFailed && (errorCode == null || errorCode.trim().isEmpty)
              ? 'measurement_failed'
              : errorCode,
          errorMessage: raw['error_message']?.toString(),
        ),
      );
    }
    return List<BertSyntheticSampleRecord>.unmodifiable(parsed);
  }

  BertComparisonSummary summarize(List<BertSyntheticSampleRecord> records) {
    var verifiedCount = 0;
    var failedCount = 0;
    var notMeasuredCount = 0;
    var agreementCount = 0;
    var cpuSum = 0.0;
    var httpSum = 0.0;
    var httpCount = 0;
    var allValid = true;

    for (final record in records) {
      final validation = validateRecord(record);
      if (!validation.isValid) {
        allValid = false;
      }
      switch (record.status) {
        case BertMeasurementStatus.verified:
          verifiedCount++;
          if (record.modelCandidateCategory == record.ruleCandidateCategory) {
            agreementCount++;
          }
          final cpuMs = record.cpuInferenceMs;
          if (cpuMs != null && cpuMs.isFinite) {
            cpuSum += cpuMs;
          }
          final httpMs = record.httpRoundTripMs;
          if (httpMs != null && httpMs.isFinite) {
            httpSum += httpMs;
            httpCount++;
          }
          break;
        case BertMeasurementStatus.failed:
          failedCount++;
          break;
        case BertMeasurementStatus.notMeasured:
          notMeasuredCount++;
          break;
      }
    }

    return BertComparisonSummary(
      totalCount: records.length,
      verifiedCount: verifiedCount,
      failedCount: failedCount,
      notMeasuredCount: notMeasuredCount,
      ruleModelAgreementCount: agreementCount,
      meanCpuInferenceMs: verifiedCount > 0 ? cpuSum / verifiedCount : null,
      meanHttpRoundTripMs: httpCount > 0 ? httpSum / httpCount : null,
      allValid: allValid,
    );
  }

  String formatReadOnlyReport(List<BertSyntheticSampleRecord> records) {
    final summary = summarize(records);
    final buffer = StringBuffer()
      ..writeln(
        '合成サンプル比較 (${summary.totalCount}件: '
        '検証済${summary.verifiedCount} / 失敗${summary.failedCount} / 未計測${summary.notMeasuredCount})',
      )
      ..writeln(
        '平均CPU推論: ${summary.meanCpuInferenceMs == null ? '未計測' : '${summary.meanCpuInferenceMs!.toStringAsFixed(1)}ms'} / '
        '平均HTTP: ${summary.meanHttpRoundTripMs == null ? '未計測' : '${summary.meanHttpRoundTripMs!.toStringAsFixed(1)}ms'}',
      );
    for (final record in records) {
      final ruleLabel =
          BertExpenseCategories.labels[record.ruleCandidateCategory] ??
              record.ruleCandidateCategory;
      final modelLabel = record.modelCandidateCategory == null
          ? '未取得'
          : (BertExpenseCategories.labels[record.modelCandidateCategory!] ??
              record.modelCandidateCategory!);
      final scoreText = record.topUncalibratedScore == null
          ? '未計測'
          : '未校正スコア ${(record.topUncalibratedScore! * 100).toStringAsFixed(1)}%';
      final cpuText = record.cpuInferenceMs == null
          ? 'CPU未計測'
          : 'CPU ${record.cpuInferenceMs!.toStringAsFixed(1)}ms';
      final httpText = record.httpRoundTripMs == null
          ? 'HTTP未計測'
          : 'HTTP ${record.httpRoundTripMs!.toStringAsFixed(1)}ms';
      buffer.writeln(
        '- [${record.status.wireName}] ${record.sampleId}: '
        'ルール=$ruleLabel / モデル=$modelLabel ($scoreText, $cpuText, $httpText)',
      );
    }
    return buffer.toString().trimRight();
  }

  static Map<String, Object?> _asMap(Object? value) {
    if (value is Map<Object?, Object?>) {
      return value.map((key, val) => MapEntry(key.toString(), val));
    }
    return const <String, Object?>{};
  }

  static double? _asFiniteDouble(Object? value) {
    if (value is num) {
      final d = value.toDouble();
      return d.isFinite ? d : null;
    }
    final parsed = double.tryParse(value?.toString() ?? '');
    if (parsed == null || !parsed.isFinite) {
      return null;
    }
    return parsed;
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '');
  }
}
