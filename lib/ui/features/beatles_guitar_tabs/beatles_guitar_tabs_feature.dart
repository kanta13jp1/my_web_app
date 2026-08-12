import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/guitar_tab_repository.dart';
import '../../../data/services/guitar_tab_catalog_service.dart';
import '../../../data/services/guitar_lesson_link_service.dart';
import 'view_models/beatles_guitar_tabs_view_model.dart';
import 'views/beatles_guitar_tabs_page.dart';

class BeatlesGuitarTabsFeature extends StatelessWidget {
  const BeatlesGuitarTabsFeature({
    super.key,
    this.repository,
    this.linkService,
  });

  final GuitarTabRepository? repository;
  final GuitarLessonLinkService? linkService;

  @override
  Widget build(BuildContext context) {
    final resolvedRepository = repository ??
        const LocalGuitarTabRepository(
          catalogService: GuitarTabCatalogService(),
        );
    final resolvedLinkService =
        linkService ?? const UrlLauncherGuitarLessonLinkService();

    return ChangeNotifierProvider<BeatlesGuitarTabsViewModel>(
      create: (_) => BeatlesGuitarTabsViewModel(
        repository: resolvedRepository,
        linkService: resolvedLinkService,
      )..load(),
      child: const BeatlesGuitarTabsPage(),
    );
  }
}
