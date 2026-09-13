/// デザイン適合データ — docs/DESIGN.md の7項目でスコアリング
///
/// compliance の7要素 (順番固定):
///   [0] darkBg      : 適切なダーク背景 (#0A0A0A〜#2A2A2A)
///   [1] orangeAccent: メインCTAにオレンジ (#FF6B35) を使用
///   [2] jaTypo      : Noto Sans JP + line-height 1.7
///   [3] spacing     : 4px グリッドスペーシング
///   [4] cardStyle   : DESIGN.md カード規格 (radius 12px + shadow)
///   [5] withValues  : withOpacity() 不使用 → withValues(alpha:) 統一
///   [6] a11y        : IconButton に tooltip / Semantics ラベル付き
///
/// mcpToolUsed: 設計に使用したツールのセット (null = 未使用 / 未記録)
///   'figma'        : Figma MCP を使用してデザインを参照
///   'aidesigner'   : AIDesigner MCP でUI案を生成
///   'designskills' : Design Skills エージェントでコード生成
///   'designmd'     : DESIGN.md のみ参照して手動実装

library;

enum DesignCategory {
  marketing,
  home,
  notes,
  ai,
  business,
  personal,
  creative,
  admin,
}

const Map<DesignCategory, String> categoryLabel = {
  DesignCategory.marketing: 'マーケティング',
  DesignCategory.home: 'ホーム・ダッシュボード',
  DesignCategory.notes: 'ノート・知識',
  DesignCategory.ai: 'AI機能',
  DesignCategory.business: 'ビジネス・成長',
  DesignCategory.personal: '個人・健康',
  DesignCategory.creative: 'クリエイティブ',
  DesignCategory.admin: '管理・開発',
};

class PageComplianceRecord {
  final String route;
  final String name;
  final DesignCategory category;

  /// null = 未審査; List<bool> length=7 = 審査済み
  final List<bool>? compliance;
  final String? auditDate; // 'YYYY-MM-DD'
  final String? notes;

  /// 設計に使用したツール (null = 未記録, 空リスト = ツール未使用)
  /// 値例: ['figma', 'aidesigner', 'designskills', 'designmd']
  final List<String>? mcpToolUsed;

  const PageComplianceRecord({
    required this.route,
    required this.name,
    required this.category,
    this.compliance,
    this.auditDate,
    this.notes,
    this.mcpToolUsed,
  });

  bool get isAudited => compliance != null;

  double get score {
    if (compliance == null) return 0.0;
    final c = compliance!;
    return c.where((b) => b).length / c.length;
  }

  int get scorePercent => (score * 100).round();
}

// ───────────────────────────────────────────────────────
// 全画面データ
// ───────────────────────────────────────────────────────

