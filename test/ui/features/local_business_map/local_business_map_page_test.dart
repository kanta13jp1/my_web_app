import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:my_web_app/data/repositories/local_business_reference_repository.dart';
import 'package:my_web_app/data/repositories/statistical_area_boundary_repository.dart';
import 'package:my_web_app/data/services/local_business_reference_service.dart';
import 'package:my_web_app/domain/models/local_business_reference.dart';
import 'package:my_web_app/domain/models/statistical_area_boundary.dart';
import 'package:my_web_app/theme/design_tokens.dart';
import 'package:my_web_app/ui/features/local_business_map/local_business_map_feature.dart';
import 'package:my_web_app/ui/features/local_business_map/views/local_business_map_page.dart';

class _FakeRepository implements LocalBusinessReferenceRepository {
  const _FakeRepository({this.fail = false});

  final bool fail;

  @override
  Future<LocalBusinessReferenceSnapshot> load({int limit = 30}) async {
    if (fail) throw StateError('offline');
    return _snapshot;
  }
}

class _FakeLinkService implements LocalBusinessReferenceLinkService {
  @override
  Future<bool> open(Uri uri) async => true;
}

class _FakeBoundaryRepository implements StatisticalAreaBoundaryRepository {
  @override
  Future<StatisticalAreaBoundaryCatalog> loadCatalog(
    StatisticalBoundaryScope scope,
  ) async =>
      scope == StatisticalBoundaryScope.fuchuCity
          ? StatisticalAreaBoundaryCatalog.fuchuFallback
          : _catalogFor(scope);
}

