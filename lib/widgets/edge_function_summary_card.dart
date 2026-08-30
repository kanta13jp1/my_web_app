import 'package:flutter/material.dart';

/// ホーム画面用: Edge Function 一覧の簡易表示カード。
///
/// 全 Edge Functions を UI 有無別に集計して表示し、
/// 各 Function の UI 操作手順または「UI未実装」を示す。
/// 詳細は EdgeFunctionStatusPage (/edge-functions) へリンク。
class EdgeFunctionSummaryCard extends StatefulWidget {
  const EdgeFunctionSummaryCard({super.key});

  @override
  State<EdgeFunctionSummaryCard> createState() =>
      _EdgeFunctionSummaryCardState();
}

class _EdgeFunctionSummaryCardState extends State<EdgeFunctionSummaryCard> {
  bool _expanded = false;

  // Edge Function の定義 (EdgeFunctionStatusPage と同期)
  static const List<_FnDef> _functions = [
    _FnDef('get-home-dashboard', 'ホーム画面の統合データ', true, '/home', 'ホーム画面を開く'),
    _FnDef(
      'ai-assistant',
      'AI アシスタント (汎用)',
      true,
      '/agents',
      'ホーム > AI組織OS をタップ',
    ),
    _FnDef(
      'growth-weekly-digest',
      '週次グロース指標',
      true,
      '/growth-mission',
      '成長ミッション > 週次',
    ),
    _FnDef(
      'get-public-memo-preview',
      '公開メモ SEO プレビュー',
      false,
      null,
      'サーバーサイド専用 (index.html SEO pre-rendering)',
    ),
    _FnDef(
      'local-election-intelligence',
      '選挙インテリジェンス',
      true,
      '/election-dashboard',
      '選挙戦略ページ > AI分析',
    ),
    _FnDef(
      'memo-reactions',
      '公開メモ絵文字リアクション',
      true,
      '/public-memos',
      '公開メモ詳細 > 絵文字リアクションバー',
    ),
    // --- 追加 Edge Functions ---
    // 追加 (session432o)
    // 追加 (session432p-432q: 185→195)
    // 追加 (session432r-432t: 195→210)
    // 追加 (session432u: 210→215)
    // 追加 (cs-check 自動連携)
    // 追加 (cs-check 自動連携)
    _FnDef(
      'guitar-recording-studio',
      'ギターレコーディングスタジオ + 公開ギャラリー',
      true,
      '/guitar-recording-studio',
      'スタジオ (/guitar-recording-studio) / 公開ギャラリー (/public-guitar-gallery)',
    ),
    // 追加 (cs-check 自動連携)
    // 追加 (cs-check 自動連携)
    // 追加 (cs-check 自動連携)
    // 追加 (cs-check 自動連携)
    // 追加 (cs-check 自動連携)
    // 追加 (cs-check 自動連携)
    // 追加 (cs-check 自動連携)
    _FnDef(
      'core-hub',
      'コアハブ (ホームダッシュボード/チャット/AI/成長統合)',
      true,
      '/home',
      'ホーム画面 (統合API経由)',
    ),
    _FnDef(
      'enterprise-hub',
      'エンタープライズハブ (業務管理/CRM/BI/コンプライアンス統合)',
      true,
      '/admin',
      '管理者ダッシュボード > エンタープライズ機能',
    ),
    _FnDef(
      'lifestyle-hub',
      'ライフスタイルハブ (健康/旅行/スマートホーム/通知統合)',
      true,
      '/home',
      'ホーム > 生活管理カード',
    ),
    _FnDef(
      'media-hub',
      'メディアハブ (動画/音声/ドキュメント/会議統合)',
      true,
      '/admin',
      '管理者ダッシュボード > メディア管理',
    ),
    _FnDef(
      'social-commerce-hub',
      'ソーシャル・コマースハブ (SNS/EC/決済/学習統合)',
      true,
      '/social-feed',
      'ソーシャルフィード > コマース機能',
    ),
    _FnDef(
      'tools-hub',
      'ツールハブ (生産性ツール/メモ/習慣/テンプレート統合)',
      true,
      '/home',
      'ホーム > クイックアクセス > ツール',
    ),
    // 追加 (cs-check 自動連携)
    _FnDef(
      'admin-hub',
      '管理者ハブ統合 (CS/競合/ユーザー/統計)',
      true,
      '/admin',
      '管理者ダッシュボード > 統合管理',
    ),
    _FnDef(
      'ai-hub',
      'AIハブ統合 (要約/選挙分析/トリガー)',
      true,
      '/ai-summarizer',
      'AI要約ページ / 選挙戦略ページ > AIアシスタント',
    ),
    _FnDef(
      'growth-hub',
      '成長ハブ統合 (グロース指令/自動化/週次)',
      true,
      '/growth-mission',
      '成長ミッションページ > グロース指令センター',
    ),
    _FnDef(
      'schedule-hub',
      'スケジュールハブ統合 (実行ログ/ヘルスチェック/結果/モニター)',
      true,
      '/admin',
      '管理者ダッシュボード > Schedule モニター',
    ),
    // 追加 (cs-check 自動連携)
    _FnDef(
      'app-hub',
      'アプリハブ統合 (サブスクリプション/カレンダー/タスク/チャット統合)',
      true,
      '/app-hub',
      'アプリハブページ',
    ),
    // 追加 (cs-check 自動連携 2026-04-17)
    // 追加 (cs-check 自動連携 2026-04-12)
    // 追加 (cs-check 自動連携 2026-04-18)
    _FnDef(
      'agent-hub',
      'AIエージェントハブ (部署/パフォーマンス/ルーティング統合)',
      true,
      '/agent-hub',
      'AIエージェントハブページ > 部署・パフォーマンス・タスクルーティング',
    ),
    _FnDef(
      'admin-notification-hub',
      '管理者通知ハブ (緊急/警告/情報通知管理)',
      true,
      '/admin-notifications',
      '管理者通知ハブページ > 重要度別通知フィルタリング',
    ),
    // 追加 (cs-check 自動連携 2026-04-18)
    _FnDef(
      'daily-judgment',
      'AI デイリー判定',
      true,
      '/daily-judgment',
      'デイリー判定ページ > AIによる今日の優先事項・判断',
    ),
    _FnDef(
      'ai-university-content',
      'AI大学コンテンツ管理 (UPSERT/GET)',
      true,
      '/ai-university-content',
      'AI大学コンテンツページ > プロバイダー別コンテンツ一覧',
    ),
    _FnDef(
      'development-achievements',
      '開発実績一覧',
      true,
      '/development-achievements',
      '開発実績ページ > 完了済みタスク・実績リスト',
    ),
    // 追加 (cs-check 自動連携 2026-04-18)
    _FnDef(
      'semantic-search',
      'セマンティック検索 (意味ベース検索)',
      true,
      '/semantic-search',
      'セマンティック検索ページ > キーワード入力で意味ベース検索',
    ),
    _FnDef(
      'sitemap-analytics',
      'サイトマップ・Web分析',
      true,
      '/sitemap-analytics',
      'サイトマップ分析ページ > ページ別アクセス数・直帰率',
    ),
    _FnDef(
      'social-feed',
      'ソーシャルフィード (投稿フィード)',
      true,
      '/social-feed',
      'ソーシャルフィードページ > 公開/フォロー別フィード表示',
    ),
    // 追加 (cs-check 自動連携 2026-04-18)
    _FnDef(
      'notification-digest',
      '通知ダイジェスト',
      true,
      '/notification-digest',
      '通知ダイジェストページ > 未読・本日・重要通知サマリー',
    ),
    // 追加 (cs-check 自動連携 2026-04-18)
    _FnDef(
      'affiliate-marketing',
      'アフィリエイトマーケティング管理',
      true,
      '/affiliate-marketing',
      'アフィリエイトマーケティングページ > プログラム一覧・成果確認',
    ),
    _FnDef(
      'ai-image-generator',
      'AI画像生成',
      true,
      '/ai-image-generator',
      'AI画像生成ページ > プロンプト入力で画像生成',
    ),
    _FnDef(
      'ai-secretary',
      'AIセクレタリー (スケジュール・タスク管理)',
      true,
      '/ai-secretary',
      'AIセクレタリーページ > 今日のスケジュール・優先タスク確認',
    ),
    // 追加 (cs-check 自動連携 2026-04-18)
    _FnDef(
      'ai-summarizer',
      'AI要約 (テキスト・URL要約)',
      true,
      '/ai-summarizer',
      'AI要約ページ > テキストまたはURL入力で要約生成',
    ),
    _FnDef(
      'ai-writing-assistant',
      'AI文章アシスタント',
      true,
      '/ai-writing-assistant',
      'AI文章アシスタントページ > 文章生成・校正・翻訳',
    ),
    _FnDef(
      'analytics-export',
      'アナリティクスエクスポート',
      true,
      '/analytics-export',
      'アナリティクスエクスポートページ > CSV/JSONデータエクスポート',
    ),
    // 追加 (cs-check 自動連携 2026-04-18)
    _FnDef(
      'ai-university-badges',
      'AI大学 達成バッジ管理',
      true,
      '/ai-university-badges',
      'AI大学バッジページ > 取得バッジ一覧・条件確認',
    ),
    _FnDef(
      'ai-university-streaks',
      'AI大学 連続学習ストリーク',
      true,
      '/ai-university-streaks',
      'AI大学ストリークページ > 連続学習日数・ランキング',
    ),
    _FnDef(
      'ai-workflow-automation',
      'AIワークフロー自動化',
      true,
      '/ai-workflow-automation',
      'AIワークフロー自動化ページ > ワークフロー一覧・管理',
    ),
    // 追加 (cs-check 自動連携 2026-04-19)
    _FnDef(
      'knowledge-base',
      'ナレッジベース (記事・FAQ管理)',
      true,
      '/knowledge-base',
      'ナレッジベースページ > 記事検索・カテゴリ別閲覧',
    ),
    _FnDef(
      'podcast-manager',
      'ポッドキャストマネージャー',
      true,
      '/podcast-manager',
      'ポッドキャストページ > 番組一覧・エピソード再生',
    ),
    _FnDef(
      'virtual-pet',
      'バーチャルペット',
      true,
      '/virtual-pet',
      'バーチャルペットページ > ペット育成・ステータス確認',
    ),
    // 追加 (cs-check 自動連携 2026-04-19)
    _FnDef(
      'access-control',
      'アクセス制御 (ロール・権限管理)',
      true,
      '/access-control',
      'アクセス制御ページ > ロール一覧・権限設定',
    ),
    _FnDef(
      'loyalty-points',
      'ロイヤルティポイント管理',
      true,
      '/loyalty-points',
      'ロイヤルティポイントページ > ポイント残高・履歴確認',
    ),
    _FnDef(
      'voice-memo-transcriber',
      '音声メモ文字起こし',
      true,
      '/voice-memo',
      '音声メモページ > 録音・文字起こし・一覧表示',
    ),
    // 追加 (cs-check 自動連携 2026-04-19)
    _FnDef(
      'habit-tracker',
      '習慣トラッカー',
      true,
      '/habit-tracker',
      '習慣トラッカーページ > 習慣追加・チェックイン・ストリーク確認',
    ),
    _FnDef(
      'social-media-scheduler',
      'SNS投稿スケジューラー',
      true,
      '/social-media-scheduler',
      'SNSスケジューラーページ > 投稿予約・プラットフォーム選択',
    ),
    _FnDef(
      'address-book',
      'アドレス帳 (連絡先管理)',
      true,
      '/address-book',
      'アドレス帳ページ > 連絡先追加・検索・グループ管理',
    ),
    _FnDef(
      'goal-tracker',
      'ゴールトラッカー (目標管理)',
      true,
      '/goal-tracker',
      'ゴール管理ページ > 目標設定・進捗追跡・達成確認',
    ),
    _FnDef(
      'fitness-health-tracker',
      'フィットネス・健康トラッカー',
      true,
      '/fitness-health-tracker',
      '健康管理ページ > 運動記録・健康指標・フィットネス目標',
    ),
    // 追加 (cs-check 自動連携 2026-04-19)
    _FnDef(
      'leave-management',
      '休暇・休職管理',
      true,
      '/leave-management',
      '休暇管理ページ > 休暇申請・承認状況確認',
    ),
    _FnDef(
      'performance-review',
      'パフォーマンスレビュー (自己評価・フィードバック)',
      true,
      '/performance-review',
      'パフォーマンスレビューページ > 評価期間別レビュー提出・履歴確認',
    ),
    // 追加 (cs-check 自動連携 2026-04-19)
    _FnDef(
      'calendar-events',
      'カレンダーイベント管理',
      true,
      '/calendar-events',
      'カレンダーページ > イベント一覧・追加・編集',
    ),
    _FnDef(
      'expense-tracker',
      '支出トラッカー (家計簿)',
      true,
      '/expense-tracker',
      '支出トラッカーページ > 支出記録・カテゴリ別集計',
    ),
    _FnDef(
      'reading-list',
      '読書リスト管理',
      true,
      '/reading-list',
      '読書リストページ > 読書中・未読・完読リスト管理',
    ),
    // 追加 (cs-check 自動連携 2026-04-19)
    _FnDef(
      'analyze-reality',
      '現実分析 (目標vs現状ギャップ分析)',
      true,
      '/analyze-reality',
      '現実分析ページ > 目標入力・現状分析・改善提案',
    ),
    _FnDef(
      'appointment-scheduler',
      'アポイントメントスケジューラー',
      true,
      '/appointment-scheduler',
      'スケジューラーページ > 予約枠管理・アポ設定',
    ),
    _FnDef(
      'ar-navigation',
      'ARナビゲーション',
      true,
      '/ar-navigation',
      'ARナビページ > 目的地設定・AR経路表示',
    ),
    // 追加 (cs-check 自動連携 2026-04-19)
    _FnDef(
      'auction-marketplace',
      'オークションマーケットプレイス',
      true,
      '/auction-marketplace',
      'オークションページ > 出品・入札・落札管理',
    ),
    _FnDef(
      'audio-effects-processor',
      '音声エフェクトプロセッサー',
      true,
      '/audio-effects-processor',
      '音声エフェクトページ > エフェクト適用・音声加工',
    ),
    _FnDef(
      'bookmark-sync',
      'ブックマーク同期',
      true,
      '/bookmark-sync',
      'ブックマーク同期ページ > ブックマーク一覧・デバイス間同期',
    ),
    // 追加 (cs-check 自動連携 2026-04-19)
    _FnDef(
      'budget-financial-planner',
      '予算・財務プランナー',
      true,
      '/budget-financial-planner',
      '予算管理ページ > 収支入力・予算設定・財務分析',
    ),
    _FnDef(
      'carbon-footprint-tracker',
      'カーボンフットプリントトラッカー',
      true,
      '/carbon-footprint',
      'カーボンフットプリントページ > CO2排出量記録・削減目標管理',
    ),
    _FnDef(
      'customer-feedback',
      'カスタマーフィードバック管理',
      true,
      '/customer-feedback',
      'フィードバックページ > 顧客フィードバック収集・分析・対応状況確認',
    ),
    // 追加 (cs-check 自動連携 2026-04-19)
    _FnDef(
      'digital-wallet',
      'デジタルウォレット (資産管理)',
      true,
      '/digital-wallet',
      'デジタルウォレットページ > 残高確認・送金・取引履歴',
    ),
    _FnDef(
      'time-tracker',
      '時間トラッカー (作業時間記録)',
      true,
      '/time-tracker',
      '時間トラッカーページ > タスク別作業時間記録・集計',
    ),
    // 追加 (cs-check 自動連携 2026-04-19)
    _FnDef(
      'document-esignature',
      '電子署名 (ドキュメント署名管理)',
      true,
      '/document-esignature',
      '電子署名ページ > ドキュメント署名依頼・署名状況確認',
    ),
    _FnDef(
      'elearning-course-manager',
      'eラーニングコース管理',
      true,
      '/elearning-course-manager',
      'eラーニングページ > コース一覧・受講進捗確認',
    ),
    _FnDef(
      'email-template-builder',
      'メールテンプレートビルダー',
      true,
      '/email-template-builder',
      'メールテンプレートページ > テンプレート作成・プレビュー・送信',
    ),
    // 追加 (cs-check 自動連携 2026-04-20)
    _FnDef(
      'donation-crowdfunding',
      'ドネーション・クラウドファンディング管理',
      true,
      '/donation',
      'ドネーションページ > 寄付プロジェクト一覧・支援状況確認',
    ),
    _FnDef(
      'emergency-contacts',
      '緊急連絡先管理',
      true,
      '/emergency-contacts',
      '緊急連絡先ページ > 連絡先登録・グループ設定',
    ),
    _FnDef(
      'event-ticketing',
      'イベントチケット管理',
      true,
      '/event-ticketing',
      'イベントチケットページ > イベント作成・チケット発行・参加者管理',
    ),
    // 追加 (cs-check 自動連携 2026-04-20)
    _FnDef(
      'discord-notifications',
      'Discord通知管理',
      true,
      '/discord-notifications',
      'Discord通知ページ > チャンネル設定・通知送信・履歴確認',
    ),
    _FnDef(
      'family-sharing-manager',
      'ファミリー共有管理',
      true,
      '/family-sharing',
      'ファミリー共有ページ > メンバー招待・共有リスト・アクセス権限管理',
    ),
    _FnDef(
      'meeting-manager',
      'ミーティング管理',
      true,
      '/meeting-manager',
      'ミーティング管理ページ > 会議スケジュール・議事録・参加者管理',
    ),
    // 追加 (cs-check 自動連携 2026-04-20)
    _FnDef(
      'feature-flags',
      'フィーチャーフラグ管理',
      true,
      '/feature-flags',
      'フィーチャーフラグページ > フラグ作成・ロールアウト率・A/Bテスト連携',
    ),
    _FnDef(
      'personal-dashboard',
      'パーソナルダッシュボード (KPI・週次推移・習慣)',
      true,
      '/personal-dashboard',
      'パーソナルダッシュボードページ > KPI確認・週次アクティビティ・習慣統計',
    ),
    _FnDef(
      'smart-inbox-triage',
      'スマート受信トレイ (マルチチャネル統合)',
      true,
      '/smart-inbox',
      'スマート受信トレイページ > メール/Slack/LINE統合受信箱・AI優先度分類',
    ),
    // 追加 (cs-check 自動連携 2026-04-20)
    _FnDef(
      'home-iot-manager',
      'スマートホーム IoT デバイス管理',
      true,
      '/home-iot',
      'スマートホーム IoT ページ > デバイス一覧・オン/オフ制御・温度湿度確認',
    ),
    _FnDef(
      'qr-code-generator',
      'QRコードジェネレーター',
      true,
      '/qr-code-generator',
      'QRコード生成ページ > テキスト/URL入力でQRコード生成・ダウンロード',
    ),
    _FnDef(
      'recipe-meal-planner',
      'レシピ・食事プランナー',
      true,
      '/recipe-meal-planner',
      'レシピ・食事プランナーページ > レシピ検索・週間食事プラン作成',
    ),
    // 追加 (cs-check 自動連携 2026-04-20)
    _FnDef(
      'focus-timer',
      'フォーカスタイマー (深集中セッション管理)',
      true,
      '/focus-timer',
      'フォーカスタイマーページ > 集中セッション開始・履歴確認',
    ),
    _FnDef(
      'form-builder',
      'フォームビルダー (カスタムフォーム作成)',
      true,
      '/form-builder',
      'フォームビルダーページ > フォーム作成・公開・回答一覧',
    ),
    _FnDef(
      'language-learning',
      '語学学習 (多言語レッスン管理)',
      true,
      '/language-learning',
      '語学学習ページ > レッスン選択・進捗確認・単語練習',
    ),
    // 追加 (cs-check 自動連携 2026-04-20)
    _FnDef(
      'password-vault',
      'パスワード金庫 (認証情報管理)',
      true,
      '/password-vault',
      'パスワード金庫ページ > 保存済みパスワード一覧・新規追加',
    ),
    _FnDef(
      'virtual-whiteboard',
      'バーチャルホワイトボード (共同作業)',
      true,
      '/virtual-whiteboard',
      'バーチャルホワイトボードページ > ボード一覧・新規作成・共有',
    ),
    _FnDef(
      'workflow-templates',
      'ワークフローテンプレート管理',
      true,
      '/workflow-templates',
      'ワークフローテンプレートページ > テンプレート一覧・ギャラリー表示',
    ),
    // 追加 (cs-check 自動連携 2026-04-20)
    _FnDef(
      'gift-registry',
      'ギフトレジストリ (ギフトリスト管理)',
      true,
      '/gift-registry',
      'ギフトレジストリページ > ギフトリスト追加・共有・達成状況確認',
    ),
    _FnDef(
      'mindmap-diagram',
      'マインドマップ・ダイアグラム作成',
      true,
      '/mindmap',
      'マインドマップページ > ノード追加・接続・図の編集',
    ),
    _FnDef(
      'music-collaboration',
      '音楽コラボレーション (セッション管理)',
      true,
      '/music-collaboration',
      '音楽コラボページ > セッション一覧・参加・楽曲共有',
    ),
    // 追加 (cs-check 自動連携 2026-04-20)
    _FnDef(
      'changelog-manager',
      'チェンジログ管理 (一覧/詳細)',
      true,
      '/changelog',
      'チェンジログページ > 変更履歴一覧',
    ),
    _FnDef(
      'travel-itinerary-planner',
      '旅行プランナー (旅程管理)',
      true,
      '/travel-itinerary',
      '旅行プランナーページ > 旅程作成・管理',
    ),
    // 追加 (cs-check 自動連携 2026-04-20)
    _FnDef(
      'dns-domain-manager',
      'DNS・ドメイン管理',
      true,
      '/dns-domain-manager',
      'DNS・ドメイン管理ページ > ドメイン一覧・DNSレコード設定',
    ),
    _FnDef(
      'inventory-barcode',
      '在庫・バーコード管理',
      true,
      '/inventory-barcode',
      '在庫管理ページ > バーコードスキャン・在庫登録・一覧表示',
    ),
    _FnDef(
      'legal-compliance-manager',
      'リーガルコンプライアンス管理',
      true,
      '/legal-compliance',
      'コンプライアンスページ > 規制要件確認・リスク管理・監査ログ',
    ),
    // 追加 (cs-check 自動連携 2026-04-20)
    _FnDef(
      'github-pr-manager',
      'GitHub PR管理 (プルリクエスト一覧・レビュー)',
      true,
      '/github-pr',
      'GitHub PRページ > PR一覧・レビュー・マージ管理',
    ),
    _FnDef(
      'parking-reservation',
      '駐車場予約管理',
      true,
      '/parking-reservation',
      '駐車場予約ページ > 予約確認・空き状況・キャンセル管理',
    ),
    _FnDef(
      'pet-care-manager',
      'ペットケア管理',
      true,
      '/pet-care',
      'ペットケアページ > ペット情報登録・ケアスケジュール・ワクチン記録',
    ),
    // 追加 (cs-check 自動連携 2026-04-20)
    _FnDef(
      'music-playlist-manager',
      '音楽プレイリスト管理 (再生リスト作成・編集)',
      true,
      '/music-playlist-manager',
      '音楽プレイリストページ > プレイリスト作成・曲追加・再生',
    ),
    _FnDef(
      'photo-gallery-manager',
      'フォトギャラリー管理 (写真アルバム・共有)',
      true,
      '/photo-gallery',
      'フォトギャラリーページ > アルバム作成・写真アップロード・共有',
    ),
    // 追加 (cs-check 自動連携 2026-04-20)
    _FnDef(
      'screen-recorder',
      'スクリーンレコーダー (録画・ダウンロード)',
      true,
      '/screen-recorder',
      'スクリーンレコーダーページ > 録画開始・停止・ダウンロード',
    ),
    _FnDef(
      'recruitment-job-board',
      '採用・求人ボード管理',
      true,
      '/recruitment',
      '採用求人ボードページ > 求人一覧・応募管理・ステータス更新',
    ),
    _FnDef(
      'two-factor-auth',
      '二要素認証 (2FA設定・管理)',
      true,
      '/two-factor-auth',
      '二要素認証ページ > 認証設定・バックアップコード確認',
    ),
    // 追加 (cs-check 自動連携 2026-04-21)
    _FnDef(
      'line-notifications',
      'LINE通知管理 (メッセージ送信・履歴)',
      true,
      '/line-notifications',
      'LINE通知ページ > チャンネル設定・メッセージ送信・送信履歴確認',
    ),
    _FnDef(
      'vehicle-fleet-manager',
      '車両フリート管理 (車両登録・運行管理)',
      true,
      '/vehicle-fleet',
      '車両管理ページ > 車両一覧・走行履歴・メンテナンス記録',
    ),
    _FnDef(
      'video-meeting-manager',
      'ビデオ会議管理 (会議室・録画管理)',
      true,
      '/video-meeting',
      'ビデオ会議ページ > 会議室一覧・参加者管理・録画確認',
    ),
    // 追加 (cs-check 自動連携 2026-04-21)
    _FnDef(
      'viral-video-generator',
      'バイラル動画ジェネレーター (AI動画企画生成)',
      true,
      '/viral-video-generator',
      'バイラル動画ページ > プロンプト入力でバイラル動画企画生成',
    ),
    _FnDef(
      'viral-video-ad-generator',
      'バイラル動画広告ジェネレーター (AI広告動画生成)',
      true,
      '/viral-ad-generator',
      'バイラル広告ジェネレーターページ > ターゲット設定・AI広告動画企画生成',
    ),
    // 追加 (cs-check 自動連携 2026-04-24)
    _FnDef(
      'health-check',
      'インフラ健全性チェック (DB接続・テーブル・EFランタイム)',
      true,
      '/health-check',
      'インフラ健全性ページ > DB接続・テーブルアクセス・EFランタイム状態確認',
    ),
    // 追加 (cs-check 自動連携 2026-04-29)
    _FnDef(
      'memory-search-hub',
      'メモリー検索ハブ (BM25 + ベクター検索 + Haiku リランキング)',
      true,
      '/memory-search',
      'メモリー検索ページ > キーワード入力でBM25+ベクター混合検索',
    ),
    // 追加 (cs-check 自動連携 2026-05-05)
    _FnDef(
      'stripe-webhook',
      'Stripe 決済イベント Webhook (サーバーサイド専用)',
      false,
      null,
      'Stripe → Supabase サーバーサイド専用 (UIなし / 請求管理は /billing)',
    ),
    // 追加 (cs-check 自動連携 2026-07-26)
    _FnDef(
      'autonomous-ops',
      '自律運用エンジン (スケジュール実行・自動タスク管理)',
      true,
      '/autonomous-ops-console',
      '自律運用コンソールページ > タスク実行状況・スケジュール確認',
    ),
    // 追加 (cs-check 自動連携 2026-05-09)
    _FnDef(
      'mcp-well-known',
      'MCP Well-Known URI ディスカバリー (サーバーサイド専用)',
      false,
      null,
      'MCP クライアント向け Well-Known エンドポイント (UIなし / サーバーサイド専用)',
    ),
    // 追加 (cs-check 自動連携 2026-07-29)
    _FnDef(
      'shop-funnel',
      'デジタル商品ストアのファネル (商品一覧・購入フロー)',
      true,
      '/shop',
      'デジタル作品ストア > 商品確認・購入フロー開始',
    ),
    _FnDef(
      'shop-checkout',
      'Stripe Checkout セッション作成 (デジタル商品購入)',
      true,
      '/shop',
      '商品詳細ページ > 購入ボタン → Stripe Checkout へ遷移',
    ),
    _FnDef(
      'shop-download',
      '購入済みデジタル商品の署名付きURL発行',
      true,
      '/shop/downloads',
      '購入済みページ > ダウンロードボタンを押す',
    ),
  ];

