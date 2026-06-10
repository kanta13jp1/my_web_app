class NoteSearchRanker {
  const NoteSearchRanker._();

  static bool matches(Map<String, dynamic> note, String query) {
    return score(note, query) >= 0.5;
  }

  static double score(Map<String, dynamic> note, String query) {
    final rawQuery = query.trim().toLowerCase();
    if (rawQuery.isEmpty) return 1;

    final title = (note['title'] as String? ?? '').trim();
    final content = (note['content'] as String? ?? '').trim();
    final tags = _tags(note).join(' ');
    final haystack = '$title $tags $content'.trim().toLowerCase();
    if (haystack.isEmpty) return 0;
    if (haystack.contains(rawQuery)) return 1;

    final queryTokens = _tokens(rawQuery);
    final haystackTokens = _tokens(haystack);
    if (queryTokens.isEmpty || haystackTokens.isEmpty) {
      return _dice(rawQuery, haystack);
    }

    var tokenHits = 0;
    var fuzzyTotal = 0.0;
    for (final queryToken in queryTokens) {
      var best = 0.0;
      for (final candidate in haystackTokens) {
        final canUseSubstringMatch =
            queryToken.length >= 3 && candidate.length >= 3;
        if (canUseSubstringMatch &&
            (candidate.contains(queryToken) ||
                queryToken.contains(candidate))) {
          best = 1;
          break;
        }
        final similarity = _dice(queryToken, candidate);
        if (similarity > best) best = similarity;
      }
      if (best >= 0.58) tokenHits += 1;
      fuzzyTotal += best;
    }

    final tokenCoverage = tokenHits / queryTokens.length;
    final fuzzyAverage = fuzzyTotal / queryTokens.length;
    return (tokenCoverage * 0.62) + (fuzzyAverage * 0.38);
  }

  static List<String> _tags(Map<String, dynamic> note) {
    final raw = note['tags'];
    if (raw is List) {
      return raw.map((item) => item.toString()).where((item) {
        return item.trim().isNotEmpty;
      }).toList(growable: false);
    }
    return const <String>[];
  }

  static List<String> _tokens(String value) {
    return value
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .map((token) => token.trim())
        .where((token) => token.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  static double _dice(String a, String b) {
    final left = _bigrams(a);
    final right = _bigrams(b);
    if (left.isEmpty || right.isEmpty) return a == b ? 1 : 0;

    final rightCounts = <String, int>{};
    for (final item in right) {
      rightCounts[item] = (rightCounts[item] ?? 0) + 1;
    }

    var intersection = 0;
    for (final item in left) {
      final count = rightCounts[item] ?? 0;
      if (count <= 0) continue;
      intersection += 1;
      rightCounts[item] = count - 1;
    }

    return (2 * intersection) / (left.length + right.length);
  }

  static List<String> _bigrams(String value) {
    final normalized = value.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    if (normalized.length < 2) {
      return normalized.isEmpty ? const <String>[] : <String>[normalized];
    }
    return List<String>.generate(
      normalized.length - 1,
      (index) => normalized.substring(index, index + 2),
      growable: false,
    );
  }
}
