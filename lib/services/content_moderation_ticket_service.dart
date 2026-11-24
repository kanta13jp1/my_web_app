import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// モデレーション違反カテゴリ。
enum ModerationViolationCategory {
  spam('spam', 'スパム・機械的投稿', ModerationSeverity.low, 72),
  harassment('harassment', 'ハラスメント・攻撃的表現', ModerationSeverity.medium, 12),
  privacyViolation(
    'privacy_violation',
    '個人情報・プライバシー侵害',
    ModerationSeverity.high,
    4,
  ),
  misinformation('misinformation', '虚偽情報・誤情報流布', ModerationSeverity.medium, 24),
  illegalContent(
    'illegal_content',
    '違法・法令違反コンテンツ',
    ModerationSeverity.urgent,
    1,
  );

  const ModerationViolationCategory(
    this.dbValue,
    this.labelJa,
    this.baselineSeverity,
    this.slaHours,
  );

  final String dbValue;
  final String labelJa;
  final ModerationSeverity baselineSeverity;
  final int slaHours;

  static ModerationViolationCategory? tryParse(String raw) {
    final String normalized = raw.trim();
    for (final ModerationViolationCategory value
        in ModerationViolationCategory.values) {
      if (value.dbValue == normalized) {
        return value;
      }
    }
    return null;
  }
}

/// モデレーション重大度。
enum ModerationSeverity {
  low('low', '低'),
  medium('medium', '中'),
  high('high', '高'),
  urgent('urgent', '緊急');

  const ModerationSeverity(this.dbValue, this.labelJa);

  final String dbValue;
  final String labelJa;

  static ModerationSeverity? tryParse(String raw) {
    final String normalized = raw.trim();
    for (final ModerationSeverity value in ModerationSeverity.values) {
      if (value.dbValue == normalized) {
        return value;
      }
    }
    return null;
  }
}

/// モデレーションチケット対応ステータス。
enum ModerationTicketStatus {
  open('open', '未対応'),
  inReview('in_review', '確認中'),
  resolved('resolved', '解決済み'),
  dismissed('dismissed', '却下');

  const ModerationTicketStatus(this.dbValue, this.labelJa);

  final String dbValue;
  final String labelJa;

  static ModerationTicketStatus? tryParse(String raw) {
    final String normalized = raw.trim();
    for (final ModerationTicketStatus value in ModerationTicketStatus.values) {
      if (value.dbValue == normalized) {
        return value;
      }
    }
    return null;
  }
}

/// 報告起票用ドラフト。
@immutable
class ModerationTicketDraft {
  const ModerationTicketDraft({
    required this.targetEntityType,
    required this.targetEntityId,
    required this.violationCategory,
    required this.reportReason,
    this.evidenceReference = '',
  });

  final String targetEntityType;
  final String targetEntityId;
  final ModerationViolationCategory violationCategory;
  final String reportReason;
  final String evidenceReference;
}

/// モデレーション対応チケットモデル。
@immutable
class ModerationTicket {
  const ModerationTicket({
    required this.id,
    required this.targetEntityType,
    required this.targetEntityId,
    required this.violationCategory,
    required this.severity,
    required this.reportReason,
    this.evidenceReference = '',
    this.ticketStatus = ModerationTicketStatus.open,
    this.assignedModeratorId,
    this.resolutionNote,
    this.resolvedAtIso,
    this.createdAtIso = '',
  });

  final String id;
  final String targetEntityType;
  final String targetEntityId;
  final ModerationViolationCategory violationCategory;
  final ModerationSeverity severity;
  final String reportReason;
  final String evidenceReference;
  final ModerationTicketStatus ticketStatus;
  final String? assignedModeratorId;
  final String? resolutionNote;
  final String? resolvedAtIso;
  final String createdAtIso;

  ModerationTicket copyWith({
    ModerationTicketStatus? ticketStatus,
    String? assignedModeratorId,
    String? resolutionNote,
    String? resolvedAtIso,
    bool clearResolvedAt = false,
  }) {
    return ModerationTicket(
      id: id,
      targetEntityType: targetEntityType,
      targetEntityId: targetEntityId,
      violationCategory: violationCategory,
      severity: severity,
      reportReason: reportReason,
      evidenceReference: evidenceReference,
      ticketStatus: ticketStatus ?? this.ticketStatus,
      assignedModeratorId: assignedModeratorId ?? this.assignedModeratorId,
      resolutionNote: resolutionNote ?? this.resolutionNote,
      resolvedAtIso:
          clearResolvedAt ? null : (resolvedAtIso ?? this.resolvedAtIso),
      createdAtIso: createdAtIso,
    );
  }

