import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/utils/layout_safe_focus_traversal_policy.dart';

class _SkipChildLayout extends SingleChildRenderObjectWidget {
  const _SkipChildLayout({required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _SkipChildLayoutRenderBox();
  }
}

class _SkipChildLayoutRenderBox extends RenderProxyBox {
  @override
  void performLayout() {
    size = constraints.constrain(const Size(100, 100));
  }

  @override
  void paint(PaintingContext context, Offset offset) {}

  @override
  bool hitTestChildren(
    BoxHitTestResult result, {
    required Offset position,
  }) {
    return false;
  }
}

void main() {
  testWidgets(
    'avoids StateError when a FocusNode RenderBox is attached without layout',
    (WidgetTester tester) async {
      final laidOutNode = FocusNode(debugLabel: 'laidOut');
      final unlaidOutNode = FocusNode(debugLabel: 'unlaidOut');
      addTearDown(laidOutNode.dispose);
      addTearDown(unlaidOutNode.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: <Widget>[
                Focus(
                  focusNode: laidOutNode,
                  child: const SizedBox(width: 80, height: 32),
                ),
                _SkipChildLayout(
                  child: Focus(
                    focusNode: unlaidOutNode,
                    child: const SizedBox(width: 80, height: 32),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      expect(
        LayoutSafeReadingOrderTraversalPolicy.hasLaidOutRenderBox(laidOutNode),
        isTrue,
      );
      expect(
        LayoutSafeReadingOrderTraversalPolicy.hasLaidOutRenderBox(
          unlaidOutNode,
        ),
        isFalse,
      );

      expect(
        () => ReadingOrderTraversalPolicy.sort(<FocusNode>[
          laidOutNode,
          unlaidOutNode,
        ]),
        throwsStateError,
      );

      final policy = LayoutSafeReadingOrderTraversalPolicy();
      final sorted = policy.sortDescendants(
        <FocusNode>[unlaidOutNode, laidOutNode],
        laidOutNode,
      );
      expect(sorted.toList(), <FocusNode>[laidOutNode, unlaidOutNode]);
    },
  );

  testWidgets(
    'handles unattached FocusNodes alongside laid-out nodes safely',
    (WidgetTester tester) async {
      final laidOutNode = FocusNode(debugLabel: 'laidOut');
      final detachedNode = FocusNode(debugLabel: 'detached');
      addTearDown(laidOutNode.dispose);
      addTearDown(detachedNode.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Focus(
              focusNode: laidOutNode,
              child: const SizedBox(width: 80, height: 32),
            ),
          ),
        ),
      );

      final policy = LayoutSafeReadingOrderTraversalPolicy();
      final sorted = policy.sortDescendants(
        <FocusNode>[detachedNode, laidOutNode],
        laidOutNode,
      );
      expect(sorted.toList(), <FocusNode>[laidOutNode, detachedNode]);
    },
  );

  testWidgets(
    'preserves standard reading order when all descendants are laid out',
    (WidgetTester tester) async {
      final topLeft = FocusNode(debugLabel: 'topLeft');
      final topRight = FocusNode(debugLabel: 'topRight');
      final bottom = FocusNode(debugLabel: 'bottom');
      addTearDown(topLeft.dispose);
      addTearDown(topRight.dispose);
      addTearDown(bottom.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Focus(
                      focusNode: topRight,
                      child: const SizedBox(width: 60, height: 30),
                    ),
                    Focus(
                      focusNode: topLeft,
                      child: const SizedBox(width: 60, height: 30),
                    ),
                  ],
                ),
                Focus(
                  focusNode: bottom,
                  child: const SizedBox(width: 60, height: 30),
                ),
              ],
            ),
          ),
        ),
      );

      final nodes = <FocusNode>[bottom, topLeft, topRight];
      final expected = ReadingOrderTraversalPolicy().sortDescendants(
        nodes,
        bottom,
      );
      final actual = LayoutSafeReadingOrderTraversalPolicy().sortDescendants(
        nodes,
        bottom,
      );
      expect(actual.toList(), expected.toList());
    },
  );

  testWidgets(
    'propagates MaterialApp.builder FocusTraversalGroup into pushed routes',
    (WidgetTester tester) async {
      late FocusTraversalPolicy observedPolicy;

      await tester.pumpWidget(
        MaterialApp(
          builder: (BuildContext context, Widget? child) {
            return FocusTraversalGroup(
              policy: LayoutSafeReadingOrderTraversalPolicy(),
              child: child!,
            );
          },
          routes: <String, WidgetBuilder>{
            '/': (BuildContext context) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pushNamed('/next');
                    },
                    child: const Text('Go'),
                  ),
                ),
              );
            },
            '/next': (BuildContext context) {
              return Scaffold(
                body: Builder(
                  builder: (BuildContext routeContext) {
                    observedPolicy = FocusTraversalGroup.of(routeContext);
                    return const Text('Next');
                  },
                ),
              );
            },
          },
        ),
      );

      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();

      expect(observedPolicy, isA<LayoutSafeReadingOrderTraversalPolicy>());
    },
  );
}
