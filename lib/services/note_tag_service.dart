class NoteTagService {
  const NoteTagService._();

  /// Supabase の text[]、ローカル下書き、UI 入力を同じ形にそろえる。
  ///
  /// Evernote 由来の表記を失わないよう、大文字小文字やタグ内の空白は変更せず、
  /// 前後空白の除去と大文字小文字を無視した重複排除だけを行う。
  static List<String> normalize(dynamic rawTags) {
    final Iterable<dynamic> candidates;
    if (rawTags == null) {
      return const <String>[];
    } else if (rawTags is Iterable) {
      candidates = rawTags;
    } else {
      candidates = <dynamic>[rawTags];
    }

    final normalized = <String>[];
    final seen = <String>{};
    for (final candidate in candidates) {
      if (candidate == null) continue;
      final tag = candidate.toString().trim();
      if (tag.isEmpty) continue;
      if (seen.add(tag.toLowerCase())) {
        normalized.add(tag);
      }
    }
    return List<String>.unmodifiable(normalized);
  }

  static bool equals(dynamic left, dynamic right) {
    final a = normalize(left);
    final b = normalize(right);
    if (a.length != b.length) return false;
    for (var index = 0; index < a.length; index++) {
      if (a[index] != b[index]) return false;
    }
    return true;
  }

  static bool containsTag(dynamic rawTags, String selectedTag) {
    final target = selectedTag.trim().toLowerCase();
    if (target.isEmpty) return true;
    return normalize(rawTags).any((tag) => tag.toLowerCase() == target);
  }

  static bool containsSearch(dynamic rawTags, String query) {
    final target = query.trim().toLowerCase();
    if (target.isEmpty) return true;
    return normalize(rawTags).any((tag) => tag.toLowerCase().contains(target));
  }

  static List<String> collectFromRows(Iterable<Map<String, dynamic>> rows) {
    final byFoldedName = <String, String>{};
    for (final row in rows) {
      for (final tag in normalize(row['tags'])) {
        byFoldedName.putIfAbsent(tag.toLowerCase(), () => tag);
      }
    }
    final tags = byFoldedName.values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return List<String>.unmodifiable(tags);
  }
}
