import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../data/video_studio_gateway.dart';
import '../domain/video_studio_models.dart';

enum VideoStudioLoadStatus { initial, loading, ready, failure }

class VideoStudioViewModel extends ChangeNotifier {
  VideoStudioViewModel({
    required VideoStudioGateway gateway,
    Uuid uuid = const Uuid(),
    Duration pollInterval = const Duration(seconds: 8),
  })  : _gateway = gateway,
        _uuid = uuid,
        _pollInterval = pollInterval;

  final VideoStudioGateway _gateway;
  final Uuid _uuid;
  final Duration _pollInterval;

  VideoStudioLoadStatus _loadStatus = VideoStudioLoadStatus.initial;
  VideoStudioCatalog? _catalog;
  VideoCreditBalance _balance = VideoCreditBalance.zero;
  List<VideoGenerationJob> _jobs = const [];
  List<VideoImprovementAuthorization> _authorizations = const [];
  VideoGenerationJob? _activeJob;
  String _prompt = '';
  int _durationSeconds = 5;
  String _aspectRatio = '16:9';
  String _resolution = '720p';
  bool _rightsConfirmed = false;
  bool _adultConfirmed = false;
  bool _isGenerating = false;
  bool _isRefreshing = false;
  String? _openingOutputJobId;
  bool _isOpeningCheckout = false;
  bool _isAuthorizingImprovement = false;
  String? _revokingAuthorizationId;
  int _authorizationValidityHours = 168;
  int _authorizationRegenerations = 2;
  String? _reviewingArtifactId;
  String? _parentArtifactId;
  String? _appliedReviewId;
  String? _appliedImprovementTitle;
  bool _authenticationRequired = false;
  String? _errorMessage;
  String? _noticeMessage;
  String? _idempotencyKey;
  Timer? _pollTimer;

  VideoStudioLoadStatus get loadStatus => _loadStatus;
  VideoStudioCatalog? get catalog => _catalog;
  VideoCreditBalance get balance => _balance;
  List<VideoGenerationJob> get jobs => List.unmodifiable(_jobs);
  List<VideoImprovementAuthorization> get authorizations =>
      List.unmodifiable(_authorizations);
  VideoGenerationJob? get activeJob => _activeJob;
  String get prompt => _prompt;
  int get durationSeconds => _durationSeconds;
  String get aspectRatio => _aspectRatio;
  String get resolution => _resolution;
  bool get rightsConfirmed => _rightsConfirmed;
  bool get adultConfirmed => _adultConfirmed;
  bool get isGenerating => _isGenerating;
  bool get isRefreshing => _isRefreshing;
  String? get openingOutputJobId => _openingOutputJobId;
  bool get isOpeningCheckout => _isOpeningCheckout;
  bool get isAuthorizingImprovement => _isAuthorizingImprovement;
  String? get revokingAuthorizationId => _revokingAuthorizationId;
  int get authorizationValidityHours => _authorizationValidityHours;
  int get authorizationRegenerations => _authorizationRegenerations;
  int get authorizationTotalCredits =>
      requiredCredits * _authorizationRegenerations;
  String? get reviewingArtifactId => _reviewingArtifactId;
  String? get parentArtifactId => _parentArtifactId;
  String? get appliedReviewId => _appliedReviewId;
  String? get appliedImprovementTitle => _appliedImprovementTitle;
  bool get hasAppliedImprovement =>
      _parentArtifactId != null && _appliedReviewId != null;
  VideoImprovementAuthorization? get activeAuthorization {
    for (final authorization in _authorizations) {
      if (authorization.isActive) return authorization;
    }
    return null;
  }

  VideoImprovementAuthorization? get matchingActiveAuthorization {
    final sourceArtifactId = _parentArtifactId;
    if (sourceArtifactId == null) return null;
    for (final authorization in _authorizations) {
      if (authorization.isActive &&
          _isArtifactInLineage(
            sourceArtifactId,
            authorization.rootArtifactId,
          )) {
        return authorization;
      }
    }
    return null;
  }

  bool get authenticationRequired => _authenticationRequired;
  String? get errorMessage => _errorMessage;
  String? get noticeMessage => _noticeMessage;

  VideoGenerationModelOption? get selectedModel {
    final models = _catalog?.models ?? const [];
    return models.isEmpty ? null : models.first;
  }

