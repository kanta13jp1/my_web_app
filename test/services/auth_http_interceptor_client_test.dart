import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_web_app/services/auth_http_interceptor_client.dart';
import 'package:my_web_app/services/authenticated_api_client.dart';

class _FakeAuthSessionGateway implements AuthSessionGateway {
  _FakeAuthSessionGateway({
    AuthSessionSnapshot? initialSession,
    this.nextRefreshedSession,
    this.failRefresh = false,
    this.refreshDelay = Duration.zero,
  }) : session = initialSession;

  AuthSessionSnapshot? session;
  AuthSessionSnapshot? nextRefreshedSession;
  bool failRefresh;
  Duration refreshDelay;

  int refreshCallCount = 0;
  int clearCallCount = 0;

  @override
  AuthSessionSnapshot? currentSession() => session;

  @override
  Future<AuthSessionSnapshot?> refreshSession() async {
    refreshCallCount += 1;
    if (refreshDelay > Duration.zero) {
      await Future<void>.delayed(refreshDelay);
    }
    if (failRefresh) {
      return null;
    }
    session = nextRefreshedSession;
    return session;
  }

  @override
  Future<void> clearSession() async {
    clearCallCount += 1;
    session = null;
  }
}

void main() {
  group('AuthHttpInterceptorClient & AuthenticatedApiClient (#2604)', () {
    test(
      'dynamically attaches latest rotated token without stale closure capture',
      () async {
        final seenHeaders = <String?>[];
        final gateway = _FakeAuthSessionGateway(
          initialSession: AuthSessionSnapshot(
            accessToken: 'tok-1',
            expiresAt: DateTime.utc(2026, 11, 24, 12),
          ),
        );
        final client = AuthHttpInterceptorClient(
          sessionGateway: gateway,
          clock: () => DateTime.utc(2026, 11, 24, 10),
          config: const AuthHttpInterceptorConfig(
            allowedAuthOrigins: <String>{'https://api.example.com'},
          ),
          innerClient: MockClient((http.Request req) async {
            seenHeaders.add(req.headers['Authorization']);
            return http.Response('{"ok":true}', 200);
          }),
        );

        await client.get(Uri.parse('https://api.example.com/v1/profile'));
        gateway.session = AuthSessionSnapshot(
          accessToken: 'tok-2',
          expiresAt: DateTime.utc(2026, 11, 24, 13),
        );
        await client.get(Uri.parse('https://api.example.com/v1/profile'));

        expect(seenHeaders, <String?>['Bearer tok-1', 'Bearer tok-2']);
        expect(gateway.refreshCallCount, 0);
        client.close();
      },
    );

    test(
      'coalesces proactive refresh when token expires within refreshLeadTime',
      () async {
        final seenHeaders = <String?>[];
        final gateway = _FakeAuthSessionGateway(
          initialSession: AuthSessionSnapshot(
            accessToken: 'exp-1',
            expiresAt: DateTime.utc(2026, 11, 24, 10, 0, 20),
          ),
          nextRefreshedSession: AuthSessionSnapshot(
            accessToken: 'new-1',
            expiresAt: DateTime.utc(2026, 11, 24, 11),
          ),
          refreshDelay: const Duration(milliseconds: 20),
        );
        final client = AuthHttpInterceptorClient(
          sessionGateway: gateway,
          clock: () => DateTime.utc(2026, 11, 24, 10, 0, 0),
          config: const AuthHttpInterceptorConfig(
            allowedAuthOrigins: <String>{'https://api.example.com'},
            refreshLeadTime: Duration(seconds: 60),
          ),
          innerClient: MockClient((http.Request req) async {
            seenHeaders.add(req.headers['Authorization']);
            return http.Response('{"ok":true}', 200);
          }),
        );

        await Future.wait<http.Response>(<Future<http.Response>>[
          client.get(Uri.parse('https://api.example.com/v1/a')),
          client.get(Uri.parse('https://api.example.com/v1/b')),
          client.get(Uri.parse('https://api.example.com/v1/c')),
        ]);

        expect(gateway.refreshCallCount, 1);
        expect(
          seenHeaders,
          <String?>['Bearer new-1', 'Bearer new-1', 'Bearer new-1'],
        );
        client.close();
      },
    );

    test(
      'refreshes once and replays POST payload when server responds 401',
      () async {
        final seenAuthHeaders = <String?>[];
        final seenBodies = <String>[];
        final gateway = _FakeAuthSessionGateway(
          initialSession: AuthSessionSnapshot(
            accessToken: 'old-1',
            expiresAt: DateTime.utc(2026, 11, 24, 12),
          ),
          nextRefreshedSession: AuthSessionSnapshot(
            accessToken: 'rec-1',
            expiresAt: DateTime.utc(2026, 11, 24, 13),
          ),
        );
        final client = AuthHttpInterceptorClient(
          sessionGateway: gateway,
          clock: () => DateTime.utc(2026, 11, 24, 10),
          config: const AuthHttpInterceptorConfig(
            allowedAuthOrigins: <String>{'https://api.example.com'},
          ),
          innerClient: MockClient((http.Request req) async {
            seenAuthHeaders.add(req.headers['Authorization']);
            seenBodies.add(req.body);
            if (req.headers['Authorization'] == 'Bearer old-1') {
              return http.Response('{"error":"expired"}', 401);
            }
            return http.Response('{"saved":true,"id":"item-1"}', 200);
          }),
        );

        final api = AuthenticatedApiClient(
          httpClient: client,
          baseUri: Uri.parse('https://api.example.com'),
        );
        final payload = await api.postJson(
          '/v1/items',
          body: const <String, dynamic>{'name': 'alpha'},
        );

        expect(payload, <String, dynamic>{'saved': true, 'id': 'item-1'});
        expect(gateway.refreshCallCount, 1);
        expect(gateway.clearCallCount, 0);
        expect(
          seenAuthHeaders,
          <String?>['Bearer old-1', 'Bearer rec-1'],
        );
        expect(seenBodies, <String>[
          jsonEncode(const <String, dynamic>{'name': 'alpha'}),
          jsonEncode(const <String, dynamic>{'name': 'alpha'}),
        ]);
        api.close();
      },
    );

    testWidgets(
      'clears local auth state and navigates to /login on unrecoverable 401',
      (WidgetTester tester) async {
        final navigatorKey = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: navigatorKey,
            initialRoute: '/home',
            routes: <String, WidgetBuilder>{
              '/home': (BuildContext _) => const Scaffold(
                    body: Text('Authenticated Home'),
                  ),
              '/login': (BuildContext _) => const Scaffold(
                    body: Text('Login Screen'),
                  ),
            },
          ),
        );
        expect(find.text('Authenticated Home'), findsOneWidget);

        final gateway = _FakeAuthSessionGateway(
          initialSession: AuthSessionSnapshot(
            accessToken: 'rev-1',
            expiresAt: DateTime.utc(2026, 11, 24, 12),
          ),
          failRefresh: true,
        );
        final api = AuthenticatedApiClient(
          baseUri: Uri.parse('https://api.example.com'),
          httpClient: AuthHttpInterceptorClient(
            sessionGateway: gateway,
            navigatorKey: navigatorKey,
            clock: () => DateTime.utc(2026, 11, 24, 10),
            config: const AuthHttpInterceptorConfig(
              allowedAuthOrigins: <String>{'https://api.example.com'},
            ),
            innerClient: MockClient(
              (http.Request _) async => http.Response('unauthorized', 401),
            ),
          ),
        );

        await expectLater(
          api.getJson('/v1/protected'),
          throwsA(isA<AuthHttpUnauthorizedException>()),
        );
        await tester.pumpAndSettle();

        expect(gateway.refreshCallCount, 1);
        expect(gateway.clearCallCount, 1);
        expect(gateway.currentSession(), isNull);
        expect(find.text('Login Screen'), findsOneWidget);
        expect(find.text('Authenticated Home'), findsNothing);
        api.close();
      },
    );

    test(
      'never leaks Authorization headers to untrusted or unallowed origins',
      () async {
        final capturedHeaders = <String, String?>{};
        final gateway = _FakeAuthSessionGateway(
          initialSession: AuthSessionSnapshot(
            accessToken: 'sec-1',
            expiresAt: DateTime.utc(2026, 11, 24, 12),
          ),
        );
        final client = AuthHttpInterceptorClient(
          sessionGateway: gateway,
          clock: () => DateTime.utc(2026, 11, 24, 10),
          config: const AuthHttpInterceptorConfig(
            allowedAuthOrigins: <String>{'https://api.example.com'},
          ),
          innerClient: MockClient((http.Request req) async {
            capturedHeaders[req.url.toString()] = req.headers['Authorization'];
            return http.Response('ok', 200);
          }),
        );

        await client.get(Uri.parse('https://api.example.com/v1/ok'));
        await client.get(Uri.parse('https://api.example.com.evil.com/leak'));
        await client.get(Uri.parse('http://api.example.com/downgrade'));
        await client.get(
          Uri.parse('https://api.example.com/public'),
          headers: const <String, String>{
            AuthHttpInterceptorClient.skipAuthHeader: 'true',
          },
        );

        expect(
          capturedHeaders['https://api.example.com/v1/ok'],
          'Bearer sec-1',
        );
        expect(
          capturedHeaders['https://api.example.com.evil.com/leak'],
          isNull,
        );
        expect(
          capturedHeaders['http://api.example.com/downgrade'],
          isNull,
        );
        expect(
          capturedHeaders['https://api.example.com/public'],
          isNull,
        );
        client.close();
      },
    );
  });
}
