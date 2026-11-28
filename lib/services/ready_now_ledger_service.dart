/// 依存関係の状態。
enum DependencyStatus {
  ready('ready'),
  blockedExternal('blocked_external'),
  unknown('unknown');

  const DependencyStatus(this.wireName);

  final String wireName;
}

/// 証跡に基づく信頼度。
enum EvidenceConfidence {
  high('high'),
  medium('medium'),
  low('low'),
  unknown('unknown');

  const EvidenceConfidence(this.wireName);

  final String wireName;
}

/// 計算によって導出される実行準備状態。
enum ReadinessState {
  readyNow('ready_now', sortOrder: 0),
  blockedExternal('blocked_external', sortOrder: 1),
  missingProofUnknown('missing_proof_unknown', sortOrder: 2),
  completed('completed', sortOrder: 3);

  const ReadinessState(this.wireName, {required this.sortOrder});

  final String wireName;
  final int sortOrder;
}

/// 収益・初回ユーザー獲得のクリティカルパス段階（厳格な順序付き）。
enum CriticalPathStage {
  identityAndPayoutReadiness('identity_and_payout_readiness', order: 0),
  namedProspect('named_prospect', order: 1),
  attributableVisit('attributable_visit', order: 2),
  checkout('checkout', order: 3),
  verifiedPayout('verified_payout', order: 4);

  const CriticalPathStage(this.wireName, {required this.order});

  final String wireName;
  final int order;
}

/// Ready-Now 台帳の 1 エントリ。
class ReadyNowLedgerEntry {
  const ReadyNowLedgerEntry({
    required this.entryId,
    required this.title,
    required this.priorityRank,
    required this.progressPercent,
    required this.stage,
    required this.dependencyStatus,
    this.blockerOwner,
    this.nextExternalAction,
    this.completedEvidence = const <String>[],
    this.remainingAcceptanceItems = const <String>[],
    this.lastEvidenceTimestamp,
    this.confidence = EvidenceConfidence.unknown,
    this.isCompleted = false,
  });

  final String entryId;
  final String title;
  final int priorityRank;
  final int progressPercent;
  final CriticalPathStage stage;
  final DependencyStatus dependencyStatus;
  final String? blockerOwner;
  final String? nextExternalAction;
  final List<String> completedEvidence;
  final List<String> remainingAcceptanceItems;
  final DateTime? lastEvidenceTimestamp;
  final EvidenceConfidence confidence;
  final bool isCompleted;

  bool get hasValidEvidence =>
      completedEvidence.any((item) => item.trim().isNotEmpty) &&
      lastEvidenceTimestamp != null;

  /// 証跡と依存関係から導出される実行準備状態。
  /// 進捗 90% 以上でも完了証跡または確認日時が欠落している場合は
  /// `missingProofUnknown` として扱い、90% をそのまま引き継がない。
  ReadinessState get readinessState {
    if (progressPercent >= 90 && !hasValidEvidence) {
      return ReadinessState.missingProofUnknown;
    }
    if (isCompleted && hasValidEvidence && remainingAcceptanceItems.isEmpty) {
      return ReadinessState.completed;
    }
    if (dependencyStatus == DependencyStatus.blockedExternal) {
      return ReadinessState.blockedExternal;
    }
    if (dependencyStatus == DependencyStatus.unknown || !hasValidEvidence) {
      return ReadinessState.missingProofUnknown;
    }
    return ReadinessState.readyNow;
  }

  /// 証跡不足で `missingProofUnknown` に降格された場合、未検証の進捗率を返さない。
  int? get verifiedProgressPercent {
    if (readinessState == ReadinessState.missingProofUnknown) {
      return null;
    }
    return progressPercent;
  }
}

class ReadyNowValidationResult {
  const ReadyNowValidationResult({required this.errors});

  final List<String> errors;

  bool get isValid => errors.isEmpty;
}

class ReadyNowLedgerSummary {
  const ReadyNowLedgerSummary({
    required this.totalCount,
    required this.readyNowCount,
    required this.blockedExternalCount,
    required this.missingProofUnknownCount,
    required this.completedCount,
    required this.allValid,
  });

  final int totalCount;
  final int readyNowCount;
  final int blockedExternalCount;
  final int missingProofUnknownCount;
  final int completedCount;
  final bool allValid;
}

/// Issue #5311 Part 1: 決定論的 Ready-Now 台帳の契約検証・
/// クリティカルパス遷移ガード・決定的ソートを提供する純粋 Dart サービス。
class ReadyNowLedgerService {
  const ReadyNowLedgerService();