  int get requiredCredits =>
      (selectedModel?.creditsPerSecond ?? 0) * _durationSeconds;
  bool get hasEnoughCredits => _balance.availableCredits >= requiredCredits;
  bool get canGenerate =>
      _loadStatus == VideoStudioLoadStatus.ready &&
      !_isGenerating &&
      (_activeJob == null || _activeJob!.isTerminal) &&
      _prompt.trim().length >= 3 &&
      _rightsConfirmed &&
      _adultConfirmed &&
      hasEnoughCredits;
  bool get canAuthorizeImprovement =>
      _loadStatus == VideoStudioLoadStatus.ready &&
      hasAppliedImprovement &&
      !_isAuthorizingImprovement &&
      (_activeJob == null || _activeJob!.isTerminal) &&
      _rightsConfirmed &&
      _adultConfirmed &&
      matchingActiveAuthorization == null;
  bool get canRunAuthorizedImprovement =>
      _loadStatus == VideoStudioLoadStatus.ready &&
      hasAppliedImprovement &&
      matchingActiveAuthorization != null &&
      !_isAuthorizingImprovement &&
      (_activeJob == null || _activeJob!.isTerminal) &&
      _rightsConfirmed &&
      _adultConfirmed;

  Future<void> load({Uri? currentUri}) async {
    _loadStatus = VideoStudioLoadStatus.loading;
    _authenticationRequired = false;
    _errorMessage = null;
    _noticeMessage =
        currentUri?.queryParameters['billing'] == 'video_credits_success'
            ? '決済を受け付けました。残高への反映に数秒かかる場合があります。'
            : null;
    notifyListeners();
    try {
      final results = await Future.wait<Object>([
        _gateway.loadCatalog(),
        _gateway.loadBalance(),
        _gateway.listJobs(),
        _gateway.loadAuthorizations(),
      ]);
      _catalog = results[0] as VideoStudioCatalog;
      _balance = results[1] as VideoCreditBalance;
      _jobs = results[2] as List<VideoGenerationJob>;
      _authorizations = results[3] as List<VideoImprovementAuthorization>;
      if (_catalog?.models.isEmpty ?? true) {
        throw const VideoStudioException('catalog_empty');
      }
      final running = _jobs.where((job) => !job.isTerminal).toList();
      _activeJob = running.isEmpty ? null : running.first;
      if (_activeJob == null) _restorePendingImprovement();
      _loadStatus = VideoStudioLoadStatus.ready;
      if (_activeJob != null) _startPolling();
    } catch (error) {
      _loadStatus = VideoStudioLoadStatus.failure;
      _authenticationRequired = error is VideoStudioException &&
          error.code == 'authentication_required';
      _errorMessage = _friendlyError(error);
    }
    notifyListeners();
  }

  void setPrompt(String value) {
    if (_prompt == value) return;
    _prompt = value;
    _idempotencyKey = null;
    notifyListeners();
  }

  void setDuration(int value) {
    if (_durationSeconds == value) return;
    _durationSeconds = value;
    _idempotencyKey = null;
    notifyListeners();
  }

  void setAspectRatio(String value) {
    if (_aspectRatio == value) return;
    _aspectRatio = value;
    _idempotencyKey = null;
    notifyListeners();
  }

  void setResolution(String value) {
    if (_resolution == value) return;
    _resolution = value;
    _idempotencyKey = null;
    notifyListeners();
  }

  void setRightsConfirmed(bool value) {
    if (_rightsConfirmed == value) return;
    _rightsConfirmed = value;
    notifyListeners();
  }

  void setAdultConfirmed(bool value) {
    if (_adultConfirmed == value) return;
    _adultConfirmed = value;
    notifyListeners();
  }

  void setAuthorizationValidityHours(int value) {
    if (![24, 168, 720].contains(value) ||
        _authorizationValidityHours == value) {
      return;
    }
    _authorizationValidityHours = value;
    notifyListeners();
  }

  void setAuthorizationRegenerations(int value) {
    if (![1, 2, 3, 5].contains(value) || _authorizationRegenerations == value) {
      return;
    }
    _authorizationRegenerations = value;
    notifyListeners();
  }

