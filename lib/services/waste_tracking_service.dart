class WasteCategoryDefinition {
  const WasteCategoryDefinition({
    required this.label,
    required this.keywords,
  });

  final String label;
  final List<String> keywords;
}

class WasteTrackingService {
  const WasteTrackingService._();

  static const List<WasteCategoryDefinition> categories =
      <WasteCategoryDefinition>[
        WasteCategoryDefinition(
          label: '飲酒',
          keywords: <String>[
            '飲酒',
            '酒',
            'ビール',
            'ハイボール',
            'チューハイ',
            '焼酎',
            'ワイン',
            '日本酒',
          ],
        ),
        WasteCategoryDefinition(
          label: '喫煙',
          keywords: <String>[
            '喫煙',
            'たばこ',
            'タバコ',
            '煙草',
            'iqos',
            'アイコス',
          ],
        ),
        WasteCategoryDefinition(
          label: 'キャバクラ',
          keywords: <String>['キャバクラ'],
        ),
        WasteCategoryDefinition(
          label: 'スナック',
          keywords: <String>['スナック'],
        ),
        WasteCategoryDefinition(
          label: 'ガールズバー',
          keywords: <String>['ガールズバー', 'girls bar'],
        ),
        WasteCategoryDefinition(
          label: '風俗',
          keywords: <String>['風俗'],
        ),
        WasteCategoryDefinition(
          label: 'デリヘル',
          keywords: <String>['デリヘル'],
        ),
        WasteCategoryDefinition(
          label: 'ピンサロ',
          keywords: <String>['ピンサロ'],
        ),
        WasteCategoryDefinition(
          label: 'セクキャバ',
          keywords: <String>['セクキャバ'],
        ),
        WasteCategoryDefinition(
          label: 'ゲーム',
          keywords: <String>['ゲーム', '課金', 'steam', 'switch', 'ps5'],
        ),
        WasteCategoryDefinition(
          label: 'ギャンブル',
          keywords: <String>[
            'ギャンブル',
            'パチンコ',
            'スロット',
            '競馬',
            '競艇',
            '競輪',
            'カジノ',
          ],
        ),
      ];

  static const String markerPrefix = '[浪費:';

  static List<String> get categoryLabels =>
      categories.map((category) => category.label).toList(growable: false);

  static String attachWasteCategory(
    String description,
    String? category,
  ) {
    final base = stripWasteMarker(description).trim();
    final normalizedCategory = normalizeCategory(category);
    if (normalizedCategory == null) {
      return base;
    }
    if (base.isEmpty) {
      return '$markerPrefix$normalizedCategory]';
    }
    return '$base $markerPrefix$normalizedCategory]';
  }

  static String stripWasteMarker(String description) {
    return description
        .replaceAll(RegExp(r'\s*\[浪費:[^\]]+\]\s*$'), '')
        .trim();
  }

  static String? extractWasteCategory(String description) {
    final markerMatch =
        RegExp(r'\[浪費:([^\]]+)\]\s*$').firstMatch(description.trim());
    if (markerMatch != null) {
      return normalizeCategory(markerMatch.group(1));
    }

    final base = stripWasteMarker(description).toLowerCase();
    for (final category in categories) {
      for (final keyword in category.keywords) {
        if (base.contains(keyword.toLowerCase())) {
          return category.label;
        }
      }
    }
    return null;
  }

  static String? normalizeCategory(String? category) {
    final normalized = category?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    for (final defined in categories) {
      if (defined.label == normalized) {
        return defined.label;
      }
    }
    return null;
  }
}
