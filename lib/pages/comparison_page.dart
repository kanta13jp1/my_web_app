import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/growth_acquisition_service.dart';

/// Competitor-specific comparison landing page.
/// Each competitor gets a dedicated route (/vs-notion, /vs-evernote, …)
/// so organic search traffic for "Notion代替", "Evernote代替", etc. lands on
/// a page that speaks directly to that user's context.
class ComparisonPage extends StatefulWidget {
  final String competitorKey;

  const ComparisonPage({super.key, required this.competitorKey});

  @override
  State<ComparisonPage> createState() => _ComparisonPageState();
}

class _ComparisonPageState extends State<ComparisonPage> {
  String? _pricingTier;
  double? _pricingStartUsd;
  String? _pricingNotesJa;
  String? _japanPresenceLevel;

  @override
  void initState() {
    super.initState();
    unawaited(_fetchDbOverlay());
  }

  Future<void> _fetchDbOverlay() async {
    try {
      final data = await Supabase.instance.client
          .from('competitors')
          .select(
            'pricing_tier, pricing_start_usd, pricing_notes_ja, japan_presence_level',
          )
          .eq('id', widget.competitorKey.toLowerCase())
          .maybeSingle();
      if (data != null && mounted) {
        setState(() {
          _pricingTier = data['pricing_tier'] as String?;
          final rawUsd = data['pricing_start_usd'];
          _pricingStartUsd = rawUsd != null ? (rawUsd as num).toDouble() : null;
          _pricingNotesJa = data['pricing_notes_ja'] as String?;
          _japanPresenceLevel = data['japan_presence_level'] as String?;
        });
      }
    } catch (_) {
      // フォールバック: const map のみで表示
    }
  }