  /// 一般通報者 INSERT 向けペイロード。
  /// RLS `owner_insert` に従い `ticket_status='open'` を固定し、
  /// 管理者専用列は null 扱いとして送信しない。
  Map<String, Object?> toInsertPayload(String reporterUserId) {
    return <String, Object?>{
      'reporter_user_id': reporterUserId,
      'target_entity_type': targetEntityType,
      'target_entity_id': targetEntityId,
      'violation_category': violationCategory.dbValue,
      'severity': severity.dbValue,
      'report_reason': reportReason,
      'evidence_reference': evidenceReference,
      'ticket_status': ModerationTicketStatus.open.dbValue,
    };
  }

  static ModerationTicket fromJson(Map<String, Object?> json) {
    final String modId = _readString(json, 'assigned_moderator_id');
    final String resNote = _readString(json, 'resolution_note');
    final String resAt = _readString(json, 'resolved_at');

    return ModerationTicket(
      id: _readString(json, 'id', fallback: 'ticket-local'),
      targetEntityType: _readString(
        json,
        'target_entity_type',
        fallback: 'note',
      ),
      targetEntityId: _readString(json, 'target_entity_id'),
      violationCategory: ModerationViolationCategory.tryParse(
            _readString(json, 'violation_category', fallback: 'spam'),
          ) ??
          ModerationViolationCategory.spam,
      severity: ModerationSeverity.tryParse(
            _readString(json, 'severity', fallback: 'low'),
          ) ??
          ModerationSeverity.low,
      reportReason: _readString(json, 'report_reason'),
      evidenceReference: _readString(json, 'evidence_reference'),
      ticketStatus: ModerationTicketStatus.tryParse(
            _readString(json, 'ticket_status', fallback: 'open'),
          ) ??
          ModerationTicketStatus.open,
      assignedModeratorId: modId.isEmpty ? null : modId,
      resolutionNote: resNote.isEmpty ? null : resNote,
      resolvedAtIso: resAt.isEmpty ? null : resAt,
      createdAtIso: _readString(json, 'created_at'),
    );
  }

  static String _readString(
    Map<String, Object?> json,
    String key, {
    String fallback = '',
  }) {
    final Object? value = json[key];
    if (value == null) {
      return fallback;
    }
    final String text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }
}

/// 決定論的モデレーション基準判定ロジック。
class ModerationPolicyEvaluator {
  const ModerationPolicyEvaluator._();

  static const List<String> _urgentKeywords = <String>[
    '殺害',
    '爆破',
    '自傷',
    '脅迫',
    '流出',
    'illegal',
    'threat',
  ];

  static const List<String> _highSeverityKeywords = <String>[
    '個人情報',
    '住所',
    '電話番号',
    '口座',
    'つきまとい',
    'doxxing',
  ];

  /// 基準書 (`docs/governance/content-moderation-standards.md`) に沿った重大度判定。
  static ModerationSeverity classifySeverity({
    required ModerationViolationCategory category,
    required String reasonText,
  }) {
    final String lower = reasonText.toLowerCase();
    for (final String kw in _urgentKeywords) {
      if (lower.contains(kw)) {
        return ModerationSeverity.urgent;
      }
    }
    if (category == ModerationViolationCategory.illegalContent) {
      return ModerationSeverity.urgent;
    }
    for (final String kw in _highSeverityKeywords) {
      if (lower.contains(kw)) {
        return ModerationSeverity.high;
      }
    }
    return category.baselineSeverity;
  }

  /// 許可されたチケットステータス遷移を判定する。
  static bool canTransitionStatus({
    required ModerationTicketStatus from,
    required ModerationTicketStatus to,
  }) {
    if (from == to) {
      return false;
    }
    switch (from) {
      case ModerationTicketStatus.open:
        return to == ModerationTicketStatus.inReview ||
            to == ModerationTicketStatus.resolved ||
            to == ModerationTicketStatus.dismissed;
      case ModerationTicketStatus.inReview:
        return to == ModerationTicketStatus.resolved ||
            to == ModerationTicketStatus.dismissed;
      case ModerationTicketStatus.resolved:
      case ModerationTicketStatus.dismissed:
        return to == ModerationTicketStatus.inReview;
    }
  }

