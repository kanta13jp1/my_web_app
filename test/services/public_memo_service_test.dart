import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/public_memo_service.dart';

void main() {
  group('PublicMemoService URL builders', () {
    test('buildPublicMemoAppUrl returns the app detail route', () {
      final url = PublicMemoService.buildPublicMemoAppUrl(42);

      expect(
        url,
        'https://my-web-app-b67f4.web.app/public-memo?id=42&utm_source=public_memo&utm_medium=share&utm_campaign=growth_mission',
      );
    });

    test('buildPublicMemoUrl returns the app detail route', () {
      final url = PublicMemoService.buildPublicMemoUrl(42);

      expect(url, PublicMemoService.buildPublicMemoAppUrl(42));
    });

    test(
      'buildPublicMemoReaderUrl returns the bot-readable core-hub route',
      () {
        final url = PublicMemoService.buildPublicMemoReaderUrl(
          44,
          supabaseUrl: 'https://example.supabase.co',
        );

        expect(
          url,
          'https://example.supabase.co/functions/v1/core-hub'
          '?action=memo.public.view&id=44',
        );
      },
    );

    test('buildPublicMemoReaderUrl appends the requested format', () {
      final url = PublicMemoService.buildPublicMemoReaderUrl(
        44,
        format: 'json',
        supabaseUrl: 'https://example.supabase.co',
      );

      expect(
        url,
        'https://example.supabase.co/functions/v1/core-hub'
        '?action=memo.public.view&id=44&format=json',
      );
    });
  });

  group('PublicMemoService reaction contract', () {
    test('load request uses only memo.react.list', () {
      expect(PublicMemoService.buildLoadReactionsRequest(42), {
        'action': 'memo.react.list',
        'memo_id': 42,
      });
    });

    test('toggle request uses only memo.react.toggle', () {
      expect(
        PublicMemoService.buildToggleReactionRequest(
          memoId: 42,
          reaction: '👍',
        ),
        {'action': 'memo.react.toggle', 'memo_id': 42, 'reaction': '👍'},
      );
    });
  });
}
