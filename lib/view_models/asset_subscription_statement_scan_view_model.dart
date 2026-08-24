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

class AssetSubscriptionStatementFileFailure {
  final String fileName;
  final String message;

  const AssetSubscriptionStatementFileFailure({
    required this.fileName,
    required this.message,
  });
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
  String? _currentFileName;
  String? _sourceAccountId;
  List<AssetSubscriptionStatementCandidateReview> _reviews = const [];
  List<AssetSubscriptionStatementFileFailure> _fileFailures = const [];
  int _selectedImageCount = 0;
  int _analyzedImageCount = 0;
  int _processingImageNumber = 0;
  int _processingImageTotal = 0;
  int _mergedDuplicateCount = 0;
  int _analysisBatchSequence = 0;
  bool _disposed = false;

  bool get isAnalyzing => _isAnalyzing;
  String? get errorMessage => _errorMessage;
  String? get infoMessage => _infoMessage;
  bool get loginRequired => _loginRequired;
  String? get analyzedFileName {
    if (_currentFileName != null) return _currentFileName;
    if (_selectedImageCount == 0) return null;
    return '$_analyzedImageCount / $_selectedImageCount枚を解析';
  }

  String? get currentFileName => _currentFileName;
  int get selectedImageCount => _selectedImageCount;
  int get analyzedImageCount => _analyzedImageCount;
  int get processingImageNumber => _processingImageNumber;
  int get processingImageTotal => _processingImageTotal;
  int get mergedDuplicateCount => _mergedDuplicateCount;
  List<AssetSubscriptionStatementFileFailure> get fileFailures =>
      List<AssetSubscriptionStatementFileFailure>.unmodifiable(_fileFailures);
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

    List<AssetSubscriptionStatementImage>? selectedImages;
    try {
      selectedImages = await _imagePicker.pickImages();
    } on AssetSubscriptionStatementScanException catch (error) {
      _errorMessage = error.message;
      _notifyListeners();
      return;
    } catch (_) {
      _errorMessage = '画像を選択できませんでした。';
      _notifyListeners();
      return;
    }
    if (selectedImages.isEmpty) return;
    if (selectedImages.length > assetSubscriptionStatementMaxImageCount) {
      _errorMessage = '画像は一度に5枚まで選択できます。';
      _notifyListeners();
      return;
    }

    final pendingImages = List<AssetSubscriptionStatementImage>.of(
      selectedImages,
    );
    selectedImages = null;
    final batchImageCount = pendingImages.length;
    final batchSequence = ++_analysisBatchSequence;
    final existingNames =
        _existingSubscriptions.map((cost) => _normalizeName(cost.name)).toSet();
    final seenNames = _reviews
        .map((review) => _normalizeName(review.candidate.serviceName))
        .toSet();
    final usedCandidateIds =
        _reviews.map((review) => review.candidate.id).toSet();
    final accumulatedReviews =
        List<AssetSubscriptionStatementCandidateReview>.of(_reviews);
    final accumulatedFailures = List<AssetSubscriptionStatementFileFailure>.of(
      _fileFailures,
    );
    _isAnalyzing = true;
    _selectedImageCount += batchImageCount;
    _processingImageNumber = 1;
    _processingImageTotal = batchImageCount;
    _notifyListeners();
    try {
      for (var imageIndex = 0; pendingImages.isNotEmpty; imageIndex++) {
        final image = pendingImages.removeAt(0);
        _processingImageNumber = imageIndex + 1;
        _currentFileName = image.fileName;
        _notifyListeners();
        try {
          final candidates = await _analyzer.analyze(image);
          if (candidates.isEmpty) {
            accumulatedFailures.add(
              AssetSubscriptionStatementFileFailure(
                fileName: image.fileName,
                message: 'サブスク候補を特定できませんでした。',
              ),
            );
            continue;
          }
          _analyzedImageCount++;
          for (var candidateIndex = 0;
              candidateIndex < candidates.length;
              candidateIndex++) {
            final candidate = candidates[candidateIndex];
            final normalizedName = _normalizeName(candidate.serviceName);
            if (seenNames.contains(normalizedName)) {
              _mergedDuplicateCount++;
              continue;
            }
            seenNames.add(normalizedName);
            final uniqueCandidate = _withUniqueId(
              candidate,
              usedCandidateIds: usedCandidateIds,
              fallbackSuffix: '${batchSequence}_${imageIndex}_$candidateIndex',
            );
            final alreadyRegistered = existingNames.contains(normalizedName);
            accumulatedReviews.add(
              AssetSubscriptionStatementCandidateReview(
                candidate: uniqueCandidate,
                alreadyRegistered: alreadyRegistered,
                selected: !alreadyRegistered,
                // 明細だけでは利用頻度を判断できないため、AIに残す/解約を決めさせない。
                decision: AssetSubscriptionReviewDecision.hold,
              ),
            );
          }
        } on AssetSubscriptionStatementScanException catch (error) {
          if (error.requiresLogin) {
            // 認証前の画像は解析件数に含めず、ログイン後に安全のため再選択する。
            _selectedImageCount -= pendingImages.length + 1;
            _errorMessage = error.message;
            _loginRequired = true;
            break;
          }
          accumulatedFailures.add(
            AssetSubscriptionStatementFileFailure(
              fileName: image.fileName,
              message: error.message,
            ),
          );
        } catch (_) {
          accumulatedFailures.add(
            AssetSubscriptionStatementFileFailure(
              fileName: image.fileName,
              message: '時間をおいて再試行してください。',
            ),
          );
        } finally {
          _reviews = List<AssetSubscriptionStatementCandidateReview>.of(
            accumulatedReviews,
          );
          _fileFailures = List<AssetSubscriptionStatementFileFailure>.of(
            accumulatedFailures,
          );
          _notifyListeners();
        }
      }

      if (_reviews.isEmpty && !_loginRequired) {
        _errorMessage = 'サブスク候補を特定できませんでした。明細部分が鮮明な画像で再試行してください。';
      } else if (_fileFailures.isNotEmpty && !_loginRequired) {
        _infoMessage =
            '$_analyzedImageCount枚の解析結果を保持しました。解析できなかった画像は下記で確認できます。';
      }
    } finally {
      // 処理済み画像は逐次リストから外し、残りもここで参照を手放す。
      pendingImages.clear();
      _currentFileName = null;
      _processingImageNumber = 0;
      _processingImageTotal = 0;
      _isAnalyzing = false;
      _notifyListeners();
    }
  }

  void markSignedIn() {
    _errorMessage = null;
    _loginRequired = false;
    _currentFileName = null;
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

  static AssetSubscriptionStatementCandidate _withUniqueId(
    AssetSubscriptionStatementCandidate candidate, {
    required Set<String> usedCandidateIds,
    required String fallbackSuffix,
  }) {
    final originalId = candidate.id.trim().isEmpty
        ? 'statement_candidate'
        : candidate.id.trim();
    final id = usedCandidateIds.add(originalId)
        ? originalId
        : '${originalId}_$fallbackSuffix';
    usedCandidateIds.add(id);
    if (id == candidate.id) return candidate;
    return AssetSubscriptionStatementCandidate(
      id: id,
      serviceName: candidate.serviceName,
      chargedAmountJpy: candidate.chargedAmountJpy,
      chargedAt: candidate.chargedAt,
      billingCycle: candidate.billingCycle,
      billingGateway: candidate.billingGateway,
      confidence: candidate.confidence,
      evidence: candidate.evidence,
    );
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
