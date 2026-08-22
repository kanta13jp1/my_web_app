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
  bool _authenticationRequired = false;
  String? _errorMessage;
  String? _noticeMessage;
  String? _idempotencyKey;
  Timer? _pollTimer;

  VideoStudioLoadStatus get loadStatus => _loadStatus;
  VideoStudioCatalog? get catalog => _catalog;
  VideoCreditBalance get balance => _balance;
  List<VideoGenerationJob> get jobs => List.unmodifiable(_jobs);
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
      ]);
      _catalog = results[0] as VideoStudioCatalog;
      _balance = results[1] as VideoCreditBalance;
      _jobs = results[2] as List<VideoGenerationJob>;
      if (_catalog?.models.isEmpty ?? true) {
        throw const VideoStudioException('catalog_empty');
      }
      final running = _jobs.where((job) => !job.isTerminal).toList();
      _activeJob = running.isEmpty ? null : running.first;
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
      );
      _activeJob = result.job;
      _balance = result.balance;
      _replaceJob(result.job);
      _idempotencyKey = null;
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
        _balance = await _gateway.loadBalance();
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

  void _replaceJob(VideoGenerationJob job) {
    _jobs = [job, ..._jobs.where((existing) => existing.id != job.id)];
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
      'video_credit_checkout_unavailable' => '購入画面を開けませんでした。時間をおいて再度お試しください。',
      _ => '動画サービスに接続できませんでした。時間をおいて再度お試しください。',
    };
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}
