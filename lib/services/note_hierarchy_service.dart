import 'note_wiki_link_service.dart';

class NoteTreeNode {
  final NoteSummary note;
  final int depth;
  final int childCount;
  final bool hasChildren;
  final bool isExpanded;

  const NoteTreeNode({
    required this.note,
    required this.depth,
    required this.childCount,
    required this.hasChildren,
    required this.isExpanded,
  });
}

/// Pure helpers for Notion-style nested subpages: breadcrumbs, descendant
/// traversal, parent cycle/depth validation, and tree flattening.
class NoteHierarchyService {
  NoteHierarchyService._();

  static const int maxDepth = 32;

  static Map<String, NoteSummary> _indexById(List<NoteSummary> allNotes) {
    final Map<String, NoteSummary> byId = <String, NoteSummary>{};
    for (final NoteSummary note in allNotes) {
      if (note.id.isNotEmpty) {
        byId[note.id] = note;
      }
    }
    return byId;
  }

  /// Returns `[root, ..., current]` for [noteId] with cycle and depth guards.
  static List<NoteSummary> buildBreadcrumbs({
    required String noteId,
    required List<NoteSummary> allNotes,
  }) {
    final Map<String, NoteSummary> byId = _indexById(allNotes);
    final NoteSummary? start = byId[noteId];
    if (start == null) {
      return const <NoteSummary>[];
    }

    final List<NoteSummary> chain = <NoteSummary>[start];
    final Set<String> visited = <String>{start.id};
    String? cursor = start.parentNoteId;
    int steps = 0;

    while (cursor != null &&
        cursor.isNotEmpty &&
        steps < maxDepth &&
        !visited.contains(cursor)) {
      final NoteSummary? parent = byId[cursor];
      if (parent == null) break;
      chain.add(parent);
      visited.add(parent.id);
      cursor = parent.parentNoteId;
      steps += 1;
    }

    return chain.reversed.toList(growable: false);
  }

  static List<NoteSummary> directChildren({
    required String parentNoteId,
    required List<NoteSummary> allNotes,
  }) {
    if (parentNoteId.isEmpty) {
      return const <NoteSummary>[];
    }
    return allNotes
        .where(
          (NoteSummary note) =>
              note.id != parentNoteId && note.parentNoteId == parentNoteId,
        )
        .toList(growable: false);
  }

  static Set<String> descendantIds({
    required String rootNoteId,
    required List<NoteSummary> allNotes,
  }) {
    if (rootNoteId.isEmpty) {
      return const <String>{};
    }
    final Map<String, List<NoteSummary>> childrenByParent =
        <String, List<NoteSummary>>{};
    for (final NoteSummary note in allNotes) {
      final String? pid = note.parentNoteId;
      if (pid == null || pid.isEmpty || pid == note.id) continue;
      childrenByParent.putIfAbsent(pid, () => <NoteSummary>[]).add(note);
    }

    final Set<String> out = <String>{};
    final List<String> queue = <String>[rootNoteId];
    int head = 0;
    while (head < queue.length) {
      final String current = queue[head];
      head += 1;
      final List<NoteSummary>? kids = childrenByParent[current];
      if (kids == null) continue;
      for (final NoteSummary kid in kids) {
        if (kid.id == rootNoteId) continue;
        if (out.add(kid.id)) {
          queue.add(kid.id);
        }
      }
    }
    return out;
  }

  static int depthOfParentChain({
    required String? parentNoteId,
    required Map<String, NoteSummary> byId,
  }) {
    if (parentNoteId == null || parentNoteId.isEmpty) {
      return 0;
    }
    final Set<String> visited = <String>{};
    String? cursor = parentNoteId;
    int depth = 0;
    while (cursor != null && cursor.isNotEmpty) {
      if (!visited.add(cursor) || depth > maxDepth) {
        return maxDepth + 1;
      }
      final NoteSummary? node = byId[cursor];
      if (node == null) {
        return -1;
      }
      depth += 1;
      cursor = node.parentNoteId;
    }
    return depth;
  }

