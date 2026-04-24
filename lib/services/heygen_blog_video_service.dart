class HeyGenBlogVideoScene {
  const HeyGenBlogVideoScene({
    required this.label,
    required this.narration,
    required this.visualDirection,
    required this.caption,
  });

  final String label;
  final String narration;
  final String visualDirection;
  final String caption;
}

class HeyGenBlogVideoPlan {
  const HeyGenBlogVideoPlan({
    required this.title,
    required this.sourceSummary,
    required this.productionBrief,
    required this.scenes,
    required this.shortPost,
    required this.reuseChecklist,
  });

  final String title;
  final String sourceSummary;
  final String productionBrief;
  final List<HeyGenBlogVideoScene> scenes;
  final String shortPost;
  final List<String> reuseChecklist;

  String get clipboardText => [
        title,
        '',
        'Source summary:',
        sourceSummary,
        '',
        'HeyGen production brief:',
        productionBrief,
        '',
        'Scenes:',
        ...scenes.map(
          (scene) => [
            '- ${scene.label}',
            '  Narration: ${scene.narration}',
            '  Visual: ${scene.visualDirection}',
            '  Caption: ${scene.caption}',
          ].join('\n'),
        ),
        '',
        'SNS post:',
        shortPost,
        '',
        'Reuse checklist:',
        ...reuseChecklist.map((item) => '- $item'),
      ].join('\n');
}

class HeyGenBlogVideoService {
  static HeyGenBlogVideoPlan buildPlan({
    required String title,
    String? excerpt,
    String? draftPath,
    String? sourceUrl,
    List<String> targetPlatforms = const [],
  }) {
    final cleanTitle = _clean(title, fallback: 'ブログ記事');
    final summary = _sourceSummary(
      title: cleanTitle,
      excerpt: excerpt,
      draftPath: draftPath,
      sourceUrl: sourceUrl,
      targetPlatforms: targetPlatforms,
    );
    final platformLine = targetPlatforms.isEmpty
        ? 'X / YouTube Shorts / LinkedIn'
        : targetPlatforms.join(' / ');
    final corePoint = _firstMeaningfulLine(excerpt, fallback: cleanTitle);

    return HeyGenBlogVideoPlan(
      title: 'HeyGenブログ動画化: $cleanTitle',
      sourceSummary: summary,
      productionBrief: 'HeyGen Avatar Vで、ブログ記事を60秒の解説動画に変換する。'
          '講師アバターは落ち着いた口調、画面は記事タイトル・要点・CTAの3層で構成。'
          '配信先は $platformLine。SNS再利用を前提に1文を短く区切る。',
      scenes: [
        HeyGenBlogVideoScene(
          label: 'Hook',
          narration: 'この記事では「$cleanTitle」の要点を、60秒で整理します。',
          visualDirection: '記事タイトルを大きく表示し、講師アバターを右側に配置。',
          caption: cleanTitle,
        ),
        const HeyGenBlogVideoScene(
          label: 'Problem',
          narration: '読むだけで終わらせず、実装や改善の判断に使える形へ変えます。',
          visualDirection: 'Before: 長い記事 / After: 要点カード の比較。',
          caption: '読む -> 判断 -> 実践',
        ),
        HeyGenBlogVideoScene(
          label: 'Key point',
          narration: corePoint,
          visualDirection: 'キーポイントを3つのカードに分けて表示。',
          caption: _captionFrom(corePoint),
        ),
        const HeyGenBlogVideoScene(
          label: 'Action',
          narration: '次にやることは一つだけです。記事の要点を、今日の作業に一つ適用します。',
          visualDirection: 'チェックリストUI。1つだけチェックが入る演出。',
          caption: '今日の実践を1つ決める',
        ),
        HeyGenBlogVideoScene(
          label: 'CTA',
          narration: '詳しい手順はブログ本文で確認してください。保存して、あとで実践に戻りましょう。',
          visualDirection: '記事URLまたは下書きパスを表示し、SNS保存を促す。',
          caption: sourceUrl?.trim().isNotEmpty == true
              ? sourceUrl!.trim()
              : draftPath?.trim().isNotEmpty == true
                  ? draftPath!.trim()
                  : 'ブログ本文へ',
        ),
      ],
      shortPost: _shortPost(cleanTitle, sourceUrl),
      reuseChecklist: [
        'X向け: Hook + Key point + CTA の3文に圧縮',
        'YouTube Shorts向け: 冒頭2秒に記事タイトルを固定表示',
        'LinkedIn向け: ProblemとActionをやや丁寧に説明',
        '多言語化: 英語版は専門用語を残し、1文を短くする',
      ],
    );
  }

  static String _sourceSummary({
    required String title,
    String? excerpt,
    String? draftPath,
    String? sourceUrl,
    required List<String> targetPlatforms,
  }) {
    final parts = <String>[
      'title=$title',
      if (excerpt != null && excerpt.trim().isNotEmpty)
        'excerpt=${_clip(excerpt.trim(), 180)}',
      if (draftPath != null && draftPath.trim().isNotEmpty) 'draft=$draftPath',
      if (sourceUrl != null && sourceUrl.trim().isNotEmpty) 'url=$sourceUrl',
      if (targetPlatforms.isNotEmpty) 'platforms=${targetPlatforms.join(', ')}',
    ];
    return parts.join(' / ');
  }

  static String _firstMeaningfulLine(String? text, {required String fallback}) {
    final normalized = (text ?? '')
        .replaceAll(RegExp(r'[#*_>`\[\]()]'), ' ')
        .split(RegExp(r'[\r\n。.!?]'))
        .map((line) => line.trim())
        .where((line) => line.length >= 12)
        .toList();
    if (normalized.isEmpty) {
      return 'この記事の中心は「$fallback」です。背景、実装、次の改善を順番に確認します。';
    }
    return _clip(normalized.first, 110);
  }

  static String _captionFrom(String text) {
    final clipped = _clip(text.replaceAll(RegExp(r'\s+'), ' '), 34);
    return clipped.isEmpty ? '要点を短く実践へ' : clipped;
  }

  static String _shortPost(String title, String? sourceUrl) {
    final link = sourceUrl?.trim();
    return [
      'ブログ記事を60秒のHeyGen解説動画に変換します。',
      'テーマ: $title',
      if (link != null && link.isNotEmpty) link,
      '#HeyGen #ブログ動画化 #自分株式会社',
    ].join('\n');
  }

  static String _clean(String value, {required String fallback}) {
    final cleaned = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    return cleaned.isEmpty ? fallback : _clip(cleaned, 80);
  }

  static String _clip(String text, int maxChars) {
    if (text.length <= maxChars) return text;
    return '${text.substring(0, maxChars - 3)}...';
  }
}
