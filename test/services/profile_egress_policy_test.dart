import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/user_profile.dart';
import 'package:my_web_app/services/profile_egress_policy.dart';

void main() {
  group('ProfileEgressPolicy', () {
    test('accepts a supported image at the upload limit', () {
      expect(
        () => ProfileEgressPolicy.validateAvatar(
          fileBytes: Uint8List(ProfileEgressPolicy.maxAvatarBytes),
          fileExtension: '.JPG',
          contentType: ' IMAGE/JPEG ',
        ),
        returnsNormally,
      );
      expect(
        ProfileEgressPolicy.normalizeContentType(' IMAGE/JPEG '),
        'image/jpeg',
      );
    });

    test('rejects oversized and mismatched image uploads', () {
      expect(
        () => ProfileEgressPolicy.validateAvatar(
          fileBytes: Uint8List(ProfileEgressPolicy.maxAvatarBytes + 1),
          fileExtension: 'png',
          contentType: 'image/png',
        ),
        throwsA(isA<ProfileAvatarValidationException>()),
      );
      expect(
        () => ProfileEgressPolicy.validateAvatar(
          fileBytes: Uint8List.fromList([1]),
          fileExtension: 'png',
          contentType: 'image/jpeg',
        ),
        throwsA(isA<ProfileAvatarValidationException>()),
      );
      expect(
        () => ProfileEgressPolicy.validateAvatar(
          fileBytes: Uint8List.fromList([1]),
          fileExtension: 'svg',
          contentType: 'image/svg+xml',
        ),
        throwsA(isA<ProfileAvatarValidationException>()),
      );
      expect(
        () => ProfileEgressPolicy.validateAvatar(
          fileBytes: Uint8List(0),
          fileExtension: 'png',
          contentType: 'image/png',
        ),
        throwsA(isA<ProfileAvatarValidationException>()),
      );
    });

    test('versions URLs by content while preserving transform parameters', () {
      const baseUrl =
          'https://example.supabase.co/storage/v1/render/image/public/avatars/user.png?width=256&quality=80';
      final first = ProfileEgressPolicy.versionedPublicUrl(
        baseUrl,
        Uint8List.fromList([1, 2, 3]),
      );
      final same = ProfileEgressPolicy.versionedPublicUrl(
        baseUrl,
        Uint8List.fromList([1, 2, 3]),
      );
      final changed = ProfileEgressPolicy.versionedPublicUrl(
        baseUrl,
        Uint8List.fromList([1, 2, 4]),
      );

      expect(first, same);
      expect(changed, isNot(first));
      expect(Uri.parse(first).queryParameters['width'], '256');
      expect(Uri.parse(first).queryParameters['quality'], '80');
      expect(Uri.parse(first).queryParameters['v'], hasLength(16));
    });

    test('keeps paid image transformations disabled by default', () {
      expect(ProfileEgressPolicy.imageTransformEnabled, isFalse);
      expect(ProfileEgressPolicy.avatarTransformOptions(), isNull);

      final enabled = ProfileEgressPolicy.avatarTransformOptions(
        enabled: true,
      )!;
      expect(enabled.width, 256);
      expect(enabled.height, 256);
      expect(enabled.quality, 80);
    });
  });

  group('ProfileReadCache', () {
    late DateTime now;
    late ProfileReadCache cache;

    setUp(() {
      now = DateTime.utc(2026, 8, 10, 10);
      cache = ProfileReadCache(
        ttl: const Duration(minutes: 5),
        maxEntries: 2,
        now: () => now,
      );
    });

    test('returns a cached profile only within the TTL', () {
      final profile = UserProfile(userId: 'user-1');
      cache.write(profile);

      now = now.add(const Duration(minutes: 4, seconds: 59));
      expect(cache.read('user-1'), same(profile));

      now = now.add(const Duration(seconds: 1));
      expect(cache.read('user-1'), isNull);
    });

    test('invalidates updates and evicts the oldest bounded entry', () {
      cache.write(UserProfile(userId: 'user-1'));
      now = now.add(const Duration(seconds: 1));
      cache.write(UserProfile(userId: 'user-2'));
      now = now.add(const Duration(seconds: 1));
      cache.write(UserProfile(userId: 'user-3'));

      expect(cache.length, 2);
      expect(cache.read('user-1'), isNull);
      cache.invalidate('user-2');
      expect(cache.read('user-2'), isNull);
    });
  });

  test('avatar bucket migration enforces size and MIME restrictions', () {
    final migration = File(
      'supabase/migrations/20260826083000_harden_avatar_storage_egress.sql',
    ).readAsStringSync();
    expect(migration, contains("where id = 'avatars'"));
    expect(migration, contains('file_size_limit = 5242880'));
    expect(migration, contains("'image/png'"));
    expect(migration, contains("'image/jpeg'"));
    expect(migration, contains("'image/webp'"));
    expect(migration, contains("'image/gif'"));
  });

  test('profile service wires bounded reads and response-free writes', () {
    final source = File('lib/services/profile_service.dart').readAsStringSync();
    const cacheControlWiring =
        'cacheControl: ProfileEgressPolicy.avatarCacheControl';

    expect(source, contains('.select(_profileColumns)'));
    expect(source, isNot(contains('.select()')));
    expect(source, contains(cacheControlWiring));
    expect(source, contains('ProfileEgressPolicy.versionedPublicUrl'));
  });
}
