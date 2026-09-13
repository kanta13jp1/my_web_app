import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/toeic_practice_repository.dart';
import '../../../../domain/models/toeic_practice.dart';
import '../../../../domain/use_cases/build_toeic_dashboard_snapshot_use_case.dart';

enum ToeicPracticeStage { dashboard, question, summary }

class ToeicPracticeViewModel extends ChangeNotifier {
  ToeicPracticeViewModel({
    required ToeicPracticeRepository repository,
    BuildToeicDashboardSnapshotUseCase snapshotUseCase =
        const BuildToeicDashboardSnapshotUseCase(),
    DateTime Function()? clock,
  })  : _repository = repository,
        _snapshotUseCase = snapshotUseCase,
        _clock = clock ?? DateTime.now;

  static const int dailyQuestionCount = 5;

  final ToeicPracticeRepository _repository;
  final BuildToeicDashboardSnapshotUseCase _snapshotUseCase;
  final DateTime Function() _clock;

  bool _isLoading = true;
  String? _errorMessage;
  List<ToeicQuestion> _questions = const <ToeicQuestion>[];
  ToeicProgress _progress = ToeicProgress.initial();
  ToeicPracticeStage _stage = ToeicPracticeStage.dashboard;
  List<ToeicQuestion> _sessionQuestions = const <ToeicQuestion>[];
  ToeicPart? _sessionPart;
  int _questionIndex = 0;
  int? _selectedAnswerIndex;
  bool _answerSubmitted = false;
  int _sessionCorrect = 0;
  final Map<ToeicPart, int> _sessionAnsweredByPart = <ToeicPart, int>{};
  final Map<ToeicPart, int> _sessionCorrectByPart = <ToeicPart, int>{};

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  ToeicPracticeStage get stage => _stage;
  ToeicProgress get progress => _progress;
  int? get selectedAnswerIndex => _selectedAnswerIndex;
  bool get answerSubmitted => _answerSubmitted;
  int get sessionCorrect => _sessionCorrect;
  int get sessionLength => _sessionQuestions.length;
  int get questionNumber => _questionIndex + 1;
  bool get isLastQuestion => _questionIndex == _sessionQuestions.length - 1;
  ToeicPart? get sessionPart => _sessionPart;

  ToeicDashboardSnapshot get dashboard =>
      _snapshotUseCase(progress: _progress, today: _clock());

  ToeicQuestion? get currentQuestion {
    if (_sessionQuestions.isEmpty ||
        _questionIndex >= _sessionQuestions.length) {
      return null;
    }
    return _sessionQuestions[_questionIndex];
  }

  bool get selectedAnswerIsCorrect {
    final question = currentQuestion;
    return question != null && _selectedAnswerIndex == question.answerIndex;
  }

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final results = await Future.wait<Object>(<Future<Object>>[
        _repository.getQuestions(),
        _repository.getProgress(),
      ]);
      _questions = results[0] as List<ToeicQuestion>;
      _progress = results[1] as ToeicProgress;
      if (_questions.isEmpty) {
        _errorMessage = '練習問題を読み込めませんでした。';
      }
    } catch (_) {
      _errorMessage = 'TOEIC対策データの読み込みに失敗しました。';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setTargetScore(int score) async {
    if (_progress.targetScore == score) return;
    _progress = _progress.copyWith(targetScore: score);
    notifyListeners();
    try {
      await _repository.saveProgress(_progress);
    } catch (_) {
      _errorMessage = '目標スコアを保存できませんでした。';
      notifyListeners();
    }
  }

  void startDailySession() => _startSession(part: null);

  void startPartSession(ToeicPart part) => _startSession(part: part);

  void _startSession({ToeicPart? part}) {
    final pool = part == null
        ? _questions
        : _questions.where((question) => question.part == part).toList();
    if (pool.isEmpty) return;

    final count = math.min(dailyQuestionCount, pool.length);
    final offset = _progress.totalAnswered % pool.length;
    _sessionQuestions = List<ToeicQuestion>.generate(
      count,
      (index) => pool[(offset + index) % pool.length],
      growable: false,
    );
    _sessionPart = part;
    _questionIndex = 0;
    _selectedAnswerIndex = null;
    _answerSubmitted = false;
    _sessionCorrect = 0;
    _sessionAnsweredByPart.clear();
    _sessionCorrectByPart.clear();
    _stage = ToeicPracticeStage.question;
    notifyListeners();
  }

  void selectAnswer(int index) {
    if (_answerSubmitted || currentQuestion == null) return;
    _selectedAnswerIndex = index;
    notifyListeners();
  }

  void submitAnswer() {
    final question = currentQuestion;
    if (_answerSubmitted || question == null || _selectedAnswerIndex == null) {
      return;
    }
    _answerSubmitted = true;
    _sessionAnsweredByPart.update(
      question.part,
      (count) => count + 1,
      ifAbsent: () => 1,
    );
    if (selectedAnswerIsCorrect) {
      _sessionCorrect++;
      _sessionCorrectByPart.update(
        question.part,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
    notifyListeners();
  }

  Future<void> nextQuestion() async {
    if (!_answerSubmitted) return;
    if (!isLastQuestion) {
      _questionIndex++;
      _selectedAnswerIndex = null;
      _answerSubmitted = false;
      notifyListeners();
      return;
    }
    await _completeSession();
  }

  Future<void> _completeSession() async {
    final answeredByPart = Map<ToeicPart, int>.from(_progress.answeredByPart);
    final correctByPart = Map<ToeicPart, int>.from(_progress.correctByPart);
    for (final entry in _sessionAnsweredByPart.entries) {
      answeredByPart.update(
        entry.key,
        (count) => count + entry.value,
        ifAbsent: () => entry.value,
      );
    }
    for (final entry in _sessionCorrectByPart.entries) {
      correctByPart.update(
        entry.key,
        (count) => count + entry.value,
        ifAbsent: () => entry.value,
      );
    }
    final practiceDates = Set<String>.from(_progress.practiceDateKeys)
      ..add(_dateKey(_clock()));
    _progress = _progress.copyWith(
      totalAnswered: _progress.totalAnswered + _sessionQuestions.length,
      totalCorrect: _progress.totalCorrect + _sessionCorrect,
      answeredByPart: answeredByPart,
      correctByPart: correctByPart,
      practiceDateKeys: practiceDates,
    );
    _stage = ToeicPracticeStage.summary;
    notifyListeners();
    try {
      await _repository.saveProgress(_progress);
    } catch (_) {
      _errorMessage = '学習結果を保存できませんでした。';
      notifyListeners();
    }
  }

  void showDashboard() {
    _stage = ToeicPracticeStage.dashboard;
    notifyListeners();
  }

  void repeatSession() {
    _startSession(part: _sessionPart);
  }

  String _dateKey(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}
