class WikiLinkRef {
  final String targetTitle;
  final String? alias;

  const WikiLinkRef({
    required this.targetTitle,
    this.alias,
  });

  String get displayLabel {
    final String? trimmedAlias = alias?.trim();
    if (trimmedAlias != null && trimmedAlias.isNotEmpty) {
      return trimmedAlias;
    }
    return targetTitle;
  }
}

class NoteSummary {
  final String id;
  final String title;
  final String content;
  final DateTime? updatedAt;

  const NoteSummary({
    required this.id,
    required this.title,
    required this.content,
    this.updatedAt,
  });
}

class NoteBacklink {
  final String sourceNoteId;
  final String sourceTitle;
  final String snippet;

  const NoteBacklink({
    required this.sourceNoteId,
    required this.sourceTitle,
    required this.snippet,
  });
}

/// Pure service for Notion/Obsidian-style `[[Page Link]]` extraction, resolution,
/// backlink discovery, and clickable Markdown conversion.
class NoteWikiLinkService {
  NoteWikiLinkService._();

  static const String wikiLinkScheme = 'wikilink://';
  static final RegExp _wikiLinkPattern = RegExp(r'\[\[([^\]\n]+?)\]\]');

  static String normalizeTitle(String title) {
    return title.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  }

  static List<WikiLinkRef> extractWikiLinks(String markdown) {
    final String sanitized = _stripCodeSpans(markdown);
    final Set<String> seenTargets = <String>{};
    final List<WikiLinkRef> out = <WikiLinkRef>[];

    for (final RegExpMatch match in _wikiLinkPattern.allMatches(sanitized)) {
      final WikiLinkRef? parsed = _parseInnerLink(match.group(1) ?? '');
      if (parsed == null) continue;
      final String key = normalizeTitle(parsed.targetTitle);
      if (key.isEmpty || !seenTargets.add(key)) continue;
      out.add(parsed);
    }
    return out;
  }

  static NoteSummary? resolveLink(
    String targetTitle,
    List<NoteSummary> candidates, {
    String? excludeNoteId,
  }) {
    final String normalizedTarget = normalizeTitle(targetTitle);
    if (normalizedTarget.isEmpty) {
      return null;
    }
    for (final NoteSummary candidate in candidates) {
      if (excludeNoteId != null && candidate.id == excludeNoteId) {
        continue;
      }
      if (normalizeTitle(candidate.title) == normalizedTarget) {
        return candidate;
      }
    }
    return null;
  }

  static List<NoteBacklink> findBacklinks({
    required String currentNoteTitle,
    required List<NoteSummary> allNotes,
    String? currentNoteId,
  }) {
    final String normalizedCurrent = normalizeTitle(currentNoteTitle);
    if (normalizedCurrent.isEmpty) {
      return const <NoteBacklink>[];
    }

    final List<NoteBacklink> out = <NoteBacklink>[];
    for (final NoteSummary note in allNotes) {
      if (currentNoteId != null && note.id == currentNoteId) {
        continue;
      }
      final List<WikiLinkRef> links = extractWikiLinks(note.content);
      final bool matches = links.any(
        (WikiLinkRef link) =>
            normalizeTitle(link.targetTitle) == normalizedCurrent,
      );
      if (!matches) continue;

      out.add(
        NoteBacklink(
          sourceNoteId: note.id,
          sourceTitle: note.title.trim().isEmpty ? '無題のノート' : note.title.trim(),
          snippet: _extractMatchingSnippet(note.content, normalizedCurrent),
        ),
      );
    }
    return out;
  }

  static String replaceWikiLinksWithMarkdownLinks(String markdown) {
    final String normalized = markdown.replaceAll('\r\n', '\n');
    final List<String> lines = normalized.split('\n');
    final List<String> outLines = <String>[];
    bool inFence = false;

    for (final String line in lines) {
      if (line.trimLeft().startsWith('```')) {
        inFence = !inFence;
        outLines.add(line);
        continue;
      }
      if (inFence) {
        outLines.add(line);
        continue;
      }
      outLines.add(_replaceOutsideInlineCode(line));
    }

    return outLines.join('\n');
  }

  static String _replaceOutsideInlineCode(String line) {
    final StringBuffer out = StringBuffer();
    final RegExp inlineCode = RegExp(r'`[^`]*`');
    int lastEnd = 0;

    for (final RegExpMatch codeMatch in inlineCode.allMatches(line)) {
      if (codeMatch.start > lastEnd) {
        out.write(_replaceSegment(line.substring(lastEnd, codeMatch.start)));
      }
      out.write(codeMatch.group(0));
      lastEnd = codeMatch.end;
    }
    if (lastEnd < line.length) {
      out.write(_replaceSegment(line.substring(lastEnd)));
    }
    return out.toString();
  }

  static String _replaceSegment(String segment) {
    return segment.replaceAllMapped(_wikiLinkPattern, (Match match) {
      final WikiLinkRef? parsed = _parseInnerLink(match.group(1) ?? '');
      if (parsed == null) {
        return match.group(0) ?? '';
      }
      final String encodedTarget = Uri.encodeComponent(parsed.targetTitle);
      return '[${parsed.displayLabel}]($wikiLinkScheme$encodedTarget)';
    });
  }

  static WikiLinkRef? _parseInnerLink(String rawInner) {
    final int pipeIdx = rawInner.indexOf('|');
    if (pipeIdx >= 0) {
      final String target = rawInner.substring(0, pipeIdx).trim();
      final String alias = rawInner.substring(pipeIdx + 1).trim();
      if (target.isEmpty) return null;
      return WikiLinkRef(
        targetTitle: target,
        alias: alias.isEmpty ? null : alias,
      );
    }
    final String target = rawInner.trim();
    if (target.isEmpty) return null;
    return WikiLinkRef(targetTitle: target);
  }

  static String _stripCodeSpans(String markdown) {
    final String normalized = markdown.replaceAll('\r\n', '\n');
    final List<String> lines = normalized.split('\n');
    final List<String> nonCodeLines = <String>[];
    bool inFence = false;

    for (final String line in lines) {
      if (line.trimLeft().startsWith('```')) {
        inFence = !inFence;
        continue;
      }
      if (!inFence) {
        nonCodeLines.add(line.replaceAll(RegExp(r'`[^`]*`'), ' '));
      }
    }
    return nonCodeLines.join('\n');
  }

  static String _extractMatchingSnippet(
    String content,
    String normalizedTarget,
  ) {
    for (final String rawLine in content.replaceAll('\r\n', '\n').split('\n')) {
      final String trimmed = rawLine.trim();
      if (trimmed.isEmpty) continue;
      final List<WikiLinkRef> lineLinks = extractWikiLinks(trimmed);
      if (lineLinks.any(
        (WikiLinkRef link) =>
            normalizeTitle(link.targetTitle) == normalizedTarget,
      )) {
        return trimmed.length > 96
            ? '${trimmed.substring(0, 95)}…'
            : trimmed;
      }
    }
    final String fallback = content.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (fallback.length > 96) {
      return '${fallback.substring(0, 95)}…';
    }
    return fallback;
  }
}
