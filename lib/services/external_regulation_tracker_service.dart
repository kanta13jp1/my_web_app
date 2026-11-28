import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 外部環境・法規制要因の分類。
enum RegulationFactorCategory {
  regulation('regulation', '法規制・輸入規制'),
  politicalClaim('political_claim', '政治的クレーム・外交声明'),
  economicEmbargo('economic_embargo', '禁輸措置・経済的影響'),
  supplyChainDisruption('supply_chain_disruption', 'サプライチェーン障害');

  const RegulationFactorCategory(this.dbValue, this.labelJa);

  final String dbValue;
  final String labelJa;

  static RegulationFactorCategory? tryParse(String raw) {
    final String normalized = raw.trim();
    for (final RegulationFactorCategory value
        in RegulationFactorCategory.values) {
      if (value.dbValue == normalized) {
        return value;
      }
    }
    return null;
  }
}

/// 事業・ワークフローへの影響度。
enum RegulationImpactLevel {
  low('low', '低', requiresEscalation: false),
  medium('medium', '中', requiresEscalation: false),
  high('high', '高', requiresEscalation: true),
  critical('critical', '緊急', requiresEscalation: true);

  const RegulationImpactLevel(
    this.dbValue,
    this.labelJa, {
    required this.requiresEscalation,
  });

  final String dbValue;
  final String labelJa;
  final bool requiresEscalation;

  static RegulationImpactLevel? tryParse(String raw) {
    final String normalized = raw.trim().toLowerCase();
    for (final RegulationImpactLevel value in RegulationImpactLevel.values) {
      if (value.dbValue == normalized) {
        return value;
      }
    }
    return null;
  }
}

/// 外部情報に対する事実確認ステータス。
/// 登録直後は必ず [FactCheckStatus.pendingFactCheck]（事実確認待ち）となる。
enum FactCheckStatus {
  pendingFactCheck('pending_fact_check', '事実確認待ち'),
  verified('verified', '一次情報確認済み'),
  disputed('disputed', '要再確認・係争中'),
  resolved('resolved', '対応完了');

  const FactCheckStatus(this.dbValue, this.labelJa);

  final String dbValue;
  final String labelJa;

  static FactCheckStatus? tryParse(String raw) {
    final String normalized = raw.trim();
    for (final FactCheckStatus value in FactCheckStatus.values) {
      if (value.dbValue == normalized) {
        return value;
      }
    }
    return null;
  }
}

/// 外部規制・サプライチェーン影響の入力ドラフト。
@immutable
class ExternalRegulationImpactDraft {
  const ExternalRegulationImpactDraft({
    required this.jurisdictionCode,
    required this.factorCategory,
    required this.title,
    required this.affectedProductArea,
    required this.impactLevel,
    required this.sourceReference,
    this.summary = '',
    this.effectiveDate = '',
    this.stakeholders = '',
    this.verificationStatus = FactCheckStatus.pendingFactCheck,
    this.awaitingFactCheck = true,
  });

  final String jurisdictionCode;
  final RegulationFactorCategory factorCategory;
  final String title;
  final String affectedProductArea;
  final RegulationImpactLevel impactLevel;
  final String sourceReference;
  final String summary;
  final String effectiveDate;
  final String stakeholders;
  final FactCheckStatus verificationStatus;
  final bool awaitingFactCheck;
}

/// 登録・追跡対象の外部規制・サプライチェーン影響レコード。
@immutable
class ExternalRegulationImpact {
  const ExternalRegulationImpact({
    required this.id,
    required this.jurisdictionCode,
    required this.factorCategory,
    required this.title,
    required this.affectedProductArea,
    required this.impactLevel,
    required this.sourceReference,
    this.summary = '',
    this.effectiveDate = '',
    this.stakeholders = const <String>[],
    this.verificationStatus = FactCheckStatus.pendingFactCheck,
    this.awaitingFactCheck = true,
    this.escalationIssueUrl = '',
    this.createdAtIso = '',
  });

