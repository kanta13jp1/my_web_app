import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/guitar_course_repository.dart';
import '../../../data/repositories/guitar_tab_repository.dart';
import '../../../data/services/guitar_course_progress_service.dart';
import '../../../data/services/guitar_daily_course_catalog_service.dart';
import '../../../data/services/guitar_lesson_link_service.dart';
import '../../../data/services/guitar_tab_catalog_service.dart';
import '../../../data/services/structured_tab_catalog_service.dart';
import '../../../data/services/structured_tab_pdf_service.dart';
import '../../../data/services/user_structured_tab_storage_service.dart';
import '../../../domain/use_cases/build_guitar_course_snapshot_use_case.dart';
import 'view_models/beatles_guitar_tabs_view_model.dart';
import 'views/beatles_guitar_tabs_page.dart';

class BeatlesGuitarTabsFeature extends StatelessWidget {
  const BeatlesGuitarTabsFeature({
    super.key,
    this.repository,
    this.courseRepository,
    this.linkService,
    this.structuredCatalogService,
    this.userTabStorageService,
    this.pdfService,
  });

  final GuitarTabRepository? repository;
  final GuitarCourseRepository? courseRepository;
  final GuitarLessonLinkService? linkService;
  final StructuredTabCatalogService? structuredCatalogService;
  final UserStructuredTabStorageService? userTabStorageService;
  final StructuredTabPdfService? pdfService;

  @override
  Widget build(BuildContext context) {
    final resolvedRepository = repository ??
        const LocalGuitarTabRepository(
          catalogService: GuitarTabCatalogService(),
        );
    final resolvedLinkService =
        linkService ?? const UrlLauncherGuitarLessonLinkService();
    final resolvedCourseRepository = courseRepository ??
        LocalGuitarCourseRepository(
          catalogService: const GuitarDailyCourseCatalogService(),
          progressService: SharedPreferencesGuitarCourseProgressService(),
        );

    return ChangeNotifierProvider<BeatlesGuitarTabsViewModel>(
      create: (_) => BeatlesGuitarTabsViewModel(
        repository: resolvedRepository,
        courseRepository: resolvedCourseRepository,
        linkService: resolvedLinkService,
        buildCourseSnapshot: const BuildGuitarCourseSnapshotUseCase(),
      )..load(),
      child: BeatlesGuitarTabsPage(
        structuredCatalogService: structuredCatalogService,
        userTabStorageService: userTabStorageService,
        pdfService: pdfService,
      ),
    );
  }
}
