enum GateDisposition {
  published('published', '公開承認済み'),
  revisionQueue('revision_queue', '修正キュー隔離'),
  discarded('discarded', '自動破棄');

  final String wireKey;
  final String labelJa;

  const GateDisposition(this.wireKey, this.labelJa);
}

enum GateStage {
  sentinel('sentinel'),
  warden('warden');

  final String wireKey;

  const GateStage(this.wireKey);
}

enum GateSeverity {
  info('info'),
  warning('warning'),
  critical('critical');

  final String wireKey;

  const GateSeverity(this.wireKey);
}

class GateFinding {
  final GateStage stage;
  final String code;
  final GateSeverity severity;
  final String message;

  const GateFinding({
    required this.stage,
    required this.code,
    required this.severity,
    required this.message,
  });
}

class RevisionQueueItem {
  final String id;
  final String candidateId;
  final String sourceAction;
  final GateStage failedStage;
  final GateDisposition disposition;
  final String contentExcerpt;
  final List<GateFinding> findings;
  final DateTime createdAt;
  final bool resolved;

  const RevisionQueueItem({
    required this.id,
    required this.candidateId,
    required this.sourceAction,
    required this.failedStage,
    required this.disposition,
    required this.contentExcerpt,
    required this.findings,
    required this.createdAt,
    this.resolved = false,
  });

  RevisionQueueItem copyWith({bool? resolved}) {
    return RevisionQueueItem(
      id: id,
      candidateId: candidateId,
      sourceAction: sourceAction,
      failedStage: failedStage,
      disposition: disposition,
      contentExcerpt: contentExcerpt,
      findings: findings,
      createdAt: createdAt,
      resolved: resolved ?? this.resolved,
    );
  }
}

class GateEvaluationResult {
  final GateDisposition disposition;
  final bool publishable;
  final bool sentinelPassed;
  final bool wardenPassed;
  final double qualityScore;
  final List<GateFinding> findings;
  final String? queuedItemId;

  const GateEvaluationResult({
    required this.disposition,
    required this.publishable,
    required this.sentinelPassed,
    required this.wardenPassed,
    required this.qualityScore,
    required this.findings,
    this.queuedItemId,
  });
}

