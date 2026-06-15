import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_mirror_read_policy.dart';

void main() {
  group('resolveMirrorRead (last-write-wins)', () {
    final t1 = DateTime.utc(2026, 6, 14, 10, 0, 0);
    final t2 = DateTime.utc(2026, 6, 14, 11, 0, 0);

    test('no mirror → keep local', () {
      expect(
        resolveMirrorRead(
          hasLocal: true,
          hasMirror: false,
          localUpdatedAt: t1,
          mirrorUpdatedAt: null,
        ),
        AssetMirrorAdoption.keepLocal,
      );
    });

    test('no local → adopt mirror', () {
      expect(
        resolveMirrorRead(
          hasLocal: false,
          hasMirror: true,
          localUpdatedAt: null,
          mirrorUpdatedAt: t1,
        ),
        AssetMirrorAdoption.adoptMirror,
      );
    });

    test('both present, mirror newer → adopt mirror', () {
      expect(
        resolveMirrorRead(
          hasLocal: true,
          hasMirror: true,
          localUpdatedAt: t1,
          mirrorUpdatedAt: t2,
        ),
        AssetMirrorAdoption.adoptMirror,
      );
    });

    test('both present, local newer → keep local (offline edit preserved)', () {
      expect(
        resolveMirrorRead(
          hasLocal: true,
          hasMirror: true,
          localUpdatedAt: t2,
          mirrorUpdatedAt: t1,
        ),
        AssetMirrorAdoption.keepLocal,
      );
    });

    test('both present, equal timestamps → keep local (stable tie)', () {
      expect(
        resolveMirrorRead(
          hasLocal: true,
          hasMirror: true,
          localUpdatedAt: t1,
          mirrorUpdatedAt: t1,
        ),
        AssetMirrorAdoption.keepLocal,
      );
    });

    test('both present, local timestamp null (legacy) → adopt mirror', () {
      expect(
        resolveMirrorRead(
          hasLocal: true,
          hasMirror: true,
          localUpdatedAt: null,
          mirrorUpdatedAt: t1,
        ),
        AssetMirrorAdoption.adoptMirror,
      );
    });

    test('both present, mirror timestamp null → keep local (safe side)', () {
      expect(
        resolveMirrorRead(
          hasLocal: true,
          hasMirror: true,
          localUpdatedAt: t1,
          mirrorUpdatedAt: null,
        ),
        AssetMirrorAdoption.keepLocal,
      );
    });

    test('flag default is OFF (production unchanged)', () {
      expect(AssetMirrorReadPolicy.authoritative, isFalse);
    });
  });

  group('readPrefKeys (Phase 3 legacy fallback flag)', () {
    test('legacy enabled (default) → aggregated + legacy keys', () {
      expect(
        AssetMirrorReadPolicy.readPrefKeys(
          aggregatedKey: 'asset_display_prefs_v1',
          legacyKeys: const <String>['display_mode', 'section_overrides'],
          legacyDisabled: false,
        ),
        <String>['asset_display_prefs_v1', 'display_mode', 'section_overrides'],
      );
    });

    test('legacy disabled → aggregated key only (fallback retired)', () {
      expect(
        AssetMirrorReadPolicy.readPrefKeys(
          aggregatedKey: 'asset_inflow_prefs_v1',
          legacyKeys: const <String>['inflow_deleted_ids'],
          legacyDisabled: true,
        ),
        <String>['asset_inflow_prefs_v1'],
      );
    });

    test('the Phase 3 build flag defaults to OFF (production unchanged)', () {
      expect(AssetMirrorReadPolicy.legacyReadDisabled, isFalse);
    });
  });
}
