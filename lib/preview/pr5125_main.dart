import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../pages/import_page.dart';
import '../pages/note_collections_page.dart';
import '../pages/note_editor_page.dart';
import '../pages/note_list_page.dart';
import '../pages/note_navigation_page.dart';
import '../pages/note_tags_page.dart';
import '../pages/note_tasks_page.dart';
import '../pages/space_sharing_page.dart';
import '../services/gamification_service.dart';
import '../services/theme_service.dart';
import 'pr5125_store.dart';

/// Dedicated entrypoint: intentionally never imports main.dart or Firebase.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Keep accessibility information available for cloud UI verification.
  WidgetsBinding.instance.ensureSemantics();
  final store = Preview5125Store();
  await Supabase.initialize(
    url: 'https://pr5125.invalid',
    publishableKey: 'fictional-preview-not-a-secret',
    httpClient: store.client,
    authOptions: const FlutterAuthClientOptions(
      autoRefreshToken: false,
      detectSessionInUri: false,
      localStorage: EmptyLocalStorage(),
    ),
  );
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  final payload = {
    'sub': Preview5125Store.userId,
    'exp': 4102444800,
    'role': 'authenticated',
  };
  final token =
      '${encode({'alg': 'none', 'typ': 'JWT'})}.${encode(payload)}.preview';
  await Supabase.instance.client.auth.recoverSession(
    jsonEncode({
      'access_token': token,
      'refresh_token': 'fictional-preview',
      'token_type': 'bearer',
      'expires_in': 315360000,
      'expires_at': 4102444800,
      'user': {
        'id': Preview5125Store.userId,
        'aud': 'authenticated',
        'email': 'reader@example.invalid',
        'app_metadata': <String, dynamic>{},
        'user_metadata': <String, dynamic>{},
        'created_at': Preview5125Store.date,
      },
    }),
  );
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GamificationService()),
        ChangeNotifierProvider(create: (_) => ThemeService()),
      ],
      child: const Preview5125App(),
    ),
  );
}

class Preview5125App extends StatelessWidget {
  const Preview5125App({super.key});

  @override
  Widget build(BuildContext context) {
    final screen = Uri.base.queryParameters['screen'] ?? 'note-list';
    final page = switch (screen) {
      'import' => const ImportPage(),
      'note-editor' => const NoteEditorPage(noteId: '1'),
      'note-collections' => const NoteCollectionsPage(),
      'note-tags' => const NoteTagsPage(),
      'note-navigation' => const NoteNavigationPage(),
      'note-tasks' => const NoteTasksPage(),
      'space-sharing' => const SpaceSharingPage(initialSpaceId: 1),
      _ => const NoteListPage(),
    };
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PR #5125 架空データ・画面確認',
      locale: const Locale('ja'),
      supportedLocales: const [Locale('ja'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
        fontFamily: 'NotoSansJP',
      ),
      builder: (context, child) => Column(
        children: [
          Material(
            color: const Color(0xFFFFF3CD),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  '架空データ・閲覧専用／DB接続なし\n保存・共有・ファイル取込・AIは実行しません。個人情報を入力しないでください。',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          ),
          Expanded(child: child ?? const SizedBox.shrink()),
        ],
      ),
      home: page,
    );
  }
}
