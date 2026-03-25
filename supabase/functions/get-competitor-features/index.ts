import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// ---------------------------------------------------------------------------
// Competitor feature data
// ---------------------------------------------------------------------------

const COMPETITOR_DATA = [
  // -------------------------------------------------------------------------
  // Notion
  // -------------------------------------------------------------------------
  {
    id: "notion",
    name: "Notion",
    features: [
      // ---- ノート編集 ----
      {
        category: "ノート編集",
        feature: "リッチテキスト編集",
        competitorDetail: "Markdown + スラッシュコマンドでブロック挿入",
        status: "done",
        appDetail: "Markdown 対応エディタ実装済み",
      },
      {
        category: "ノート編集",
        feature: "AI 文章補助",
        competitorDetail: "Notion AI: 文章生成・改善・要約",
        status: "done",
        appDetail: "AI Secretary / MAGI System で複数モデル対応",
      },
      {
        category: "ノート編集",
        feature: "バージョン履歴",
        competitorDetail: "無料プランは7日間、有料は無制限",
        status: "notYet",
        appDetail: "未実装 — ロードマップに追加予定",
      },
      {
        category: "ノート編集",
        feature: "ファイル添付",
        competitorDetail: "画像・PDF 等をブロックとして埋め込み",
        status: "notYet",
        appDetail: "未実装",
      },
      {
        category: "ノート編集",
        feature: "コードブロック",
        competitorDetail: "シンタックスハイライト付きコードブロック",
        status: "partial",
        appDetail: "Markdown コードフェンス対応済み",
      },
      // ---- 整理・検索 ----
      {
        category: "整理・検索",
        feature: "タグ・カテゴリ",
        competitorDetail: "ページにタグ付け・フィルタリング",
        status: "done",
        appDetail: "カテゴリページ実装済み",
      },
      {
        category: "整理・検索",
        feature: "全文検索",
        competitorDetail: "ページ横断検索・クイックファインド",
        status: "partial",
        appDetail: "AI 検索・埋め込み検索を部分実装",
      },
      {
        category: "整理・検索",
        feature: "テンプレート",
        competitorDetail: "公式テンプレートギャラリー + コミュニティ共有",
        status: "partial",
        appDetail: "テンプレートマーケットプレイス画面実装済み",
      },
      // ---- データベース ----
      {
        category: "データベース",
        feature: "テーブルビュー",
        competitorDetail: "スプレッドシート形式でプロパティ管理",
        status: "notYet",
        appDetail: "未実装 — 中期計画で対応予定",
      },
      {
        category: "データベース",
        feature: "カンバン/ボード",
        competitorDetail: "ステータス別カードビュー",
        status: "notYet",
        appDetail: "未実装 — 中期計画で対応予定",
      },
      {
        category: "データベース",
        feature: "カレンダービュー",
        competitorDetail: "日付プロパティをカレンダーで表示",
        status: "notYet",
        appDetail: "未実装",
      },
      {
        category: "データベース",
        feature: "ガントチャート",
        competitorDetail: "タイムラインビューでスケジュール管理",
        status: "notYet",
        appDetail: "未実装",
      },
      {
        category: "データベース",
        feature: "リレーション・ロールアップ",
        competitorDetail: "DB 間リンクと集計フィールド",
        status: "notYet",
        appDetail: "未実装 — 長期計画で対応予定",
      },
      // ---- 共有・コラボ ----
      {
        category: "共有・コラボ",
        feature: "ページ公開",
        competitorDetail: "URLで誰でも閲覧可能なページ公開",
        status: "done",
        appDetail: "公開メモ機能実装済み・OGP対応",
      },
      {
        category: "共有・コラボ",
        feature: "リアルタイム共同編集",
        competitorDetail: "複数人が同時に編集可能",
        status: "notYet",
        appDetail: "未実装 — 中期計画 (Team workspace) で対応予定",
      },
      {
        category: "共有・コラボ",
        feature: "コメント・メンション",
        competitorDetail: "ブロックへのインラインコメント",
        status: "notYet",
        appDetail: "未実装",
      },
      {
        category: "共有・コラボ",
        feature: "チームワークスペース",
        competitorDetail: "組織単位でのページ・権限管理",
        status: "notYet",
        appDetail: "未実装 — 中期計画で Team/Enterprise 対応予定",
      },
      // ---- 移行・連携 ----
      {
        category: "移行・連携",
        feature: "Notion からインポート",
        competitorDetail: "Notion 公式はエクスポートのみ提供",
        status: "done",
        appDetail: "CSV インポート実装済み・Edge Function first",
      },
      {
        category: "移行・連携",
        feature: "Evernote からインポート",
        competitorDetail: "ENEX インポート対応",
        status: "done",
        appDetail: "ENEX インポート実装済み・Edge Function first",
      },
      {
        category: "移行・連携",
        feature: "Markdown インポート",
        competitorDetail: "Markdown ファイルのインポート可能",
        status: "done",
        appDetail: "Markdown インポート実装済み",
      },
      {
        category: "移行・連携",
        feature: "Web クリッパー",
        competitorDetail: "ブラウザ拡張でウェブページを保存",
        status: "notYet",
        appDetail: "未実装",
      },
      {
        category: "移行・連携",
        feature: "外部サービス連携 (Zapier 等)",
        competitorDetail: "API + Zapier/Make/IFTTT 連携",
        status: "partial",
        appDetail: "Supabase Edge Function 経由で API 公開中",
      },
      // ---- プラットフォーム ----
      {
        category: "プラットフォーム",
        feature: "Web アプリ",
        competitorDetail: "ブラウザで全機能利用可能",
        status: "done",
        appDetail: "Flutter Web 実装済み",
      },
      {
        category: "プラットフォーム",
        feature: "モバイルアプリ (iOS/Android)",
        competitorDetail: "ネイティブアプリ提供",
        status: "inProgress",
        appDetail: "Flutter クロスプラットフォーム対応可能 — リリース準備中",
      },
      {
        category: "プラットフォーム",
        feature: "デスクトップアプリ",
        competitorDetail: "Mac/Windows Electron アプリ",
        status: "inProgress",
        appDetail: "Flutter Desktop 対応可能 — リリース準備中",
      },
      {
        category: "プラットフォーム",
        feature: "オフライン対応",
        competitorDetail: "オフラインでも閲覧・編集可能",
        status: "notYet",
        appDetail: "未実装 — 長期計画で対応予定",
      },
      // ---- 自分株式会社 独自機能 ----
      {
        category: "自分株式会社 独自機能",
        feature: "マインドマップ",
        competitorDetail: "— Notion にはない機能",
        status: "unique",
        appDetail: "ビジュアルマインドマップ実装済み",
      },
      {
        category: "自分株式会社 独自機能",
        feature: "記憶ドリル",
        competitorDetail: "— Notion にはない機能",
        status: "unique",
        appDetail: "スペーシング反復学習ドリル実装済み",
      },
      {
        category: "自分株式会社 独自機能",
        feature: "AI エージェント組織",
        competitorDetail: "— Notion にはない機能",
        status: "unique",
        appDetail: "CEO/CFO/CMO/CHRO 役員会議 AI 実装済み",
      },
      {
        category: "自分株式会社 独自機能",
        feature: "経営コックピット",
        competitorDetail: "— Notion にはない機能",
        status: "unique",
        appDetail: "KPI・資産・習慣を一画面で管理",
      },
      {
        category: "自分株式会社 独自機能",
        feature: "Growth ロードマップ進捗表示",
        competitorDetail: "— Notion にはない機能",
        status: "unique",
        appDetail: "このカードがその機能です",
      },
      {
        category: "自分株式会社 独自機能",
        feature: "Referral 紹介プログラム",
        competitorDetail: "— Notion にはない機能",
        status: "unique",
        appDetail: "anti-abuse 付き referral code 発行・管理実装済み",
      },
    ],
  },

  // -------------------------------------------------------------------------
  // EverNote
  // -------------------------------------------------------------------------
  {
    id: "evernote",
    name: "EverNote",
    features: [
      // ---- ノート作成 ----
      {
        category: "ノート作成",
        feature: "リッチテキスト編集",
        competitorDetail: "フォント・色・レイアウト等のリッチエディタ",
        status: "done",
        appDetail: "Markdown 対応エディタ実装済み",
      },
      {
        category: "ノート作成",
        feature: "Web クリッパー",
        competitorDetail: "ブラウザ拡張でウェブページ全体を保存",
        status: "notYet",
        appDetail: "未実装",
      },
      {
        category: "ノート作成",
        feature: "手書きメモ / スケッチ",
        competitorDetail: "タブレット/スタイラスでの手書き入力",
        status: "notYet",
        appDetail: "未実装",
      },
      {
        category: "ノート作成",
        feature: "音声メモ",
        competitorDetail: "マイクで録音した音声をノートに添付",
        status: "notYet",
        appDetail: "未実装",
      },
      {
        category: "ノート作成",
        feature: "PDF 注釈",
        competitorDetail: "PDF に直接注釈を書き込み",
        status: "notYet",
        appDetail: "未実装",
      },
      // ---- 整理・検索 ----
      {
        category: "整理・検索",
        feature: "ノートブック",
        competitorDetail: "階層型ノートブックでノートを分類",
        status: "done",
        appDetail: "カテゴリページ実装済み",
      },
      {
        category: "整理・検索",
        feature: "タグ",
        competitorDetail: "複数タグでノートをクロスカテゴリ管理",
        status: "done",
        appDetail: "タグ機能実装済み",
      },
      {
        category: "整理・検索",
        feature: "スタック (ノートブックグループ)",
        competitorDetail: "ノートブックをまとめるスタック機能",
        status: "notYet",
        appDetail: "未実装",
      },
      {
        category: "整理・検索",
        feature: "全文検索",
        competitorDetail: "ノート本文・添付ファイル・手書きも検索",
        status: "partial",
        appDetail: "AI 検索・埋め込み検索を部分実装",
      },
      {
        category: "整理・検索",
        feature: "OCR (画像内文字検索)",
        competitorDetail: "スキャンや写真内のテキストを検索可能",
        status: "notYet",
        appDetail: "未実装",
      },
      // ---- タスク・リマインダー ----
      {
        category: "タスク・リマインダー",
        feature: "リマインダー設定",
        competitorDetail: "ノートに日時リマインダーを設定",
        status: "notYet",
        appDetail: "未実装",
      },
      {
        category: "タスク・リマインダー",
        feature: "タスク管理",
        competitorDetail: "チェックリスト・締切・担当者付きタスク",
        status: "partial",
        appDetail: "習慣トラッカー・KPI 管理で部分対応",
      },
      {
        category: "タスク・リマインダー",
        feature: "Google カレンダー連携",
        competitorDetail: "カレンダーイベントをノートに紐付け",
        status: "notYet",
        appDetail: "未実装",
      },
      // ---- 共有 ----
      {
        category: "共有",
        feature: "ノート共有 (閲覧リンク)",
        competitorDetail: "URLで誰でも閲覧可能なノート公開",
        status: "done",
        appDetail: "公開メモ機能実装済み・OGP対応",
      },
      {
        category: "共有",
        feature: "ワークチャット",
        competitorDetail: "Evernote 内でのメッセージ・共有機能",
        status: "notYet",
        appDetail: "未実装",
      },
      {
        category: "共有",
        feature: "プレゼンテーションモード",
        competitorDetail: "ノートをスライド風に全画面表示",
        status: "notYet",
        appDetail: "未実装",
      },
      // ---- プラットフォーム ----
      {
        category: "プラットフォーム",
        feature: "Web アプリ",
        competitorDetail: "ブラウザで全機能利用可能",
        status: "done",
        appDetail: "Flutter Web 実装済み",
      },
      {
        category: "プラットフォーム",
        feature: "iOS/Android アプリ",
        competitorDetail: "ネイティブモバイルアプリ",
        status: "inProgress",
        appDetail: "Flutter クロスプラットフォーム対応可能 — リリース準備中",
      },
      {
        category: "プラットフォーム",
        feature: "デスクトップアプリ",
        competitorDetail: "Mac/Windows ネイティブアプリ",
        status: "inProgress",
        appDetail: "Flutter Desktop 対応可能 — リリース準備中",
      },
      {
        category: "プラットフォーム",
        feature: "オフライン対応",
        competitorDetail: "オフラインでノートの閲覧・編集が可能",
        status: "notYet",
        appDetail: "未実装 — 長期計画で対応予定",
      },
      // ---- 移行・連携 ----
      {
        category: "移行・連携",
        feature: "ENEX エクスポート/インポート",
        competitorDetail: "Evernote 標準フォーマットで移行対応",
        status: "done",
        appDetail: "ENEX インポート実装済み・Edge Function first",
      },
      {
        category: "移行・連携",
        feature: "Slack / Google Drive 連携",
        competitorDetail: "外部ツールとのファイル共有連携",
        status: "partial",
        appDetail: "Supabase Edge Function 経由で API 公開中",
      },
      // ---- 自分株式会社 独自機能 ----
      {
        category: "自分株式会社 独自機能",
        feature: "AI エージェント組織",
        competitorDetail: "— EverNote にはない機能",
        status: "unique",
        appDetail: "CEO/CFO/CMO/CHRO 役員会議 AI 実装済み",
      },
      {
        category: "自分株式会社 独自機能",
        feature: "マインドマップ",
        competitorDetail: "— EverNote にはない機能",
        status: "unique",
        appDetail: "ビジュアルマインドマップ実装済み",
      },
      {
        category: "自分株式会社 独自機能",
        feature: "記憶ドリル (スペーシング反復)",
        competitorDetail: "— EverNote にはない機能",
        status: "unique",
        appDetail: "スペーシング反復学習ドリル実装済み",
      },
      {
        category: "自分株式会社 独自機能",
        feature: "経営コックピット",
        competitorDetail: "— EverNote にはない機能",
        status: "unique",
        appDetail: "KPI・資産・習慣を一画面で管理",
      },
      {
        category: "自分株式会社 独自機能",
        feature: "家計・資産管理",
        competitorDetail: "— EverNote にはない機能",
        status: "unique",
        appDetail: "収支カレンダー・資産管理・月次収支分析実装済み",
      },
    ],
  },

  // -------------------------------------------------------------------------
  // MoneyForward
  // -------------------------------------------------------------------------
  {
    id: "moneyforward",
    name: "MoneyForward",
    features: [
      // ---- 家計管理 ----
      {
        category: "家計管理",
        feature: "口座・カード自動連携",
        competitorDetail: "銀行・クレカ・電子マネーを自動取得",
        status: "notYet",
        appDetail: "未実装 — 金融 API 連携は長期計画",
      },
      {
        category: "家計管理",
        feature: "収支グラフ分析",
        competitorDetail: "月次・カテゴリ別の収支を可視化",
        status: "done",
        appDetail: "月間カレンダー収支・KPI ダッシュボード実装済み",
      },
      {
        category: "家計管理",
        feature: "自動カテゴリ分類",
        competitorDetail: "取引を AI で自動カテゴリ分け",
        status: "notYet",
        appDetail: "未実装",
      },
      {
        category: "家計管理",
        feature: "レシートスキャン",
        competitorDetail: "カメラでレシートを撮影して自動入力",
        status: "notYet",
        appDetail: "未実装",
      },
      {
        category: "家計管理",
        feature: "手動収支入力",
        competitorDetail: "手動での収支記録",
        status: "done",
        appDetail: "収支入力・振替機能実装済み",
      },
      // ---- 資産管理 ----
      {
        category: "資産管理",
        feature: "総資産表示",
        competitorDetail: "全口座の資産合計をリアルタイム表示",
        status: "done",
        appDetail: "資産管理画面実装済み",
      },
      {
        category: "資産管理",
        feature: "資産推移グラフ",
        competitorDetail: "資産の時系列変化を折れ線グラフで表示",
        status: "partial",
        appDetail: "KPI チャートで部分対応",
      },
      {
        category: "資産管理",
        feature: "銀行残高リアルタイム連携",
        competitorDetail: "主要銀行の残高を自動取得",
        status: "notYet",
        appDetail: "未実装 — 金融 API 連携は長期計画",
      },
      {
        category: "資産管理",
        feature: "証券・株式管理",
        competitorDetail: "株・投信・ETF の保有状況を自動取得",
        status: "notYet",
        appDetail: "未実装",
      },
      {
        category: "資産管理",
        feature: "年金・iDeCo 管理",
        competitorDetail: "年金ねっと連携で将来受取額を確認",
        status: "notYet",
        appDetail: "未実装",
      },
      // ---- 予算管理 ----
      {
        category: "予算管理",
        feature: "月次予算設定",
        competitorDetail: "カテゴリ別に月の支出上限を設定",
        status: "partial",
        appDetail: "KPI 目標設定で部分対応",
      },
      {
        category: "予算管理",
        feature: "予実比較",
        competitorDetail: "予算に対して実際の支出を比較表示",
        status: "done",
        appDetail: "月間収支カレンダーで収入・支出・差額を表示",
      },
      // ---- 投資 ----
      {
        category: "投資",
        feature: "投資運用状況",
        competitorDetail: "保有投資信託・株式の損益を表示",
        status: "notYet",
        appDetail: "未実装",
      },
      {
        category: "投資",
        feature: "ポートフォリオ分析",
        competitorDetail: "アセットクラス別配分をグラフ表示",
        status: "notYet",
        appDetail: "未実装",
      },
      // ---- 税務 ----
      {
        category: "税務",
        feature: "確定申告サポート",
        competitorDetail: "家計簿データを確定申告に活用",
        status: "notYet",
        appDetail: "未実装",
      },
      {
        category: "税務",
        feature: "ふるさと納税管理",
        competitorDetail: "寄付記録・控除額計算をサポート",
        status: "notYet",
        appDetail: "未実装",
      },
      // ---- プラットフォーム ----
      {
        category: "プラットフォーム",
        feature: "Web アプリ",
        competitorDetail: "ブラウザで全機能利用可能",
        status: "done",
        appDetail: "Flutter Web 実装済み",
      },
      {
        category: "プラットフォーム",
        feature: "iOS/Android アプリ",
        competitorDetail: "ネイティブモバイルアプリ",
        status: "inProgress",
        appDetail: "Flutter クロスプラットフォーム対応可能 — リリース準備中",
      },
      // ---- 自分株式会社 独自機能 ----
      {
        category: "自分株式会社 独自機能",
        feature: "AI エージェント組織 (CFO 含む)",
        competitorDetail: "— MoneyForward にはない機能",
        status: "unique",
        appDetail: "CFO AI による財務分析・アドバイス実装済み",
      },
      {
        category: "自分株式会社 独自機能",
        feature: "ノートメモ機能",
        competitorDetail: "— MoneyForward にはない機能",
        status: "unique",
        appDetail: "Markdown メモ・AI 整理・公開メモ実装済み",
      },
      {
        category: "自分株式会社 独自機能",
        feature: "マインドマップ",
        competitorDetail: "— MoneyForward にはない機能",
        status: "unique",
        appDetail: "ビジュアルマインドマップ実装済み",
      },
      {
        category: "自分株式会社 独自機能",
        feature: "記憶ドリル",
        competitorDetail: "— MoneyForward にはない機能",
        status: "unique",
        appDetail: "スペーシング反復学習ドリル実装済み",
      },
      {
        category: "自分株式会社 独自機能",
        feature: "Growth ロードマップ進捗表示",
        competitorDetail: "— MoneyForward にはない機能",
        status: "unique",
        appDetail: "このカードがその機能です",
      },
    ],
  },

  // -------------------------------------------------------------------------
  // X (Twitter)
  // -------------------------------------------------------------------------
  {
    id: "x",
    name: "X",
    features: [
      // ---- 投稿・コンテンツ ----
      {
        category: "投稿・コンテンツ",
        feature: "テキスト投稿",
        competitorDetail: "最大4000文字 (Premium) / 280文字 (無料)",
        status: "done",
        appDetail: "Markdown ノート作成実装済み (文字数制限なし)",
      },
      {
        category: "投稿・コンテンツ",
        feature: "画像・動画添付",
        competitorDetail: "最大4枚の画像、または動画を投稿に添付",
        status: "notYet",
        appDetail: "未実装",
      },
      {
        category: "投稿・コンテンツ",
        feature: "スレッド投稿",
        competitorDetail: "連続ポストをスレッドとして繋げる",
        status: "notYet",
        appDetail: "未実装 — ノートのリンク機能で代替可能",
      },
      {
        category: "投稿・コンテンツ",
        feature: "ポーリング (投票)",
        competitorDetail: "最大4択の投票をポストに埋め込み",
        status: "notYet",
        appDetail: "未実装",
      },
      {
        category: "投稿・コンテンツ",
        feature: "引用ポスト",
        competitorDetail: "他ユーザーのポストにコメントを添えて共有",
        status: "notYet",
        appDetail: "未実装",
      },
      // ---- タイムライン・発見 ----
      {
        category: "タイムライン・発見",
        feature: "アルゴリズムタイムライン",
        competitorDetail: "エンゲージメント予測に基づくコンテンツ推薦",
        status: "notYet",
        appDetail: "未実装 — 長期計画でレコメンドエンジン対応予定",
      },
      {
        category: "タイムライン・発見",
        feature: "トレンド",
        competitorDetail: "地域・世界のリアルタイムトレンドを表示",
        status: "notYet",
        appDetail: "未実装",
      },
      {
        category: "タイムライン・発見",
        feature: "ハッシュタグ",
        competitorDetail: "ハッシュタグでコンテンツを横断検索",
        status: "partial",
        appDetail: "タグ機能実装済み (クロスカテゴリ検索で代替)",
      },
      {
        category: "タイムライン・発見",
        feature: "全文・ユーザー検索",
        competitorDetail: "キーワード・ユーザー・日付・メディアで絞り込み検索",
        status: "partial",
        appDetail: "AI 埋め込み検索を部分実装",
      },
      // ---- エンゲージメント ----
      {
        category: "エンゲージメント",
        feature: "いいね",
        competitorDetail: "ポストへのリアクション (いいね)",
        status: "notYet",
        appDetail: "未実装",
      },
      {
        category: "エンゲージメント",
        feature: "リポスト",
        competitorDetail: "他ユーザーのポストをそのまま拡散",
        status: "notYet",
        appDetail: "未実装",
      },
      {
        category: "エンゲージメント",
        feature: "リプライ",
        competitorDetail: "ポストへの返信",
        status: "notYet",
        appDetail: "未実装",
      },
      {
        category: "エンゲージメント",
        feature: "ブックマーク",
        competitorDetail: "ポストを非公開でコレクションに保存",
        status: "done",
        appDetail: "ノートへの保存・お気に入り機能実装済み",
      },
      // ---- コミュニケーション ----
      {
        category: "コミュニケーション",
        feature: "ダイレクトメッセージ (DM)",
        competitorDetail: "1対1またはグループでのプライベートメッセージ",
        status: "notYet",
        appDetail: "未実装",
      },
      {
        category: "コミュニケーション",
        feature: "X スペース (音声ライブ)",
        competitorDetail: "リアルタイム音声配信・参加",
        status: "notYet",
        appDetail: "未実装",
      },
      // ---- コミュニティ ----
      {
        category: "コミュニティ",
        feature: "コミュニティ機能",
        competitorDetail: "テーマ別のクローズドグループを作成・参加",
        status: "notYet",
        appDetail: "未実装 — チームワークスペースで中期対応予定",
      },
      {
        category: "コミュニティ",
        feature: "フォロー/フォロワー",
        competitorDetail: "ユーザー間の非対称フォロー関係",
        status: "notYet",
        appDetail: "未実装",
      },
      // ---- 収益化 ----
      {
        category: "収益化",
        feature: "X Premium (有料プラン)",
        competitorDetail: "長文投稿・認証バッジ・広告収益分配",
        status: "inProgress",
        appDetail: "Pro/Team/Enterprise プラン設計中",
      },
      {
        category: "収益化",
        feature: "Super Follows (有料フォロー)",
        competitorDetail: "有料フォロワーへの限定コンテンツ配信",
        status: "notYet",
        appDetail: "未実装 — 中長期計画でコンテンツ収益化対応予定",
      },
      {
        category: "収益化",
        feature: "広告収益分配",
        competitorDetail: "Premium ユーザーの広告インプレッション収益分配",
        status: "notYet",
        appDetail: "未実装",
      },
      // ---- プラットフォーム ----
      {
        category: "プラットフォーム",
        feature: "Web アプリ",
        competitorDetail: "ブラウザで全機能利用可能",
        status: "done",
        appDetail: "Flutter Web 実装済み",
      },
      {
        category: "プラットフォーム",
        feature: "iOS/Android アプリ",
        competitorDetail: "ネイティブモバイルアプリ",
        status: "inProgress",
        appDetail: "Flutter クロスプラットフォーム対応可能 — リリース準備中",
      },
      // ---- 自分株式会社 独自機能 ----
      {
        category: "自分株式会社 独自機能",
        feature: "AI エージェント組織",
        competitorDetail: "— X にはない機能",
        status: "unique",
        appDetail: "CEO/CFO/CMO/CHRO 役員会議 AI 実装済み",
      },
      {
        category: "自分株式会社 独自機能",
        feature: "長文プライベートノート管理",
        competitorDetail: "— X は短文パブリック投稿が主軸",
        status: "unique",
        appDetail: "Markdown ノート・カテゴリ・AI 整理実装済み",
      },
      {
        category: "自分株式会社 独自機能",
        feature: "家計・資産管理",
        competitorDetail: "— X にはない機能",
        status: "unique",
        appDetail: "収支カレンダー・資産管理・月次収支分析実装済み",
      },
      {
        category: "自分株式会社 独自機能",
        feature: "マインドマップ",
        competitorDetail: "— X にはない機能",
        status: "unique",
        appDetail: "ビジュアルマインドマップ実装済み",
      },
      {
        category: "自分株式会社 独自機能",
        feature: "記憶ドリル (スペーシング反復)",
        competitorDetail: "— X にはない機能",
        status: "unique",
        appDetail: "スペーシング反復学習ドリル実装済み",
      },
      {
        category: "自分株式会社 独自機能",
        feature: "Growth ロードマップ進捗表示",
        competitorDetail: "— X にはない機能",
        status: "unique",
        appDetail: "このカードがその機能です",
      },
    ],
  },

  // -------------------------------------------------------------------------
  // Animaworks
  // -------------------------------------------------------------------------
  {
    id: "animaworks",
    name: "Animaworks",
    features: [
      // ---- 目標・習慣管理 ----
      {
        category: "目標・習慣管理",
        feature: "目標設定・管理",
        competitorDetail: "短期・長期の目標をツリー構造で設定・追跡",
        status: "partial",
        appDetail: "KPI 目標設定・Growth ロードマップで部分対応",
      },
      {
        category: "目標・習慣管理",
        feature: "習慣トラッカー",
        competitorDetail: "毎日の習慣を記録・継続率を可視化",
        status: "done",
        appDetail: "習慣トラッカー実装済み (チェックイン・連続記録・グラフ)",
      },
      {
        category: "目標・習慣管理",
        feature: "OKR / KPI 管理",
        competitorDetail: "目標と主要結果 (OKR) を階層管理",
        status: "done",
        appDetail: "KPI ダッシュボード実装済み",
      },
      {
        category: "目標・習慣管理",
        feature: "マイルストーン設定",
        competitorDetail: "目標達成に向けた中間マイルストーンを管理",
        status: "partial",
        appDetail: "Growth ロードマップの短期/中期/長期計画で対応",
      },
      // ---- 振り返り・ジャーナル ----
      {
        category: "振り返り・ジャーナル",
        feature: "日次振り返り",
        competitorDetail: "今日の出来事・感情・成果を記録",
        status: "done",
        appDetail: "Markdown ノートで日記・振り返り記録可能",
      },
      {
        category: "振り返り・ジャーナル",
        feature: "週次/月次レビュー",
        competitorDetail: "週・月単位で振り返りテンプレートを提供",
        status: "partial",
        appDetail: "Growth 週次 digest・月間収支カレンダーで部分対応",
      },
      {
        category: "振り返り・ジャーナル",
        feature: "ムード・感情トラッキング",
        competitorDetail: "気分・感情を毎日記録してグラフ化",
        status: "notYet",
        appDetail: "未実装",
      },
      {
        category: "振り返り・ジャーナル",
        feature: "感謝ジャーナル",
        competitorDetail: "毎日の感謝を3つ記録するマインドフルネス機能",
        status: "notYet",
        appDetail: "未実装",
      },
      // ---- タスク・プロジェクト ----
      {
        category: "タスク・プロジェクト",
        feature: "タスク管理",
        competitorDetail: "To-Do リスト・優先度・締切管理",
        status: "partial",
        appDetail: "ノート内チェックリスト・習慣トラッカーで部分対応",
      },
      {
        category: "タスク・プロジェクト",
        feature: "プロジェクト管理",
        competitorDetail: "プロジェクトごとにタスクをグループ管理",
        status: "notYet",
        appDetail: "未実装 — 中期計画で対応予定",
      },
      {
        category: "タスク・プロジェクト",
        feature: "タイムボックス",
        competitorDetail: "作業時間をブロック単位でカレンダーに割り当て",
        status: "notYet",
        appDetail: "未実装",
      },
      // ---- ライフデザイン ----
      {
        category: "ライフデザイン",
        feature: "ライフホイール評価",
        competitorDetail: "人生の各領域 (仕事/健康/人間関係等) をバランス評価",
        status: "notYet",
        appDetail: "未実装",
      },
      {
        category: "ライフデザイン",
        feature: "ビジョンボード",
        competitorDetail: "目標イメージを視覚的にコラージュして動機付け",
        status: "notYet",
        appDetail: "未実装",
      },
      {
        category: "ライフデザイン",
        feature: "ライフイベント記録",
        competitorDetail: "人生の重要な出来事を時系列で記録",
        status: "partial",
        appDetail: "月間カレンダーで日別記録可能",
      },
      // ---- 通知・リマインダー ----
      {
        category: "通知・リマインダー",
        feature: "習慣リマインダー通知",
        competitorDetail: "習慣実行を促すプッシュ通知",
        status: "done",
        appDetail: "通知サービス実装済み (土曜リマインダー等)",
      },
      {
        category: "通知・リマインダー",
        feature: "目標チェックインリマインダー",
        competitorDetail: "定期的な目標進捗チェックを通知",
        status: "partial",
        appDetail: "通知基盤実装済み — 目標チェックイン通知は拡張可能",
      },
      // ---- プラットフォーム ----
      {
        category: "プラットフォーム",
        feature: "Web アプリ",
        competitorDetail: "ブラウザで利用可能",
        status: "done",
        appDetail: "Flutter Web 実装済み",
      },
      {
        category: "プラットフォーム",
        feature: "iOS/Android アプリ",
        competitorDetail: "ネイティブモバイルアプリ",
        status: "inProgress",
        appDetail: "Flutter クロスプラットフォーム対応可能 — リリース準備中",
      },
      // ---- 自分株式会社 独自機能 ----
      {
        category: "自分株式会社 独自機能",
        feature: "AI エージェント組織 (CEO/CFO/CMO/CHRO)",
        competitorDetail: "— Animaworks にはない機能",
        status: "unique",
        appDetail: "役員会議 AI で戦略的意思決定を支援",
      },
      {
        category: "自分株式会社 独自機能",
        feature: "Markdown ノート + AI 整理",
        competitorDetail: "— Animaworks にはない機能",
        status: "unique",
        appDetail: "AI Secretary によるノート改善・要約・次アクション生成",
      },
      {
        category: "自分株式会社 独自機能",
        feature: "家計・資産管理",
        competitorDetail: "— Animaworks にはない機能",
        status: "unique",
        appDetail: "収支カレンダー・資産管理・月次収支分析実装済み",
      },
      {
        category: "自分株式会社 独自機能",
        feature: "マインドマップ",
        competitorDetail: "— Animaworks にはない機能",
        status: "unique",
        appDetail: "ビジュアルマインドマップ実装済み",
      },
      {
        category: "自分株式会社 独自機能",
        feature: "記憶ドリル (スペーシング反復)",
        competitorDetail: "— Animaworks にはない機能",
        status: "unique",
        appDetail: "スペーシング反復学習ドリル実装済み",
      },
      {
        category: "自分株式会社 独自機能",
        feature: "競合比較 Growth ロードマップ",
        competitorDetail: "— Animaworks にはない機能",
        status: "unique",
        appDetail: "このカードがその機能です",
      },
    ],
  },

  // -------------------------------------------------------------------------
  // Claude Code
  // -------------------------------------------------------------------------
  {
    id: "claude-code",
    name: "Claude Code",
    features: [
      // ---- AI コーディング支援 ----
      {
        category: "AI コーディング支援",
        feature: "AI コード生成・補完",
        competitorDetail: "自然言語の指示でコードを自動生成・補完",
        status: "notYet",
        appDetail: "未実装 — コーディング機能は対象外 (別の価値軸で差別化)",
      },
      {
        category: "AI コーディング支援",
        feature: "バグ検出・自動修正",
        competitorDetail: "エラーを解析して修正案を提案・適用",
        status: "notYet",
        appDetail: "未実装",
      },
      {
        category: "AI コーディング支援",
        feature: "コードレビュー",
        competitorDetail: "プルリクエスト・コード全体のレビューコメント生成",
        status: "notYet",
        appDetail: "未実装",
      },
      {
        category: "AI コーディング支援",
        feature: "テスト自動生成",
        competitorDetail: "ユニットテスト・E2E テストコードを自動生成",
        status: "notYet",
        appDetail: "未実装",
      },
      {
        category: "AI コーディング支援",
        feature: "ドキュメント生成",
        competitorDetail: "コードからコメント・README を自動生成",
        status: "done",
        appDetail: "AI Secretary でノート・レポート生成実装済み (汎用文書生成)",
      },
      // ---- ファイル・環境操作 ----
      {
        category: "ファイル・環境操作",
        feature: "ファイル読み書き・編集",
        competitorDetail: "プロジェクト内の任意ファイルを読み取り・編集",
        status: "done",
        appDetail: "Markdown ノート作成・編集実装済み",
      },
      {
        category: "ファイル・環境操作",
        feature: "ターミナルコマンド実行",
        competitorDetail: "シェルコマンドを直接実行して結果をフィードバック",
        status: "notYet",
        appDetail: "未実装 — Web/モバイル環境では対象外",
      },
      {
        category: "ファイル・環境操作",
        feature: "Git 操作支援",
        competitorDetail: "コミット・PR・ブランチ操作を AI が補助",
        status: "notYet",
        appDetail: "未実装",
      },
      {
        category: "ファイル・環境操作",
        feature: "マルチファイル横断編集",
        competitorDetail: "複数ファイルにまたがる変更を一括実行",
        status: "partial",
        appDetail: "ノートのリンク・カテゴリ横断検索で部分対応",
      },
      // ---- 拡張・統合 ----
      {
        category: "拡張・統合",
        feature: "MCP (Model Context Protocol) 拡張",
        competitorDetail: "カスタムツールを MCP サーバーとして接続",
        status: "notYet",
        appDetail: "未実装",
      },
      {
        category: "拡張・統合",
        feature: "IDE / エディタ統合",
        competitorDetail: "VS Code 等のエディタにシームレスに統合",
        status: "notYet",
        appDetail: "未実装 — Web アプリとして独立",
      },
      {
        category: "拡張・統合",
        feature: "ブラウザ操作 (Computer Use)",
        competitorDetail: "ブラウザを自律制御して Web タスクを実行",
        status: "notYet",
        appDetail: "未実装",
      },
      {
        category: "拡張・統合",
        feature: "カスタムシステムプロンプト (CLAUDE.md)",
        competitorDetail: "プロジェクト固有の指示書でふるまいをカスタマイズ",
        status: "partial",
        appDetail: "AI エージェントへの役割設定機能で部分対応",
      },
      // ---- AI モデル ----
      {
        category: "AI モデル",
        feature: "マルチモデル対応",
        competitorDetail: "Claude Opus / Sonnet / Haiku を用途別に切り替え",
        status: "done",
        appDetail: "AI ステータス画面で Claude / Gemini / GPT 等を切り替え可能",
      },
      {
        category: "AI モデル",
        feature: "コンテキスト長 (長い会話)",
        competitorDetail: "200K トークン超の長いコンテキストを保持",
        status: "partial",
        appDetail: "ノート・チャット履歴でコンテキスト管理、長文対応拡張予定",
      },
      // ---- プラットフォーム ----
      {
        category: "プラットフォーム",
        feature: "CLI (コマンドラインインターフェース)",
        competitorDetail: "ターミナルから直接起動して使用",
        status: "notYet",
        appDetail: "未実装 — Web/モバイルが主軸",
      },
      {
        category: "プラットフォーム",
        feature: "Web アプリ / GUI",
        competitorDetail: "ブラウザ / GUI での操作",
        status: "done",
        appDetail: "Flutter Web 実装済み",
      },
      // ---- 自分株式会社 独自機能 ----
      {
        category: "自分株式会社 独自機能",
        feature: "個人生産性統合 (ノート + 習慣 + 家計)",
        competitorDetail: "— Claude Code にはない機能 (コーディング専用ツール)",
        status: "unique",
        appDetail: "ノート / 習慣トラッカー / 収支管理 / 資産管理を一元化",
      },
      {
        category: "自分株式会社 独自機能",
        feature: "AI エージェント組織 (CEO/CFO/CMO/CHRO)",
        competitorDetail: "— Claude Code にはない機能",
        status: "unique",
        appDetail: "役員会議 AI で戦略的意思決定を支援",
      },
      {
        category: "自分株式会社 独自機能",
        feature: "マインドマップ",
        competitorDetail: "— Claude Code にはない機能",
        status: "unique",
        appDetail: "ビジュアルマインドマップ実装済み",
      },
      {
        category: "自分株式会社 独自機能",
        feature: "記憶ドリル (スペーシング反復)",
        competitorDetail: "— Claude Code にはない機能",
        status: "unique",
        appDetail: "スペーシング反復学習ドリル実装済み",
      },
      {
        category: "自分株式会社 独自機能",
        feature: "Growth ロードマップ + 競合比較",
        competitorDetail: "— Claude Code にはない機能",
        status: "unique",
        appDetail: "このカードがその機能です",
      },
    ],
  },

  // -------------------------------------------------------------------------
  // Codex
  // -------------------------------------------------------------------------
  {
    id: "codex",
    name: "Codex",
    features: [
      // ---- AI コーディング支援 ----
      {
        category: "AI コーディング支援",
        feature: "クラウド上でのコード自動生成",
        competitorDetail:
          "GitHub Issues / PR をもとに自律的にコードを生成・PR 作成",
        status: "notYet",
        appDetail:
          "未実装 — コーディング特化は対象外。AI Secretary で文書生成は実装済み",
      },
      {
        category: "AI コーディング支援",
        feature: "マルチファイル編集",
        competitorDetail: "リポジトリ全体を把握して複数ファイルを一括変更",
        status: "notYet",
        appDetail: "未実装",
      },
      {
        category: "AI コーディング支援",
        feature: "CI/CD パイプライン統合",
        competitorDetail: "GitHub Actions と連携してテスト・デプロイを自動化",
        status: "notYet",
        appDetail: "未実装 — Web アプリ向け別軸で差別化",
      },
      {
        category: "AI コーディング支援",
        feature: "テスト自動生成・実行",
        competitorDetail: "ユニット/統合テストを自動生成し sandbox 内で実行",
        status: "notYet",
        appDetail: "未実装",
      },
      // ---- コラボレーション ----
      {
        category: "コラボレーション",
        feature: "Pull Request レビュー支援",
        competitorDetail: "PR の差分を解析してレビューコメントを自動生成",
        status: "notYet",
        appDetail: "未実装",
      },
      {
        category: "コラボレーション",
        feature: "Issue トリアージ",
        competitorDetail: "GitHub Issues を分析して優先度・担当者提案",
        status: "notYet",
        appDetail: "未実装",
      },
      // ---- ナレッジ管理 ----
      {
        category: "ナレッジ管理",
        feature: "コードベース検索・Q&A",
        competitorDetail: "コードの意味を理解した自然言語検索",
        status: "partial",
        appDetail: "MAGI System + AI Secretary でドキュメント Q&A 実装済み",
      },
      {
        category: "ナレッジ管理",
        feature: "ドキュメント自動生成",
        competitorDetail: "コードから README・API ドキュメントを自動生成",
        status: "done",
        appDetail: "AI Secretary でノート・レポート生成実装済み",
      },
      // ---- 自分株式会社 独自機能 ----
      {
        category: "自分株式会社 独自機能",
        feature: "収支・資産管理",
        competitorDetail: "— Codex にはない機能",
        status: "unique",
        appDetail: "収支・資産トラッキング実装済み",
      },
      {
        category: "自分株式会社 独自機能",
        feature: "記憶ドリル (スペーシング反復)",
        competitorDetail: "— Codex にはない機能",
        status: "unique",
        appDetail: "スペーシング反復学習ドリル実装済み",
      },
      {
        category: "自分株式会社 独自機能",
        feature: "マインドマップ",
        competitorDetail: "— Codex にはない機能",
        status: "unique",
        appDetail: "マインドマップ生成・閲覧実装済み",
      },
    ],
  },

  // -------------------------------------------------------------------------
  // netkeiba
  // -------------------------------------------------------------------------
  {
    id: "netkeiba",
    name: "netkeiba",
    features: [
      // ---- 競馬情報 ----
      {
        category: "競馬情報",
        feature: "レース結果・成績データベース",
        competitorDetail: "過去レース結果・着順・タイムの全データ閲覧",
        status: "notYet",
        appDetail:
          "未実装 — 競馬特化機能は対象外。独自ノートで自由記録は可能",
      },
      {
        category: "競馬情報",
        feature: "馬・騎手・調教師プロフィール",
        competitorDetail: "出走馬・関係者の詳細プロフィール・成績",
        status: "notYet",
        appDetail: "未実装",
      },
      {
        category: "競馬情報",
        feature: "オッズ・予想印リアルタイム表示",
        competitorDetail: "リアルタイムオッズ・公式予想印を表示",
        status: "notYet",
        appDetail: "未実装",
      },
      {
        category: "競馬情報",
        feature: "出馬表・馬柱",
        competitorDetail: "出走馬の過去成績を馬柱形式で表示",
        status: "notYet",
        appDetail: "未実装",
      },
      // ---- コミュニティ ----
      {
        category: "コミュニティ",
        feature: "予想投稿・コメント",
        competitorDetail: "ユーザーが予想を投稿してコメントし合える",
        status: "partial",
        appDetail: "公開メモ機能で意見・予想の投稿・共有が可能",
      },
      {
        category: "コミュニティ",
        feature: "重賞予想コンテスト",
        competitorDetail: "ユーザー間の予想コンテスト機能",
        status: "notYet",
        appDetail: "未実装",
      },
      {
        category: "コミュニティ",
        feature: "フォロー・フォロワー",
        competitorDetail: "ユーザーをフォローして予想をタイムライン表示",
        status: "notYet",
        appDetail: "未実装 — Referral 経由の繋がりは実装済み",
      },
      // ---- 収支管理 ----
      {
        category: "収支管理",
        feature: "馬券収支トラッキング",
        competitorDetail: "馬券の購入・払戻を記録して収支をグラフ表示",
        status: "done",
        appDetail: "収支管理機能で任意カテゴリの収支トラッキング実装済み",
      },
      {
        category: "収支管理",
        feature: "的中率・回収率の自動計算",
        competitorDetail: "勝率・ROI を自動計算して表示",
        status: "partial",
        appDetail:
          "ノートと収支を組み合わせて手動管理可能。自動集計は一部実装",
      },
      // ---- 自分株式会社 独自機能 ----
      {
        category: "自分株式会社 独自機能",
        feature: "AI Secretary (汎用 AI アシスタント)",
        competitorDetail: "— netkeiba にはない機能",
        status: "unique",
        appDetail: "あらゆるジャンルの AI 分析・要約・アドバイス実装済み",
      },
      {
        category: "自分株式会社 独自機能",
        feature: "MAGI System (多角的 AI 議論)",
        competitorDetail: "— netkeiba にはない機能",
        status: "unique",
        appDetail: "3 視点 AI 議論機能実装済み",
      },
      {
        category: "自分株式会社 独自機能",
        feature: "記憶ドリル (スペーシング反復)",
        competitorDetail: "— netkeiba にはない機能",
        status: "unique",
        appDetail: "スペーシング反復学習ドリル実装済み",
      },
      {
        category: "自分株式会社 独自機能",
        feature: "Growth ロードマップ + 競合比較",
        competitorDetail: "— netkeiba にはない機能",
        status: "unique",
        appDetail: "このカードがその機能です",
      },
    ],
  },

  // -------------------------------------------------------------------------
  // OpenClaw
  // -------------------------------------------------------------------------
  {
    id: "openclaw",
    name: "OpenClaw",
    features: [
      // ---- AI エージェント ----
      {
        category: "AI エージェント",
        feature: "自律的タスク実行",
        competitorDetail: "ユーザーの指示から自律的に計画・実行",
        status: "notYet",
        appDetail: "未実装 — MAGI Systemで部分的に対応予定",
      },
      {
        category: "AI エージェント",
        feature: "Webブラウジング・スクレイピング",
        competitorDetail: "Web上の情報を自律的に検索・取得",
        status: "notYet",
        appDetail: "未実装",
      },
      {
        category: "AI エージェント",
        feature: "ツール使用 (Tool Use)",
        competitorDetail: "外部APIやカスタムツールの呼び出し",
        status: "partial",
        appDetail: "Supabase Edge Function経由でのAPI連携を部分実装",
      },
      {
        category: "AI エージェント",
        feature: "ローカル環境・ファイル操作",
        competitorDetail: "ファイルシステムやコマンドの実行",
        status: "done",
        appDetail: "ノート・メディア・データのローカル/クラウド保存実装済み",
      },
      // ---- 自分株式会社 独自機能 ----
      {
        category: "自分株式会社 独自機能",
        feature: "個人生産性統合 (ノート + 習慣 + 家計)",
        competitorDetail: "— OpenClaw にはない機能",
        status: "unique",
        appDetail: "ノート / 習慣トラッカー / 収支管理 / 資産管理を一元化",
      },
      {
        category: "自分株式会社 独自機能",
        feature: "AI エージェント組織 (CEO/CFO/CMO/CHRO)",
        competitorDetail: "— OpenClaw にはない機能",
        status: "unique",
        appDetail: "役員会議 AI で戦略的意思決定を支援",
      },
      {
        category: "自分株式会社 独自機能",
        feature: "Growth ロードマップ + 競合比較",
        competitorDetail: "— OpenClaw にはない機能",
        status: "unique",
        appDetail: "このカードがその機能です",
      },
    ],
  },

  // -------------------------------------------------------------------------
  // Claude Cowork
  // -------------------------------------------------------------------------
  {
    id: "claude-works",
    name: "Claude Cowork",
    features: [
      // ---- 法人・チーム AI ----
      {
        category: "法人・チーム AI",
        feature: "社内ナレッジ連携 (RAG)",
        competitorDetail: "社内ドキュメント・WikiとAIを統合",
        status: "notYet",
        appDetail:
          "未実装 — 中期計画で Team workspace と合わせて対応予定",
      },
      {
        category: "法人・チーム AI",
        feature: "Artifacts 共同編集",
        competitorDetail: "AIが生成したコードや文書をチームで閲覧・編集",
        status: "notYet",
        appDetail: "未実装",
      },
      {
        category: "法人・チーム AI",
        feature: "エンタープライズセキュリティ",
        competitorDetail: "SOC2 / SSO / データプライバシー管理",
        status: "notYet",
        appDetail: "未実装 — 長期計画で法人向け管理機能を整備",
      },
      // ---- 自分株式会社 独自機能 ----
      {
        category: "自分株式会社 独自機能",
        feature: "個人資産・収支との統合",
        competitorDetail: "— Claude Cowork にはない機能",
        status: "unique",
        appDetail: "個人の収支・資産トラッキングを AI 支援と一元化",
      },
      {
        category: "自分株式会社 独自機能",
        feature: "AI 役員会議 (MAGI System)",
        competitorDetail: "— Claude Cowork にはない機能",
        status: "unique",
        appDetail:
          "複数ペルソナ (CEO/CFO/CMO/CHRO) の AI が同時に議論・提案",
      },
      {
        category: "自分株式会社 独自機能",
        feature: "スペーシング記憶ドリル",
        competitorDetail: "— Claude Cowork にはない機能",
        status: "unique",
        appDetail: "学習定着化システムを実装済み",
      },
    ],
  },

  // -------------------------------------------------------------------------
  // Chatwork
  // -------------------------------------------------------------------------
  {
    id: "chatwork",
    name: "Chatwork",
    features: [
      // ---- コミュニケーション ----
      {
        category: "コミュニケーション",
        feature: "グループチャット・DM",
        competitorDetail: "チーム内でのテキストコミュニケーション",
        status: "notYet",
        appDetail: "未実装 — 中期計画 (Team workspace) で対応予定",
      },
      // ---- タスク管理 ----
      {
        category: "タスク管理",
        feature: "タスクのアサインと通知",
        competitorDetail: "メッセージからタスクを作成し担当者へ通知",
        status: "partial",
        appDetail: "個人向けタスク管理・リマインダーは実装済み",
      },
      // ---- ファイル管理 ----
      {
        category: "ファイル管理",
        feature: "ファイル添付と共有",
        competitorDetail: "チャットへのファイル添付・一覧表示",
        status: "partial",
        appDetail: "ノートへのファイル・画像添付は部分実装済み",
      },
      // ---- 自分株式会社 独自機能 ----
      {
        category: "自分株式会社 独自機能",
        feature: "AI 役員会議 (MAGI System)",
        competitorDetail: "— Chatwork にはない機能",
        status: "unique",
        appDetail:
          "単なるチャットではなく、AI ペルソナと多角的な議論が可能",
      },
      {
        category: "自分株式会社 独自機能",
        feature: "個人の収支・資産・習慣の一元化",
        competitorDetail: "— Chatwork にはない機能",
        status: "unique",
        appDetail: "パーソナルな生産性管理とビジネスを統合",
      },
    ],
  },

  // -------------------------------------------------------------------------
  // Slack
  // -------------------------------------------------------------------------
  {
    id: "slack",
    name: "Slack",
    features: [
      // ---- コミュニケーション ----
      {
        category: "コミュニケーション",
        feature: "チャンネルとスレッド",
        competitorDetail: "トピック別の部屋とメッセージごとの返信",
        status: "notYet",
        appDetail: "未実装 — チーム機能拡張時に対応予定",
      },
      {
        category: "コミュニケーション",
        feature: "ハドルミーティング",
        competitorDetail: "チャンネル内での手軽な音声・画面共有",
        status: "notYet",
        appDetail: "未実装",
      },
      // ---- 連携・拡張 ----
      {
        category: "連携・拡張",
        feature: "外部アプリ連携",
        competitorDetail: "Google Drive, GitHubなど多数の連携",
        status: "partial",
        appDetail: "Supabase Edge Function経由でのAPI連携を部分実装",
      },
      {
        category: "連携・拡張",
        feature: "ワークフロービルダー",
        competitorDetail: "ノーコードでのルーチン業務自動化",
        status: "notYet",
        appDetail: "未実装 — AI エージェントへのタスク依頼で代替予定",
      },
      // ---- 自分株式会社 独自機能 ----
      {
        category: "自分株式会社 独自機能",
        feature: "AI 役員会議 (MAGI System)",
        competitorDetail: "— Slack にはない機能 (単なるボットではない)",
        status: "unique",
        appDetail: "複数ペルソナのAIが組織の意思決定を自律支援",
      },
      {
        category: "自分株式会社 独自機能",
        feature: "フローとストックの統合",
        competitorDetail: "— Slack はフロー情報中心で流れてしまう",
        status: "unique",
        appDetail: "チャットとノートを AI で自動整理・構造化する思想",
      },
    ],
  },

  // -------------------------------------------------------------------------
  // ジョブカン
  // -------------------------------------------------------------------------
  {
    id: "jobcan",
    name: "ジョブカン",
    features: [
      // ---- バックオフィス (勤怠) ----
      {
        category: "バックオフィス (勤怠)",
        feature: "打刻・シフト管理",
        competitorDetail: "ICカードやGPSでの出退勤打刻とシフト作成",
        status: "notYet",
        appDetail: "未実装 — 個人タスクのトラッキングは実装済み",
      },
      // ---- バックオフィス (経費) ----
      {
        category: "バックオフィス (経費)",
        feature: "領収書AI読み取り・精算",
        competitorDetail: "領収書画像を解析し経費申請を自動化",
        status: "partial",
        appDetail: "個人の収支入力・家計管理として部分実装",
      },
      // ---- バックオフィス (ワークフロー) ----
      {
        category: "バックオフィス (ワークフロー)",
        feature: "稟議・承認経路設定",
        competitorDetail: "社内の各種申請と多段階の承認フロー",
        status: "notYet",
        appDetail: "未実装 — 将来的にAIによる自動申請・代理承認を検討",
      },
      // ---- 自分株式会社 独自機能 ----
      {
        category: "自分株式会社 独自機能",
        feature: "AI 役員会議 (MAGI System)",
        competitorDetail: "— ジョブカン にはない機能",
        status: "unique",
        appDetail: "業務管理だけでなく、意思決定そのものをAIが支援",
      },
      {
        category: "自分株式会社 独自機能",
        feature: "個人生産性からのシームレスな統合",
        competitorDetail: "— 管理者主体のツール設計",
        status: "unique",
        appDetail:
          "従業員個人のノートやタスク管理の延長でバックオフィスが完結",
      },
    ],
  },
];

// ---------------------------------------------------------------------------
// Handler
// ---------------------------------------------------------------------------

serve((req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  return new Response(
    JSON.stringify({ success: true, competitors: COMPETITOR_DATA }),
    {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    },
  );
});
