import 'package:my_web_app/utils/wiki_page_response.dart';

typedef WikiInvoke = Future<dynamic> Function(Map<String, dynamic> body);

class WikiPageBatch {
  WikiPageBatch(List<Map<String, dynamic>> pages, this.nextOffset)
      : pages = List.unmodifiable(pages.map(Map<String, dynamic>.unmodifiable));

  final List<Map<String, dynamic>> pages;
  final int? nextOffset;
}

/// Owner identity is supplied by the authenticated hub, never by this client.
class WikiRepository {
  WikiRepository(this._invoke);

  final WikiInvoke _invoke;

  Map<String, dynamic> _response(dynamic value) {
    if (value is! Map<String, dynamic> || value['success'] != true) {
      throw const FormatException('Invalid Wiki response');
    }
    return value;
  }

  Map<String, dynamic> _page(dynamic row) {
    if (row is! Map<String, dynamic>) {
      throw const FormatException('Invalid Wiki page');
    }
    final page = normalizeWikiPageResponse(row);
    if (page['id'] is! String || (page['id'] as String).isEmpty) {
      throw const FormatException('Missing Wiki page ID');
    }
    return page;
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

  Future<Map<String, dynamic>> get(String id) async {
    if (id.trim().isEmpty) throw ArgumentError('Wiki page ID is required');
    final data = _response(await _invoke({'action': 'wiki.get', 'id': id}));
    final page = _page(data['page']);
    if (page['id'] != id) {
      throw const FormatException('Unexpected Wiki page ID');
    }
    return Map.unmodifiable(page);
  }
}
