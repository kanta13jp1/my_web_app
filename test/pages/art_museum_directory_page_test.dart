import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/data/repositories/art_museum_repository.dart';
import 'package:my_web_app/domain/models/art_museum.dart';
import 'package:my_web_app/pages/art_museum_directory_page.dart';
import 'package:my_web_app/view_models/art_museum_directory_view_model.dart';

class _FakeArtMuseumRepository implements ArtMuseumRepository {
  _FakeArtMuseumRepository(this.catalog);

  final ArtMuseumCatalog catalog;

  @override
  Future<ArtMuseumCatalog> getCatalog() async => catalog;
}

class _RefreshFailureRepository implements ArtMuseumRepository {
  _RefreshFailureRepository(this.catalog);

  final ArtMuseumCatalog catalog;
  int _callCount = 0;

  @override
  Future<ArtMuseumCatalog> getCatalog() async {
    _callCount += 1;
    if (_callCount > 1) throw StateError('refresh failed');
    return catalog;
  }
}

void main() {
  testWidgets('mobile layout searches museums and opens details', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final viewModel = _viewModel();
    addTearDown(viewModel.dispose);

    await tester.pumpWidget(_app(viewModel));
    await tester.pumpAndSettle();

    expect(find.text('3館'), findsOneWidget);
    expect(find.text('3都道府県'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('museum-search-field')), '青森');
    await tester.pump();

    expect(find.text('検索結果 1館'), findsOneWidget);
    expect(viewModel.visibleMuseums.single.name, '青森県立美術館');

    await tester.fling(
      find.byKey(const Key('museum-directory-scroll')),
      const Offset(0, -1200),
      1200,
    );
    await tester.pumpAndSettle();
    expect(find.text('青森県立美術館'), findsOneWidget);
    expect(find.byType(SliverList), findsOneWidget);
    await tester.tap(find.text('青森県立美術館'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('museum-detail-sheet')), findsOneWidget);
    expect(find.text('所在地'), findsOneWidget);
    expect(find.text('青森県 青森市'), findsWidgets);
  });

  testWidgets('wide layout uses a responsive grid without overflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final viewModel = _viewModel();
    addTearDown(viewModel.dispose);

    await tester.pumpWidget(_app(viewModel));
    await tester.pumpAndSettle();

    expect(find.byType(SliverGrid), findsOneWidget);
    expect(find.text('検索結果 3館'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows an empty state and can reset filters', (tester) async {
    final viewModel = _viewModel();
    addTearDown(viewModel.dispose);

    await tester.pumpWidget(_app(viewModel));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('museum-search-field')),
      '一致しない検索語',
    );
    await tester.pump();

    expect(find.text('検索結果 0館'), findsOneWidget);
    await tester.fling(
      find.byKey(const Key('museum-directory-scroll')),
      const Offset(0, -1600),
      1200,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('museum-empty-state')), findsOneWidget);

    await tester.tap(find.text('すべて表示'));
    await tester.pump();

    expect(find.text('検索結果 3館'), findsOneWidget);
  });

  testWidgets('keeps loaded museums visible when a refresh fails', (
    tester,
  ) async {
    final catalog = _catalog();
    final viewModel = ArtMuseumDirectoryViewModel(
      repository: _RefreshFailureRepository(catalog),
    );
    addTearDown(viewModel.dispose);

    await tester.pumpWidget(_app(viewModel));
    await tester.pumpAndSettle();
    await viewModel.load();
    await tester.pump();

    expect(find.byKey(const Key('museum-refresh-error')), findsOneWidget);
    expect(find.text('検索結果 3館'), findsOneWidget);
  });
}

Widget _app(ArtMuseumDirectoryViewModel viewModel) {
  return MaterialApp(
    theme: ThemeData(useMaterial3: true),
    home: ArtMuseumDirectoryPage(
      viewModel: viewModel,
      urlLauncher: (_) async => true,
    ),
  );
}

ArtMuseumDirectoryViewModel _viewModel() {
  return ArtMuseumDirectoryViewModel(
    repository: _FakeArtMuseumRepository(_catalog()),
  );
}

ArtMuseumCatalog _catalog() {
  return ArtMuseumCatalog(
    sourceLabel: '文化庁 博物館総合サイト',
    sourceUrl: Uri.parse('https://example.com/guide'),
    downloadUrl: Uri.parse('https://example.com/museums.csv'),
    asOf: '2026-08-20',
    museums: <ArtMuseum>[
      ArtMuseum(
        name: '北海道立近代美術館',
        prefecture: '北海道',
        municipality: '札幌市',
        registrationStatus: '登録博物館',
        operatorName: '都道府県立',
        officialUrl: Uri.parse('https://example.com/hokkaido'),
      ),
      ArtMuseum(
        name: '青森県立美術館',
        prefecture: '青森県',
        municipality: '青森市',
        registrationStatus: '登録博物館',
        operatorName: '都道府県立',
        officialUrl: Uri.parse('https://example.com/aomori'),
      ),
      ArtMuseum(
        name: '東京都美術館',
        prefecture: '東京都',
        municipality: '台東区',
        registrationStatus: '指定施設',
        operatorName: '都立',
        officialUrl: Uri.parse('https://example.com/tokyo'),
      ),
    ],
  );
}
