import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:my_web_app/preview/pr5125_store.dart';

void main() {
  test('reads only synthetic rows from the in-memory adapter', () async {
    final store = Preview5125Store();
    final response = await store.client.get(Uri.parse('https://pr5125.invalid/rest/v1/notes?id=eq.1'));
    final rows = jsonDecode(response.body) as List;
    expect(rows.length, 1);
    expect((rows.first as Map<String, dynamic>)['title'], contains('架空データ'));
    store.client.close();
  });
  test('all mutations and external destinations fail closed', () async {
    final store = Preview5125Store();
    for (final method in ['POST', 'PATCH', 'DELETE', 'PUT']) {
      final response = await store.client.send(http.Request(method, Uri.parse('https://pr5125.invalid/rest/v1/notes')));
      expect(response.statusCode, 403);
    }
    final external = await store.client.get(Uri.parse('https://example.com/rest/v1/notes'));
    expect(external.statusCode, 403);
    expect(store.tables['notes']!.length, 2);
    store.client.close();
  });
}
