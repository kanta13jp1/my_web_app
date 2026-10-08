class PythonBlockReview {
  final List<String> blocks;
  final List<int> candidates;
  const PythonBlockReview(this.blocks, this.candidates);

  static PythonBlockReview inspect(String response, String names) {
    final required =
        names.split(RegExp(r'[,\s]+')).where((v) => v.isNotEmpty).toList();
    if (required.isEmpty ||
        required.any((v) => !RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(v))) {
      throw const FormatException('必要な関数名を半角英数字と区切りのカンマで入力してください。');
    }
    final blocks = RegExp(r'^```(?:python|py)[ \t]*\r?\n([\s\S]*?)^```[ \t]*$',
            multiLine: true)
        .allMatches(response)
        .map((m) => m.group(1)!)
        .toList();
    final candidates = <int>[];
    for (var i = 0; i < blocks.length; i++) {
      if (required.every((name) =>
          RegExp('^def[ \\t]+${RegExp.escape(name)}[ \t]*\\(', multiLine: true)
              .hasMatch(blocks[i]))) {
        candidates.add(i);
      }
    }
    return PythonBlockReview(blocks, candidates);
  }
}