  @override
  Widget build(BuildContext context) {
    final info =
        _competitorInfo[widget.competitorKey.toLowerCase()] ?? _defaultInfo;
    return _ComparisonShell(
      info: info,
      competitorKey: widget.competitorKey.toLowerCase(),
      pricingTier: _pricingTier,
      pricingStartUsd: _pricingStartUsd,
      pricingNotesJa: _pricingNotesJa,
      japanPresenceLevel: _japanPresenceLevel,
    );
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
  accentColor: Color(0xFF4F46E5),
  painPoints: ['複数サービスへのログインが面倒', 'データが分散して管理しにくい', '月額料金が積み重なる'],
  features: [
    _FeatureComparison(
      feature: 'タスク管理',
      competitorHas: true,
      weHave: true,
    ),
    _FeatureComparison(
      feature: 'AI サポート',
      competitorHas: false,
      weHave: true,
    ),
    _FeatureComparison(
      feature: '完全無料',
      competitorHas: false,
      weHave: true,
    ),
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
      _FeatureComparison(
        feature: 'メモ・ノート作成',
        competitorHas: true,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'データベース / テーブル',
        competitorHas: true,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'AI 自動整理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '資産・家計管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '完全無料（制限なし）',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'Notion データインポート',
        competitorHas: true,
        weHave: true,
      ),
    ],
  ),
  'evernote': const _CompetitorInfo(
    name: 'Evernote',
    emoji: '🐘',
    tagline: 'Evernoteは2026-04からノート1,000件上限。自分株式会社は無制限＋AI整理で移行先筆頭。',
    searchKeyword: 'Evernote代替 Evernote移行 EvernoteAlternative',
    accentColor: Color(0xFF00A82D),
    painPoints: [
      'ノート件数: 2026-04施行の無料プラン上限1,000件 — 15年ユーザーが大量離脱中',
      'デバイス2台まで・月額600円〜のプレミアムに移行しないとノートが見られなくなる',
      'AI機能なし・手動タグ整理のみ — 自分株式会社はAIタグ自動付与で整理ゼロ',
    ],
    features: [
      _FeatureComparison(
        feature: 'メモ・ノート管理',
        competitorHas: true,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '画像・添付ファイル管理',
        competitorHas: true,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'AI タグ自動付与',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '公開メモ共有',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '完全無料（デバイス制限なし）',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'ノート件数: 無制限 (Evernoteは1,000件上限)',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'ENEX インポート (既存ノートをそのまま移行)',
        competitorHas: true,
        weHave: true,
      ),
    ],
  ),
  'moneyforward': const _CompetitorInfo(
    name: 'MoneyForward',
    emoji: '💰',
    tagline:
        'MoneyForward AI Cowork (2026-07 GA) は法人バックオフィス特化。自分株式会社は個人・フリーランスの財務部署AI。',
    searchKeyword: 'MoneyForward代替 MoneyForwardAICowork代替',
    accentColor: Color(0xFF0D47A1),
    painPoints: [
      'MoneyForward AI Cowork は法人 5,000席以上・バックオフィス向け — 個人・フリーランスは対象外',
      '無料プランは連携口座数 4 件まで・プレミアム月額 500 円〜',
      '資産管理のみでタスク・ノート・AI大学・習慣管理は別アプリが必要',
    ],
    features: [
      _FeatureComparison(
        feature: '収支・家計管理',
        competitorHas: true,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '資産残高把握',
        competitorHas: true,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '個人・フリーランス向け財務AI (先月比・改善提案)',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'タスク・ノート・習慣と財務の部署横断連携',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '完全無料（口座数制限なし）',
        competitorHas: false,
        weHave: true,
      ),
    ],
  ),
  'slack': const _CompetitorInfo(
    name: 'Slack (Agentforce)',
    emoji: '💬',
    tagline: 'Salesforce Agentforce搭載AIが仕事を代行。でも個人の人生6部署は扱えない。',
    searchKeyword: 'Slack代替 SlackAgentforce代替',
    accentColor: Color(0xFF4A154B),
    painPoints: [
      'Agentforce利用にはBusiness+ \$15/seat/月〜が必要 (約¥2,250〜)',
      '企業・チーム向けで個人利用には過剰・高コスト',
      '仕事のコミュニケーション特化で健康・家計・習慣は対象外',
    ],
    features: [
      _FeatureComparison(
        feature: 'メッセージ・チャット',
        competitorHas: true,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'メッセージ履歴無制限',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'ノート・メモ統合',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'AI 会話まとめ',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '完全無料',
        competitorHas: false,
        weHave: true,
      ),
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
      _FeatureComparison(
        feature: 'ビジネスチャット',
        competitorHas: true,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'タスク管理',
        competitorHas: true,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'ノート・メモ統合',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'AI サポート',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '完全無料',
        competitorHas: false,
        weHave: true,
      ),
    ],
  ),
  'x': const _CompetitorInfo(
    name: 'X (Twitter)',
    emoji: '𝕏',
    tagline: 'SNS 発信 × 知識管理をひとつに。フォロワーゼロでも価値を蓄える。',
    searchKeyword: 'X代替 Twitter代替',
    accentColor: Color(0xFF1C1C1E),
    painPoints: [
      'X は140文字の制限で深い思考を記録しにくい',
      'Xプレミアムは月額980円〜',
      '投稿は流れてしまい知識として蓄積されない',
    ],
    features: [
      _FeatureComparison(
        feature: '長文・短文メモ',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'AI 要約・整理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '公開共有（OGP付き）',
        competitorHas: true,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '思考の蓄積・検索',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '完全無料',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'Markdown 対応',
        competitorHas: false,
        weHave: true,
      ),
    ],
  ),
  'animaworks': const _CompetitorInfo(
    name: 'Animaworks',
    emoji: '🎯',
    tagline: '習慣化 × 目標管理 × AI コーチング。完全無料で始める自己成長。',
    searchKeyword: 'Animaworks代替 習慣管理アプリ代替',
    accentColor: Color(0xFFFF6B35),
    painPoints: [
      '習慣アプリは習慣だけ管理できてもメモや資産管理は別アプリが必要',
      '月額課金が続くと習慣以上にコストの習慣化になる',
      '成長の振り返りがデータとして蓄積されない',
    ],
    features: [
      _FeatureComparison(
        feature: '習慣トラッキング',
        competitorHas: true,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '目標設定・進捗管理',
        competitorHas: true,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'AI コーチング',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'ノート・メモ統合',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '資産管理連携',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '完全無料',
        competitorHas: false,
        weHave: true,
      ),
    ],
  ),
  'claude-code': const _CompetitorInfo(
    name: 'Claude Code',
    emoji: '🤖',
    tagline: 'AI コーディング支援 × 知識管理 × 成長記録を1つに。無料で。',
    searchKeyword: 'Claude Code代替 AIコーディングツール代替',
    accentColor: Color(0xFFD97706),
    painPoints: [
      'Claude Code は開発専用で個人の知識蓄積・成長管理ができない',
      'コーディング以外の業務や思考を記録する場所がない',
      '開発実績や成長を可視化・共有する仕組みがない',
    ],
    features: [
      _FeatureComparison(
        feature: 'AI コーディング支援',
        competitorHas: true,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '開発実績の記録・可視化',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'ノート・アイデア管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '成長ロードマップ追跡',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'AI 朝ブリーフィング',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '完全無料',
        competitorHas: false,
        weHave: true,
      ),
    ],
  ),
  'codex': const _CompetitorInfo(
    name: 'Codex',
    emoji: '⚡',
    tagline: 'AI コード生成を超えた、知識と成長の統合プラットフォーム。',
    searchKeyword: 'Codex代替 OpenAI Codex代替',
    accentColor: Color(0xFF10B981),
    painPoints: [
      'Codex はコード生成特化で個人の知識・成長管理ができない',
      'API 利用コストが継続的に発生する',
      '生成したコードや知見を体系的に蓄積・検索する手段がない',
    ],
    features: [
      _FeatureComparison(
        feature: 'AI コード生成',
        competitorHas: true,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'コード・アイデアの蓄積',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '技術ブログ投稿管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '成長ミッション追跡',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '公開メモ共有（OGP）',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '完全無料',
        competitorHas: false,
        weHave: true,
      ),
    ],
  ),
  'netkeiba': const _CompetitorInfo(
    name: 'netkeiba',
    emoji: '🐎',
    tagline: '情熱を知識に変える。記録・分析・共有をひとつに。完全無料。',
    searchKeyword: 'netkeiba代替 競馬情報サイト代替',
    accentColor: Color(0xFF7C3AED),
    painPoints: [
      'netkeiba プレミアムは月額660円〜',
      '競馬以外の情報・知識管理は別アプリが必要',
      '分析データを自分の資産として蓄積する仕組みがない',
    ],
    features: [
      _FeatureComparison(
        feature: '情報収集・閲覧',
        competitorHas: true,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'AI 分析・要約',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'ノートへの記録・蓄積',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '公開メモ共有',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '資産・収支管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '完全無料',
        competitorHas: false,
        weHave: true,
      ),
    ],
  ),
  'openclaw': const _CompetitorInfo(
    name: 'OpenClaw',
    emoji: '🦾',
    tagline: '自律 AI エージェントの力を、個人の成長管理に。完全無料で。',
    searchKeyword: 'OpenClaw代替 AIエージェント代替',
    accentColor: Color(0xFF0EA5E9),
    painPoints: [
      '自律 AI エージェントは設定・運用が複雑でエンジニア向け',
      '個人の知識蓄積や成長管理には適していない',
      '継続利用には API コストが必要',
    ],
    features: [
      _FeatureComparison(
        feature: 'AI エージェント実行',
        competitorHas: true,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '個人向け AI 朝ブリーフィング',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'ノート・メモ統合管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '成長ロードマップ可視化',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'ノーコードで即利用可能',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '完全無料',
        competitorHas: false,
        weHave: true,
      ),
    ],
  ),
  'claude-cowork': const _CompetitorInfo(
    name: 'Claude Cowork',
    emoji: '🏛️',
    tagline: 'Anthropic公式AIワークスペース。でも仕事のみ・データ揮発・月\$20〜。',
    searchKeyword: 'Claude Cowork代替 Anthropic Cowork代替',
    accentColor: Color(0xFF6366F1),
    painPoints: [
      'Pro \$20/月〜 (Max \$100〜) — 個人利用でも課金が継続発生',
      '分離VM内で動作するためセッション終了でデータが消える',
      '仕事SaaS連携のみで財務・健康・習慣・KPI管理は対象外',
    ],
    features: [
      _FeatureComparison(
        feature: 'AI ワークスペース',
        competitorHas: true,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '個人向け AI 組織OS',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '資産・家計管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '成長ミッション追跡',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'ノート・公開メモ',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '完全無料（個人利用）',
        competitorHas: false,
        weHave: true,
      ),
    ],
  ),
  'jobcan': const _CompetitorInfo(
    name: 'ジョブカン',
    emoji: '📋',
    tagline: 'バックオフィス管理を個人にも。勤怠・経費・成長を1アプリで。',
    searchKeyword: 'ジョブカン代替 バックオフィスツール代替',
    accentColor: Color(0xFF059669),
    painPoints: [
      'ジョブカンは法人向けで個人・フリーランスには高額',
      '機能ごとに別モジュール購入が必要（月額200円〜/人×モジュール数）',
      'バックオフィス管理と知識管理・成長管理は完全に分断されている',
    ],
    features: [
      _FeatureComparison(
        feature: '勤怠・タスク管理',
        competitorHas: true,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '経費・収支管理',
        competitorHas: true,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'AI 業務サポート',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'ノート・ナレッジ管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '個人向け無料プラン',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '完全無料',
        competitorHas: false,
        weHave: true,
      ),
    ],
  ),
  'amazon': const _CompetitorInfo(
    name: 'Amazon',
    emoji: '📦',
    tagline: 'Alexa・Kindle・Amazon家計管理を1つに。完全無料で使う自分株式会社。',
    searchKeyword: 'Amazon代替 Alexa代替 Kindle代替',
    accentColor: Color(0xFFFF9900),
    painPoints: [
      'Amazonのサービスは機能ごとに分散しており一元管理できない（Alexa・Kindle・Photos・Business）',
      'Amazon Prime は年額6,000円〜、Kindleアンリミテッドは月額980円〜とコストが積み重なる',
      '購買記録・読書記録・タスク・メモを統合して管理する手段がない',
    ],
    features: [
      _FeatureComparison(
        feature: 'AIアシスタント (Alexa/Gemini)',
        competitorHas: true,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '読書・ナレッジ管理 (Kindle相当)',
        competitorHas: true,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '購買・支出の記録と資産管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'ノート・メモ・タスク統合',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '習慣化・成長ロードマップ',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '完全無料',
        competitorHas: false,
        weHave: true,
      ),
    ],
  ),
  'google': const _CompetitorInfo(
    name: 'Google',
    emoji: '🔍',
    tagline: 'Google Planner Gem はメール・カレンダーのみ。自分株式会社は財務・健康・習慣・6部署を一元管理。',
    searchKeyword: 'Google代替 GoogleKeep代替 GoogleWorkspace代替 GeminiPlanner代替',
    accentColor: Color(0xFF4285F4),
    painPoints: [
      'Google Planner Gem (2026-04 GA) はGmail/Calendar/Driveのみ — Workspace外データを統合できない',
      'Google Keep・Tasks・Calendar・Docsがバラバラで横断的な生産性管理ができない',
      'Google Workspace は月額680円〜、資産管理・習慣管理・AI大学などライフ全体をカバーしない',
    ],
    features: [
      _FeatureComparison(
        feature: 'AIアシスタント (Gemini相当)',
        competitorHas: true,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'メモ・ノート管理 (Keep相当)',
        competitorHas: true,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'タスク・ToDo管理 (Tasks相当)',
        competitorHas: true,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '資産・家計管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '習慣化・成長ロードマップ',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'Workspace外データ統合 (財務・健康・習慣)',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '広告なし・完全無料',
        competitorHas: false,
        weHave: true,
      ),
    ],
  ),
  'google_agent_builder': const _CompetitorInfo(
    name: 'Google Agent Builder',
    emoji: '🤖',
    tagline: 'Google Agent Builder はコード必須の開発者ツール。自分株式会社はノーコードで個人の人生6部署を無料管理。',
    searchKeyword: 'GoogleAgentBuilder代替 Vertex AI Agent代替 Gemini Agent代替',
    accentColor: Color(0xFF4285F4),
    painPoints: [
      'Python/JSのコーディング知識が必須 — 非エンジニアには利用不可',
      'GCP従量課金 (Vertex AI) — 個人利用でも予測できないコスト発生リスク',
      '業務ワークフロー特化で、健康・習慣・家計など個人の6部署を管理できない',
    ],
    features: [
      _FeatureComparison(
        feature: 'ノーコード操作',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'Gemini AIアシスタント',
        competitorHas: true,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '日本語ネイティブUI',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '個人の6部署統合 (健康・財務・習慣)',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '予測可能な完全無料',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'マルチステップAIエージェント',
        competitorHas: true,
        weHave: true,
      ),
    ],
  ),
  'microsoft': const _CompetitorInfo(
    name: 'Microsoft',
    emoji: '🪟',
    tagline: 'OneNote・To Do・Copilot を1つに。完全無料の自分株式会社。',
    searchKeyword: 'Microsoft代替 OneNote代替 MicrosoftToDo代替 Copilot代替',
    accentColor: Color(0xFF00A4EF),
    painPoints: [
      'OneNote・To Do・Teams・Outlookがサイロ化しており統合的なライフ管理ができない',
      'Microsoft 365 Personal は年額14,900円、Business Basic は月額750円〜と高コスト',
      'AIコパイロット機能は上位プランに限定されており個人ユーザーには敷居が高い',
    ],
    features: [
      _FeatureComparison(
        feature: 'AIアシスタント (Copilot相当)',
        competitorHas: true,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'ノート管理 (OneNote相当)',
        competitorHas: true,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'タスク管理 (To Do相当)',
        competitorHas: true,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '資産・家計管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '習慣化・成長ロードマップ',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '完全無料',
        competitorHas: false,
        weHave: true,
      ),
    ],
  ),
  'discord': const _CompetitorInfo(
    name: 'Discord',
    emoji: '🎮',
    tagline: 'Discordのコミュニティ機能を超えた、個人の生産性AIアプリ。完全無料。',
    searchKeyword: 'Discord代替 Discordコミュニティ代替',
    accentColor: Color(0xFF5865F2),
    painPoints: [
      'Discordはチャット・コミュニティ特化で、個人のタスク管理や資産管理には使えない',
      'Nitro (月額1,100円〜) がなければファイルサイズ制限や画質制限がある',
      'メモ・習慣化・成長管理など個人の生産性向上ツールとしての機能が皆無',
    ],
    features: [
      _FeatureComparison(
        feature: 'コミュニティ/チャット',
        competitorHas: true,
        weHave: false,
      ),
      _FeatureComparison(
        feature: 'AIアシスタント',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'タスク・習慣管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '資産・家計管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '成長ロードマップ',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '完全無料 (Nitro不要)',
        competitorHas: false,
        weHave: true,
      ),
    ],
  ),
  'line': const _CompetitorInfo(
    name: 'LINE',
    emoji: '💚',
    tagline: 'LINEのメッセージ機能を超えた、AI統合の個人生産性アプリ。完全無料。',
    searchKeyword: 'LINE代替 LINEメモ代替 LINEスケジュール代替',
    accentColor: Color(0xFF06C755),
    painPoints: [
      'LINEはメッセージ・通話特化で、タスク管理・資産管理・習慣化機能がほぼない',
      'LINE VOOM・KeepメモはAI機能ゼロで、個人の生産性向上ツールとして力不足',
      'LINEビジネス機能 (LINE公式アカウント等) は月額5,000円〜と高コスト',
    ],
    features: [
      _FeatureComparison(
        feature: 'メッセージ・通話',
        competitorHas: true,
        weHave: false,
      ),
      _FeatureComparison(
        feature: 'AIアシスタント',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'タスク・習慣管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'メモ・ノート (Keep相当)',
        competitorHas: true,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '資産・家計管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '成長ロードマップ・自己分析',
        competitorHas: false,
        weHave: true,
      ),
    ],
  ),
  'facebook': const _CompetitorInfo(
    name: 'Facebook',
    emoji: '👥',
    tagline: 'Facebookのソーシャル機能を超えた、AI統合の個人生産性アプリ。完全無料。',
    searchKeyword: 'Facebook代替 Facebook個人管理代替 Meta代替',
    accentColor: Color(0xFF1877F2),
    painPoints: [
      'Facebookはソーシャル・広告に特化し、個人の生産性管理・メモ・資産管理機能がない',
      'プライバシー問題・個人データの広告活用への懸念が根強く、機密情報を書けない',
      'Facebookメモ・グループ機能は基本的で、AI活用・習慣化管理ツールとしては力不足',
    ],
    features: [
      _FeatureComparison(
        feature: 'SNS・コミュニティ',
        competitorHas: true,
        weHave: false,
      ),
      _FeatureComparison(
        feature: 'AIアシスタント (Meta AI)',
        competitorHas: true,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'タスク・習慣管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'メモ・ノート管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '資産・家計管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '広告なし・完全無料・プライバシー保護',
        competitorHas: false,
        weHave: true,
      ),
    ],
  ),
  'github': const _CompetitorInfo(
    name: 'GitHub',
    emoji: '🐙',
    tagline: 'GitHubのコード管理・コラボレーション機能を超えた、AI統合の個人生産性アプリ。完全無料。',
    searchKeyword: 'GitHub代替 ギットハブ代替 コード管理代替 開発者ツール代替',
    accentColor: Color(0xFF24292E),
    painPoints: [
      'GitHubはコード管理・開発者コラボレーションに特化し、日常の個人タスク・資産管理・習慣化には対応していない',
      'GitHubのプロジェクト管理はエンジニア向けで、一般ユーザーの生活全般の管理には不向き',
      'GitHubはコード以外のメモ・目標管理・AIアシスタント機能が欠けている',
    ],
    features: [
      _FeatureComparison(
        feature: 'コードリポジトリ管理',
        competitorHas: true,
        weHave: false,
      ),
      _FeatureComparison(
        feature: 'Pull Request・コードレビュー',
        competitorHas: true,
        weHave: false,
      ),
      _FeatureComparison(
        feature: 'CI/CDパイプライン',
        competitorHas: true,
        weHave: false,
      ),
      _FeatureComparison(
        feature: 'タスク・習慣管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'AIアシスタント',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '資産・家計管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'メモ・ノート管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '完全無料・広告なし',
        competitorHas: false,
        weHave: true,
      ),
    ],
  ),
  'liven': const _CompetitorInfo(
    name: 'Liven',
    emoji: '🍽️',
    tagline: 'Livenの飲食・ロイヤルティ機能を超えた、AI統合の個人生産性アプリ。完全無料。',
    searchKeyword: 'Liven代替 ライブン代替 飲食ロイヤルティ代替 外食管理代替',
    accentColor: Color(0xFFFF6B35),
    painPoints: [
      'Livenは飲食店の注文・ポイント管理に特化し、個人の生産性・資産管理・AIアシスタント機能がない',
      '対応店舗が限られており、日常の全タスク・習慣管理には使えない',
      'Livenのデータは飲食消費に偏り、個人の成長・目標達成・メモ管理のツールとしては力不足',
    ],
    features: [
      _FeatureComparison(
        feature: '飲食注文・デリバリー',
        competitorHas: true,
        weHave: false,
      ),
      _FeatureComparison(
        feature: 'ポイント・ロイヤルティプログラム',
        competitorHas: true,
        weHave: false,
      ),
      _FeatureComparison(
        feature: 'タスク・習慣管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'AIアシスタント',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '資産・家計管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'メモ・ノート管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '完全無料・広告なし',
        competitorHas: false,
        weHave: true,
      ),
    ],
  ),
  // -----------------------------------------------------------------------
  // PS#4 S77: 高脅威競合 追加エントリ (wildcard /vs-* router 対応)
  // -----------------------------------------------------------------------
  'notion-ai': const _CompetitorInfo(
    name: 'Notion AI',
    emoji: '🤖',
    tagline: 'Notion AI は文書AIに特化。自分株式会社は個人の6部署すべてをAIで統括する生活OS。',
    searchKeyword: 'NotionAI代替 Notion AI代替 ドキュメントAI代替',
    accentColor: Color(0xFF1F2937),
    painPoints: [
      'Notion AI は月額\$10のアドオン — ノート・Wiki生成が中心でタスク・財務・健康管理は別アプリが必要',
      'Notion は組織・チーム向け設計で、個人CEO的な自律ライフ運営の概念がない',
      '日本 DC (2026-05予定) 開設でエンタープライズ向けに強化されるが個人ユーザーの価格は変わらない',
    ],
    features: [
      _FeatureComparison(
        feature: 'AIドキュメント生成・要約',
        competitorHas: true,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'AIタスク自動整理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '個人財務管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '習慣・健康トラッキング',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'AI大学 (250+社AIツール学習)',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '完全無料（AIも追加料金なし）',
        competitorHas: false,
        weHave: true,
      ),
    ],
  ),
  'openai': const _CompetitorInfo(
    name: 'OpenAI / ChatGPT',
    emoji: '🧠',
    tagline: 'ChatGPTは最強のAIだが、あなたの生活データを記憶・管理できない。自分株式会社はAI×ライフOSの統合体。',
    searchKeyword: 'ChatGPT代替 OpenAI代替 GPT-4代替 AIアシスタント代替',
    accentColor: Color(0xFF10A37F),
    painPoints: [
      'ChatGPT Plus \$20/月 — 会話は賢いが家計・タスク・習慣のデータが蓄積されず毎回ゼロから始まる',
      '個人の資産・ToDo・健康データと連携した「文脈あるAI相談」ができない',
      'AI大学的な学習管理・競合モニタリング・WBSダッシュボードの統合がない',
    ],
    features: [
      _FeatureComparison(
        feature: '汎用AIチャット・文章生成',
        competitorHas: true,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '個人データ連携AI (家計・タスク文脈)',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'AIタスク・目標管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '個人資産・家計トラッキング',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'AI大学 (250+社AIツール学習)',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '無料で始められる',
        competitorHas: true,
        weHave: true,
      ),
    ],
  ),
  'anthropic': const _CompetitorInfo(
    name: 'Anthropic / Claude',
    emoji: '🔶',
    tagline:
        'Claude は最高の推論AIだが、あなたの人生データを統合管理できない。自分株式会社はClaude APIを内部で活用する生活OS。',
    searchKeyword: 'Claude代替 Anthropic代替 Claudeアシスタント代替',
    accentColor: Color(0xFFD97706),
    painPoints: [
      'Claude Pro \$20/月 — 安全性・推論力は最高クラスだが個人データ蓄積・ライフトラッキング機能がない',
      'Claude.ai は会話AIに特化。財務管理・タスク管理・習慣化との統合が不足',
      '自分株式会社は Claude API を内部活用しており、将来的な AI 性能向上の恩恵を自動的に受けられる',
    ],
    features: [
      _FeatureComparison(
        feature: '高精度AIチャット・分析',
        competitorHas: true,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'ライフデータ統合AIアシスタント',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '個人WBS・目標管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '家計・資産トラッキング',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'AI大学学習ログ管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '無料プランあり',
        competitorHas: true,
        weHave: true,
      ),
    ],
  ),
  'cursor': const _CompetitorInfo(
    name: 'Cursor',
    emoji: '⌨️',
    tagline: 'Cursor はコード生成AI IDE。自分株式会社はコード以外の「人生」全体をAIで管理するOS。',
    searchKeyword: 'Cursor代替 CursorIDE代替 AIコードエディタ代替',
    accentColor: Color(0xFF7C3AED),
    painPoints: [
      'Cursor Pro \$20/月 — 開発者向けコードAIで、家計・健康・習慣・目標管理の機能が全くない',
      'コーディング以外の日常タスク・財務・AI大学学習を一元管理できない',
      '開発者以外には無縁のツール — 自分株式会社はノンエンジニアも含む全ライフカテゴリをカバー',
    ],
    features: [
      _FeatureComparison(
        feature: 'AIコード補完・生成',
        competitorHas: true,
        weHave: false,
      ),
      _FeatureComparison(
        feature: 'タスク・プロジェクト管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '個人財務・家計管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'AI学習ログ・AI大学',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '習慣トラッキング',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '完全無料プランあり',
        competitorHas: true,
        weHave: true,
      ),
    ],
  ),
  'perplexity': const _CompetitorInfo(
    name: 'Perplexity AI',
    emoji: '🔍',
    tagline: 'Perplexityは最高のAI検索エンジン。自分株式会社はあなたの人生データを土台にした「個人専用AI秘書」。',
    searchKeyword: 'Perplexity代替 PerplexityAI代替 AI検索代替 AIリサーチ代替',
    accentColor: Color(0xFF0EA5E9),
    painPoints: [
      'Perplexity Pro \$20/月 — Web検索AIとして優秀だが、個人の財務・タスク・健康データを蓄積・管理できない',
      '「今の天気は?」に答えられても「今月の支出はどうだった?」には答えられない',
      'リサーチツールであり、個人の行動・習慣・目標との統合がない',
    ],
    features: [
      _FeatureComparison(
        feature: 'Web検索 + AI要約',
        competitorHas: true,
        weHave: false,
      ),
      _FeatureComparison(
        feature: '個人データ連携AI',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'タスク・習慣管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '家計・資産管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'AI大学 (250+社AIツール学習)',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '無料で始められる',
        competitorHas: true,
        weHave: true,
      ),
    ],
  ),
  'figma': const _CompetitorInfo(
    name: 'Figma',
    emoji: '🎨',
    tagline: 'Figmaはデザインコラボツール。自分株式会社はデザイン以外の人生全体をAIで最適化する個人OS。',
    searchKeyword: 'Figma代替 UIデザイン代替 プロトタイピング代替',
    accentColor: Color(0xFFF24E1E),
    painPoints: [
      'Figma Starter \$12/editor/月 — デザイン・UI作成専門ツールで、個人の財務・タスク・健康管理機能がない',
      'デザイナー以外には適合しないプロフェッショナルツール',
      'チーム向け設計で個人のライフOS的な使い方は想定されていない',
    ],
    features: [
      _FeatureComparison(
        feature: 'UI/UXデザイン・プロトタイプ',
        competitorHas: true,
        weHave: false,
      ),
      _FeatureComparison(
        feature: 'タスク・プロジェクト管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '個人財務・家計管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'AIアシスタント統合',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '習慣・健康トラッキング',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '無料プランあり',
        competitorHas: true,
        weHave: true,
      ),
    ],
  ),
  'freee': const _CompetitorInfo(
    name: 'freee',
    emoji: '📊',
    tagline: 'freeeは中小企業の会計・バックオフィスDX。自分株式会社は個人・フリーランスのライフ全体をAIで最適化。',
    searchKeyword: 'freee代替 フリー代替 クラウド会計代替 個人確定申告代替',
    accentColor: Color(0xFF00B900),
    painPoints: [
      'freee会計 ¥980/月〜 — 会計・請求書・給与に特化し、個人のライフスタイル管理・習慣・AI大学学習との統合がない',
      '確定申告・税務処理は優秀だが、日常のタスク管理・健康・目標設定は別アプリが必要',
      'フリーランス・個人事業主向けだが「人生の財務部長」として機能するのは自分株式会社',
    ],
    features: [
      _FeatureComparison(
        feature: 'クラウド会計・確定申告',
        competitorHas: true,
        weHave: false,
      ),
      _FeatureComparison(
        feature: '個人家計・資産トラッキング',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'AIアシスタント (財務相談)',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'タスク・習慣管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '無料プランあり',
        competitorHas: true,
        weHave: true,
      ),
    ],
  ),
  'smarthr': const _CompetitorInfo(
    name: 'SmartHR',
    emoji: '👥',
    tagline: 'SmartHRは企業人事DXの王者。自分株式会社は個人が自分自身のHRを管理する個人人事部AI。',
    searchKeyword: 'SmartHR代替 クラウド人事代替 勤怠管理代替',
    accentColor: Color(0xFF0077C7),
    painPoints: [
      'SmartHR ¥600〜/employee/月 — 企業向け人事労務SaaSで個人ユーザーは対象外',
      '企業の入退社・給与・評価管理に特化し、個人のキャリア目標・スキル学習・副業管理との統合がない',
      '自分株式会社の「人事部署AI」は個人が自分のスキル・目標・学習記録を自律管理できる唯一の設計',
    ],
    features: [
      _FeatureComparison(
        feature: '企業向け人事労務管理',
        competitorHas: true,
        weHave: false,
      ),
      _FeatureComparison(
        feature: '個人スキル・目標管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'AI大学 (キャリアスキル学習)',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'タスク・WBS管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '完全無料',
        competitorHas: false,
        weHave: true,
      ),
    ],
  ),
  'zoom': const _CompetitorInfo(
    name: 'Zoom',
    emoji: '📹',
    tagline: 'ZoomはビデオMTGの定番。自分株式会社は会議を含む「仕事×生活×学習」を統合するライフOS。',
    searchKeyword: 'Zoom代替 ビデオ会議代替 Web会議代替',
    accentColor: Color(0xFF2D8CFF),
    painPoints: [
      'Zoom Pro \$15.99/月 — ビデオ会議に特化し、タスク管理・家計・習慣・AI学習との統合がない',
      '会議履歴やメモはZoom内で完結し、個人の目標・プロジェクト管理に繋がらない',
      'AIサマリー機能(Zoom AI Companion)はあるが個人のライフ全体と連携しない',
    ],
    features: [
      _FeatureComparison(
        feature: 'ビデオ会議・ウェビナー',
        competitorHas: true,
        weHave: false,
      ),
      _FeatureComparison(
        feature: 'タスク・プロジェクト管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'AI大学 (学習管理)',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '個人財務・家計管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '習慣・健康トラッキング',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '無料プランあり',
        competitorHas: true,
        weHave: true,
      ),
    ],
  ),
  'shopify': const _CompetitorInfo(
    name: 'Shopify',
    emoji: '🛍️',
    tagline: 'ShopifyはECサイト構築の王者。自分株式会社はECを含む個人のビジネス×生活全体をAIで最適化。',
    searchKeyword: 'Shopify代替 ECサイト代替 ネットショップ代替',
    accentColor: Color(0xFF96BF48),
    painPoints: [
      'Shopify Basic \$29/月 — ECサイト構築・商品管理に特化し、個人の財務全体・タスク・健康管理との統合がない',
      '販売者向けツールで、購入者の個人ライフ管理や目標設定との接続がない',
      '副業・ハンドメイド販売の管理はできるが、個人のライフスタイル最適化には不十分',
    ],
    features: [
      _FeatureComparison(
        feature: 'ECサイト構築・商品管理',
        competitorHas: true,
        weHave: false,
      ),
      _FeatureComparison(
        feature: '個人財務・収支管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'タスク・目標管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'AIアシスタント',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '無料トライアルあり',
        competitorHas: true,
        weHave: true,
      ),
    ],
  ),
  'canva': const _CompetitorInfo(
    name: 'Canva',
    emoji: '🖌️',
    tagline: 'Canvaはデザイン民主化の先駆者。自分株式会社はデザイン以外の「人生全体」をAIで最適化する個人OS。',
    searchKeyword: 'Canva代替 オンラインデザイン代替 グラフィックデザイン代替',
    accentColor: Color(0xFF7D2AE8),
    painPoints: [
      'Canva Pro \$12.99/月 — グラフィック・プレゼン作成に特化し、個人の財務・タスク・健康管理との統合がない',
      'クリエイター向けツールで、個人のライフスタイル管理・目標設定・AI学習との接続がない',
      'チームコラボはできるが、個人のWBS・習慣・資産管理は別アプリが必要',
    ],
    features: [
      _FeatureComparison(
        feature: 'グラフィック・プレゼン作成',
        competitorHas: true,
        weHave: false,
      ),
      _FeatureComparison(
        feature: 'タスク・目標管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '個人財務・家計管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'AIアシスタント統合',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '無料プランあり',
        competitorHas: true,
        weHave: true,
      ),
    ],
  ),
  'mercari': const _CompetitorInfo(
    name: 'メルカリ',
    emoji: '🏪',
    tagline: 'メルカリは日本最大のフリマアプリ。自分株式会社は不要品売却を含む個人の資産・収支全体をAIで管理。',
    searchKeyword: 'メルカリ代替 フリマ代替 不用品売却代替',
    accentColor: Color(0xFFFF0211),
    painPoints: [
      'メルカリは売買取引に特化 — 売上金の家計全体への統合・税務管理・資産トラッキングができない',
      '不要品売却の記録が個人の財務ダッシュボードに自動反映されない',
      '副収入としての売上をタスク・目標管理と紐付けられないため「副業CEO」的な管理が不可能',
    ],
    features: [
      _FeatureComparison(
        feature: 'フリマ・中古品売買',
        competitorHas: true,
        weHave: false,
      ),
      _FeatureComparison(
        feature: '個人収支・資産管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'タスク・副業管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'AIアシスタント',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '無料で始められる',
        competitorHas: true,
        weHave: true,
      ),
    ],
  ),
  'rakuten': const _CompetitorInfo(
    name: '楽天グループ',
    emoji: '🛒',
    tagline: '楽天はEC・金融・通信の複合サービス群。自分株式会社は楽天サービスを含む個人の全取引・資産をAIで一元管理。',
    searchKeyword: '楽天代替 楽天市場代替 楽天経済圏代替',
    accentColor: Color(0xFFBF0000),
    painPoints: [
      '楽天は個別サービス(市場/銀行/カード/モバイル)の集合体 — 横断的な個人財務ダッシュボードが存在しない',
      '楽天ポイント・銀行残高・カード明細が分散し、資産全体を俯瞰できない',
      '楽天経済圏の最適化はできるが、タスク・習慣・健康・AI学習との統合がない',
    ],
    features: [
      _FeatureComparison(
        feature: 'EC・金融・通信サービス群',
        competitorHas: true,
        weHave: false,
      ),
      _FeatureComparison(
        feature: '個人資産・収支一元管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'AIアシスタント統合',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'タスク・習慣管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'AI大学 (学習管理)',
        competitorHas: false,
        weHave: true,
      ),
    ],
  ),
  'salesforce': const _CompetitorInfo(
    name: 'Salesforce',
    emoji: '☁️',
    tagline: 'SalesforceはCRMの王者。自分株式会社は個人が「自分自身の顧客」として人生全体をCRM的にAI管理する個人OS。',
    searchKeyword: 'Salesforce代替 CRM代替 顧客管理代替',
    accentColor: Color(0xFF00A1E0),
    painPoints: [
      'Salesforce Starter \$25/user/月〜 — 企業向けCRMで個人ユーザーには高すぎ・複雑すぎる',
      '営業・顧客管理に最適化されており、個人の家計・健康・習慣・AI学習との統合がない',
      'Agentforce(AI)はエンタープライズ向け — 個人の「人生CEO」的なAI活用とは設計思想が異なる',
    ],
    features: [
      _FeatureComparison(
        feature: '企業向けCRM・営業管理',
        competitorHas: true,
        weHave: false,
      ),
      _FeatureComparison(
        feature: '個人タスク・目標管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '個人財務・家計管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'AI大学 (学習管理)',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '完全無料',
        competitorHas: false,
        weHave: true,
      ),
    ],
  ),
  'windsurf': const _CompetitorInfo(
    name: 'Windsurf (Codeium)',
    emoji: '🏄',
    tagline: 'Windsurfは次世代AI IDEの挑戦者。自分株式会社はコーディング以外の人生全体をAI化する個人OS。',
    searchKeyword: 'Windsurf代替 Codeium代替 AI IDE代替 Cursor代替',
    accentColor: Color(0xFF5C6BC0),
    painPoints: [
      'Windsurf Pro \$15/月 — AI IDEとして開発者に特化し、家計・健康・習慣・目標管理は対象外',
      'Cursor同様、コーディング以外の日常タスク・財務管理・AI大学学習を一元管理できない',
      '開発者専用ツール — 自分株式会社はノンエンジニアも含む全ライフカテゴリをカバー',
    ],
    features: [
      _FeatureComparison(
        feature: 'AIコード補完・エージェント',
        competitorHas: true,
        weHave: false,
      ),
      _FeatureComparison(
        feature: 'タスク・プロジェクト管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '個人財務・家計管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'AI学習ログ・AI大学',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '習慣・健康トラッキング',
        competitorHas: false,
        weHave: true,
      ),
    ],
  ),
  'clickup': const _CompetitorInfo(
    name: 'ClickUp',
    emoji: '📋',
    tagline: 'ClickUpはオールインワンプロジェクト管理ツール。自分株式会社はタスク管理に加えAI・財務・健康を統合した個人OS。',
    searchKeyword: 'ClickUp代替 タスク管理代替 プロジェクト管理代替 Asana代替',
    accentColor: Color(0xFF7B68EE),
    painPoints: [
      'ClickUp Unlimited \$7/user/月 — チーム向け設計でタスク管理は優秀だが個人の財務・健康・AI学習との統合がない',
      '機能が多すぎて個人用途には過剰 — 自分株式会社は個人CEO視点で設計された必要十分なUI',
      'AI機能は別料金(\$5/月追加) — 自分株式会社はAI機能を無料で統合提供',
    ],
    features: [
      _FeatureComparison(
        feature: 'タスク・プロジェクト管理',
        competitorHas: true,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '個人財務・家計管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'AIアシスタント統合 (無料)',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '習慣・健康トラッキング',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'AI大学 (学習管理)',
        competitorHas: false,
        weHave: true,
      ),
    ],
  ),
  'airtable': const _CompetitorInfo(
    name: 'Airtable',
    emoji: '📊',
    tagline: 'Airtableはローコードデータベース。自分株式会社はデータベース構築不要で個人の全情報をAIが自動管理。',
    searchKeyword: 'Airtable代替 データベース代替 スプレッドシート代替 ノーコード代替',
    accentColor: Color(0xFF18BFFF),
    painPoints: [
      'Airtable Plus \$10/user/月 — 柔軟なデータベースだが設計・構築に時間がかかり個人での即時活用が難しい',
      'スプレッドシート的な管理は手動入力が前提 — AIによる自動入力・提案は限定的',
      '財務・健康・タスクを統合するには複数のベースを自分で設計する必要がある',
    ],
    features: [
      _FeatureComparison(
        feature: 'カスタムデータベース構築',
        competitorHas: true,
        weHave: false,
      ),
      _FeatureComparison(
        feature: 'ゼロ設定でAIが自動管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '個人財務・資産管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'AIアシスタント統合',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '無料プランあり',
        competitorHas: true,
        weHave: true,
      ),
    ],
  ),
  'miro': const _CompetitorInfo(
    name: 'Miro',
    emoji: '🎯',
    tagline: 'Miroはビジュアルコラボレーションの王者。自分株式会社はビジョンボード・WBSを含む個人の計画全体をAIで管理。',
    searchKeyword: 'Miro代替 ホワイトボード代替 マインドマップ代替 ビジュアル計画代替',
    accentColor: Color(0xFFFFD02F),
    painPoints: [
      'Miro Starter \$10/month — チームコラボ向けホワイトボードで個人の財務・習慣・AI学習との統合がない',
      'アイデア・計画の可視化は得意だが、実行管理・振り返り・データ蓄積が弱い',
      '個人の長期ビジョンと日常タスクを繋ぐ「実行OS」としての機能がない',
    ],
    features: [
      _FeatureComparison(
        feature: 'ビジュアルボード・マインドマップ',
        competitorHas: true,
        weHave: false,
      ),
      _FeatureComparison(
        feature: 'タスク実行・習慣トラッキング',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '個人財務・家計管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'AIアシスタント統合',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '無料プランあり',
        competitorHas: true,
        weHave: true,
      ),
    ],
  ),
  'obsidian': const _CompetitorInfo(
    name: 'Obsidian',
    emoji: '🔮',
    tagline: 'ObsidianはPKM(個人知識管理)の最高峰。自分株式会社はノートに留まらず財務・タスク・健康をAIで統合管理。',
    searchKeyword: 'Obsidian代替 PKM代替 ノート代替 個人知識管理代替',
    accentColor: Color(0xFF7E6AD2),
    painPoints: [
      'Obsidian無料 / Sync \$4/月 — MarkdownベースのPKMで財務管理・習慣トラッキング・AIアシスタントは別アプリが必要',
      'プラグイン設定に時間がかかり、非エンジニアには敷居が高い',
      'ローカルファイルベースのため、モバイル同期・チーム共有・AIクエリが標準では不十分',
    ],
    features: [
      _FeatureComparison(
        feature: 'PKM・マークダウンノート',
        competitorHas: true,
        weHave: false,
      ),
      _FeatureComparison(
        feature: 'AIアシスタント統合 (無料)',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '個人財務・資産管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'タスク・習慣管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '設定ゼロで即利用',
        competitorHas: false,
        weHave: true,
      ),
    ],
  ),
  'grammarly': const _CompetitorInfo(
    name: 'Grammarly',
    emoji: '✍️',
    tagline: 'GrammarlyはAI文章校正の王者。自分株式会社はライティング支援を含む個人の情報発信・学習・生活全体をAI化。',
    searchKeyword: 'Grammarly代替 文章校正代替 AIライティング代替',
    accentColor: Color(0xFF15C39A),
    painPoints: [
      'Grammarly Pro \$12/月 — 英文校正・文章改善に特化し、タスク・財務・習慣・AI大学学習との統合がない',
      '文章を「書く」ことは支援するが、アイデアの「管理・実行・振り返り」のサポートがない',
      '英語が主対象で、日本語での個人ライフ管理・目標設定には不向き',
    ],
    features: [
      _FeatureComparison(
        feature: 'AI文章校正・改善',
        competitorHas: true,
        weHave: false,
      ),
      _FeatureComparison(
        feature: 'タスク・目標管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '個人財務・家計管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'AI大学 (学習管理)',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '無料プランあり',
        competitorHas: true,
        weHave: true,
      ),
    ],
  ),
  'duolingo': const _CompetitorInfo(
    name: 'Duolingo',
    emoji: '🦉',
    tagline:
        'Duolingoは語学学習のゲーミフィケーション先駆者。自分株式会社はAI大学で250+社のAIツール学習を同様の継続仕組みで提供。',
    searchKeyword: 'Duolingo代替 語学学習代替 学習アプリ代替 eラーニング代替',
    accentColor: Color(0xFF58CC02),
    painPoints: [
      'Duolingo Plus \$6.99/月 — 語学専門で、AIツール学習・キャリアスキル・財務・習慣管理との統合がない',
      '学習の継続仕組みは優秀だが、学んだことを実務・財務・目標設定と繋げる機能がない',
      '自分株式会社のAI大学は250+社のAIツールを体系的に学べ、実際の業務改善に直結する設計',
    ],
    features: [
      _FeatureComparison(
        feature: '語学・スキル学習ゲーミフィケーション',
        competitorHas: true,
        weHave: false,
      ),
      _FeatureComparison(
        feature: 'AI大学 (250+社AIツール学習)',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'タスク・目標管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '個人財務管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '無料プランあり',
        competitorHas: true,
        weHave: true,
      ),
    ],
  ),
  'udemy': const _CompetitorInfo(
    name: 'Udemy',
    emoji: '🎓',
    tagline: 'Udemyは世界最大のオンライン学習マーケット。自分株式会社のAI大学はAIツールに特化した無料・継続学習プラットフォーム。',
    searchKeyword: 'Udemy代替 オンライン学習代替 eラーニング代替 スキルアップ代替',
    accentColor: Color(0xFFA435F0),
    painPoints: [
      'Udemy講座 ¥1,500〜¥27,000/講座 — 体系的コースは優秀だが個人の財務・タスク・習慣管理との統合がない',
      '学習記録が個人のWBS・目標設定・キャリア計画と連動しない',
      '自分株式会社のAI大学は250+社を無料で学べ、学習ログが自動記録されてタスク・目標と紐付く',
    ],
    features: [
      _FeatureComparison(
        feature: '体系的オンラインコース',
        competitorHas: true,
        weHave: false,
      ),
      _FeatureComparison(
        feature: 'AI大学 (250+社AIツール・無料)',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '学習ログ×目標管理連携',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '個人財務・家計管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '無料で始められる',
        competitorHas: false,
        weHave: true,
      ),
    ],
  ),
  'dropbox': const _CompetitorInfo(
    name: 'Dropbox',
    emoji: '📦',
    tagline: 'Dropboxはファイルストレージの先駆者。自分株式会社はファイル管理を超えた個人の全情報・知識・計画をAIで統合管理。',
    searchKeyword: 'Dropbox代替 クラウドストレージ代替 ファイル共有代替',
    accentColor: Color(0xFF0061FE),
    painPoints: [
      'Dropbox Plus \$9.99/月 — クラウドストレージとして安定しているが財務・タスク・習慣・AI学習との統合がない',
      'ファイルを「保存」するが、その内容を元にAIが行動提案・目標管理を行う機能がない',
      '個人のライフOS的な役割は持たず、単なるバックアップ・同期ツールに留まる',
    ],
    features: [
      _FeatureComparison(
        feature: 'クラウドストレージ・同期',
        competitorHas: true,
        weHave: false,
      ),
      _FeatureComparison(
        feature: 'タスク・目標管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '個人財務・家計管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'AIアシスタント統合',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '無料プランあり',
        competitorHas: true,
        weHave: true,
      ),
    ],
  ),
  'teams': const _CompetitorInfo(
    name: 'Microsoft Teams',
    emoji: '💼',
    tagline:
        'Microsoft Teamsは企業コラボの定番。自分株式会社はTeamsを含む全コミュニケーション・仕事・生活をAIで一元管理。',
    searchKeyword: 'Microsoft Teams代替 ビジネスチャット代替 テレワーク代替',
    accentColor: Color(0xFF6264A7),
    painPoints: [
      'Teams無料 / Microsoft 365 \$6/user/月〜 — 企業向けコラボで個人の財務・健康・習慣・AI学習との統合がない',
      'ビジネスコミュニケーションに特化しており、個人CEO的な自律ライフ管理の概念がない',
      'Microsoft 365との連携は強いが、個人のライフ全体を俯瞰する個人OS的機能がない',
    ],
    features: [
      _FeatureComparison(
        feature: 'ビジネスチャット・ビデオ会議',
        competitorHas: true,
        weHave: false,
      ),
      _FeatureComparison(
        feature: '個人タスク・習慣管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '個人財務・資産管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'AI大学 (学習管理)',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '完全無料プランあり',
        competitorHas: true,
        weHave: true,
      ),
    ],
  ),
  'linear': const _CompetitorInfo(
    name: 'Linear',
    emoji: '📐',
    tagline:
        'LinearはエンジニアチームのためのモダンIssueトラッカー。自分株式会社は個人のすべての目標・タスクをAIで管理する個人OS。',
    searchKeyword: 'Linear代替 Issue管理代替 プロジェクト管理代替 Jira代替',
    accentColor: Color(0xFF5E6AD2),
    painPoints: [
      'Linear Plus \$8/user/月 — ソフトウェア開発チーム向けで個人の財務・健康・習慣管理の概念がない',
      'スプリント・サイクル管理は優秀だが、個人の目標・家計・学習・健康との統合がない',
      'エンジニアチーム専用設計 — 自分株式会社は全職種・個人ユーザーに対応',
    ],
    features: [
      _FeatureComparison(
        feature: 'ソフトウェア開発Issue管理',
        competitorHas: true,
        weHave: false,
      ),
      _FeatureComparison(
        feature: '個人WBS・目標管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '個人財務・家計管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'AIアシスタント統合',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '完全無料',
        competitorHas: false,
        weHave: true,
      ),
    ],
  ),
  'hubspot': const _CompetitorInfo(
    name: 'HubSpot',
    emoji: '🧲',
    tagline: 'HubSpotはインバウンドマーケティングCRMの王者。自分株式会社は個人が「自分自身のマーケター」としてライフ全体をAI管理。',
    searchKeyword: 'HubSpot代替 CRM代替 マーケティング自動化代替',
    accentColor: Color(0xFFFF7A59),
    painPoints: [
      'HubSpot Starter \$15/user/月〜 — マーケティング・営業CRM特化で個人の財務・習慣・AI学習との統合がない',
      '企業の顧客獲得に最適化されており、個人のライフスタイル管理・目標設定には不向き',
      'フリープランはあるが機能制限が多く、個人CEOとしてフル活用するには有料プランが必要',
    ],
    features: [
      _FeatureComparison(
        feature: 'CRM・マーケティング自動化',
        competitorHas: true,
        weHave: false,
      ),
      _FeatureComparison(
        feature: '個人タスク・目標管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '個人財務・家計管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'AI大学 (学習管理)',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '無料プランあり',
        competitorHas: true,
        weHave: true,
      ),
    ],
  ),
  'coda': const _CompetitorInfo(
    name: 'Coda',
    emoji: '📄',
    tagline:
        'CodaはドキュメントとデータベースとアプリをひとつにするAll-in-One。自分株式会社はAI×生活全体の統合OSとして一歩先を行く。',
    searchKeyword: 'Coda代替 ドキュメントDB代替 Notion代替 ノーコード代替',
    accentColor: Color(0xFFE55A2B),
    painPoints: [
      'Coda Pro \$10/user/月 — 柔軟なDoc/DBだが設計に時間がかかり財務・健康・AI学習は別途構築が必要',
      'AI機能(Coda AI)は有料プランのみ — 自分株式会社はAI機能を無料から統合提供',
      '個人の全ライフカテゴリを統合管理するには複数のページを自分で設計する必要がある',
    ],
    features: [
      _FeatureComparison(
        feature: 'カスタムDoc/DB/アプリ構築',
        competitorHas: true,
        weHave: false,
      ),
      _FeatureComparison(
        feature: 'ゼロ設定でAI管理開始',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '個人財務・家計管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'AIアシスタント (無料)',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '無料プランあり',
        competitorHas: true,
        weHave: true,
      ),
    ],
  ),
  'atlassian': const _CompetitorInfo(
    name: 'Atlassian (Jira / Confluence)',
    emoji: '🗂️',
    tagline:
        'AtlassianはJira/Confluenceでソフトウェア開発の王者。自分株式会社は開発以外の「人生プロジェクト」を個人CEOとして管理。',
    searchKeyword: 'Jira代替 Confluence代替 プロジェクト管理代替 Atlassian代替',
    accentColor: Color(0xFF0052CC),
    painPoints: [
      'Jira Standard \$7.75/user/月 — ソフトウェア開発チーム向けで複雑すぎ、個人ユーザーには過剰',
      '個人の財務・健康・習慣・AI学習の統合管理という概念がなく設定コストが高い',
      'エンジニア以外には敷居が高い — 自分株式会社はノンエンジニア含む全ライフカテゴリをカバー',
    ],
    features: [
      _FeatureComparison(
        feature: 'ソフトウェア開発PM',
        competitorHas: true,
        weHave: false,
      ),
      _FeatureComparison(
        feature: '個人WBS・目標管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '個人財務・家計管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'AIアシスタント統合',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '完全無料',
        competitorHas: false,
        weHave: true,
      ),
    ],
  ),
  'replit': const _CompetitorInfo(
    name: 'Replit',
    emoji: '💻',
    tagline: 'Replitはブラウザ完結型AI開発環境。自分株式会社はコーディング以外の「人生OS」として全カテゴリをAIで管理。',
    searchKeyword: 'Replit代替 ブラウザIDE代替 AIコーディング代替',
    accentColor: Color(0xFFF5821B),
    painPoints: [
      'Replit Core \$20/月 — AI開発環境として優秀だが個人の財務・習慣・目標・AI大学学習との統合がない',
      'コーディング以外の日常タスク・家計・健康管理は対象外のツール',
      '開発者専用 — 自分株式会社はノンエンジニアも含む全ライフカテゴリをカバー',
    ],
    features: [
      _FeatureComparison(
        feature: 'ブラウザAI開発環境',
        competitorHas: true,
        weHave: false,
      ),
      _FeatureComparison(
        feature: 'タスク・目標管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '個人財務・家計管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'AI大学 (学習管理)',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '無料プランあり',
        competitorHas: true,
        weHave: true,
      ),
    ],
  ),
  'bolt-new': const _CompetitorInfo(
    name: 'Bolt.new (StackBlitz)',
    emoji: '⚡',
    tagline: 'Bolt.newはAIフルスタックアプリビルダーの革命児。自分株式会社はアプリ構築を超えた個人の全ライフをAIで最適化。',
    searchKeyword: 'Bolt.new代替 AIアプリビルダー代替 StackBlitz代替',
    accentColor: Color(0xFF8B5CF6),
    painPoints: [
      'Bolt Pro \$20/月 — AIによる高速アプリ生成が売りだが、個人の財務・習慣・健康・AI学習管理機能がない',
      'アプリを「作る」ツールであり、個人の「生活を管理・最適化する」ツールではない',
      '開発者・起業家向け設計 — 自分株式会社は全ユーザーの日常ライフを直接サポート',
    ],
    features: [
      _FeatureComparison(
        feature: 'AIフルスタックアプリ生成',
        competitorHas: true,
        weHave: false,
      ),
      _FeatureComparison(
        feature: 'タスク・習慣管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '個人財務・家計管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'AIアシスタント統合',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '無料プランあり',
        competitorHas: true,
        weHave: true,
      ),
    ],
  ),
  'lovable': const _CompetitorInfo(
    name: 'Lovable',
    emoji: '💜',
    tagline: 'LovableはAIアプリビルダーの新星。自分株式会社はアプリ生成を超えた個人CEO向け統合ライフOSを無料提供。',
    searchKeyword: 'Lovable代替 AIアプリ生成代替 Bolt.new代替',
    accentColor: Color(0xFF7C3AED),
    painPoints: [
      'Lovable \$20/月〜 — React+SupabaseアプリをAIで即生成できるが個人の財務・習慣・健康管理は対象外',
      'アプリを作る側のツールで、個人の日常生活を管理・最適化するツールではない',
      '自分株式会社はLovableと同じSupabase+Flutter技術基盤を使いながら、作成済みの統合ライフOSを無料提供',
    ],
    features: [
      _FeatureComparison(
        feature: 'AIフルスタックアプリ生成',
        competitorHas: true,
        weHave: false,
      ),
      _FeatureComparison(
        feature: 'タスク・目標管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '個人財務・家計管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'AI大学 (学習管理)',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '完全無料',
        competitorHas: false,
        weHave: true,
      ),
    ],
  ),
  'mistral': const _CompetitorInfo(
    name: 'Mistral AI',
    emoji: '🌬️',
    tagline: 'MistralはEU発の高性能オープンAIモデル。自分株式会社はAIモデルを内部活用しながら個人の生活OSとして完成系を提供。',
    searchKeyword: 'Mistral代替 オープンソースAI代替 LLM代替',
    accentColor: Color(0xFFFF7000),
    painPoints: [
      'Mistral API — 優秀なLLMモデルを提供するが個人ユーザーが直接使うにはAPI知識と開発スキルが必要',
      'モデルを「使うツールを作る」レイヤーであり、個人の財務・タスク・健康管理は別途構築が必要',
      '自分株式会社はMistralのようなAI APIを内部活用した「完成した個人OS」を無料で提供',
    ],
    features: [
      _FeatureComparison(
        feature: '高性能LLMモデル/API',
        competitorHas: true,
        weHave: false,
      ),
      _FeatureComparison(
        feature: 'AI統合ライフアシスタント',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '個人財務・家計管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'タスク・習慣管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '設定ゼロで即利用',
        competitorHas: false,
        weHave: true,
      ),
    ],
  ),
  'jasper-ai': const _CompetitorInfo(
    name: 'Jasper AI',
    emoji: '✨',
    tagline: 'JasperはAIコンテンツ生成の第一人者。自分株式会社はコンテンツ作成だけでなく個人の生活・学習・財務まで統合管理。',
    searchKeyword: 'Jasper代替 AIライティング代替 AIコンテンツ生成代替',
    accentColor: Color(0xFF4F46E5),
    painPoints: [
      'Jasper Creator \$39/月 — マーケティングコンテンツ生成に特化し個人の財務・タスク・習慣・AI学習との統合がない',
      'コンテンツを「書く」ことに最適化されており、個人の目標設定・行動管理・振り返りはサポートしない',
      '自分株式会社は日本語でのAI文章支援も含む統合ライフOSを無料から提供',
    ],
    features: [
      _FeatureComparison(
        feature: 'AIマーケティングコンテンツ生成',
        competitorHas: true,
        weHave: false,
      ),
      _FeatureComparison(
        feature: 'タスク・目標管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '個人財務・家計管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'AI大学 (学習管理)',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '無料で始められる',
        competitorHas: false,
        weHave: true,
      ),
    ],
  ),
  'logseq': const _CompetitorInfo(
    name: 'Logseq',
    emoji: '🔗',
    tagline: 'LogseqはオープンソースPKMの新星。自分株式会社はノート管理を超えた財務・タスク・健康の全統合ライフOSをAIで提供。',
    searchKeyword: 'Logseq代替 PKM代替 Obsidian代替 ノート管理代替',
    accentColor: Color(0xFF3B82F6),
    painPoints: [
      'Logseq無料/オープンソース — アウトライナーPKMとして優秀だが財務・習慣・AI大学学習の統合は別ツールが必要',
      'バレットジャーナル的な手動管理が前提で、AIによる自動整理・提案機能が弱い',
      '非エンジニアには設定コストが高く、個人CEOとして即利用するには準備が必要',
    ],
    features: [
      _FeatureComparison(
        feature: 'アウトライナーPKM',
        competitorHas: true,
        weHave: false,
      ),
      _FeatureComparison(
        feature: 'AIアシスタント統合 (無料)',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '個人財務・資産管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'タスク・習慣管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '設定ゼロで即利用',
        competitorHas: false,
        weHave: true,
      ),
    ],
  ),
  'headspace': const _CompetitorInfo(
    name: 'Headspace',
    emoji: '🧘',
    tagline: 'Headspaceはマインドフルネス瞑想アプリの王者。自分株式会社はメンタル健康を含む全ライフカテゴリをAIで統合管理。',
    searchKeyword: 'Headspace代替 瞑想アプリ代替 マインドフルネス代替 Calm代替',
    accentColor: Color(0xFFFF6B6B),
    painPoints: [
      'Headspace \$12.99/月 — 瞑想・マインドフルネス専門アプリで財務・タスク・習慣・AI学習との統合がない',
      '心の健康に特化しており、身体・財務・仕事・学習の全体像を俯瞰できない',
      '自分株式会社は健康トラッキングを含む6部署(人事/財務/IT/営業/開発/法務)をAIで統合管理',
    ],
    features: [
      _FeatureComparison(
        feature: '瞑想・マインドフルネスコンテンツ',
        competitorHas: true,
        weHave: false,
      ),
      _FeatureComparison(
        feature: '習慣・健康トラッキング',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '個人財務・家計管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'タスク・目標管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '無料で始められる',
        competitorHas: false,
        weHave: true,
      ),
    ],
  ),
  'spotify': const _CompetitorInfo(
    name: 'Spotify',
    emoji: '🎵',
    tagline: 'Spotifyは音楽・ポッドキャストの王者。自分株式会社はエンタメを含む個人の全ライフをAIで最適化する統合OS。',
    searchKeyword: 'Spotify代替 音楽ストリーミング代替 ポッドキャスト代替',
    accentColor: Color(0xFF1DB954),
    painPoints: [
      'Spotify Premium ¥980/月 — 音楽・ポッドキャスト専門で個人の財務・タスク・習慣・AI学習との統合がない',
      'エンタメ消費ツールであり、個人のライフスタイル最適化・目標達成支援とは設計が異なる',
      'Spotify学習ポッドキャストは良質だが、学んだことをタスク・目標と繋げる機能がない',
    ],
    features: [
      _FeatureComparison(
        feature: '音楽・ポッドキャスト配信',
        competitorHas: true,
        weHave: false,
      ),
      _FeatureComparison(
        feature: 'タスク・目標管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '個人財務・家計管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'AI大学 (学習管理)',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '無料プランあり',
        competitorHas: true,
        weHave: true,
      ),
    ],
  ),
  'moneyforward-cloud': const _CompetitorInfo(
    name: 'マネーフォワードクラウド',
    emoji: '📈',
    tagline: 'マネーフォワードクラウドは法人向けバックオフィスDX。自分株式会社は個人・フリーランスのライフ全体をAIで最適化。',
    searchKeyword: 'マネーフォワードクラウド代替 クラウド会計代替 バックオフィス代替',
    accentColor: Color(0xFF0066CC),
    painPoints: [
      'MFクラウド会計 ¥2,980/月〜 — 中小企業・個人事業主の会計・給与・経費に特化し個人ライフ管理との統合がない',
      '法人バックオフィスDXは優秀だが個人のタスク・習慣・AI学習・健康管理は別アプリが必要',
      'フリーランスの確定申告支援はできるが「個人CEOとしての財務部長」的な視点での管理は自分株式会社',
    ],
    features: [
      _FeatureComparison(
        feature: '法人向けクラウド会計・給与',
        competitorHas: true,
        weHave: false,
      ),
      _FeatureComparison(
        feature: '個人家計・資産トラッキング',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'AIアシスタント (財務相談)',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'タスク・習慣管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '無料プランあり',
        competitorHas: false,
        weHave: true,
      ),
    ],
  ),
  'zoho': const _CompetitorInfo(
    name: 'Zoho',
    emoji: '🌐',
    tagline: 'ZohoはCRM・会計・HRの総合ビジネスSaaS。自分株式会社は個人版の統合ライフOSとして同等の機能を無料で提供。',
    searchKeyword: 'Zoho代替 CRM代替 ビジネスSaaS代替 G Suite代替',
    accentColor: Color(0xFFE44B23),
    painPoints: [
      'Zoho One \$37/user/月 — 40+アプリ統合は企業向けで個人ユーザーには複雑すぎ・高コスト',
      '企業のCRM・HR・会計に最適化されており、個人の習慣・健康・AI大学学習との統合がない',
      '個人版「自分株式会社」は財務・タスク・習慣・AI学習を無料から統合するZoho的な役割を果たす',
    ],
    features: [
      _FeatureComparison(
        feature: '企業向け統合ビジネスSaaS',
        competitorHas: true,
        weHave: false,
      ),
      _FeatureComparison(
        feature: '個人タスク・目標管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '個人財務・家計管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'AI大学 (学習管理)',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '完全無料',
        competitorHas: false,
        weHave: true,
      ),
    ],
  ),
  'stripe': const _CompetitorInfo(
    name: 'Stripe',
    emoji: '💳',
    tagline: 'Stripeは決済インフラの覇者。自分株式会社はStripeを含む収入・支出・資産を統合した個人財務部長AIを提供。',
    searchKeyword: 'Stripe代替 決済代替 サブスクリプション管理代替',
    accentColor: Color(0xFF635BFF),
    painPoints: [
      'Stripe 2.9%+30¢/決済 — 決済処理に特化し個人の財務全体・タスク・習慣・AI学習との統合がない',
      'EC・SaaS事業者向け決済ツールで個人の日常収支管理・目標設定には設計が合わない',
      'Stripe収益データが個人の財務ダッシュボード・家計管理に自動連携されない',
    ],
    features: [
      _FeatureComparison(
        feature: '決済処理・サブスク管理',
        competitorHas: true,
        weHave: false,
      ),
      _FeatureComparison(
        feature: '個人収支・資産管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'タスク・目標管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'AIアシスタント統合',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '無料で始められる',
        competitorHas: false,
        weHave: true,
      ),
    ],
  ),
  'typeform': const _CompetitorInfo(
    name: 'Typeform',
    emoji: '📝',
    tagline: 'Typeformは会話型フォームの先駆者。自分株式会社はフォーム収集を超えた個人の全情報をAIで管理・活用する統合OS。',
    searchKeyword: 'Typeform代替 フォーム代替 アンケート代替 Google Forms代替',
    accentColor: Color(0xFF262627),
    painPoints: [
      'Typeform Basic \$25/月 — 美しいフォーム・アンケート作成に特化し個人の財務・タスク・習慣・AI学習との統合がない',
      'データ収集ツールであり、収集したデータを個人の目標・行動管理に繋げる機能がない',
      '自分株式会社はTypeformで収集するようなセルフチェック・振り返りデータをAIが自動分析して行動提案',
    ],
    features: [
      _FeatureComparison(
        feature: '会話型フォーム・アンケート',
        competitorHas: true,
        weHave: false,
      ),
      _FeatureComparison(
        feature: 'タスク・目標管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '個人財務・家計管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'AIアシスタント統合',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '無料で始められる',
        competitorHas: false,
        weHave: true,
      ),
    ],
  ),
  'make-integromat': const _CompetitorInfo(
    name: 'Make (旧Integromat)',
    emoji: '⚙️',
    tagline: 'Makeはワークフロー自動化の革命児。自分株式会社はMake的な自動化を内包した個人CEO向け統合ライフOS。',
    searchKeyword: 'Make代替 Integromat代替 ワークフロー自動化代替 Zapier代替',
    accentColor: Color(0xFF6D00CC),
    painPoints: [
      'Make Core 無料〜\$9/月 — ワークフロー自動化は優秀だが設定・管理コストが高く個人の財務・習慣・AI学習との統合がない',
      'ビジネスプロセス自動化に最適化されており、個人のライフスタイル最適化・目標達成支援とは設計が異なる',
      '自分株式会社はMakeのような設定不要でAIが個人の全行動を自動記録・提案する統合OSを提供',
    ],
    features: [
      _FeatureComparison(
        feature: 'ビジュアルワークフロー自動化',
        competitorHas: true,
        weHave: false,
      ),
      _FeatureComparison(
        feature: 'タスク・目標管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '個人財務・家計管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'AIアシスタント統合',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '無料プランあり',
        competitorHas: true,
        weHave: true,
      ),
    ],
  ),
  'whatsapp': const _CompetitorInfo(
    name: 'WhatsApp',
    emoji: '💬',
    tagline: 'WhatsAppは世界最大のメッセンジャー。自分株式会社はコミュニケーションを含む個人の全ライフをAIで統合管理。',
    searchKeyword: 'WhatsApp代替 メッセージアプリ代替 LINE代替',
    accentColor: Color(0xFF25D366),
    painPoints: [
      'WhatsApp無料 — メッセージ送受信に特化し個人の財務・タスク・習慣・AI学習との統合がない',
      'コミュニケーションツールであり、個人の目標設定・行動管理・ライフスタイル最適化はサポートしない',
      '日本ではLINEが主流 — 自分株式会社は日本語に特化した個人CEO向け統合OSを提供',
    ],
    features: [
      _FeatureComparison(
        feature: 'メッセージ・音声通話',
        competitorHas: true,
        weHave: false,
      ),
      _FeatureComparison(
        feature: 'タスク・目標管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '個人財務・家計管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'AIアシスタント統合',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '無料で始められる',
        competitorHas: true,
        weHave: true,
      ),
    ],
  ),
  'telegram': const _CompetitorInfo(
    name: 'Telegram',
    emoji: '✈️',
    tagline: 'Telegramはセキュアメッセージングの先駆者。自分株式会社はプライバシーを重視しながら個人の全ライフをAI管理。',
    searchKeyword: 'Telegram代替 セキュアメッセージ代替 暗号化チャット代替',
    accentColor: Color(0xFF2AABEE),
    painPoints: [
      'Telegram無料 — 暗号化メッセージ・チャンネルに特化し個人の財務・タスク・習慣・AI学習との統合がない',
      'セキュリティ重視のコミュニケーションツールで個人のライフスタイル管理OSとしての機能はない',
      'Bot機能で拡張可能だが個人の目標・財務・習慣を統合管理するには独自開発が必要',
    ],
    features: [
      _FeatureComparison(
        feature: '暗号化メッセージ・チャンネル',
        competitorHas: true,
        weHave: false,
      ),
      _FeatureComparison(
        feature: 'タスク・習慣管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '個人財務・資産管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'AIアシスタント統合',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '無料で始められる',
        competitorHas: true,
        weHave: true,
      ),
    ],
  ),
  'wordpress': const _CompetitorInfo(
    name: 'WordPress',
    emoji: '📰',
    tagline: 'WordPressはウェブサイト構築の王者。自分株式会社はブログ・サイト管理を含む個人のビジネス×生活全体をAIで最適化。',
    searchKeyword: 'WordPress代替 ブログ代替 CMS代替 ウェブサイト代替',
    accentColor: Color(0xFF21759B),
    painPoints: [
      'WordPress.com \$4/月〜 — ウェブサイト・ブログ構築に特化し個人の財務・タスク・習慣・AI学習との統合がない',
      'コンテンツ発信ツールで個人のライフスタイル管理・目標設定・資産トラッキングには対応していない',
      'プラグイン設定に時間がかかり非エンジニアには敷居が高い — 自分株式会社は即利用可能な統合OS',
    ],
    features: [
      _FeatureComparison(
        feature: 'ウェブサイト・ブログ構築',
        competitorHas: true,
        weHave: false,
      ),
      _FeatureComparison(
        feature: 'タスク・目標管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '個人財務・家計管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'AI大学 (学習管理)',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '無料プランあり',
        competitorHas: true,
        weHave: true,
      ),
    ],
  ),
  'wix': const _CompetitorInfo(
    name: 'Wix',
    emoji: '🌟',
    tagline: 'Wixはノーコードウェブサイトビルダーの雄。自分株式会社はサイト構築を超えた個人の全ライフをAIで管理する統合OS。',
    searchKeyword: 'Wix代替 ウェブサイトビルダー代替 ノーコードサイト代替',
    accentColor: Color(0xFF0C6EFC),
    painPoints: [
      'Wix Light \$17/月 — ウェブサイト構築・ECに特化し個人の財務・タスク・習慣・AI学習との統合がない',
      'ビジュアルサイトビルダーで個人のライフスタイル管理・目標設定・資産トラッキングには対応していない',
      'AI Wixが画像生成・コピー作成を支援するが個人の日常行動管理との連携はない',
    ],
    features: [
      _FeatureComparison(
        feature: 'ノーコードウェブサイト構築',
        competitorHas: true,
        weHave: false,
      ),
      _FeatureComparison(
        feature: 'タスク・目標管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '個人財務・家計管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'AI大学 (学習管理)',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '無料プランあり',
        competitorHas: true,
        weHave: true,
      ),
    ],
  ),
  'coursera': const _CompetitorInfo(
    name: 'Coursera',
    emoji: '🎓',
    tagline: 'Courseraは世界最大のオンライン学習プラットフォーム。自分株式会社のAI大学はAIツールに特化した無料・実践学習を提供。',
    searchKeyword: 'Coursera代替 オンライン学習代替 大学講座代替 スキルアップ代替',
    accentColor: Color(0xFF0056D2),
    painPoints: [
      'Coursera Plus \$59/月 — 大学・企業提携コースは質が高いが個人の財務・タスク・習慣管理との統合がない',
      '学習記録が個人のWBS・目標設定・キャリア計画と自動連動しない',
      '自分株式会社のAI大学は260+社を無料で体系学習でき、学習ログがタスク・目標管理に直結する',
    ],
    features: [
      _FeatureComparison(
        feature: '大学・企業提携オンライン学習',
        competitorHas: true,
        weHave: false,
      ),
      _FeatureComparison(
        feature: 'AI大学 (260+社AIツール・無料)',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '学習ログ×目標管理連携',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '個人財務・家計管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '無料プランあり',
        competitorHas: true,
        weHave: true,
      ),
    ],
  ),
  'elevenlabs': const _CompetitorInfo(
    name: 'ElevenLabs',
    emoji: '🔊',
    tagline: 'ElevenLabsはAI音声生成の最先端。自分株式会社はAI音声を含む全AIツール活用を個人のライフOS内で統合管理。',
    searchKeyword: 'ElevenLabs代替 AI音声生成代替 テキスト読み上げ代替',
    accentColor: Color(0xFFFF4B4B),
    painPoints: [
      'ElevenLabs Creator \$22/月 — AI音声合成に特化し個人の財務・タスク・習慣・目標管理との統合がない',
      '音声コンテンツ制作ツールで個人のライフスタイル最適化・行動管理には対応していない',
      '自分株式会社のAI大学にElevenLabs活用法を収録し、音声AIを含む260+社のAI知識を体系的に学べる',
    ],
    features: [
      _FeatureComparison(
        feature: 'AI音声生成・クローン',
        competitorHas: true,
        weHave: false,
      ),
      _FeatureComparison(
        feature: 'AI大学 (AIツール学習管理)',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'タスク・目標管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '個人財務・家計管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '無料プランあり',
        competitorHas: true,
        weHave: true,
      ),
    ],
  ),
  'ollama': const _CompetitorInfo(
    name: 'Ollama',
    emoji: '🦙',
    tagline: 'OllamaはローカルLLM実行の決定版。自分株式会社はOllamaのようなAI基盤を活用した個人向け統合ライフOSを提供。',
    searchKeyword: 'Ollama代替 ローカルLLM代替 プライベートAI代替',
    accentColor: Color(0xFF2D3748),
    painPoints: [
      'Ollama無料・オープンソース — ローカルLLM実行は優秀だが個人の財務・タスク・習慣管理アプリとしては設計されていない',
      'CLIベースで非エンジニアには敷居が高い — 自分株式会社はノンエンジニアも即利用できるUIを提供',
      'LLMを「動かす」ツールであり、個人の目標・家計・学習・健康を統合管理する「使うツール」ではない',
    ],
    features: [
      _FeatureComparison(
        feature: 'ローカルLLM実行環境',
        competitorHas: true,
        weHave: false,
      ),
      _FeatureComparison(
        feature: 'AI統合ライフアシスタント',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '個人財務・家計管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'タスク・習慣管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '設定ゼロで即利用',
        competitorHas: false,
        weHave: true,
      ),
    ],
  ),
  'vercel': const _CompetitorInfo(
    name: 'Vercel',
    emoji: '▲',
    tagline: 'Vercelはフロントエンドデプロイの王者。自分株式会社はデプロイインフラを超えた個人のビジネス×生活全体をAIで管理。',
    searchKeyword: 'Vercel代替 フロントエンドデプロイ代替 Next.js代替',
    accentColor: Color(0xFF000000),
    painPoints: [
      'Vercel Pro \$20/month — Next.js/Reactのデプロイ最適化に特化し個人の財務・タスク・習慣・AI学習との統合がない',
      '開発者向けインフラツールで個人のライフスタイル管理・目標設定には対応していない',
      'v0によるAI UI生成は革新的だが個人の日常行動管理・健康・資産管理との連携はない',
    ],
    features: [
      _FeatureComparison(
        feature: 'フロントエンドデプロイ・CDN',
        competitorHas: true,
        weHave: false,
      ),
      _FeatureComparison(
        feature: 'タスク・目標管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '個人財務・家計管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'AI大学 (学習管理)',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '無料プランあり',
        competitorHas: true,
        weHave: true,
      ),
    ],
  ),
  'v0': const _CompetitorInfo(
    name: 'v0 (Vercel)',
    emoji: '🎨',
    tagline: 'v0はAI UIジェネレーターの革命。自分株式会社はUIを生成するだけでなく個人の全ライフをAIで管理する完成済みOS。',
    searchKeyword: 'v0代替 AI UIジェネレーター代替 Vercel v0代替',
    accentColor: Color(0xFF1a1a1a),
    painPoints: [
      'v0 \$20/月 — ReactコンポーネントをAI生成する開発者ツールで個人の財務・習慣・AI学習管理には対応しない',
      'UIを「作る」ツールで個人の「生活を管理・最適化する」ツールではない',
      '自分株式会社はv0で構築したようなUIを既に完成品として無料で提供している統合ライフOS',
    ],
    features: [
      _FeatureComparison(
        feature: 'AI UIコンポーネント生成',
        competitorHas: true,
        weHave: false,
      ),
      _FeatureComparison(
        feature: 'タスク・習慣管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '個人財務・家計管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'AI大学 (学習管理)',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '無料で始められる',
        competitorHas: false,
        weHave: true,
      ),
    ],
  ),
  'paypal': const _CompetitorInfo(
    name: 'PayPal',
    emoji: '💰',
    tagline: 'PayPalはグローバル決済の定番。自分株式会社はPayPal決済を含む個人の収入・支出・資産全体をAI財務部長が管理。',
    searchKeyword: 'PayPal代替 オンライン決済代替 送金代替',
    accentColor: Color(0xFF003087),
    painPoints: [
      'PayPal手数料型 — 決済・送金に特化し個人の家計全体・タスク・習慣・AI学習との統合がない',
      'PayPal残高・取引記録が個人の財務ダッシュボードに自動連携されない',
      '決済インフラであり、個人のライフスタイル最適化・目標達成支援という視点でのサポートがない',
    ],
    features: [
      _FeatureComparison(
        feature: 'オンライン決済・送金',
        competitorHas: true,
        weHave: false,
      ),
      _FeatureComparison(
        feature: '個人収支・資産一元管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'タスク・目標管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'AIアシスタント統合',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '無料で始められる',
        competitorHas: false,
        weHave: true,
      ),
    ],
  ),
  'freee-hr': const _CompetitorInfo(
    name: 'freee人事労務',
    emoji: '👷',
    tagline: 'freee人事労務は勤怠・給与管理のSaaS。自分株式会社は個人が自分自身のHR部長として働き方・スキル・目標を管理。',
    searchKeyword: 'freee人事労務代替 勤怠管理代替 給与計算代替',
    accentColor: Color(0xFF00B900),
    painPoints: [
      'freee人事労務 ¥1,980/月〜 — 企業向け勤怠・給与管理に特化し個人のキャリア・スキル・健康・AI学習との統合がない',
      '会社の人事業務支援ツールで個人が「自分自身のHR部長」として管理する設計ではない',
      '自分株式会社の人事部署AIは個人のスキル習得・副業管理・AI大学学習を一元管理できる唯一の設計',
    ],
    features: [
      _FeatureComparison(
        feature: '企業向け勤怠・給与計算',
        competitorHas: true,
        weHave: false,
      ),
      _FeatureComparison(
        feature: '個人スキル・キャリア管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'AI大学 (スキルアップ学習)',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'タスク・目標管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '完全無料',
        competitorHas: false,
        weHave: true,
      ),
    ],
  ),
  'cloudsign': const _CompetitorInfo(
    name: 'クラウドサイン',
    emoji: '✍️',
    tagline: 'クラウドサインは電子契約の日本No.1。自分株式会社は契約管理を含む個人の法務・財務・タスクをAIで一元管理。',
    searchKeyword: 'クラウドサイン代替 電子契約代替 電子署名代替',
    accentColor: Color(0xFF0082CC),
    painPoints: [
      'クラウドサイン ¥11,000/月〜 — 電子契約に特化し個人の財務・タスク・習慣・AI学習との統合がない',
      '企業間の契約業務DXに最適化されており個人の日常ライフ管理とは設計が異なる',
      '自分株式会社の法務部署AIは個人の重要書類・契約・約束事を含む全ライフをAIで管理',
    ],
    features: [
      _FeatureComparison(
        feature: '電子契約・法的効力',
        competitorHas: true,
        weHave: false,
      ),
      _FeatureComparison(
        feature: '個人タスク・目標管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '個人財務・家計管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'AI大学 (学習管理)',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '完全無料',
        competitorHas: false,
        weHave: true,
      ),
    ],
  ),
  'groq-ai': const _CompetitorInfo(
    name: 'Groq',
    emoji: '⚡',
    tagline:
        'GroqはLPU搭載の超高速AI推論プラットフォーム。自分株式会社はGroqのような高速AIを内部活用した完成済み個人OSを提供。',
    searchKeyword: 'Groq代替 高速AI推論代替 LLM API代替',
    accentColor: Color(0xFFF54E42),
    painPoints: [
      'Groq API — 超高速LLM推論を提供するが個人ユーザーが直接使うにはAPI知識と開発スキルが必要',
      'AIインフラプレイヤーであり、個人の財務・タスク・習慣・目標管理アプリとしては設計されていない',
      '自分株式会社はGroqのような高速AIを内部活用した「完成した個人OS」を設定ゼロで無料提供',
    ],
    features: [
      _FeatureComparison(
        feature: '超高速AI推論API',
        competitorHas: true,
        weHave: false,
      ),
      _FeatureComparison(
        feature: 'AI統合ライフアシスタント',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '個人財務・家計管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'タスク・習慣管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '設定ゼロで即利用',
        competitorHas: false,
        weHave: true,
      ),
    ],
  ),
  'databricks': const _CompetitorInfo(
    name: 'Databricks',
    emoji: '🔥',
    tagline:
        'DatabricksはAI/データLakehouseの王者。自分株式会社はデータ基盤を超えた個人のライフ全体をAIで最適化する個人OS。',
    searchKeyword: 'Databricks代替 MLOps代替 データプラットフォーム代替',
    accentColor: Color(0xFFFF3621),
    painPoints: [
      'Databricks Pay-per-use — エンタープライズAI/データ分析に特化し個人ユーザーには複雑すぎ・高コスト',
      '大規模データ処理・ML基盤ツールで個人の財務・タスク・習慣・AI学習管理には設計が合わない',
      'AI大学にDatabricks学習コンテンツを収録し、エンタープライズAIを個人のキャリアに活かす方法を提供',
    ],
    features: [
      _FeatureComparison(
        feature: 'エンタープライズAI/データ基盤',
        competitorHas: true,
        weHave: false,
      ),
      _FeatureComparison(
        feature: 'AI大学 (Databricks学習)',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '個人財務・家計管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'タスク・目標管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '完全無料',
        competitorHas: false,
        weHave: true,
      ),
    ],
  ),
  // PS#4 S82: 20社追加 2026-04-28
  'asana': const _CompetitorInfo(
    name: 'Asana',
    emoji: '📋',
    tagline: 'AsanaはチームPM標準ツール。自分株式会社は個人・チーム両対応のAI駆動タスク管理を1アプリで提供。',
    searchKeyword: 'Asana代替 プロジェクト管理代替 タスク管理代替',
    accentColor: Color(0xFFF06A6A),
    painPoints: [
      'Asana — チーム向けPMツールで個人利用には機能過多・月額費用がかさむ',
      'AI機能はアドオン扱いで基本プランでは使えない。財務・習慣・学習管理は対象外',
      '自分株式会社はAI駆動タスク管理＋財務＋習慣を1アプリで無料提供',
    ],
    features: [
      _FeatureComparison(
        feature: 'チームプロジェクト管理',
        competitorHas: true,
        weHave: false,
      ),
      _FeatureComparison(
        feature: 'AI統合タスクアシスタント',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '個人財務・家計管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '習慣トラッキング',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '完全無料',
        competitorHas: false,
        weHave: true,
      ),
    ],
  ),
  'trello': const _CompetitorInfo(
    name: 'Trello',
    emoji: '📊',
    tagline: 'Trelloはカンバン型タスク管理の定番。自分株式会社はカンバン＋AI判定＋財務を統合した次世代個人OS。',
    searchKeyword: 'Trello代替 カンバン代替 ボード管理代替',
    accentColor: Color(0xFF0052CC),
    painPoints: [
      'Trello — カンバンボードは直感的だが財務・習慣・AI活用は別アプリが必要',
      'Atlassian傘下でエンタープライズ寄りになり個人プランの機能制限が増加',
      '自分株式会社はタスク・財務・AI判定・習慣を1アプリで統合提供',
    ],
    features: [
      _FeatureComparison(
        feature: 'カンバンボード',
        competitorHas: true,
        weHave: false,
      ),
      _FeatureComparison(
        feature: 'AI統合ライフアシスタント',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '個人財務管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '習慣・目標トラッキング',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '完全無料',
        competitorHas: false,
        weHave: true,
      ),
    ],
  ),
  'todoist': const _CompetitorInfo(
    name: 'Todoist',
    emoji: '✅',
    tagline: 'TodoistはGTD実践者向けタスク管理の傑作。自分株式会社はAI自動優先付け＋財務を統合した個人OS。',
    searchKeyword: 'Todoist代替 GTD代替 タスク管理アプリ代替',
    accentColor: Color(0xFFDB4035),
    painPoints: [
      'Todoist Pro \$5/月 — タスク管理に特化し財務・習慣・AI学習管理は別アプリ依存',
      'AI自動優先付けはPro以上。個人の全ライフ管理には複数サブスクが必要',
      '自分株式会社はAI優先付け＋財務＋習慣管理を完全無料で統合提供',
    ],
    features: [
      _FeatureComparison(
        feature: 'GTD対応タスク管理',
        competitorHas: true,
        weHave: false,
      ),
      _FeatureComparison(
        feature: 'AI統合ライフマネジメント',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '家計・財務管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '習慣トラッキング',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '完全無料',
        competitorHas: false,
        weHave: true,
      ),
    ],
  ),
  'n8n': const _CompetitorInfo(
    name: 'n8n',
    emoji: '🔀',
    tagline: 'n8nはOSSワークフロー自動化ツール。自分株式会社はノーコード設定不要で個人ライフを自動化する完成済みOS。',
    searchKeyword: 'n8n代替 ワークフロー自動化代替 Zapier代替',
    accentColor: Color(0xFFEA5B26),
    painPoints: [
      'n8n — セルフホスト型OSSでエンジニアには強力だが一般ユーザーにはセットアップが高難易度',
      'ワークフロー設計・ノード構築のスキルが必要で個人ユーザーが即使えるアプリではない',
      '自分株式会社はAI自動化を設定ゼロで提供する完成済み個人OS',
    ],
    features: [
      _FeatureComparison(
        feature: 'カスタムワークフロー自動化',
        competitorHas: true,
        weHave: false,
      ),
      _FeatureComparison(
        feature: '設定ゼロで即使えるAI',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '個人財務・家計管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'タスク・習慣管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '完全無料',
        competitorHas: false,
        weHave: true,
      ),
    ],
  ),
  'zapier': const _CompetitorInfo(
    name: 'Zapier',
    emoji: '⚡',
    tagline: 'Zapierはノーコード自動化の定番。自分株式会社はZap設計不要でAI統合ライフ管理を即提供。',
    searchKeyword: 'Zapier代替 自動化ツール代替 ノーコード自動化代替',
    accentColor: Color(0xFFFF4A00),
    painPoints: [
      'Zapier Pro \$19.99/月〜 — 外部SaaS連携自動化に特化し個人ライフ管理アプリとしては設計外',
      'Zap(自動化フロー)の設計が必要で財務・習慣・AI学習を1アプリで管理できない',
      '自分株式会社はAI・財務・タスク・習慣を1アプリで統合・月額ゼロ',
    ],
    features: [
      _FeatureComparison(
        feature: '外部SaaS自動化連携',
        competitorHas: true,
        weHave: false,
      ),
      _FeatureComparison(
        feature: 'AI統合個人OS',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '家計・財務管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '習慣・目標管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '完全無料',
        competitorHas: false,
        weHave: true,
      ),
    ],
  ),
  'netflix': const _CompetitorInfo(
    name: 'Netflix',
    emoji: '🎬',
    tagline: 'Netflixは世界No.1動画配信。自分株式会社はエンタメ管理＋学習推薦AIを搭載した個人OS。',
    searchKeyword: 'Netflix代替 動画配信代替 エンタメ管理代替',
    accentColor: Color(0xFFE50914),
    painPoints: [
      'Netflix ¥790〜/月 — 動画消費に特化し財務・タスク・習慣・AI学習管理は対象外',
      '視聴時間が財務・健康・目標達成に与える影響を可視化・管理する機能がない',
      '自分株式会社はAI大学での学習推薦＋時間・財務管理を統合した個人OS',
    ],
    features: [
      _FeatureComparison(
        feature: '動画コンテンツ配信',
        competitorHas: true,
        weHave: false,
      ),
      _FeatureComparison(
        feature: 'AI学習推薦・AI大学',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '個人財務・時間管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '習慣・目標トラッキング',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '完全無料',
        competitorHas: false,
        weHave: true,
      ),
    ],
  ),
  'signal': const _CompetitorInfo(
    name: 'Signal',
    emoji: '🔐',
    tagline: 'Signalはプライバシー最優先の暗号化メッセージアプリ。自分株式会社はプライバシー重視のAI個人OSを提供。',
    searchKeyword: 'Signal代替 暗号化メッセージ代替 プライバシーアプリ代替',
    accentColor: Color(0xFF2592E9),
    painPoints: [
      'Signal — 暗号化通信に特化しタスク・財務・習慣・AI学習管理は別アプリが必要',
      'メッセージング以外の個人ライフ管理機能はゼロ',
      '自分株式会社はプライバシーを重視しながらAI・財務・タスク・習慣を統合管理',
    ],
    features: [
      _FeatureComparison(
        feature: 'E2E暗号化メッセージング',
        competitorHas: true,
        weHave: false,
      ),
      _FeatureComparison(
        feature: 'AI統合ライフアシスタント',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '個人財務管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'タスク・習慣管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '完全無料',
        competitorHas: false,
        weHave: true,
      ),
    ],
  ),
  'twilio': const _CompetitorInfo(
    name: 'Twilio',
    emoji: '📞',
    tagline: 'TwilioはコミュニケーションAPI最大手。自分株式会社はAPI知識不要でAI通知・リマインダーを提供する個人OS。',
    searchKeyword: 'Twilio代替 通信API代替 SMS自動化代替',
    accentColor: Color(0xFFF22F46),
    painPoints: [
      'Twilio — 開発者向けSMS/音声/メールAPIで一般個人ユーザーが直接使えるアプリではない',
      '通知・リマインダー自動化には開発スキルとAPI費用が必要',
      '自分株式会社はAI通知・デイリーリマインダーを設定ゼロで無料提供',
    ],
    features: [
      _FeatureComparison(
        feature: 'SMS/音声/メールAPI',
        competitorHas: true,
        weHave: false,
      ),
      _FeatureComparison(
        feature: 'AI通知・リマインダー',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '個人財務・タスク管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '設定ゼロで即利用',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '完全無料',
        competitorHas: false,
        weHave: true,
      ),
    ],
  ),
  'snowflake': const _CompetitorInfo(
    name: 'Snowflake',
    emoji: '❄️',
    tagline:
        'Snowflakeはエンタープライズデータクラウドの王者。自分株式会社はデータ分析を個人レベルに democratize した個人OS。',
    searchKeyword: 'Snowflake代替 データクラウド代替 データウェアハウス代替',
    accentColor: Color(0xFF29B5E8),
    painPoints: [
      'Snowflake — エンタープライズ向けデータウェアハウスで個人ユーザーには複雑・高コスト',
      'SQLスキルとクラウド知識が必要で財務・習慣・AI学習管理アプリとしては設計外',
      '自分株式会社はAI大学にSnowflake学習コンテンツを収録し個人キャリアに活かせる',
    ],
    features: [
      _FeatureComparison(
        feature: 'エンタープライズデータ分析',
        competitorHas: true,
        weHave: false,
      ),
      _FeatureComparison(
        feature: 'AI大学 (Snowflake学習)',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '個人財務・家計管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'タスク・目標管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '完全無料',
        competitorHas: false,
        weHave: true,
      ),
    ],
  ),
  'vanta': const _CompetitorInfo(
    name: 'Vanta',
    emoji: '🛡️',
    tagline:
        'VantaはSOC2/ISO27001自動化のセキュリティコンプライアンスSaaS。自分株式会社は個人データを安全に管理するAI個人OS。',
    searchKeyword: 'Vanta代替 セキュリティコンプライアンス代替 SOC2代替',
    accentColor: Color(0xFF7C3AED),
    painPoints: [
      'Vanta — 企業向けセキュリティ認証自動化に特化し個人ユーザーの財務・タスク管理には不適',
      'スタートアップがSOC2取得に使うBtoBツールで月額費用も企業向け水準',
      '自分株式会社はAI大学でセキュリティ知識を学べる個人向けOS',
    ],
    features: [
      _FeatureComparison(
        feature: 'セキュリティ認証自動化',
        competitorHas: true,
        weHave: false,
      ),
      _FeatureComparison(
        feature: 'AI大学 (セキュリティ学習)',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '個人財務・タスク管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '完全無料',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '設定ゼロで即利用',
        competitorHas: false,
        weHave: true,
      ),
    ],
  ),
  'progate': const _CompetitorInfo(
    name: 'Progate',
    emoji: '💻',
    tagline: 'Progateはブラウザで学ぶプログラミング学習サービス。自分株式会社はAI大学で260社超のAIツールを学べる個人OS。',
    searchKeyword: 'Progate代替 プログラミング学習代替 コーディング学習代替',
    accentColor: Color(0xFF3CBC8D),
    painPoints: [
      'Progate Pro ¥1,078/月 — プログラミング学習に特化し財務・習慣・タスク管理は別アプリ依存',
      'AI・最新テクノロジー学習コンテンツの更新が遅く実務レベルのAI活用に対応しにくい',
      '自分株式会社のAI大学は260社超のAIツールを無料で学べ、財務・習慣管理も統合',
    ],
    features: [
      _FeatureComparison(
        feature: 'プログラミング学習',
        competitorHas: true,
        weHave: false,
      ),
      _FeatureComparison(
        feature: 'AI大学 (AIツール学習)',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '個人財務・家計管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '習慣・目標管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '完全無料',
        competitorHas: false,
        weHave: true,
      ),
    ],
  ),
  'schoo': const _CompetitorInfo(
    name: 'Schoo',
    emoji: '🎓',
    tagline: 'Schooは社会人向けオンライン学習の日本代表。自分株式会社はAI大学で最新AIスキルを無料で学べる個人OS。',
    searchKeyword: 'Schoo代替 オンライン学習代替 社会人学習代替',
    accentColor: Color(0xFFFF6B2B),
    painPoints: [
      'Schoo ¥980/月 — 動画学習に特化しAI・財務・習慣・タスク管理は対象外',
      'AI最新動向のコンテンツ更新速度が追いつかない。260社超のAIツールを体系的に学べない',
      '自分株式会社のAI大学は最新AI260社超を無料で学べ、実践ライフ管理も統合',
    ],
    features: [
      _FeatureComparison(
        feature: '動画オンライン学習',
        competitorHas: true,
        weHave: false,
      ),
      _FeatureComparison(
        feature: 'AI大学 (AIツール実践学習)',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '個人財務・家計管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '習慣・目標トラッキング',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '完全無料',
        competitorHas: false,
        weHave: true,
      ),
    ],
  ),
  'sansan': const _CompetitorInfo(
    name: 'Sansan',
    emoji: '📇',
    tagline: 'Sansanは名刺管理・法人CRMの日本No.1。自分株式会社はAI人脈管理を個人ライフ全体に統合した個人OS。',
    searchKeyword: 'Sansan代替 名刺管理代替 CRM代替',
    accentColor: Color(0xFF003B8E),
    painPoints: [
      'Sansan — 法人向け名刺・CRM管理に特化し個人の財務・習慣・AI学習管理には未対応',
      '個人向けEight (無料)はシンプルすぎ、エンタープライズSansanは高額で個人使用は非効率',
      '自分株式会社はAI人脈管理＋財務＋タスク＋習慣を1アプリで統合提供',
    ],
    features: [
      _FeatureComparison(
        feature: '名刺・法人CRM管理',
        competitorHas: true,
        weHave: false,
      ),
      _FeatureComparison(
        feature: 'AI統合個人ライフ管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '個人財務・家計管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '習慣・目標管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '完全無料',
        competitorHas: false,
        weHave: true,
      ),
    ],
  ),
  'kincone': const _CompetitorInfo(
    name: 'KINCONE',
    emoji: '⏰',
    tagline: 'KINCONEはSuicaで打刻できる交通費・勤怠管理SaaS。自分株式会社は勤怠＋財務＋AI管理を統合した個人OS。',
    searchKeyword: 'KINCONE代替 交通費精算代替 勤怠管理代替',
    accentColor: Color(0xFF00A55A),
    painPoints: [
      'KINCONE — Suica打刻・交通費精算に特化し個人の財務全体・習慣・AI学習は管理対象外',
      '法人向けSaaSで個人フリーランスが使うには機能が限定的・コストが合わない場合も',
      '自分株式会社は勤務時間・交通費を含む財務全体をAIで管理する個人OS',
    ],
    features: [
      _FeatureComparison(
        feature: 'Suica打刻・交通費管理',
        competitorHas: true,
        weHave: false,
      ),
      _FeatureComparison(
        feature: 'AI統合財務・家計管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '習慣・目標トラッキング',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'AI大学 (HR/労務学習)',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '完全無料',
        competitorHas: false,
        weHave: true,
      ),
    ],
  ),
  'synthesia': const _CompetitorInfo(
    name: 'Synthesia',
    emoji: '🎭',
    tagline: 'SynthesiaはAIアバター動画生成の世界リーダー。自分株式会社はAI大学でSynthesia活用法を学べる個人OS。',
    searchKeyword: 'Synthesia代替 AIアバター動画代替 AI動画生成代替',
    accentColor: Color(0xFF1A6FFF),
    painPoints: [
      'Synthesia Starter \$29/月 — AIアバター動画生成に特化し財務・タスク・習慣管理は対象外',
      '動画制作ツールであり個人ライフ全体をAIで管理するOSとしては設計されていない',
      '自分株式会社のAI大学はSynthesia等のAI動画ツールを無料で学び実践できる個人OS',
    ],
    features: [
      _FeatureComparison(
        feature: 'AIアバター動画生成',
        competitorHas: true,
        weHave: false,
      ),
      _FeatureComparison(
        feature: 'AI大学 (Synthesia学習)',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '個人財務・家計管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'タスク・習慣管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '完全無料',
        competitorHas: false,
        weHave: true,
      ),
    ],
  ),
  'runway': const _CompetitorInfo(
    name: 'Runway',
    emoji: '🎨',
    tagline: 'RunwayはGen-3搭載のAI動画・クリエイティブツール。自分株式会社はAI大学でRunway活用を学べる個人OS。',
    searchKeyword: 'Runway代替 AI動画編集代替 AI動画生成代替',
    accentColor: Color(0xFF8B5CF6),
    painPoints: [
      'Runway Standard \$15/月 — AI動画生成・編集に特化し財務・タスク・習慣管理は対象外',
      'クリエイティブ制作ツールで個人の日常ライフ管理OSとしては機能しない',
      '自分株式会社のAI大学はRunwayなどのAIクリエイティブツールを体系的に学べる',
    ],
    features: [
      _FeatureComparison(
        feature: 'AI動画生成・編集',
        competitorHas: true,
        weHave: false,
      ),
      _FeatureComparison(
        feature: 'AI大学 (AI動画ツール学習)',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '個人財務・家計管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'タスク・目標管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '完全無料',
        competitorHas: false,
        weHave: true,
      ),
    ],
  ),
  'heygen': const _CompetitorInfo(
    name: 'HeyGen',
    emoji: '🤖',
    tagline: 'HeyGenはAIアバターで多言語動画を自動生成。自分株式会社はAI大学でHeyGenの活用法を学べる個人OS。',
    searchKeyword: 'HeyGen代替 AIアバター代替 多言語動画代替',
    accentColor: Color(0xFF00C9A7),
    painPoints: [
      'HeyGen Creator \$29/月 — AIアバター動画生成に特化し個人ライフ管理は対象外',
      'マーケティング・動画制作用途で財務・習慣・タスク管理OSとしては機能しない',
      '自分株式会社はHeyGen等のAIツール活用知識をAI大学で無料提供し実践ライフ管理も統合',
    ],
    features: [
      _FeatureComparison(
        feature: 'AIアバター多言語動画',
        competitorHas: true,
        weHave: false,
      ),
      _FeatureComparison(
        feature: 'AI大学 (HeyGen学習)',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '個人財務・家計管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'タスク・習慣管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '完全無料',
        competitorHas: false,
        weHave: true,
      ),
    ],
  ),
  'devin': const _CompetitorInfo(
    name: 'Devin (Cognition AI)',
    emoji: '👨‍💻',
    tagline: 'Devinは初のAIソフトウェアエンジニア。自分株式会社はAI大学でDevin等のAIコーディングエージェントを学べる個人OS。',
    searchKeyword: 'Devin代替 AIソフトウェアエンジニア代替 AIコーディングエージェント代替',
    accentColor: Color(0xFF0077FF),
    painPoints: [
      'Devin Teams \$500/月 — AIエンジニアリングに特化し個人の財務・習慣・日常ライフ管理は対象外',
      'エンタープライズ向けAIコーディングエージェントで個人ユーザーには高額・高難易度',
      '自分株式会社はAI大学でDevin活用を学べ財務・習慣・タスク管理も1アプリで提供',
    ],
    features: [
      _FeatureComparison(
        feature: 'AIソフトウェアエンジニア',
        competitorHas: true,
        weHave: false,
      ),
      _FeatureComparison(
        feature: 'AI大学 (Devin/AI coding学習)',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '個人財務・家計管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '習慣・目標管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '完全無料',
        competitorHas: false,
        weHave: true,
      ),
    ],
  ),
  'hugging-face': const _CompetitorInfo(
    name: 'Hugging Face',
    emoji: '🤗',
    tagline: 'Hugging FaceはOSSモデルのGitHub。自分株式会社はAI大学でHugging Faceの活用を学べる個人OS。',
    searchKeyword: 'Hugging Face代替 MLモデルハブ代替 AIモデル代替',
    accentColor: Color(0xFFFFD21E),
    painPoints: [
      'Hugging Face Pro \$9/月 — MLモデルハブ・Spacesに特化し個人ライフ管理OSとしては設計外',
      'エンジニア・研究者向けプラットフォームで一般ユーザーが財務・習慣・タスクを管理するツールではない',
      '自分株式会社はAI大学でHugging Face活用を無料で学べ、実践ライフ管理も1アプリで提供',
    ],
    features: [
      _FeatureComparison(
        feature: 'AIモデルハブ・Spaces',
        competitorHas: true,
        weHave: false,
      ),
      _FeatureComparison(
        feature: 'AI大学 (Hugging Face学習)',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '個人財務・家計管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'タスク・習慣管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '設定ゼロで即利用',
        competitorHas: false,
        weHave: true,
      ),
    ],
  ),
  'replicate': const _CompetitorInfo(
    name: 'Replicate',
    emoji: '🔄',
    tagline: 'ReplicateはAPIでAIモデルを即呼び出せるクラウド。自分株式会社はAI大学でReplicate活用を学べる個人OS。',
    searchKeyword: 'Replicate代替 AIモデルAPI代替 画像生成API代替',
    accentColor: Color(0xFF6366F1),
    painPoints: [
      'Replicate — AIモデルAPI提供に特化し個人ライフ管理OSとしては設計されていない',
      'API開発スキルが必要で財務・習慣・タスク管理を提供するアプリではない',
      '自分株式会社はAI大学でReplicate等のAIAPIを学べ、財務・習慣・タスク管理も統合提供',
    ],
    features: [
      _FeatureComparison(
        feature: 'AIモデルAPI (画像/動画/音声)',
        competitorHas: true,
        weHave: false,
      ),
      _FeatureComparison(
        feature: 'AI大学 (AIモデルAPI学習)',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '個人財務・家計管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: 'タスク・習慣管理',
        competitorHas: false,
        weHave: true,
      ),
      _FeatureComparison(
        feature: '設定ゼロで即利用',
        competitorHas: false,
        weHave: true,
      ),
    ],
  ),
};

