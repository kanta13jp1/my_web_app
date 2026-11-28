import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// アーリーアクセス権限ティア（Obsidian Catalyst の Insider / Supporter / VIP 着想）。
///
/// 現在は非課金（招待・オプトイン限定）として運用し、決済連携は一切含まない。
/// 将来的に有料支援ティアを導入する場合は、決済プラットフォーム規約・法的審査が別途必要。
enum EarlyAccessTier {
  standard(
    rank: 0,
    dbValue: 'standard',
    labelJa: 'Standard (一般)',
    badgeLabel: 'STANDARD',
    summaryJa: '一般向けの標準公開機能および一般先行機能のみ利用できます。',
  ),
  insider(
    rank: 1,
    dbValue: 'insider',
    labelJa: 'Insider (早期実験)',
    badgeLabel: 'INSIDER',
    summaryJa: '開発初期の先行実験フラグ（Insider 枠）を有効化できます。',
  ),
  supporter(
    rank: 2,
    dbValue: 'supporter',
    labelJa: 'Supporter (先行プレビュー)',
    badgeLabel: 'SUPPORTER',
    summaryJa: 'Insider 機能に加え、主要プレビュー機能（Supporter 枠）を解放します。',
  ),
  vip(
    rank: 3,
    dbValue: 'vip',
    labelJa: 'VIP (最優先ラボ)',
    badgeLabel: 'VIP',
    summaryJa: 'すべてのアーリーアクセス実験機能（VIP ラボ含む）をテストできます。',
  );

  const EarlyAccessTier({
    required this.rank,
    required this.dbValue,
    required this.labelJa,
    required this.badgeLabel,
    required this.summaryJa,
  });

  final int rank;
  final String dbValue;
  final String labelJa;
  final String badgeLabel;
  final String summaryJa;

  static EarlyAccessTier fromDb(String? raw) {
    final String normalized = (raw ?? '').trim().toLowerCase();
    for (final EarlyAccessTier tier in EarlyAccessTier.values) {
      if (tier.dbValue == normalized) {
        return tier;
      }
    }
    return EarlyAccessTier.standard;
  }

  static EarlyAccessTier maxTier(EarlyAccessTier a, EarlyAccessTier b) {
    return a.rank >= b.rank ? a : b;
  }
}

/// アーリーアクセス機能向けフィードバック種別。
enum EarlyAccessFeedbackCategory {
  bug('bug', 'バグ報告', 'bug'),
  enhancement('enhancement', '改善要望', 'enhancement'),
  ux('ux', 'UX改善', 'ux'),
  feedback('feedback', '感想', 'early-access');

  const EarlyAccessFeedbackCategory(
    this.dbValue,
    this.labelJa,
    this.githubLabel,
  );

  final String dbValue;
  final String labelJa;
  final String githubLabel;

  static EarlyAccessFeedbackCategory fromDb(String? raw) {
    final String normalized = (raw ?? '').trim().toLowerCase();
    for (final EarlyAccessFeedbackCategory cat
        in EarlyAccessFeedbackCategory.values) {
      if (cat.dbValue == normalized) {
        return cat;
      }
    }
    return EarlyAccessFeedbackCategory.feedback;
  }
}

/// 同期間状態の分類。
enum EarlyAccessSyncStatus {
  synced('synced', '同期済み'),
  queuedOffline('queued_offline', 'オフライン待機中');

  const EarlyAccessSyncStatus(this.dbValue, this.labelJa);

  final String dbValue;
  final String labelJa;
}

/// フィーチャーフラグ定義モデル。
@immutable
class EarlyAccessFeatureFlag {
  const EarlyAccessFeatureFlag({
    required this.flagKey,
    required this.title,
    required this.description,
    required this.minTier,
    this.isActive = true,
    this.feedbackLabel = 'early-access',
    this.monetizationEnabled = false,
  });

  final String flagKey;
  final String title;
  final String description;
  final EarlyAccessTier minTier;
  final bool isActive;
  final String feedbackLabel;
  final bool monetizationEnabled;

