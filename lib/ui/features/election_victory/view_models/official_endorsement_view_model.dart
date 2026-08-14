import 'package:flutter/foundation.dart';

import '../../../../data/repositories/official_endorsement_repository.dart';
import '../../../../models/election_intelligence.dart';

class OfficialEndorsementViewModel extends ChangeNotifier {
  OfficialEndorsementViewModel({
    OfficialEndorsementRepository repository =
        const OfficialEndorsementRepository(),
  })  : _repository = repository,
        _snapshot = repository.fallbackSnapshot;

  final OfficialEndorsementRepository _repository;
  OfficialEndorsementSnapshot _snapshot;

  OfficialEndorsementSnapshot get snapshot => _snapshot;

  OfficialEndorsementPrefecture? forPrefecture(String prefecture) =>
      _snapshot.forPrefecture(prefecture);

  void updateFromIntelligence(ElectionIntelligenceSnapshot? intelligence) {
    final next = _repository.resolve(intelligence);
    if (_hasSameValues(_snapshot, next)) {
      return;
    }
    _snapshot = next;
    notifyListeners();
  }

  static bool _hasSameValues(
    OfficialEndorsementSnapshot current,
    OfficialEndorsementSnapshot next,
  ) {
    final summariesMatch = current.sourceUrl == next.sourceUrl &&
        current.sourceAsOf == next.sourceAsOf &&
        current.sourceDocumentSha256 == next.sourceDocumentSha256 &&
        current.totalCount == next.totalCount &&
        current.incumbentCount == next.incumbentCount &&
        current.newcomerCount == next.newcomerCount &&
        current.formerCount == next.formerCount &&
        current.recommendationCount == next.recommendationCount &&
        current.prefectureCount == next.prefectureCount;
    if (!summariesMatch ||
        current.prefectures.length != next.prefectures.length) {
      return false;
    }
    for (var index = 0; index < current.prefectures.length; index += 1) {
      final currentPrefecture = current.prefectures[index];
      final nextPrefecture = next.prefectures[index];
      if (currentPrefecture.prefecture != nextPrefecture.prefecture ||
          currentPrefecture.totalCount != nextPrefecture.totalCount ||
          currentPrefecture.incumbentCount != nextPrefecture.incumbentCount ||
          currentPrefecture.newcomerCount != nextPrefecture.newcomerCount ||
          currentPrefecture.formerCount != nextPrefecture.formerCount) {
        return false;
      }
    }
    return true;
  }
}
