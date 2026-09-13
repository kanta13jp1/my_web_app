import 'package:flutter/foundation.dart';
import 'package:my_web_app/models/competitor_claim_evidence.dart';
import 'package:my_web_app/services/competitor_claim_evidence_repository.dart';

enum ComparisonEvidenceStatus { initial, loading, loaded, unavailable }

class ComparisonEvidenceViewModel extends ChangeNotifier {
  ComparisonEvidenceViewModel({
    required CompetitorClaimEvidenceRepository repository,
  }) : _repository = repository;

  final CompetitorClaimEvidenceRepository _repository;
  ComparisonEvidenceStatus _status = ComparisonEvidenceStatus.initial;
  List<CompetitorClaimEvidence> _claims = const [];
  int _requestGeneration = 0;

  ComparisonEvidenceStatus get status => _status;
  List<CompetitorClaimEvidence> get claims => _claims;

  Future<void> load(String competitorId) async {
    final generation = ++_requestGeneration;
    _status = ComparisonEvidenceStatus.loading;
    _claims = const [];
    notifyListeners();

    try {
      final claims = await _repository.fetchForCompetitor(competitorId);
      if (generation != _requestGeneration) {
        return;
      }
      _claims = claims;
      _status = ComparisonEvidenceStatus.loaded;
      notifyListeners();
    } catch (_) {
      if (generation != _requestGeneration) {
        return;
      }
      _claims = const [];
      _status = ComparisonEvidenceStatus.unavailable;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _requestGeneration++;
    super.dispose();
  }
}
