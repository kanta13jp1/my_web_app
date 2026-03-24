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
    _PlanItem(
      label: 'vs MoneyForward',
      target: 15000000,
    ),
    _PlanItem(
      label: 'vs X',
      target: 600000000,
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
// Competitor Feature Comparison Card
// ===========================================================================

/// 実装ステータスの種別
enum _FeatureStatus {
  done, // 実装済み
  partial, // 部分実装
  inProgress, // 開発中
  notYet, // 未実装
  unique, // 自分株式会社 独自機能 (競合にない)
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
  final String competitorDetail;
  final _FeatureStatus status;
  final String appDetail;

  const _FeatureRow({
    required this.category,
    required this.feature,
    required this.competitorDetail,
    required this.status,
    required this.appDetail,
  });
}

// ---------------------------------------------------------------------------
// Feature data — Notion
// ---------------------------------------------------------------------------

const _notionFeatureRows = <_FeatureRow>[
  // ---- ノート編集 ----
  _FeatureRow(
    category: 'ノート編集',
    feature: 'リッチテキスト編集',
    competitorDetail: 'Markdown + スラッシュコマンドでブロック挿入',
    status: _FeatureStatus.done,
    appDetail: 'Markdown 対応エディタ実装済み',
  ),
  _FeatureRow(
    category: 'ノート編集',
    feature: 'AI 文章補助',
    competitorDetail: 'Notion AI: 文章生成・改善・要約',
    status: _FeatureStatus.done,
    appDetail: 'AI Secretary / MAGI System で複数モデル対応',
  ),
  _FeatureRow(
    category: 'ノート編集',
    feature: 'バージョン履歴',
    competitorDetail: '無料プランは7日間、有料は無制限',
    status: _FeatureStatus.notYet,
    appDetail: '未実装 — ロードマップに追加予定',
  ),
  _FeatureRow(
    category: 'ノート編集',
    feature: 'ファイル添付',
    competitorDetail: '画像・PDF 等をブロックとして埋め込み',
    status: _FeatureStatus.notYet,
    appDetail: '未実装',
  ),
  _FeatureRow(
    category: 'ノート編集',
    feature: 'コードブロック',
    competitorDetail: 'シンタックスハイライト付きコードブロック',
    status: _FeatureStatus.partial,
    appDetail: 'Markdown コードフェンス対応済み',
  ),
  // ---- 整理・検索 ----
  _FeatureRow(
    category: '整理・検索',
    feature: 'タグ・カテゴリ',
    competitorDetail: 'ページにタグ付け・フィルタリング',
    status: _FeatureStatus.done,
    appDetail: 'カテゴリページ実装済み',
  ),
  _FeatureRow(
    category: '整理・検索',
    feature: '全文検索',
    competitorDetail: 'ページ横断検索・クイックファインド',
    status: _FeatureStatus.partial,
    appDetail: 'AI 検索・埋め込み検索を部分実装',
  ),
  _FeatureRow(
    category: '整理・検索',
    feature: 'テンプレート',
    competitorDetail: '公式テンプレートギャラリー + コミュニティ共有',
    status: _FeatureStatus.partial,
    appDetail: 'テンプレートマーケットプレイス画面実装済み',
  ),
  // ---- データベース ----
  _FeatureRow(
    category: 'データベース',
    feature: 'テーブルビュー',
    competitorDetail: 'スプレッドシート形式でプロパティ管理',
    status: _FeatureStatus.notYet,
    appDetail: '未実装 — 中期計画で対応予定',
  ),
  _FeatureRow(
    category: 'データベース',
    feature: 'カンバン/ボード',
    competitorDetail: 'ステータス別カードビュー',
    status: _FeatureStatus.notYet,
    appDetail: '未実装 — 中期計画で対応予定',
  ),
  _FeatureRow(
    category: 'データベース',
    feature: 'カレンダービュー',
    competitorDetail: '日付プロパティをカレンダーで表示',
    status: _FeatureStatus.notYet,
    appDetail: '未実装',
  ),
  _FeatureRow(
    category: 'データベース',
    feature: 'ガントチャート',
    competitorDetail: 'タイムラインビューでスケジュール管理',
    status: _FeatureStatus.notYet,
    appDetail: '未実装',
  ),
  _FeatureRow(
    category: 'データベース',
    feature: 'リレーション・ロールアップ',
    competitorDetail: 'DB 間リンクと集計フィールド',
    status: _FeatureStatus.notYet,
    appDetail: '未実装 — 長期計画で対応予定',
  ),
  // ---- 共有・コラボ ----
  _FeatureRow(
    category: '共有・コラボ',
    feature: 'ページ公開',
    competitorDetail: 'URLで誰でも閲覧可能なページ公開',
    status: _FeatureStatus.done,
    appDetail: '公開メモ機能実装済み・OGP対応',
  ),
  _FeatureRow(
    category: '共有・コラボ',
    feature: 'リアルタイム共同編集',
    competitorDetail: '複数人が同時に編集可能',
    status: _FeatureStatus.notYet,
    appDetail: '未実装 — 中期計画 (Team workspace) で対応予定',
  ),
  _FeatureRow(
    category: '共有・コラボ',
    feature: 'コメント・メンション',
    competitorDetail: 'ブロックへのインラインコメント',
    status: _FeatureStatus.notYet,
    appDetail: '未実装',
  ),
  _FeatureRow(
    category: '共有・コラボ',
    feature: 'チームワークスペース',
    competitorDetail: '組織単位でのページ・権限管理',
    status: _FeatureStatus.notYet,
    appDetail: '未実装 — 中期計画で Team/Enterprise 対応予定',
  ),
  // ---- 移行・連携 ----
  _FeatureRow(
    category: '移行・連携',
    feature: 'Notion からインポート',
    competitorDetail: 'Notion 公式はエクスポートのみ提供',
    status: _FeatureStatus.done,
    appDetail: 'CSV インポート実装済み・Edge Function first',
  ),
  _FeatureRow(
    category: '移行・連携',
    feature: 'Evernote からインポート',
    competitorDetail: 'ENEX インポート対応',
    status: _FeatureStatus.done,
    appDetail: 'ENEX インポート実装済み・Edge Function first',
  ),
  _FeatureRow(
    category: '移行・連携',
    feature: 'Markdown インポート',
    competitorDetail: 'Markdown ファイルのインポート可能',
    status: _FeatureStatus.done,
    appDetail: 'Markdown インポート実装済み',
  ),
  _FeatureRow(
    category: '移行・連携',
    feature: 'Web クリッパー',
    competitorDetail: 'ブラウザ拡張でウェブページを保存',
    status: _FeatureStatus.notYet,
    appDetail: '未実装',
  ),
  _FeatureRow(
    category: '移行・連携',
    feature: '外部サービス連携 (Zapier 等)',
    competitorDetail: 'API + Zapier/Make/IFTTT 連携',
    status: _FeatureStatus.partial,
    appDetail: 'Supabase Edge Function 経由で API 公開中',
  ),
  // ---- プラットフォーム ----
  _FeatureRow(
    category: 'プラットフォーム',
    feature: 'Web アプリ',
    competitorDetail: 'ブラウザで全機能利用可能',
    status: _FeatureStatus.done,
    appDetail: 'Flutter Web 実装済み',
  ),
  _FeatureRow(
    category: 'プラットフォーム',
    feature: 'モバイルアプリ (iOS/Android)',
    competitorDetail: 'ネイティブアプリ提供',
    status: _FeatureStatus.inProgress,
    appDetail: 'Flutter クロスプラットフォーム対応可能 — リリース準備中',
  ),
  _FeatureRow(
    category: 'プラットフォーム',
    feature: 'デスクトップアプリ',
    competitorDetail: 'Mac/Windows Electron アプリ',
    status: _FeatureStatus.inProgress,
    appDetail: 'Flutter Desktop 対応可能 — リリース準備中',
  ),
  _FeatureRow(
    category: 'プラットフォーム',
    feature: 'オフライン対応',
    competitorDetail: 'オフラインでも閲覧・編集可能',
    status: _FeatureStatus.notYet,
    appDetail: '未実装 — 長期計画で対応予定',
  ),
  // ---- 自分株式会社 独自機能 ----
  _FeatureRow(
    category: '自分株式会社 独自機能',
    feature: 'マインドマップ',
    competitorDetail: '— Notion にはない機能',
    status: _FeatureStatus.unique,
    appDetail: 'ビジュアルマインドマップ実装済み',
  ),
  _FeatureRow(
    category: '自分株式会社 独自機能',
    feature: '記憶ドリル',
    competitorDetail: '— Notion にはない機能',
    status: _FeatureStatus.unique,
    appDetail: 'スペーシング反復学習ドリル実装済み',
  ),
  _FeatureRow(
    category: '自分株式会社 独自機能',
    feature: 'AI エージェント組織',
    competitorDetail: '— Notion にはない機能',
    status: _FeatureStatus.unique,
    appDetail: 'CEO/CFO/CMO/CHRO 役員会議 AI 実装済み',
  ),
  _FeatureRow(
    category: '自分株式会社 独自機能',
    feature: '経営コックピット',
    competitorDetail: '— Notion にはない機能',
    status: _FeatureStatus.unique,
    appDetail: 'KPI・資産・習慣を一画面で管理',
  ),
  _FeatureRow(
    category: '自分株式会社 独自機能',
    feature: 'Growth ロードマップ進捗表示',
    competitorDetail: '— Notion にはない機能',
    status: _FeatureStatus.unique,
    appDetail: 'このカードがその機能です',
  ),
  _FeatureRow(
    category: '自分株式会社 独自機能',
    feature: 'Referral 紹介プログラム',
    competitorDetail: '— Notion にはない機能',
    status: _FeatureStatus.unique,
    appDetail: 'anti-abuse 付き referral code 発行・管理実装済み',
  ),
];

// ---------------------------------------------------------------------------
// Feature data — EverNote
// ---------------------------------------------------------------------------

const _evernoteFeatureRows = <_FeatureRow>[
  // ---- ノート作成 ----
  _FeatureRow(
    category: 'ノート作成',
    feature: 'リッチテキスト編集',
    competitorDetail: 'フォント・色・レイアウト等のリッチエディタ',
    status: _FeatureStatus.done,
    appDetail: 'Markdown 対応エディタ実装済み',
  ),
  _FeatureRow(
    category: 'ノート作成',
    feature: 'Web クリッパー',
    competitorDetail: 'ブラウザ拡張でウェブページ全体を保存',
    status: _FeatureStatus.notYet,
    appDetail: '未実装',
  ),
  _FeatureRow(
    category: 'ノート作成',
    feature: '手書きメモ / スケッチ',
    competitorDetail: 'タブレット/スタイラスでの手書き入力',
    status: _FeatureStatus.notYet,
    appDetail: '未実装',
  ),
  _FeatureRow(
    category: 'ノート作成',
    feature: '音声メモ',
    competitorDetail: 'マイクで録音した音声をノートに添付',
    status: _FeatureStatus.notYet,
    appDetail: '未実装',
  ),
  _FeatureRow(
    category: 'ノート作成',
    feature: 'PDF 注釈',
    competitorDetail: 'PDF に直接注釈を書き込み',
    status: _FeatureStatus.notYet,
    appDetail: '未実装',
  ),
  // ---- 整理・検索 ----
  _FeatureRow(
    category: '整理・検索',
    feature: 'ノートブック',
    competitorDetail: '階層型ノートブックでノートを分類',
    status: _FeatureStatus.done,
    appDetail: 'カテゴリページ実装済み',
  ),
  _FeatureRow(
    category: '整理・検索',
    feature: 'タグ',
    competitorDetail: '複数タグでノートをクロスカテゴリ管理',
    status: _FeatureStatus.done,
    appDetail: 'タグ機能実装済み',
  ),
  _FeatureRow(
    category: '整理・検索',
    feature: 'スタック (ノートブックグループ)',
    competitorDetail: 'ノートブックをまとめるスタック機能',
    status: _FeatureStatus.notYet,
    appDetail: '未実装',
  ),
  _FeatureRow(
    category: '整理・検索',
    feature: '全文検索',
    competitorDetail: 'ノート本文・添付ファイル・手書きも検索',
    status: _FeatureStatus.partial,
    appDetail: 'AI 検索・埋め込み検索を部分実装',
  ),
  _FeatureRow(
    category: '整理・検索',
    feature: 'OCR (画像内文字検索)',
    competitorDetail: 'スキャンや写真内のテキストを検索可能',
    status: _FeatureStatus.notYet,
    appDetail: '未実装',
  ),
  // ---- タスク・リマインダー ----
  _FeatureRow(
    category: 'タスク・リマインダー',
    feature: 'リマインダー設定',
    competitorDetail: 'ノートに日時リマインダーを設定',
    status: _FeatureStatus.notYet,
    appDetail: '未実装',
  ),
  _FeatureRow(
    category: 'タスク・リマインダー',
    feature: 'タスク管理',
    competitorDetail: 'チェックリスト・締切・担当者付きタスク',
    status: _FeatureStatus.partial,
    appDetail: '習慣トラッカー・KPI 管理で部分対応',
  ),
  _FeatureRow(
    category: 'タスク・リマインダー',
    feature: 'Google カレンダー連携',
    competitorDetail: 'カレンダーイベントをノートに紐付け',
    status: _FeatureStatus.notYet,
    appDetail: '未実装',
  ),
  // ---- 共有 ----
  _FeatureRow(
    category: '共有',
    feature: 'ノート共有 (閲覧リンク)',
    competitorDetail: 'URLで誰でも閲覧可能なノート公開',
    status: _FeatureStatus.done,
    appDetail: '公開メモ機能実装済み・OGP対応',
  ),
  _FeatureRow(
    category: '共有',
    feature: 'ワークチャット',
    competitorDetail: 'Evernote 内でのメッセージ・共有機能',
    status: _FeatureStatus.notYet,
    appDetail: '未実装',
  ),
  _FeatureRow(
    category: '共有',
    feature: 'プレゼンテーションモード',
    competitorDetail: 'ノートをスライド風に全画面表示',
    status: _FeatureStatus.notYet,
    appDetail: '未実装',
  ),
  // ---- プラットフォーム ----
  _FeatureRow(
    category: 'プラットフォーム',
    feature: 'Web アプリ',
    competitorDetail: 'ブラウザで全機能利用可能',
    status: _FeatureStatus.done,
    appDetail: 'Flutter Web 実装済み',
  ),
  _FeatureRow(
    category: 'プラットフォーム',
    feature: 'iOS/Android アプリ',
    competitorDetail: 'ネイティブモバイルアプリ',
    status: _FeatureStatus.inProgress,
    appDetail: 'Flutter クロスプラットフォーム対応可能 — リリース準備中',
  ),
  _FeatureRow(
    category: 'プラットフォーム',
    feature: 'デスクトップアプリ',
    competitorDetail: 'Mac/Windows ネイティブアプリ',
    status: _FeatureStatus.inProgress,
    appDetail: 'Flutter Desktop 対応可能 — リリース準備中',
  ),
  _FeatureRow(
    category: 'プラットフォーム',
    feature: 'オフライン対応',
    competitorDetail: 'オフラインでノートの閲覧・編集が可能',
    status: _FeatureStatus.notYet,
    appDetail: '未実装 — 長期計画で対応予定',
  ),
  // ---- 移行・連携 ----
  _FeatureRow(
    category: '移行・連携',
    feature: 'ENEX エクスポート/インポート',
    competitorDetail: 'Evernote 標準フォーマットで移行対応',
    status: _FeatureStatus.done,
    appDetail: 'ENEX インポート実装済み・Edge Function first',
  ),
  _FeatureRow(
    category: '移行・連携',
    feature: 'Slack / Google Drive 連携',
    competitorDetail: '外部ツールとのファイル共有連携',
    status: _FeatureStatus.partial,
    appDetail: 'Supabase Edge Function 経由で API 公開中',
  ),
  // ---- 自分株式会社 独自機能 ----
  _FeatureRow(
    category: '自分株式会社 独自機能',
    feature: 'AI エージェント組織',
    competitorDetail: '— EverNote にはない機能',
    status: _FeatureStatus.unique,
    appDetail: 'CEO/CFO/CMO/CHRO 役員会議 AI 実装済み',
  ),
  _FeatureRow(
    category: '自分株式会社 独自機能',
    feature: 'マインドマップ',
    competitorDetail: '— EverNote にはない機能',
    status: _FeatureStatus.unique,
    appDetail: 'ビジュアルマインドマップ実装済み',
  ),
  _FeatureRow(
    category: '自分株式会社 独自機能',
    feature: '記憶ドリル (スペーシング反復)',
    competitorDetail: '— EverNote にはない機能',
    status: _FeatureStatus.unique,
    appDetail: 'スペーシング反復学習ドリル実装済み',
  ),
  _FeatureRow(
    category: '自分株式会社 独自機能',
    feature: '経営コックピット',
    competitorDetail: '— EverNote にはない機能',
    status: _FeatureStatus.unique,
    appDetail: 'KPI・資産・習慣を一画面で管理',
  ),
  _FeatureRow(
    category: '自分株式会社 独自機能',
    feature: '家計・資産管理',
    competitorDetail: '— EverNote にはない機能',
    status: _FeatureStatus.unique,
    appDetail: '収支カレンダー・資産管理・月次収支分析実装済み',
  ),
];

// ---------------------------------------------------------------------------
// Feature data — MoneyForward
// ---------------------------------------------------------------------------

const _moneyforwardFeatureRows = <_FeatureRow>[
  // ---- 家計管理 ----
  _FeatureRow(
    category: '家計管理',
    feature: '口座・カード自動連携',
    competitorDetail: '銀行・クレカ・電子マネーを自動取得',
    status: _FeatureStatus.notYet,
    appDetail: '未実装 — 金融 API 連携は長期計画',
  ),
  _FeatureRow(
    category: '家計管理',
    feature: '収支グラフ分析',
    competitorDetail: '月次・カテゴリ別の収支を可視化',
    status: _FeatureStatus.done,
    appDetail: '月間カレンダー収支・KPI ダッシュボード実装済み',
  ),
  _FeatureRow(
    category: '家計管理',
    feature: '自動カテゴリ分類',
    competitorDetail: '取引を AI で自動カテゴリ分け',
    status: _FeatureStatus.notYet,
    appDetail: '未実装',
  ),
  _FeatureRow(
    category: '家計管理',
    feature: 'レシートスキャン',
    competitorDetail: 'カメラでレシートを撮影して自動入力',
    status: _FeatureStatus.notYet,
    appDetail: '未実装',
  ),
  _FeatureRow(
    category: '家計管理',
    feature: '手動収支入力',
    competitorDetail: '手動での収支記録',
    status: _FeatureStatus.done,
    appDetail: '収支入力・振替機能実装済み',
  ),
  // ---- 資産管理 ----
  _FeatureRow(
    category: '資産管理',
    feature: '総資産表示',
    competitorDetail: '全口座の資産合計をリアルタイム表示',
    status: _FeatureStatus.done,
    appDetail: '資産管理画面実装済み',
  ),
  _FeatureRow(
    category: '資産管理',
    feature: '資産推移グラフ',
    competitorDetail: '資産の時系列変化を折れ線グラフで表示',
    status: _FeatureStatus.partial,
    appDetail: 'KPI チャートで部分対応',
  ),
  _FeatureRow(
    category: '資産管理',
    feature: '銀行残高リアルタイム連携',
    competitorDetail: '主要銀行の残高を自動取得',
    status: _FeatureStatus.notYet,
    appDetail: '未実装 — 金融 API 連携は長期計画',
  ),
  _FeatureRow(
    category: '資産管理',
    feature: '証券・株式管理',
    competitorDetail: '株・投信・ETF の保有状況を自動取得',
    status: _FeatureStatus.notYet,
    appDetail: '未実装',
  ),
  _FeatureRow(
    category: '資産管理',
    feature: '年金・iDeCo 管理',
    competitorDetail: '年金ねっと連携で将来受取額を確認',
    status: _FeatureStatus.notYet,
    appDetail: '未実装',
  ),
  // ---- 予算管理 ----
  _FeatureRow(
    category: '予算管理',
    feature: '月次予算設定',
    competitorDetail: 'カテゴリ別に月の支出上限を設定',
    status: _FeatureStatus.partial,
    appDetail: 'KPI 目標設定で部分対応',
  ),
  _FeatureRow(
    category: '予算管理',
    feature: '予実比較',
    competitorDetail: '予算に対して実際の支出を比較表示',
    status: _FeatureStatus.done,
    appDetail: '月間収支カレンダーで収入・支出・差額を表示',
  ),
  // ---- 投資 ----
  _FeatureRow(
    category: '投資',
    feature: '投資運用状況',
    competitorDetail: '保有投資信託・株式の損益を表示',
    status: _FeatureStatus.notYet,
    appDetail: '未実装',
  ),
  _FeatureRow(
    category: '投資',
    feature: 'ポートフォリオ分析',
    competitorDetail: 'アセットクラス別配分をグラフ表示',
    status: _FeatureStatus.notYet,
    appDetail: '未実装',
  ),
  // ---- 税務 ----
  _FeatureRow(
    category: '税務',
    feature: '確定申告サポート',
    competitorDetail: '家計簿データを確定申告に活用',
    status: _FeatureStatus.notYet,
    appDetail: '未実装',
  ),
  _FeatureRow(
    category: '税務',
    feature: 'ふるさと納税管理',
    competitorDetail: '寄付記録・控除額計算をサポート',
    status: _FeatureStatus.notYet,
    appDetail: '未実装',
  ),
  // ---- プラットフォーム ----
  _FeatureRow(
    category: 'プラットフォーム',
    feature: 'Web アプリ',
    competitorDetail: 'ブラウザで全機能利用可能',
    status: _FeatureStatus.done,
    appDetail: 'Flutter Web 実装済み',
  ),
  _FeatureRow(
    category: 'プラットフォーム',
    feature: 'iOS/Android アプリ',
    competitorDetail: 'ネイティブモバイルアプリ',
    status: _FeatureStatus.inProgress,
    appDetail: 'Flutter クロスプラットフォーム対応可能 — リリース準備中',
  ),
  // ---- 自分株式会社 独自機能 ----
  _FeatureRow(
    category: '自分株式会社 独自機能',
    feature: 'AI エージェント組織 (CFO 含む)',
    competitorDetail: '— MoneyForward にはない機能',
    status: _FeatureStatus.unique,
    appDetail: 'CFO AI による財務分析・アドバイス実装済み',
  ),
  _FeatureRow(
    category: '自分株式会社 独自機能',
    feature: 'ノートメモ機能',
    competitorDetail: '— MoneyForward にはない機能',
    status: _FeatureStatus.unique,
    appDetail: 'Markdown メモ・AI 整理・公開メモ実装済み',
  ),
  _FeatureRow(
    category: '自分株式会社 独自機能',
    feature: 'マインドマップ',
    competitorDetail: '— MoneyForward にはない機能',
    status: _FeatureStatus.unique,
    appDetail: 'ビジュアルマインドマップ実装済み',
  ),
  _FeatureRow(
    category: '自分株式会社 独自機能',
    feature: '記憶ドリル',
    competitorDetail: '— MoneyForward にはない機能',
    status: _FeatureStatus.unique,
    appDetail: 'スペーシング反復学習ドリル実装済み',
  ),
  _FeatureRow(
    category: '自分株式会社 独自機能',
    feature: 'Growth ロードマップ進捗表示',
    competitorDetail: '— MoneyForward にはない機能',
    status: _FeatureStatus.unique,
    appDetail: 'このカードがその機能です',
  ),
];

// ---------------------------------------------------------------------------
// Feature data — X (Twitter)
// ---------------------------------------------------------------------------

const _xFeatureRows = <_FeatureRow>[
  // ---- 投稿・コンテンツ ----
  _FeatureRow(
    category: '投稿・コンテンツ',
    feature: 'テキスト投稿',
    competitorDetail: '最大4000文字 (Premium) / 280文字 (無料)',
    status: _FeatureStatus.done,
    appDetail: 'Markdown ノート作成実装済み (文字数制限なし)',
  ),
  _FeatureRow(
    category: '投稿・コンテンツ',
    feature: '画像・動画添付',
    competitorDetail: '最大4枚の画像、または動画を投稿に添付',
    status: _FeatureStatus.notYet,
    appDetail: '未実装',
  ),
  _FeatureRow(
    category: '投稿・コンテンツ',
    feature: 'スレッド投稿',
    competitorDetail: '連続ポストをスレッドとして繋げる',
    status: _FeatureStatus.notYet,
    appDetail: '未実装 — ノートのリンク機能で代替可能',
  ),
  _FeatureRow(
    category: '投稿・コンテンツ',
    feature: 'ポーリング (投票)',
    competitorDetail: '最大4択の投票をポストに埋め込み',
    status: _FeatureStatus.notYet,
    appDetail: '未実装',
  ),
  _FeatureRow(
    category: '投稿・コンテンツ',
    feature: '引用ポスト',
    competitorDetail: '他ユーザーのポストにコメントを添えて共有',
    status: _FeatureStatus.notYet,
    appDetail: '未実装',
  ),
  // ---- タイムライン・発見 ----
  _FeatureRow(
    category: 'タイムライン・発見',
    feature: 'アルゴリズムタイムライン',
    competitorDetail: 'エンゲージメント予測に基づくコンテンツ推薦',
    status: _FeatureStatus.notYet,
    appDetail: '未実装 — 長期計画でレコメンドエンジン対応予定',
  ),
  _FeatureRow(
    category: 'タイムライン・発見',
    feature: 'トレンド',
    competitorDetail: '地域・世界のリアルタイムトレンドを表示',
    status: _FeatureStatus.notYet,
    appDetail: '未実装',
  ),
  _FeatureRow(
    category: 'タイムライン・発見',
    feature: 'ハッシュタグ',
    competitorDetail: 'ハッシュタグでコンテンツを横断検索',
    status: _FeatureStatus.partial,
    appDetail: 'タグ機能実装済み (クロスカテゴリ検索で代替)',
  ),
  _FeatureRow(
    category: 'タイムライン・発見',
    feature: '全文・ユーザー検索',
    competitorDetail: 'キーワード・ユーザー・日付・メディアで絞り込み検索',
    status: _FeatureStatus.partial,
    appDetail: 'AI 埋め込み検索を部分実装',
  ),
  // ---- エンゲージメント ----
  _FeatureRow(
    category: 'エンゲージメント',
    feature: 'いいね',
    competitorDetail: 'ポストへのリアクション (いいね)',
    status: _FeatureStatus.notYet,
    appDetail: '未実装',
  ),
  _FeatureRow(
    category: 'エンゲージメント',
    feature: 'リポスト',
    competitorDetail: '他ユーザーのポストをそのまま拡散',
    status: _FeatureStatus.notYet,
    appDetail: '未実装',
  ),
  _FeatureRow(
    category: 'エンゲージメント',
    feature: 'リプライ',
    competitorDetail: 'ポストへの返信',
    status: _FeatureStatus.notYet,
    appDetail: '未実装',
  ),
  _FeatureRow(
    category: 'エンゲージメント',
    feature: 'ブックマーク',
    competitorDetail: 'ポストを非公開でコレクションに保存',
    status: _FeatureStatus.done,
    appDetail: 'ノートへの保存・お気に入り機能実装済み',
  ),
  // ---- コミュニケーション ----
  _FeatureRow(
    category: 'コミュニケーション',
    feature: 'ダイレクトメッセージ (DM)',
    competitorDetail: '1対1またはグループでのプライベートメッセージ',
    status: _FeatureStatus.notYet,
    appDetail: '未実装',
  ),
  _FeatureRow(
    category: 'コミュニケーション',
    feature: 'X スペース (音声ライブ)',
    competitorDetail: 'リアルタイム音声配信・参加',
    status: _FeatureStatus.notYet,
    appDetail: '未実装',
  ),
  // ---- コミュニティ ----
  _FeatureRow(
    category: 'コミュニティ',
    feature: 'コミュニティ機能',
    competitorDetail: 'テーマ別のクローズドグループを作成・参加',
    status: _FeatureStatus.notYet,
    appDetail: '未実装 — チームワークスペースで中期対応予定',
  ),
  _FeatureRow(
    category: 'コミュニティ',
    feature: 'フォロー/フォロワー',
    competitorDetail: 'ユーザー間の非対称フォロー関係',
    status: _FeatureStatus.notYet,
    appDetail: '未実装',
  ),
  // ---- 収益化 ----
  _FeatureRow(
    category: '収益化',
    feature: 'X Premium (有料プラン)',
    competitorDetail: '長文投稿・認証バッジ・広告収益分配',
    status: _FeatureStatus.inProgress,
    appDetail: 'Pro/Team/Enterprise プラン設計中',
  ),
  _FeatureRow(
    category: '収益化',
    feature: 'Super Follows (有料フォロー)',
    competitorDetail: '有料フォロワーへの限定コンテンツ配信',
    status: _FeatureStatus.notYet,
    appDetail: '未実装 — 中長期計画でコンテンツ収益化対応予定',
  ),
  _FeatureRow(
    category: '収益化',
    feature: '広告収益分配',
    competitorDetail: 'Premium ユーザーの広告インプレッション収益分配',
    status: _FeatureStatus.notYet,
    appDetail: '未実装',
  ),
  // ---- プラットフォーム ----
  _FeatureRow(
    category: 'プラットフォーム',
    feature: 'Web アプリ',
    competitorDetail: 'ブラウザで全機能利用可能',
    status: _FeatureStatus.done,
    appDetail: 'Flutter Web 実装済み',
  ),
  _FeatureRow(
    category: 'プラットフォーム',
    feature: 'iOS/Android アプリ',
    competitorDetail: 'ネイティブモバイルアプリ',
    status: _FeatureStatus.inProgress,
    appDetail: 'Flutter クロスプラットフォーム対応可能 — リリース準備中',
  ),
  // ---- 自分株式会社 独自機能 ----
  _FeatureRow(
    category: '自分株式会社 独自機能',
    feature: 'AI エージェント組織',
    competitorDetail: '— X にはない機能',
    status: _FeatureStatus.unique,
    appDetail: 'CEO/CFO/CMO/CHRO 役員会議 AI 実装済み',
  ),
  _FeatureRow(
    category: '自分株式会社 独自機能',
    feature: '長文プライベートノート管理',
    competitorDetail: '— X は短文パブリック投稿が主軸',
    status: _FeatureStatus.unique,
    appDetail: 'Markdown ノート・カテゴリ・AI 整理実装済み',
  ),
  _FeatureRow(
    category: '自分株式会社 独自機能',
    feature: '家計・資産管理',
    competitorDetail: '— X にはない機能',
    status: _FeatureStatus.unique,
    appDetail: '収支カレンダー・資産管理・月次収支分析実装済み',
  ),
  _FeatureRow(
    category: '自分株式会社 独自機能',
    feature: 'マインドマップ',
    competitorDetail: '— X にはない機能',
    status: _FeatureStatus.unique,
    appDetail: 'ビジュアルマインドマップ実装済み',
  ),
  _FeatureRow(
    category: '自分株式会社 独自機能',
    feature: '記憶ドリル (スペーシング反復)',
    competitorDetail: '— X にはない機能',
    status: _FeatureStatus.unique,
    appDetail: 'スペーシング反復学習ドリル実装済み',
  ),
  _FeatureRow(
    category: '自分株式会社 独自機能',
    feature: 'Growth ロードマップ進捗表示',
    competitorDetail: '— X にはない機能',
    status: _FeatureStatus.unique,
    appDetail: 'このカードがその機能です',
  ),
];

// ---------------------------------------------------------------------------
// Widget
// ---------------------------------------------------------------------------

/// 競合4社 (Notion / EverNote / MoneyForward / X) の機能一覧と
/// 自分株式会社 の実装状況を比較表示するカード。
class CompetitorFeatureComparisonCard extends StatefulWidget {
  const CompetitorFeatureComparisonCard({super.key});

  @override
  State<CompetitorFeatureComparisonCard> createState() =>
      _CompetitorFeatureComparisonCardState();
}

// Keep old name as alias for backward compatibility
typedef NotionFeatureComparisonCard = CompetitorFeatureComparisonCard;

class _CompetitorFeatureComparisonCardState
    extends State<CompetitorFeatureComparisonCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late TabController _tabController;

  static const _competitors = ['Notion', 'EverNote', 'MoneyForward', 'X'];
  static const _featureLists = [
    _notionFeatureRows,
    _evernoteFeatureRows,
    _moneyforwardFeatureRows,
    _xFeatureRows,
  ];

  String _filterCategory = 'すべて';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _competitors.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _filterCategory = 'すべて');
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<_FeatureRow> get _currentRows =>
      _featureLists[_tabController.index];

  List<String> get _categories {
    final cats = <String>['すべて'];
    for (final row in _currentRows) {
      if (!cats.contains(row.category)) cats.add(row.category);
    }
    return cats;
  }

  List<_FeatureRow> get _filtered => _filterCategory == 'すべて'
      ? _currentRows
      : _currentRows.where((r) => r.category == _filterCategory).toList();

  int _doneCount(List<_FeatureRow> rows) =>
      rows.where((r) => r.status == _FeatureStatus.done).length;
  int _partialCount(List<_FeatureRow> rows) =>
      rows.where((r) => r.status == _FeatureStatus.partial).length;
  int _inProgressCount(List<_FeatureRow> rows) =>
      rows.where((r) => r.status == _FeatureStatus.inProgress).length;
  int _notYetCount(List<_FeatureRow> rows) =>
      rows.where((r) => r.status == _FeatureStatus.notYet).length;
  int _uniqueCount(List<_FeatureRow> rows) =>
      rows.where((r) => r.status == _FeatureStatus.unique).length;
  int _totalNotUnique(List<_FeatureRow> rows) =>
      rows.where((r) => r.status != _FeatureStatus.unique).length;
  int _implemented(List<_FeatureRow> rows) =>
      _doneCount(rows) + _partialCount(rows) + _inProgressCount(rows);

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

    final rows = _currentRows;

    return Container(
      key: const Key('competitor_feature_comparison_card'),
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
                          '競合機能比較',
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
                        count: _doneCount(rows),
                        color: _FeatureStatus.done.color,
                      ),
                      _SummaryChip(
                        label: '部分実装',
                        count: _partialCount(rows),
                        color: _FeatureStatus.partial.color,
                      ),
                      _SummaryChip(
                        label: '開発中',
                        count: _inProgressCount(rows),
                        color: _FeatureStatus.inProgress.color,
                      ),
                      _SummaryChip(
                        label: '未実装',
                        count: _notYetCount(rows),
                        color: _FeatureStatus.notYet.color,
                      ),
                      _SummaryChip(
                        label: '独自機能',
                        count: _uniqueCount(rows),
                        color: _FeatureStatus.unique.color,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Overall progress bar
                  _OverallProgressBar(
                    implemented: _implemented(rows),
                    total: _totalNotUnique(rows),
                    competitorName:
                        _competitors[_tabController.index],
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
            Divider(height: 1, color: borderColor),
            // Tab bar
            TabBar(
              controller: _tabController,
              onTap: (_) => setState(() => _filterCategory = 'すべて'),
              tabs: _competitors
                  .map((c) => Tab(
                        child: Text(
                          c,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),)
                  .toList(),
              labelColor: const Color(0xFF6366F1),
              unselectedLabelColor: subColor,
              indicatorColor: const Color(0xFF6366F1),
              indicatorSize: TabBarIndicatorSize.label,
              dividerColor: borderColor,
              padding: EdgeInsets.zero,
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
              competitorName: _competitors[_tabController.index],
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
    required String competitorName,
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
      widgets.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
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
      for (final row in entry.value) {
        widgets.add(
          _FeatureRowTile(
            row: row,
            competitorName: competitorName,
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
  final String competitorName;
  final bool isDark;
  final Color textColor;
  final Color subColor;

  const _OverallProgressBar({
    required this.implemented,
    required this.total,
    required this.competitorName,
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
              '$competitorName 機能カバー率',
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
  final String competitorName;
  final Color textColor;
  final Color subColor;
  final Color borderColor;
  final bool isDark;

  const _FeatureRowTile({
    required this.row,
    required this.competitorName,
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
                  // Competitor detail
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$competitorName: ',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: subColor,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          row.competitorDetail,
                          style: TextStyle(
                            fontSize: 11,
                            color: subColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  // 自分株式会社 detail
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '自分株式会社: ',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          row.appDetail,
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