  int get _withUiCount => _functions.where((f) => f.hasUi).length;
  int get _noUiCount => _functions.where((f) => !f.hasUi).length;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pct = (_withUiCount / _functions.length * 100).round();
    final noUiFns = _functions.where((f) => !f.hasUi).toList();

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          // ヘッダー
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.api,
                      size: 18,
                      color: Color(0xFF6366F1),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Edge Functions 実装状況',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(
                          height: 2,
                        ),
                        Text(
                          '全 ${_functions.length} 件  |  UI 実装済: $_withUiCount 件  |  UI未実装: $_noUiCount 件  ($pct%)',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? const Color(0xFFBDBDBD)
                                : const Color(0xFF757575),
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 進捗バー
                  SizedBox(
                    width: 60,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$pct%',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF6366F1),
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(
                          height: 4,
                        ),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _withUiCount / _functions.length,
                            minHeight: 6,
                            backgroundColor: isDark
                                ? const Color(0xFF424242)
                                : const Color(0xFFEEEEEE),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF6366F1),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 20,
                    color: isDark
                        ? const Color(0xFFBDBDBD)
                        : const Color(0xFF757575),
                  ),
                ],
              ),
            ),
          ),

          if (_expanded) ...[
            const Divider(
              height: 1,
            ),

            // UI未実装の関数リスト
            if (noUiFns.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 14,
                      color: Color(0xFFFF6B35),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'UI 未実装 / 未連携 ($_noUiCount 件)',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFF6B35),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: noUiFns.length,
                itemBuilder: (context, i) {
                  final fn = noUiFns[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.circle,
                          size: 6,
                          color: Color(0xFFFF6B35),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            fn.name,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              height: 1.5,
                            ),
                          ),
                        ),
                        Text(
                          fn.description,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? const Color(0xFFBDBDBD)
                                : const Color(0xFF757575),
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const Divider(
                height: 16,
              ),
            ],

            // UI実装済み一覧 (最初の10件)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    size: 14,
                    color: Colors.green,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'UI 実装済み ($_withUiCount 件) — 操作手順',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.green,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            ..._functions
                .where((f) => f.hasUi)
                .take(8)
                .map((fn) => _buildFnRow(fn, isDark)),
            if (_withUiCount > 8)
              Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 8),
                child: Text(
                  '他 ${_withUiCount - 8} 件 → 詳細は Edge Functions 状況ページへ',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? const Color(0xFF9E9E9E)
                        : const Color(0xFF9E9E9E),
                    height: 1.5,
                  ),
                ),
              ),

            // 詳細ページへのボタン
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.open_in_new, size: 14),
                  label: const Text('Edge Functions 詳細・テストページ'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF6366F1),
                    side: const BorderSide(color: Color(0xFF6366F1)),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                  onPressed: () =>
                      Navigator.pushNamed(context, '/edge-functions'),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFnRow(_FnDef fn, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.chevron_right, size: 14, color: Colors.green),
          const SizedBox(width: 4),
          SizedBox(
            width: 160,
            child: Text(
              fn.name,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
          ),
          Expanded(
            child: Text(
              fn.uiInstruction ?? '',
              style: TextStyle(
                fontSize: 11,
                color:
                    isDark ? const Color(0xFFBDBDBD) : const Color(0xFF757575),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FnDef {
  final String name;
  final String description;
  final bool hasUi;
  final String? uiPath;
  final String? uiInstruction;

  const _FnDef(
    this.name,
    this.description,
    this.hasUi,
    this.uiPath,
    this.uiInstruction,
  );
}