  static List<String> validateDraft(ModerationTicketDraft draft) {
    final List<String> errors = <String>[];
    final String entityType = draft.targetEntityType.trim();
    if (entityType.isEmpty) {
      errors.add('対象種別（例: note / comment / profile）は必須です。');
    } else if (entityType.length > 60) {
      errors.add('対象種別は60文字以内で入力してください。');
    }

    final String entityId = draft.targetEntityId.trim();
    if (entityId.isEmpty) {
      errors.add('対象IDは必須です。');
    } else if (entityId.length > 120) {
      errors.add('対象IDは120文字以内で入力してください。');
    }

    final String reason = draft.reportReason.trim();
    if (reason.isEmpty) {
      errors.add('報告理由・具体的状況は必須です。');
    } else if (reason.length > 2000) {
      errors.add('報告理由は2000文字以内で入力してください。');
    }
    return List<String>.unmodifiable(errors);
  }
}

typedef ModerationTicketSubmitFn = Future<ModerationTicket> Function(
  ModerationTicket ticket,
);
typedef ModerationTicketTransitionFn = Future<ModerationTicket> Function(
  ModerationTicket updatedTicket,
);

/// モデレーションチケット受付・管理サービス。
class ContentModerationTicketService extends ChangeNotifier {
  ContentModerationTicketService({
    SupabaseClient Function()? clientResolver,
    ModerationTicketSubmitFn? submitOverride,
    ModerationTicketTransitionFn? transitionOverride,
    List<ModerationTicket> initialTickets = const <ModerationTicket>[],
  })  : _clientResolver = clientResolver,
        _submitOverride = submitOverride,
        _transitionOverride = transitionOverride,
        _tickets = List<ModerationTicket>.of(initialTickets);

  final SupabaseClient Function()? _clientResolver;
  final ModerationTicketSubmitFn? _submitOverride;
  final ModerationTicketTransitionFn? _transitionOverride;
  final List<ModerationTicket> _tickets;

  ModerationTicketStatus? _statusFilter;
  List<String> _validationErrors = const <String>[];
  String _statusBanner = '';
  bool _isBusy = false;

  List<ModerationTicket> get allTickets =>
      List<ModerationTicket>.unmodifiable(_tickets);

  ModerationTicketStatus? get statusFilter => _statusFilter;

  List<ModerationTicket> get filteredTickets {
    final ModerationTicketStatus? filter = _statusFilter;
    if (filter == null) {
      return allTickets;
    }
    return List<ModerationTicket>.unmodifiable(
      _tickets.where(
        (ModerationTicket ticket) => ticket.ticketStatus == filter,
      ),
    );
  }

  List<String> get validationErrors =>
      List<String>.unmodifiable(_validationErrors);
  String get statusBanner => _statusBanner;
  bool get isBusy => _isBusy;

  void setStatusFilter(ModerationTicketStatus? filter) {
    if (_statusFilter == filter) {
      return;
    }
    _statusFilter = filter;
    notifyListeners();
  }

  Future<void> loadTickets() async {
    final SupabaseClient? client = _resolveClientOrNull();
    if (client == null) {
      return;
    }
    final List<Map<String, Object?>> rows = await client
        .from('moderation_tickets')
        .select()
        .order('created_at', ascending: false);
    _tickets
      ..clear()
      ..addAll(rows.map(ModerationTicket.fromJson));
    notifyListeners();
  }