// ---------------------------------------------------------------------------
// Shell widget
// ---------------------------------------------------------------------------

class _ComparisonShell extends StatefulWidget {
  final _CompetitorInfo info;
  final String competitorKey;
  final String? pricingTier;
  final double? pricingStartUsd;
  final String? pricingNotesJa;
  final String? japanPresenceLevel;
  const _ComparisonShell({
    required this.info,
    required this.competitorKey,
    this.pricingTier,
    this.pricingStartUsd,
    this.pricingNotesJa,
    this.japanPresenceLevel,
  });

  @override
  State<_ComparisonShell> createState() => _ComparisonShellState();
}

class _ComparisonShellState extends State<_ComparisonShell> {
  static const _acquisitionService = GrowthAcquisitionService();
  static const _pageBackground = Color(0xFF080812);
  static const _surfacePrimary = Color(0xFF12131E);
  static const _surfaceSecondary = Color(0xFF171A27);
  static const _surfaceMuted = Color(0xFF1F2333);
  static const _borderColor = Color(0xFF2A3044);
  static const _textPrimary = Color(0xFFF5F7FB);
  static const _textSecondary = Color(0xFFB2BDD3);
  static const _textMuted = Color(0xFF7E8AA6);
  static const _orange = Color(0xFFFF6B35);
  static const _indigo = Color(0xFF3D5AFE);

