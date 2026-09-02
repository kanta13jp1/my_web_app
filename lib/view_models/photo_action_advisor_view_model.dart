import 'package:flutter/foundation.dart';

import '../domain/models/photo_action_advice.dart';
import '../services/photo_action_advisor_service.dart';

class PhotoActionAdvisorViewModel extends ChangeNotifier {
  PhotoActionAdvisorViewModel({
    required PhotoActionImagePicker imagePicker,
    required PhotoActionAnalyzer analyzer,
  })  : _imagePicker = imagePicker,
        _analyzer = analyzer;

  final PhotoActionImagePicker _imagePicker;
  final PhotoActionAnalyzer _analyzer;

  PhotoActionImage? _selectedImage;
  PhotoActionAdvice? _advice;
  String? _errorMessage;
  bool _requiresLogin = false;
  bool _isAnalyzing = false;
  int _requestSequence = 0;
  bool _disposed = false;

  PhotoActionImage? get selectedImage => _selectedImage;
  PhotoActionAdvice? get advice => _advice;
  String? get errorMessage => _errorMessage;
  bool get requiresLogin => _requiresLogin;
  bool get isAnalyzing => _isAnalyzing;

  Future<void> pickAndAnalyze(PhotoActionImageSource source) async {
    if (_isAnalyzing) return;
    _clearError();
    PhotoActionImage? image;
    try {
      image = await _imagePicker.pick(source);
    } on PhotoActionAdvisorException catch (error) {
      _setError(error);
      return;
    } catch (_) {
      _setError(const PhotoActionAdvisorException('画像を選択できませんでした。'));
      return;
    }
    if (image == null) return;
    _selectedImage = image;
    _advice = null;
    _notifyListeners();
    await analyzeSelected();
  }

  Future<void> analyzeSelected() async {
    final image = _selectedImage;
    if (image == null || _isAnalyzing) return;
    final sequence = ++_requestSequence;
    _isAnalyzing = true;
    _clearError(notify: false);
    _notifyListeners();
    try {
      final result = await _analyzer.analyze(image);
      if (sequence != _requestSequence || _disposed) return;
      _advice = result;
    } on PhotoActionAdvisorException catch (error) {
      if (sequence != _requestSequence || _disposed) return;
      _setError(error, notify: false);
    } catch (_) {
      if (sequence != _requestSequence || _disposed) return;
      _setError(
        const PhotoActionAdvisorException(
          'AI分析に失敗しました。時間をおいて、もう一度お試しください。',
        ),
        notify: false,
      );
    } finally {
      if (sequence == _requestSequence && !_disposed) {
        _isAnalyzing = false;
        _notifyListeners();
      }
    }
  }

  void _clearError({bool notify = true}) {
    _errorMessage = null;
    _requiresLogin = false;
    if (notify) _notifyListeners();
  }

  void _setError(
    PhotoActionAdvisorException error, {
    bool notify = true,
  }) {
    _errorMessage = error.message;
    _requiresLogin = error.requiresLogin;
    if (notify) _notifyListeners();
  }

  void _notifyListeners() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _requestSequence++;
    super.dispose();
  }
}