  factory EarlyAccessFeatureFlag.fromJson(Map<String, Object?> json) {
    return EarlyAccessFeatureFlag(
      flagKey: (json['flag_key'] as String? ?? '').trim(),
      title: (json['title'] as String? ?? '').trim(),
      description: (json['description'] as String? ?? '').trim(),
      minTier: EarlyAccessTier.fromDb(json['min_tier'] as String?),
      isActive: json['is_active'] as bool? ?? true,
      feedbackLabel:
          (json['feedback_label'] as String? ?? 'early-access').trim(),
      monetizationEnabled: json['monetization_enabled'] as bool? ?? false,
    );
  }
}

/// GitHub Issue 連携用の送信ペイロード。
@immutable
class EarlyAccessFeedbackDraft {
  const EarlyAccessFeedbackDraft({
    required this.flagKey,
    required this.flagTitle,
    required this.feedbackLabel,
    required this.tier,
    required this.category,
    required this.title,
    required this.body,
  });

  final String flagKey;
  final String flagTitle;
  final String feedbackLabel;
  final EarlyAccessTier tier;
  final EarlyAccessFeedbackCategory category;
  final String title;
  final String body;
}

/// GitHub Issue 作成レスポンスモデル。
@immutable
class GitHubIssueDispatchResult {
  const GitHubIssueDispatchResult({
    this.issueNumber,
    this.issueUrl,
    required this.dispatchedToGitHub,
    this.statusMessage = '',
  });

  final int? issueNumber;
  final String? issueUrl;
  final bool dispatchedToGitHub;
  final String statusMessage;
}

/// 送信済み・待機中フィードバック記録モデル。
@immutable
class EarlyAccessFeedbackRecord {
  const EarlyAccessFeedbackRecord({
    required this.id,
    required this.flagKey,
    required this.accessTierSnapshot,
    required this.category,
    required this.title,
    required this.body,
    required this.status,
    this.githubIssueNumber,
    this.githubIssueUrl,
    required this.createdAtIso,
    required this.syncStatus,
  });

  final String id;
  final String flagKey;
  final EarlyAccessTier accessTierSnapshot;
  final EarlyAccessFeedbackCategory category;
  final String title;
  final String body;
  final String status;
  final int? githubIssueNumber;
  final String? githubIssueUrl;
  final String createdAtIso;
  final EarlyAccessSyncStatus syncStatus;

  EarlyAccessFeedbackRecord copyWith({
    String? status,
    int? githubIssueNumber,
    String? githubIssueUrl,
    EarlyAccessSyncStatus? syncStatus,
  }) {
    return EarlyAccessFeedbackRecord(
      id: id,
      flagKey: flagKey,
      accessTierSnapshot: accessTierSnapshot,
      category: category,
      title: title,
      body: body,
      status: status ?? this.status,
      githubIssueNumber: githubIssueNumber ?? this.githubIssueNumber,
      githubIssueUrl: githubIssueUrl ?? this.githubIssueUrl,
      createdAtIso: createdAtIso,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'flag_key': flagKey,
      'access_tier_snapshot': accessTierSnapshot.dbValue,
      'category': category.dbValue,
      'title': title,
      'body': body,
      'status': status,
      'github_issue_number': githubIssueNumber,
      'github_issue_url': githubIssueUrl,
      'created_at': createdAtIso,
      'sync_status': syncStatus.dbValue,
    };
  }

  factory EarlyAccessFeedbackRecord.fromJson(Map<String, Object?> json) {
    final String rawSync =
        (json['sync_status'] as String? ?? 'synced').trim().toLowerCase();
    return EarlyAccessFeedbackRecord(
      id: (json['id'] as String? ?? '').trim(),
      flagKey: (json['flag_key'] as String? ?? '').trim(),
      accessTierSnapshot: EarlyAccessTier.fromDb(
        json['access_tier_snapshot'] as String?,
      ),
      category: EarlyAccessFeedbackCategory.fromDb(json['category'] as String?),
      title: (json['title'] as String? ?? '').trim(),
      body: (json['body'] as String? ?? '').trim(),
      status: (json['status'] as String? ?? 'submitted').trim(),
      githubIssueNumber: (json['github_issue_number'] as num?)?.toInt(),
      githubIssueUrl: json['github_issue_url'] as String?,
      createdAtIso: (json['created_at'] as String? ?? '').trim(),
      syncStatus: rawSync == EarlyAccessSyncStatus.queuedOffline.dbValue
          ? EarlyAccessSyncStatus.queuedOffline
          : EarlyAccessSyncStatus.synced,
    );
  }
}

