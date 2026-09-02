import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/data/models/guitar_daily_course_model.dart';
import 'package:my_web_app/data/repositories/guitar_course_repository.dart';
import 'package:my_web_app/data/repositories/guitar_tab_repository.dart';
import 'package:my_web_app/data/services/guitar_course_progress_service.dart';
import 'package:my_web_app/data/services/guitar_daily_course_catalog_service.dart';
import 'package:my_web_app/data/services/guitar_tab_catalog_service.dart';
import 'package:my_web_app/data/services/guitar_lesson_link_service.dart';
import 'package:my_web_app/domain/models/guitar_tab_song.dart';
import 'package:my_web_app/domain/use_cases/build_guitar_course_snapshot_use_case.dart';
import 'package:my_web_app/ui/features/beatles_guitar_tabs/view_models/beatles_guitar_tabs_view_model.dart';

void main() {
  group('BeatlesGuitarTabsViewModel', () {
    late BeatlesGuitarTabsViewModel viewModel;
    late _MemoryGuitarCourseProgressService progressService;

    setUp(() {
      progressService = _MemoryGuitarCourseProgressService();
      viewModel = BeatlesGuitarTabsViewModel(
        repository: const LocalGuitarTabRepository(
          catalogService: GuitarTabCatalogService(),
        ),
        courseRepository: LocalGuitarCourseRepository(
          catalogService: const GuitarDailyCourseCatalogService(),
          progressService: progressService,
        ),
        linkService: _FakeGuitarLessonLinkService(),
        buildCourseSnapshot: const BuildGuitarCourseSnapshotUseCase(),
        clock: () => DateTime(2026, 8, 13),
      );
    });

    tearDown(() => viewModel.dispose());

    test('loads songs and selects the first practice', () async {
      await viewModel.load();

      expect(viewModel.status, BeatlesGuitarTabsStatus.ready);
      expect(viewModel.songs, hasLength(4));
      expect(viewModel.selectedSong?.title, 'Blackbird');
      expect(viewModel.practiceBpm, 60);
      expect(viewModel.selectedPracticeStep?.id, 'separate');
      expect(viewModel.courseSnapshot?.currentDay?.dayNumber, 1);
      expect(viewModel.courseSnapshot?.totalDayCount, 14);
    });

    test(
      'filters by query and difficulty while keeping selection visible',
      () async {
        await viewModel.load();

        viewModel.setQuery('sun');
        expect(viewModel.filteredSongs.map((song) => song.title), <String>[
          'Here Comes the Sun',
        ]);
        expect(viewModel.selectedSong?.title, 'Here Comes the Sun');

        viewModel.setQuery('');
        viewModel.setDifficulty(GuitarTabDifficulty.beginner);
        expect(viewModel.filteredSongs.map((song) => song.title), <String>[
          'Day Tripper',
          'Let It Be',
        ]);
        expect(viewModel.selectedSong?.title, 'Day Tripper');
      },
    );

    test(
      'changes tempo and resets it to the selected song recommendation',
      () async {
        await viewModel.load();
        viewModel.selectSong('day-tripper-riff');

        viewModel.setPracticeBpm(124);
        expect(viewModel.practiceBpm, 124);

        viewModel.resetPracticeBpm();
        expect(viewModel.practiceBpm, 88);
      },
    );

    test('selects a practice step and adopts its starting tempo', () async {
      await viewModel.load();

      viewModel.selectPracticeStep('tempo');

      expect(viewModel.selectedPracticeStep?.title, '原速へ橋渡し');
      expect(viewModel.practiceBpm, 84);

      viewModel.setPracticeBpm(90);
      viewModel.resetPracticeBpm();
      expect(viewModel.practiceBpm, 84);
    });

    test('opens only a resource belonging to the selected song', () async {
      final links = _FakeGuitarLessonLinkService();
      final linkedViewModel = BeatlesGuitarTabsViewModel(
        repository: const LocalGuitarTabRepository(
          catalogService: GuitarTabCatalogService(),
        ),
        courseRepository: LocalGuitarCourseRepository(
          catalogService: const GuitarDailyCourseCatalogService(),
          progressService: progressService,
        ),
        linkService: links,
        buildCourseSnapshot: const BuildGuitarCourseSnapshotUseCase(),
        clock: () => DateTime(2026, 8, 13),
      );
      addTearDown(linkedViewModel.dispose);
      await linkedViewModel.load();

      expect(await linkedViewModel.openResource('musescore'), isTrue);
      expect(
        links.opened.single,
        Uri.parse('https://ja.musescore.com/user/6375061/scores/7758575'),
      );
      expect(await linkedViewModel.openResource('unknown'), isFalse);
    });

    test('exposes a retryable failure state', () async {
      final failed = BeatlesGuitarTabsViewModel(
        repository: const _FailingGuitarTabRepository(),
        courseRepository: LocalGuitarCourseRepository(
          catalogService: const GuitarDailyCourseCatalogService(),
          progressService: progressService,
        ),
        linkService: _FakeGuitarLessonLinkService(),
        buildCourseSnapshot: const BuildGuitarCourseSnapshotUseCase(),
      );
      addTearDown(failed.dispose);

      await failed.load();

      expect(failed.status, BeatlesGuitarTabsStatus.failure);
      expect(failed.errorMessage, isNotEmpty);
      expect(failed.songs, isEmpty);
    });

    test('persists daily tasks and unlocks the next course day', () async {
      await viewModel.load();

      for (final task in viewModel.courseSnapshot!.currentDay!.tasks) {
        expect(await viewModel.toggleDailyTask(task.id), isTrue);
      }
      expect(viewModel.courseSnapshot?.canCompleteCurrentDay, isTrue);

      expect(await viewModel.completeCurrentCourseDay(), isTrue);

      expect(viewModel.courseSnapshot?.completedDayCount, 1);
      expect(viewModel.courseSnapshot?.currentDay?.dayNumber, 2);
      expect(viewModel.courseSnapshot?.currentStreak, 1);
      expect(progressService.value.completedDayNumbers, <int>[1]);
    });
  });
}

class _MemoryGuitarCourseProgressService
    implements GuitarCourseProgressService {
  GuitarCourseProgressModel value = const GuitarCourseProgressModel();

  @override
  Future<GuitarCourseProgressModel> load() async => value;

  @override
  Future<void> save(GuitarCourseProgressModel progress) async {
    value = progress;
  }
}

class _FakeGuitarLessonLinkService implements GuitarLessonLinkService {
  final List<Uri> opened = <Uri>[];

  @override
  Future<bool> openExternal(Uri uri) async {
    opened.add(uri);
    return true;
  }
}

class _FailingGuitarTabRepository implements GuitarTabRepository {
  const _FailingGuitarTabRepository();

  @override
  Future<List<GuitarTabSong>> getSongs() {
    return Future<List<GuitarTabSong>>.error(StateError('catalog unavailable'));
  }
}
