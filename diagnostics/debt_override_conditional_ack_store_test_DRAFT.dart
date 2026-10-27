// DRAFT ONLY: not executed. Requires the store portion of
// debt_override_conditional_ack_DRAFT.patch at the stated public base.
// Suggested destination: test/services/asset_sync_dirty_keys_conditional_clear_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_sync_dirty_keys_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const store = AssetSyncDirtyKeysStore();
  const target = 'debt_payment_day_overrides';
  const other = 'other_domain';

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AssetSyncDirtyKeysStore.resetWriteLockForTest();
  });

  test('unchanged generation clears only the requested domain', () async {
    final prefs = await SharedPreferences.getInstance();
    await store.markDirty(target, 'mobit', prefs: prefs);
    await store.markDirty(other, 'keep', prefs: prefs);
    final generation = AssetSyncDirtyKeysStore.mutationGeneration;
    expect(AssetSyncDirtyKeysStore.hasPendingMutations, isFalse);
    Set<String>? observed;

    await store.clearDomainIfUnchanged(
      target,
      generation: generation,
      isCurrent: (keys) {
        observed = keys;
        return true;
      },
      prefs: prefs,
    );

    expect(observed, <String>{'mobit'});
    expect(await store.loadDirty(target, prefs: prefs), isEmpty);
    expect(await store.loadDirty(other, prefs: prefs), <String>{'keep'});
  });

  test('same-key re-mark after generation is never acknowledged by old clear',
      () async {
    final prefs = await SharedPreferences.getInstance();
    await store.markDirty(target, 'mobit', prefs: prefs);
    final generation = AssetSyncDirtyKeysStore.mutationGeneration;
    await store.markDirty(target, 'mobit', prefs: prefs);

    await store.clearDomainIfUnchanged(
      target,
      generation: generation,
      isCurrent: (_) => true,
      prefs: prefs,
    );

    expect(await store.loadDirty(target, prefs: prefs), <String>{'mobit'});
  });

  test('a newer mutation in another domain makes old clear conservative',
      () async {
    final prefs = await SharedPreferences.getInstance();
    await store.markDirty(target, 'mobit', prefs: prefs);
    final generation = AssetSyncDirtyKeysStore.mutationGeneration;
    await store.markDirty(other, 'new', prefs: prefs);

    await store.clearDomainIfUnchanged(
      target,
      generation: generation,
      isCurrent: (_) => true,
      prefs: prefs,
    );

    expect(await store.loadDirty(target, prefs: prefs), <String>{'mobit'});
    expect(await store.loadDirty(other, prefs: prefs), <String>{'new'});
  });

  test('a mark queued immediately after clear is never erased', () async {
    final prefs = await SharedPreferences.getInstance();
    await store.markDirty(target, 'mobit', prefs: prefs);
    final generation = AssetSyncDirtyKeysStore.mutationGeneration;

    // Both are enqueued synchronously. The generation changes as soon as
    // markDirty is called, before either Future is awaited.
    final clear = store.clearDomainIfUnchanged(
      target,
      generation: generation,
      isCurrent: (_) => true,
      prefs: prefs,
    );
    final mark = store.markDirty(target, 'new-key', prefs: prefs);
    await Future.wait(<Future<void>>[clear, mark]);

    expect(
      await store.loadDirty(target, prefs: prefs),
      <String>{'mobit', 'new-key'},
    );
  });

  test('a false predicate preserves dirty and leaves the lock usable',
      () async {
    final prefs = await SharedPreferences.getInstance();
    await store.markDirty(target, 'mobit', prefs: prefs);
    final generation = AssetSyncDirtyKeysStore.mutationGeneration;
    var called = false;

    await store.clearDomainIfUnchanged(
      target,
      generation: generation,
      isCurrent: (keys) {
        called = true;
        expect(keys, <String>{'mobit'});
        return false;
      },
      prefs: prefs,
    );
    expect(called, isTrue);
    expect(await store.loadDirty(target, prefs: prefs), <String>{'mobit'});
    await store.markDirty(target, 'new-key', prefs: prefs);
    expect(
      await store.loadDirty(target, prefs: prefs),
      <String>{'mobit', 'new-key'},
    );
  });

  test('a throwing predicate propagates error and does not poison the lock',
      () async {
    final prefs = await SharedPreferences.getInstance();
    await store.markDirty(target, 'mobit', prefs: prefs);
    final generation = AssetSyncDirtyKeysStore.mutationGeneration;
    var called = false;

    await expectLater(
      store.clearDomainIfUnchanged(
        target,
        generation: generation,
        isCurrent: (_) {
          called = true;
          throw StateError('predicate failure');
        },
        prefs: prefs,
      ),
      throwsA(isA<StateError>()),
    );
    expect(called, isTrue);
    expect(await store.loadDirty(target, prefs: prefs), <String>{'mobit'});
    await store.markDirty(target, 'new-key', prefs: prefs);
    expect(
      await store.loadDirty(target, prefs: prefs),
      <String>{'mobit', 'new-key'},
    );
  });
}