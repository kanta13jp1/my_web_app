import 'package:flutter/material.dart';

/// Competitor-specific comparison landing page.
/// Each competitor gets a dedicated route (/vs-notion, /vs-evernote, …)
/// so organic search traffic for "Notion代替", "Evernote代替", etc. lands on
/// a page that speaks directly to that user's context.
class ComparisonPage extends StatelessWidget {
  final String competitorKey;

  const ComparisonPage({super.key, required this.competitorKey});

  @override
  Widget build(BuildContext context) {
    final info = _competitorInfo[competitorKey.toLowerCase()] ?? _defaultInfo;
    return _ComparisonShell(info: info);
  }
}

// ---------------------------------------------------------------------------
// Competitor metadata
// ---------------------------------------------------------------------------

class _CompetitorInfo {
  final String name;
  final String emoji;
  final String tagline;
  final String searchKeyword;
  final Color accentColor;
  final List<String> painPoints;
  final List<_FeatureComparison> features;

  const _CompetitorInfo({
    required this.name,
    required this.emoji,
    required this.tagline,
    required this.searchKeyword,
    required this.accentColor,
    required this.painPoints,
    required this.features,
  });
}

class _FeatureComparison {
  final String feature;
  final bool competitorHas;
  final bool weHave;

  const _FeatureComparison({
    required this.feature,
    required this.competitorHas,
    required this.weHave,
  });
}

const _defaultInfo = _CompetitorInfo(
  name: '競合サービス',
  emoji: '🔄',
  tagline: '複数ツールをまとめて、完全無料で使える',
  searchKeyword: '代替',
  accentColor: Color(0xFF3949AB),
  painPoints: ['複数サービスへのログインが面倒', 'データが分散して管理しにくい', '月額料金が積み重なる'],
  features: [
    _FeatureComparison(feature: 'タスク管理', competitorHas: true, weHave: true),
    _FeatureComparison(feature: 'AI サポート', competitorHas: false, weHave: true),
    _FeatureComparison(feature: '完全無料', competitorHas: false, weHave: true),
  ],
);

final _competitorInfo = <String, _CompetitorInfo>{
  'notion': const _CompetitorInfo(
    name: 'Notion',
    emoji: '📝',
    tagline: 'Notion のすべての機能を、完全無料で。AIが自動整理まで。',
    searchKeyword: 'Notion代替',
    accentColor: Color(0xFF1F2937),
    painPoints: [
      'Notionの無料プランはページ数に制限がある',
      'AI機能（Notion AI）は月額追加料金が必要',
      'データベースの設定が複雑で学習コストが高い',
    ],
    features: [
      _FeatureComparison(feature: 'メモ・ノート作成', competitorHas: true, weHave: true),
      _FeatureComparison(feature: 'データベース / テーブル', competitorHas: true, weHave: true),
      _FeatureComparison(feature: 'AI 自動整理', competitorHas: false, weHave: true),
      _FeatureComparison(feature: '資産・家計管理', competitorHas: false, weHave: true),
      _FeatureComparison(feature: '完全無料（制限なし）', competitorHas: false, weHave: true),
      _FeatureComparison(feature: 'Notion データインポート', competitorHas: true, weHave: true),
    ],
  ),
  'evernote': const _CompetitorInfo(
    name: 'Evernote',
    emoji: '🐘',
    tagline: '2.5億人が使ったEvernoteの代替。データもそのまま移行できる。',
    searchKeyword: 'Evernote代替',
    accentColor: Color(0xFF00A82D),
    painPoints: [
      'Evernoteの無料プランはデバイス2台まで',
      '月額600円〜のプレミアム料金',
      'AI機能がなく手動整理が必要',
    ],
    features: [
      _FeatureComparison(feature: 'メモ・ノート管理', competitorHas: true, weHave: true),
      _FeatureComparison(feature: '画像・添付ファイル管理', competitorHas: true, weHave: true),
      _FeatureComparison(feature: 'AI タグ自動付与', competitorHas: false, weHave: true),
      _FeatureComparison(feature: '公開メモ共有', competitorHas: false, weHave: true),
      _FeatureComparison(feature: '完全無料（デバイス制限なし）', competitorHas: false, weHave: true),
      _FeatureComparison(feature: 'ENEX インポート', competitorHas: true, weHave: true),
    ],
  ),
  'moneyforward': const _CompetitorInfo(
    name: 'MoneyForward',
    emoji: '💰',
    tagline: '家計管理もタスク管理も1つのアプリで。完全無料。',
    searchKeyword: 'MoneyForward代替',
    accentColor: Color(0xFF0D47A1),
    painPoints: [
      'MoneyForwardの無料プランは連携口座数が4件まで',
      'プレミアムは月額500円〜',
      '資産管理しかできず、メモやタスクは別アプリが必要',
    ],
    features: [
      _FeatureComparison(feature: '収支・家計管理', competitorHas: true, weHave: true),
      _FeatureComparison(feature: '資産残高把握', competitorHas: true, weHave: true),
      _FeatureComparison(feature: 'タスク・ノート連携', competitorHas: false, weHave: true),
      _FeatureComparison(feature: 'AI 資産アドバイス', competitorHas: false, weHave: true),
      _FeatureComparison(feature: '完全無料（口座数制限なし）', competitorHas: false, weHave: true),
    ],
  ),
  'slack': const _CompetitorInfo(
    name: 'Slack',
    emoji: '💬',
    tagline: 'チームコミュニケーションをAIが支援。月額ゼロ円で始める。',
    searchKeyword: 'Slack代替',
    accentColor: Color(0xFF4A154B),
    painPoints: [
      'Slackの無料プランはメッセージ履歴が90日に限定',
      'Proプランは月額925円〜/人',
      '他の業務ツールと連携が必要で複数アプリを行き来する',
    ],
    features: [
      _FeatureComparison(feature: 'メッセージ・チャット', competitorHas: true, weHave: true),
      _FeatureComparison(feature: 'メッセージ履歴無制限', competitorHas: false, weHave: true),
      _FeatureComparison(feature: 'ノート・メモ統合', competitorHas: false, weHave: true),
      _FeatureComparison(feature: 'AI 会話まとめ', competitorHas: false, weHave: true),
      _FeatureComparison(feature: '完全無料', competitorHas: false, weHave: true),
    ],
  ),
  'chatwork': const _CompetitorInfo(
    name: 'Chatwork',
    emoji: '🏢',
    tagline: '国内ビジネスチャットの代替。ノート・資産管理も1つに。',
    searchKeyword: 'Chatwork代替',
    accentColor: Color(0xFFE53935),
    painPoints: [
      'Chatworkの無料プランはグループ4件・メッセージ40件保存まで',
      'ビジネスプランは月額700円〜/人',
      'チャット以外の機能がなく複数ツール管理が必要',
    ],
    features: [
      _FeatureComparison(feature: 'ビジネスチャット', competitorHas: true, weHave: true),
      _FeatureComparison(feature: 'タスク管理', competitorHas: true, weHave: true),
      _FeatureComparison(feature: 'ノート・メモ統合', competitorHas: false, weHave: true),
      _FeatureComparison(feature: 'AI サポート', competitorHas: false, weHave: true),
      _FeatureComparison(feature: '完全無料', competitorHas: false, weHave: true),
    ],
  ),
};

