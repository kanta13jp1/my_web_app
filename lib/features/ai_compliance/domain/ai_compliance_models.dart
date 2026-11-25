/// Compliance verification lifecycle status for AI models (#2763).
enum ComplianceVerificationStatus {
  unverified('unverified', '未検証'),
  inReview('in_review', '検証中'),
  approved('approved', '承認済');

  const ComplianceVerificationStatus(this.wireValue, this.labelJa);

  final String wireValue;
  final String labelJa;

  static ComplianceVerificationStatus fromWire(final String? raw) {
    final normalized = (raw ?? '').trim();
    for (final value in ComplianceVerificationStatus.values) {
      if (value.wireValue == normalized) {
        return value;
      }
    }
    return ComplianceVerificationStatus.unverified;
  }
}

/// Normalizes untyped map responses into `Map<String, Object?>`.
Map<String, Object?> normalizeAiComplianceMap(final Object? raw) {
  if (raw is Map<Object?, Object?>) {
    final out = <String, Object?>{};
    for (final entry in raw.entries) {
      out[entry.key.toString()] = entry.value;
    }
    return out;
  }
  return <String, Object?>{};
}

/// Mandatory security & terms checklist flags (#2763).
class ComplianceChecklistState {
  const ComplianceChecklistState({
    required this.termsReviewed,
    required this.dataRetentionChecked,
    required this.piiLeakageChecked,
    required this.securityControlsVerified,
  });

  const ComplianceChecklistState.empty()
      : termsReviewed = false,
        dataRetentionChecked = false,
        piiLeakageChecked = false,
        securityControlsVerified = false;

  factory ComplianceChecklistState.fromMap(final Map<Object?, Object?> raw) {
    final map = normalizeAiComplianceMap(raw);
    return ComplianceChecklistState(
      termsReviewed: map['terms_reviewed'] == true,
      dataRetentionChecked: map['data_retention_checked'] == true,
      piiLeakageChecked: map['pii_leakage_checked'] == true,
      securityControlsVerified: map['security_controls_verified'] == true,
    );
  }

  final bool termsReviewed;
  final bool dataRetentionChecked;
  final bool piiLeakageChecked;
  final bool securityControlsVerified;

  bool get allComplete =>
      termsReviewed &&
      dataRetentionChecked &&
      piiLeakageChecked &&
      securityControlsVerified;

  int get completedCount {
    var count = 0;
    if (termsReviewed) count += 1;
    if (dataRetentionChecked) count += 1;
    if (piiLeakageChecked) count += 1;
    if (securityControlsVerified) count += 1;
    return count;
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'terms_reviewed': termsReviewed,
      'data_retention_checked': dataRetentionChecked,
      'pii_leakage_checked': piiLeakageChecked,
      'security_controls_verified': securityControlsVerified,
    };
  }

  ComplianceChecklistState copyWith({
    final bool? termsReviewed,
    final bool? dataRetentionChecked,
    final bool? piiLeakageChecked,
    final bool? securityControlsVerified,
  }) {
    return ComplianceChecklistState(
      termsReviewed: termsReviewed ?? this.termsReviewed,
      dataRetentionChecked: dataRetentionChecked ?? this.dataRetentionChecked,
      piiLeakageChecked: piiLeakageChecked ?? this.piiLeakageChecked,
      securityControlsVerified:
          securityControlsVerified ?? this.securityControlsVerified,
    );
  }
}

/// Immutable compliance workflow record for an AI model/provider (#2763).
class AiComplianceRecord {
  const AiComplianceRecord({
    required this.id,
    required this.providerKey,
    required this.modelId,
    required this.providerName,
    required this.termsUrl,
    required this.reviewNotes,
    required this.status,
    required this.statusLabel,
    required this.checklist,
    required this.approvalNote,
    required this.issueDispatchStatus,
    required this.invokeAllowed,
    required this.invokeGuardCode,
    this.humanApprovedBy,
    this.approvedAt,
    this.githubIssueNumber,
    this.githubIssueUrl,
  });

  factory AiComplianceRecord.fromMap(final Map<Object?, Object?> raw) {
    final map = normalizeAiComplianceMap(raw);
    final status = ComplianceVerificationStatus.fromWire(
      map['status']?.toString(),
    );
    final rawChecklist = map['checklist'];
    final checklist = rawChecklist is Map<Object?, Object?>
        ? ComplianceChecklistState.fromMap(rawChecklist)
        : const ComplianceChecklistState.empty();

    return AiComplianceRecord(
      id: (map['id'] ?? '').toString(),
      providerKey: (map['provider_key'] ?? '').toString(),
      modelId: (map['model_id'] ?? '').toString(),
      providerName: (map['provider_name'] ?? '').toString(),
      termsUrl: (map['terms_url'] ?? '').toString(),
      reviewNotes: (map['review_notes'] ?? '').toString(),
      status: status,
      statusLabel: (map['status_label'] ?? status.labelJa).toString(),
      checklist: checklist,
      humanApprovedBy: map['human_approved_by']?.toString(),
      approvedAt: map['approved_at']?.toString(),
      approvalNote: (map['approval_note'] ?? '').toString(),
      githubIssueNumber: (map['github_issue_number'] as num?)?.toInt(),
      githubIssueUrl: map['github_issue_url']?.toString(),
      issueDispatchStatus: (map['issue_dispatch_status'] ?? 'none').toString(),
      invokeAllowed: map['invoke_allowed'] == true &&
          status == ComplianceVerificationStatus.approved,
      invokeGuardCode:
          (map['invoke_guard_code'] ?? 'COMPLIANCE_NOT_APPROVED').toString(),
    );
  }