  Future<ModerationTicket?> submitReport(ModerationTicketDraft draft) async {
    final List<String> errors = ModerationPolicyEvaluator.validateDraft(draft);
    if (errors.isNotEmpty) {
      _validationErrors = errors;
      _statusBanner = '必須項目を確認してください。';
      notifyListeners();
      return null;
    }

    _validationErrors = const <String>[];
    _isBusy = true;
    notifyListeners();

    final DateTime now = DateTime.now().toUtc();
    final ModerationSeverity severity =
        ModerationPolicyEvaluator.classifySeverity(
      category: draft.violationCategory,
      reasonText: draft.reportReason,
    );
    final ModerationTicket candidate = ModerationTicket(
      id: 'mod-${now.microsecondsSinceEpoch}',
      targetEntityType: draft.targetEntityType.trim(),
      targetEntityId: draft.targetEntityId.trim(),
      violationCategory: draft.violationCategory,
      severity: severity,
      reportReason: draft.reportReason.trim(),
      evidenceReference: draft.evidenceReference.trim(),
      createdAtIso: now.toIso8601String(),
    );

    try {
      ModerationTicket persisted = candidate;
      final ModerationTicketSubmitFn? overrideFn = _submitOverride;
      if (overrideFn != null) {
        persisted = await overrideFn(candidate);
      } else {
        final SupabaseClient? client = _resolveClientOrNull();
        final String? userId = client?.auth.currentUser?.id;
        if (client != null && userId != null) {
          final List<Map<String, Object?>> rows = await client
              .from('moderation_tickets')
              .insert(candidate.toInsertPayload(userId))
              .select();
          if (rows.isNotEmpty) {
            persisted = ModerationTicket.fromJson(rows.first);
          }
        }
      }
      _tickets.insert(0, persisted);
      _statusBanner =
          'チケットを「${persisted.ticketStatus.labelJa}」（重大度: ${persisted.severity.labelJa} / SLA ${persisted.violationCategory.slaHours}時間）で受け付けました。';
      return persisted;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<bool> transitionTicketStatus({
    required String ticketId,
    required ModerationTicketStatus nextStatus,
    String moderatorId = '',
    String resolutionNote = '',
  }) async {
    final int index = _tickets.indexWhere(
      (ModerationTicket item) => item.id == ticketId,
    );
    if (index < 0) {
      _validationErrors = const <String>['対象のチケットが見つかりません。'];
      notifyListeners();
      return false;
    }

    final ModerationTicket current = _tickets[index];
    if (!ModerationPolicyEvaluator.canTransitionStatus(
      from: current.ticketStatus,
      to: nextStatus,
    )) {
      _validationErrors = <String>[
        '${current.ticketStatus.labelJa} から ${nextStatus.labelJa} への直接遷移は許可されていません。',
      ];
      notifyListeners();
      return false;
    }

    final String trimmedNote = resolutionNote.trim();
    if ((nextStatus == ModerationTicketStatus.resolved ||
            nextStatus == ModerationTicketStatus.dismissed) &&
        trimmedNote.isEmpty) {
      _validationErrors = const <String>[
        '解決済みまたは却下へ更新する際は判断根拠（措置メモ）の記入が必須です。',
      ];
      notifyListeners();
      return false;
    }

    _validationErrors = const <String>[];
    _isBusy = true;
    notifyListeners();

    final bool isTerminal = nextStatus == ModerationTicketStatus.resolved ||
        nextStatus == ModerationTicketStatus.dismissed;
    final DateTime now = DateTime.now().toUtc();
    final ModerationTicket updated = current.copyWith(
      ticketStatus: nextStatus,
      assignedModeratorId: moderatorId.trim().isEmpty
          ? current.assignedModeratorId
          : moderatorId.trim(),
      resolutionNote:
          trimmedNote.isEmpty ? current.resolutionNote : trimmedNote,
      resolvedAtIso: isTerminal ? now.toIso8601String() : null,
      clearResolvedAt: !isTerminal,
    );

    try {
      ModerationTicket saved = updated;
      final ModerationTicketTransitionFn? overrideFn = _transitionOverride;
      if (overrideFn != null) {
        saved = await overrideFn(updated);
      } else {
        final SupabaseClient? client = _resolveClientOrNull();
        if (client != null && client.auth.currentUser != null) {
          final Map<String, Object?> patch = <String, Object?>{
            'ticket_status': updated.ticketStatus.dbValue,
            if (updated.assignedModeratorId != null)
              'assigned_moderator_id': updated.assignedModeratorId,
            if (updated.resolutionNote != null)
              'resolution_note': updated.resolutionNote,
            'resolved_at': updated.resolvedAtIso,
            'updated_at': now.toIso8601String(),
          };
          final List<Map<String, Object?>> rows = await client
              .from('moderation_tickets')
              .update(patch)
              .eq('id', ticketId)
              .select();
          if (rows.isNotEmpty) {
            saved = ModerationTicket.fromJson(rows.first);
          }
        }
      }
      _tickets[index] = saved;
      _statusBanner =
          'チケット (${saved.id}) を「${saved.ticketStatus.labelJa}」へ更新しました。';
      return true;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  SupabaseClient? _resolveClientOrNull() {
    final SupabaseClient Function()? resolver = _clientResolver;
    if (resolver != null) {
      return resolver();
    }
    try {
      return Supabase.instance.client;
    } on AssertionError {
      return null;
    } catch (_) {
      return null;
    }
  }
}
