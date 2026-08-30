import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/toeic_practice_repository.dart';
import '../../../data/services/toeic_progress_service.dart';
import '../../../data/services/toeic_question_catalog_service.dart';
import 'view_models/toeic_practice_view_model.dart';
import 'views/toeic_practice_page.dart';

class ToeicFeature extends StatelessWidget {
  const ToeicFeature({super.key, this.repository, this.clock});

  final ToeicPracticeRepository? repository;
  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context) {
    final resolvedRepository = repository ??
        LocalToeicPracticeRepository(
          catalogService: const LocalToeicQuestionCatalogService(),
          progressService: SharedPreferencesToeicProgressService(),
        );
    return ChangeNotifierProvider<ToeicPracticeViewModel>(
      create: (_) =>
          ToeicPracticeViewModel(repository: resolvedRepository, clock: clock)
            ..load(),
      child: const ToeicPracticePage(),
    );
  }
}