  Future<bool> authorizeAndGenerateImprovement() async {
    if (!canAuthorizeImprovement) return false;
    final sourceArtifactId = _parentArtifactId!;
    final sourceReviewId = _appliedReviewId!;
    _isAuthorizingImprovement = true;
    _errorMessage = null;
    _noticeMessage = null;
    _idempotencyKey ??= _uuid.v4().replaceAll('-', '');
    notifyListeners();
    try {
      final result = await _gateway.authorizeImprovement(
        idempotencyKey: _idempotencyKey!,
        sourceArtifactId: sourceArtifactId,
        sourceReviewId: sourceReviewId,
        validityHours: _authorizationValidityHours,
        totalRegenerations: _authorizationRegenerations,
      );
      _authorizations = [
        result.authorization,
        ..._authorizations.where(
          (authorization) => authorization.id != result.authorization.id,
        ),
      ];
      _balance = result.balance;
      _idempotencyKey = null;
      final job = result.job;
      if (job != null) {
        _activeJob = job;
        _replaceJob(job);
        _parentArtifactId = null;
        _appliedReviewId = null;
        _appliedImprovementTitle = null;
        _noticeMessage = '継続承認 ${result.authorization.id} を保存し、最初の改善生成を開始しました。';
        if (!job.isTerminal) _startPolling();
      } else {
        _noticeMessage = _pendingAuthorizationNotice(result.authorization);
      }
      return true;
    } catch (error) {
      _errorMessage = _friendlyError(error);
      return false;
    } finally {
      _isAuthorizingImprovement = false;
      notifyListeners();
    }
  }

  Future<bool> runAuthorizedImprovement() async {
    final authorization = matchingActiveAuthorization;
    if (!canRunAuthorizedImprovement || authorization == null) return false;
    final sourceArtifactId = _parentArtifactId!;
    final sourceReviewId = _appliedReviewId!;
    _isAuthorizingImprovement = true;
    _errorMessage = null;
    _noticeMessage = null;
    _idempotencyKey ??= _uuid.v4().replaceAll('-', '');
    notifyListeners();
    try {
      final result = await _gateway.runAuthorizedImprovement(
        idempotencyKey: _idempotencyKey!,
        authorizationId: authorization.id,
        sourceArtifactId: sourceArtifactId,
        sourceReviewId: sourceReviewId,
      );
      _authorizations = [
        result.authorization,
        ..._authorizations.where(
          (existing) => existing.id != result.authorization.id,
        ),
      ];
      _balance = result.balance;
      _idempotencyKey = null;
      final job = result.job;
      if (job != null) {
        _activeJob = job;
        _replaceJob(job);
        _parentArtifactId = null;
        _appliedReviewId = null;
        _appliedImprovementTitle = null;
        _noticeMessage = '継続承認 ${result.authorization.id} の残枠で改善生成を開始しました。';
        if (!job.isTerminal) _startPolling();
      } else {
        _noticeMessage = _pendingAuthorizationNotice(result.authorization);
      }
      return true;
    } catch (error) {
      _errorMessage = _friendlyError(error);
      return false;
    } finally {
      _isAuthorizingImprovement = false;
      notifyListeners();
    }
  }

  Future<bool> revokeAuthorization(String authorizationId) async {
    if (_revokingAuthorizationId != null) return false;
    _revokingAuthorizationId = authorizationId;
    _errorMessage = null;
    notifyListeners();
    try {
      final revoked = await _gateway.revokeAuthorization(authorizationId);
      _authorizations = [
        revoked,
        ..._authorizations.where(
          (authorization) => authorization.id != authorizationId,
        ),
      ];
      _noticeMessage = '継続承認を停止しました。進行中の生成には影響しません。';
      return true;
    } catch (error) {
      _errorMessage = _friendlyError(error);
      return false;
    } finally {
      _revokingAuthorizationId = null;
      notifyListeners();
    }
  }

  Future<bool> generate() async {
    if (!canGenerate) return false;
    _isGenerating = true;
    _errorMessage = null;
    _noticeMessage = null;
    _idempotencyKey ??= _uuid.v4().replaceAll('-', '');
    notifyListeners();
    try {
      final result = await _gateway.createJob(
        idempotencyKey: _idempotencyKey!,
        modelKey: selectedModel!.key,
        prompt: _prompt.trim(),
        durationSeconds: _durationSeconds,
        aspectRatio: _aspectRatio,
        resolution: _resolution,
        parentArtifactId: _parentArtifactId,
        appliedReviewId: _appliedReviewId,
      );
      _activeJob = result.job;
      _balance = result.balance;
      _replaceJob(result.job);
      _idempotencyKey = null;
      _parentArtifactId = null;
      _appliedReviewId = null;
      _appliedImprovementTitle = null;
      _noticeMessage = '生成を受け付けました。完了までこの画面で自動更新します。';
      if (!result.job.isTerminal) _startPolling();
      return true;
    } catch (error) {
      _errorMessage = _friendlyError(error);
      return false;
    } finally {
      _isGenerating = false;
      notifyListeners();
    }
  }

