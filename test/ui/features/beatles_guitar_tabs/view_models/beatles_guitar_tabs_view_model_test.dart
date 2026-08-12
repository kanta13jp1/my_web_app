import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/data/repositories/guitar_tab_repository.dart';
import 'package:my_web_app/data/services/guitar_tab_catalog_service.dart';
import 'package:my_web_app/domain/models/guitar_tab_song.dart';
import 'package:my_web_app/ui/features/beatles_guitar_tabs/view_models/beatles_guitar_tabs_view_model.dart';

void main() {
  group('BeatlesGuitarTabsViewModel', () {
    late BeatlesGuitarTabsViewModel viewModel;

    setUp(() {
      viewModel = BeatlesGuitarTabsViewModel(
        repository: const LocalGuitarTabRepository(
          catalogService: GuitarTabCatalogService(),
        ),
      );
    });

    tearDown(() => viewModel.dispose());

    test('loads songs and selects the first practice', () async {
      await viewModel.load();

      expect(viewModel.status, BeatlesGuitarTabsStatus.ready);
      expect(viewModel.songs, hasLength(4));
      expect(viewModel.selectedSong?.title, 'Blackbird');
      expect(viewModel.practiceBpm, 72);
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

    test('exposes a retryable failure state', () async {
      final failed = BeatlesGuitarTabsViewModel(
        repository: const _FailingGuitarTabRepository(),
      );
      addTearDown(failed.dispose);

      await failed.load();

      expect(failed.status, BeatlesGuitarTabsStatus.failure);
      expect(failed.errorMessage, isNotEmpty);
      expect(failed.songs, isEmpty);
    });
  });
}

class _FailingGuitarTabRepository implements GuitarTabRepository {
  const _FailingGuitarTabRepository();

  @override
  Future<List<GuitarTabSong>> getSongs() {
    return Future<List<GuitarTabSong>>.error(StateError('catalog unavailable'));
  }
}