/// Two-stage AI output quality gate (Sentinel + Warden) with frontend
/// revision queue inspection and resolution.
class SentinelWardenGateService {
  static final RegExp _emailRe = RegExp(
    r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}',
  );
  static final RegExp _phoneRe = RegExp(
    r'(?:\+?\d{1,3}[-.\s]?)?(?:\(?\d{2,4}\)?[-.\s]?){2}\d{3,4}',
  );
  static final RegExp _secretRe =
      RegExp(r'(?:sk|ghp|AIza)[_-]?[A-Za-z0-9]{16,}');
  static final RegExp _hallucinationRe = RegExp(
    r'(\bTODO\b|\bFIXME\b|lorem ipsum|\[citation needed\]|架空の数値)',
    caseSensitive: false,
  );
  static final RegExp _templatePlaceholderRe = RegExp(
    r'\{\{[^}]+\}\}|<placeholder>',
    caseSensitive: false,
  );

  final Map<String, RevisionQueueItem> _revisionQueue =
      <String, RevisionQueueItem>{};
  final DateTime Function() _now;

  SentinelWardenGateService({DateTime Function()? now})
      : _now = now ?? DateTime.now;

  List<RevisionQueueItem> listRevisionQueue({bool includeResolved = false}) {
    return _revisionQueue.values
        .where((item) => includeResolved || !item.resolved)
        .toList(growable: false);
  }

  bool resolveRevisionItem(String itemId) {
    final existing = _revisionQueue[itemId];
    if (existing == null) return false;
    _revisionQueue[itemId] = existing.copyWith(resolved: true);
    return true;
  }

  GateEvaluationResult evaluateOutput({
    required String id,
    required String sourceAction,
    required String content,
    Map<String, Object?> structuredData = const <String, Object?>{},
    List<String> requiredKeys = const <String>[],
    int minContentLength = 10,
    int maxContentLength = 20000,
    double minQualityScore = 0.7,
  }) {
    final trimmed = content.trim();
    final sentinelFindings = _runSentinel(
      trimmed: trimmed,
      structuredData: structuredData,
      requiredKeys: requiredKeys,
      minContentLength: minContentLength,
    );

    if (sentinelFindings.isNotEmpty) {
      final critical =
          sentinelFindings.any((f) => f.severity == GateSeverity.critical);
      final disposition =
          critical ? GateDisposition.discarded : GateDisposition.revisionQueue;
      final queuedId = disposition == GateDisposition.revisionQueue
          ? _enqueue(
              candidateId: id,
              sourceAction: sourceAction,
              failedStage: GateStage.sentinel,
              disposition: disposition,
              trimmed: trimmed,
              findings: sentinelFindings,
            )
          : null;
      return GateEvaluationResult(
        disposition: disposition,
        publishable: false,
        sentinelPassed: false,
        wardenPassed: false,
        qualityScore: 0.0,
        findings: sentinelFindings,
        queuedItemId: queuedId,
      );
    }

    final wardenFindings = <GateFinding>[];
    var score = 1.0;
    if (trimmed.length > maxContentLength) {
      score -= 0.35;
      wardenFindings.add(
        GateFinding(
          stage: GateStage.warden,
          code: 'exceeds_max_length',
          severity: GateSeverity.warning,
          message: 'Output exceeds $maxContentLength characters.',
        ),
      );
    }

    final fenceCount = '```'.allMatches(trimmed).length;
    if (fenceCount.isOdd) {
      score -= 0.4;
      wardenFindings.add(
        const GateFinding(
          stage: GateStage.warden,
          code: 'unbalanced_code_fence',
          severity: GateSeverity.warning,
          message: 'Markdown code fence count is odd.',
        ),
      );
    }

    if (_templatePlaceholderRe.hasMatch(trimmed)) {
      score -= 0.4;
      wardenFindings.add(
        const GateFinding(
          stage: GateStage.warden,
          code: 'unresolved_template_placeholder',
          severity: GateSeverity.warning,
          message: 'Unresolved template placeholder remains in output.',
        ),
      );
    }

    final clampedScore = score.clamp(0.0, 1.0);
    final wardenPassed =
        wardenFindings.isEmpty && clampedScore >= minQualityScore;
    if (!wardenPassed) {
      final queuedId = _enqueue(
        candidateId: id,
        sourceAction: sourceAction,
        failedStage: GateStage.warden,
        disposition: GateDisposition.revisionQueue,
        trimmed: trimmed,
        findings: wardenFindings,
      );
      return GateEvaluationResult(
        disposition: GateDisposition.revisionQueue,
        publishable: false,
        sentinelPassed: true,
        wardenPassed: false,
        qualityScore: clampedScore,
        findings: wardenFindings,
        queuedItemId: queuedId,
      );
    }

    return GateEvaluationResult(
      disposition: GateDisposition.published,
      publishable: true,
      sentinelPassed: true,
      wardenPassed: true,
      qualityScore: clampedScore,
      findings: const <GateFinding>[],
    );
  }

  List<GateFinding> _runSentinel({
    required String trimmed,
    required Map<String, Object?> structuredData,
    required List<String> requiredKeys,
    required int minContentLength,
  }) {
    final findings = <GateFinding>[];
    if (trimmed.isEmpty) {
      findings.add(
        const GateFinding(
          stage: GateStage.sentinel,
          code: 'empty_output',
          severity: GateSeverity.critical,
          message: 'Output content is empty.',
        ),
      );
      return findings;
    }

    if (_emailRe.hasMatch(trimmed) ||
        _phoneRe.hasMatch(trimmed) ||
        _secretRe.hasMatch(trimmed)) {
      findings.add(
        const GateFinding(
          stage: GateStage.sentinel,
          code: 'pii_or_secret_detected',
          severity: GateSeverity.critical,
          message: 'Detected PII or credential-like token in output.',
        ),
      );
    }

    if (trimmed.length < minContentLength) {
      findings.add(
        GateFinding(
          stage: GateStage.sentinel,
          code: 'too_short_for_fact_check',
          severity: GateSeverity.warning,
          message: 'Output shorter than $minContentLength characters.',
        ),
      );
    }

    if (_hallucinationRe.hasMatch(trimmed)) {
      findings.add(
        const GateFinding(
          stage: GateStage.sentinel,
          code: 'unverified_marker',
          severity: GateSeverity.warning,
          message: 'Output contains unverified placeholder or marker.',
        ),
      );
    }

    for (final key in requiredKeys) {
      final value = structuredData[key];
      if (value == null || (value is String && value.isEmpty)) {
        findings.add(
          GateFinding(
            stage: GateStage.sentinel,
            code: 'missing_schema_key:$key',
            severity: GateSeverity.warning,
            message: 'Missing required structured field: $key',
          ),
        );
      }
    }
    return findings;
  }

  String _enqueue({
    required String candidateId,
    required String sourceAction,
    required GateStage failedStage,
    required GateDisposition disposition,
    required String trimmed,
    required List<GateFinding> findings,
  }) {
    final itemId = 'rev-$candidateId';
    final excerpt = trimmed.length > 160 ? trimmed.substring(0, 160) : trimmed;
    _revisionQueue[itemId] = RevisionQueueItem(
      id: itemId,
      candidateId: candidateId,
      sourceAction: sourceAction,
      failedStage: failedStage,
      disposition: disposition,
      contentExcerpt: excerpt,
      findings: List<GateFinding>.unmodifiable(findings),
      createdAt: _now().toUtc(),
    );
    return itemId;
  }
}