  Future<void> refreshActiveJob() async {
    final active = _activeJob;
    if (active == null || active.isTerminal || _isRefreshing) return;
    _isRefreshing = true;
    notifyListeners();
    try {
      final refreshed = await _gateway.refreshJob(active.id);
      _activeJob = refreshed;
      _replaceJob(refreshed);
      if (refreshed.isTerminal) {
        _pollTimer?.cancel();
        final refreshedState = await Future.wait<Object>([
          _gateway.loadBalance(),
          _gateway.loadAuthorizations(),
        ]);
        _balance = refreshedState[0] as VideoCreditBalance;
        _authorizations =
            refreshedState[1] as List<VideoImprovementAuthorization>;
        _noticeMessage = refreshed.isSuccessful
            ? '動画が完成しました。リンクは1時間有効です。'
            : '生成に失敗したため、予約クレジットを返却しました。';
      }
    } catch (error) {
      _errorMessage = _friendlyError(error);
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }

  Future<Uri?> loadOutputUrl(VideoGenerationJob job) async {
    if (!job.isSuccessful || _openingOutputJobId != null) return null;
    final expiresAt = job.outputExpiresAt;
    if (job.outputUrl != null &&
        expiresAt != null &&
        expiresAt.isAfter(DateTime.now().add(const Duration(minutes: 1)))) {
      return job.outputUrl;
    }
    _openingOutputJobId = job.id;
    _errorMessage = null;
    notifyListeners();
    try {
      final refreshed = await _gateway.refreshJob(job.id);
      _replaceJob(refreshed);
      if (_activeJob?.id == refreshed.id) _activeJob = refreshed;
      if (!refreshed.isSuccessful || refreshed.outputUrl == null) {
        throw const VideoStudioException('output_not_ready');
      }
      return refreshed.outputUrl;
    } catch (error) {
      _errorMessage = _friendlyError(error);
      return null;
    } finally {
      _openingOutputJobId = null;
      notifyListeners();
    }
  }

  Future<Uri?> createCheckout(String packKey, String returnUrl) async {
    if (_isOpeningCheckout) return null;
    _isOpeningCheckout = true;
    _errorMessage = null;
    notifyListeners();
    try {
      return await _gateway.createCreditCheckout(
        packKey: packKey,
        returnUrl: returnUrl,
      );
    } catch (error) {
      _errorMessage = _friendlyError(error);
      return null;
    } finally {
      _isOpeningCheckout = false;
      notifyListeners();
    }
  }

  Future<bool> reviewArtifact(
    VideoGenerationJob job,
    VideoArtifactReviewDraft review, {
    bool applyToNextGeneration = true,
  }) async {
    final artifact = job.artifact;
    if (artifact == null || _reviewingArtifactId != null) return false;
    _reviewingArtifactId = artifact.id;
    _errorMessage = null;
    notifyListeners();
    try {
      final result = await _gateway.reviewArtifact(
        artifactId: artifact.id,
        review: review,
      );
      final updatedJob = job.withArtifact(result.artifact);
      _replaceJob(updatedJob);
      if (_activeJob?.id == updatedJob.id) _activeJob = updatedJob;
      if (applyToNextGeneration && review.decision == 'improve') {
        _prompt = result.review.suggestedPrompt;
        _durationSeconds = job.durationSeconds;
        _aspectRatio = job.aspectRatio;
        _resolution = job.resolution;
        _parentArtifactId = result.artifact.id;
        _appliedReviewId = result.review.id;
        _appliedImprovementTitle = result.artifact.title;
        _idempotencyKey = null;
        _noticeMessage = 'レビューを保存し、改善版プロンプトを次回生成へ反映しました。';
      } else {
        _noticeMessage = 'レビューを保存しました。動画は販売候補の素材として保管されています。';
      }
      return true;
    } catch (error) {
      _errorMessage = _friendlyError(error);
      return false;
    } finally {
      _reviewingArtifactId = null;
      notifyListeners();
    }
  }

  void clearAppliedImprovement() {
    if (!hasAppliedImprovement) return;
    _parentArtifactId = null;
    _appliedReviewId = null;
    _appliedImprovementTitle = null;
    _idempotencyKey = null;
    notifyListeners();
  }

  void _replaceJob(VideoGenerationJob job) {
    _jobs = [job, ..._jobs.where((existing) => existing.id != job.id)];
  }

  void _restorePendingImprovement() {
    final consumedReviewIds =
        _jobs.map((job) => job.appliedReviewId).whereType<String>().toSet();
    for (final job in _jobs) {
      final artifact = job.artifact;
      final review = artifact?.latestReview;
      if (artifact == null ||
          review == null ||
          review.decision != 'improve' ||
          consumedReviewIds.contains(review.id)) {
        continue;
      }
      _prompt = review.suggestedPrompt;
      _durationSeconds = job.durationSeconds;
      _aspectRatio = job.aspectRatio;
      _resolution = job.resolution;
      _parentArtifactId = artifact.id;
      _appliedReviewId = review.id;
      _appliedImprovementTitle = artifact.title;
      return;
    }
  }

  bool _isArtifactInLineage(String artifactId, String rootArtifactId) {
    final artifacts = <String, VideoArtifact>{};
    for (final job in _jobs) {
      final artifact = job.artifact;
      if (artifact != null) artifacts[artifact.id] = artifact;
    }
    var currentId = artifactId;
    final visited = <String>{};
    while (visited.add(currentId)) {
      if (currentId == rootArtifactId) return true;
      final parent = artifacts[currentId]?.parentArtifactId;
      if (parent == null) return false;
      currentId = parent;
    }
    return false;
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      _pollInterval,
      (_) => unawaited(refreshActiveJob()),
    );
  }