  final String id;
  final String providerKey;
  final String modelId;
  final String providerName;
  final String termsUrl;
  final String reviewNotes;
  final ComplianceVerificationStatus status;
  final String statusLabel;
  final ComplianceChecklistState checklist;
  final String? humanApprovedBy;
  final String? approvedAt;
  final String approvalNote;
  final int? githubIssueNumber;
  final String? githubIssueUrl;
  final String issueDispatchStatus;
  final bool invokeAllowed;
  final String invokeGuardCode;

  AiComplianceRecord copyWith({
    final ComplianceVerificationStatus? status,
    final String? statusLabel,
    final ComplianceChecklistState? checklist,
    final String? humanApprovedBy,
    final String? approvedAt,
    final String? approvalNote,
    final bool? invokeAllowed,
    final String? invokeGuardCode,
  }) {
    return AiComplianceRecord(
      id: id,
      providerKey: providerKey,
      modelId: modelId,
      providerName: providerName,
      termsUrl: termsUrl,
      reviewNotes: reviewNotes,
      status: status ?? this.status,
      statusLabel: statusLabel ?? this.statusLabel,
      checklist: checklist ?? this.checklist,
      humanApprovedBy: humanApprovedBy ?? this.humanApprovedBy,
      approvedAt: approvedAt ?? this.approvedAt,
      approvalNote: approvalNote ?? this.approvalNote,
      githubIssueNumber: githubIssueNumber,
      githubIssueUrl: githubIssueUrl,
      issueDispatchStatus: issueDispatchStatus,
      invokeAllowed: invokeAllowed ?? this.invokeAllowed,
      invokeGuardCode: invokeGuardCode ?? this.invokeGuardCode,
    );
  }
}

/// Summary counters for AI compliance records.
class AiComplianceSummary {
  const AiComplianceSummary({
    required this.total,
    required this.unverified,
    required this.inReview,
    required this.approved,
  });

  const AiComplianceSummary.empty()
      : total = 0,
        unverified = 0,
        inReview = 0,
        approved = 0;

  factory AiComplianceSummary.fromMap(final Map<Object?, Object?> raw) {
    final map = normalizeAiComplianceMap(raw);
    return AiComplianceSummary(
      total: (map['total'] as num?)?.toInt() ?? 0,
      unverified: (map['unverified'] as num?)?.toInt() ?? 0,
      inReview: (map['in_review'] as num?)?.toInt() ?? 0,
      approved: (map['approved'] as num?)?.toInt() ?? 0,
    );
  }

  final int total;
  final int unverified;
  final int inReview;
  final int approved;
}

/// Result of compliance list/seed/update endpoints.
class AiComplianceFeedResult {
  const AiComplianceFeedResult({
    required this.records,
    required this.summary,
    this.highlightedRecord,
  });

  factory AiComplianceFeedResult.fromPayload(final Map<Object?, Object?> raw) {
    final map = normalizeAiComplianceMap(raw);
    final rawList = map['records'];
    final records = <AiComplianceRecord>[];
    if (rawList is List<Object?>) {
      for (final item in rawList) {
        if (item is Map<Object?, Object?>) {
          records.add(AiComplianceRecord.fromMap(item));
        }
      }
    }
    final summaryRaw = map['summary'];
    final summary = summaryRaw is Map<Object?, Object?>
        ? AiComplianceSummary.fromMap(summaryRaw)
        : const AiComplianceSummary.empty();
    final recordRaw = map['record'];
    final highlighted = recordRaw is Map<Object?, Object?>
        ? AiComplianceRecord.fromMap(recordRaw)
        : null;
    return AiComplianceFeedResult(
      records: records,
      summary: summary,
      highlightedRecord: highlighted,
    );
  }

  final List<AiComplianceRecord> records;
  final AiComplianceSummary summary;
  final AiComplianceRecord? highlightedRecord;
}

/// System-level API invocation guard check output.
class AiComplianceGuardResult {
  const AiComplianceGuardResult({
    required this.allowed,
    required this.code,
    required this.status,
    required this.reason,
  });

  factory AiComplianceGuardResult.fromPayload(
    final Map<Object?, Object?> raw,
  ) {
    final map = normalizeAiComplianceMap(raw);
    return AiComplianceGuardResult(
      allowed: map['allowed'] == true,
      code: (map['code'] ?? 'COMPLIANCE_NOT_APPROVED').toString(),
      status: ComplianceVerificationStatus.fromWire(map['status']?.toString()),
      reason: (map['reason'] ?? '').toString(),
    );
  }

  final bool allowed;
  final String code;
  final ComplianceVerificationStatus status;
  final String reason;
}

/// Repository abstraction for `app-hub` `ai_compliance.*` (#2763).
abstract class AiComplianceRepository {
  Future<AiComplianceFeedResult> listRecords({
    final String? statusFilter,
    final String? query,
  });

  Future<AiComplianceFeedResult> seedDefaults();

  Future<AiComplianceFeedResult> submitReview({
    required final String providerKey,
    required final String modelId,
    required final String providerName,
    final String? termsUrl,
    final String? reviewNotes,
    final ComplianceChecklistState? checklist,
  });

  Future<AiComplianceFeedResult> updateChecklist({
    required final String id,
    required final ComplianceChecklistState checklist,
  });

  Future<AiComplianceFeedResult> approveEntry({
    required final String id,
    required final String reviewerName,
    required final bool humanConfirmed,
    final String? approvalNote,
  });

  Future<AiComplianceGuardResult> checkInvokeGuard({
    required final String id,
  });
}
