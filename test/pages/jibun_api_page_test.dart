import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/jibun_api_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeUser extends Fake implements User {
  @override
  String get id => 'test-user-id';
}

class _FakeGoTrueClient extends Fake implements GoTrueClient {
  _FakeGoTrueClient(this._user);

  final User? _user;

  @override
  User? get currentUser => _user;
}

class _FakeFunctionResponse extends Fake implements FunctionResponse {
  _FakeFunctionResponse(this._data);

  final Object? _data;

  @override
  Object? get data => _data;

  @override
  int get status => 200;
}

class _FakeFunctionsClient extends Fake implements FunctionsClient {
  final List<String> invokedActions = <String>[];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #invoke) {
      final Object? fnArg = invocation.positionalArguments.isNotEmpty
          ? invocation.positionalArguments.first
          : '';
      final String functionName = '$fnArg';
      final Object? body = invocation.namedArguments[#body];
      final String action = body is Map ? '${body['action'] ?? ''}' : '';
      invokedActions.add('$functionName:$action');
      if (action == 'jibunapi.key.list') {
        return Future<FunctionResponse>.value(
          _FakeFunctionResponse(<String, Object>{
            'keys': <Map<String, Object>>[
              <String, Object>{
                'id': 'key-1',
                'name': 'Antigravity MCP',
                'key_prefix': 'jibun_sk_test',
                'scopes': <String>['notes.read', 'tasks.read'],
                'revoked': false,
              },
            ],
          }),
        );
      }
      if (action == 'jibunapi.worker.list') {
        return Future<FunctionResponse>.value(
          _FakeFunctionResponse(<String, Object>{
            'workers': <Map<String, Object>>[],
          }),
        );
      }
      return Future<FunctionResponse>.value(
        _FakeFunctionResponse(<String, Object>{'success': true}),
      );
    }
    return super.noSuchMethod(invocation);
  }
}

class _FakeSupabaseClient extends Fake implements SupabaseClient {
  _FakeSupabaseClient({
    required User? user,
    required FunctionsClient functions,
  })  : _auth = _FakeGoTrueClient(user),
        _functions = functions;

  final GoTrueClient _auth;
  final FunctionsClient _functions;

  @override
  GoTrueClient get auth => _auth;

  @override
  FunctionsClient get functions => _functions;
}

Future<void> _scrollToAndPump(
  WidgetTester tester,
  Finder finder,
) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('logged-out user sees login prompt without calling tools-hub', (
    WidgetTester tester,
  ) async {
    final functions = _FakeFunctionsClient();
    final client = _FakeSupabaseClient(user: null, functions: functions);

    await tester.pumpWidget(
      MaterialApp(
        home: JibunApiPage(supabaseClient: client),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('自分APIを利用するにはログインが必要です。'), findsOneWidget);
    expect(functions.invokedActions, isEmpty);
  });

  testWidgets('renders Antigravity MCP card and existing API key', (
    WidgetTester tester,
  ) async {
    const endpoint = 'https://example.supabase.co/functions/v1/tools-hub/mcp';
    final functions = _FakeFunctionsClient();
    final client = _FakeSupabaseClient(
      user: _FakeUser(),
      functions: functions,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: JibunApiPage(
          supabaseClient: client,
          mcpEndpointUrl: endpoint,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('antigravity_mcp_card')),
      findsOneWidget,
    );
    expect(find.text('Antigravity MCP 接続'), findsOneWidget);
    expect(find.text(endpoint), findsOneWidget);
    expect(find.textContaining('<YOUR_JIBUN_API_KEY>'), findsWidgets);

    await _scrollToAndPump(tester, find.text('Antigravity MCP'));
    expect(find.text('Antigravity MCP'), findsOneWidget);
    expect(
      functions.invokedActions,
      containsAll(<String>[
        'tools-hub:jibunapi.key.list',
        'tools-hub:jibunapi.worker.list',
      ]),
    );
  });

  testWidgets('copy buttons write endpoint URL and valid mcp_config.json', (
    WidgetTester tester,
  ) async {
    const endpoint = 'https://example.supabase.co/functions/v1/tools-hub/mcp';
    String? copiedText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        if (call.method == 'Clipboard.setData') {
          final args = call.arguments;
          if (args is Map) {
            copiedText = args['text'] as String?;
          }
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    final functions = _FakeFunctionsClient();
    final client = _FakeSupabaseClient(
      user: _FakeUser(),
      functions: functions,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: JibunApiPage(
          supabaseClient: client,
          mcpEndpointUrl: endpoint,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final endpointBtn =
        find.byKey(const ValueKey<String>('copy_mcp_endpoint_button'));
    await _scrollToAndPump(tester, endpointBtn);
    await tester.tap(endpointBtn);
    await tester.pumpAndSettle();

    expect(copiedText, endpoint);
    expect(find.text('MCP エンドポイントをコピーしました'), findsOneWidget);

    final configBtn =
        find.byKey(const ValueKey<String>('copy_mcp_config_button'));
    await _scrollToAndPump(tester, configBtn);
    await tester.tap(configBtn);
    await tester.pumpAndSettle();

    expect(copiedText, isNotNull);
    final decoded = jsonDecode(copiedText!) as Map<String, Object?>;
    final servers = decoded['mcpServers']! as Map<String, Object?>;
    final server = servers['my-web-app']! as Map<String, Object?>;
    final headers = server['headers']! as Map<String, Object?>;
    expect(server['serverUrl'], endpoint);
    expect(headers['Authorization'], 'Bearer <YOUR_JIBUN_API_KEY>');
    expect(find.text('Antigravity MCP 設定 JSON をコピーしました'), findsOneWidget);
  });

  test('resolveMcpEndpointUrl returns placeholder or explicit override', () {
    expect(
      JibunApiPage.resolveMcpEndpointUrl(),
      JibunApiPage.mcpEndpointPlaceholder,
    );
    expect(
      JibunApiPage.resolveMcpEndpointUrl(
        overrideUrl: 'https://example.supabase.co/functions/v1/tools-hub/mcp',
      ),
      'https://example.supabase.co/functions/v1/tools-hub/mcp',
    );
  });

  testWidgets('reflows at 320px 2.0x textScale with labeled 48px targets', (
    WidgetTester tester,
  ) async {
    final semanticsHandle = tester.ensureSemantics();
    try {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const endpoint = 'https://example.supabase.co/functions/v1/tools-hub/mcp';
      final functions = _FakeFunctionsClient();
      final client = _FakeSupabaseClient(
        user: _FakeUser(),
        functions: functions,
      );

      await tester.pumpWidget(
        MaterialApp(
          builder: (BuildContext context, Widget? child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2),
            ),
            child: child!,
          ),
          home: JibunApiPage(
            supabaseClient: client,
            mcpEndpointUrl: endpoint,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      final endpointBtn =
          find.byKey(const ValueKey<String>('copy_mcp_endpoint_button'));
      await _scrollToAndPump(tester, endpointBtn);
      expect(tester.takeException(), isNull);
      expect(tester.getSize(endpointBtn).width, greaterThanOrEqualTo(48));
      expect(tester.getSize(endpointBtn).height, greaterThanOrEqualTo(48));

      final configBtn =
          find.byKey(const ValueKey<String>('copy_mcp_config_button'));
      await _scrollToAndPump(tester, configBtn);
      expect(tester.takeException(), isNull);
      expect(tester.getSize(configBtn).width, greaterThanOrEqualTo(48));
      expect(tester.getSize(configBtn).height, greaterThanOrEqualTo(48));

      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    } finally {
      semanticsHandle.dispose();
    }
  });
}