  static const _featuredCompetitorKeys = <String>[
    'notion',
    'evernote',
    'moneyforward',
    'slack',
    'google',
    'github',
    'claude-code',
    'codex',
    'line',
    'discord',
  ];

  @override
  void initState() {
    super.initState();
    unawaited(_acquisitionService.recordComparisonTouch(widget.competitorKey));
  }

  _CompetitorInfo get _info => widget.info;
  bool get _hasImportSupport =>
      widget.competitorKey == 'notion' || widget.competitorKey == 'evernote';
  int get _sharedFeatureCount => _info.features
      .where((feature) => feature.competitorHas && feature.weHave)
      .length;
  int get _ourAdvantageCount => _info.features
      .where((feature) => !feature.competitorHas && feature.weHave)
      .length;

  List<MapEntry<String, _CompetitorInfo>> get _relatedCompetitors {
    final seen = <String>{widget.competitorKey};
    final orderedKeys = <String>[
      ..._featuredCompetitorKeys,
      ..._competitorInfo.keys,
    ];
    final items = <MapEntry<String, _CompetitorInfo>>[];

    for (final key in orderedKeys) {
      if (!seen.add(key)) {
        continue;
      }
      final info = _competitorInfo[key];
      if (info == null) {
        continue;
      }
      items.add(MapEntry(key, info));
      if (items.length >= 6) {
        break;
      }
    }

    return items;
  }

