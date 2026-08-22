import 'package:flutter/foundation.dart';

import '../models/asset_liability_workbook.dart';
import '../models/asset_subscription_statement_scan.dart';
import '../services/asset_subscription_statement_scan_service.dart';

class AssetSubscriptionStatementCandidateReview {
  final AssetSubscriptionStatementCandidate candidate;
  final bool selected;
  final bool alreadyRegistered;
  final AssetSubscriptionReviewDecision decision;

  const AssetSubscriptionStatementCandidateReview({
    required this.candidate,
    required this.selected,
    required this.alreadyRegistered,
    required this.decision,
  });

  AssetSubscriptionStatementCandidateReview copyWith({
    bool? selected,
    AssetSubscriptionReviewDecision? decision,
  }) {
    return AssetSubscriptionStatementCandidateReview(
      candidate: candidate,
      selected: selected ?? this.selected,
      alreadyRegistered: alreadyRegistered,
      decision: decision ?? this.decision,
    );
  }
}

/// 明細画像の選択・解析・重複除外・ユーザー判断を管理するViewModel。
class AssetSubscriptionStatementScanViewModel extends ChangeNotifier {
  final AssetSubscriptionStatementImagePicker _imagePicker;
  final AssetSubscriptionStatementAnalyzer _analyzer;
  final List<AssetRecurringFixedCost> _existingSubscriptions;
  final DateTime Function() _now;

  AssetSubscriptionStatementScanViewModel({
    required AssetSubscriptionStatementImagePicker imagePicker,
    required AssetSubscriptionStatementAnalyzer analyzer,
    required List<AssetRecurringFixedCost> existingSubscriptions,
    DateTime Function()? now,
  })  : _imagePicker = imagePicker,
        _analyzer = analyzer,
        _existingSubscriptions = List<AssetRecurringFixedCost>.unmodifiable(
          existingSubscriptions,
        ),
        _now = now ?? DateTime.now;

  bool _isAnalyzing = false;
  String? _errorMessage;
  String? _infoMessage;
  bool _loginRequired = false;
  String? _analyzedFileName;
  String? _sourceAccountId;
  List<AssetSubscriptionStatementCandidateReview> _reviews = const [];
  bool _disposed = false;

  bool get isAnalyzing => _isAnalyzing;
  String? get errorMessage => _errorMessage;
  String? get infoMessage => _infoMessage;
  bool get loginRequired => _loginRequired;
  String? get analyzedFileName => _analyzedFileName;
  String? get sourceAccountId => _sourceAccountId;
  List<AssetSubscriptionStatementCandidateReview> get reviews =>
      List<AssetSubscriptionStatementCandidateReview>.unmodifiable(_reviews);
  bool get hasResults => _reviews.isNotEmpty;

  int get selectedCount => _reviews.where((item) => item.selected).length;
  int get duplicateCount =>
      _reviews.where((item) => item.alreadyRegistered).length;
  int get reviewNeededCount => _reviews
      .where(
        (item) =>
            item.selected &&
            item.decision == AssetSubscriptionReviewDecision.hold,
      )
      .length;

  double get selectedMonthlyTotal => _reviews
      .where((item) => item.selected)
      .fold(0, (sum, item) => sum + item.candidate.monthlyEquivalentJpy);

  double get selectedAnnualTotal => selectedMonthlyTotal * 12;

  double get cancelCandidateMonthlySavings => _reviews
      .where(
        (item) =>
            item.selected &&
            item.decision == AssetSubscriptionReviewDecision.cancelCandidate,
      )
      .fold(0, (sum, item) => sum + item.candidate.monthlyEquivalentJpy);

  Future<void> pickAndAnalyze() async {
    if (_isAnalyzing) return;
    _errorMessage = null;
    _infoMessage = null;
    _loginRequired = false;
    _notifyListeners();

    AssetSubscriptionStatementImage? image;
    try {
      image = await _imagePicker.pickImage();
    } on AssetSubscriptionStatementScanException catch (error) {
      _errorMessage = error.message;
      _notifyListeners();
      return;
    } catch (_) {
      _errorMessage = '画像を選択できませんでした。';
      _notifyListeners();
      return;
    }
    if (image == null) return;

    _isAnalyzing = true;
    _analyzedFileName = image.fileName;
    _reviews = const [];
    _notifyListeners();
    try {
      final candidates = await _analyzer.analyze(image);
      if (candidates.isEmpty) {
        _errorMessage = 'サブスク候補を特定できませんでした。明細部分が鮮明な画像で再試行してください。';
        return;
      }
      final existingNames = _existingSubscriptions
          .map((cost) => _normalizeName(cost.name))
          .toSet();
      _reviews = <AssetSubscriptionStatementCandidateReview>[
        for (final candidate in candidates)
          AssetSubscriptionStatementCandidateReview(
            candidate: candidate,
            alreadyRegistered: existingNames.contains(
              _normalizeName(candidate.serviceName),
            ),
            selected: !existingNames.contains(
              _normalizeName(candidate.serviceName),
            ),
            // 明細だけでは利用頻度を判断できないため、AIに残す/解約を決めさせない。
            decision: AssetSubscriptionReviewDecision.hold,
          ),
      ];
    } on AssetSubscriptionStatementScanException catch (error) {
      _errorMessage = error.message;
      _loginRequired = error.requiresLogin;
    } catch (_) {
      _errorMessage = '明細画像を解析できませんでした。時間をおいて再試行してください。';
    } finally {
      // 画像バイト列はローカル変数だけで保持し、ここで参照を手放す。
      image = null;
      _isAnalyzing = false;
      _notifyListeners();
    }
  }

  void markSignedIn() {
    _errorMessage = null;
    _loginRequired = false;
    _analyzedFileName = null;
    _infoMessage = 'ログインしました。安全のため、明細画像をもう一度選んでください。';
    _notifyListeners();
  }

  void setSourceAccountId(String? value) {
    final normalized = value?.trim();
    _sourceAccountId =
        normalized == null || normalized.isEmpty ? null : normalized;
    _notifyListeners();
  }

  void setSelected(String candidateId, bool selected) {
    _reviews = <AssetSubscriptionStatementCandidateReview>[
      for (final review in _reviews)
        if (review.candidate.id == candidateId && !review.alreadyRegistered)
          review.copyWith(selected: selected)
        else
          review,
    ];
    _notifyListeners();
  }

  void setDecision(
    String candidateId,
    AssetSubscriptionReviewDecision decision,
  ) {
    if (decision == AssetSubscriptionReviewDecision.unreviewed) return;
    _reviews = <AssetSubscriptionStatementCandidateReview>[
      for (final review in _reviews)
        if (review.candidate.id == candidateId)
          review.copyWith(decision: decision)
        else
          review,
    ];
    _notifyListeners();
  }

  List<AssetRecurringFixedCost> buildSelectedCosts() {
    final stamp = _now().microsecondsSinceEpoch;
    var index = 0;
    return <AssetRecurringFixedCost>[
      for (final review in _reviews)
        if (review.selected)
          review.candidate.toRecurringFixedCost(
            id: 'sub_statement_${stamp}_${index++}',
            reviewDecision: review.decision,
            sourceAccountId: _sourceAccountId,
          ),
    ];
  }

  static String _normalizeName(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[\s\-_./・（）()]+'), '');
  }

  void _notifyListeners() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
