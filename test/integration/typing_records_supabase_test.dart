import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/typing_game.dart';
import 'package:my_web_app/services/typing_score_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Run only in the disposable cloud stack, with real GoTrue + PostgREST + RLS.
/// Never accepts a remote host or a production credential.
void main() {
  test(
    'real local auth isolates history and mediates publication and expiry',
    () async {
      final url = Platform.environment['TYPING_TEST_URL']!;
      final key = Platform.environment['TYPING_TEST_ANON_KEY']!;
      final database = Platform.environment['TYPING_TEST_DB_URL']!;
      expect(Uri.parse(url).host, '127.0.0.1');
      expect(Uri.parse(database).host, '127.0.0.1');
      final clients = <SupabaseClient>[];
      SupabaseClient client() {
        final value = SupabaseClient(
          url,
          key,
          authOptions: const AuthClientOptions(
          autoRefreshToken: false,
          authFlowType: AuthFlowType.implicit,
        ),
        );
        clients.add(value);
        return value;
      }

      addTearDown(() async {
        for (final value in clients) {
          await value.dispose();
        }
      });
      final a = client();
      final b = client();
      const password = 'Disposable-typing-test-847!';
      await a.auth.signUp(email: 'typing-a@example.test', password: password);
      await b.auth.signUp(email: 'typing-b@example.test', password: password);
      expect(a.auth.currentSession, isNotNull);
      expect(b.auth.currentSession, isNotNull);
      final storeA = SupabaseTypingScoreStore(a);
      final storeB = SupabaseTypingScoreStore(b);
      final game = TypingGame()..start();
      game.type(game.guide[0]);
      game.updateElapsed(TypingGame.duration);
      final report = TypingRunReport.fromGame(game);
      await storeA.save(report);
      await storeA.save(report);
      expect((await storeA.mine()).single['score'], 10);
      expect(await storeB.mine(), isEmpty);
      expect(await storeB.ranking(), isEmpty);
      final restored = client();
      await restored.auth.signInWithPassword(
        email: 'typing-a@example.test',
        password: password,
      );
      expect(
        (await SupabaseTypingScoreStore(restored).mine()).single['id'],
        report.id,
      );
      await expectLater(
        a.rpc(
          'typing_game_records',
          params: {
            'p_action': 'save',
            'p_data': {...report.toJson(), 'correct': report.correct + 1},
          },
        ),
        throwsA(
          isA<PostgrestException>().having((e) => e.code, 'code', '22023'),
        ),
      );
      for (final action in ['delete', 'withdraw', 'publish']) {
        await expectLater(
          b.rpc(
            'typing_game_records',
            params: {
              'p_action': action,
              'p_data': {
                'id': report.id,
                if (action == 'publish') 'alias': 'NotMine',
              },
            },
          ),
          throwsA(
            isA<PostgrestException>().having((e) => e.code, 'code', '42501'),
          ),
        );
      }
      await storeA.publish(report.id, 'TypingFan');
      final entry = (await storeB.ranking()).single;
      expect(entry['alias'], 'TypingFan');
      expect(
        entry.keys,
        unorderedEquals(['alias', 'score', 'accuracy', 'words']),
      );
      await storeA.withdraw(report.id);
      expect(await storeB.ranking(), isEmpty);
      expect(await storeA.mine(), hasLength(1));
      final ownB = TypingRunReport.fromGame(game);
      await storeB.save(ownB);
      await storeB.publish(ownB.id, 'OtherPlayer');
      await storeB.delete(ownB.id);
      expect(await storeB.mine(), isEmpty);
      expect(await storeB.ranking(), isEmpty);
      await storeA.publish(report.id, 'TypingFan');

      final owner = a.auth.currentUser!.id;
      final uuid = RegExp(r'^[0-9a-f-]{36}$');
      expect(uuid.hasMatch(owner) && uuid.hasMatch(report.id), isTrue);
      Future<String> sql(String statement) async {
        final result = await Process.run('psql', [
          database,
          '-X',
          '-At',
          '-v',
          'ON_ERROR_STOP=1',
          '-c',
          statement,
        ]);
        expect(result.exitCode, 0, reason: 'Disposable fixture SQL failed');
        return (result.stdout as String).trim();
      }

      final where = "owner_id='$owner'::uuid and id='${report.id}'::uuid";
      await sql(
        "update typing_private.runs set created_at=now()-interval '91 days' where $where",
      );
      expect(await storeB.ranking(), isEmpty);
      expect(
        await sql('select count(*) from typing_private.runs where $where'),
        '1',
      );
      expect(
        await sql('select count(*) from typing_private.entries where $where'),
        '1',
      );
      await sql('select typing_private.purge_expired_publications()');
      expect(
        await sql('select count(*) from typing_private.entries where $where'),
        '0',
      );
      expect(
        await sql('select count(*) from typing_private.runs where $where'),
        '1',
      );
      expect(await storeA.mine(), hasLength(1));
      await a.auth.signOut();
      await expectLater(storeA.mine(), throwsStateError);
    },
    timeout: const Timeout(Duration(minutes: 3)),
    skip: Platform.environment['TYPING_TEST_URL'] == null,
  );
}
