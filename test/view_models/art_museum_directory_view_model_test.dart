import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/data/repositories/art_museum_repository.dart';
import 'package:my_web_app/domain/models/art_museum.dart';
import 'package:my_web_app/view_models/art_museum_directory_view_model.dart';

class _FakeArtMuseumRepository implements ArtMuseumRepository {
  _FakeArtMuseumRepository(this.catalog);

  final ArtMuseumCatalog catalog;

  @override
  Future<ArtMuseumCatalog> getCatalog() async => catalog;
}

class _CompletingArtMuseumRepository implements ArtMuseumRepository {
  final Completer<ArtMuseumCatalog> completer = Completer<ArtMuseumCatalog>();

  @override
  Future<ArtMuseumCatalog> getCatalog() => completer.future;
}

void main() {
  late ArtMuseumDirectoryViewModel viewModel;

  setUp(() {
    viewModel = ArtMuseumDirectoryViewModel(
      repository: _FakeArtMuseumRepository(_catalog()),
    );
  });

  tearDown(() => viewModel.dispose());

  test('loads the catalog and exposes every museum', () async {
    await viewModel.load();

    expect(viewModel.status, ArtMuseumDirectoryStatus.ready);
    expect(viewModel.visibleMuseums, hasLength(4));
  });

  test('filters by region, prefecture, and multiple search terms', () async {
    await viewModel.load();

    viewModel.selectRegion(JapanRegion.tohoku);
    expect(viewModel.visibleMuseums.map((museum) => museum.name), ['青森県立美術館']);

    viewModel.selectRegion(JapanRegion.all);
    viewModel.selectPrefecture('東京都');
    viewModel.updateQuery('東京 都立');
    expect(viewModel.visibleMuseums.map((museum) => museum.name), ['東京都美術館']);
  });

  test('clearFilters restores the complete catalog', () async {
    await viewModel.load();
    viewModel.selectRegion(JapanRegion.hokkaido);
    viewModel.updateQuery('存在しない');
    expect(viewModel.visibleMuseums, isEmpty);

    viewModel.clearFilters();

    expect(viewModel.selectedRegion, JapanRegion.all);
    expect(viewModel.selectedPrefecture, isNull);
    expect(viewModel.query, isEmpty);
    expect(viewModel.visibleMuseums, hasLength(4));
  });

  test('ignores a pending result after disposal', () async {
    final repository = _CompletingArtMuseumRepository();
    final disposedViewModel = ArtMuseumDirectoryViewModel(
      repository: repository,
    );

    final loadFuture = disposedViewModel.load();
    disposedViewModel.dispose();
    repository.completer.complete(_catalog());

    await expectLater(loadFuture, completes);
  });
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
      const ArtMuseum(
        name: '金沢21世紀美術館',
        prefecture: '石川県',
        municipality: '金沢市',
        registrationStatus: '登録博物館',
        operatorName: '市区町村立',
      ),
    ],
  );
}