StatisticalAreaBoundaryCatalog _catalogFor(StatisticalBoundaryScope scope) {
  final codes = switch (scope) {
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
    StatisticalBoundaryScope.fuchuCity => throw StateError('not used'),
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

const _snapshot = LocalBusinessReferenceSnapshot(
  officialAggregate: OfficialBusinessAggregate.fuchuHonmachi1,
  businesses: <PublicBusinessReference>[
    PublicBusinessReference(
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
    ),
    PublicBusinessReference(
      id: 'node/2',
      name: '本町カフェ',
      category: 'カフェ',
      categoryCode: 'amenity:cafe',
      latitude: 35.6666,
      longitude: 139.4781,
      distanceMeters: 35,
      address: '住所情報はOSM未登録',
      ownershipLabel: '経営形態未確認',
      sourceLabel: 'OpenStreetMap',
      sourceUrl: 'https://www.openstreetmap.org/node/2',
    ),
  ],
  centerLatitude: 35.666471,
  centerLongitude: 139.477994,
  radiusMeters: 300,
  coverageNote: '本町一丁目の中心点から300m以内の参考一覧です。',
  ownershipNote: '個人経営かどうかを推測・判定しません。',
  publicSourceLabel: 'OpenStreetMap via Overpass API',
  publicSourceUrl: 'https://www.openstreetmap.org/copyright',
  license: 'ODbL 1.0',
  fetchedAt: null,
);

StatisticalAreaBoundarySet _boundarySetForScope(
  StatisticalBoundaryScope scope,
) {
  return StatisticalAreaBoundarySet(
    scope: scope,
    datasetLabel: '行政区域テスト',
    sourceLabel: 'CODH',
    sourceUrl: 'https://example.com/${scope.name}',
    license: 'CC BY 4.0',
    boundaryNote: '2023年境界です。',
    simplificationNote: '簡略化済みです。',
    areas: const <StatisticalAreaBoundary>[
      StatisticalAreaBoundary(
        code: '13',
        name: '東京都',
        isTarget: true,
        points: <StatisticalAreaBoundaryPoint>[
          StatisticalAreaBoundaryPoint(35, 139),
          StatisticalAreaBoundaryPoint(36, 140),
          StatisticalAreaBoundaryPoint(35, 140),
          StatisticalAreaBoundaryPoint(35, 139),
        ],
      ),
      StatisticalAreaBoundary(
        code: '01',
        name: '北海道',
        isTarget: false,
        points: <StatisticalAreaBoundaryPoint>[
          StatisticalAreaBoundaryPoint(44, 141),
          StatisticalAreaBoundaryPoint(45, 142),
          StatisticalAreaBoundaryPoint(44, 142),
          StatisticalAreaBoundaryPoint(44, 141),
        ],
      ),
      StatisticalAreaBoundary(
        code: '47',
        name: '沖縄県',
        isTarget: false,
        points: <StatisticalAreaBoundaryPoint>[
          StatisticalAreaBoundaryPoint(24, 123),
          StatisticalAreaBoundaryPoint(25, 124),
          StatisticalAreaBoundaryPoint(24, 124),
          StatisticalAreaBoundaryPoint(24, 123),
        ],
      ),
    ],
  );
}

LocalBusinessReferenceSnapshot _snapshotWithBoundarySet(
  StatisticalAreaBoundarySet boundarySet,
) {
  return LocalBusinessReferenceSnapshot(
    officialAggregate: _snapshot.officialAggregate,
    businesses: const <PublicBusinessReference>[],
    centerLatitude: _snapshot.centerLatitude,
    centerLongitude: _snapshot.centerLongitude,
    radiusMeters: 0,
    coverageNote: '未連携です。',
    ownershipNote: _snapshot.ownershipNote,
    publicSourceLabel: _snapshot.publicSourceLabel,
    publicSourceUrl: _snapshot.publicSourceUrl,
    license: _snapshot.license,
    fetchedAt: null,
    statisticalBoundarySet: boundarySet,
  );
}

void _setViewport(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Widget _subject({bool fail = false}) {
  return MaterialApp(
    theme: ThemeData.dark(),
    home: LocalBusinessMapFeature(
      repository: _FakeRepository(fail: fail),
      boundaryRepository: _FakeBoundaryRepository(),
      linkService: _FakeLinkService(),
      mapBuilder:
          (context, snapshot, selectedBusinessId, onSelect, onOpenAttribution) {
        return ColoredBox(
          key: const Key('fake-local-business-map'),
          color: Colors.black,
          child: Center(
            child: Text(
              '${snapshot.statisticalBoundarySet.target.name}|'
              'selected:$selectedBusinessId',
            ),
          ),
        );
      },
    ),
  );
}

void main() {
  test('broad viewport uses whole-scope bounds instead of selected center', () {
    final selectedCenter = LatLng(
      _snapshot.centerLatitude,
      _snapshot.centerLongitude,
    );
    final viewport = statisticalBoundaryMapViewportFor(
      _boundarySetForScope(StatisticalBoundaryScope.japan),
      selectedCenter,
    );

    expect(viewport.scopeBounds, isNotNull);
    expect(viewport.scopeBounds!.south, 24);
    expect(viewport.scopeBounds!.north, 45);
    expect(viewport.scopeBounds!.west, 123);
    expect(viewport.scopeBounds!.east, 142);
    expect(viewport.maximumZoom, 4.5);
    expect(viewport.center, isNot(selectedCenter));
  });

  test('fallback viewport policy has deterministic bounds for every scope', () {
    final selectedCenter = LatLng(
      _snapshot.centerLatitude,
      _snapshot.centerLongitude,
    );
    final expectations = <StatisticalBoundaryScope,
        ({
      double south,
      double north,
      double west,
      double east,
      double maxZoom,
    })>{
      StatisticalBoundaryScope.tokyo: (
        south: 20,
        north: 36,
        west: 136,
        east: 154,
        maxZoom: 7.5,
      ),
      StatisticalBoundaryScope.kanto: (
        south: 20,
        north: 38,
        west: 136,
        east: 154,
        maxZoom: 6.5,
      ),
      StatisticalBoundaryScope.japan: (
        south: 20,
        north: 46,
        west: 122,
        east: 154,
        maxZoom: 4.5,
      ),
    };

    for (final entry in expectations.entries) {
      final set = StatisticalAreaBoundaryCatalog.fallbackFor(entry.key).select(
        entry.key.defaultAreaCode,
      );
      final viewport = statisticalBoundaryMapViewportFor(set, selectedCenter);
      expect(viewport.scopeBounds!.south, entry.value.south);
      expect(viewport.scopeBounds!.north, entry.value.north);
      expect(viewport.scopeBounds!.west, entry.value.west);
      expect(viewport.scopeBounds!.east, entry.value.east);
      expect(viewport.maximumZoom, entry.value.maxZoom);
    }

    final fuchuViewport = statisticalBoundaryMapViewportFor(
      StatisticalAreaBoundarySet.fuchuHonmachi1,
      selectedCenter,
    );
    expect(fuchuViewport.scopeBounds, isNull);
    expect(fuchuViewport.center, selectedCenter);
  });

  testWidgets('shows the official 20 separately from public references', (
    tester,
  ) async {
    _setViewport(tester, const Size(1200, 900));
    await tester.pumpWidget(_subject());
    await tester.pumpAndSettle();

    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    final title = appBar.title! as Text;
    expect(title.style?.color, DesignTokens.textPrimary);
    expect(
      find.byKey(const Key('official-business-aggregate-card')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('sole-proprietor-count-metric')),
      findsOneWidget,
    );
    expect(find.text('公開情報の参考一覧'), findsOneWidget);
    expect(find.text('2件'), findsOneWidget);
    expect(find.text('経営形態未確認'), findsNWidgets(2));
    expect(find.text('本町商店'), findsOneWidget);
    expect(find.textContaining('個人経営20件'), findsOneWidget);
    expect(
      find.byKey(const Key('statistical-boundary-source-link')),
      findsOneWidget,
    );
    expect(find.textContaining('統計上の境界'), findsWidgets);
    expect(find.byKey(const Key('fuchu-area-selector')), findsOneWidget);

    await tester.tap(find.byKey(const Key('public-business-reference-0')));
    await tester.pump();
    expect(find.text('本町一丁目|selected:node/1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('switches to another Fuchu town without copying statistics', (
    tester,
  ) async {
    _setViewport(tester, const Size(1200, 900));
    await tester.pumpWidget(_subject());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('fuchu-area-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('宮町三丁目').last);
    await tester.pumpAndSettle();

    expect(find.text('東京都府中市 宮町三丁目'), findsOneWidget);
    expect(find.text('宮町三丁目|selected:null'), findsOneWidget);
    expect(
      find.byKey(const Key('official-aggregate-unavailable-note')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('sole-proprietor-count-metric')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('widens and narrows across all four boundary scopes', (
    tester,
  ) async {
    _setViewport(tester, const Size(1200, 1000));
    await tester.pumpWidget(_subject());
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('statistical-boundary-scope-selector')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('boundary-scope-tokyo')));
    await tester.pumpAndSettle();
    expect(find.text('東京都 府中市'), findsOneWidget);
    expect(find.text('東京都内 60市区町村'), findsOneWidget);
    expect(find.byKey(const Key('sole-proprietor-count-metric')), findsNothing);

    await tester.tap(find.byKey(const Key('boundary-scope-kanto')));
    await tester.pumpAndSettle();
    expect(find.text('関東地方 東京都'), findsOneWidget);
    expect(find.text('関東 7都県'), findsOneWidget);

    await tester.tap(find.byKey(const Key('boundary-scope-japan')));
    await tester.pumpAndSettle();
    expect(find.text('日本 東京都'), findsOneWidget);
    expect(find.text('全国 47都道府県'), findsOneWidget);

    await tester.tap(find.byKey(const Key('boundary-scope-fuchuCity')));
    await tester.pumpAndSettle();
    expect(find.text('東京都府中市 本町一丁目'), findsOneWidget);
    expect(
      find.byKey(const Key('sole-proprietor-count-metric')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders town polygons separately from the public radius', (
    tester,
  ) async {
    _setViewport(tester, const Size(700, 600));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => buildLocalBusinessReferenceMap(
              context,
              _snapshot,
              null,
              (_) {},
              () {},
              includeBaseTiles: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final boundaryLayer = tester.widget<PolygonLayer<String>>(
      find.byKey(const Key('statistical-boundary-polygon-layer')),
    );
    expect(boundaryLayer.polygons, hasLength(7));
    expect(boundaryLayer.polygons.last.label, '本町一丁目');
    expect(boundaryLayer.polygons.last.borderStrokeWidth, 3);
    expect(
      find.byKey(const Key('public-reference-radius-layer')),
      findsOneWidget,
    );
    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    expect(map.options.initialCameraFit, isNull);
    expect(map.options.initialCenter.latitude, _snapshot.centerLatitude);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fits Japan viewport to every scope polygon', (tester) async {
    _setViewport(tester, const Size(700, 600));
    final boundarySet = _boundarySetForScope(StatisticalBoundaryScope.japan);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => buildLocalBusinessReferenceMap(
              context,
              _snapshotWithBoundarySet(boundarySet),
              null,
              (_) {},
              () {},
              includeBaseTiles: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    final fit = map.options.initialCameraFit! as FitBounds;
    expect(fit.bounds.south, 24);
    expect(fit.bounds.north, 45);
    expect(fit.bounds.west, 123);
    expect(fit.bounds.east, 142);
    expect(fit.padding, const EdgeInsets.all(28));
    expect(fit.maxZoom, 4.5);
    expect(
      find.byKey(const ValueKey('statistical-area-map-japan-13')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses the compact scroll layout without overflow', (
    tester,
  ) async {
    _setViewport(tester, const Size(390, 844));
    await tester.pumpWidget(_subject());
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('local-business-compact-layout')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('fake-local-business-map')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('本町カフェ'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('本町カフェ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps the official card when public loading fails', (
    tester,
  ) async {
    _setViewport(tester, const Size(390, 844));
    await tester.pumpWidget(_subject(fail: true));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('official-business-aggregate-card')),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.textContaining('公開参考情報を取得できませんでした'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('公開参考情報を取得できませんでした'), findsOneWidget);
    expect(find.text('0件'), findsOneWidget);
  });
}
