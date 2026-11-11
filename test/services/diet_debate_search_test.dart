import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_web_app/data/diet_debate_notes.dart';
import 'package:my_web_app/services/diet_debate_search.dart';

void main() {
  const issue = '121115104X01220230516';
  Map<String, dynamic> row(int order, String suffix) => {
        'issueID': issue,
        'speechID': '${issue}_$suffix',
        'speechOrder': order,
        'speechURL': 'https://kokkai.ndl.go.jp/txt/$issue/$order',
        'speaker': order == 0 ? '会議録情報' : '発言者',
        'date': '2023-05-16',
        'nameOfHouse': '参議院',
        'nameOfMeeting': '文教科学委員会',
      };

  test('NDLのID表記、会議情報、確認済み要約との対応', () {
    expect(DietSpeech.fromJson(row(0, '000')).isMeetingInformation, isTrue);
    for (final pair in [(10, '010'), (11, '011'), (139, '139'), (140, '140')]) {
      final speech = DietSpeech.fromJson(row(pair.$1, pair.$2));
      expect(speech.isMeetingInformation, isFalse);
      expect(DietDebateNote.forSpeech(speech.id), isNotNull);
    }
    expect(DietSpeech.fromJson(row(1000, '1000')).id, '${issue}_1000');
    expect(DietDebateNote.forSpeech('${issue}_999'), isNull);
  });

  test('検索条件・ページ位置を送り、本文を表示せず不正な出典だけを省略する', () async {
    final search = DietDebateSearch(
      createClient: () => MockClient((request) async {
        expect(request.url.host, 'kokkai.ndl.go.jp');
        expect(request.url.path, '/api/speech');
        expect(request.url.queryParameters, {
          'any': '教育',
          'speaker': '発言者',
          'speakerGroup': '会派',
          'from': '2023-05-16',
          'until': '2023-05-16',
          'maximumRecords': '10',
          'startRecord': '11',
          'recordPacking': 'json',
        });
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'numberOfRecords': 23,
              'nextRecordPosition': 21,
              'speechRecord': [
                {
                  ...row(139, '139'),
                  'speakerGroup': '会派',
                  'speech': '育児の負担と物価の関係',
                },
                {
                  ...row(140, '140'),
                  'speechURL': 'https://example.org/invalid',
                },
              ],
            }),
          ),
          200,
        );
      }),
    );
    final result = await search.search(
      term: ' 教育 ',
      speaker: '発言者',
      group: '会派',
      date: '2023-05-16',
      start: 11,
    );
    expect(result.items.single.id, '${issue}_139');
    expect(result.items.single.group, '会派');
    expect(result.items.single.topics, ['子育て', '物価']);
    expect(result.skipped, 1);
    expect(result.next, 21);
    expect(result.total, 23);
  });

  test('検索欄と同じ書記素数で各条件の100文字までを受け付ける', () async {
    var now = DateTime.utc(2026, 1, 1);
    final requests = <Uri>[];
    final search = DietDebateSearch(
      now: () => now,
      createClient: () => MockClient((request) async {
        requests.add(request.url);
        return http.Response('{"numberOfRecords":0}', 200);
      }),
    );
    final prefix = List.filled(99, 'あ').join();
    final term = '$prefix𠮷';
    final speaker = '$prefixは\u3099';
    final group = '$prefix会';
    final invalidLength = throwsA(
      isA<DietSearchError>().having(
        (error) => error.message,
        'message',
        '検索条件を確認してください。',
      ),
    );
    await expectLater(search.search(term: '${term}A'), invalidLength);
    await expectLater(search.search(speaker: '${speaker}A'), invalidLength);
    await expectLater(search.search(group: '${group}A'), invalidLength);
    expect(requests, isEmpty);

    await search.search(term: term);
    now = now.add(const Duration(seconds: 5));
    await search.search(speaker: speaker);
    now = now.add(const Duration(seconds: 5));
    await search.search(group: group);
    expect(requests, hasLength(3));
    expect(requests[0].queryParameters['any'], term);
    expect(requests[1].queryParameters['speaker'], speaker);
    expect(requests[2].queryParameters['speakerGroup'], group);
  });

  test('総バイト超過はクライアントと検索状態を開始せず、次の通常検索を許可する', () async {
    var factories = 0;
    var httpCalls = 0;
    var nowCalls = 0;
    Uri? accepted;
    final search = DietDebateSearch(
      now: () {
        nowCalls++;
        return DateTime.utc(2026, 1, 1);
      },
      createClient: () {
        factories++;
        return MockClient((request) async {
          httpCalls++;
          accepted = request.url;
          return http.Response('{"numberOfRecords":0}', 200);
        });
      },
    );
    final familyTerm = List.filled(100, '👨‍👩‍👧‍👦').join();
    final japanese = List.filled(100, 'あ').join();
    expect(familyTerm.characters.length, 100);
    expect(japanese.characters.length, 100);
    final tooLong = throwsA(
      isA<DietSearchError>().having(
        (error) => error.message,
        'message',
        '検索条件が長すぎます。検索語・発言者・会派を短くしてください。',
      ),
    );
    await expectLater(search.search(term: familyTerm), tooLong);
    await expectLater(
      search.search(term: japanese, speaker: japanese, group: japanese),
      tooLong,
    );
    expect(factories, 0);
    expect(httpCalls, 0);
    expect(nowCalls, 0);

    final result = await search.search(
      term: '子育て',
      speaker: '田中',
      group: '国民民主党',
    );
    expect(result.total, 0);
    expect(factories, 1);
    expect(httpCalls, 1);
    expect(accepted!.queryParameters['any'], '子育て');
    expect(accepted!.queryParameters['speaker'], '田中');
    expect(accepted!.queryParameters['speakerGroup'], '国民民主党');
  });

  test('実入力のquery2000バイトは送信し2001バイトは状態更新前に拒否する', () async {
    var factories = 0;
    var nowCalls = 0;
    final requests = <Uri>[];
    final term = List.filled(100, 'あ').join();
    final speaker = List.filled(100, 'い').join();
    final group = '${List.filled(13, 'う').join()}aaaaa';
    Uri query(String value) => Uri.https('kokkai.ndl.go.jp', '/api/speech', {
          'any': term,
          'speaker': speaker,
          'speakerGroup': value,
          'maximumRecords': '10',
          'startRecord': '1',
          'recordPacking': 'json',
        });
    expect(term.characters.length, 100);
    expect(speaker.characters.length, 100);
    expect(group.characters.length, 18);
    expect(utf8.encode(query(group).query).length, 2000);
    expect(utf8.encode(query('${group}b').query).length, 2001);
    final search = DietDebateSearch(
      now: () {
        nowCalls++;
        return DateTime.utc(2026, 1, 1);
      },
      createClient: () {
        factories++;
        return MockClient((request) async {
          requests.add(request.url);
          return http.Response('{"numberOfRecords":0}', 200);
        });
      },
    );
    await search.search(term: term, speaker: speaker, group: group);
    expect(factories, 1);
    expect(requests, hasLength(1));
    expect(requests.single, query(group));
    final clockCallsAfterAccepted = nowCalls;
    await expectLater(
      search.search(term: term, speaker: speaker, group: '${group}b'),
      throwsA(
        isA<DietSearchError>().having(
          (error) => error.message,
          'message',
          '検索条件が長すぎます。検索語・発言者・会派を短くしてください。',
        ),
      ),
    );
    expect(factories, 1);
    expect(requests, hasLength(1));
    expect(nowCalls, clockCallsAfterAccepted);
  });

  test('並行リクエスト・終了後5秒以内の新規検索を抑え、同一条件をキャッシュ', () async {
    var now = DateTime.utc(2026, 1, 1);
    var count = 0;
    final first = Completer<http.Response>();
    final search = DietDebateSearch(
      now: () => now,
      createClient: () => MockClient((request) async {
        count++;
        if (count == 1) return first.future;
        return http.Response('{"numberOfRecords":0}', 200);
      }),
    );
    final pending = search.search(term: '教育');
    await expectLater(
      search.search(term: '物価'),
      throwsA(isA<DietSearchError>()),
    );
    first.complete(http.Response('{"numberOfRecords":0}', 200));
    final firstPage = await pending;
    expect(firstPage.items, isEmpty);
    expect(firstPage.fetchedAt, now);
    now = now.add(const Duration(seconds: 1));
    expect((await search.search(term: '教育')).fetchedAt, firstPage.fetchedAt);
    expect((await search.search(term: '教育')).total, 0);
    await expectLater(
      search.search(term: '物価'),
      throwsA(isA<DietSearchError>()),
    );
    now = now.add(const Duration(seconds: 5));
    expect((await search.search(term: '物価')).total, 0);
    expect(count, 2);
  });

  test('条件なしとAPIのエラー応答を0件と混同しない', () async {
    var count = 0;
    final search = DietDebateSearch(
      createClient: () => MockClient((_) async {
        count++;
        return http.Response('{"message":[{"error":"19007"}]}', 200);
      }),
    );
    await expectLater(search.search(), throwsA(isA<DietSearchError>()));
    await expectLater(
      search.search(term: ' ', speaker: '\t', group: '　'),
      throwsA(isA<DietSearchError>()),
    );
    expect(count, 0);
    await expectLater(
      search.search(speaker: '発言者'),
      throwsA(isA<DietSearchError>()),
    );
    expect(count, 1);
  });
}
