import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/data/repositories/statistical_area_boundary_repository.dart';
import 'package:my_web_app/domain/models/statistical_area_boundary.dart';

Map<String, dynamic> _topologyFixture() {
  return <String, dynamic>{
    'type': 'Topology',
    'objects': <String, dynamic>{
      'town': <String, dynamic>{
        'type': 'GeometryCollection',
        'geometries': <Map<String, dynamic>>[
          for (var index = 0; index < 101; index++)
            <String, dynamic>{
              'type': 'Polygon',
              'arcs': <List<int>>[
                <int>[0],
              ],
              'properties': <String, dynamic>{
                'KEY_CODE': index == 50
                    ? '13206021001'
                    : '13206${index.toString().padLeft(6, '0')}',
                'S_NAME': index == 50 ? '本町一丁目' : 'テスト町$index',
                'X_CODE': 139.48 + index / 10000,
                'Y_CODE': 35.66 + index / 10000,
              },
            },
        ],
      },
    },
    'arcs': <List<List<double>>>[
      <List<double>>[
        <double>[139.47, 35.66],
        <double>[139.48, 35.66],
        <double>[139.48, 35.67],
        <double>[139.47, 35.67],
        <double>[139.47, 35.66],
      ],
    ],
  };
}

Map<String, dynamic> _administrativeFixture({required bool municipalities}) {
  final count = municipalities ? 60 : 47;
  return <String, dynamic>{
    'type': 'Topology',
    'objects': <String, dynamic>{
      'areas': <String, dynamic>{
        'type': 'GeometryCollection',
        'geometries': <Map<String, dynamic>>[
          for (var index = 1; index <= count; index++)
            for (var municipality = 1;
                municipality <= (municipalities ? 1 : 2);
                municipality++)
              <String, dynamic>{
                'type': 'MultiPolygon',
                'arcs': <List<List<int>>>[
                  <List<int>>[
                    <int>[0],
                  ],
                ],
                'properties': <String, dynamic>{
                  'N03_001': index == 13 ? '東京都' : '都県$index',
                  'N03_004': municipalities
                      ? (index == 6 ? '府中市' : '市区町村$index')
                      : '自治体$municipality',
                  'N03_007': municipalities
                      ? (index == 6
                          ? '13206'
                          : '13${index.toString().padLeft(3, '0')}')
                      : '${index.toString().padLeft(2, '0')}'
                          '${municipality.toString().padLeft(3, '0')}',
                },
              },
        ],
      },
    },
    'arcs': <List<List<double>>>[
      <List<double>>[
        <double>[139, 35],
        <double>[140, 35],
        <double>[140, 36],
        <double>[139, 36],
        <double>[139, 35],
      ],
    ],
  };
}

void main() {
  test('decodes a Fuchu TopoJSON catalog and selects a town', () {
    final catalog = const FuchuStatisticalAreaTopologyDecoder().decode(
      _topologyFixture(),
    );

    expect(catalog.municipalityName, '東京都府中市');
    expect(catalog.areas, hasLength(101));
    expect(catalog.findByCode('13206021001')?.name, '本町一丁目');

    final selection = catalog.select('13206021001');
    expect(selection.target.code, '13206021001');
    expect(selection.target.points.first.latitude, 35.66);
    expect(selection.target.points.last.latitude, 35.66);
    expect(selection.sourceUrl, contains('13206021001'));
  });

  test('rejects incomplete municipality data', () {
    expect(
      () => const FuchuStatisticalAreaTopologyDecoder().decode(
        <String, dynamic>{
          'type': 'Topology',
          'objects': <String, dynamic>{
            'town': <String, dynamic>{
              'geometries': const <dynamic>[],
            },
          },
          'arcs': const <dynamic>[],
        },
      ),
      throwsA(isA<Exception>()),
    );
  });

  test('decodes Tokyo municipality boundaries', () {
    final catalog =
        const FuchuStatisticalAreaTopologyDecoder().decodeAdministrative(
      _administrativeFixture(municipalities: true),
      StatisticalBoundaryScope.tokyo,
    );

    expect(catalog.scope, StatisticalBoundaryScope.tokyo);
    expect(catalog.areas, hasLength(60));
    expect(catalog.findByCode('13206')?.name, '府中市');
    expect(catalog.select('13206').target.hasGeometry, isTrue);
  });

  test('filters Kanto and keeps all 47 prefectures for Japan', () {
    const decoder = FuchuStatisticalAreaTopologyDecoder();
    final topology = _administrativeFixture(municipalities: false);

    final kanto = decoder.decodeAdministrative(
      topology,
      StatisticalBoundaryScope.kanto,
    );
    final japan = decoder.decodeAdministrative(
      topology,
      StatisticalBoundaryScope.japan,
    );

    expect(
      kanto.areas.map((area) => area.code),
      <String>['08', '09', '10', '11', '12', '13', '14'],
    );
    expect(japan.areas, hasLength(47));
    expect(japan.areas.map((area) => area.code).toSet(), hasLength(47));
    expect(japan.areas.map((area) => area.name).toSet(), hasLength(47));
    expect(japan.select('13').target.name, '東京都');
  });
}
