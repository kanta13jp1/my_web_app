import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_web_app/pages/asset_management_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@JS('window.__flowProbeState')
external set probeState(JSString value);

Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  final semantics = binding.ensureSemantics();
  final requests = <String>[];
  SharedPreferences.setMockInitialValues(
    <String, Object>{'asset_management_display_mode_v1': 'full'},
  );
  await Supabase.initialize(
    url: 'http://127.0.0.1:9999',
    publishableKey: 'synthetic-publishable-key',
    httpClient: MockClient((request) async {
      requests.add('${request.method} ${request.url.path}');
      return http.Response(
        '[]',
        200,
        headers: {'content-type': 'application/json'},
      );
    }),
    authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
  );
  final pageKey = GlobalKey();
  runApp(
    MaterialApp(
      theme: ThemeData(fontFamily: 'NotoSansJP'),
      home: AssetManagementPage(
        key: pageKey,
        initialFocus: AssetManagementInitialFocus.flow,
      ),
    ),
  );
  Timer.periodic(
    const Duration(milliseconds: 100),
    (_) {
      final values = <String, String>{};
      void visit(Element element) {
        final widget = element.widget;
        if (widget is TextField) {
          final label = widget.decoration?.labelText;
          if (label == '内容' || label == 'メモ（任意）' || label == '金額 (円)') {
            values[label!] = widget.controller?.text ?? '';
          }
        }
        element.visitChildren(visit);
      }

      final context = pageKey.currentContext;
      if (context is Element) visit(context);
      probeState = jsonEncode(
        {
          'fields': values,
          'requests': requests,
          'authenticated': Supabase.instance.client.auth.currentUser != null,
          'semantics': semantics.hashCode,
        },
      ).toJS;
    },
  );
}