const List<PageComplianceRecord> kDesignComplianceData = [
  // ─── マーケティング ──────────────────────────────────
  PageComplianceRecord(
    route: '/landing',
    name: 'ランディングページ',
    category: DesignCategory.marketing,
    compliance: [true, true, true, false, true, true, true],
    auditDate: '2026-04-05',
    notes: '一部セクションでスペーシング要改善',
  ),
  PageComplianceRecord(
    route: '/enterprise',
    name: 'エンタープライズLP',
    category: DesignCategory.marketing,
    compliance: [true, true, true, true, true, true, false],
    auditDate: '2026-03-30',
  ),
  PageComplianceRecord(
    route: '/feature-requests',
    name: '機能リクエスト',
    category: DesignCategory.marketing,
    compliance: [true, true, true, true, true, true, false],
    auditDate: '2026-03-25',
  ),
  PageComplianceRecord(
    route: '/referral',
    name: 'リファラルプログラム',
    category: DesignCategory.marketing,
    compliance: [true, true, true, false, true, true, false],
    auditDate: '2026-03-25',
  ),
  PageComplianceRecord(
    route: '/vs-notion',
    name: 'Notion 比較ページ',
    category: DesignCategory.marketing,
    compliance: [true, true, true, false, true, true, true],
    auditDate: '2026-03-26',
  ),
  PageComplianceRecord(
    route: '/vs-evernote',
    name: 'Evernote 比較ページ',
    category: DesignCategory.marketing,
    compliance: [true, true, true, false, true, true, true],
    auditDate: '2026-03-26',
  ),
  PageComplianceRecord(
    route: '/vs-moneyforward',
    name: 'MoneyForward 比較',
    category: DesignCategory.marketing,
    compliance: [true, true, true, false, true, true, true],
    auditDate: '2026-03-26',
  ),
  PageComplianceRecord(
    route: '/vs-slack',
    name: 'Slack 比較ページ',
    category: DesignCategory.marketing,
    compliance: [true, true, true, false, true, true, true],
    auditDate: '2026-03-26',
  ),
  PageComplianceRecord(
    route: '/vs-chatwork',
    name: 'Chatwork 比較',
    category: DesignCategory.marketing,
    compliance: [true, true, true, false, true, true, true],
    auditDate: '2026-03-26',
  ),
  PageComplianceRecord(
    route: '/vs-x',
    name: 'X (Twitter) 比較',
    category: DesignCategory.marketing,
    compliance: [true, true, true, false, true, true, true],
    auditDate: '2026-03-26',
  ),
  PageComplianceRecord(
    route: '/vs-amazon',
    name: 'Amazon 比較ページ',
    category: DesignCategory.marketing,
    compliance: [true, true, true, false, true, true, true],
    auditDate: '2026-03-26',
  ),
  PageComplianceRecord(
    route: '/vs-google',
    name: 'Google 比較ページ',
    category: DesignCategory.marketing,
    compliance: [true, true, true, false, true, true, true],
    auditDate: '2026-03-31',
  ),
  PageComplianceRecord(
    route: '/vs-discord',
    name: 'Discord 比較',
    category: DesignCategory.marketing,
    compliance: [true, true, true, false, true, true, true],
    auditDate: '2026-03-31',
  ),
  PageComplianceRecord(
    route: '/vs-line',
    name: 'LINE 比較ページ',
    category: DesignCategory.marketing,
    compliance: [true, true, true, false, true, true, true],
    auditDate: '2026-03-31',
  ),
  PageComplianceRecord(
    route: '/vs-github',
    name: 'GitHub 比較ページ',
    category: DesignCategory.marketing,
    compliance: [true, true, true, false, true, true, true],
    auditDate: '2026-03-31',
  ),
  // Not audited comparison pages
  PageComplianceRecord(
    route: '/vs-animaworks',
    name: 'Animaworks 比較',
    category: DesignCategory.marketing,
  ),
  PageComplianceRecord(
    route: '/vs-claude-code',
    name: 'Claude Code 比較',
    category: DesignCategory.marketing,
  ),
  PageComplianceRecord(
    route: '/vs-codex',
    name: 'Codex 比較',
    category: DesignCategory.marketing,
  ),
  PageComplianceRecord(
    route: '/vs-netkeiba',
    name: 'netkeiba 比較',
    category: DesignCategory.marketing,
  ),
  PageComplianceRecord(
    route: '/vs-openclaw',
    name: 'OpenClaw 比較',
    category: DesignCategory.marketing,
  ),
  PageComplianceRecord(
    route: '/vs-claude-cowork',
    name: 'Claude Cowork 比較',
    category: DesignCategory.marketing,
  ),
  PageComplianceRecord(
    route: '/vs-jobcan',
    name: 'ジョブカン 比較',
    category: DesignCategory.marketing,
  ),
  PageComplianceRecord(
    route: '/vs-microsoft',
    name: 'Microsoft 比較',
    category: DesignCategory.marketing,
  ),
  PageComplianceRecord(
    route: '/vs-facebook',
    name: 'Facebook 比較',
    category: DesignCategory.marketing,
  ),
  PageComplianceRecord(
    route: '/vs-liven',
    name: 'Liven 比較',
    category: DesignCategory.marketing,
  ),

  // ─── ホーム・ダッシュボード ────────────────────────────
  PageComplianceRecord(
    route: '/home',
    name: 'ホーム (メインハブ)',
    category: DesignCategory.home,
    compliance: [true, true, false, false, true, true, false],
    auditDate: '2026-04-06',
    notes: '6907行の大規模ファイル。タイポグラフィ・スペーシング要統一',
  ),
  PageComplianceRecord(
    route: '/home-insights',
    name: '成長・支援ダッシュボード',
    category: DesignCategory.home,
    compliance: [true, true, true, false, true, true, false],
    auditDate: '2026-03-28',
  ),
  PageComplianceRecord(
    route: '/work-menu',
    name: '業務メニュー',
    category: DesignCategory.home,
    compliance: [true, true, true, false, true, true, false],
    auditDate: '2026-03-28',
  ),
  PageComplianceRecord(
    route: '/admin',
    name: '管理者ダッシュボード',
    category: DesignCategory.home,
    compliance: [true, true, true, true, true, true, false],
    auditDate: '2026-03-26',
  ),
  PageComplianceRecord(
    route: '/ui-design-status',
    name: 'UIデザインステータス (本ページ)',
    category: DesignCategory.home,
    compliance: [true, true, true, true, true, true, true],
    auditDate: '2026-04-07',
    notes: 'DESIGN.md に完全準拠して新規作成',
  ),

  // ─── ノート・知識 ───────────────────────────────────
  PageComplianceRecord(
    route: '/note-editor',
    name: 'ノートエディタ',
    category: DesignCategory.notes,
    compliance: [true, true, false, false, true, true, false],
    auditDate: '2026-03-30',
    notes: 'タイポグラフィ・スペーシング要改善',
  ),
  PageComplianceRecord(
    route: '/public-memos',
    name: '公開メモ一覧',
    category: DesignCategory.notes,
    compliance: [true, true, true, false, true, true, false],
    auditDate: '2026-03-25',
  ),
  PageComplianceRecord(
    route: '/tech-blog-tracker',
    name: '技術ブログ管理',
    category: DesignCategory.notes,
    compliance: [true, true, true, false, true, true, false],
    auditDate: '2026-03-25',
  ),
  PageComplianceRecord(
    route: '/templates',
    name: 'テンプレート広場 (18種)',
    category: DesignCategory.notes,
    compliance: [true, true, true, true, true, true, false],
    auditDate: '2026-03-28',
  ),
  PageComplianceRecord(
    route: '/table-data',
    name: 'テーブルDB (Notion Database相当)',
    category: DesignCategory.notes,
    compliance: [true, true, true, true, true, true, false],
    auditDate: '2026-03-28',
  ),
  PageComplianceRecord(
    route: '/kanban',
    name: 'カンバンボード',
    category: DesignCategory.notes,
    compliance: [true, true, true, true, true, true, false],
    auditDate: '2026-03-28',
  ),
  PageComplianceRecord(
    route: '/mind-map',
    name: 'マインドマップ',
    category: DesignCategory.notes,
    compliance: [true, true, false, false, true, true, false],
    auditDate: '2026-03-25',
    notes: 'タイポグラフィ要改善',
  ),
  PageComplianceRecord(
    route: '/gantt-timeline',
    name: 'ガントチャート',
    category: DesignCategory.notes,
    compliance: [true, true, true, true, true, true, false],
    auditDate: '2026-04-02',
  ),
  PageComplianceRecord(
    route: '/wiki-database',
    name: 'Wikiデータベース',
    category: DesignCategory.notes,
  ),
  PageComplianceRecord(
    route: '/knowledge-base',
    name: 'ナレッジベース',
    category: DesignCategory.notes,
  ),
  PageComplianceRecord(
    route: '/note-comments',
    name: 'ノートコメント',
    category: DesignCategory.notes,
    compliance: [true, true, true, true, true, true, true],
    auditDate: '2026-03-30',
  ),

  // ─── AI機能 ─────────────────────────────────────────
  PageComplianceRecord(
    route: '/ai-search',
    name: 'AI全文検索',
    category: DesignCategory.ai,
    compliance: [true, true, false, false, true, true, false],
    auditDate: '2026-03-28',
    notes: 'タイポグラフィ・スペーシング要改善',
  ),
  PageComplianceRecord(
    route: '/morning-briefing',
    name: 'モーニングブリーフィング',
    category: DesignCategory.ai,
    compliance: [true, true, true, false, true, true, false],
    auditDate: '2026-03-25',
  ),
  PageComplianceRecord(
    route: '/embedding-lab',
    name: 'Embedding ラボ',
    category: DesignCategory.ai,
    compliance: [true, true, true, true, true, true, false],
    auditDate: '2026-03-31',
  ),
  PageComplianceRecord(
    route: '/ai-writing-assistant',
    name: 'AI文章・要約アシスタント',
    category: DesignCategory.ai,
    compliance: [true, true, false, false, true, true, false],
    auditDate: '2026-04-03',
  ),
  PageComplianceRecord(
    route: '/smart-inbox',
    name: 'スマート受信トレイ',
    category: DesignCategory.ai,
    compliance: [true, true, true, false, true, true, false],
    auditDate: '2026-04-03',
  ),
  PageComplianceRecord(
    route: '/ai-secretary',
    name: 'AI秘書',
    category: DesignCategory.ai,
    compliance: [true, false, false, false, true, true, false],
    auditDate: '2026-03-25',
  ),
  PageComplianceRecord(
    route: '/ai-image-generator',
    name: 'AI画像生成',
    category: DesignCategory.ai,
  ),
  PageComplianceRecord(
    route: '/ai-suggest-tags',
    name: 'AIタグ提案',
    category: DesignCategory.ai,
  ),
  PageComplianceRecord(
    route: '/workflow-automation',
    name: 'AIワークフロー自動化',
    category: DesignCategory.ai,
  ),
  PageComplianceRecord(
    route: '/semantic-search',
    name: 'セマンティック検索',
    category: DesignCategory.ai,
  ),

  // ─── ビジネス・成長 ──────────────────────────────────
  PageComplianceRecord(
    route: '/growth-mission',
    name: '成長ミッション',
    category: DesignCategory.business,
    compliance: [true, true, true, false, true, true, false],
    auditDate: '2026-03-25',
  ),
  PageComplianceRecord(
    route: '/growth-command-center',
    name: 'Growth 指揮センター',
    category: DesignCategory.business,
    compliance: [true, true, true, false, true, true, false],
    auditDate: '2026-03-25',
  ),
  PageComplianceRecord(
    route: '/team-workspace',
    name: 'チームワークスペース',
    category: DesignCategory.business,
    compliance: [true, true, true, true, true, true, false],
    auditDate: '2026-03-30',
  ),
  PageComplianceRecord(
    route: '/local-election-700',
    name: '統一地方選 700人目標',
    category: DesignCategory.business,
    compliance: [true, true, true, false, true, true, false],
    auditDate: '2026-03-31',
  ),
  PageComplianceRecord(
    route: '/election-strategy',
    name: '選挙戦略ページ',
    category: DesignCategory.business,
    compliance: [true, true, true, false, true, true, false],
    auditDate: '2026-03-25',
  ),
  PageComplianceRecord(
    route: '/asset-management',
    name: '資産管理',
    category: DesignCategory.business,
    compliance: [true, true, false, false, true, true, false],
    auditDate: '2026-03-25',
    notes: 'タイポグラフィ要改善',
  ),
  PageComplianceRecord(
    route: '/cfo-office',
    name: 'CFO室',
    category: DesignCategory.business,
    compliance: [true, true, false, false, true, true, false],
    auditDate: '2026-03-25',
  ),
  PageComplianceRecord(
    route: '/financial-report',
    name: '財務レポート',
    category: DesignCategory.business,
    compliance: [true, true, false, false, true, true, false],
    auditDate: '2026-03-25',
  ),
  PageComplianceRecord(
    route: '/growth-achievement-summary',
    name: '成長実績サマリー',
    category: DesignCategory.business,
    compliance: [true, true, true, false, true, true, false],
    auditDate: '2026-03-25',
  ),
  PageComplianceRecord(
    route: '/growth-weekly-digest',
    name: '週次グロースダイジェスト',
    category: DesignCategory.business,
    compliance: [true, true, true, false, true, true, false],
    auditDate: '2026-03-25',
  ),
  PageComplianceRecord(
    route: '/crm-pipeline',
    name: 'CRM営業パイプライン',
    category: DesignCategory.business,
  ),
  PageComplianceRecord(
    route: '/gantt-timeline',
    name: 'ガントチャート',
    category: DesignCategory.business,
    compliance: [true, true, true, true, true, true, false],
    auditDate: '2026-04-02',
  ),

  // ─── 個人・健康 ──────────────────────────────────────
  PageComplianceRecord(
    route: '/daily-habits',
    name: '毎日の習慣',
    category: DesignCategory.personal,
    compliance: [true, false, false, false, true, true, false],
    auditDate: '2026-03-20',
    notes: 'カラートークン・タイポグラフィ要全面改善',
  ),
  PageComplianceRecord(
    route: '/health',
    name: '健康管理',
    category: DesignCategory.personal,
    compliance: [true, false, false, false, true, true, false],
    auditDate: '2026-03-20',
    notes: '要改善',
  ),
  PageComplianceRecord(
    route: '/mental-check',
    name: 'メンタルチェック',
    category: DesignCategory.personal,
    compliance: [true, false, false, false, true, true, false],
    auditDate: '2026-03-20',
    notes: '要改善',
  ),
  PageComplianceRecord(
    route: '/memory-drill',
    name: '記憶ドリル',
    category: DesignCategory.personal,
    compliance: [true, true, false, false, true, true, false],
    auditDate: '2026-03-25',
    notes: 'タイポグラフィ要改善',
  ),
  PageComplianceRecord(
    route: '/calendar-events',
    name: 'カレンダー (TableCalendar)',
    category: DesignCategory.personal,
    compliance: [true, true, true, true, true, true, false],
    auditDate: '2026-04-06',
  ),
  PageComplianceRecord(
    route: '/habit-gamification',
    name: '習慣ゲーミフィケーション',
    category: DesignCategory.personal,
    compliance: [true, true, true, true, true, true, false],
    auditDate: '2026-04-03',
  ),
  PageComplianceRecord(
    route: '/behavior-review',
    name: '行動振り返り',
    category: DesignCategory.personal,
    compliance: [true, false, false, false, true, true, false],
    auditDate: '2026-03-20',
  ),
  PageComplianceRecord(
    route: '/expense-tracker',
    name: '支出トラッカー',
    category: DesignCategory.personal,
    compliance: [true, false, false, false, false, true, false],
    auditDate: '2026-03-20',
  ),
  PageComplianceRecord(
    route: '/shopping-list',
    name: '買い物リスト',
    category: DesignCategory.personal,
    compliance: [true, false, false, false, false, true, false],
    auditDate: '2026-03-20',
  ),
  PageComplianceRecord(
    route: '/wip-limit',
    name: 'WIP制限管理',
    category: DesignCategory.personal,
  ),
  PageComplianceRecord(
    route: '/travel-itinerary',
    name: '旅行プランナー',
    category: DesignCategory.personal,
    compliance: [true, true, true, true, true, true, false],
    auditDate: '2026-04-03',
  ),
  PageComplianceRecord(
    route: '/recipe-meal-planner',
    name: 'レシピ・献立プランナー',
    category: DesignCategory.personal,
    compliance: [true, true, true, true, true, true, false],
    auditDate: '2026-04-03',
  ),
  PageComplianceRecord(
    route: '/focus-timer',
    name: 'フォーカスタイマー',
    category: DesignCategory.personal,
  ),
  PageComplianceRecord(
    route: '/goal-tracker',
    name: '目標トラッカー',
    category: DesignCategory.personal,
    compliance: [true, true, true, true, true, true, false],
    auditDate: '2026-04-04',
  ),

  // ─── クリエイティブ ──────────────────────────────────
  PageComplianceRecord(
    route: '/guitar-recording-studio',
    name: 'ギタースタジオ',
    category: DesignCategory.creative,
    compliance: [true, true, true, true, true, true, false],
    auditDate: '2026-04-05',
  ),
  PageComplianceRecord(
    route: '/public-guitar-gallery',
    name: '公開ギャラリー',
    category: DesignCategory.creative,
    compliance: [true, true, true, true, true, true, true],
    auditDate: '2026-04-06',
    notes: 'DESIGN.md に完全準拠',
  ),
  PageComplianceRecord(
    route: '/code-playground',
    name: 'コードプレイグラウンド',
    category: DesignCategory.creative,
    compliance: [true, true, true, true, true, true, false],
    auditDate: '2026-04-03',
  ),
  PageComplianceRecord(
    route: '/virtual-whiteboard',
    name: 'バーチャルホワイトボード',
    category: DesignCategory.creative,
    compliance: [true, true, true, true, true, true, false],
    auditDate: '2026-04-03',
  ),
  PageComplianceRecord(
    route: '/music-collaboration',
    name: '音楽コラボ',
    category: DesignCategory.creative,
  ),
  PageComplianceRecord(
    route: '/music-playlist-manager',
    name: '音楽プレイリスト管理',
    category: DesignCategory.creative,
    compliance: [true, true, true, true, true, true, false],
    auditDate: '2026-04-04',
  ),
  PageComplianceRecord(
    route: '/ai-image-generator',
    name: 'AI画像生成',
    category: DesignCategory.creative,
  ),
  PageComplianceRecord(
    route: '/viral-ad-generator',
    name: 'バイラル広告生成',
    category: DesignCategory.creative,
  ),
  PageComplianceRecord(
    route: '/video-ad-generator',
    name: '動画広告生成',
    category: DesignCategory.creative,
  ),

  // ─── 管理・開発 ──────────────────────────────────────
  PageComplianceRecord(
    route: '/edge-functions',
    name: 'Edge Function 一覧',
    category: DesignCategory.admin,
    compliance: [true, true, true, false, true, true, false],
    auditDate: '2026-04-04',
  ),
  PageComplianceRecord(
    route: '/ai-status',
    name: 'AI ステータス',
    category: DesignCategory.admin,
    compliance: [true, true, true, false, true, true, false],
    auditDate: '2026-03-25',
  ),
  PageComplianceRecord(
    route: '/analytics-export',
    name: '分析エクスポート',
    category: DesignCategory.admin,
    compliance: [true, true, true, false, true, true, false],
    auditDate: '2026-04-04',
  ),
  PageComplianceRecord(
    route: '/settings',
    name: '設定',
    category: DesignCategory.admin,
    compliance: [true, true, false, false, true, true, false],
    auditDate: '2026-03-20',
    notes: 'タイポグラフィ・スペーシング要改善',
  ),
  PageComplianceRecord(
    route: '/api-playground',
    name: 'APIプレイグラウンド',
    category: DesignCategory.admin,
  ),
  PageComplianceRecord(
    route: '/feature-flags',
    name: 'フィーチャーフラグ',
    category: DesignCategory.admin,
  ),
  PageComplianceRecord(
    route: '/profile-settings',
    name: 'プロフィール設定',
    category: DesignCategory.admin,
    compliance: [true, true, false, false, true, true, false],
    auditDate: '2026-03-26',
  ),

  // ─── 未カテゴライズ (未審査) ─────────────────────────
  PageComplianceRecord(
    route: '/agents',
    name: 'AI エージェント組織',
    category: DesignCategory.ai,
  ),
  PageComplianceRecord(
    route: '/digital-danshari',
    name: '断捨離ガイド',
    category: DesignCategory.personal,
  ),
  PageComplianceRecord(
    route: '/real-world-danshari',
    name: 'リアル断捨離',
    category: DesignCategory.personal,
  ),
  PageComplianceRecord(
    route: '/stock-tasks',
    name: '週末ストックタスク',
    category: DesignCategory.personal,
  ),
  PageComplianceRecord(
    route: '/mindless-task',
    name: '思考停止タスク',
    category: DesignCategory.personal,
  ),
  PageComplianceRecord(
    route: '/thought-capture',
    name: '思考キャプチャ',
    category: DesignCategory.personal,
  ),
  PageComplianceRecord(
    route: '/thought-anchor',
    name: 'アンカー思考',
    category: DesignCategory.personal,
  ),
  PageComplianceRecord(
    route: '/reality-check',
    name: 'リアリティチェック',
    category: DesignCategory.personal,
  ),
  PageComplianceRecord(
    route: '/rewards',
    name: '実績・リワード',
    category: DesignCategory.personal,
  ),
  PageComplianceRecord(
    route: '/activity-feed',
    name: 'アクティビティフィード',
    category: DesignCategory.notes,
  ),
  PageComplianceRecord(
    route: '/social-feed',
    name: 'ソーシャルフィード',
    category: DesignCategory.notes,
  ),
  PageComplianceRecord(
    route: '/news-rss',
    name: 'ニュース・RSSアグリゲーター',
    category: DesignCategory.ai,
  ),
  PageComplianceRecord(
    route: '/booking-sync',
    name: 'ブッキング同期',
    category: DesignCategory.business,
  ),
  PageComplianceRecord(
    route: '/horse-racing',
    name: '競馬予測 AI',
    category: DesignCategory.ai,
  ),
  PageComplianceRecord(
    route: '/language-learning',
    name: '語学学習',
    category: DesignCategory.ai,
  ),
  PageComplianceRecord(
    route: '/horse-racing',
    name: '競馬予測',
    category: DesignCategory.ai,
  ),
  PageComplianceRecord(
    route: '/fitness-health-tracker',
    name: 'フィットネス・健康トラッカー',
    category: DesignCategory.personal,
    compliance: [true, true, true, true, true, true, false],
    auditDate: '2026-04-04',
  ),
  PageComplianceRecord(
    route: '/legal-compliance',
    name: '法務・コンプライアンス',
    category: DesignCategory.business,
    compliance: [true, true, true, true, true, true, false],
    auditDate: '2026-04-04',
  ),
  PageComplianceRecord(
    route: '/elearning',
    name: 'eラーニング',
    category: DesignCategory.ai,
    compliance: [true, true, true, true, true, true, false],
    auditDate: '2026-04-04',
  ),
  PageComplianceRecord(
    route: '/event-ticketing',
    name: 'イベントチケット管理',
    category: DesignCategory.business,
    compliance: [true, true, true, true, true, true, false],
    auditDate: '2026-04-04',
  ),
  PageComplianceRecord(
    route: '/form-builder',
    name: 'フォームビルダー',
    category: DesignCategory.admin,
    compliance: [true, true, true, true, true, true, false],
    auditDate: '2026-04-04',
  ),
  PageComplianceRecord(
    route: '/home-iot',
    name: 'ホームIoT管理',
    category: DesignCategory.personal,
    compliance: [true, true, true, true, true, true, false],
    auditDate: '2026-04-04',
  ),
  PageComplianceRecord(
    route: '/real-estate',
    name: '不動産管理',
    category: DesignCategory.business,
    compliance: [true, true, true, true, true, true, false],
    auditDate: '2026-04-03',
  ),
  PageComplianceRecord(
    route: '/budget-financial-planner',
    name: '予算・財務プランナー',
    category: DesignCategory.business,
  ),
  PageComplianceRecord(
    route: '/appointment-scheduler',
    name: '予約スケジューラー',
    category: DesignCategory.business,
  ),
  PageComplianceRecord(
    route: '/subscription-billing',
    name: 'サブスクリプション管理',
    category: DesignCategory.business,
  ),
  PageComplianceRecord(
    route: '/vehicle-fleet',
    name: '車両フリート管理',
    category: DesignCategory.business,
  ),
  PageComplianceRecord(
    route: '/spreadsheet-database',
    name: '表計算',
    category: DesignCategory.notes,
  ),
  PageComplianceRecord(
    route: '/qr-code-generator',
    name: 'QRコード生成',
    category: DesignCategory.creative,
  ),
  PageComplianceRecord(
    route: '/voice-memo',
    name: '音声メモ文字起こし',
    category: DesignCategory.ai,
  ),
  PageComplianceRecord(
    route: '/time-tracker',
    name: '時間トラッカー',
    category: DesignCategory.personal,
  ),
  PageComplianceRecord(
    route: '/changelog',
    name: 'チェンジログ',
    category: DesignCategory.admin,
  ),
  PageComplianceRecord(
    route: '/social-scheduler',
    name: 'SNSスケジューラー',
    category: DesignCategory.marketing,
  ),
  PageComplianceRecord(
    route: '/video-meeting',
    name: 'ビデオミーティング',
    category: DesignCategory.business,
  ),
  PageComplianceRecord(
    route: '/password-vault',
    name: 'パスワード金庫',
    category: DesignCategory.admin,
  ),
  PageComplianceRecord(
    route: '/two-factor-auth',
    name: '二要素認証管理',
    category: DesignCategory.admin,
  ),
  PageComplianceRecord(
    route: '/access-control',
    name: 'アクセス制御',
    category: DesignCategory.admin,
  ),
  PageComplianceRecord(
    route: '/sitemap-analytics',
    name: 'サイトマップ分析',
    category: DesignCategory.admin,
  ),
  PageComplianceRecord(
    route: '/photo-gallery',
    name: 'フォトギャラリー',
    category: DesignCategory.creative,
  ),
  PageComplianceRecord(
    route: '/podcast-manager',
    name: 'ポッドキャスト管理',
    category: DesignCategory.creative,
  ),
  PageComplianceRecord(
    route: '/screen-recorder',
    name: 'スクリーンレコーダー',
    category: DesignCategory.creative,
  ),
  PageComplianceRecord(
    route: '/auction-marketplace',
    name: 'オークションマーケット',
    category: DesignCategory.business,
  ),
  PageComplianceRecord(
    route: '/affiliate-marketing',
    name: 'アフィリエイト管理',
    category: DesignCategory.marketing,
  ),
  PageComplianceRecord(
    route: '/donation',
    name: '寄付管理',
    category: DesignCategory.business,
  ),
  PageComplianceRecord(
    route: '/emergency-contacts',
    name: '緊急連絡先',
    category: DesignCategory.personal,
  ),
  PageComplianceRecord(
    route: '/family-sharing',
    name: 'ファミリー共有',
    category: DesignCategory.personal,
  ),
  PageComplianceRecord(
    route: '/pet-care',
    name: 'ペットケア',
    category: DesignCategory.personal,
  ),
  PageComplianceRecord(
    route: '/carbon-footprint',
    name: 'カーボンフットプリント',
    category: DesignCategory.personal,
  ),
  PageComplianceRecord(
    route: '/recruitment',
    name: '採用管理',
    category: DesignCategory.business,
  ),
  PageComplianceRecord(
    route: '/inventory-barcode',
    name: '在庫・バーコード管理',
    category: DesignCategory.business,
  ),
  PageComplianceRecord(
    route: '/virtual-pet',
    name: 'バーチャルペット',
    category: DesignCategory.creative,
  ),
  PageComplianceRecord(
    route: '/ar-navigation',
    name: 'ARナビゲーション',
    category: DesignCategory.creative,
  ),
  PageComplianceRecord(
    route: '/digital-wallet',
    name: 'デジタルウォレット',
    category: DesignCategory.business,
  ),
  PageComplianceRecord(
    route: '/loyalty-points',
    name: 'ロイヤルティポイント',
    category: DesignCategory.business,
  ),
  PageComplianceRecord(
    route: '/gift-registry',
    name: 'ギフトレジストリ',
    category: DesignCategory.personal,
  ),
  PageComplianceRecord(
    route: '/parking-reservation',
    name: '駐車場予約',
    category: DesignCategory.business,
  ),
  PageComplianceRecord(
    route: '/address-book',
    name: 'アドレスブック',
    category: DesignCategory.personal,
  ),
  PageComplianceRecord(
    route: '/customer-feedback',
    name: '顧客フィードバック',
    category: DesignCategory.business,
  ),
  PageComplianceRecord(
    route: '/reading-list',
    name: '読書リスト',
    category: DesignCategory.personal,
  ),
  PageComplianceRecord(
    route: '/bookmark-sync',
    name: 'ブックマーク同期',
    category: DesignCategory.personal,
    compliance: [true, true, true, true, true, true, false],
    auditDate: '2026-04-04',
  ),
  PageComplianceRecord(
    route: '/wardrobe',
    name: 'ワードローブ管理',
    category: DesignCategory.personal,
  ),
  PageComplianceRecord(
    route: '/document-esignature',
    name: '電子署名',
    category: DesignCategory.business,
    compliance: [true, true, true, true, true, true, false],
    auditDate: '2026-04-04',
  ),
  PageComplianceRecord(
    route: '/meeting-manager',
    name: 'ミーティング管理',
    category: DesignCategory.business,
    compliance: [true, true, true, true, true, true, false],
    auditDate: '2026-04-04',
  ),
  PageComplianceRecord(
    route: '/ci-cd-pipeline',
    name: 'CI/CDパイプライン管理',
    category: DesignCategory.admin,
    compliance: [true, true, true, true, true, true, false],
    auditDate: '2026-04-04',
  ),
];

/// DESIGN.md 7項目のラベル
const List<Map<String, String>> kComplianceItems = [
  {'key': 'darkBg', 'label': 'ダーク背景', 'short': 'BG'},
  {'key': 'orange', 'label': 'オレンジCTA', 'short': 'AC'},
  {'key': 'typography', 'label': '日本語タイポ', 'short': 'TY'},
  {'key': 'spacing', 'label': '4pxグリッド', 'short': 'SP'},
  {'key': 'cardStyle', 'label': 'カードスタイル', 'short': 'CA'},
  {'key': 'withValues', 'label': 'withValues(α)', 'short': 'OP'},
  {'key': 'a11y', 'label': 'アクセシビリティ', 'short': 'A11Y'},
];