/// 決定論的なアーリーアクセス判定・GitHub Issue ペイロード生成ロジック。
class EarlyAccessPolicyEvaluator {
  const EarlyAccessPolicyEvaluator._();

  static const int minTitleLength = 4;
  static const int maxTitleLength = 120;
  static const int minBodyLength = 10;
  static const int maxBodyLength = 4000;

  static const List<EarlyAccessFeatureFlag> defaultCatalog =
      <EarlyAccessFeatureFlag>[
    EarlyAccessFeatureFlag(
      flagKey: 'offline_vault_prefetch',
      title: 'オフライン要約キャッシュ (一般先行)',
      description: '直近閲覧したノートの要約インデックスを端末内キャッシュへプリフェッチする標準先行フラグです。',
      minTier: EarlyAccessTier.standard,
      feedbackLabel: 'early-access-standard',
    ),
    EarlyAccessFeatureFlag(
      flagKey: 'ai_voice_macro_v2',
      title: '音声コマンド・マクロ v2 (Insider)',
      description: '音声メモ入力から日次タスク候補と要約を連続生成する Insider 向け先行実験機能です。',
      minTier: EarlyAccessTier.insider,
      feedbackLabel: 'early-access-insider',
    ),
    EarlyAccessFeatureFlag(
      flagKey: 'knowledge_graph_3d_preview',
      title: 'ナレッジグラフ空間プレビュー (Supporter)',
      description: 'ノートの関連性とタグクラスタを立体的に俯瞰する Supporter 向けプレビュー機能です。',
      minTier: EarlyAccessTier.supporter,
      feedbackLabel: 'early-access-supporter',
    ),
    EarlyAccessFeatureFlag(
      flagKey: 'multi_agent_sprint_board',
      title: '自律エージェント進捗ライブボード (VIP)',
      description: '複数エージェントの並列タスク進捗とボトルネックをリアルタイム監視する VIP 向け先行画面です。',
      minTier: EarlyAccessTier.vip,
      feedbackLabel: 'early-access-vip',
    ),
  ];

  /// 管理者のみ変更可能な Supabase Auth `app_metadata` から権限ティアを解釈する。
  /// クライアント編集可能な `user_metadata` はセキュリティ上一切信頼しない。
  static EarlyAccessTier parseTierFromAppMetadata(
    Map<String, Object?>? appMetadata,
  ) {
    if (appMetadata == null || appMetadata.isEmpty) {
      return EarlyAccessTier.standard;
    }
    final Object? raw = appMetadata['early_access_tier'];
    if (raw is String) {
      return EarlyAccessTier.fromDb(raw);
    }
    return EarlyAccessTier.standard;
  }

  /// 指定された権限ティアでフィーチャーフラグを解放・オプトイン可能か判定する。
  static bool isFlagUnlocked(
    EarlyAccessTier userTier,
    EarlyAccessFeatureFlag flag,
  ) {
    if (!flag.isActive || flag.monetizationEnabled) {
      return false;
    }
    return userTier.rank >= flag.minTier.rank;
  }

  /// 権限に応じて現在解放済みのフラグ一覧を返す。
  static List<EarlyAccessFeatureFlag> unlockedFlagsFor(
    EarlyAccessTier userTier,
    List<EarlyAccessFeatureFlag> catalog,
  ) {
    return catalog
        .where((EarlyAccessFeatureFlag flag) => isFlagUnlocked(userTier, flag))
        .toList(growable: false);
  }

