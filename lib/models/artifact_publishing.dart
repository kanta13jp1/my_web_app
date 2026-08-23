enum ArtifactStage {
  intake('intake', '取込'),
  automatedChecks('automated_checks', '自動検査'),
  humanReview('human_review', '人手レビュー'),
  approved('approved', '人手承認済み'),
  staged('staged', '商品ステージ'),
  ready('ready', '公開準備完了'),
  published('published', '公開済み'),
  rejected('rejected', '却下');

  const ArtifactStage(this.databaseValue, this.labelJa);

  factory ArtifactStage.fromDatabase(String? value) => values.firstWhere(
        (stage) => stage.databaseValue == value,
        orElse: () => ArtifactStage.intake,
      );

  final String databaseValue;
  final String labelJa;

  bool get canReject => this != published && this != rejected;

  List<ArtifactStage> get transitionTargets => switch (this) {
        intake => const [automatedChecks],
        automatedChecks => const [humanReview, intake],
        humanReview => const [approved, automatedChecks],
        approved => const [staged, humanReview],
        staged => const [ready, humanReview],
        ready => const [published, staged],
        published => const [ready],
        rejected => const [intake],
      };
}

enum ArtifactCheckStatus {
  pending('pending', '未確認'),
  passed('pass', '合格'),
  failed('fail', 'ブロック'),
  notApplicable('not_applicable', '対象外');

  const ArtifactCheckStatus(this.databaseValue, this.labelJa);

  factory ArtifactCheckStatus.fromDatabase(String? value) => values.firstWhere(
        (status) => status.databaseValue == value,
        orElse: () => ArtifactCheckStatus.pending,
      );

  final String databaseValue;
  final String labelJa;
}

class ArtifactCheck {
  const ArtifactCheck({
    required this.key,
    required this.kind,
    required this.status,
    required this.isHardGate,
    required this.evidenceSummary,
  });

  factory ArtifactCheck.fromRow(Map<String, dynamic> row) => ArtifactCheck(
        key: row['check_key'] as String? ?? '',
        kind: row['check_kind'] as String? ?? '',
        status: ArtifactCheckStatus.fromDatabase(row['status'] as String?),
        isHardGate: row['is_hard_gate'] as bool? ?? true,
        evidenceSummary: row['evidence_summary'] as String? ?? '',
      );

  final String key;
  final String kind;
  final ArtifactCheckStatus status;
  final bool isHardGate;
  final String evidenceSummary;

  bool get allowsNotApplicable => const {
        'third_party_license',
        'face_voice_consent',
        'chatgpt_voice_output',
      }.contains(key);

  bool get isSatisfied =>
      status == ArtifactCheckStatus.passed ||
      (allowsNotApplicable && status == ArtifactCheckStatus.notApplicable);

  bool canEditAt(ArtifactStage stage) => switch (key) {
        'secret_scan' || 'pii_scan' => stage == ArtifactStage.automatedChecks,
        'third_party_license' ||
        'face_voice_consent' ||
        'chatgpt_voice_output' ||
        'human_contribution' =>
          stage == ArtifactStage.humanReview,
        'price_match' ||
        'private_object' ||
        'content_integrity' =>
          stage == ArtifactStage.staged,
        _ => false,
      };

  String get labelJa => switch (key) {
        'secret_scan' => '秘密情報',
        'pii_scan' => '個人情報',
        'third_party_license' => '第三者ライセンス',
        'face_voice_consent' => '顔・声の同意',
        'chatgpt_voice_output' => 'Voice Output 制限',
        'human_contribution' => '人間の寄与',
        'price_match' => '価格一致',
        'private_object' => '非公開ファイル',
        'content_integrity' => 'ハッシュ整合',
        _ => key,
      };
}

class ArtifactCandidate {
  const ArtifactCandidate({
    required this.id,
    required this.title,
    required this.sha256,
    required this.mimeType,
    required this.fileSizeBytes,
    required this.kind,
    required this.stage,
    required this.checks,
    required this.sourceTools,
    required this.productId,
    required this.productName,
    required this.productActive,
    required this.intendedPriceJpy,
    required this.proposedStorageBucket,
    required this.proposedStoragePath,
    required this.humanContributionSummary,
    required this.rejectionReason,
    required this.updatedAt,
  });

  factory ArtifactCandidate.fromRow(Map<String, dynamic> row) {
    final checkRows = row['artifact_checks'] as List<dynamic>? ?? const [];
    final provenanceRows =
        row['artifact_provenance'] as List<dynamic>? ?? const [];
    final rawProduct = row['shop_products'];
    final product = rawProduct is Map
        ? Map<String, dynamic>.from(rawProduct)
        : const <String, dynamic>{};
    final checks = checkRows
        .map(
          (raw) => ArtifactCheck.fromRow(Map<String, dynamic>.from(raw as Map)),
        )
        .toList(growable: false)
      ..sort((left, right) => left.key.compareTo(right.key));
    final tools = provenanceRows
        .map((raw) => (raw as Map)['source_tool']?.toString() ?? '')
        .where((tool) => tool.isNotEmpty)
        .toSet()
        .toList(growable: false)
      ..sort();
    return ArtifactCandidate(
      id: row['id'] as String? ?? '',
      title: row['title'] as String? ?? '',
      sha256: row['artifact_sha256'] as String? ?? '',
      mimeType: row['mime_type'] as String? ?? '',
      fileSizeBytes: (row['file_size_bytes'] as num?)?.toInt() ?? 0,
      kind: row['artifact_kind'] as String? ?? '',
      stage: ArtifactStage.fromDatabase(row['stage'] as String?),
      checks: checks,
      sourceTools: tools,
      productId: row['product_id'] as String?,
      productName: product['name_ja'] as String?,
      productActive: product['is_active'] as bool? ?? false,
      intendedPriceJpy: (row['intended_price_jpy'] as num?)?.toInt(),
      proposedStorageBucket: row['proposed_storage_bucket'] as String?,
      proposedStoragePath: row['proposed_storage_path'] as String?,
      humanContributionSummary:
          row['human_contribution_summary'] as String? ?? '',
      rejectionReason: row['rejection_reason'] as String? ?? '',
      updatedAt: DateTime.tryParse(row['updated_at'] as String? ?? ''),
    );
  }

  final String id;
  final String title;
  final String sha256;
  final String mimeType;
  final int fileSizeBytes;
  final String kind;
  final ArtifactStage stage;
  final List<ArtifactCheck> checks;
  final List<String> sourceTools;
  final String? productId;
  final String? productName;
  final bool productActive;
  final int? intendedPriceJpy;
  final String? proposedStorageBucket;
  final String? proposedStoragePath;
  final String humanContributionSummary;
  final String rejectionReason;
  final DateTime? updatedAt;

  int get satisfiedHardGateCount =>
      checks.where((check) => check.isHardGate && check.isSatisfied).length;

  int get hardGateCount => checks.where((check) => check.isHardGate).length;

  bool get allHardGatesSatisfied =>
      hardGateCount == 9 && satisfiedHardGateCount == hardGateCount;
}
