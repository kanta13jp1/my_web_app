import 'package:my_web_app/utils/wiki_page_response.dart';

typedef WikiInvoke = Future<dynamic> Function(Map<String, dynamic> body);

class WikiPageBatch {
  WikiPageBatch(List<Map<String, dynamic>> pages, this.nextOffset)
      : pages = List.unmodifiable(pages.map(Map<String, dynamic>.unmodifiable));

  final List<Map<String, dynamic>> pages;
  final int? nextOffset;
}

class WikiPageDetail {
  WikiPageDetail({
    required Map<String, dynamic> page,
    List<Map<String, dynamic>> children = const <Map<String, dynamic>>[],
    List<Map<String, dynamic>> tableRows = const <Map<String, dynamic>>[],
    this.childrenHasMore = false,
    this.tableRowsHasMore = false,
  })  : page = Map<String, dynamic>.unmodifiable(page),
        children = List<Map<String, dynamic>>.unmodifiable(
          children.map(Map<String, dynamic>.unmodifiable),
        ),
        tableRows = List<Map<String, dynamic>>.unmodifiable(
          tableRows.map(Map<String, dynamic>.unmodifiable),
        );

  final Map<String, dynamic> page;
  final List<Map<String, dynamic>> children;
  final List<Map<String, dynamic>> tableRows;
  final bool childrenHasMore;
  final bool tableRowsHasMore;
}

/// Owner identity is supplied by the authenticated hub, never by this client.
class WikiRepository {
  WikiRepository(this._invoke);

  final WikiInvoke _invoke;

  Map<String, dynamic> _response(Object? value) {
    if (value is! Map<String, dynamic> || value['success'] != true) {
      throw const FormatException('Invalid Wiki response');
    }
    return value;
  }

  Map<String, dynamic> _page(Object? row) {
    if (row is! Map<String, dynamic>) {
      throw const FormatException('Invalid Wiki page');
    }
    final page = normalizeWikiPageResponse(row);
    if (page['id'] is! String || (page['id'] as String).isEmpty) {
      throw const FormatException('Missing Wiki page ID');
    }
    return page;
  }

  Map<String, dynamic> _tableRow(Object? row) {
    if (row is! Map<String, dynamic>) {
      throw const FormatException('Invalid Wiki table row');
    }
    return normalizeWikiTableRowResponse(row);
  }

  List<Map<String, dynamic>> _normalizeRows(
    Object? value,
    Map<String, dynamic> Function(Object?) mapper,
  ) {
    if (value == null) return const <Map<String, dynamic>>[];
    if (value is! List) {
      throw const FormatException('Invalid Wiki detail list');
    }
    return value.map(mapper).toList();
  }

  bool _optionalFlag(Object? value) {
    if (value == null) return false;
    if (value is! bool) {
      throw const FormatException('Invalid Wiki boolean flag');
    }
    return value;
  }

  Future<WikiPageBatch> list({int offset = 0, int limit = 50}) async {
    if (offset < 0 || offset > 1000000 || limit < 1 || limit > 100) {
      throw ArgumentError('Invalid Wiki pagination');
    }
    final data = _response(
      await _invoke({
        'action': 'wiki.list',
        'offset': offset,
        'limit': limit,
      }),
    );
    final rows = data['pages'];
    final next = data['next_offset'];
    if (rows is! List ||
        rows.length > limit ||
        !data.containsKey('next_offset') ||
        (next != null &&
            (next is! int || next != offset + limit || rows.length != limit))) {
      throw const FormatException('Invalid Wiki pagination response');
    }
    return WikiPageBatch(rows.map(_page).toList(), next as int?);
  }

  Future<WikiPageDetail> getDetail(String id) async {
    final trimmed = id.trim();
    if (trimmed.isEmpty) throw ArgumentError('Wiki page ID is required');
    final data = _response(
      await _invoke({'action': 'wiki.get', 'id': trimmed}),
    );
    final page = _page(data['page']);
    if (page['id'] != trimmed) {
      throw const FormatException('Unexpected Wiki page ID');
    }
    final children = _normalizeRows(data['children'], _page);
    final tableRows = _normalizeRows(data['table_rows'], _tableRow);
    final childrenHasMore = _optionalFlag(data['children_has_more']);
    final tableRowsHasMore = _optionalFlag(data['table_rows_has_more']);
    return WikiPageDetail(
      page: page,
      children: children,
      tableRows: tableRows,
      childrenHasMore: childrenHasMore,
      tableRowsHasMore: tableRowsHasMore,
    );
  }

  Future<Map<String, dynamic>> get(String id) async {
    return (await getDetail(id)).page;
  }

  Future<Map<String, dynamic>> createPage({
    required String title,
    required String content,
    String? parentId,
  }) async {
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) {
      throw ArgumentError('Wiki page title is required');
    }
    final trimmedParent = parentId?.trim();
    if (parentId != null &&
        (trimmedParent == null || trimmedParent.isEmpty)) {
      throw ArgumentError('Invalid Wiki parent ID');
    }
    final data = _response(
      await _invoke({
        'action': 'wiki.create',
        'title': trimmedTitle,
        'content': content.trim(),
        if (trimmedParent != null) 'parent_id': trimmedParent,
      }),
    );
    final Object? rawPage = data['page'];
    if (rawPage == null) return const <String, dynamic>{};
    return Map<String, dynamic>.unmodifiable(_page(rawPage));
  }

  Future<Map<String, dynamic>> addTableRow({
    required String pageId,
    required String content,
  }) async {
    final trimmedPageId = pageId.trim();
    if (trimmedPageId.isEmpty) {
      throw ArgumentError('Wiki page ID is required');
    }
    final data = _response(
      await _invoke({
        'action': 'sheet.add_row',
        'sheet_id': trimmedPageId,
        'data': <String, dynamic>{'content': content.trim()},
      }),
    );
    final Object? rawRow = data['row'];
    if (rawRow == null) return const <String, dynamic>{};
    return Map<String, dynamic>.unmodifiable(_tableRow(rawRow));
  }
}
