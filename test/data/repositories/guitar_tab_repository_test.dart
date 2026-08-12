import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/data/repositories/guitar_tab_repository.dart';
import 'package:my_web_app/data/services/guitar_tab_catalog_service.dart';
import 'package:my_web_app/domain/models/guitar_tab_song.dart';

void main() {
  group('LocalGuitarTabRepository', () {
    const repository = LocalGuitarTabRepository(
      catalogService: GuitarTabCatalogService(),
    );

    test('maps the bundled catalog to immutable domain models', () async {
      final songs = await repository.getSongs();

      expect(songs, hasLength(4));
      expect(songs.first.title, 'Blackbird');
      expect(songs.first.difficulty, GuitarTabDifficulty.intermediate);
      expect(songs.first.sections.single.lines, hasLength(6));
      expect(() => songs.add(songs.first), throwsUnsupportedError);
      expect(
        () => songs.first.techniques.add('mutated'),
        throwsUnsupportedError,
      );
      expect(
        () => songs.first.sections.single.lines.add('mutated'),
        throwsUnsupportedError,
      );
    });
  });
}
