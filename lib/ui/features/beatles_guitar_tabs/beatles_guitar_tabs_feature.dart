import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/guitar_tab_repository.dart';
import '../../../data/services/guitar_tab_catalog_service.dart';
import 'view_models/beatles_guitar_tabs_view_model.dart';
import 'views/beatles_guitar_tabs_page.dart';

class BeatlesGuitarTabsFeature extends StatelessWidget {
  const BeatlesGuitarTabsFeature({super.key, this.repository});

  final GuitarTabRepository? repository;

  @override
  Widget build(BuildContext context) {
    final resolvedRepository = repository ??
        const LocalGuitarTabRepository(
          catalogService: GuitarTabCatalogService(),
        );

    return ChangeNotifierProvider<BeatlesGuitarTabsViewModel>(
      create: (_) =>
          BeatlesGuitarTabsViewModel(repository: resolvedRepository)..load(),
      child: const BeatlesGuitarTabsPage(),
    );
  }
}