  String get _switchStepTitle =>
      _hasImportSupport ? '既存データをそのまま移行' : '${_info.name} から30秒で乗り換え開始';

  String get _switchStepBody => _hasImportSupport
      ? '${_info.name} のデータをインポートしながら、今の資産を崩さず移行できます。'
      : 'まずは無料で始めて、${_info.name} では分散していた作業を1か所に集約できます。';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBackground,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _info.accentColor.withValues(alpha: 0.12),
              _pageBackground,
              _pageBackground,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildHero(context),
                _buildOutcomeCards(),
                _buildPainPoints(),
                _buildFeatureTable(),
                _buildSwitchPlan(context),
                _buildRelatedComparisons(context),
                _buildCta(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: Container(
            decoration: BoxDecoration(
              color: _surfacePrimary,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: _info.accentColor.withValues(alpha: 0.26),
              ),
              boxShadow: [
                BoxShadow(
                  color: _info.accentColor.withValues(alpha: 0.15),
                  blurRadius: 36,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            padding: const EdgeInsets.all(28),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 760;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _buildTag(
                          icon: Icons.compare_arrows_rounded,
                          label: '21競合比較',
                          backgroundColor:
                              _info.accentColor.withValues(alpha: 0.18),
                          foregroundColor: _textPrimary,
                        ),
                        _buildTag(
                          icon: Icons.search_rounded,
                          label: _info.searchKeyword,
                          backgroundColor: _surfaceMuted,
                          foregroundColor: _textSecondary,
                        ),
                        if (_hasImportSupport)
                          _buildTag(
                            icon: Icons.publish_rounded,
                            label: 'インポート対応',
                            backgroundColor: _orange.withValues(alpha: 0.18),
                            foregroundColor: _textPrimary,
                          ),
                        if (widget.pricingTier != null)
                          _PricingBadge(tier: widget.pricingTier!),
                        if (widget.japanPresenceLevel != null)
                          _JapanPresenceBadge(
                            level: widget.japanPresenceLevel!,
                          ),
                      ],
                    ),
                    if (widget.pricingStartUsd != null ||
                        widget.pricingNotesJa != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            if (widget.pricingStartUsd != null)
                              Text(
                                '最安 \$${widget.pricingStartUsd?.toStringAsFixed(2)}/月',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: _textSecondary,
                                  height: 1.5,
                                ),
                              ),
                            if (widget.pricingStartUsd != null &&
                                widget.pricingNotesJa != null)
                              const SizedBox(width: 6),
                            if (widget.pricingNotesJa != null)
                              Tooltip(
                                message: widget.pricingNotesJa ?? '',
                                child: const Icon(
                                  Icons.info_outline,
                                  size: 14,
                                  color: _textMuted,
                                ),
                              ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 22),
                    Text(
                      '${_info.emoji} ${_info.name} の代わりに\n自分株式会社を使う',
                      style: const TextStyle(
                        fontFamily: 'NotoSansJP',
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.96,
                        color: _textPrimary,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _info.tagline,
                      style: const TextStyle(
                        fontSize: 16,
                        color: _textSecondary,
                        height: 1.75,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 14,
                      runSpacing: 14,
                      children: [
                        _buildMetricCard(
                          icon: Icons.layers_rounded,
                          label: '共通コア機能',
                          value: '$_sharedFeatureCount個',
                          accent: _info.accentColor,
                        ),
                        _buildMetricCard(
                          icon: Icons.auto_awesome_rounded,
                          label: '乗り換えメリット',
                          value: '+$_ourAdvantageCount個',
                          accent: _indigo,
                        ),
                        _buildMetricCard(
                          icon: _hasImportSupport
                              ? Icons.move_down_rounded
                              : Icons.timer_rounded,
                          label: _hasImportSupport ? '移行方法' : '開始時間',
                          value: _hasImportSupport ? 'データ引継ぎ可' : '30秒で開始',
                          accent: _orange,
                        ),
                      ],
                    ),
                    const SizedBox(height: 26),
                    if (compact)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildPrimaryHeroButton(context),
                          const SizedBox(height: 12),
                          _buildSecondaryHeroButton(context),
                        ],
                      )
                    else
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _buildPrimaryHeroButton(context),
                          _buildSecondaryHeroButton(context),
                        ],
                      ),
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: _surfaceSecondary,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _borderColor),
                      ),
                      child: const Wrap(
                        spacing: 12,
                        runSpacing: 10,
                        children: [
                          _BenefitPill(
                            icon: Icons.check_circle_outline_rounded,
                            label: 'タスク・ノート・習慣を横断',
                          ),
                          _BenefitPill(
                            icon: Icons.savings_outlined,
                            label: '無料で比較しながら移行',
                          ),
                          _BenefitPill(
                            icon: Icons.psychology_alt_outlined,
                            label: 'AIが今日の最優先を整理',
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOutcomeCards() {
    final cards = [
      _buildOutcomeCard(
        icon: Icons.hub_rounded,
        title: '${_info.name} だけでは足りない作業をひとつに集約',
        body: 'ノート・タスク・財務・習慣・AI大学まで、別アプリで分かれていた流れをまとめます。',
        accent: _info.accentColor,
      ),
      _buildOutcomeCard(
        icon: Icons.currency_yen_rounded,
        title: 'まず無料で始めて、必要になってから広げる',
        body: '比較検討の段階でも登録しやすく、月額の積み上がりを気にせず試せます。',
        accent: _orange,
      ),
      _buildOutcomeCard(
        icon: Icons.auto_graph_rounded,
        title: 'AI が「今日やること」を1件に絞る',
        body: '${_info.name} の単機能では埋まらない、判断・実行・振り返りまでを一気通貫で支援します。',
        accent: _indigo,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 760) {
                return Column(
                  children: cards
                      .map(
                        (card) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: card,
                        ),
                      )
                      .toList(),
                );
              }

              return Row(
                children: [
                  for (var i = 0; i < cards.length; i++) ...[
                    Expanded(child: cards[i]),
                    if (i != cards.length - 1) const SizedBox(width: 12),
                  ],
                ],
              );
            },
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
          constraints: const BoxConstraints(maxWidth: 1040),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_info.name} を使っていて詰まりやすいポイント',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.72,
                  color: _textPrimary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '今のツールで十分そうに見えても、日々の運用ではここがボトルネックになりがちです。',
                style: TextStyle(
                  fontSize: 14,
                  color: _textSecondary,
                  height: 1.7,
                ),
              ),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 760;
                  final items = <Widget>[];

                  for (var i = 0; i < _info.painPoints.length; i++) {
                    items.add(
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: _surfacePrimary,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _borderColor),
                        ),
                        child: Text(
                          '${i + 1}. ${_info.painPoints[i]}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: _textSecondary,
                            height: 1.7,
                          ),
                        ),
                      ),
                    );
                  }

                  if (compact) {
                    return Column(
                      children: items
                          .map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: item,
                            ),
                          )
                          .toList(),
                    );
                  }

                  return Row(
                    children: [
                      for (var i = 0; i < items.length; i++) ...[
                        Expanded(child: items[i]),
                        if (i != items.length - 1) const SizedBox(width: 12),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureTable() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '機能比較',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.72,
                  color: _textPrimary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${_info.name} と共通で持っている核は残しつつ、自分株式会社側の追加メリットを見える化しています。',
                style: const TextStyle(
                  fontSize: 14,
                  color: _textSecondary,
                  height: 1.7,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                decoration: BoxDecoration(
                  color: _surfacePrimary,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: _borderColor),
                ),
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: _surfaceSecondary,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          const Expanded(
                            flex: 5,
                            child: Text(
                              '比較項目',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: _textPrimary,
                                height: 1.5,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              _info.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: _textSecondary,
                                height: 1.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const Expanded(
                            flex: 2,
                            child: Text(
                              '自分株式会社',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: _indigo,
                                height: 1.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final feature in _info.features)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _FeatureRowCard(
                          feature: feature,
                          competitorName: _info.name,
                          accentColor: _info.accentColor,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchPlan(BuildContext context) {
    final steps = [
      _buildStepCard(
        number: '01',
        title: _switchStepTitle,
        body: _switchStepBody,
        accent: _info.accentColor,
      ),
      _buildStepCard(
        number: '02',
        title: '今日の最重要タスクを AI に任せる',
        body: 'ノート・タスク・習慣・財務を横断して、今やるべき1件を先に見つけられます。',
        accent: _indigo,
      ),
      _buildStepCard(
        number: '03',
        title: '必要になった機能だけ横に増やす',
        body: '${_info.name} 単体では届かない資産管理・AI大学・部署AIまで、後から同じアプリ内で広げられます。',
        accent: _orange,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _surfacePrimary,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: _borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '乗り換えの進め方',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.72,
                    color: _textPrimary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  '一気に全部を置き換えなくても大丈夫です。まず入口をひとつにして、そこから必要な機能を足していけます。',
                  style: TextStyle(
                    fontSize: 14,
                    color: _textSecondary,
                    height: 1.7,
                  ),
                ),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < 760) {
                      return Column(
                        children: steps
                            .map(
                              (step) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: step,
                              ),
                            )
                            .toList(),
                      );
                    }

                    return Row(
                      children: [
                        for (var i = 0; i < steps.length; i++) ...[
                          Expanded(child: steps[i]),
                          if (i != steps.length - 1) const SizedBox(width: 12),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildPrimaryHeroButton(context),
                    _buildSecondaryHeroButton(context),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRelatedComparisons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '他の比較ページも見る',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.72,
                  color: _textPrimary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '比較検討の途中なら、近いカテゴリの競合ページもすぐ見比べられます。',
                style: TextStyle(
                  fontSize: 14,
                  color: _textSecondary,
                  height: 1.7,
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _relatedCompetitors.map((entry) {
                  final key = entry.key;
                  final info = entry.value;
                  return InkWell(
                    onTap: () => Navigator.of(context).pushNamed('/vs-$key'),
                    borderRadius: BorderRadius.circular(18),
                    child: Ink(
                      width: 190,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _surfacePrimary,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: _borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${info.emoji} ${info.name}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _textPrimary,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            info.searchKeyword,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: _textSecondary,
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _info.accentColor.withValues(alpha: 0.9),
                  _indigo,
                ],
              ),
              borderRadius: BorderRadius.circular(30),
            ),
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                Text(
                  '次は ${_info.name} の代替を\n実際に試す番です',
                  style: const TextStyle(
                    fontFamily: 'NotoSansJP',
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                    letterSpacing: 0.96,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  _hasImportSupport
                      ? '既存データを残したまま移行できます。まずは無料で登録して、必要ならインポートから始めてください。'
                      : 'クレジットカード不要。比較しながら試して、必要な機能だけあとから広げられます。',
                  style: const TextStyle(
                    color: Color(0xFFE5E7EB),
                    fontSize: 14,
                    height: 1.8,
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
                      label: const Text(
                        '無料で自分株式会社を始める',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: _textPrimary,
                        foregroundColor: _indigo,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 16,
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).pushNamed(
                        _hasImportSupport ? '/import' : '/',
                      ),
                      icon: Icon(
                        _hasImportSupport
                            ? Icons.upload_file_rounded
                            : Icons.dashboard_customize_rounded,
                        size: 18,
                      ),
                      label: Text(
                        _hasImportSupport
                            ? '${_info.name} からインポート'
                            : 'ホームで全機能を見る',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _textPrimary,
                        side: const BorderSide(color: Color(0xFFE5E7EB)),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTag({
    required IconData icon,
    required String label,
    required Color backgroundColor,
    required Color foregroundColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foregroundColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: foregroundColor,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required String label,
    required String value,
    required Color accent,
  }) {
    return Container(
      constraints: const BoxConstraints(minWidth: 170),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceSecondary,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.34)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: accent),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: _textMuted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOutcomeCard({
    required IconData icon,
    required String title,
    required String body,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surfacePrimary,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
              fontSize: 13,
              color: _textSecondary,
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepCard({
    required String number,
    required String title,
    required String body,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surfaceSecondary,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            number,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: accent,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
              fontSize: 13,
              color: _textSecondary,
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryHeroButton(BuildContext context) {
    return FilledButton.icon(
      onPressed: () =>
          Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false),
      icon: const Icon(Icons.rocket_launch, size: 18),
      label: const Text('無料で始める（30秒）'),
      style: FilledButton.styleFrom(
        backgroundColor: _indigo,
        foregroundColor: _textPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    );
  }

  Widget _buildSecondaryHeroButton(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () =>
          Navigator.of(context).pushNamed(_hasImportSupport ? '/import' : '/'),
      icon: Icon(
        _hasImportSupport
            ? Icons.upload_file_rounded
            : Icons.dashboard_customize_rounded,
        size: 18,
      ),
      label: Text(_hasImportSupport ? '${_info.name} からインポート' : 'ホームで全機能を見る'),
      style: OutlinedButton.styleFrom(
        foregroundColor: _textPrimary,
        side: const BorderSide(color: _borderColor),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    );
  }
}

class _PricingBadge extends StatelessWidget {
  final String tier;
  const _PricingBadge({required this.tier});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (tier) {
      'free' => ('完全無料', const Color(0xFF4CAF50)),
      'freemium' => ('無料プランあり', const Color(0xFF009688)),
      'paid' => ('有料', const Color(0xFFFF9800)),
      'enterprise' => ('要見積', const Color(0xFF607D8B)),
      _ => ('?', const Color(0xFF9E9E9E)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          height: 1.4,
        ),
      ),
    );
  }
}

class _JapanPresenceBadge extends StatelessWidget {
  final String level;
  const _JapanPresenceBadge({required this.level});

  @override
  Widget build(BuildContext context) {
    final (emoji, label, color) = switch (level) {
      'dominant' => ('🇯🇵', '日本No.1', const Color(0xFFE53935)),
      'strong' => ('🇯🇵', '日本主要', const Color(0xFFFF6B35)),
      'growing' => ('📈', '日本成長中', const Color(0xFFFFB300)),
      'limited' => ('🌐', '日本限定的', const Color(0xFF607D8B)),
      'not_present' => ('⚠️', '日本未展開', const Color(0xFF9E9E9E)),
      _ => ('', '', const Color(0xFF9E9E9E)),
    };
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$emoji $label',
        style: TextStyle(
          color: color,
          fontSize: 11,
          height: 1.4,
        ),
      ),
    );
  }
}

class _BenefitPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _BenefitPill({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _ComparisonShellState._pageBackground,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _ComparisonShellState._borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: _ComparisonShellState._textSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: _ComparisonShellState._textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureRowCard extends StatelessWidget {
  final _FeatureComparison feature;
  final String competitorName;
  final Color accentColor;

  const _FeatureRowCard({
    required this.feature,
    required this.competitorName,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    Widget buildStatus(String label, bool value, Color highlight) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: highlight.withValues(alpha: value ? 0.16 : 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: highlight.withValues(alpha: value ? 0.3 : 0.18),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              value ? Icons.check_circle_rounded : Icons.cancel_rounded,
              size: 18,
              color: value ? highlight : _ComparisonShellState._textMuted,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: value
                    ? _ComparisonShellState._textPrimary
                    : _ComparisonShellState._textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 640;

        if (compact) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _ComparisonShellState._surfaceSecondary,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feature.feature,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _ComparisonShellState._textPrimary,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    buildStatus(
                      competitorName,
                      feature.competitorHas,
                      accentColor,
                    ),
                    buildStatus(
                      '自分株式会社',
                      feature.weHave,
                      _ComparisonShellState._indigo,
                    ),
                  ],
                ),
              ],
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _ComparisonShellState._surfaceSecondary,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 5,
                child: Text(
                  feature.feature,
                  style: const TextStyle(
                    fontSize: 14,
                    color: _ComparisonShellState._textPrimary,
                    height: 1.6,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Center(
                  child: buildStatus(
                    competitorName,
                    feature.competitorHas,
                    accentColor,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: Center(
                  child: buildStatus(
                    '自分株式会社',
                    feature.weHave,
                    _ComparisonShellState._indigo,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
