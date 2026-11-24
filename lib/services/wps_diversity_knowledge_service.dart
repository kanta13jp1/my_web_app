import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum WpsKnowledgeSource {
  notebooklm('notebooklm', 'NotebookLM'),
  aiMonitor('ai_monitor', 'AIツール監視'),
  manual('manual', '手動登録');

  const WpsKnowledgeSource(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static WpsKnowledgeSource parse(Object? raw) {
    final normalized = (raw?.toString() ?? '').trim().toLowerCase();
    for (final value in WpsKnowledgeSource.values) {
      if (value.wireValue == normalized) return value;
    }
    return WpsKnowledgeSource.manual;
  }
}

enum WpsTopicCategory {
  wps('wps', 'WPS'),
  diversity('diversity', 'ダイバーシティ'),
  gender('gender', 'ジェンダー'),
  humanRights('human_rights', '人権・行動計画'),
  general('general', '一般');

  const WpsTopicCategory(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static WpsTopicCategory parse(Object? raw) {
    final normalized = (raw?.toString() ?? '').trim().toLowerCase();
    for (final value in WpsTopicCategory.values) {
      if (value.wireValue == normalized) return value;
    }
    return WpsTopicCategory.general;
  }
}

enum WpsPolicyReviewStatus {
  pendingReview('pending_review', '管理者レビュー待ち'),
  approved('approved', '承認済み'),
  needsRevision('needs_revision', '修正依頼');

  const WpsPolicyReviewStatus(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static WpsPolicyReviewStatus parse(Object? raw) {
    final normalized = (raw?.toString() ?? '').trim().toLowerCase();
    for (final value in WpsPolicyReviewStatus.values) {
      if (value.wireValue == normalized) return value;
    }
    return WpsPolicyReviewStatus.pendingReview;
  }
}

@immutable
class WpsTaggingResult {
  const WpsTaggingResult({
    required this.tags,
    required this.primaryTopic,
    required this.frameworkReferences,
    required this.matchedKeywords,
    required this.confidenceScore,
    required this.referenceUrl,
    required this.requiresAdminReview,
    required this.suggestedReviewStatus,
  });

  final List<String> tags;
  final WpsTopicCategory primaryTopic;
  final List<String> frameworkReferences;
  final List<String> matchedKeywords;
  final int confidenceScore;
  final String referenceUrl;
  final bool requiresAdminReview;
  final WpsPolicyReviewStatus suggestedReviewStatus;
}

class WpsDiversityKnowledgeTagger {
  const WpsDiversityKnowledgeTagger._();

  static const String unscr1325Url = 'https://www.un.org/womenwatch/osagi/wps/';
  static const String mofaWpsNap3Url =
      'https://www.mofa.go.jp/mofaj/fp/hr_hr/page22_001965.html';

  static const String unscr1325Reference =
      'UNSCR 1325 (S/RES/1325, 2000-10-31): equal participation in prevention, '
      'peacebuilding, humanitarian response & protection against gender-based violence';
  static const String mofaNap3Reference =
      '外務省 第3次女性・平和・安全保障に関する行動計画（2023–2028年度）';

  static const List<(WpsTopicCategory, String, int, List<String>)> _rules =
      <(WpsTopicCategory, String, int, List<String>)>[
    (
      WpsTopicCategory.wps,
      'WPS',
      40,
      <String>[
        'wps',
        '女性・平和・安全保障',
        'women, peace and security',
        'women peace and security',
        'unscr 1325',
        's/res/1325',
        '安保理決議第1325号',
        '安保理決議1325',
        '第3次wps行動計画',
        '第3次行動計画',
      ],
    ),
    (
      WpsTopicCategory.diversity,
      'ダイバーシティ',
      30,
      <String>[
        'ダイバーシティ',
        'diversity',
        'インクルージョン',
        'inclusion',
        'de&i',
        'dei',
        '多様性方針',
        '多様性',
        '多文化共生',
      ],
    ),
    (
      WpsTopicCategory.gender,
      'ジェンダー',
      30,
      <String>[
        'ジェンダー',
        'gender',
        'ジェンダー平等',
        '男女共同参画',
        '女性活躍',
        'gender equality',
        '女性参画',
      ],
    ),
    (
      WpsTopicCategory.humanRights,
      '人権・行動計画',
      20,
      <String>[
        '行動計画',
        '人権',
        'human rights',
        'humanitarian',
        '紛争予防',
        '平和構築',
        'gender-based violence',
        'ジェンダーに基づく暴力',
      ],
    ),
  ];

  static const List<String> _unscrTriggers = <String>[
    'unscr 1325',
    's/res/1325',
    '1325',
    'wps',
    '女性・平和・安全保障',
    'women, peace and security',
    'women peace and security',
  ];

  static const List<String> _mofaNap3Triggers = <String>[
    '第3次',
    '第３次',
    '2023–2028',
    '2023-2028',
    '外務省',
    'mofa',
    'wps行動計画',
  ];

  static String sanitizeReferenceUrl(String rawUrl) {
    final cleaned = rawUrl.trim();
    if (cleaned.isEmpty) return '';
    final parsed = Uri.tryParse(cleaned);
    if (parsed == null) {
      return '';
    }
    final scheme = parsed.scheme.toLowerCase();
    if ((scheme != 'http' && scheme != 'https') || parsed.host.isEmpty) {
      return '';
    }
    return cleaned;
  }

  static WpsTaggingResult classify({
    required String title,
    required String content,
    String referenceUrl = '',
  }) {
    final haystack = '${title.trim()}\n${content.trim()}'.toLowerCase();
    final tags = <String>[];
    final matchedKeywords = <String>[];
    final seenKw = <String>{};
    final topicScores = <WpsTopicCategory, int>{};

    for (final (category, tagLabel, weight, keywords) in _rules) {
      var hits = 0;
      for (final kw in keywords) {
        if (haystack.contains(kw.toLowerCase())) {
          hits += 1;
          if (seenKw.add(kw)) {
            matchedKeywords.add(kw);
          }
        }
      }
      if (hits > 0) {
        tags.add(tagLabel);
        topicScores[category] = weight + (hits - 1) * 10;
      }
    }

    final hasUnscr = _unscrTriggers.any(haystack.contains);
    final hasMofaNap3 = _mofaNap3Triggers.any(haystack.contains);
    final frameworkRefs = <String>[
      if (hasUnscr) unscr1325Reference,
      if (hasMofaNap3) mofaNap3Reference,
    ];

    var resolvedUrl = sanitizeReferenceUrl(referenceUrl);
    if (resolvedUrl.isEmpty) {
      if (hasMofaNap3) {
        resolvedUrl = mofaWpsNap3Url;
      } else if (hasUnscr) {
        resolvedUrl = unscr1325Url;
      }
    }

    if (topicScores.isEmpty) {
      return WpsTaggingResult(
        tags: const <String>[],
        primaryTopic: WpsTopicCategory.general,
        frameworkReferences: List<String>.unmodifiable(frameworkRefs),
        matchedKeywords: const <String>[],
        confidenceScore: 0,
        referenceUrl: resolvedUrl,
        requiresAdminReview: false,
        suggestedReviewStatus: WpsPolicyReviewStatus.pendingReview,
      );
    }

    var primary = WpsTopicCategory.general;
    var bestScore = -1;
    var totalScore = 0;
    topicScores.forEach((category, score) {
      totalScore += score;
      if (score > bestScore) {
        bestScore = score;
        primary = category;
      }
    });

    return WpsTaggingResult(
      tags: List<String>.unmodifiable(tags),
      primaryTopic: primary,
      frameworkReferences: List<String>.unmodifiable(frameworkRefs),
      matchedKeywords: List<String>.unmodifiable(matchedKeywords),
      confidenceScore: totalScore > 100 ? 100 : totalScore,
      referenceUrl: resolvedUrl,
      requiresAdminReview: true,
      suggestedReviewStatus: WpsPolicyReviewStatus.pendingReview,
    );
  }
}

@immutable
class WpsDiversityPolicyItem {
  const WpsDiversityPolicyItem({
    required this.id,
    required this.userId,
    required this.intakeSource,
    required this.title,
    required this.summary,
    required this.primaryTopic,
    required this.policyTags,
    required this.frameworkReferences,
    required this.referenceUrl,
    required this.confidenceScore,
    required this.reviewStatus,
    this.reviewNote = '',
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final WpsKnowledgeSource intakeSource;
  final String title;
  final String summary;
  final WpsTopicCategory primaryTopic;
  final List<String> policyTags;
  final List<String> frameworkReferences;
  final String referenceUrl;
  final int confidenceScore;
  final WpsPolicyReviewStatus reviewStatus;
  final String reviewNote;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get hasSafeReferenceUrl =>
      WpsDiversityKnowledgeTagger.sanitizeReferenceUrl(referenceUrl).isNotEmpty;

  factory WpsDiversityPolicyItem.fromJson(Map<String, Object?> json) {
    final scoreRaw = json['confidence_score'];
    final score = scoreRaw is num
        ? scoreRaw.round().clamp(0, 100)
        : (int.tryParse(scoreRaw?.toString() ?? '') ?? 0).clamp(0, 100);
    return WpsDiversityPolicyItem(
      id: (json['id']?.toString() ?? '').trim(),
      userId: (json['user_id']?.toString() ?? '').trim(),
      intakeSource: WpsKnowledgeSource.parse(json['intake_source']),
      title: (json['title']?.toString() ?? '').trim(),
      summary: (json['summary']?.toString() ?? '').trim(),
      primaryTopic: WpsTopicCategory.parse(json['primary_topic']),
      policyTags: _parseStringList(json['policy_tags']),
      frameworkReferences: _parseStringList(json['framework_references']),
      referenceUrl: WpsDiversityKnowledgeTagger.sanitizeReferenceUrl(
        json['reference_url']?.toString() ?? '',
      ),
      confidenceScore: score,
      reviewStatus: WpsPolicyReviewStatus.parse(json['review_status']),
      reviewNote: (json['review_note']?.toString() ?? '').trim(),
      createdAt: _parseUtcDate(json['created_at']),
      updatedAt: _parseUtcDate(json['updated_at']),
    );
  }
}

@immutable
class WpsKnowledgeStats {
  const WpsKnowledgeStats({
    required this.totalCount,
    required this.pendingReviewCount,
    required this.approvedCount,
    required this.needsRevisionCount,
    required this.tagCounts,
  });

  final int totalCount;
  final int pendingReviewCount;
  final int approvedCount;
  final int needsRevisionCount;
  final Map<String, int> tagCounts;

  factory WpsKnowledgeStats.fromItems(List<WpsDiversityPolicyItem> items) {
    var pending = 0;
    var approved = 0;
    var needsRevision = 0;
    final counts = <String, int>{};

    for (final item in items) {
      switch (item.reviewStatus) {
        case WpsPolicyReviewStatus.pendingReview:
          pending += 1;
        case WpsPolicyReviewStatus.approved:
          approved += 1;
        case WpsPolicyReviewStatus.needsRevision:
          needsRevision += 1;
      }
      for (final tag in item.policyTags) {
        counts[tag] = (counts[tag] ?? 0) + 1;
      }
    }

    return WpsKnowledgeStats(
      totalCount: items.length,
      pendingReviewCount: pending,
      approvedCount: approved,
      needsRevisionCount: needsRevision,
      tagCounts: Map<String, int>.unmodifiable(counts),
    );
  }
}

abstract class WpsDiversityKnowledgeRepository {
  Future<List<WpsDiversityPolicyItem>> listPolicies({int limit = 50});

  Future<WpsDiversityPolicyItem> createTaggedPolicy({
    required String title,
    required String summary,
    WpsKnowledgeSource source = WpsKnowledgeSource.notebooklm,
    String referenceUrl = '',
  });

  Future<WpsDiversityPolicyItem> updateReview({
    required String id,
    required WpsPolicyReviewStatus status,
    String reviewNote = '',
    List<String>? overrideTags,
  });
}

typedef WpsSupabaseClientResolver = SupabaseClient Function();

/// `wps_diversity_policies` テーブルへの遅延解決 Supabase リポジトリ (#2585)。
class SupabaseWpsDiversityKnowledgeRepository
    implements WpsDiversityKnowledgeRepository {
  SupabaseWpsDiversityKnowledgeRepository({
    SupabaseClient? client,
    WpsSupabaseClientResolver? clientResolver,
  })  : _client = client,
        _clientResolver = clientResolver;

  final SupabaseClient? _client;
  final WpsSupabaseClientResolver? _clientResolver;

  SupabaseClient get _resolvedClient =>
      _client ??
      (_clientResolver != null ? _clientResolver() : Supabase.instance.client);

  @override
  Future<List<WpsDiversityPolicyItem>> listPolicies({int limit = 50}) async {
    final rows = await _resolvedClient
        .from('wps_diversity_policies')
        .select(
          'id, user_id, intake_source, title, summary, primary_topic, '
          'policy_tags, framework_references, reference_url, '
          'confidence_score, review_status, review_note, created_at, updated_at',
        )
        .order('updated_at', ascending: false)
        .limit(limit);
    return _extractRows(rows)
        .map(WpsDiversityPolicyItem.fromJson)
        .toList(growable: false);
  }

  @override
  Future<WpsDiversityPolicyItem> createTaggedPolicy({
    required String title,
    required String summary,
    WpsKnowledgeSource source = WpsKnowledgeSource.notebooklm,
    String referenceUrl = '',
  }) async {
    final userId = _resolvedClient.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw StateError('WPS・ダイバーシティ方針の登録にはログインが必要です');
    }
    final cleanTitle = title.trim();
    final cleanSummary = summary.trim();
    final tagged = WpsDiversityKnowledgeTagger.classify(
      title: cleanTitle,
      content: cleanSummary,
      referenceUrl: referenceUrl,
    );
    final inserted = await _resolvedClient
        .from('wps_diversity_policies')
        .insert(<String, Object?>{
          'user_id': userId,
          'intake_source': source.wireValue,
          'title': cleanTitle,
          'summary': cleanSummary,
          'primary_topic': tagged.primaryTopic.wireValue,
          'policy_tags': tagged.tags,
          'framework_references': tagged.frameworkReferences,
          'reference_url': tagged.referenceUrl,
          'confidence_score': tagged.confidenceScore,
          'review_status': tagged.suggestedReviewStatus.wireValue,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .select()
        .single();
    return WpsDiversityPolicyItem.fromJson(_asStringMap(inserted));
  }

  @override
  Future<WpsDiversityPolicyItem> updateReview({
    required String id,
    required WpsPolicyReviewStatus status,
    String reviewNote = '',
    List<String>? overrideTags,
  }) async {
    final reviewerId = _resolvedClient.auth.currentUser?.id;
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final payload = <String, Object?>{
      'review_status': status.wireValue,
      'review_note': reviewNote.trim(),
      'reviewed_at': nowIso,
      'updated_at': nowIso,
      if (reviewerId != null && reviewerId.isNotEmpty)
        'reviewed_by': reviewerId,
      if (overrideTags != null) 'policy_tags': overrideTags,
    };
    final updated = await _resolvedClient
        .from('wps_diversity_policies')
        .update(payload)
        .eq('id', id)
        .select()
        .single();
    return WpsDiversityPolicyItem.fromJson(_asStringMap(updated));
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

List<String> _parseStringList(Object? raw) {
  if (raw is! List<Object?>) return const <String>[];
  return List<String>.unmodifiable(
    raw
        .map((entry) => entry?.toString().trim() ?? '')
        .where((entry) => entry.isNotEmpty),
  );
}

DateTime? _parseUtcDate(Object? raw) {
  final text = raw?.toString().trim() ?? '';
  if (text.isEmpty) return null;
  return DateTime.tryParse(text)?.toUtc();
}