  /// フィードバック入力バリデーション。正常時は `null` を返す。
  static String? validateFeedbackInput({
    required String title,
    required String body,
  }) {
    final String trimmedTitle = title.trim();
    if (trimmedTitle.length < minTitleLength ||
        trimmedTitle.length > maxTitleLength) {
      return 'タイトルは $minTitleLength〜$maxTitleLength 文字で入力してください。';
    }
    final String trimmedBody = body.trim();
    if (trimmedBody.length < minBodyLength ||
        trimmedBody.length > maxBodyLength) {
      return 'フィードバック詳細は $minBodyLength〜$maxBodyLength 文字で入力してください。';
    }
    return null;
  }

  /// GitHub Issues API / Edge Function 連携用の構造化ペイロードを生成する。
  static Map<String, Object?> buildGitHubIssuePayload(
    EarlyAccessFeedbackDraft draft,
  ) {
    final String sanitizedTitle = draft.title.trim();
    final String sanitizedBody = draft.body.trim();
    final List<String> labels = <String>{
      'early-access',
      draft.feedbackLabel,
      draft.category.githubLabel,
    }.toList(growable: false);

    final String issueBody = <String>[
      '## アーリーアクセス機能フィードバック',
      '',
      '- **対象フィーチャーフラグ**: `${draft.flagKey}` (${draft.flagTitle})',
      '- **検証ティア**: `${draft.tier.dbValue}`',
      '- **カテゴリ**: ${draft.category.labelJa} (`${draft.category.dbValue}`)',
      '',
      '### 詳細内容',
      '',
      sanitizedBody,
    ].join('\n');

    return <String, Object?>{
      'title': '[Early Access: ${draft.flagKey}] $sanitizedTitle',
      'body': issueBody,
      'labels': labels,
      'flag_key': draft.flagKey,
      'tier': draft.tier.dbValue,
      'category': draft.category.dbValue,
    };
  }
}

/// オフライン待機キャッシュの抽象化。
abstract class EarlyAccessCacheStore {
  Future<String?> readJson();
  Future<void> writeJson(String raw);
}

/// テスト用インメモリキャッシュ実装。
class InMemoryEarlyAccessCacheStore implements EarlyAccessCacheStore {
  InMemoryEarlyAccessCacheStore([this._raw]);

  String? _raw;

  @override
  Future<String?> readJson() async => _raw;

  @override
  Future<void> writeJson(String raw) async {
    _raw = raw;
  }
}

/// SharedPreferences キャッシュ実装。
class SharedPreferencesEarlyAccessCacheStore implements EarlyAccessCacheStore {
  const SharedPreferencesEarlyAccessCacheStore({
    this.storageKey = 'early_access_feature_hub_cache_v1',
  });

  final String storageKey;

  @override
  Future<String?> readJson() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(storageKey);
  }

  @override
  Future<void> writeJson(String raw) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, raw);
  }
}

typedef EarlyAccessIssueDispatcher = Future<GitHubIssueDispatchResult> Function(
  EarlyAccessFeedbackDraft draft,
);

/// 段階的アーリーアクセス・フィーチャーフラグ・フィードバック連携状態管理サービス。
class EarlyAccessFeatureService extends ChangeNotifier {
  EarlyAccessFeatureService({
    SupabaseClient Function()? clientResolver,
    EarlyAccessCacheStore? cacheStore,
    EarlyAccessIssueDispatcher? issueDispatcher,
    Map<String, Object?>? Function()? appMetadataResolver,
    DateTime Function()? nowProvider,
    List<EarlyAccessFeatureFlag>? initialCatalog,
    EarlyAccessTier initialEnrollmentTier = EarlyAccessTier.standard,
  })  : _clientResolver = clientResolver,
        _cacheStore =
            cacheStore ?? const SharedPreferencesEarlyAccessCacheStore(),
        _issueDispatcher = issueDispatcher,
        _appMetadataResolver = appMetadataResolver,
        _nowProvider = nowProvider ?? DateTime.now,
        _catalog = List<EarlyAccessFeatureFlag>.unmodifiable(
          initialCatalog ?? EarlyAccessPolicyEvaluator.defaultCatalog,
        ),
        _enrollmentTier = initialEnrollmentTier;

