class AiUniversityCuratedVideo {
  const AiUniversityCuratedVideo({
    required this.id,
    required this.title,
    required this.duration,
    required this.description,
    required this.sourceUrl,
    this.youtubeVideoId,
  });

  final String id;
  final String title;
  final String duration;
  final String description;
  final String sourceUrl;
  final String? youtubeVideoId;
}

/// Public AI University lessons formerly mixed into the philosophy selector.
///
/// Descriptions intentionally avoid time-sensitive market and valuation claims
/// unless a dated first-party source can be presented alongside the lesson.
const List<AiUniversityCuratedVideo> aiUniversityCuratedVideos =
    <AiUniversityCuratedVideo>[
  AiUniversityCuratedVideo(
    id: 'anthropic-claude-apps',
    title: 'Anthropic Claude Apps 解説',
    duration: '7:10',
    description: 'MCPを使った外部サービス連携と、対話型AIアプリの設計観点を学ぶ公開済みレッスンです。',
    sourceUrl: 'https://youtu.be/Zclp_zK9cYM',
    youtubeVideoId: 'Zclp_zK9cYM',
  ),
  AiUniversityCuratedVideo(
    id: 'google-gemini-life',
    title: 'Google Geminiで暮らしを整える8つのコツ',
    duration: '6:27',
    description: 'Googleの各サービスを横断して日常の情報を整理する手順を学ぶ公開済みレッスンです。',
    sourceUrl: 'https://youtu.be/di5SbHouAVY',
    youtubeVideoId: 'di5SbHouAVY',
  ),
  AiUniversityCuratedVideo(
    id: 'nomic-aec',
    title: 'Nomic Platform — 建設・設計業界特化AI',
    duration: '8:17',
    description: '建設・設計業務の文書検索と情報整理を題材に、業界特化AIの考え方を学ぶ公開済みレッスンです。',
    sourceUrl: 'https://youtu.be/shdsy9qqcNM',
    youtubeVideoId: 'shdsy9qqcNM',
  ),
  AiUniversityCuratedVideo(
    id: 'multi-agent-convergence',
    title: 'AIのパラダイムシフト — Multi-Agent Convergence',
    duration: '9:19',
    description: '複数AIエージェントが協調する設計パターンを学ぶ、AI生成の公開教材です。',
    sourceUrl: '/assets/videos/multi-agent-convergence.mp4',
  ),
];