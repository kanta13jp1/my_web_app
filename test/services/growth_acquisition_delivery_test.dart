import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_web_app/services/growth_acquisition_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  for (final failure in ['offline', 'server', 'rejected', 'duplicate']) {
    test('acquisition delivery: $failure then a new successful action',
        () async {
      final requests = <Map<String, dynamic>>[];
      var accepted = 0;
      final transport = MockClient((request) async {
        expect(request.url.path, '/functions/v1/growth-hub');
        requests.add(jsonDecode(request.body) as Map<String, dynamic>);
        if (requests.length == 1) {
          if (failure == 'offline') {
            throw http.ClientException('controlled offline failure');
          }
          if (failure == 'server') {
            return http.Response('{"error":"controlled failure"}', 503);
          }
          return http.Response(
            jsonEncode({
              'success': failure == 'duplicate',
              'recorded': false,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        accepted++;
        return http.Response(
          '{"success":true,"recorded":true}',
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final client = SupabaseClient(
        'https://example.invalid',
        'test-anon-key',
        httpClient: transport,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      addTearDown(client.dispose);
      final service = GrowthAcquisitionService(clientOverride: client);

      // Exercise the actual production service, with only transport replaced.
      // Its void result does not expose rejection, duplication or offline loss.
      await expectLater(
        service.recordTouchpointForPagePath(
          '/landing',
          currentUri: Uri.parse('https://example.invalid/landing'),
        ),
        completes,
      );
      expect(requests, hasLength(1));
      expect(accepted, 0);

      await service.recordTouchpointForPagePath(
        '/landing',
        currentUri: Uri.parse('https://example.invalid/landing'),
      );
      // A new successful call sends itself; the failed call is not replayed.
      expect(requests, hasLength(2));
      expect(accepted, 1);
      expect(requests.every((r) => r['signalKey'] == 'touch_landing'), isTrue);
      expect(
        requests.every((r) => r['action'] == 'acquisition.signal'),
        isTrue,
      );
    });
  }
}
