enum InlineDiffSegmentType { unchanged, added, deleted }

class InlineDiffSegment {
  final InlineDiffSegmentType type;
  final String text;

  const InlineDiffSegment({
    required this.type,
    required this.text,
  });
}

class InlineDiffProposal {
  final String title;
  final String originalText;
  final String proposedText;
  final List<InlineDiffSegment> segments;
  final int addedSegmentCount;
  final int deletedSegmentCount;

  const InlineDiffProposal({
    required this.title,
    required this.originalText,
    required this.proposedText,
    required this.segments,
    required this.addedSegmentCount,
    required this.deletedSegmentCount,
  });

  bool get hasChanges => addedSegmentCount > 0 || deletedSegmentCount > 0;
}

class InlineTextDiffService {
  const InlineTextDiffService._();

  static List<String> tokenize(String text) {
    if (text.isEmpty) return const <String>[];
    final matches = RegExp(
      r'\r\n|\n|[A-Za-z0-9_]+|\s+|.',
      dotAll: true,
    ).allMatches(text);
    return matches
        .map((match) => match.group(0) ?? '')
        .where((token) => token.isNotEmpty)
        .toList(growable: false);
  }

  static List<InlineDiffSegment> computeDiff(
    String original,
    String proposed,
  ) {
    final a = tokenize(original);
    final b = tokenize(proposed);
    final n = a.length;
    final m = b.length;

    if (n == 0 && m == 0) {
      return const <InlineDiffSegment>[];
    }
    if (n == 0) {
      return <InlineDiffSegment>[
        InlineDiffSegment(type: InlineDiffSegmentType.added, text: proposed),
      ];
    }
    if (m == 0) {
      return <InlineDiffSegment>[
        InlineDiffSegment(type: InlineDiffSegmentType.deleted, text: original),
      ];
    }

    // Standard DP LCS table for concise prompt/suggestion proposals.
    final dp = List<List<int>>.generate(
      n + 1,
      (_) => List<int>.filled(m + 1, 0),
    );
    for (var i = n - 1; i >= 0; i--) {
      for (var j = m - 1; j >= 0; j--) {
        if (a[i] == b[j]) {
          dp[i][j] = 1 + dp[i + 1][j + 1];
        } else {
          final down = dp[i + 1][j];
          final right = dp[i][j + 1];
          dp[i][j] = down >= right ? down : right;
        }
      }
    }

    final raw = <InlineDiffSegment>[];
    var i = 0;
    var j = 0;
    while (i < n && j < m) {
      if (a[i] == b[j]) {
        raw.add(
          InlineDiffSegment(
            type: InlineDiffSegmentType.unchanged,
            text: a[i],
          ),
        );
        i++;
        j++;
      } else if (dp[i + 1][j] >= dp[i][j + 1]) {
        raw.add(
          InlineDiffSegment(
            type: InlineDiffSegmentType.deleted,
            text: a[i],
          ),
        );
        i++;
      } else {
        raw.add(
          InlineDiffSegment(
            type: InlineDiffSegmentType.added,
            text: b[j],
          ),
        );
        j++;
      }
    }
    while (i < n) {
      raw.add(
        InlineDiffSegment(type: InlineDiffSegmentType.deleted, text: a[i]),
      );
      i++;
    }
    while (j < m) {
      raw.add(
        InlineDiffSegment(type: InlineDiffSegmentType.added, text: b[j]),
      );
      j++;
    }

    // Coalesce adjacent segments of the same diff type for crisp RichText spans.
    final merged = <InlineDiffSegment>[];
    for (final seg in raw) {
      if (merged.isNotEmpty && merged.last.type == seg.type) {
        final prev = merged.removeLast();
        merged.add(
          InlineDiffSegment(
            type: seg.type,
            text: '${prev.text}${seg.text}',
          ),
        );
      } else {
        merged.add(seg);
      }
    }
    return List<InlineDiffSegment>.unmodifiable(merged);
  }

  static InlineDiffProposal buildProposal({
    required String originalText,
    required String proposedText,
    String title = 'AI修正提案のインライン差分',
  }) {
    final segments = computeDiff(originalText, proposedText);
    var added = 0;
    var deleted = 0;
    for (final seg in segments) {
      if (seg.type == InlineDiffSegmentType.added) added++;
      if (seg.type == InlineDiffSegmentType.deleted) deleted++;
    }
    return InlineDiffProposal(
      title: title,
      originalText: originalText,
      proposedText: proposedText,
      segments: segments,
      addedSegmentCount: added,
      deletedSegmentCount: deleted,
    );
  }

  /// Parses structured change proposals inside AI markdown replies:
  /// 1) `<<<ORIGINAL\n...\n===\n...\n>>>PROPOSED`
  /// 2) Fenced ```` ```diff ... ``` ```` unified diff block (`-` / `+` lines)
  static InlineDiffProposal? extractProposal(String markdown) {
    final markerMatch = RegExp(
      r'<<<ORIGINAL\r?\n(.*?)\r?\n===\r?\n(.*?)\r?\n>>>PROPOSED',
      dotAll: true,
    ).firstMatch(markdown);
    if (markerMatch != null) {
      final original = markerMatch.group(1) ?? '';
      final proposed = markerMatch.group(2) ?? '';
      return buildProposal(originalText: original, proposedText: proposed);
    }

    final diffFenceMatch = RegExp(
      r'```diff\r?\n(.*?)```',
      dotAll: true,
    ).firstMatch(markdown);
    if (diffFenceMatch != null) {
      final block = diffFenceMatch.group(1) ?? '';
      final origLines = <String>[];
      final propLines = <String>[];
      for (final rawLine in block.split(RegExp(r'\r?\n'))) {
        if (rawLine.startsWith('---') ||
            rawLine.startsWith('+++') ||
            rawLine.startsWith('@@')) {
          continue;
        }
        if (rawLine.startsWith('-')) {
          origLines.add(rawLine.substring(1));
        } else if (rawLine.startsWith('+')) {
          propLines.add(rawLine.substring(1));
        } else if (rawLine.startsWith(' ')) {
          final ctx = rawLine.substring(1);
          origLines.add(ctx);
          propLines.add(ctx);
        } else if (rawLine.isNotEmpty) {
          origLines.add(rawLine);
          propLines.add(rawLine);
        }
      }
      if (origLines.isNotEmpty || propLines.isNotEmpty) {
        return buildProposal(
          originalText: origLines.join('\n'),
          proposedText: propLines.join('\n'),
        );
      }
    }
    return null;
  }
}
