import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum IntakeSource {
  notebooklm('notebooklm', 'NotebookLM'),
  githubIssue('github_issue', 'GitHub Issue'),
  manual('manual', '手動入力');

  const IntakeSource(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static IntakeSource parse(Object? raw) {
    final normalized = (raw?.toString() ?? '').trim().toLowerCase();
    for (final value in IntakeSource.values) {
      if (value.wireValue == normalized) return value;
    }
    return IntakeSource.manual;
  }
}

enum ComplianceRiskCategory {
  none('none', 'リスクなし'),
  antitrust('antitrust', '独占禁止法'),
  competitionLaw('competition_law', '企業結合・競争法'),
  financialClaim('financial_claim', '財務・業績主張'),
  regulatory('regulatory', '業法・規制'),
  legalCompliance('legal_compliance', '法務・コンプライアンス');

  const ComplianceRiskCategory(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static ComplianceRiskCategory parse(Object? raw) {
    final normalized = (raw?.toString() ?? '').trim().toLowerCase();
    for (final value in ComplianceRiskCategory.values) {
      if (value.wireValue == normalized) return value;
    }
    return ComplianceRiskCategory.none;
  }
}

enum ComplianceReviewStatus {
  pending('pending', '確認待ち'),
  verifiedSafe('verified_safe', '確認済み'),
  flaggedHold('flagged_hold', '保留・要対処');

  const ComplianceReviewStatus(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static ComplianceReviewStatus parse(Object? raw) {
    final normalized = (raw?.toString() ?? '').trim().toLowerCase();
    for (final value in ComplianceReviewStatus.values) {
      if (value.wireValue == normalized) return value;
    }
    return ComplianceReviewStatus.pending;
  }
}

@immutable
class ComplianceClassificationResult {
  const ComplianceClassificationResult({
    required this.riskCategory,
    required this.riskScore,
    required this.matchedKeywords,
    required this.requiresVerification,
    required this.suggestedReviewStatus,
  });

  final ComplianceRiskCategory riskCategory;
  final int riskScore;
  final List<String> matchedKeywords;
  final bool requiresVerification;
  final ComplianceReviewStatus suggestedReviewStatus;
}

class IntakeComplianceClassifier {
  const IntakeComplianceClassifier._();

  static const List<(ComplianceRiskCategory, int, List<String>)> _rules =
      <(ComplianceRiskCategory, int, List<String>)>[
    (
      ComplianceRiskCategory.antitrust,
      40,
      <String>[
        '独占禁止法',
        '独禁法',
        'antitrust',
        'cartel',
        'カルテル',
        '談合',
        '優越的地位の濫用',
        '不公正な取引方法',
      ],
    ),
    (
      ComplianceRiskCategory.competitionLaw,
      35,
      <String>[
        '企業結合規制',
        '競争消費者法',
        '競争法',
        'merger control',
        'competition law',
        '公正取引委員会',
        'jftc',
        'accc',
        '市場支配力',
        'market dominance',
      ],
    ),
    (
      ComplianceRiskCategory.financialClaim,
      30,
      <String>[
        '財務予測',
        '売上予測',
        '業績予想',
        '利益保証',
        '株価予測',
        'earnings forecast',
        'revenue projection',
        'financial claim',
        '金融商品取引法',
        '金商法',
        'インサイダー取引',
        'insider trading',
        '有価証券報告書',
      ],
    ),
    (
      ComplianceRiskCategory.regulatory,
      25,
      <String>[
        '法規制',
        '輸出規制',
        'export control',
        '個人情報保護法',
        'gdpr',
        '薬機法',
        '景品表示法',
        '下請法',
        '外為法',
        '許認可',
        'regulatory',
        'sanctions',
      ],
    ),
    (
      ComplianceRiskCategory.legalCompliance,
      20,
      <String>[
        '法務リスク',
        'コンプライアンス違反',
        'compliance risk',
        'legal compliance',
        '著作権侵害',
        'copyright infringement',
        '特許侵害',
        'patent infringement',
        '訴訟リスク',
        'litigation',
        '契約違反',
        'breach of contract',
        '守秘義務違反',
      ],
    ),
  ];

  static ComplianceClassificationResult classify({
    required String title,
    required String content,
  }) {
    final haystack = '${title.trim()}\n${content.trim()}'.toLowerCase();
    final matched = <String>[];
    final seen = <String>{};
    final categoryScores = <ComplianceRiskCategory, int>{};

    for (final (category, weight, keywords) in _rules) {
      var hits = 0;
      for (final keyword in keywords) {
        if (haystack.contains(keyword.toLowerCase())) {
          hits += 1;
          if (seen.add(keyword)) {
            matched.add(keyword);
          }
        }
      }
      if (hits > 0) {
        categoryScores[category] = weight + (hits - 1) * 10;
      }
    }

    if (categoryScores.isEmpty) {
      return const ComplianceClassificationResult(
        riskCategory: ComplianceRiskCategory.none,
        riskScore: 0,
        matchedKeywords: <String>[],
        requiresVerification: false,
        suggestedReviewStatus: ComplianceReviewStatus.verifiedSafe,
      );
    }

    var primaryCategory = ComplianceRiskCategory.none;
    var bestScore = -1;
    var totalScore = 0;
    categoryScores.forEach((category, score) {
      totalScore += score;
      if (score > bestScore) {
        bestScore = score;
        primaryCategory = category;
      }
    });

    return ComplianceClassificationResult(
      riskCategory: primaryCategory,
      riskScore: totalScore > 100 ? 100 : totalScore,
      matchedKeywords: List<String>.unmodifiable(matched),
      requiresVerification: true,
      suggestedReviewStatus: ComplianceReviewStatus.pending,
    );
  }
}

@immutable
class IntakeComplianceScreeningItem {
  const IntakeComplianceScreeningItem({
    required this.id,
    required this.userId,
    required this.intakeSource,
    required this.title,
    required this.contentExcerpt,
    required this.riskCategory,
    required this.riskScore,
    required this.matchedKeywords,
    required this.requiresVerification,
    required this.reviewStatus,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final IntakeSource intakeSource;
  final String title;
  final String contentExcerpt;
  final ComplianceRiskCategory riskCategory;
  final int riskScore;
  final List<String> matchedKeywords;
  final bool requiresVerification;
  final ComplianceReviewStatus reviewStatus;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory IntakeComplianceScreeningItem.fromJson(Map<String, Object?> json) {
    final rawKeywords = json['matched_keywords'];
    final keywords = rawKeywords is List<Object?>
        ? rawKeywords
            .map((e) => e?.toString().trim() ?? '')
            .where((e) => e.isNotEmpty)
            .toList(growable: false)
        : const <String>[];
    final scoreRaw = json['risk_score'];
    final score = scoreRaw is num
        ? scoreRaw.round().clamp(0, 100)
        : (int.tryParse(scoreRaw?.toString() ?? '') ?? 0).clamp(0, 100);
    return IntakeComplianceScreeningItem(
      id: (json['id']?.toString() ?? '').trim(),
      userId: (json['user_id']?.toString() ?? '').trim(),
      intakeSource: IntakeSource.parse(json['intake_source']),
      title: (json['title']?.toString() ?? '').trim(),
      contentExcerpt: (json['content_excerpt']?.toString() ?? '').trim(),
      riskCategory: ComplianceRiskCategory.parse(json['risk_category']),
      riskScore: score,
      matchedKeywords: List<String>.unmodifiable(keywords),
      requiresVerification: json['requires_verification'] == true,
      reviewStatus: ComplianceReviewStatus.parse(json['review_status']),
      createdAt: _parseUtcDate(json['created_at']),
      updatedAt: _parseUtcDate(json['updated_at']),
    );
  }
}

abstract class IntakeComplianceRepository {
  Future<List<IntakeComplianceScreeningItem>> listScreenings({
    bool onlyRequiresVerification = false,
    int limit = 50,
  });

  Future<IntakeComplianceScreeningItem> screenAndSave({
    required String title,
    required String content,
    IntakeSource source = IntakeSource.manual,
  });

  Future<IntakeComplianceScreeningItem> updateReviewStatus({
    required String id,
    required ComplianceReviewStatus status,
  });
}

typedef ComplianceSupabaseClientResolver = SupabaseClient Function();

/// `intake_compliance_screenings` テーブルへの遅延解決 Supabase リポジトリ (#2595)。
class SupabaseIntakeComplianceRepository implements IntakeComplianceRepository {
  SupabaseIntakeComplianceRepository({
    SupabaseClient? client,
    ComplianceSupabaseClientResolver? clientResolver,
  })  : _client = client,
        _clientResolver = clientResolver;

  final SupabaseClient? _client;
  final ComplianceSupabaseClientResolver? _clientResolver;

  SupabaseClient get _resolvedClient =>
      _client ??
      (_clientResolver != null ? _clientResolver() : Supabase.instance.client);

  @override
  Future<List<IntakeComplianceScreeningItem>> listScreenings({
    bool onlyRequiresVerification = false,
    int limit = 50,
  }) async {
    var query = _resolvedClient.from('intake_compliance_screenings').select(
          'id, user_id, intake_source, title, content_excerpt, '
          'risk_category, risk_score, matched_keywords, '
          'requires_verification, review_status, created_at, updated_at',
        );
    if (onlyRequiresVerification) {
      query = query.eq('requires_verification', true);
    }
    final rows = await query.order('created_at', ascending: false).limit(limit);
    return _extractRows(rows)
        .map(IntakeComplianceScreeningItem.fromJson)
        .toList(growable: false);
  }

  @override
  Future<IntakeComplianceScreeningItem> screenAndSave({
    required String title,
    required String content,
    IntakeSource source = IntakeSource.manual,
  }) async {
    final userId = _resolvedClient.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw StateError('コンプライアンス記録の保存にはログインが必要です');
    }
    final cleanTitle = title.trim();
    final cleanContent = content.trim();
    final result = IntakeComplianceClassifier.classify(
      title: cleanTitle,
      content: cleanContent,
    );
    final excerpt = cleanContent.length > 300
        ? cleanContent.substring(0, 300)
        : cleanContent;
    final inserted = await _resolvedClient
        .from('intake_compliance_screenings')
        .insert(<String, Object?>{
          'user_id': userId,
          'intake_source': source.wireValue,
          'title': cleanTitle,
          'content_excerpt': excerpt,
          'risk_category': result.riskCategory.wireValue,
          'risk_score': result.riskScore,
          'matched_keywords': result.matchedKeywords,
          'requires_verification': result.requiresVerification,
          'review_status': result.suggestedReviewStatus.wireValue,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .select()
        .single();
    return IntakeComplianceScreeningItem.fromJson(_asStringMap(inserted));
  }

  @override
  Future<IntakeComplianceScreeningItem> updateReviewStatus({
    required String id,
    required ComplianceReviewStatus status,
  }) async {
    final requiresVerification = status != ComplianceReviewStatus.verifiedSafe;
    final updated = await _resolvedClient
        .from('intake_compliance_screenings')
        .update(<String, Object?>{
          'review_status': status.wireValue,
          'requires_verification': requiresVerification,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id)
        .select()
        .single();
    return IntakeComplianceScreeningItem.fromJson(_asStringMap(updated));
  }
}

List<Map<String, Object?>> _extractRows(Object? raw) {
  if (raw is! List<Object?>) return const <Map<String, Object?>>[];
  return raw
      .whereType<Map<Object?, Object?>>()
      .map(_asStringMap)
      .toList(growable: false);
}

Map<String, Object?> _asStringMap(Object? raw) {
  final result = <String, Object?>{};
  if (raw is Map<Object?, Object?>) {
    raw.forEach((key, value) {
      result[key.toString()] = value;
    });
  }
  return result;
}

DateTime? _parseUtcDate(Object? raw) {
  final text = raw?.toString().trim() ?? '';
  if (text.isEmpty) return null;
  return DateTime.tryParse(text)?.toUtc();
}