  final String id;
  final String jurisdictionCode;
  final RegulationFactorCategory factorCategory;
  final String title;
  final String affectedProductArea;
  final RegulationImpactLevel impactLevel;
  final String sourceReference;
  final String summary;
  final String effectiveDate;
  final List<String> stakeholders;
  final FactCheckStatus verificationStatus;
  final bool awaitingFactCheck;
  final String escalationIssueUrl;
  final String createdAtIso;

  bool get requiresAlertWorkflow => impactLevel.requiresEscalation;

  ExternalRegulationImpact copyWith({
    String? escalationIssueUrl,
    FactCheckStatus? verificationStatus,
    bool? awaitingFactCheck,
  }) {
    return ExternalRegulationImpact(
      id: id,
      jurisdictionCode: jurisdictionCode,
      factorCategory: factorCategory,
      title: title,
      affectedProductArea: affectedProductArea,
      impactLevel: impactLevel,
      sourceReference: sourceReference,
      summary: summary,
      effectiveDate: effectiveDate,
      stakeholders: stakeholders,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      awaitingFactCheck: awaitingFactCheck ?? this.awaitingFactCheck,
      escalationIssueUrl: escalationIssueUrl ?? this.escalationIssueUrl,
      createdAtIso: createdAtIso,
    );
  }

  Map<String, Object?> toInsertPayload(String userId) {
    return <String, Object?>{
      'user_id': userId,
      'jurisdiction_code': jurisdictionCode,
      'factor_category': factorCategory.dbValue,
      'title': title,
      'summary': summary,
      'affected_product_area': affectedProductArea,
      'impact_level': impactLevel.dbValue,
      'verification_status': verificationStatus.dbValue,
      'awaiting_fact_check': awaitingFactCheck,
      'source_reference': sourceReference,
      if (effectiveDate.isNotEmpty) 'effective_date': effectiveDate,
      'escalation_issue_url': escalationIssueUrl,
    };
  }

  Map<String, Object?> toRepositoryDispatchPayload() {
    return <String, Object?>{
      'event_type': 'external-regulation-high-impact',
      'client_payload': <String, Object?>{
        'title': title,
        'jurisdiction_code': jurisdictionCode,
        'factor_category': factorCategory.dbValue,
        'affected_product_area': affectedProductArea,
        'impact_level': impactLevel.dbValue,
        'verification_status': verificationStatus.dbValue,
        'awaiting_fact_check': awaitingFactCheck,
        'source_reference': sourceReference,
        'effective_date': effectiveDate,
        'summary': summary,
        'stakeholders': stakeholders,
      },
    };
  }