  final SupabaseClient Function()? _clientResolver;
  final EarlyAccessCacheStore _cacheStore;
  final EarlyAccessIssueDispatcher? _issueDispatcher;
  final Map<String, Object?>? Function()? _appMetadataResolver;
  final DateTime Function() _nowProvider;

  List<EarlyAccessFeatureFlag> _catalog;
  EarlyAccessTier _enrollmentTier;
  EarlyAccessTier _appMetadataTier = EarlyAccessTier.standard;
  final Set<String> _optedInFlags = <String>{};
  final List<EarlyAccessFeedbackRecord> _feedbackRecords =
      <EarlyAccessFeedbackRecord>[];

  bool _isLoading = false;
  bool _isSubmittingFeedback = false;
  bool _disposed = false;
  String _statusMessage = '';
  EarlyAccessSyncStatus _optInSyncStatus = EarlyAccessSyncStatus.synced;

  List<EarlyAccessFeatureFlag> get catalog => _catalog;
  EarlyAccessTier get enrollmentTier => _enrollmentTier;
  EarlyAccessTier get appMetadataTier => _appMetadataTier;
  EarlyAccessTier get effectiveTier =>
      EarlyAccessTier.maxTier(_enrollmentTier, _appMetadataTier);
  Set<String> get optedInFlags => Set<String>.unmodifiable(_optedInFlags);
  List<EarlyAccessFeedbackRecord> get feedbackRecords =>
      List<EarlyAccessFeedbackRecord>.unmodifiable(_feedbackRecords);
  bool get isLoading => _isLoading;
  bool get isSubmittingFeedback => _isSubmittingFeedback;
  String get statusMessage => _statusMessage;
  EarlyAccessSyncStatus get optInSyncStatus => _optInSyncStatus;

  List<EarlyAccessFeatureFlag> get unlockedFlags =>
      EarlyAccessPolicyEvaluator.unlockedFlagsFor(effectiveTier, _catalog);

  bool isFlagUnlocked(EarlyAccessFeatureFlag flag) =>
      EarlyAccessPolicyEvaluator.isFlagUnlocked(effectiveTier, flag);

  bool isFlagOptedIn(String flagKey) {
    final EarlyAccessFeatureFlag? flag = _findFlag(flagKey);
    if (flag == null || !isFlagUnlocked(flag)) {
      return false;
    }
    return _optedInFlags.contains(flagKey);
  }