  /// 単一エントリの契約検証。
  ReadyNowValidationResult validateEntry(ReadyNowLedgerEntry entry) {
    final errors = <String>[];
    if (entry.entryId.trim().isEmpty) {
      errors.add('entry_id_required');
    }
    if (entry.title.trim().isEmpty) {
      errors.add('title_required');
    }
    if (entry.progressPercent < 0 || entry.progressPercent > 100) {
      errors.add('progress_percent_out_of_range');
    }
    if (entry.progressPercent >= 90) {
      if (!entry.completedEvidence.any((item) => item.trim().isNotEmpty)) {
        errors.add('progress_90_plus_requires_completed_evidence');
      }
      if (entry.lastEvidenceTimestamp == null) {
        errors.add('progress_90_plus_requires_evidence_timestamp');
      }
    }
    if (entry.dependencyStatus == DependencyStatus.blockedExternal) {
      if ((entry.blockerOwner ?? '').trim().isEmpty) {
        errors.add('blocked_external_requires_blocker_owner');
      }
      if ((entry.nextExternalAction ?? '').trim().isEmpty) {
        errors.add('blocked_external_requires_next_external_action');
      }
    }
    if (entry.isCompleted && entry.remainingAcceptanceItems.isNotEmpty) {
      errors.add('completed_entry_must_have_no_remaining_acceptance_items');
    }
    return ReadyNowValidationResult(errors: List<String>.unmodifiable(errors));
  }

  /// 証跡ゲート付きのクリティカルパス遷移チェック。
  /// 段階を飛ばす遷移や証跡なしの前進を拒否する。
  ReadyNowValidationResult validateStageTransition({
    required CriticalPathStage fromStage,
    required CriticalPathStage toStage,
    required List<String> completedEvidence,
    required DateTime? lastEvidenceTimestamp,
  }) {
    final errors = <String>[];
    final delta = toStage.order - fromStage.order;
    if (delta > 1) {
      errors.add('cannot_skip_critical_path_stage');
    }
    if (delta > 0) {
      if (!completedEvidence.any((item) => item.trim().isNotEmpty)) {
        errors.add('stage_advance_requires_completed_evidence');
      }
      if (lastEvidenceTimestamp == null) {
        errors.add('stage_advance_requires_evidence_timestamp');
      }
    }
    return ReadyNowValidationResult(errors: List<String>.unmodifiable(errors));
  }

  /// Ready-Now 項目を先頭に配置し、クリティカルパス順・優先度順・ID順で決定論的に整列する。
  List<ReadyNowLedgerEntry> sortReadyNowFirst(
    List<ReadyNowLedgerEntry> entries,
  ) {
    final sorted = List<ReadyNowLedgerEntry>.of(entries);
    sorted.sort((a, b) {
      final stateCmp =
          a.readinessState.sortOrder.compareTo(b.readinessState.sortOrder);
      if (stateCmp != 0) {
        return stateCmp;
      }
      final stageCmp = a.stage.order.compareTo(b.stage.order);
      if (stageCmp != 0) {
        return stageCmp;
      }
      final priorityCmp = a.priorityRank.compareTo(b.priorityRank);
      if (priorityCmp != 0) {
        return priorityCmp;
      }
      return a.entryId.compareTo(b.entryId);
    });
    return List<ReadyNowLedgerEntry>.unmodifiable(sorted);
  }

  ReadyNowLedgerSummary summarize(List<ReadyNowLedgerEntry> entries) {
    var readyNow = 0;
    var blockedExternal = 0;
    var missingProofUnknown = 0;
    var completed = 0;
    var allValid = true;

    for (final entry in entries) {
      if (!validateEntry(entry).isValid) {
        allValid = false;
      }
      switch (entry.readinessState) {
        case ReadinessState.readyNow:
          readyNow++;
          break;
        case ReadinessState.blockedExternal:
          blockedExternal++;
          break;
        case ReadinessState.missingProofUnknown:
          missingProofUnknown++;
          break;
        case ReadinessState.completed:
          completed++;
          break;
      }
    }

    return ReadyNowLedgerSummary(
      totalCount: entries.length,
      readyNowCount: readyNow,
      blockedExternalCount: blockedExternal,
      missingProofUnknownCount: missingProofUnknown,
      completedCount: completed,
      allValid: allValid,
    );
  }
}
