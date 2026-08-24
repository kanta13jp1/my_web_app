import 'package:flutter/foundation.dart';

import '../models/artifact_publishing.dart';
import '../services/artifact_publishing_service.dart';

class ArtifactPublishingViewModel extends ChangeNotifier {
  ArtifactPublishingViewModel({required ArtifactPublishingGateway gateway})
      : _gateway = gateway;

  final ArtifactPublishingGateway _gateway;

  bool _loading = false;
  bool _authorized = false;
  bool _accessChecked = false;
  String? _error;
  String? _workingCandidateId;
  List<ArtifactCandidate> _candidates = const [];

  bool get loading => _loading;
  bool get authorized => _authorized;
  bool get accessChecked => _accessChecked;
  String? get error => _error;
  String? get workingCandidateId => _workingCandidateId;
  List<ArtifactCandidate> get candidates => _candidates;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _authorized = await _gateway.isCurrentUserAdmin();
      _accessChecked = true;
      _candidates = _authorized ? await _gateway.fetchCandidates() : const [];
    } catch (error) {
      _accessChecked = true;
      _authorized = false;
      _error = error.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> transition(
    ArtifactCandidate candidate,
    ArtifactStage target, {
    String? rejectionReason,
    String? humanContributionSummary,
    String? productId,
    int? intendedPriceJpy,
    String? proposedStoragePath,
  }) async {
    return _runCandidateAction(candidate.id, () async {
      await _gateway.transitionStage(
        candidateId: candidate.id,
        expectedStage: candidate.stage,
        targetStage: target,
        rejectionReason: rejectionReason,
        humanContributionSummary: humanContributionSummary,
        productId: productId,
        intendedPriceJpy: intendedPriceJpy,
        proposedStoragePath: proposedStoragePath,
      );
      _candidates = await _gateway.fetchCandidates();
    });
  }

  Future<bool> reviewCheck(
    ArtifactCandidate candidate,
    ArtifactCheck check,
    ArtifactCheckStatus status, {
    String? evidenceSummary,
  }) async {
    return _runCandidateAction(candidate.id, () async {
      await _gateway.reviewCheck(
        candidateId: candidate.id,
        checkKey: check.key,
        status: status,
        evidenceSummary: evidenceSummary,
      );
      _candidates = await _gateway.fetchCandidates();
    });
  }

  Future<bool> _runCandidateAction(
    String candidateId,
    Future<void> Function() action,
  ) async {
    _workingCandidateId = candidateId;
    _error = null;
    notifyListeners();
    try {
      await action();
      return true;
    } catch (error) {
      _error = error.toString();
      return false;
    } finally {
      _workingCandidateId = null;
      notifyListeners();
    }
  }
}
