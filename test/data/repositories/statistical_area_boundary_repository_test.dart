import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/data/repositories/statistical_area_boundary_repository.dart';

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
}
