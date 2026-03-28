import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/gamification_service.dart';
import 'note_editor_page.dart';

class _TemplateEntry {
  final String id;
  final String category;
  final String title;
  final String description;
  final String content;
  final IconData icon;
  final Color color;

  const _TemplateEntry({
    required this.id,
    required this.category,
    required this.title,
    required this.description,
    required this.content,
    required this.icon,
    required this.color,
  });
}

final List<_TemplateEntry> _templates = [
  // ── 日次記録
  const _TemplateEntry(
    id: 'daily_report',
    category: '日次記録',
    title: '日報',
    description: '今日の成果・課題・明日の計画を整理',
    content: '# 日報\n\n## 今日やったこと\n-\n\n## 成果・気づき\n-\n\n## 課題・ブロッカー\n-\n\n## 明日やること\n-\n\n## メモ\n',
    icon: Icons.today,
    color: Color(0xFF6366F1),
  ),
  const _TemplateEntry(
    id: 'morning_planning',
    category: '日次記録',
    title: '朝の計画',
    description: '今日の最優先タスクと気分を設定',
    content: '# 朝の計画\n\n## 今日の最重要タスク（MIT）\n1.\n2.\n3.\n\n## 気分・体調\n- エネルギーレベル: /10\n- 集中力: /10\n\n## 今日のテーマ・意図\n>\n\n## 感謝すること\n-\n',
    icon: Icons.wb_sunny,
    color: Color(0xFFF59E0B),
  ),
  const _TemplateEntry(
    id: 'evening_reflection',
    category: '日次記録',
    title: '夜の振り返り',
    description: '今日を3つの問いで振り返る',
    content: '# 夜の振り返り\n\n## 今日うまくいったことは？\n-\n\n## 今日学んだことは？\n-\n\n## 明日もっとうまくやるには？\n-\n\n## 感謝リスト\n1.\n2.\n3.\n\n## 明日のFirst Action\n-\n',
    icon: Icons.nights_stay,
    color: Color(0xFF8B5CF6),
  ),

  // ── ビジネス
  const _TemplateEntry(
    id: 'meeting_notes',
    category: 'ビジネス',
    title: '会議メモ',
    description: '参加者・議題・決定事項・アクションを記録',
    content: '# 会議メモ\n\n## 基本情報\n- 日時:\n- 場所/URL:\n- 参加者:\n\n## 議題\n1.\n2.\n\n## 議事録\n\n### 議題1:\n決定事項:\nアクションアイテム:\n\n## ネクストアクション\n| 担当 | タスク | 期限 |\n|------|--------|------|\n|      |        |      |\n',
    icon: Icons.groups,
    color: Color(0xFF0EA5E9),
  ),
  const _TemplateEntry(
    id: 'project_brief',
    category: 'ビジネス',
    title: 'プロジェクト概要',
    description: 'プロジェクトのスコープ・目標・リスクを定義',
    content: '# プロジェクト概要\n\n## プロジェクト名\n## 担当者\n## 期間: ～\n\n## 目的・背景\n\n## 目標・成果物\n-\n\n## スコープ\n### In Scope\n-\n### Out of Scope\n-\n\n## マイルストーン\n| 日付 | マイルストーン |\n|------|---------------|\n|      |               |\n\n## リスク\n-\n',
    icon: Icons.account_tree,
    color: Color(0xFF10B981),
  ),
  const _TemplateEntry(
    id: 'okr',
    category: 'ビジネス',
    title: 'OKR',
    description: '四半期目標をOKRフォーマットで設定',
    content: '# OKR — Q\n\n## Objective（目標）\n>\n\n### Key Result 1\n- 目標値:\n- 現在値:\n\n### Key Result 2\n- 目標値:\n- 現在値:\n\n### Key Result 3\n- 目標値:\n- 現在値:\n\n## 週次チェックイン\n| 週 | KR1 | KR2 | KR3 | メモ |\n|----|-----|-----|-----|------|\n| W1 |     |     |     |      |\n',
    icon: Icons.flag,
    color: Color(0xFFEF4444),
  ),
  const _TemplateEntry(
    id: 'weekly_review',
    category: 'ビジネス',
    title: '週次レビュー',
    description: '先週の振り返りと今週の優先事項を整理',
    content: '# 週次レビュー\n\n## 先週の振り返り\n### できたこと\n-\n\n### できなかったこと & 理由\n-\n\n### 学び・気づき\n-\n\n## 今週の目標\n### 最優先タスク（3つ）\n1.\n2.\n3.\n\n## 生活・健康\n- 睡眠: 平均 h/日\n- 運動: 回\n\n## 来週の自分へ\n>\n',
    icon: Icons.calendar_view_week,
    color: Color(0xFF06B6D4),
  ),

  // ── 思考・アイデア
  const _TemplateEntry(
    id: 'brainstorm',
    category: '思考・アイデア',
    title: 'ブレインストーミング',
    description: 'アイデアを発散→収束させるフレームワーク',
    content: '# ブレインストーミング\n\n## テーマ / 問い\n>\n\n## 発散フェーズ（制約なし、量を重視）\n-\n-\n-\n-\n-\n\n## 収束フェーズ（絞り込み）\n### 実現可能性が高いもの\n-\n\n### 影響力が大きいもの\n-\n\n### ユニーク/差別化できるもの\n-\n\n## 次のアクション\n-\n',
    icon: Icons.lightbulb,
    color: Color(0xFFF59E0B),
  ),
  const _TemplateEntry(
    id: 'pros_cons',
    category: '思考・アイデア',
    title: 'メリット・デメリット分析',
    description: '意思決定のためのPros/Cons整理',
    content: '# メリット・デメリット分析\n\n## 検討事項\n>\n\n## メリット（Pros）\n| 重要度 | 内容 |\n|--------|------|\n| 高     |      |\n| 中     |      |\n\n## デメリット（Cons）\n| 重要度 | 内容 |\n|--------|------|\n| 高     |      |\n| 中     |      |\n\n## 判断\n- 決定:\n- 理由:\n',
    icon: Icons.balance,
    color: Color(0xFF8B5CF6),
  ),
  const _TemplateEntry(
    id: 'book_note',
    category: '思考・アイデア',
    title: '読書ノート',
    description: '本の要点・名言・行動変容をまとめる',
    content: '# 読書ノート\n\n## 書籍情報\n- タイトル:\n- 著者:\n- 読了日:\n\n## 一言サマリー\n>\n\n## 重要な学び（トップ3）\n1.\n2.\n3.\n\n## 印象に残った引用\n>\n（p.）\n\n## 実際にやること（アクション）\n-\n\n## 評価\n⭐️⭐️⭐️⭐️⭐️ /5\n',
    icon: Icons.menu_book,
    color: Color(0xFF10B981),
  ),

  // ── 学習・成長
  const _TemplateEntry(
    id: 'learning_log',
    category: '学習・成長',
    title: '学習ログ',
    description: '学んだこと・疑問点・復習予定を記録',
    content: '# 学習ログ\n\n## 学習テーマ\n## 学習時間: 分\n\n## 今日学んだこと\n### キーポイント\n-\n-\n\n### 新しい概念・用語\n| 用語 | 説明 |\n|------|------|\n|      |      |\n\n## 疑問・もやもや\n-\n\n## 復習予定\n- 明日:\n- 1週間後:\n- 1ヶ月後:\n',
    icon: Icons.school,
    color: Color(0xFF6366F1),
  ),
  const _TemplateEntry(
    id: 'goal_setting',
    category: '学習・成長',
    title: '目標設定（SMART）',
    description: 'SMARTフレームワークで目標を具体化',
    content: '# 目標設定 — SMART\n\n## 目標\n>\n\n## SMART チェック\n### S (Specific) — 具体的か？\n-\n\n### M (Measurable) — 測定可能か？\n- 指標:\n- 現在値: → 目標値:\n\n### A (Achievable) — 達成可能か？\n-\n\n### R (Relevant) — 関連性があるか？\n-\n\n### T (Time-bound) — 期限があるか？\n- 期限:\n\n## アクションプラン\n| ステップ | 期限 | ステータス |\n|----------|------|------------|\n|          |      | □           |\n',
    icon: Icons.gps_fixed,
    color: Color(0xFFEF4444),
  ),
  const _TemplateEntry(
    id: 'habit_tracker',
    category: '学習・成長',
    title: '習慣トラッカー',
    description: '月間の習慣達成を記録するテンプレート',
    content: '# 習慣トラッカー\n\n## 習慣リスト\n| # | 習慣 | 目標頻度 |\n|---|------|----------|\n| 1 |      | 毎日      |\n| 2 |      | 毎日      |\n| 3 |      | 週3回    |\n\n## 月末振り返り\n- 最も継続できた習慣:\n- 改善が必要な習慣:\n- 来月の目標:\n',
    icon: Icons.check_circle,
    color: Color(0xFF10B981),
  ),

  // ── 個人・生活
  const _TemplateEntry(
    id: 'travel_plan',
    category: '個人・生活',
    title: '旅行計画',
    description: '旅程・予算・持ち物チェックリスト',
    content: '# 旅行計画\n\n## 基本情報\n- 目的地:\n- 期間: 〜\n- メンバー:\n\n## 旅程\n### Day 1\n-\n\n## 予算\n| カテゴリ | 予算 | 実績 |\n|----------|------|------|\n| 交通     |      |      |\n| 宿泊     |      |      |\n| 食事     |      |      |\n\n## 持ち物チェックリスト\n- [ ] パスポート/身分証\n- [ ] 充電器\n- [ ] 着替え（泊分）\n- [ ] 常備薬\n- [ ]\n',
    icon: Icons.flight,
    color: Color(0xFF0EA5E9),
  ),
  const _TemplateEntry(
    id: 'budget_review',
    category: '個人・生活',
    title: '月次家計簿レビュー',
    description: '収支を振り返り、改善点を見つける',
    content: '# 月次家計簿レビュー\n\n## 収入\n| 項目 | 金額 |\n|------|------|\n| 給与 | ¥    |\n| 副業 | ¥    |\n| **合計** | ¥ |\n\n## 支出\n| カテゴリ | 予算 | 実績 | 差分 |\n|----------|------|------|------|\n| 家賃     | ¥    | ¥    |      |\n| 食費     | ¥    | ¥    |      |\n| 交通費   | ¥    | ¥    |      |\n| **合計** | ¥    | ¥    |      |\n\n## 貯蓄\n- 今月の貯蓄額: ¥\n- 貯蓄率: %\n\n## 振り返り\n- 無駄遣いだったもの:\n- 来月の改善点:\n',
    icon: Icons.account_balance_wallet,
    color: Color(0xFFF59E0B),
  ),

  // ── 技術・開発
  const _TemplateEntry(
    id: 'bug_report',
    category: '技術・開発',
    title: 'バグレポート',
    description: '再現手順・期待動作・環境を記録',
    content: '# バグレポート\n\n## 概要\n\n## 再現手順\n1.\n2.\n3.\n\n## 期待する動作\n-\n\n## 実際の動作\n-\n\n## 環境\n- OS:\n- ブラウザ/バージョン:\n- アプリバージョン:\n\n## 優先度\n- [ ] Critical（サービス停止）\n- [ ] High（主要機能が使えない）\n- [ ] Medium（回避策あり）\n- [ ] Low（軽微）\n',
    icon: Icons.bug_report,
    color: Color(0xFFEF4444),
  ),
  const _TemplateEntry(
    id: 'tech_spec',
    category: '技術・開発',
    title: '技術仕様書',
    description: '機能の設計・API・データモデルを定義',
    content: '# 技術仕様書\n\n## 機能概要\n## ステータス: Draft / Review / Approved\n## 作成日:\n\n## 背景・目的\n-\n\n## 要件\n### 機能要件\n-\n### 非機能要件\n- パフォーマンス:\n- セキュリティ:\n\n## データモデル\n```sql\n-- テーブル定義\n```\n\n## API設計\n- `GET /api/xxx` — 説明\n- `POST /api/xxx` — 説明\n\n## テスト方針\n-\n',
    icon: Icons.code,
    color: Color(0xFF6366F1),
  ),
  const _TemplateEntry(
    id: 'retrospective',
    category: '技術・開発',
    title: 'スプリント振り返り（KPT）',
    description: 'Keep/Problem/Tryで開発プロセスを改善',
    content: '# スプリント振り返り — Sprint\n\n## Keep（続けること）\n-\n\n## Problem（問題・課題）\n-\n\n## Try（次にやること）\n-\n\n## スプリント指標\n- ベロシティ:\n- 完了ストーリーポイント:\n- バグ発生数:\n\n## チームの気分（1-5）\n- エネルギー:\n- 連携:\n- 満足度:\n',
    icon: Icons.loop,
    color: Color(0xFF10B981),
  ),
];