  /// Supabase Auth `app_metadata` とキャッシュ・DB 登録状態を読み込む。
  Future<void> loadInitialData() async {
    _isLoading = true;
    _notifySafely();
    try {
      _refreshAppMetadataTierOnly();
      await _restoreFromCache();

      final SupabaseClient? client = _tryResolveClient();
      final String? userId = client?.auth.currentUser?.id;
      if (client != null && userId != null) {
        final List<Object?> flagRows = await client
            .from('early_access_feature_flags')
            .select()
            .eq('is_active', true)
            .order('min_tier', ascending: true);
        if (flagRows.isNotEmpty) {
          _catalog = List<EarlyAccessFeatureFlag>.unmodifiable(
            flagRows
                .whereType<Map<String, Object?>>()
                .map(EarlyAccessFeatureFlag.fromJson),
          );
        }

        final Map<String, Object?>? enrollmentRow = await client
            .from('early_access_enrollments')
            .select()
            .eq('user_id', userId)
            .maybeSingle();
        if (enrollmentRow != null) {
          _enrollmentTier = EarlyAccessTier.fromDb(
            enrollmentRow['access_tier'] as String?,
          );
          final List<Object?> rawOpted =
              enrollmentRow['opted_in_flags'] as List<Object?>? ??
                  const <Object?>[];
          _optedInFlags
            ..clear()
            ..addAll(rawOpted.whereType<String>());
          _pruneLockedOptIns();
        }

        final List<Object?> feedbackRows = await client
            .from('early_access_feedback')
            .select()
            .eq('user_id', userId)
            .order('created_at', ascending: false);
        _feedbackRecords
          ..clear()
          ..addAll(
            feedbackRows
                .whereType<Map<String, Object?>>()
                .map(EarlyAccessFeedbackRecord.fromJson),
          );
        _statusMessage = 'アーリーアクセス権限とフラグ状態を取得しました。';
      } else {
        _statusMessage = 'ローカル構成でアーリーアクセスハブを初期化しました（非課金・オプトイン限定）。';
      }
      await _persistCache();
    } catch (_) {
      _statusMessage = '一部リモート同期に失敗したため、ローカルキャッシュから復元しました。';
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  /// Supabase Auth `app_metadata`（または注入済み検証クロージャ）を再読込して権限を更新する。
  void refreshAppMetadataAccess() {
    _refreshAppMetadataTierOnly();
    _pruneLockedOptIns();
    _statusMessage = '認証メタデータから権限ティア (${effectiveTier.badgeLabel}) を再評価しました。';
    _notifySafely();
  }

  /// 開発中フィーチャーフラグのオプトイン設定を切り替える。
  /// 権限不足フラグや無効化されたフラグは明示的に拒否する。
  Future<bool> toggleFeatureFlag(String flagKey, bool enabled) async {
    final EarlyAccessFeatureFlag? flag = _findFlag(flagKey);
    if (flag == null) {
      _statusMessage = '対象のフィーチャーフラグ ($flagKey) が見つかりません。';
      _notifySafely();
      return false;
    }
    if (enabled && !isFlagUnlocked(flag)) {
      _statusMessage =
          '「${flag.title}」の利用には ${flag.minTier.badgeLabel} 以上の権限が必要です。';
      _notifySafely();
      return false;
    }

    if (enabled) {
      _optedInFlags.add(flagKey);
    } else {
      _optedInFlags.remove(flagKey);
    }

    try {
      final SupabaseClient? client = _tryResolveClient();
      final String? userId = client?.auth.currentUser?.id;
      if (client != null && userId != null) {
        final Map<String, Object?>? existing = await client
            .from('early_access_enrollments')
            .select('id')
            .eq('user_id', userId)
            .maybeSingle();
        if (existing != null) {
          await client
              .from('early_access_enrollments')
              .update(<String, Object?>{
            'opted_in_flags': _optedInFlags.toList(growable: false),
          }).eq('user_id', userId);
        } else {
          await client.from('early_access_enrollments').insert(
            <String, Object?>{
              'user_id': userId,
              'opted_in_flags': _optedInFlags.toList(growable: false),
            },
          );
        }
      }
      _optInSyncStatus = EarlyAccessSyncStatus.synced;
      _statusMessage =
          enabled ? '「${flag.title}」を有効化しました。' : '「${flag.title}」を無効化しました。';
      await _persistCache();
      _notifySafely();
      return true;
    } catch (_) {
      _optInSyncStatus = EarlyAccessSyncStatus.queuedOffline;
      _statusMessage = 'オフラインのため「${flag.title}」の切替を端末内へ保存しました（後で再同期されます）。';
      await _persistCache();
      _notifySafely();
      return false;
    }
  }

  /// アーリーアクセス機能画面から GitHub Issues へ直結するフィードバックを送信する。
  Future<EarlyAccessFeedbackRecord?> submitFeedback({
    required String flagKey,
    required EarlyAccessFeedbackCategory category,
    required String title,
    required String body,
  }) async {
    final EarlyAccessFeatureFlag? flag = _findFlag(flagKey);
    if (flag == null) {
      _statusMessage = '対象のフィーチャーフラグが見つかりません。';
      _notifySafely();
      return null;
    }
    final String? validationError =
        EarlyAccessPolicyEvaluator.validateFeedbackInput(
      title: title,
      body: body,
    );
    if (validationError != null) {
      _statusMessage = validationError;
      _notifySafely();
      return null;
    }

    _isSubmittingFeedback = true;
    _notifySafely();

    final String nowIso = _nowProvider().toUtc().toIso8601String();
    final EarlyAccessFeedbackDraft draft = EarlyAccessFeedbackDraft(
      flagKey: flag.flagKey,
      flagTitle: flag.title,
      feedbackLabel: flag.feedbackLabel,
      tier: effectiveTier,
      category: category,
      title: title.trim(),
      body: body.trim(),
    );

    EarlyAccessFeedbackRecord record = EarlyAccessFeedbackRecord(
      id: 'ea-fb-${_nowProvider().microsecondsSinceEpoch}',
      flagKey: flag.flagKey,
      accessTierSnapshot: effectiveTier,
      category: category,
      title: draft.title,
      body: draft.body,
      status: 'submitted',
      createdAtIso: nowIso,
      syncStatus: EarlyAccessSyncStatus.queuedOffline,
    );

    try {
      final GitHubIssueDispatchResult dispatchResult =
          await _dispatchToGitHub(draft);
      record = record.copyWith(
        status: dispatchResult.dispatchedToGitHub
            ? 'linked_to_github'
            : 'submitted',
        githubIssueNumber: dispatchResult.issueNumber,
        githubIssueUrl: dispatchResult.issueUrl,
        syncStatus: dispatchResult.dispatchedToGitHub
            ? EarlyAccessSyncStatus.synced
            : EarlyAccessSyncStatus.queuedOffline,
      );
      _feedbackRecords.insert(0, record);
      await _persistFeedbackRowIfConnected(record);
      _statusMessage = dispatchResult.dispatchedToGitHub &&
              dispatchResult.issueNumber != null
          ? 'フィードバックを GitHub Issue #${dispatchResult.issueNumber} として登録しました。'
          : 'フィードバックを送信キューへ保存しました。';
      await _persistCache();
      return record;
    } catch (_) {
      _feedbackRecords.insert(0, record);
      _statusMessage = '通信または GitHub Issue 連携でエラーが発生したため、オフライン送信待機キューへ保存しました。';
      await _persistCache();
      return record;
    } finally {
      _isSubmittingFeedback = false;
      _notifySafely();
    }
  }

  /// オフライン待機状態のフィードバックを再送信する。
  Future<int> retryPendingFeedback() async {
    int retriedSuccess = 0;
    for (int i = 0; i < _feedbackRecords.length; i++) {
      final EarlyAccessFeedbackRecord existing = _feedbackRecords[i];
      if (existing.syncStatus != EarlyAccessSyncStatus.queuedOffline) {
        continue;
      }
      final EarlyAccessFeatureFlag? flag = _findFlag(existing.flagKey);
      if (flag == null) {
        continue;
      }
      try {
        final GitHubIssueDispatchResult result = await _dispatchToGitHub(
          EarlyAccessFeedbackDraft(
            flagKey: flag.flagKey,
            flagTitle: flag.title,
            feedbackLabel: flag.feedbackLabel,
            tier: existing.accessTierSnapshot,
            category: existing.category,
            title: existing.title,
            body: existing.body,
          ),
        );
        if (result.dispatchedToGitHub) {
          _feedbackRecords[i] = existing.copyWith(
            status: 'linked_to_github',
            githubIssueNumber: result.issueNumber,
            githubIssueUrl: result.issueUrl,
            syncStatus: EarlyAccessSyncStatus.synced,
          );
          retriedSuccess++;
        }
      } catch (_) {
        // 個別失敗時は次件を妨げず待機状態を維持する
      }
    }
    if (retriedSuccess > 0) {
      _statusMessage = 'オフライン待機中のフィードバック $retriedSuccess 件を GitHub へ同期しました。';
      await _persistCache();
    } else {
      _statusMessage = '再送信可能なフィードバックを同期できませんでした。';
    }
    _notifySafely();
    return retriedSuccess;
  }

  Future<GitHubIssueDispatchResult> _dispatchToGitHub(
    EarlyAccessFeedbackDraft draft,
  ) async {
    final EarlyAccessIssueDispatcher? custom = _issueDispatcher;
    if (custom != null) {
      return custom(draft);
    }
    final SupabaseClient? client = _tryResolveClient();
    if (client == null || client.auth.currentUser == null) {
      throw StateError('Supabase client unavailable for GitHub Issue dispatch');
    }
    final Map<String, Object?> payload =
        EarlyAccessPolicyEvaluator.buildGitHubIssuePayload(draft);
    final FunctionResponse response = await client.functions.invoke(
      'core-hub',
      body: <String, Object?>{
        'action': 'early_access.submit_feedback',
        'payload': payload,
      },
    );
    final Object? data = response.data;
    if (data is Map<String, Object?>) {
      return GitHubIssueDispatchResult(
        issueNumber: (data['issue_number'] as num?)?.toInt(),
        issueUrl: data['issue_url'] as String?,
        dispatchedToGitHub: true,
      );
    }
    return const GitHubIssueDispatchResult(dispatchedToGitHub: true);
  }

  Future<void> _persistFeedbackRowIfConnected(
    EarlyAccessFeedbackRecord record,
  ) async {
    final SupabaseClient? client = _tryResolveClient();
    final String? userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) {
      return;
    }
    await client.from('early_access_feedback').insert(
      <String, Object?>{
        'user_id': userId,
        'flag_key': record.flagKey,
        'access_tier_snapshot': record.accessTierSnapshot.dbValue,
        'category': record.category.dbValue,
        'title': record.title,
        'body': record.body,
      },
    );
  }

  void _refreshAppMetadataTierOnly() {
    final Map<String, Object?>? Function()? resolver = _appMetadataResolver;
    if (resolver != null) {
      _appMetadataTier =
          EarlyAccessPolicyEvaluator.parseTierFromAppMetadata(resolver());
      return;
    }
    final SupabaseClient? client = _tryResolveClient();
    _appMetadataTier = EarlyAccessPolicyEvaluator.parseTierFromAppMetadata(
      client?.auth.currentUser?.appMetadata,
    );
  }

  void _pruneLockedOptIns() {
    final Set<String> unlockedKeys = unlockedFlags
        .map((EarlyAccessFeatureFlag flag) => flag.flagKey)
        .toSet();
    _optedInFlags.removeWhere((String key) => !unlockedKeys.contains(key));
  }

  EarlyAccessFeatureFlag? _findFlag(String flagKey) {
    for (final EarlyAccessFeatureFlag flag in _catalog) {
      if (flag.flagKey == flagKey) {
        return flag;
      }
    }
    return null;
  }

  Future<void> _restoreFromCache() async {
    final String? raw = await _cacheStore.readJson();
    if (raw == null || raw.trim().isEmpty) {
      return;
    }
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?>) {
        return;
      }
      final List<Object?> rawOpted =
          decoded['opted_in_flags'] as List<Object?>? ?? const <Object?>[];
      _optedInFlags
        ..clear()
        ..addAll(rawOpted.whereType<String>());
      _pruneLockedOptIns();

      final List<Object?> rawFeedback =
          decoded['feedback_records'] as List<Object?>? ?? const <Object?>[];
      _feedbackRecords
        ..clear()
        ..addAll(
          rawFeedback
              .whereType<Map<String, Object?>>()
              .map(EarlyAccessFeedbackRecord.fromJson),
        );
    } catch (_) {
      // 破損キャッシュは無視し初期状態を維持する
    }
  }

  Future<void> _persistCache() async {
    final String encoded = jsonEncode(
      <String, Object?>{
        'opted_in_flags': _optedInFlags.toList(growable: false),
        'feedback_records': _feedbackRecords
            .map((EarlyAccessFeedbackRecord r) => r.toJson())
            .toList(growable: false),
      },
    );
    await _cacheStore.writeJson(encoded);
  }

  SupabaseClient? _tryResolveClient() {
    final SupabaseClient Function()? resolver = _clientResolver;
    if (resolver != null) {
      return resolver();
    }
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  void _notifySafely() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    super.dispose();
  }
}
