import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_web_app/pages/diet_debates_page.dart';
import 'package:my_web_app/services/diet_debate_search.dart';
import 'package:my_web_app/services/diet_reader_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  WidgetsBinding.instance.ensureSemantics();
  var clock = DateTime.utc(2026, 11, 9);
  final search = DietDebateSearch(
    now: () {
      clock = clock.add(const Duration(seconds: 6));
      return clock;
    },
    createClient: () => MockClient((request) async {
      final query = request.url.queryParameters;
      final start = int.tryParse(query['startRecord'] ?? '');
      if (request.url.host != 'kokkai.ndl.go.jp' ||
          query['any'] != '子育て' ||
          query['maximumRecords'] != '10' ||
          (start != 1 && start != 11)) {
        throw StateError('Unexpected synthetic query');
      }
      const issue = '000000000X00020000101';
      final first = start!;
      final rows = [
        for (var n = first; n < first + 10; n++)
          {
            'issueID': issue,
            'speechOrder': n,
            'speechID': '${issue}_${n.toString().padLeft(3, '0')}',
            'speechURL': 'https://kokkai.ndl.go.jp/txt/$issue/$n',
            'speaker': '試験発言者$n',
            'date': '2000-01-01',
            'nameOfHouse': '試験議院',
            'nameOfMeeting': '画面検証用の架空の会議',
            'speech': '子育て',
          },
      ];
      return http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'numberOfRecords': 20,
            if (first == 1) 'nextRecordPosition': 11,
            'speechRecord': rows,
          }),
        ),
        200,
      );
    }),
  );
  runApp(
    MaterialApp(
      theme: ThemeData(fontFamily: 'NotoSansJP'),
      home: DietDebatesPage(
        account: ValueNotifier<String?>('browser-fixture-owner'),
        preferences: DietReaderPreferences(),
        searchService: search,
      ),
    ),
  );
}
