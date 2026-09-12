import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/utils/note_route_parameters.dart';

void main() {
  test('encoded search and hierarchical tag filters survive a URL round trip', () {
    const query = 'tag:"仕事 & 個人" AND intitle:"a?b#c"';
    const state = NoteRouteParameters(
      query: query,
      tag: '仕事/個人 + #1',
      tagId: 9,
      collectionId: 24,
      includeNestedTags: true,
    );
    final uri = Uri.parse(state.location('/note-list'));
    final restored = NoteRouteParameters.fromUri(uri);

    expect(uri.path, '/note-list');
    expect(uri.fragment, isEmpty);
    expect(restored.query, query);
    expect(restored.tag, '仕事/個人 + #1');
    expect(restored.tagId, 9);
    expect(restored.collectionId, 24);
    expect(restored.includeNestedTags, isTrue);
  });

  test('note and Space links retain their target and empty links stay clean', () {
    expect(
      const NoteRouteParameters(noteId: 123).location('/note-editor'),
      '/note-editor?noteId=123',
    );
    final space = NoteRouteParameters.fromUri(
      Uri.parse('/space-sharing?spaceId=47'),
    );
    expect(space.spaceId, 47);
    expect(
      const NoteRouteParameters().location('/note-navigation'),
      '/note-navigation',
    );
  });

  test('malformed and nonpositive identifiers do not become note targets', () {
    final state = NoteRouteParameters.fromUri(
      Uri.parse(
        '/note-list?noteId=bad&tagId=-1&collectionId=0&spaceId=x&nested=yes',
      ),
    );
    expect(state.noteId, isNull);
    expect(state.tagId, isNull);
    expect(state.collectionId, isNull);
    expect(state.spaceId, isNull);
    expect(state.includeNestedTags, isFalse);
  });
}