  /// Validates whether [noteId] can safely move under [newParentNoteId].
  static bool canSetParent({
    required String noteId,
    required String? newParentNoteId,
    required List<NoteSummary> allNotes,
  }) {
    if (newParentNoteId == null || newParentNoteId.isEmpty) {
      return true;
    }
    if (newParentNoteId == noteId) {
      return false;
    }
    final Map<String, NoteSummary> byId = _indexById(allNotes);
    if (!byId.containsKey(newParentNoteId)) {
      return false;
    }
    if (noteId.isNotEmpty &&
        descendantIds(rootNoteId: noteId, allNotes: allNotes)
            .contains(newParentNoteId)) {
      return false;
    }
    final int parentDepth = depthOfParentChain(
      parentNoteId: newParentNoteId,
      byId: byId,
    );
    if (parentDepth < 0 || parentDepth > maxDepth) {
      return false;
    }
    if (noteId.isNotEmpty && byId.containsKey(noteId)) {
      final int subtreeHeight = _maxSubtreeHeight(
        rootId: noteId,
        allNotes: allNotes,
      );
      if (parentDepth + subtreeHeight > maxDepth) {
        return false;
      }
    }
    return true;
  }

  static int _maxSubtreeHeight({
    required String rootId,
    required List<NoteSummary> allNotes,
  }) {
    final Map<String, List<NoteSummary>> byParent =
        <String, List<NoteSummary>>{};
    for (final NoteSummary note in allNotes) {
      final String? pid = note.parentNoteId;
      if (pid == null || pid.isEmpty || pid == note.id) continue;
      byParent.putIfAbsent(pid, () => <NoteSummary>[]).add(note);
    }

    int visit(String id, Set<String> stack) {
      if (!stack.add(id)) return 0;
      int maxChild = 0;
      for (final NoteSummary child in byParent[id] ?? const <NoteSummary>[]) {
        final int h = 1 + visit(child.id, stack);
        if (h > maxChild) maxChild = h;
      }
      stack.remove(id);
      return maxChild;
    }

    return visit(rootId, <String>{});
  }

  /// Flattens notes into deterministic DFS tree rows, promoting orphans whose
  /// parent is missing/archived to depth 0.
  static List<NoteTreeNode> flattenTree({
    required List<NoteSummary> allNotes,
    required Set<String> expandedIds,
    bool expandAll = false,
  }) {
    if (allNotes.isEmpty) {
      return const <NoteTreeNode>[];
    }

    final Map<String, NoteSummary> byId = _indexById(allNotes);
    final Map<String, List<NoteSummary>> childrenByParent =
        <String, List<NoteSummary>>{};
    final List<NoteSummary> roots = <NoteSummary>[];

    for (final NoteSummary note in allNotes) {
      final String? pid = note.parentNoteId;
      if (pid != null &&
          pid.isNotEmpty &&
          pid != note.id &&
          byId.containsKey(pid)) {
        childrenByParent.putIfAbsent(pid, () => <NoteSummary>[]).add(note);
      } else {
        roots.add(note);
      }
    }

    final List<NoteTreeNode> out = <NoteTreeNode>[];
    final Set<String> emitted = <String>{};
    final Set<String> reachable = <String>{};

    void markReachable(String rootId) {
      final List<String> queue = <String>[rootId];
      int head = 0;
      while (head < queue.length) {
        final String id = queue[head];
        head += 1;
        if (!reachable.add(id)) continue;
        for (final NoteSummary child
            in childrenByParent[id] ?? const <NoteSummary>[]) {
          if (!reachable.contains(child.id)) {
            queue.add(child.id);
          }
        }
      }
    }

    void walk(NoteSummary node, int depth) {
      if (!emitted.add(node.id) || depth > maxDepth) {
        return;
      }
      final List<NoteSummary> kids =
          childrenByParent[node.id] ?? const <NoteSummary>[];
      final bool hasChildren = kids.isNotEmpty;
      final bool isExpanded =
          hasChildren && (expandAll || expandedIds.contains(node.id));
      out.add(
        NoteTreeNode(
          note: node,
          depth: depth,
          childCount: kids.length,
          hasChildren: hasChildren,
          isExpanded: isExpanded,
        ),
      );
      if (isExpanded) {
        for (final NoteSummary child in kids) {
          walk(child, depth + 1);
        }
      }
    }

    for (final NoteSummary root in roots) {
      markReachable(root.id);
      walk(root, 0);
    }

    // Break pure cycles whose members had parents inside the set without roots.
    for (final NoteSummary note in allNotes) {
      if (!reachable.contains(note.id)) {
        markReachable(note.id);
        walk(note, 0);
      }
    }

    return out;
  }
}
