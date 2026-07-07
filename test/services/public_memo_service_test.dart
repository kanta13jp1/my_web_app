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

      expect(
        url,
        PublicMemoService.buildPublicMemoAppUrl(42),
      );
    });

    test('buildPublicMemoReaderUrl returns the bot-readable core-hub route',
        () {
      final url = PublicMemoService.buildPublicMemoReaderUrl(44);

      expect(
        url,
        'https://smmkxxavexumewbfaqpy.supabase.co/functions/v1/core-hub'
        '?action=memo.public.view&id=44',
      );
    });

    test('buildPublicMemoReaderUrl appends the requested format', () {
      final url =
          PublicMemoService.buildPublicMemoReaderUrl(44, format: 'json');

      expect(
        url,
        'https://smmkxxavexumewbfaqpy.supabase.co/functions/v1/core-hub'
        '?action=memo.public.view&id=44&format=json',
      );
    });
  });
}
