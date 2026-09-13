import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/data/repositories/local_business_reference_repository.dart';
import 'package:my_web_app/data/repositories/statistical_area_boundary_repository.dart';
import 'package:my_web_app/data/services/local_business_reference_service.dart';
import 'package:my_web_app/domain/models/local_business_reference.dart';
import 'package:my_web_app/domain/models/statistical_area_boundary.dart';
import 'package:my_web_app/ui/features/local_business_map/view_models/local_business_map_view_model.dart';

class _FakeRepository implements LocalBusinessReferenceRepository {
  _FakeRepository(this.snapshot, {this.error});

  final LocalBusinessReferenceSnapshot snapshot;
  final Object? error;

  @override
  Future<LocalBusinessReferenceSnapshot> load({int limit = 30}) async {
    if (error != null) throw Exception(error.toString());
    return snapshot;
  }
}

class _FakeLinkService implements LocalBusinessReferenceLinkService {
  Uri? opened;

  @override
  Future<bool> open(Uri uri) async {
    opened = uri;
    return true;
  }
}

class _FakeBoundaryRepository implements StatisticalAreaBoundaryRepository {
  const _FakeBoundaryRepository(this.catalog);

  final StatisticalAreaBoundaryCatalog catalog;

  @override
  Future<StatisticalAreaBoundaryCatalog> loadCatalog(
    StatisticalBoundaryScope scope,
  ) async =>
      scope == StatisticalBoundaryScope.fuchuCity
          ? catalog
          : _catalogFor(scope);
}

StatisticalAreaBoundaryCatalog _catalogFor(StatisticalBoundaryScope scope) {
  final codes = switch (scope) {
    StatisticalBoundaryScope.fuchuCity => <String>['13206021001'],
    StatisticalBoundaryScope.tokyo => <String>[
        '13206',
        for (var index = 1; index < 60; index++)
          '13${index.toString().padLeft(3, '0')}',
      ],
    StatisticalBoundaryScope.kanto => <String>[
        '08',
        '09',
        '10',
        '11',
        '12',
        '13',
        '14',
      ],
    StatisticalBoundaryScope.japan => <String>[
        for (var index = 1; index <= 47; index++)
          index.toString().padLeft(2, '0'),
      ],
  };
  return StatisticalAreaBoundaryCatalog(
    scope: scope,
    municipalityName: scope.regionLabel,
    datasetLabel: '行政区域テスト',
    sourceLabel: 'CODH',
    sourceUrl: 'https://example.com/${scope.name}',
    license: 'CC BY 4.0',
    boundaryNote: '2023年境界です。',
    simplificationNote: '簡略化済みです。',
    areas: <StatisticalAreaBoundary>[
      for (var index = 0; index < codes.length; index++)
        StatisticalAreaBoundary(
          code: codes[index],
          name: codes[index] == scope.defaultAreaCode
              ? (scope == StatisticalBoundaryScope.tokyo ? '府中市' : '東京都')
              : '地域$index',
          isTarget: codes[index] == scope.defaultAreaCode,
          points: <StatisticalAreaBoundaryPoint>[
            StatisticalAreaBoundaryPoint(35 + index / 100, 139),
            StatisticalAreaBoundaryPoint(35 + index / 100, 140),
            StatisticalAreaBoundaryPoint(36 + index / 100, 140),
            StatisticalAreaBoundaryPoint(35 + index / 100, 139),
          ],
        ),
    ],
  );
}

final _catalog = StatisticalAreaBoundaryCatalog(
  municipalityName: '東京都府中市',
  datasetLabel: 'テスト境界',
  sourceLabel: 'テスト出典',
  sourceUrl: 'https://example.com/fuchu.topojson',
  license: 'CC BY 4.0',
  boundaryNote: '統計上の境界です。',
  simplificationNote: '簡略化済みです。',
  areas: <StatisticalAreaBoundary>[
    StatisticalAreaBoundarySet.fuchuHonmachi1.target,
    const StatisticalAreaBoundary(
      code: '13206001001',
      name: '多磨町一丁目',
      isTarget: false,
      centerLatitude: 35.679328,
      centerLongitude: 139.520087,
      points: <StatisticalAreaBoundaryPoint>[
        StatisticalAreaBoundaryPoint(35.67, 139.51),
        StatisticalAreaBoundaryPoint(35.68, 139.51),
        StatisticalAreaBoundaryPoint(35.68, 139.52),
        StatisticalAreaBoundaryPoint(35.67, 139.51),
      ],
    ),
  ],
);

const _business = PublicBusinessReference(
  id: 'node/1',
  name: '本町商店',
  category: '食品店',
  categoryCode: 'shop:deli',
  latitude: 35.6665,
  longitude: 139.478,
  distanceMeters: 20,
  address: '府中市 本町一丁目',
  ownershipLabel: '経営形態未確認',
  sourceLabel: 'OpenStreetMap',
  sourceUrl: 'https://www.openstreetmap.org/node/1',
);

