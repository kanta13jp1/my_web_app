/// URL state for note navigation; queries stay encoded and filters survive reload.
class NoteRouteParameters {
  const NoteRouteParameters({
    this.noteId,
    this.query,
    this.tag,
    this.tagId,
    this.collectionId,
    this.spaceId,
    this.includeNestedTags = false,
  });

  factory NoteRouteParameters.fromUri(Uri uri) {
    final values = uri.queryParameters;
    return NoteRouteParameters(
      noteId: _positiveId(values['noteId']),
      query: values['query'],
      tag: values['tag'],
      tagId: _positiveId(values['tagId']),
      collectionId: _positiveId(values['collectionId']),
      spaceId: _positiveId(values['spaceId']),
      includeNestedTags: values['nested'] == 'true',
    );
  }

  final int? noteId;
  final String? query;
  final String? tag;
  final int? tagId;
  final int? collectionId;
  final int? spaceId;
  final bool includeNestedTags;

  String location(String path) {
    final values = <String, String>{
      if (noteId != null) 'noteId': noteId.toString(),
      if (query != null) 'query': query!,
      if (tag != null) 'tag': tag!,
      if (tagId != null) 'tagId': tagId.toString(),
      if (collectionId != null) 'collectionId': collectionId.toString(),
      if (spaceId != null) 'spaceId': spaceId.toString(),
      if (includeNestedTags) 'nested': 'true',
    };
    return Uri(
      path: path,
      queryParameters: values.isEmpty ? null : values,
    ).toString();
  }

  static int? _positiveId(String? value) {
    final parsed = int.tryParse(value ?? '');
    return parsed != null && parsed > 0 ? parsed : null;
  }
}
