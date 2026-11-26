import 'dart:async';
import 'dart:math';

/// Reproducible seeds used to expose Hyrum's Law order dependencies (#2792).
const List<int> hyrumDefaultSeeds = <int>[11, 29, 47, 83, 131];

/// Returns a new list with [items] shuffled deterministically using [seed].
List<T> permuteWithSeed<T>(
  List<T> items, {
  required int seed,
}) {
  final copy = List<T>.from(items);
  if (copy.length <= 1) {
    return copy;
  }
  copy.shuffle(Random(seed));
  return copy;
}

/// Runs [tasks] and yields their results in a seeded completion order.
Future<List<T>> resolveInSeededOrder<T>(
  List<Future<T> Function()> tasks, {
  required int seed,
}) async {
  final indexed = List<int>.generate(tasks.length, (int i) => i);
  final order = permuteWithSeed<int>(indexed, seed: seed);
  final completers = List<Completer<T>>.generate(
    tasks.length,
    (_) => Completer<T>(),
  );

  for (final idx in order) {
    final value = await tasks[idx]();
    completers[idx].complete(value);
  }

  return Future.wait<T>(
    completers.map((Completer<T> c) => c.future),
  );
}