const _snapshot = LocalBusinessReferenceSnapshot(
  officialAggregate: OfficialBusinessAggregate.fuchuHonmachi1,
  businesses: <PublicBusinessReference>[_business],
  centerLatitude: 35.666471,
  centerLongitude: 139.477994,
  radiusMeters: 300,
  coverageNote: '中心点から300m以内',
  ownershipNote: '個人経営かどうかを判定しません。',
  publicSourceLabel: 'OpenStreetMap via Overpass API',
  publicSourceUrl: 'https://www.openstreetmap.org/copyright',
  license: 'ODbL 1.0',
  fetchedAt: null,
);

void main() {
  test('loads, selects a reference, and opens its public source', () async {
    final linkService = _FakeLinkService();
    final viewModel = LocalBusinessMapViewModel(
      repository: _FakeRepository(_snapshot),
      linkService: linkService,
    );

    await viewModel.load();
    viewModel.selectBusiness('node/1');
    final opened = await viewModel.openBusinessSource('node/1');

    expect(viewModel.status, LocalBusinessMapStatus.ready);
    expect(viewModel.selectedBusiness?.name, '本町商店');
    expect(opened, isTrue);
    expect(linkService.opened.toString(), _business.sourceUrl);
  });

  test('opens the statistical boundary source', () async {
    final linkService = _FakeLinkService();
    final viewModel = LocalBusinessMapViewModel(
      repository: _FakeRepository(_snapshot),
      linkService: linkService,
    );

    final opened = await viewModel.openBoundarySource();

    expect(opened, isTrue);
    expect(
      linkService.opened.toString(),
      _snapshot.statisticalBoundarySet.sourceUrl,
    );
  });

  test('switches the boundary without reusing Honmachi statistics', () async {
    final viewModel = LocalBusinessMapViewModel(
      repository: _FakeRepository(_snapshot),
      boundaryRepository: _FakeBoundaryRepository(_catalog),
      linkService: _FakeLinkService(),
    );

    await viewModel.load();
    viewModel.selectArea('13206001001');

    expect(viewModel.selectedArea.name, '多磨町一丁目');
    expect(viewModel.hasOfficialAggregateForSelectedArea, isFalse);
    expect(viewModel.snapshot.businesses, isEmpty);
    expect(viewModel.snapshot.radiusMeters, 0);
    expect(
      viewModel.snapshot.statisticalBoundarySet.target.code,
      '13206001001',
    );
    expect(viewModel.snapshot.centerLatitude, 35.679328);
  });

  test(
    'keeps official aggregate visible after public-source failure',
    () async {
      final viewModel = LocalBusinessMapViewModel(
        repository: _FakeRepository(_snapshot, error: StateError('offline')),
        linkService: _FakeLinkService(),
      );

      await viewModel.load();

      expect(viewModel.status, LocalBusinessMapStatus.failure);
      expect(
        viewModel.snapshot.officialAggregate.soleProprietorEstablishments,
        20,
      );
      expect(viewModel.errorMessage, contains('公式集計値'));
    },
  );

  test('uses a boundary-only error after switching towns', () async {
    final viewModel = LocalBusinessMapViewModel(
      repository: _FakeRepository(_snapshot, error: StateError('offline')),
      boundaryRepository: _FakeBoundaryRepository(_catalog),
      linkService: _FakeLinkService(),
    );

    await viewModel.load();
    viewModel.selectArea('13206001001');

    expect(viewModel.errorMessage, contains('町丁境界'));
    expect(viewModel.errorMessage, isNot(contains('公式集計値')));
  });

  test('widens through four scopes and narrows without stale data', () async {
    final viewModel = LocalBusinessMapViewModel(
      repository: _FakeRepository(_snapshot),
      boundaryRepository: _FakeBoundaryRepository(_catalog),
      linkService: _FakeLinkService(),
    );

    await viewModel.load();
    viewModel.selectBusiness('node/1');
    await viewModel.selectScope(StatisticalBoundaryScope.tokyo);
    expect(viewModel.availableAreas, hasLength(60));
    expect(viewModel.selectedAreaCode, '13206');
    expect(viewModel.snapshot.businesses, isEmpty);
    expect(viewModel.snapshot.radiusMeters, 0);
    expect(viewModel.selectedBusinessId, isNull);

    await viewModel.selectScope(StatisticalBoundaryScope.kanto);
    expect(viewModel.availableAreas, hasLength(7));
    await viewModel.selectScope(StatisticalBoundaryScope.japan);
    expect(viewModel.availableAreas, hasLength(47));
    await viewModel.selectScope(StatisticalBoundaryScope.fuchuCity);

    expect(viewModel.selectedAreaCode, '13206021001');
    expect(viewModel.snapshot.businesses, <PublicBusinessReference>[_business]);
    expect(viewModel.snapshot.radiusMeters, 300);
    expect(viewModel.hasOfficialAggregateForSelectedArea, isTrue);
  });
}
