import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../domain/unified_media_library_models.dart';

/// 統合メディアライブラリ状態管理・重複排除＆複数プロジェクト再利用制御 (#2714)。
class UnifiedMediaLibraryController extends ChangeNotifier {
  UnifiedMediaLibraryController({
    required UnifiedMediaLibraryRepository repository,
    List<UnifiedMediaAsset>? initialAssets,
  })  : _repository = repository,
        _assets = List<UnifiedMediaAsset>.from(
          initialAssets ?? const <UnifiedMediaAsset>[],
        );

  final UnifiedMediaLibraryRepository _repository;
  final List<UnifiedMediaAsset> _assets;

  bool _isBusy = false;
  bool _disposed = false;
  String _searchQuery = '';
  MediaAssetKind? _selectedKind;
  String _selectedTag = '';
  AutoTagModelPreference _selectedAiModel =
      AutoTagModelPreference.deterministicFallback;
  int _totalDeduplicatedBytesSaved = 0;
  String _statusMessage = '';
  String _errorMessage = '';

  List<UnifiedMediaAsset> get assets =>
      List<UnifiedMediaAsset>.unmodifiable(_assets);
  bool get isBusy => _isBusy;
  String get searchQuery => _searchQuery;
  MediaAssetKind? get selectedKind => _selectedKind;
  String get selectedTag => _selectedTag;
  AutoTagModelPreference get selectedAiModel => _selectedAiModel;
  int get totalDeduplicatedBytesSaved => _totalDeduplicatedBytesSaved;
  String get statusMessage => _statusMessage;
  String get errorMessage => _errorMessage;

  int get totalReuseCount {
    var total = 0;
    for (final UnifiedMediaAsset asset in _assets) {
      total += asset.reuseCount;
    }
    return total;
  }

  List<UnifiedMediaAsset> get filteredAssets {
    final String q = _searchQuery.trim().toLowerCase();
    final String t = _selectedTag.trim().toLowerCase();
    return _assets.where((UnifiedMediaAsset item) {
      if (_selectedKind != null && item.assetKind != _selectedKind) {
        return false;
      }
      if (t.isNotEmpty &&
          !item.allSearchTags.any(
            (String tag) => tag.toLowerCase() == t,
          )) {
        return false;
      }
      if (q.isNotEmpty) {
        final String hay =
            '${item.title} ${item.description} ${item.allSearchTags.join(' ')}'
                .toLowerCase();
        if (!hay.contains(q)) {
          return false;
        }
      }
      return true;
    }).toList(growable: false);
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    _notifySafely();
  }

  void selectKindFilter(MediaAssetKind? kind) {
    _selectedKind = kind;
    _notifySafely();
  }

  void selectTagFilter(String tag) {
    _selectedTag = tag.trim();
    _notifySafely();
  }

  void selectAiModel(AutoTagModelPreference model) {
    _selectedAiModel = model;
    _notifySafely();
  }

  Future<void> loadAssets() async {
    _isBusy = true;
    _errorMessage = '';
    _notifySafely();
    try {
      final List<UnifiedMediaAsset> loaded = await _repository.searchAssets();
      _assets
        ..clear()
        ..addAll(loaded);
      _statusMessage = '統合メディア ${_assets.length} 件を読み込みました。';
    } catch (error) {
      _errorMessage = 'メディア一覧の取得に失敗しました: $error';
    } finally {
      _isBusy = false;
      _notifySafely();
    }
  }

