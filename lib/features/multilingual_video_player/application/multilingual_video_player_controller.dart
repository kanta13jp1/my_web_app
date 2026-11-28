import 'package:flutter/material.dart';

import '../data/supabase_multilingual_video_repository.dart';
import '../domain/multilingual_video_player_models.dart';

/// 多言語リップシンク動画プレイヤーの状態管理 Controller (#2660).
class MultilingualVideoPlayerController extends ChangeNotifier {
  MultilingualVideoPlayerController({
    required final MultilingualVideoRepository repository,
    final Locale initialDeviceLocale = const Locale('ja'),
    final DateTime Function()? nowProvider,
  })  : _repository = repository,
        _deviceLocale = initialDeviceLocale,
        _nowProvider = nowProvider ?? (() => DateTime.now().toUtc());

  final MultilingualVideoRepository _repository;
  final DateTime Function() _nowProvider;

  Locale _deviceLocale;
  String? _preferredLanguageCode;
  String _selectedStatusFilter = 'all';
  List<VideoTranslationTrack> _tracks = const <VideoTranslationTrack>[];
  bool _isLoading = false;
  bool _isSubmitting = false;
  bool _isDisposed = false;
  String? _errorMessage;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  void _notifyIfAlive() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  Locale get deviceLocale => _deviceLocale;
  String? get preferredLanguageCode => _preferredLanguageCode;
  String get selectedStatusFilter => _selectedStatusFilter;
  List<VideoTranslationTrack> get tracks => _tracks;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;

  /// 現在のデバイス Locale とユーザー優先言語から最適再生トラックを解決する。
  ResolvedMultilingualPlayback get resolvedPlayback =>
      resolveBestLocalizedTrack(
        tracks: _tracks,
        deviceLocale: _deviceLocale,
        preferredLanguageCode: _preferredLanguageCode,
        nowUtc: _nowProvider(),
      );

  /// ステータスフィルタ適用済みトラック一覧。
  List<VideoTranslationTrack> get filteredTracks {
    if (_selectedStatusFilter == 'all') {
      return _tracks;
    }
    return _tracks
        .where(
          (final VideoTranslationTrack t) =>
              t.status.wireValue == _selectedStatusFilter,
        )
        .toList();
  }

  MultilingualVideoSummary get summary =>
      MultilingualVideoSummary.fromList(_tracks);

  /// 翻訳トラック一覧を取得する。
  Future<void> loadTranslations({final String? sourceVideoId}) async {
    if (_isDisposed) {
      return;
    }
    _isLoading = true;
    _errorMessage = null;
    _notifyIfAlive();

    try {
      final List<VideoTranslationTrack> loaded =
          await _repository.fetchTranslations(sourceVideoId: sourceVideoId);
      if (_isDisposed) {
        return;
      }
      _tracks = loaded;
    } catch (e) {
      if (_isDisposed) {
        return;
      }
      _errorMessage = '翻訳トラックの読み込みに失敗しました: $e';
    } finally {
      if (!_isDisposed) {
        _isLoading = false;
        _notifyIfAlive();
      }
    }
  }

  /// ユーザー優先言語または「端末ロケール自動 (null)」を更新する。
  void updatePreferredLanguageCode(final String? languageCode) {
    if (_isDisposed) {
      return;
    }
    _preferredLanguageCode =
        (languageCode == null || languageCode.trim().isEmpty)
            ? null
            : languageCode.trim().toLowerCase();
    _errorMessage = null;
    _notifyIfAlive();
  }

  /// 端末 / ブラウザ Locale 変更を反映する。
  void updateDeviceLocale(final Locale locale) {
    if (_isDisposed) {
      return;
    }
    _deviceLocale = locale;
    _errorMessage = null;
    _notifyIfAlive();
  }

  /// ステータスフィルタを変更する。
  void updateStatusFilter(final String filter) {
    if (_isDisposed) {
      return;
    }
    _selectedStatusFilter = filter;
    _errorMessage = null;
    _notifyIfAlive();
  }

  /// 上限検証（尺・概算コスト）を通過した新規多言語翻訳ジョブを登録する。
  Future<bool> queueTranslation(final QueueVideoTranslationInput input) async {
    if (_isDisposed) {
      return false;
    }
    final String? validationError = input.validate();
    if (validationError != null) {
      _errorMessage = validationError;
      _notifyIfAlive();
      return false;
    }

    _isSubmitting = true;
    _errorMessage = null;
    _notifyIfAlive();

    try {
      final VideoTranslationTrack created =
          await _repository.queueTranslation(input);
      if (_isDisposed) {
        return false;
      }
      _tracks = <VideoTranslationTrack>[created, ..._tracks];
      return true;
    } catch (e) {
      if (_isDisposed) {
        return false;
      }
      _errorMessage = '翻訳ジョブの登録に失敗しました: $e';
      return false;
    } finally {
      if (!_isDisposed) {
        _isSubmitting = false;
        _notifyIfAlive();
      }
    }
  }
}
