import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/domain/models/local_business_reference.dart';
import 'package:my_web_app/domain/models/statistical_area_boundary.dart';

void main() {
  test('parses official aggregate and keeps public references separate', () {
    final snapshot = LocalBusinessReferenceSnapshot.fromJson(<String, dynamic>{
      'target': <String, dynamic>{
        'center': <String, dynamic>{
          'latitude': 35.666471,
          'longitude': 139.477994,
        },
        'radiusMeters': 300,
      },
      'officialAggregate': <String, dynamic>{
        'soleProprietorEstablishments': 20,
        'totalEstablishments': 86,
      },
      'publicReference': <String, dynamic>{
        'businesses': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'node/1',
            'name': '本町商店',
            'category': '食品店',
            'latitude': 35.6665,
            'longitude': 139.478,
            'distanceMeters': 20,
            'address': '府中市 本町一丁目',
            'ownershipLabel': '経営形態未確認',
            'sourceLabel': 'OpenStreetMap',
            'sourceUrl': 'https://www.openstreetmap.org/node/1',
          },
        ],
        'coverageNote': '中心点から300m以内',
        'ownershipNote': '個人経営かどうかを判定しません。',
        'sourceLabel': 'OpenStreetMap via Overpass API',
        'sourceUrl': 'https://www.openstreetmap.org/copyright',
        'license': 'ODbL 1.0',
        'fetchedAt': '2026-08-14T12:00:00Z',
      },
    });

    expect(snapshot.officialAggregate.soleProprietorEstablishments, 20);
    expect(snapshot.officialAggregate.totalEstablishments, 86);
    expect(snapshot.businesses, hasLength(1));
    expect(snapshot.businesses.single.ownershipLabel, '経営形態未確認');
    expect(snapshot.fetchedAt, DateTime.utc(2026, 8, 14, 12));
  });

  test('uses the official fallback and skips incomplete public rows', () {
    final snapshot = LocalBusinessReferenceSnapshot.fromJson(<String, dynamic>{
      'publicReference': <String, dynamic>{
        'businesses': <Map<String, dynamic>>[
          <String, dynamic>{'id': 'node/1', 'name': '出典なし'},
        ],
      },
    });

    expect(snapshot.officialAggregate.soleProprietorEstablishments, 20);
    expect(snapshot.businesses, isEmpty);
  });

  test('provides Honmachi 1 and touching statistical boundaries', () {
    const boundarySet = StatisticalAreaBoundarySet.fuchuHonmachi1;
    final target = boundarySet.target;

    expect(boundarySet.areas, hasLength(7));
    expect(target.code, '13206021001');
    expect(target.name, '本町一丁目');
    expect(target.points.length, greaterThan(40));
    expect(target.points.first.latitude, target.points.last.latitude);
    expect(target.points.first.longitude, target.points.last.longitude);
    expect(boundarySet.sourceUrl, startsWith('https://'));
    expect(boundarySet.boundaryNote, contains('一致しない場合'));
  });
}
