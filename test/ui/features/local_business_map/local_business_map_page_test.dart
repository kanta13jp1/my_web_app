import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
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
  Future<StatisticalAreaBoundaryCatalog> loadFuchuCatalog() async =>
      StatisticalAreaBoundaryCatalog.fuchuFallback;
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
