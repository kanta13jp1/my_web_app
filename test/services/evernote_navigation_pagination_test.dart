import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_web_app/services/note_navigation_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('navigation continues past short server-capped pages', () async {
    final offsets = <String, List<int>>{};
    final client = SupabaseClient(
      'https://navigation-fixture.invalid',
      'fixture-key',
      httpClient: MockClient((request) async {
        final table = request.url.pathSegments.last;
        Object response = <Object>[];
        if (table != 'evernote_navigation_migrations') {
          expect(
            <String>['note_saved_searches', 'note_shortcuts'],
            contains(table),
          );
          final offset = int.parse(request.url.queryParameters['offset']!);
          expect(request.url.queryParameters['limit'], '500');
          offsets.putIfAbsent(table, () => <int>[]).add(offset);
          final remaining = 120 - offset;
          final count = remaining > 50 ? 50 : remaining;
          response = List<Map<String, dynamic>>.generate(
            count,
            (index) => <String, dynamic>{
              'id': 'row-${offset + index}',
              'name': 'search',
              'query': 'tag:work',
              'position': offset + index,
              'target_type': 'tag',
              'target_tag': 'work',
              'target_label': 'work',
            },
          );
        }
        return http.Response(
          jsonEncode(response),
          200,
          request: request,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(client.dispose);

    final result = await SupabaseNoteNavigationRepository(client).load();

    expect(result.savedSearches, hasLength(120));
    expect(result.shortcuts, hasLength(120));
    expect(result.savedSearches.last.id, 'row-119');
    expect(result.shortcuts.last.id, 'row-119');
    for (final pages in offsets.values) {
      expect(pages, <int>[0, 50, 100, 120]);
    }
    expect(offsets, hasLength(2));
    expect(result.migrationState, isNull);
  });
}
