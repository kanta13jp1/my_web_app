import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_web_app/models/public_memo.dart';
import 'package:my_web_app/pages/public_memo_detail_page.dart';
import 'package:my_web_app/services/public_memo_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

PublicMemoService _mockMemoService({required Map<String, dynamic> memoRow}) {
  final client = SupabaseClient(
    'https://example.supabase.co',
    'test-anon-key',
    httpClient: MockClient((request) async {
      if (request.url.path.endsWith('/rest/v1/public_memos') &&
          request.method == 'GET') {
        return http.Response(
          jsonEncode(memoRow),
          200,
          headers: const <String, String>{'content-type': 'application/json'},
          request: request,
        );
      }
      return http.Response(
        jsonEncode(<String, dynamic>{
          'reactions': <String, int>{},
          'userReactions': <String>[],
        }),
        200,
        headers: const <String, String>{'content-type': 'application/json'},
        request: request,
      );
    }),
  );
  return PublicMemoService(client);
}

Map<String, dynamic> _sampleMemoRow() => <String, dynamic>{
      'id': 15,
      'note_id': 99,
      'user_id': 'author-1',
      'title': '週次レビュー型テンプレート',
      'content': '> [!TIP]\n> 毎週日曜に振り返る\n\n- [ ] 今週の成果',
      'category': 'テンプレート',
      'like_count': 2,
      'view_count': 10,
      'is_public': true,
      'published_at': '2026-11-26T10:00:00Z',
      'created_at': '2026-11-26T10:00:00Z',
      'updated_at': '2026-11-26T10:00:00Z',
    };

void main() {
  testWidgets(
    'PublicMemoDetailPage renders MarkdownPreview and signup CTA when logged out',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PublicMemoDetailPage(
            memoId: 15,
            publicMemoService: _mockMemoService(memoRow: _sampleMemoRow()),
            currentUserIdOverride: '',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('週次レビュー型テンプレート'), findsOneWidget);
      expect(find.text('TIP'), findsOneWidget);
      expect(find.text('毎週日曜に振り返る'), findsOneWidget);
      expect(find.text('Create account to save ideas'), findsOneWidget);
      expect(find.byKey(PublicMemoDetailPage.cloneButtonKey), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'PublicMemoDetailPage triggers template clone callback when signed in',
    (tester) async {
      PublicMemo? clonedTarget;
      await tester.pumpWidget(
        MaterialApp(
          home: PublicMemoDetailPage(
            memoId: 15,
            publicMemoService: _mockMemoService(memoRow: _sampleMemoRow()),
            currentUserIdOverride: 'signed-in-user',
            cloneMemoOverride: (memo) async {
              clonedTarget = memo;
              return null;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final cloneButton = find.byKey(PublicMemoDetailPage.cloneButtonKey);
      expect(cloneButton, findsOneWidget);
      await tester.tap(cloneButton);
      await tester.pumpAndSettle();

      expect(clonedTarget?.id, 15);
      expect(clonedTarget?.title, '週次レビュー型テンプレート');
      expect(tester.takeException(), isNull);
    },
  );
}
