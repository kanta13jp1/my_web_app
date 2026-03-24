import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


// ---------------------------------------------------------------------------
// Data model
// ---------------------------------------------------------------------------

class _PlanItem {
  final String label;
  final String? deadline; // 'yyyy年MM月dd日'
  final int target;
  const _PlanItem({
    required this.label,
    this.deadline,
    required this.target,
  });
}

// ---------------------------------------------------------------------------
// Widget
// ---------------------------------------------------------------------------

/// ホーム画面最上部に表示する開発ロードマップ進捗カード。
///
/// 登録ユーザー数を `user_profiles` テーブルから取得し、
/// 短期・中期・長期計画および競合比較の進捗をプログレスバーで表示する。
class GrowthRoadmapProgressCard extends StatefulWidget {
  /// テスト用にクライアントを注入できるようにする
  final SupabaseClient? supabaseClient;

  const GrowthRoadmapProgressCard({super.key, this.supabaseClient});

  @override
  State<GrowthRoadmapProgressCard> createState() =>
      _GrowthRoadmapProgressCardState();
}

class _GrowthRoadmapProgressCardState
    extends State<GrowthRoadmapProgressCard> {
  static const _plans = [
    _PlanItem(
      label: '短期計画',
      deadline: '2026年06月30日',
      target: 100,
    ),
    _PlanItem(
      label: '中期計画',
      deadline: '2027年03月25日',
      target: 10000,
    ),
    _PlanItem(
      label: '長期計画',
      deadline: '2029年03月25日',
      target: 100000000,
    ),
    _PlanItem(
      label: 'vs NOTION',
      target: 100000000,
    ),
    _PlanItem(
      label: 'vs EverNote',
      target: 250000000,
    ),
  ];

  int _userCount = 0;
  bool _isLoading = true;

  SupabaseClient get _supabase =>
      widget.supabaseClient ?? Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadUserCount();
  }

  Future<void> _loadUserCount() async {
    try {
      final response = await _supabase
          .from('user_profiles')
          .select('user_id')
          .count(CountOption.exact);
      if (!mounted) return;
      setState(() {
        _userCount = response.count;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor =
        isDark ? const Color(0xFF1A2233) : const Color(0xFFFFFFFF);
    final borderColor =
        isDark ? const Color(0xFF2A3A55) : const Color(0xFFE2E8F0);
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subTextColor =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      key: const Key('growth_roadmap_progress_card'),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flag_outlined, size: 18, color: Color(0xFF6366F1)),
              const SizedBox(width: 8),
              const Text(
                'GROWTH ROADMAP',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: Color(0xFF6366F1),
                ),
              ),
              const Spacer(),
              if (_isLoading)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Text(
                  '現在 $_userCount 人',
                  style: TextStyle(
                    fontSize: 12,
                    color: subTextColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ..._plans.map(
            (plan) => _PlanProgressRow(
              plan: plan,
              currentCount: _userCount,
              textColor: textColor,
              subTextColor: subTextColor,
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Single plan row
// ---------------------------------------------------------------------------

class _PlanProgressRow extends StatelessWidget {
  final _PlanItem plan;
  final int currentCount;
  final Color textColor;
  final Color subTextColor;
  final bool isDark;

  const _PlanProgressRow({
    required this.plan,
    required this.currentCount,
    required this.textColor,
    required this.subTextColor,
    required this.isDark,
  });

  static const int _barSegments = 10;

  @override
  Widget build(BuildContext context) {
    final ratio =
        plan.target > 0 ? (currentCount / plan.target).clamp(0.0, 1.0) : 0.0;
    final pct = (ratio * 100).toStringAsFixed(ratio >= 0.01 ? 1 : 2);
    final filledSegments = (ratio * _barSegments).round();
    final barText = _buildBarText(filledSegments);

    // Format numbers with commas
    final currentStr = _fmt(currentCount);
    final targetStr = _fmt(plan.target);

    // Colour: green when achieved, indigo otherwise
    final barColor = ratio >= 1.0
        ? const Color(0xFF22C55E)
        : const Color(0xFF6366F1);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  plan.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ),
              if (plan.deadline != null)
                Text(
                  '目標期日 ${plan.deadline}',
                  style: TextStyle(fontSize: 11, color: subTextColor),
                ),
            ],
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Text(
                '$pct%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: barColor,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '($currentStr / $targetStr ユーザー完了)',
                  style: TextStyle(fontSize: 11, color: subTextColor),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _SegmentedBar(
            filledSegments: filledSegments,
            totalSegments: _barSegments,
            filledColor: barColor,
            emptyColor: isDark
                ? const Color(0xFF2D3748)
                : const Color(0xFFE2E8F0),
            barText: barText,
            textColor: textColor,
          ),
        ],
      ),
    );
  }

  String _buildBarText(int filled) {
    const filled_ = '■';
    const empty_ = '□';
    return List.generate(
      _barSegments,
      (i) => i < filled ? filled_ : empty_,
    ).join();
  }

  String _fmt(int n) {
    if (n >= 100000000) {
      return '${(n / 100000000).toStringAsFixed(n % 100000000 == 0 ? 0 : 1)}億';
    }
    if (n >= 10000) {
      return '${(n / 10000).toStringAsFixed(n % 10000 == 0 ? 0 : 1)}万';
    }
    // Add comma separators for numbers < 10000
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

// ---------------------------------------------------------------------------
// Segmented progress bar (visual + text fallback)
// ---------------------------------------------------------------------------

class _SegmentedBar extends StatelessWidget {
  final int filledSegments;
  final int totalSegments;
  final Color filledColor;
  final Color emptyColor;
  final String barText;
  final Color textColor;

  const _SegmentedBar({
    required this.filledSegments,
    required this.totalSegments,
    required this.filledColor,
    required this.emptyColor,
    required this.barText,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Visual segmented bar
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 10,
              child: Row(
                children: List.generate(totalSegments, (i) {
                  final isFilled = i < filledSegments;
                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: isFilled ? filledColor : emptyColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Text fallback (■□ style as requested)
        Text(
          barText,
          style: TextStyle(
            fontSize: 11,
            color: filledSegments > 0 ? filledColor : emptyColor,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}

// ===========================================================================
// Notion Feature Comparison Card
// ===========================================================================

/// 実装ステータスの種別
enum _FeatureStatus {
  done, // 実装済み
  partial, // 部分実装
  inProgress, // 開発中
  notYet, // 未実装
  unique, // MyMemo 独自機能 (Notion にない)
}

extension _FeatureStatusExt on _FeatureStatus {
  String get label => switch (this) {
        _FeatureStatus.done => '実装済み',
        _FeatureStatus.partial => '部分実装',
        _FeatureStatus.inProgress => '開発中',
        _FeatureStatus.notYet => '未実装',
        _FeatureStatus.unique => '独自機能',
      };

  Color get color => switch (this) {
        _FeatureStatus.done => const Color(0xFF22C55E),
        _FeatureStatus.partial => const Color(0xFFF59E0B),
        _FeatureStatus.inProgress => const Color(0xFF3B82F6),
        _FeatureStatus.notYet => const Color(0xFF94A3B8),
        _FeatureStatus.unique => const Color(0xFFA855F7),
      };

  IconData get icon => switch (this) {
        _FeatureStatus.done => Icons.check_circle,
        _FeatureStatus.partial => Icons.timelapse,
        _FeatureStatus.inProgress => Icons.construction,
        _FeatureStatus.notYet => Icons.radio_button_unchecked,
        _FeatureStatus.unique => Icons.auto_awesome,
      };
}

class _FeatureRow {
  final String category;
  final String feature;
  final String notionDetail;
  final _FeatureStatus status;
  final String myMemoDetail;

  const _FeatureRow({
    required this.category,
    required this.feature,
    required this.notionDetail,
    required this.status,
    required this.myMemoDetail,
  });
}

// ---------------------------------------------------------------------------
// Feature data
// ---------------------------------------------------------------------------

const _featureRows = <_FeatureRow>[
  // ---- ノート編集 ----
  _FeatureRow(
    category: 'ノート編集',
    feature: 'リッチテキスト編集',
    notionDetail: 'Markdown + スラッシュコマンドでブロック挿入',
    status: _FeatureStatus.done,
    myMemoDetail: 'Markdown 対応エディタ実装済み',
  ),
  _FeatureRow(
    category: 'ノート編集',
    feature: 'AI 文章補助',
    notionDetail: 'Notion AI: 文章生成・改善・要約',
    status: _FeatureStatus.done,
    myMemoDetail: 'AI Secretary / MAGI System で複数モデル対応',
  ),
  _FeatureRow(
    category: 'ノート編集',
    feature: 'バージョン履歴',
    notionDetail: '無料プランは7日間、有料は無制限',
    status: _FeatureStatus.notYet,
    myMemoDetail: '未実装 — ロードマップに追加予定',
  ),
  _FeatureRow(
    category: 'ノート編集',
    feature: 'ファイル添付',
    notionDetail: '画像・PDF 等をブロックとして埋め込み',
    status: _FeatureStatus.notYet,
    myMemoDetail: '未実装',
  ),
  _FeatureRow(
    category: 'ノート編集',
    feature: 'コードブロック',
    notionDetail: 'シンタックスハイライト付きコードブロック',
    status: _FeatureStatus.partial,
    myMemoDetail: 'Markdown コードフェンス対応済み',
  ),
  // ---- 整理・検索 ----
  _FeatureRow(
    category: '整理・検索',
    feature: 'タグ・カテゴリ',
    notionDetail: 'ページにタグ付け・フィルタリング',
    status: _FeatureStatus.done,
    myMemoDetail: 'カテゴリページ実装済み',
  ),
  _FeatureRow(
    category: '整理・検索',
    feature: '全文検索',
    notionDetail: 'ページ横断検索・クイックファインド',
    status: _FeatureStatus.partial,
    myMemoDetail: 'AI 検索・埋め込み検索を部分実装',
  ),
  _FeatureRow(
    category: '整理・検索',
    feature: 'テンプレート',
    notionDetail: '公式テンプレートギャラリー + コミュニティ共有',
    status: _FeatureStatus.partial,
    myMemoDetail: 'テンプレートマーケットプレイス画面実装済み',
  ),
  // ---- データベース ----
  _FeatureRow(
    category: 'データベース',
    feature: 'テーブルビュー',
    notionDetail: 'スプレッドシート形式でプロパティ管理',
    status: _FeatureStatus.notYet,
    myMemoDetail: '未実装 — 中期計画で対応予定',
  ),
  _FeatureRow(
    category: 'データベース',
    feature: 'カンバン/ボード',
    notionDetail: 'ステータス別カードビュー',
    status: _FeatureStatus.notYet,
    myMemoDetail: '未実装 — 中期計画で対応予定',
  ),
  _FeatureRow(
    category: 'データベース',
    feature: 'カレンダービュー',
    notionDetail: '日付プロパティをカレンダーで表示',
    status: _FeatureStatus.notYet,
    myMemoDetail: '未実装',
  ),
  _FeatureRow(
    category: 'データベース',
    feature: 'ガントチャート',
    notionDetail: 'タイムラインビューでスケジュール管理',
    status: _FeatureStatus.notYet,
    myMemoDetail: '未実装',
  ),
  _FeatureRow(
    category: 'データベース',
    feature: 'リレーション・ロールアップ',
    notionDetail: 'DB 間リンクと集計フィールド',
    status: _FeatureStatus.notYet,
    myMemoDetail: '未実装 — 長期計画で対応予定',
  ),
  // ---- 共有・コラボ ----
  _FeatureRow(
    category: '共有・コラボ',
    feature: 'ページ公開',
    notionDetail: 'URLで誰でも閲覧可能なページ公開',
    status: _FeatureStatus.done,
    myMemoDetail: '公開メモ機能実装済み・OGP対応',
  ),
  _FeatureRow(
    category: '共有・コラボ',
    feature: 'リアルタイム共同編集',
    notionDetail: '複数人が同時に編集可能',
    status: _FeatureStatus.notYet,
    myMemoDetail: '未実装 — 中期計画 (Team workspace) で対応予定',
  ),
  _FeatureRow(
    category: '共有・コラボ',
    feature: 'コメント・メンション',
    notionDetail: 'ブロックへのインラインコメント',
    status: _FeatureStatus.notYet,
    myMemoDetail: '未実装',
  ),
  _FeatureRow(
    category: '共有・コラボ',
    feature: 'チームワークスペース',
    notionDetail: '組織単位でのページ・権限管理',
    status: _FeatureStatus.notYet,
    myMemoDetail: '未実装 — 中期計画で Team/Enterprise 対応予定',
  ),
  // ---- 移行・連携 ----
  _FeatureRow(
    category: '移行・連携',
    feature: 'Notion からインポート',
    notionDetail: 'Notion 公式はエクスポートのみ提供',
    status: _FeatureStatus.done,
    myMemoDetail: 'CSV インポート実装済み・Edge Function first',
  ),
  _FeatureRow(
    category: '移行・連携',
    feature: 'Evernote からインポート',
    notionDetail: 'ENEX インポート対応',
    status: _FeatureStatus.done,
    myMemoDetail: 'ENEX インポート実装済み・Edge Function first',
  ),
  _FeatureRow(
    category: '移行・連携',
    feature: 'Markdown インポート',
    notionDetail: 'Markdown ファイルのインポート可能',
    status: _FeatureStatus.done,
    myMemoDetail: 'Markdown インポート実装済み',
  ),
  _FeatureRow(
    category: '移行・連携',
    feature: 'Web クリッパー',
    notionDetail: 'ブラウザ拡張でウェブページを保存',
    status: _FeatureStatus.notYet,
    myMemoDetail: '未実装',
  ),
  _FeatureRow(
    category: '移行・連携',
    feature: '外部サービス連携 (Zapier 等)',
    notionDetail: 'API + Zapier/Make/IFTTT 連携',
    status: _FeatureStatus.partial,
    myMemoDetail: 'Supabase Edge Function 経由で API 公開中',
  ),
  // ---- プラットフォーム ----
  _FeatureRow(
    category: 'プラットフォーム',
    feature: 'Web アプリ',
    notionDetail: 'ブラウザで全機能利用可能',
    status: _FeatureStatus.done,
    myMemoDetail: 'Flutter Web 実装済み',
  ),
  _FeatureRow(
    category: 'プラットフォーム',
    feature: 'モバイルアプリ (iOS/Android)',
    notionDetail: 'ネイティブアプリ提供',
    status: _FeatureStatus.inProgress,
    myMemoDetail: 'Flutter クロスプラットフォーム対応可能 — リリース準備中',
  ),
  _FeatureRow(
    category: 'プラットフォーム',
    feature: 'デスクトップアプリ',
    notionDetail: 'Mac/Windows Electron アプリ',
    status: _FeatureStatus.inProgress,
    myMemoDetail: 'Flutter Desktop 対応可能 — リリース準備中',
  ),
  _FeatureRow(
    category: 'プラットフォーム',
    feature: 'オフライン対応',
    notionDetail: 'オフラインでも閲覧・編集可能',
    status: _FeatureStatus.notYet,
    myMemoDetail: '未実装 — 長期計画で対応予定',
  ),
  // ---- MyMemo 独自機能 ----
  _FeatureRow(
    category: 'MyMemo 独自機能',
    feature: 'マインドマップ',
    notionDetail: '— Notion にはない機能',
    status: _FeatureStatus.unique,
    myMemoDetail: 'ビジュアルマインドマップ実装済み',
  ),
  _FeatureRow(
    category: 'MyMemo 独自機能',
    feature: '記憶ドリル',
    notionDetail: '— Notion にはない機能',
    status: _FeatureStatus.unique,
    myMemoDetail: 'スペーシング反復学習ドリル実装済み',
  ),
  _FeatureRow(
    category: 'MyMemo 独自機能',
    feature: 'AI エージェント組織',
    notionDetail: '— Notion にはない機能',
    status: _FeatureStatus.unique,
    myMemoDetail: 'CEO/CFO/CMO/CHRO 役員会議 AI 実装済み',
  ),
  _FeatureRow(
    category: 'MyMemo 独自機能',
    feature: '経営コックピット',
    notionDetail: '— Notion にはない機能',
    status: _FeatureStatus.unique,
    myMemoDetail: 'KPI・資産・習慣を一画面で管理',
  ),
  _FeatureRow(
    category: 'MyMemo 独自機能',
    feature: 'Growth ロードマップ進捗表示',
    notionDetail: '— Notion にはない機能',
    status: _FeatureStatus.unique,
    myMemoDetail: 'このカードがその機能です',
  ),
  _FeatureRow(
    category: 'MyMemo 独自機能',
    feature: 'Referral 紹介プログラム',
    notionDetail: '— Notion にはない機能',
    status: _FeatureStatus.unique,
    myMemoDetail: 'anti-abuse 付き referral code 発行・管理実装済み',
  ),
];

// ---------------------------------------------------------------------------
// Widget
// ---------------------------------------------------------------------------

/// Notion の機能一覧と MyMemo の実装状況を比較表示するカード。
class NotionFeatureComparisonCard extends StatefulWidget {
  const NotionFeatureComparisonCard({super.key});

  @override
  State<NotionFeatureComparisonCard> createState() =>
      _NotionFeatureComparisonCardState();
}

class _NotionFeatureComparisonCardState
    extends State<NotionFeatureComparisonCard> {
  bool _expanded = false;
  String _filterCategory = 'すべて';

  List<String> get _categories {
    final cats = <String>['すべて'];
    for (final row in _featureRows) {
      if (!cats.contains(row.category)) cats.add(row.category);
    }
    return cats;
  }

  List<_FeatureRow> get _filtered => _filterCategory == 'すべて'
      ? _featureRows
      : _featureRows.where((r) => r.category == _filterCategory).toList();

  // Summary counts
  int get _doneCount =>
      _featureRows.where((r) => r.status == _FeatureStatus.done).length;
  int get _partialCount =>
      _featureRows.where((r) => r.status == _FeatureStatus.partial).length;
  int get _inProgressCount =>
      _featureRows.where((r) => r.status == _FeatureStatus.inProgress).length;
  int get _notYetCount =>
      _featureRows.where((r) => r.status == _FeatureStatus.notYet).length;
  int get _uniqueCount =>
      _featureRows.where((r) => r.status == _FeatureStatus.unique).length;
  int get _totalNotUnique =>
      _featureRows.where((r) => r.status != _FeatureStatus.unique).length;
  int get _implemented => _doneCount + _partialCount + _inProgressCount;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor =
        isDark ? const Color(0xFF1A2233) : const Color(0xFFFFFFFF);
    final borderColor =
        isDark ? const Color(0xFF2A3A55) : const Color(0xFFE2E8F0);
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subColor =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      key: const Key('notion_feature_comparison_card'),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- Header (always visible) -----------------------------------
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.compare_arrows,
                        size: 18,
                        color: Color(0xFF6366F1),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'NOTION 機能比較',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: Color(0xFF6366F1),
                          ),
                        ),
                      ),
                      Icon(
                        _expanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        size: 20,
                        color: subColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Summary chips
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _SummaryChip(
                        label: '実装済み',
                        count: _doneCount,
                        color: _FeatureStatus.done.color,
                      ),
                      _SummaryChip(
                        label: '部分実装',
                        count: _partialCount,
                        color: _FeatureStatus.partial.color,
                      ),
                      _SummaryChip(
                        label: '開発中',
                        count: _inProgressCount,
                        color: _FeatureStatus.inProgress.color,
                      ),
                      _SummaryChip(
                        label: '未実装',
                        count: _notYetCount,
                        color: _FeatureStatus.notYet.color,
                      ),
                      _SummaryChip(
                        label: '独自機能',
                        count: _uniqueCount,
                        color: _FeatureStatus.unique.color,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Overall progress bar
                  _OverallProgressBar(
                    implemented: _implemented,
                    total: _totalNotUnique,
                    isDark: isDark,
                    textColor: textColor,
                    subColor: subColor,
                  ),
                ],
              ),
            ),
          ),

          // ---- Expandable body -------------------------------------------
          if (_expanded) ...[
            Divider(
              height: 1,
              color: borderColor,
            ),
            // Category filter chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: _categories.map((cat) {
                  final selected = cat == _filterCategory;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(cat, style: const TextStyle(fontSize: 11)),
                      selected: selected,
                      onSelected: (_) =>
                          setState(() => _filterCategory = cat),
                      selectedColor:
                          const Color(0xFF6366F1).withValues(alpha: 0.15),
                      checkmarkColor: const Color(0xFF6366F1),
                      side: BorderSide(
                        color: selected
                            ? const Color(0xFF6366F1)
                            : borderColor,
                      ),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  );
                }).toList(),
              ),
            ),
            // Feature rows
            ..._buildGroupedRows(
              _filtered,
              textColor: textColor,
              subColor: subColor,
              borderColor: borderColor,
              isDark: isDark,
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildGroupedRows(
    List<_FeatureRow> rows, {
    required Color textColor,
    required Color subColor,
    required Color borderColor,
    required bool isDark,
  }) {
    final groups = <String, List<_FeatureRow>>{};
    for (final row in rows) {
      groups.putIfAbsent(row.category, () => []).add(row);
    }

    final widgets = <Widget>[];
    for (final entry in groups.entries) {
      // Category header
      widgets.add(
        Padding(
          padding:
              const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Text(
            entry.key,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: subColor,
            ),
          ),
        ),
      );
      // Feature rows
      for (final row in entry.value) {
        widgets.add(
          _FeatureRowTile(
            row: row,
            textColor: textColor,
            subColor: subColor,
            borderColor: borderColor,
            isDark: isDark,
          ),
        );
      }
    }
    return widgets;
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _SummaryChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _SummaryChip({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        '$label $count',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _OverallProgressBar extends StatelessWidget {
  final int implemented;
  final int total;
  final bool isDark;
  final Color textColor;
  final Color subColor;

  const _OverallProgressBar({
    required this.implemented,
    required this.total,
    required this.isDark,
    required this.textColor,
    required this.subColor,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (implemented / total * 100).round() : 0;
    final ratio = total > 0 ? (implemented / total).clamp(0.0, 1.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Notion 機能カバー率',
              style: TextStyle(fontSize: 12, color: subColor),
            ),
            const Spacer(),
            Text(
              '$pct%  ($implemented / $total 機能)',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6366F1),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 8,
            backgroundColor: isDark
                ? const Color(0xFF2D3748)
                : const Color(0xFFE2E8F0),
            valueColor: const AlwaysStoppedAnimation<Color>(
              Color(0xFF6366F1),
            ),
          ),
        ),
      ],
    );
  }
}

class _FeatureRowTile extends StatelessWidget {
  final _FeatureRow row;
  final Color textColor;
  final Color subColor;
  final Color borderColor;
  final bool isDark;

  const _FeatureRowTile({
    required this.row,
    required this.textColor,
    required this.subColor,
    required this.borderColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = row.status.color;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0F172A).withValues(alpha: 0.4)
            : Colors.grey.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: row.status == _FeatureStatus.unique
              ? const Color(0xFFA855F7).withValues(alpha: 0.3)
              : borderColor,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status icon
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(row.status.icon, size: 16, color: statusColor),
            ),
            const SizedBox(width: 8),
            // Feature info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          row.feature,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          row.status.label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Notion detail
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notion: ',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: subColor,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          row.notionDetail,
                          style: TextStyle(
                            fontSize: 11,
                            color: subColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  // MyMemo detail
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MyMemo: ',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          row.myMemoDetail,
                          style: TextStyle(
                            fontSize: 11,
                            color: statusColor.withValues(alpha: 0.85),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
