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
