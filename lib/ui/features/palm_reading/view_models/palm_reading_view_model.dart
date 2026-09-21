import 'package:flutter/foundation.dart';

import '../../../../data/models/palm_reading_image.dart';
import '../../../../data/repositories/palm_reading_repository.dart';
import '../../../../data/services/palm_reading_image_picker.dart';
import '../../../../domain/models/palm_reading.dart';
import '../../../../domain/palm_reading_exception.dart';

class PalmReadingViewModel extends ChangeNotifier {
  PalmReadingViewModel({
    required PalmReadingRepository repository,
    required PalmReadingImagePicker imagePicker,
  })  : _repository = repository,
        _imagePicker = imagePicker;

  final PalmReadingRepository _repository;
  final PalmReadingImagePicker _imagePicker;

  PalmHandSide _handSide = PalmHandSide.left;
  PalmReadingImage? _selectedImage;
  PalmReading? _currentReading;
  List<PalmReading> _history = const <PalmReading>[];
  bool _privacyConsent = false;
  bool _isLoadingHistory = false;
  bool _isPickingImage = false;
  bool _isAnalyzing = false;
  bool _initialized = false;
  String? _errorMessage;
  final Set<String> _deletingIds = <String>{};
  bool _disposed = false;

  PalmHandSide get handSide => _handSide;
  PalmReadingImage? get selectedImage => _selectedImage;
  PalmReading? get currentReading => _currentReading;
  List<PalmReading> get history => List<PalmReading>.unmodifiable(_history);
  bool get privacyConsent => _privacyConsent;
  bool get isLoadingHistory => _isLoadingHistory;
  bool get isPickingImage => _isPickingImage;
  bool get isAnalyzing => _isAnalyzing;
  String? get errorMessage => _errorMessage;
  bool get canAnalyze =>
      _selectedImage != null && _privacyConsent && !_isAnalyzing;

  bool isDeleting(String readingId) => _deletingIds.contains(readingId);

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await reloadHistory();
  }

  Future<void> reloadHistory() async {
    if (_isLoadingHistory) return;
    _isLoadingHistory = true;
    _errorMessage = null;
    _notify();
    try {
      _history = await _repository.loadHistory();
    } on PalmReadingException catch (error) {
      _errorMessage = error.message;
    } catch (_) {
      _errorMessage = '手相の履歴を読み込めませんでした。';
    } finally {
      _isLoadingHistory = false;
      _notify();
    }
  }

  void selectHand(PalmHandSide handSide) {
    if (_handSide == handSide) return;
    _handSide = handSide;
    _selectedImage = null;
    _currentReading = null;
    _errorMessage = null;
    _notify();
  }

  void setPrivacyConsent(bool value) {
    if (_privacyConsent == value) return;
    _privacyConsent = value;
    _errorMessage = null;
    _notify();
  }

  Future<void> pickImage(PalmImageSource source) async {
    if (_isPickingImage || _isAnalyzing) return;
    _isPickingImage = true;
    _errorMessage = null;
    _notify();
    try {
      final image = await _imagePicker.pick(source);
      if (image == null) return;
      _selectedImage = image;
      _currentReading = null;
    } on PalmReadingException catch (error) {
      _errorMessage = error.message;
    } catch (_) {
      _errorMessage = '写真を読み込めませんでした。';
    } finally {
      _isPickingImage = false;
      _notify();
    }
  }

  void clearSelectedImage() {
    if (_isAnalyzing) return;
    _selectedImage = null;
    _currentReading = null;
    _errorMessage = null;
    _notify();
  }

  Future<void> analyze() async {
    if (_isAnalyzing) return;
    final image = _selectedImage;
    if (image == null) {
      _errorMessage = '先に手のひらの写真を撮影または選択してください。';
      _notify();
      return;
    }
    if (!_privacyConsent) {
      _errorMessage = '写真のAI解析と非公開保存への同意を確認してください。';
      _notify();
      return;
    }

    _isAnalyzing = true;
    _errorMessage = null;
    _notify();
    try {
      final reading = await _repository.analyze(
        image: image,
        handSide: _handSide,
      );
      _currentReading = reading;
      _history = <PalmReading>[
        reading,
        ..._history.where((item) => item.id != reading.id),
      ];
    } on PalmReadingException catch (error) {
      _errorMessage = error.message;
    } catch (_) {
      _errorMessage = 'AI鑑定に失敗しました。時間をおいて再試行してください。';
    } finally {
      _isAnalyzing = false;
      _notify();
    }
  }

  Future<bool> deleteReading(String readingId) async {
    if (_deletingIds.contains(readingId)) return false;
    _deletingIds.add(readingId);
    _errorMessage = null;
    _notify();
    try {
      await _repository.deleteReading(readingId);
      _history = _history.where((item) => item.id != readingId).toList();
      if (_currentReading?.id == readingId) _currentReading = null;
      return true;
    } on PalmReadingException catch (error) {
      _errorMessage = error.message;
      return false;
    } catch (_) {
      _errorMessage = '鑑定履歴を削除できませんでした。';
      return false;
    } finally {
      _deletingIds.remove(readingId);
      _notify();
    }
  }

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