  String _friendlyError(Object error) {
    final code = error is VideoStudioException ? error.code : '';
    return switch (code) {
      'authentication_required' => 'この機能を使うにはログインしてください。',
      'insufficient_video_credits' => '動画クレジットが不足しています。',
      'generation_already_active' => 'すでに生成中の動画があります。完了後に次の動画を作成できます。',
      'generation_queue_unavailable' => '生成キューへ登録できませんでした。クレジットは返却済みです。',
      'worker_temporarily_unavailable' => '生成状況を確認できませんでした。少し待って再試行します。',
      'prompt_not_allowed' => 'この内容は生成できません。プロンプトを変更してください。',
      'output_not_ready' => '完成動画を取得できませんでした。少し待って再度お試しください。',
      'artifact_not_found' => '保存済み動画素材を確認できませんでした。再読み込みしてください。',
      'invalid_review_score' ||
      'invalid_review_decision' ||
      'invalid_review_clearance' ||
      'invalid_review_text' =>
        'レビュー内容を確認してください。点数は1〜5、次回プロンプトは1000文字以内です。',
      'generation_iteration_unavailable' =>
        '改善履歴を生成ジョブへ関連付けられませんでした。クレジットは返却済みです。',
      'improvement_review_already_consumed' =>
        'このレビューはすでに改善生成へ使用されています。履歴を再読み込みしてください。',
      'improvement_review_is_not_latest' =>
        '新しいレビューが追加されています。再読み込みして最新の改善案を選んでください。',
      'artifact_clearance_blocked' => '権利またはプライバシーがブロックされた素材は再生成できません。',
      'invalid_authorization_expiry' ||
      'invalid_authorization_iterations' =>
        '継続承認の有効期限または反復回数を確認してください。',
      'authorization_confirmations_required' => '権利・年齢・利用規約・禁止事項への同意が必要です。',
      'authorization_not_found' ||
      'video_authorization_inactive' =>
        '継続承認を確認できません。最新状態を読み込んでください。',
      'video_authorization_exhausted' => '継続承認のクレジットまたは反復回数を使い切りました。',
      'video_credit_checkout_unavailable' => '購入画面を開けませんでした。時間をおいて再度お試しください。',
      _ => '動画サービスに接続できませんでした。時間をおいて再度お試しください。',
    };
  }

  String _pendingAuthorizationNotice(
    VideoImprovementAuthorization authorization,
  ) {
    final reasons = authorization.pendingReasons;
    final details = <String>[
      if (reasons.contains('review_consumed')) '指定レビューは使用済みです',
      if (reasons.contains('review_not_latest')) '最新レビューの選択が必要です',
      if (reasons.contains('review_not_improve')) '改善判定のレビューが必要です',
      if (reasons.contains('insufficient_credits')) '300 credits以上の残高が必要です',
      if (reasons.contains('active_generation')) '現在の生成完了を待っています',
    ];
    final suffix = details.isEmpty ? '実行条件の成立を待っています' : details.join('・');
    return '継続承認 ${authorization.id} を保存しました。$suffix。条件成立後に同じ承認IDで再開します。';
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}
