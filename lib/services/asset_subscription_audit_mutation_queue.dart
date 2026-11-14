/// Serializes local subscription-audit loads, decisions, and mirror restores.
///
/// A failed mutation is reported to its caller without blocking later mutations.
/// Operations must not await another run on this same queue.
class AssetSubscriptionAuditMutationQueue {
  Future<void> _tail = Future<void>.value();

  Future<T> run<T>(Future<T> Function() operation) {
    final result = _tail.then((_) => operation());
    _tail = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );
    return result;
  }
}
