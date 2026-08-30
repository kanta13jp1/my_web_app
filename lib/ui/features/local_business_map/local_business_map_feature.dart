import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/local_business_reference_repository.dart';
import '../../../data/repositories/statistical_area_boundary_repository.dart';
import '../../../data/services/local_business_reference_service.dart';
import '../../../data/services/statistical_area_boundary_service.dart';
import 'view_models/local_business_map_view_model.dart';
import 'views/local_business_map_page.dart';

class LocalBusinessMapFeature extends StatelessWidget {
  const LocalBusinessMapFeature({
    super.key,
    this.repository,
    this.boundaryRepository,
    this.linkService,
    this.mapBuilder,
  });

  final LocalBusinessReferenceRepository? repository;
  final StatisticalAreaBoundaryRepository? boundaryRepository;
  final LocalBusinessReferenceLinkService? linkService;
  final LocalBusinessMapBuilder? mapBuilder;

  @override
  Widget build(BuildContext context) {
    final resolvedRepository = repository ??
        RemoteLocalBusinessReferenceRepository(
          service: SupabaseLocalBusinessReferenceService(),
        );
    final resolvedLinkService =
        linkService ?? const UrlLauncherLocalBusinessReferenceLinkService();
    final resolvedBoundaryRepository = boundaryRepository ??
        RemoteStatisticalAreaBoundaryRepository(
          service: CodhStatisticalAreaBoundaryService(),
        );

    return ChangeNotifierProvider<LocalBusinessMapViewModel>(
      create: (_) => LocalBusinessMapViewModel(
        repository: resolvedRepository,
        boundaryRepository: resolvedBoundaryRepository,
        linkService: resolvedLinkService,
      )..load(),
      child: LocalBusinessMapPage(mapBuilder: mapBuilder),
    );
  }
}
