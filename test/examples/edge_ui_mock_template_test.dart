import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Copyable test-only fixture: production code must inject its real reader.
abstract interface class ExampleReader {
  Future<List<String>> load();
}

class FakeExampleReader implements ExampleReader {
  FakeExampleReader({this.items = const [], this.error});
  final List<String> items;
  final Exception? error;

  @override
  Future<List<String>> load() async {
    if (error case final failure?) throw failure;
    return List.unmodifiable(items);
  }
}

class ExampleScreen extends StatelessWidget {
  const ExampleScreen({required this.reader, super.key});
  final ExampleReader reader;

  @override
  Widget build(BuildContext context) => MaterialApp(
        home: Scaffold(
          body: FutureBuilder<List<String>>(
            future: reader.load(),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const CircularProgressIndicator();
              }
              if (snapshot.hasError) return const Text('取得できませんでした');
              final items = snapshot.data!;
              if (items.isEmpty) return const Text('データがありません');
              return Text(items.join(', '));
            },
          ),
        ),
      );
}

void main() {
  testWidgets('fake backend displays a successful result', (tester) async {
    await tester.pumpWidget(
      ExampleScreen(reader: FakeExampleReader(items: ['sample'])),
    );
    await tester.pumpAndSettle();
    expect(find.text('sample'), findsOneWidget);
    expect(find.text('データがありません'), findsNothing);
  });

  testWidgets('fake backend distinguishes an empty result', (tester) async {
    await tester.pumpWidget(ExampleScreen(reader: FakeExampleReader()));
    await tester.pumpAndSettle();
    expect(find.text('データがありません'), findsOneWidget);
    expect(find.text('取得できませんでした'), findsNothing);
  });

  testWidgets('fake backend does not report a failure as empty', (
    tester,
  ) async {
    await tester.pumpWidget(
      ExampleScreen(reader: FakeExampleReader(error: Exception('offline'))),
    );
    await tester.pumpAndSettle();
    expect(find.text('取得できませんでした'), findsOneWidget);
    expect(find.text('データがありません'), findsNothing);
  });
}
