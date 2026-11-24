import 'package:flutter/foundation.dart';

import '../domain/image_moderation_models.dart';

/// 画像モデレーション・タグ検索 UI のイミュータブル状態 (#2644).
@immutable
class ImageModerationState {
  const ImageModerationState({
    required this.assets,
    required this.selectedTag,
    required this.searchQuery,
    required this.includeRestricted,
    required this.externalTransferConsented,
    required this.isLoading,
    required this.isSubmitting,
    this.errorMessage,
  });

  factory ImageModerationState.initial() {
    return const ImageModerationState(
      assets: <ModeratedImageAsset>[],
      selectedTag: '',
      searchQuery: '',
      includeRestricted: false,
      externalTransferConsented: false,
      isLoading: false,
      isSubmitting: false,
    );
  }

  final List<ModeratedImageAsset> assets;
  final String selectedTag;
  final String searchQuery;
  final bool includeRestricted;
  final bool externalTransferConsented;
  final bool isLoading;
  final bool isSubmitting;
  final String? errorMessage;

  List<String> get availableTags {
    final tags = <String>[];
    for (final asset in assets) {
      for (final tag in asset.tags) {
        if (!tags.contains(tag)) {
          tags.add(tag);
        }
      }
    }
    tags.sort();
    return List<String>.unmodifiable(tags);
  }

  List<ModeratedImageAsset> get filteredAssets {
    final normalizedQuery = searchQuery.trim().toLowerCase();
    return assets.where((asset) {
      if (!includeRestricted && asset.isRestricted) {
        return false;
      }
      if (selectedTag.isNotEmpty && !asset.tags.contains(selectedTag)) {
        return false;
      }
      if (normalizedQuery.isEmpty) {
        return true;
      }
      final matchesPath =
          asset.storagePath.toLowerCase().contains(normalizedQuery);
      final matchesTag =
          asset.tags.any((tag) => tag.toLowerCase().contains(normalizedQuery));
      return matchesPath || matchesTag;
    }).toList(growable: false);
  }

  int get hiddenOrFlaggedCount =>
      assets.where((asset) => asset.isRestricted).length;

  ImageModerationState copyWith({
    List<ModeratedImageAsset>? assets,
    String? selectedTag,
    String? searchQuery,
    bool? includeRestricted,
    bool? externalTransferConsented,
    bool? isLoading,
    bool? isSubmitting,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ImageModerationState(
      assets: assets ?? this.assets,
      selectedTag: selectedTag ?? this.selectedTag,
      searchQuery: searchQuery ?? this.searchQuery,
      includeRestricted: includeRestricted ?? this.includeRestricted,
      externalTransferConsented:
          externalTransferConsented ?? this.externalTransferConsented,
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// ViT 画像解析・タグ絞り込み・同意状態管理 Controller (#2644).
class ImageModerationController extends ChangeNotifier {
  ImageModerationController({
    required ImageModerationRepository repository,
  }) : _repository = repository;

  final ImageModerationRepository _repository;
  ImageModerationState _state = ImageModerationState.initial();
  bool _isDisposed = false;

  ImageModerationState get state => _state;
  bool get isDisposed => _isDisposed;

  void _setState(ImageModerationState next) {
    if (_isDisposed) {
      return;
    }
    _state = next;
    notifyListeners();
  }

  Future<void> loadAssets() async {
    if (_isDisposed) {
      return;
    }
    _setState(_state.copyWith(isLoading: true, clearError: true));
    try {
      final fetched = await _repository.fetchAssets();
      if (_isDisposed) {
        return;
      }
      _setState(
        _state.copyWith(
          assets: List<ModeratedImageAsset>.unmodifiable(fetched),
          isLoading: false,
          clearError: true,
        ),
      );
    } catch (error) {
      _setState(
        _state.copyWith(
          isLoading: false,
          errorMessage: '画像モデレーション一覧の読込に失敗しました: $error',
        ),
      );
    }
  }

  void setSearchQuery(String query) {
    if (_isDisposed) {
      return;
    }
    _setState(_state.copyWith(searchQuery: query));
  }

  void selectTag(String tag) {
    if (_isDisposed) {
      return;
    }
    final nextTag = _state.selectedTag == tag ? '' : tag;
    _setState(_state.copyWith(selectedTag: nextTag));
  }

  void toggleIncludeRestricted({required bool include}) {
    if (_isDisposed) {
      return;
    }
    _setState(_state.copyWith(includeRestricted: include));
  }

  void setExternalTransferConsented({required bool consented}) {
    if (_isDisposed) {
      return;
    }
    _setState(_state.copyWith(externalTransferConsented: consented));
  }

  Future<void> submitImageForModeration({required String storagePath}) async {
    if (_isDisposed || _state.isSubmitting) {
      return;
    }
    _setState(_state.copyWith(isSubmitting: true, clearError: true));
    try {
      final draft = LocalImageModerationAnalyzer.prepareUploadDraft(
        storageBucket: 'user-uploads',
        storagePath: storagePath,
        externalTransferConsented: _state.externalTransferConsented,
      );
      final saved = await _repository.registerUploadedImage(draft);
      if (_isDisposed) {
        return;
      }
      final updatedList = <ModeratedImageAsset>[
        saved,
        ..._state.assets.where((item) => item.id != saved.id),
      ];
      _setState(
        _state.copyWith(
          assets: List<ModeratedImageAsset>.unmodifiable(updatedList),
          isSubmitting: false,
          clearError: true,
        ),
      );
    } catch (error) {
      _setState(
        _state.copyWith(
          isSubmitting: false,
          errorMessage: '画像解析登録に失敗しました: $error',
        ),
      );
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
