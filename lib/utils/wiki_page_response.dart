/// Maps the hub response envelope to the Wiki display fields.
/// Row identity is authoritative; metadata may contain legacy request fields.
Map<String, dynamic> normalizeWikiPageResponse(Map<String, dynamic> row) {
  final rawMetadata = row['metadata'];
  final metadata = rawMetadata is Map<String, dynamic>
      ? rawMetadata
      : const <String, dynamic>{};
  final id = row['id'] ?? row['page_id'] ?? metadata['id'];
  return <String, dynamic>{
    ...row,
    ...metadata,
    'id': id,
    'page_id': id,
    'createdAt': row['created_at'] ?? row['createdAt'] ?? metadata['createdAt'],
  };
}