  static ExternalRegulationImpact fromJson(Map<String, Object?> json) {
    final String rawStatus = _readString(
      json,
      'verification_status',
      fallback: FactCheckStatus.pendingFactCheck.dbValue,
    );
    final FactCheckStatus parsedStatus =
        FactCheckStatus.tryParse(rawStatus) ?? FactCheckStatus.pendingFactCheck;
    final bool defaultAwaiting =
        parsedStatus == FactCheckStatus.pendingFactCheck;

    return ExternalRegulationImpact(
      id: _readString(json, 'id', fallback: 'local-record'),
      jurisdictionCode: _readString(json, 'jurisdiction_code', fallback: 'JP'),
      factorCategory: RegulationFactorCategory.tryParse(
            _readString(json, 'factor_category', fallback: 'regulation'),
          ) ??
          RegulationFactorCategory.regulation,
      title: _readString(json, 'title'),
      affectedProductArea: _readString(json, 'affected_product_area'),
      impactLevel: RegulationImpactLevel.tryParse(
            _readString(json, 'impact_level', fallback: 'medium'),
          ) ??
          RegulationImpactLevel.medium,
      sourceReference: _readString(json, 'source_reference'),
      summary: _readString(json, 'summary'),
      effectiveDate: _readString(json, 'effective_date'),
      stakeholders: _readStringList(json['stakeholders']),
      verificationStatus: parsedStatus,
      awaitingFactCheck: _readBool(
        json,
        'awaiting_fact_check',
        fallback: defaultAwaiting,
      ),
      escalationIssueUrl: _readString(json, 'escalation_issue_url'),
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

  static bool _readBool(
    Map<String, Object?> json,
    String key, {
    required bool fallback,
  }) {
    final Object? value = json[key];
    if (value is bool) {
      return value;
    }
    if (value is String) {
      final String normalized = value.trim().toLowerCase();
      if (normalized == 'true') {
        return true;
      }
      if (normalized == 'false') {
        return false;
      }
    }
    return fallback;
  }

  static List<String> _readStringList(Object? value) {
    if (value is List<Object?>) {
      return value
          .map((Object? item) => item?.toString().trim() ?? '')
          .where((String item) => item.isNotEmpty)
          .toList(growable: false);
    }
    if (value is String) {
      return value
          .split(',')
          .map((String item) => item.trim().replaceFirst('@', ''))
          .where((String item) => item.isNotEmpty)
          .toList(growable: false);
    }
    return const <String>[];
  }
}

/// 決定論的バリデーション結果。
@immutable
class ExternalRegulationValidationResult {
  const ExternalRegulationValidationResult({
    required this.isValid,
    required this.errors,
    required this.normalizedRecord,
  });

  final bool isValid;
  final List<String> errors;
  final ExternalRegulationImpact? normalizedRecord;
}

/// 外部規制・サプライチェーン影響データの決定論的バリデーター。
class ExternalRegulationValidator {
  const ExternalRegulationValidator._();

  static final RegExp _jurisdictionPattern = RegExp(
    r'^[A-Z]{2,8}(?:-[A-Z0-9]{1,8})?$',
  );
  static final RegExp _httpUrlPattern = RegExp(r'^https?://\S+$');
  static final RegExp _referenceCodePattern = RegExp(
    r'^[A-Za-z0-9._:/?#=&+%@-]{4,}$',
  );
  static final RegExp _isoDatePattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');
  static final RegExp _handlePattern = RegExp(
    r'^[A-Za-z0-9](?:[A-Za-z0-9-]{0,37}[A-Za-z0-9])?$',
  );

  static ExternalRegulationValidationResult validate(
    ExternalRegulationImpactDraft draft, {
    String? recordId,
    String? createdAtIso,
  }) {
    final List<String> errors = <String>[];
    final String title = draft.title.trim();
    if (title.isEmpty) {
      errors.add('件名（タイトル）は必須です。');
    } else if (title.length > 200) {
      errors.add('件名は200文字以内で入力してください。');
    }

    final String jurisdiction = draft.jurisdictionCode.trim().toUpperCase();
    if (jurisdiction.isEmpty) {
      errors.add('対象国・地域コードは必須です。');
    } else if (!_jurisdictionPattern.hasMatch(jurisdiction)) {
      errors.add('対象国・地域コードは JP / CN / EU / US / APAC 等の英大文字形式で入力してください。');
    }

    final String productArea = draft.affectedProductArea.trim();
    if (productArea.isEmpty) {
      errors.add('影響プロダクト・サプライチェーン領域は必須です。');
    } else if (productArea.length > 120) {
      errors.add('影響プロダクト・サプライチェーン領域は120文字以内で入力してください。');
    }

    final String sourceRef = draft.sourceReference.trim();
    if (sourceRef.isEmpty) {
      errors.add('一次情報・根拠参照（公式URLまたは法令・通達番号）は必須です。');
    } else if (!_httpUrlPattern.hasMatch(sourceRef) &&
        !_referenceCodePattern.hasMatch(sourceRef)) {
      errors.add('根拠参照は有効な HTTP(S) URL または空白なしの参照IDで入力してください。');
    } else if (draft.verificationStatus == FactCheckStatus.verified &&
        !_httpUrlPattern.hasMatch(sourceRef)) {
      errors.add('「一次情報確認済み」にする場合は HTTP(S) の一次情報URLが必要です。');
    }

    if (draft.verificationStatus == FactCheckStatus.pendingFactCheck &&
        !draft.awaitingFactCheck) {
      errors.add('ステータスが「事実確認待ち」の場合、事実確認待ちフラグは true である必要があります。');
    } else if ((draft.verificationStatus == FactCheckStatus.verified ||
            draft.verificationStatus == FactCheckStatus.resolved) &&
        draft.awaitingFactCheck) {
      errors.add('確認済み・対応完了のレコードでは事実確認待ちフラグを false にする必要があります。');
    }

    final String effectiveDate = draft.effectiveDate.trim();
    if (effectiveDate.isNotEmpty && !_isValidIsoDate(effectiveDate)) {
      errors.add('発効日・基準日は実在する YYYY-MM-DD 形式で入力してください。');
    }

    final List<String> stakeholders = _parseStakeholders(
      draft.stakeholders,
      errors,
    );

    if (errors.isNotEmpty) {
      return ExternalRegulationValidationResult(
        isValid: false,
        errors: List<String>.unmodifiable(errors),
        normalizedRecord: null,
      );
    }

    final DateTime now = DateTime.now().toUtc();
    return ExternalRegulationValidationResult(
      isValid: true,
      errors: const <String>[],
      normalizedRecord: ExternalRegulationImpact(
        id: recordId ?? 'reg-${now.microsecondsSinceEpoch}',
        jurisdictionCode: jurisdiction,
        factorCategory: draft.factorCategory,
        title: title,
        affectedProductArea: productArea,
        impactLevel: draft.impactLevel,
        sourceReference: sourceRef,
        summary: draft.summary.trim(),
        effectiveDate: effectiveDate,
        stakeholders: stakeholders,
        verificationStatus: draft.verificationStatus,
        awaitingFactCheck: draft.awaitingFactCheck,
        createdAtIso: createdAtIso ?? now.toIso8601String(),
      ),
    );
  }

  static bool _isValidIsoDate(String raw) {
    final RegExpMatch? match = _isoDatePattern.firstMatch(raw);
    if (match == null) {
      return false;
    }
    final int? year = int.tryParse(match.group(1)!);
    final int? month = int.tryParse(match.group(2)!);
    final int? day = int.tryParse(match.group(3)!);
    if (year == null || month == null || day == null) {
      return false;
    }
    if (month < 1 || month > 12 || day < 1 || day > 31) {
      return false;
    }
    final DateTime parsed = DateTime.utc(year, month, day);
    return parsed.year == year && parsed.month == month && parsed.day == day;
  }

  static List<String> _parseStakeholders(String raw, List<String> errors) {
    final List<String> result = <String>[];
    for (final String token in raw.split(',')) {
      final String cleaned = token.trim().replaceFirst('@', '');
      if (cleaned.isEmpty) {
        continue;
      }
      if (!_handlePattern.hasMatch(cleaned)) {
        errors.add('通知先 GitHub ID の形式が不正です: $cleaned');
        continue;
      }
      if (!result.contains(cleaned)) {
        result.add(cleaned);
      }
    }
    return List<String>.unmodifiable(result);
  }
}

/// 高影響アラート送信結果。
@immutable
class RegulationAlertDispatchResult {
  const RegulationAlertDispatchResult({
    required this.triggered,
    required this.message,
    this.issueUrl = '',
  });

  final bool triggered;
  final String message;
  final String issueUrl;
}

typedef RegulationAlertDispatcher = Future<RegulationAlertDispatchResult>
    Function(
  ExternalRegulationImpact impact,
);

/// 外部規制・サプライチェーン影響トラッカーの状態管理サービス。
class ExternalRegulationTrackerService extends ChangeNotifier {
  ExternalRegulationTrackerService({
    SupabaseClient Function()? clientResolver,
    RegulationAlertDispatcher? alertDispatcher,
    List<ExternalRegulationImpact> initialItems =
        const <ExternalRegulationImpact>[],
  })  : _clientResolver = clientResolver,
        _alertDispatcher = alertDispatcher,
        _items = List<ExternalRegulationImpact>.of(initialItems);

  final SupabaseClient Function()? _clientResolver;
  final RegulationAlertDispatcher? _alertDispatcher;
  final List<ExternalRegulationImpact> _items;

  List<String> _validationErrors = const <String>[];
  String _statusBanner = '';
  bool _isSubmitting = false;

  List<ExternalRegulationImpact> get items =>
      List<ExternalRegulationImpact>.unmodifiable(_items);
  List<String> get validationErrors =>
      List<String>.unmodifiable(_validationErrors);
  String get statusBanner => _statusBanner;
  bool get isSubmitting => _isSubmitting;

  int get pendingFactCheckCount => _items
      .where(
        (ExternalRegulationImpact item) =>
            item.awaitingFactCheck ||
            item.verificationStatus == FactCheckStatus.pendingFactCheck,
      )
      .length;

  int get highImpactCount => _items
      .where((ExternalRegulationImpact item) => item.requiresAlertWorkflow)
      .length;

  Future<void> loadRemoteImpacts() async {
    final SupabaseClient? client = _resolveClientOrNull();
    if (client == null) {
      return;
    }
    final List<Map<String, Object?>> rows = await client
        .from('external_regulation_impacts')
        .select()
        .order('created_at', ascending: false);
    _items
      ..clear()
      ..addAll(rows.map(ExternalRegulationImpact.fromJson));
    notifyListeners();
  }

  Future<ExternalRegulationValidationResult> submitImpact(
    ExternalRegulationImpactDraft draft,
  ) async {
    final ExternalRegulationValidationResult validation =
        ExternalRegulationValidator.validate(draft);
    if (!validation.isValid || validation.normalizedRecord == null) {
      _validationErrors = validation.errors;
      _statusBanner = '入力内容に不備があります。必須項目と整合性を確認してください。';
      notifyListeners();
      return validation;
    }

    _validationErrors = const <String>[];
    _isSubmitting = true;
    notifyListeners();

    ExternalRegulationImpact savedRecord = validation.normalizedRecord!;
    String alertMessage = '「事実確認待ち」ステータスで記録しました。';

    try {
      if (savedRecord.requiresAlertWorkflow && _alertDispatcher != null) {
        final RegulationAlertDispatchResult dispatchResult =
            await _alertDispatcher(savedRecord);
        if (dispatchResult.issueUrl.isNotEmpty) {
          savedRecord = savedRecord.copyWith(
            escalationIssueUrl: dispatchResult.issueUrl,
          );
        }
        alertMessage = dispatchResult.message;
      } else if (savedRecord.requiresAlertWorkflow) {
        alertMessage =
            '影響度が「${savedRecord.impactLevel.labelJa}」のため、GitHub Actions '
            '(`external-regulation-impact-alert.yml`) による自動Issue作成対象として「事実確認待ち」で記録しました。';
      }

      final SupabaseClient? client = _resolveClientOrNull();
      final String? userId = client?.auth.currentUser?.id;
      if (client != null && userId != null) {
        await client
            .from('external_regulation_impacts')
            .insert(savedRecord.toInsertPayload(userId));
      }

      _items.insert(0, savedRecord);
      _statusBanner = alertMessage;
      return ExternalRegulationValidationResult(
        isValid: true,
        errors: const <String>[],
        normalizedRecord: savedRecord,
      );
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  void clearValidationErrors() {
    if (_validationErrors.isEmpty && _statusBanner.isEmpty) {
      return;
    }
    _validationErrors = const <String>[];
    _statusBanner = '';
    notifyListeners();
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
