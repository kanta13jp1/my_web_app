import 'package:flutter/foundation.dart';
import 'package:my_web_app/models/micro_survey.dart';
import 'package:my_web_app/services/micro_survey_repository.dart';

class MicroSurveyController extends ChangeNotifier {
  MicroSurveyController({required MicroSurveyRepository repository})
      : _repository = repository;

  final MicroSurveyRepository _repository;

  bool _isChecking = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  bool get isChecking => _isChecking;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;

  Future<bool> shouldPresent(MicroSurveyContext surveyContext) async {
    if (_isChecking || _isSubmitting) return false;
    _isChecking = true;
    _errorMessage = null;
    notifyListeners();
    try {
      return await _repository.claimPrompt(surveyContext);
    } on Object {
      // Feedback collection must never turn a completed product task into an
      // apparent failure. The next eligible task can retry after the backend
      // becomes available.
      _errorMessage = 'フィードバックの表示判定に失敗しました。';
      return false;
    } finally {
      _isChecking = false;
      notifyListeners();
    }
  }

  Future<bool> submit(
    MicroSurveyContext surveyContext,
    MicroSurveyAnswer answer,
  ) async {
    if (_isSubmitting || answer.rating < 1 || answer.rating > 5) return false;
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _repository.submit(surveyContext, answer);
      return true;
    } on Object {
      _errorMessage = '送信できませんでした。通信状態を確認して、もう一度お試しください。';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> optOut() async {
    if (_isSubmitting) return false;
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _repository.setOptOut(true);
      return true;
    } on Object {
      _errorMessage = '設定を保存できませんでした。もう一度お試しください。';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }
}
