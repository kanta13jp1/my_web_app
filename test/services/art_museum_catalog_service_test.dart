import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/data/repositories/art_museum_repository.dart';
import 'package:my_web_app/data/services/art_museum_catalog_service.dart';
import 'package:my_web_app/domain/models/art_museum.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ArtMuseumCatalogService', () {
    test('parses source metadata and valid museum rows', () {
      final catalog = ArtMuseumCatalogService.parse('''
{
  "schemaVersion": 1,
  "source": {
    "label": "文化庁",
    "url": "https://example.com/guide",
    "downloadUrl": "https://example.com/data.csv",
    "asOf": "2026-08-20"
  },
  "museums": [
    {
      "name": "青森県立美術館",
      "prefecture": "青森県",
      "municipality": "青森市",
      "registrationStatus": "登録博物館",
      "operator": "都道府県立",
      "officialUrl": "https://example.com/aomori"
    }
  ]
}
''');

      expect(catalog.schemaVersion, 1);
      expect(catalog.asOf, '2026-08-20');
      expect(catalog.museums, hasLength(1));
      expect(catalog.museums.single.name, '青森県立美術館');
    });

    test('rejects unsupported schemas and malformed rows', () {
      expect(
        () => ArtMuseumCatalogService.parse('''
{
  "schemaVersion": 2,
  "source": {"label": "文化庁"},
  "museums": [{"name": "美術館", "prefecture": "東京都"}]
}
'''),
        throwsFormatException,
      );
      expect(
        () => ArtMuseumCatalogService.parse('''
{
  "schemaVersion": 1,
  "source": {"label": "文化庁"},
  "museums": ["invalid"]
}
'''),
        throwsFormatException,
      );
    });

    test('rejects a catalog without usable museums', () {
      expect(
        () => ArtMuseumCatalogService.parse('''
{
  "schemaVersion": 1,
  "source": {"label": "文化庁"},
  "museums": []
}
'''),
        throwsFormatException,
      );
    });

    test('bundled catalog covers all 47 prefectures', () async {
      final repository = AssetArtMuseumRepository(
        catalogService: ArtMuseumCatalogService(),
      );

      final catalog = await repository.getCatalog();
      final prefectures =
          catalog.museums.map((museum) => museum.prefecture).toSet();

      expect(catalog.museums, hasLength(520));
      expect(prefectures, kJapanPrefectures.toSet());
      expect(catalog.prefectureCount, 47);
      expect(
        catalog.museums.where(
          (museum) => RegExp(r'^[◎○〇]').hasMatch(museum.name),
        ),
        isEmpty,
      );
    });
  });
}