  Future<MediaUploadResult?> uploadOrDeduplicateTextPayload({
    required String title,
    required MediaAssetKind assetKind,
    required String rawPayloadText,
    String description = '',
    List<String> tags = const <String>[],
    String? projectKey,
    PipelineReuseStage pipelineStage = PipelineReuseStage.videoTimeline,
  }) async {
    final String cleanTitle = title.trim();
    if (cleanTitle.isEmpty || rawPayloadText.trim().isEmpty) {
      _errorMessage = 'タイトルとアセット内容を入力してください。';
      _notifySafely();
      return null;
    }
    final String base64Encoded = base64Encode(utf8.encode(rawPayloadText));
    _isBusy = true;
    _errorMessage = '';
    _notifySafely();
    try {
      final MediaUploadResult res = await _repository.uploadOrDeduplicateAsset(
        title: cleanTitle,
        assetKind: assetKind,
        contentBase64: base64Encoded,
        description: description,
        tags: tags,
        aiModel: _selectedAiModel,
        projectKey: projectKey,
        pipelineStage: pipelineStage,
      );
      _upsertAsset(res.asset);
      if (res.deduplicated) {
        _totalDeduplicatedBytesSaved += res.bytesSaved;
        _statusMessage =
            '同一SHA-256アセットを検出し、重複アップロードをスキップして再利用しました (${res.bytesSaved} B 節約)。';
      } else {
        _statusMessage = '${res.asset.title} をハッシュ重複管理付きで統合ライブラリへ登録しました。';
      }
      return res;
    } catch (error) {
      _errorMessage = 'アセット登録に失敗しました: $error';
      return null;
    } finally {
      _isBusy = false;
      _notifySafely();
    }
  }

  Future<bool> reuseAssetInProject({
    required UnifiedMediaAsset asset,
    required String projectKey,
    String projectTitle = '',
    PipelineReuseStage pipelineStage = PipelineReuseStage.videoTimeline,
  }) async {
    final String cleanProject = projectKey.trim();
    if (cleanProject.isEmpty) {
      _errorMessage = '再利用先のプロジェクトキーを入力してください。';
      _notifySafely();
      return false;
    }
    _isBusy = true;
    _errorMessage = '';
    _notifySafely();
    try {
      final UnifiedMediaAsset updated = await _repository.reuseAssetInProject(
        asset: asset,
        projectKey: cleanProject,
        projectTitle: projectTitle,
        pipelineStage: pipelineStage,
      );
      _upsertAsset(updated);
      _statusMessage =
          '${updated.title} をプロジェクト「$cleanProject」へ再利用紐付けしました (再利用 ${updated.reuseCount} 回)。';
      return true;
    } catch (error) {
      _errorMessage = 'プロジェクト再利用の記録に失敗しました: $error';
      return false;
    } finally {
      _isBusy = false;
      _notifySafely();
    }
  }

  Future<bool> updateAssetTags({
    required UnifiedMediaAsset asset,
    required List<String> tags,
    bool refreshAutoTags = false,
  }) async {
    _isBusy = true;
    _errorMessage = '';
    _notifySafely();
    try {
      final UnifiedMediaAsset updated = await _repository.updateAssetTags(
        asset: asset,
        tags: tags,
        refreshAutoTags: refreshAutoTags,
        aiModel: _selectedAiModel,
      );
      _upsertAsset(updated);
      _statusMessage = '${updated.title} の検索タグを更新しました。';
      return true;
    } catch (error) {
      _errorMessage = 'タグ更新に失敗しました: $error';
      return false;
    } finally {
      _isBusy = false;
      _notifySafely();
    }
  }

  Future<bool> deleteAsset(String assetId) async {
    _isBusy = true;
    _errorMessage = '';
    _notifySafely();
    try {
      await _repository.deleteAsset(assetId);
      _assets.removeWhere((UnifiedMediaAsset item) => item.id == assetId);
      _statusMessage = 'アセットを削除しました。';
      return true;
    } catch (error) {
      _errorMessage = '削除に失敗しました: $error';
      return false;
    } finally {
      _isBusy = false;
      _notifySafely();
    }
  }

  void _upsertAsset(UnifiedMediaAsset asset) {
    final int idx = _assets.indexWhere(
      (UnifiedMediaAsset item) => item.id == asset.id,
    );
    if (idx >= 0) {
      _assets[idx] = asset;
    } else {
      _assets.insert(0, asset);
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
