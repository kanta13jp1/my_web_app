import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Reads focus node layout bounds only after the node and its RenderBox
/// ancestors have completed layout.
///
/// Prevents Flutter Web `RenderBox was not laid out` throws when
/// `ViewFocusEvent` triggers initial focus traversal before the first layout
/// pass finishes.
class LayoutSafeReadingOrderTraversalPolicy
    extends ReadingOrderTraversalPolicy {
  LayoutSafeReadingOrderTraversalPolicy({super.requestFocusCallback});

  @visibleForTesting
  static bool hasLaidOutRenderBox(FocusNode node) {
    final RenderObject? renderObject = node.context?.findRenderObject();
    if (renderObject is! RenderBox ||
        !renderObject.attached ||
        !renderObject.hasSize) {
      return false;
    }

    RenderObject? current = renderObject.parent;
    while (current != null) {
      if (current is RenderBox && !current.hasSize) {
        return false;
      }
      current = current.parent;
    }
    return true;
  }

  @override
  Iterable<FocusNode> sortDescendants(
    Iterable<FocusNode> descendants,
    FocusNode currentNode,
  ) {
    final laidOut = <FocusNode>[];
    final pendingLayout = <FocusNode>[];

    for (final node in descendants) {
      if (hasLaidOutRenderBox(node)) {
        laidOut.add(node);
      } else {
        pendingLayout.add(node);
      }
    }

    if (pendingLayout.isEmpty) {
      return super.sortDescendants(laidOut, currentNode);
    }

    return <FocusNode>[
      ...super.sortDescendants(laidOut, currentNode),
      ...pendingLayout,
    ];
  }
}