class TemplateMarketplacePage extends StatefulWidget {
  const TemplateMarketplacePage({super.key});

  @override
  State<TemplateMarketplacePage> createState() =>
      _TemplateMarketplacePageState();
}

class _TemplateMarketplacePageState extends State<TemplateMarketplacePage> {
  String _selectedCategory = 'すべて';

  List<String> get _categories {
    final cats = _templates.map((t) => t.category).toSet().toList();
    return ['すべて', ...cats];
  }

  List<_TemplateEntry> get _filtered {
    if (_selectedCategory == 'すべて') return _templates;
    return _templates.where((t) => t.category == _selectedCategory).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('テンプレート広場'),
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        foregroundColor: isDark ? Colors.white : const Color(0xFF1E293B),
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildCategoryTabs(isDark),
          Expanded(child: _buildList(isDark)),
        ],
      ),
    );
  }

  Widget _buildCategoryTabs(bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: _categories.map((cat) {
            final selected = cat == _selectedCategory;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(cat),
                selected: selected,
                onSelected: (_) => setState(() => _selectedCategory = cat),
                selectedColor: const Color(0xFF6366F1),
                labelStyle: TextStyle(
                  color: selected
                      ? Colors.white
                      : (isDark ? Colors.white70 : Colors.black87),
                  fontSize: 13,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildList(bool isDark) {
    final items = _filtered;
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      itemBuilder: (context, index) => _buildCard(items[index], isDark),
    );
  }

  Widget _buildCard(_TemplateEntry t, bool isDark) {
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    return Card(
      color: cardColor,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: t.color.withAlpha(30),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(t.icon, color: t.color, size: 22),
        ),
        title: Text(
          t.title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
          ),
        ),
        subtitle: Text(
          t.description,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white54 : Colors.grey[600],
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: t.color.withAlpha(20),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            t.category,
            style: TextStyle(fontSize: 10, color: t.color),
          ),
        ),
        onTap: () => _useTemplate(context, t),
      ),
    );
  }

  void _useTemplate(BuildContext context, _TemplateEntry t) {
    Provider.of<GamificationService>(context, listen: false)
        .awardPoints(10, reason: 'Used Template: ${t.title}');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NoteEditorPage(
          initialTitle: t.title,
          initialContent: t.content,
        ),
      ),
    );
  }
}
