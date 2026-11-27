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

/// Normalizes a Wiki embedded table row from `hub_data` (`sheet_row`).
Map<String, dynamic> normalizeWikiTableRowResponse(Map<String, dynamic> row) {
  final rawMetadata = row['metadata'];
  final metadata = rawMetadata is Map<String, dynamic>
      ? rawMetadata
      : const <String, dynamic>{};
  final Object? rawData = metadata['data'] ?? row['data'];
  final Map<Object?, Object?>? dataMap = rawData is Map ? rawData : null;
  final Object? contentSource = dataMap != null
      ? (dataMap['content'] ?? dataMap)
      : (metadata['content'] ?? row['content'] ?? rawData ?? '');
  final id = row['id'] ?? metadata['id'];
  return <String, dynamic>{
    ...row,
    ...metadata,
    'id': id,
    'sheet_id': metadata['sheet_id'] ?? row['sheet_id'],
    'content': contentSource.toString(),
    'createdAt': row['created_at'] ?? row['createdAt'] ?? metadata['createdAt'],
  };
}
