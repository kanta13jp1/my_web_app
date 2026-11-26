String stripBlogFrontmatter(String? raw) {
  final source = (raw ?? '').trimLeft();
  return source
      .replaceFirst(RegExp(r'^---(?:\r?\n)[\s\S]*?(?:\r?\n)---(?:\r?\n)?'), '')
      .trimLeft();
}

String extractBlogExcerpt(
  Map<String, dynamic> post, {
  int maxLength = 140,
}) {
  final explicit = stripBlogFrontmatter(post['excerpt']?.toString()).trim();
  if (explicit.isNotEmpty) return explicit;
  final content = stripBlogFrontmatter(post['content']?.toString()).trim();
  if (content.isEmpty) return '';
  final plain = content
      .replaceAll(RegExp(r'^#{1,6}\s.*$', multiLine: true), '')
      .replaceAll(RegExp(r'```[\s\S]*?```'), '')
      .replaceAll(RegExp(r'`([^`]*)`'), r'$1')
      .replaceAll(RegExp(r'\[([^\]]*)\]\([^)]*\)'), r'$1')
      .replaceAll(RegExp(r'[*_~>#-]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (plain.length <= maxLength) return plain;
  return '${plain.substring(0, maxLength)}…';
}

String formatBlogPlatformLabel(String platform) {
  final normalized = platform.trim().toLowerCase();
  return switch (normalized) {
    'app' => '公式ブログ',
    'qiita' => 'Qiita',
    'devto' => 'dev.to',
    'zenn' => 'Zenn',
    'hatena' => 'はてな',
    'note' => 'note',
    '' => '',
    _ => normalized.substring(0, 1).toUpperCase() + normalized.substring(1),
  };
}