// ---------------------------------------------------------------------------
// Shell widget
// ---------------------------------------------------------------------------

class _ComparisonShell extends StatelessWidget {
  final _CompetitorInfo info;
  const _ComparisonShell({required this.info});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FF),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHero(context),
            _buildPainPoints(),
            _buildFeatureTable(),
            _buildCta(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            info.accentColor.withAlpha(26),
            const Color(0xFFEEF2FF),
          ],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            children: [
              Text(info.emoji, style: const TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              Text(
                '${info.name} の代わりに\n自分株式会社を使う',
                style: const TextStyle(
                  fontFamily: 'Noto Serif JP',
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                info.tagline,
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF374151),
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context)
                        .pushNamedAndRemoveUntil('/', (_) => false),
                    icon: const Icon(Icons.rocket_launch, size: 18),
                    label: const Text('無料で始める（30秒）'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF3949AB),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () =>
                        Navigator.of(context).pushNamed('/import'),
                    icon: const Icon(Icons.upload_file, size: 18),
                    label: Text('${info.name} からインポート'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPainPoints() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${info.name} の不満はありませんか？',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              ...info.painPoints.map(
                (p) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '😤',
                        style: TextStyle(fontSize: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          p,
                          style: const TextStyle(fontSize: 15, height: 1.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureTable() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '機能比較',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              Table(
                columnWidths: const {
                  0: FlexColumnWidth(3),
                  1: FlexColumnWidth(1),
                  2: FlexColumnWidth(1),
                },
                children: [
                  TableRow(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(10),
                        child: Text(
                          '機能',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Text(
                          info.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.all(10),
                        child: Text(
                          '自分株式会社',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF3949AB),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                  ...info.features.map(
                    (f) => TableRow(
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Colors.grey[200]!),
                        ),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 12,
                          ),
                          child: Text(
                            f.feature,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Center(
                            child: Text(
                              f.competitorHas ? '✅' : '❌',
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Center(
                            child: Text(
                              f.weHave ? '✅' : '❌',
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCta(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF3949AB),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            children: [
              const Text(
                '今すぐ無料で始める',
                style: TextStyle(
                  fontFamily: 'Noto Serif JP',
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                'クレジットカード不要。30秒で登録完了。',
                style: TextStyle(color: Colors.white70, fontSize: 15),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => Navigator.of(context)
                    .pushNamedAndRemoveUntil('/', (_) => false),
                icon: const Icon(Icons.rocket_launch, size: 18),
                label: const Text(
                  '無料で自分株式会社を始める',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF3949AB),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
