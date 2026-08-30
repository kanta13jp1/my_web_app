import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/evernote_tus_resume_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const bucketId = 'evernote-migration-archives';
  const objectPath = 'owner/batch/source.enex';
  final endpoint = Uri.parse(
    'https://project-ref.storage.supabase.co/storage/v1/upload/resumable',
  );
  final uploadUrl = Uri.parse(
    'https://project-ref.storage.supabase.co/'
    'storage/v1/upload/resumable/upload-id',
  );

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('stores only a hashed key and a short-lived safe upload URL', () async {
    final preferences = await SharedPreferences.getInstance();
    final store = SharedPreferencesEvernoteTusResumeStore(
      preferences: preferences,
      now: () => DateTime.utc(2026, 8, 30, 12),
    );

    await store.save(
      endpoint: endpoint,
      bucketId: bucketId,
      objectPath: objectPath,
      uploadUrl: uploadUrl,
    );

    final key = preferences.getKeys().single;
    final value = preferences.getString(key)!;
    expect(key, startsWith('evernote_tus_resume_v1_'));
    expect(key, isNot(contains(bucketId)));
    expect(key, isNot(contains(objectPath)));
    expect(value, contains(uploadUrl.toString()));
    expect(value, isNot(contains(bucketId)));
    expect(value, isNot(contains(objectPath)));
    expect(
      await store.load(
        endpoint: endpoint,
        bucketId: bucketId,
        objectPath: objectPath,
      ),
      uploadUrl,
    );
  });

  test('removes an expired resume URL instead of attempting it', () async {
    var now = DateTime.utc(2026, 8, 30, 12);
    final preferences = await SharedPreferences.getInstance();
    final store = SharedPreferencesEvernoteTusResumeStore(
      preferences: preferences,
      now: () => now,
    );
    await store.save(
      endpoint: endpoint,
      bucketId: bucketId,
      objectPath: objectPath,
      uploadUrl: uploadUrl,
    );
    now = now.add(const Duration(hours: 24));

    final result = await store.load(
      endpoint: endpoint,
      bucketId: bucketId,
      objectPath: objectPath,
    );

    expect(result, isNull);
    expect(preferences.getKeys(), isEmpty);
  });

  test('removes a tampered cross-host resume URL', () async {
    final preferences = await SharedPreferences.getInstance();
    final store = SharedPreferencesEvernoteTusResumeStore(
      preferences: preferences,
      now: () => DateTime.utc(2026, 8, 30, 12),
    );
    await store.save(
      endpoint: endpoint,
      bucketId: bucketId,
      objectPath: objectPath,
      uploadUrl: uploadUrl,
    );
    final key = preferences.getKeys().single;
    await preferences.setString(
      key,
      '{"upload_url":"https://example.com/steal",'
      '"expires_at":"2026-08-31T11:00:00.000Z"}',
    );

    final result = await store.load(
      endpoint: endpoint,
      bucketId: bucketId,
      objectPath: objectPath,
    );

    expect(result, isNull);
    expect(preferences.getKeys(), isEmpty);
  });

  test('rejects a tampered non-HTTPS-port resume URL', () async {
    final preferences = await SharedPreferences.getInstance();
    final store = SharedPreferencesEvernoteTusResumeStore(
      preferences: preferences,
      now: () => DateTime.utc(2026, 8, 30, 12),
    );

    await expectLater(
      store.save(
        endpoint: endpoint,
        bucketId: bucketId,
        objectPath: objectPath,
        uploadUrl: Uri.parse(
          'https://project-ref.storage.supabase.co:444/'
          'storage/v1/upload/resumable/upload-id',
        ),
      ),
      throwsArgumentError,
    );
    expect(preferences.getKeys(), isEmpty);
  });

  test('removes a resume URL after a completed upload', () async {
    final preferences = await SharedPreferences.getInstance();
    final store = SharedPreferencesEvernoteTusResumeStore(
      preferences: preferences,
    );
    await store.save(
      endpoint: endpoint,
      bucketId: bucketId,
      objectPath: objectPath,
      uploadUrl: uploadUrl,
    );

    await store.remove(bucketId: bucketId, objectPath: objectPath);

    expect(preferences.getKeys(), isEmpty);
  });
}
