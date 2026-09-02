class HomeFeatureLabelFormatter {
  const HomeFeatureLabelFormatter._();

  static const Map<String, String> _localizedLabels = {
    'memory-search': 'メモ横断検索',
    'daily-judgment': '今日の判断',
    'ai-assistance-chat': 'AI相談',
    'ai-summarizer': 'AI要約',
    'home-insights': 'ふりかえり',
    'site-guide-ai': 'サイト案内AI',
    'release-notes': '更新情報',
    'ai-university': 'AI大学',
  };

  static String resolve({
    required String route,
    String? label,
    String? featureLabel,
    String? title,
  }) {
    final candidates = [label, featureLabel, title];
    for (final candidate in candidates) {
      final text = candidate?.trim() ?? '';
      if (text.isEmpty || _isLikelyMojibake(text)) continue;

      final localized = _localizedLabels[_normalizeIdentifier(text)];
      if (localized != null) return localized;
      if (!_looksLikeInternalIdentifier(text)) return text;
    }

    return _localizedLabels[_normalizeIdentifier(route)] ?? 'おすすめ機能';
  }

  static String _normalizeIdentifier(String value) {
    return value
        .trim()
        .replaceFirst(RegExp(r'^/+'), '')
        .toLowerCase()
        .replaceAll(RegExp(r'[_\s]+'), '-')
        .replaceAll(RegExp(r'-+'), '-');
  }

  static bool _looksLikeInternalIdentifier(String value) {
    return RegExp(
      r'^[a-z0-9]+(?:[_\-\s][a-z0-9]+)+$',
      caseSensitive: false,
    ).hasMatch(value.trim());
  }

  static bool _isLikelyMojibake(String text) {
    return text.contains('縺') ||
        text.contains('繝') ||
        text.contains('譁') ||
        text.contains('蟄') ||
        text.contains('螟');
  }
}
