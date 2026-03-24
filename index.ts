import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// 13競合製品の機能比較データ（フロントエンドから移行・軽量化）
// フォーマット: [競合名, カテゴリ, 機能名, 競合の詳細, ステータス, 自社アプリの詳細]
const rawData = [
  // Notion
  ['Notion','ノート編集','リッチテキスト編集','Markdown + スラッシュコマンドでブロック挿入','done','Markdown 対応エディタ実装済み'],
  ['Notion','ノート編集','AI 文章補助','Notion AI: 文章生成・改善・要約','done','AI Secretary / MAGI System で複数モデル対応'],
  ['Notion','ノート編集','バージョン履歴','無料プランは7日間、有料は無制限','notYet','未実装 — ロードマップに追加予定'],
  ['Notion','ノート編集','ファイル添付','画像・PDF 等をブロックとして埋め込み','notYet','未実装'],
  ['Notion','ノート編集','コードブロック','シンタックスハイライト付きコードブロック','partial','Markdown コードフェンス対応済み'],
  ['Notion','整理・検索','タグ・カテゴリ','ページにタグ付け・フィルタリング','done','カテゴリページ実装済み'],
  ['Notion','整理・検索','全文検索','ページ横断検索・クイックファインド','partial','AI 検索・埋め込み検索を部分実装'],
  ['Notion','整理・検索','テンプレート','公式テンプレートギャラリー + コミュニティ共有','partial','テンプレートマーケットプレイス画面実装済み'],
  ['Notion','データベース','テーブルビュー','スプレッドシート形式でプロパティ管理','notYet','未実装 — 中期計画で対応予定'],
  ['Notion','データベース','カンバン/ボード','ステータス別カードビュー','notYet','未実装 — 中期計画で対応予定'],
  ['Notion','データベース','カレンダービュー','日付プロパティをカレンダーで表示','notYet','未実装'],
  ['Notion','データベース','ガントチャート','タイムラインビューでスケジュール管理','notYet','未実装'],
  ['Notion','データベース','リレーション・ロールアップ','DB 間リンクと集計フィールド','notYet','未実装 — 長期計画で対応予定'],
  ['Notion','共有・コラボ','ページ公開','URLで誰でも閲覧可能なページ公開','done','公開メモ機能実装済み・OGP対応'],
  ['Notion','共有・コラボ','リアルタイム共同編集','複数人が同時に編集可能','notYet','未実装 — 中期計画 (Team workspace) で対応予定'],
  ['Notion','共有・コラボ','コメント・メンション','ブロックへのインラインコメント','notYet','未実装'],
  ['Notion','共有・コラボ','チームワークスペース','組織単位でのページ・権限管理','notYet','未実装 — 中期計画で Team/Enterprise 対応予定'],
  ['Notion','移行・連携','Notion からインポート','Notion 公式はエクスポートのみ提供','done','CSV インポート実装済み・Edge Function first'],
  ['Notion','移行・連携','Evernote からインポート','ENEX インポート対応','done','ENEX インポート実装済み・Edge Function first'],
  ['Notion','移行・連携','Markdown インポート','Markdown ファイルのインポート可能','done','Markdown インポート実装済み'],
  ['Notion','移行・連携','Web クリッパー','ブラウザ拡張でウェブページを保存','notYet','未実装'],
  ['Notion','移行・連携','外部サービス連携 (Zapier 等)','API + Zapier/Make/IFTTT 連携','partial','Supabase Edge Function 経由で API 公開中'],
  ['Notion','プラットフォーム','Web アプリ','ブラウザで全機能利用可能','done','Flutter Web 実装済み'],
  ['Notion','プラットフォーム','モバイルアプリ (iOS/Android)','ネイティブアプリ提供','inProgress','Flutter クロスプラットフォーム対応可能 — リリース準備中'],
  ['Notion','プラットフォーム','デスクトップアプリ','Mac/Windows Electron アプリ','inProgress','Flutter Desktop 対応可能 — リリース準備中'],
  ['Notion','プラットフォーム','オフライン対応','オフラインでも閲覧・編集可能','notYet','未実装 — 長期計画で対応予定'],
  ['Notion','自分株式会社 独自機能','マインドマップ','— Notion にはない機能','unique','ビジュアルマインドマップ実装済み'],
  ['Notion','自分株式会社 独自機能','記憶ドリル','— Notion にはない機能','unique','スペーシング反復学習ドリル実装済み'],
  ['Notion','自分株式会社 独自機能','AI エージェント組織','— Notion にはない機能','unique','CEO/CFO/CMO/CHRO 役員会議 AI 実装済み'],
  ['Notion','自分株式会社 独自機能','経営コックピット','— Notion にはない機能','unique','KPI・資産・習慣を一画面で管理'],
  ['Notion','自分株式会社 独自機能','Growth ロードマップ進捗表示','— Notion にはない機能','unique','このカードがその機能です'],
  ['Notion','自分株式会社 独自機能','Referral 紹介プログラム','— Notion にはない機能','unique','anti-abuse 付き referral code 発行・管理実装済み'],
  
  // EverNote
  ['EverNote','ノート作成','リッチテキスト編集','フォント・色・レイアウト等のリッチエディタ','done','Markdown 対応エディタ実装済み'],
  ['EverNote','ノート作成','Web クリッパー','ブラウザ拡張でウェブページ全体を保存','notYet','未実装'],
  ['EverNote','ノート作成','手書きメモ / スケッチ','タブレット/スタイラスでの手書き入力','notYet','未実装'],
  ['EverNote','整理・検索','タグ','複数タグでノートをクロスカテゴリ管理','done','タグ機能実装済み'],
  ['EverNote','タスク・リマインダー','タスク管理','チェックリスト・締切・担当者付きタスク','partial','習慣トラッカー・KPI 管理で部分対応'],
  ['EverNote','移行・連携','ENEX エクスポート/インポート','Evernote 標準フォーマットで移行対応','done','ENEX インポート実装済み・Edge Function first'],
  ['EverNote','自分株式会社 独自機能','AI エージェント組織','— EverNote にはない機能','unique','CEO/CFO/CMO/CHRO 役員会議 AI 実装済み'],

  // MoneyForward
  ['MoneyForward','家計管理','手動収支入力','手動での収支記録','done','収支入力・振替機能実装済み'],
  ['MoneyForward','家計管理','口座・カード自動連携','銀行・クレカ・電子マネーを自動取得','notYet','未実装 — 金融 API 連携は長期計画'],
  ['MoneyForward','資産管理','総資産表示','全口座の資産合計をリアルタイム表示','done','資産管理画面実装済み'],
  ['MoneyForward','資産管理','資産推移グラフ','資産の時系列変化を折れ線グラフで表示','partial','KPI チャートで部分対応'],
  ['MoneyForward','予算管理','予実比較','予算に対して実際の支出を比較表示','done','月間収支カレンダーで収入・支出・差額を表示'],
  ['MoneyForward','自分株式会社 独自機能','AI エージェント組織 (CFO 含む)','— MoneyForward にはない機能','unique','CFO AI による財務分析・アドバイス実装済み'],

  // X (Twitter)
  ['X','投稿・コンテンツ','テキスト投稿','最大4000文字 / 280文字','done','Markdown ノート作成実装済み (文字数制限なし)'],
  ['X','タイムライン・発見','全文・ユーザー検索','キーワード等で絞り込み検索','partial','AI 埋め込み検索を部分実装'],
  ['X','エンゲージメント','ブックマーク','ポストを非公開でコレクションに保存','done','ノートへの保存・お気に入り機能実装済み'],
  ['X','自分株式会社 独自機能','長文プライベートノート管理','— X は短文パブリック投稿が主軸','unique','Markdown ノート・カテゴリ・AI 整理実装済み'],

  // Animaworks
  ['Animaworks','目標・習慣管理','習慣トラッカー','毎日の習慣を記録・継続率を可視化','done','習慣トラッカー実装済み (チェックイン・連続記録・グラフ)'],
  ['Animaworks','目標・習慣管理','OKR / KPI 管理','目標と主要結果 (OKR) を階層管理','done','KPI ダッシュボード実装済み'],
  ['Animaworks','振り返り・ジャーナル','日次振り返り','今日の出来事・感情・成果を記録','done','Markdown ノートで日記・振り返り記録可能'],
  ['Animaworks','自分株式会社 独自機能','AI エージェント組織','— Animaworks にはない機能','unique','役員会議 AI で戦略的意思決定を支援'],

  // Claude Code & Codex
  ['Claude Code','AI コーディング支援','ドキュメント生成','コードからコメント・README を自動生成','done','AI Secretary でノート・レポート生成実装済み (汎用文書生成)'],
  ['Claude Code','ファイル・環境操作','ファイル読み書き・編集','プロジェクト内の任意ファイルを読み取り・編集','done','Markdown ノート作成・編集実装済み'],
  ['Codex','ナレッジ管理','コードベース検索・Q&A','コードの意味を理解した自然言語検索','partial','MAGI System + AI Secretary でドキュメント Q&A 実装済み'],
  ['Codex','自分株式会社 独自機能','収支・資産管理','— Codex にはない機能','unique','収支・資産トラッキング実装済み'],

  // netkeiba, OpenClaw, Claude works, Chatwork, Slack, ジョブカン
  ['netkeiba','収支管理','馬券収支トラッキング','馬券の購入・払戻を記録して収支をグラフ表示','done','収支管理機能で任意カテゴリの収支トラッキング実装済み'],
  ['OpenClaw','AI エージェント','ローカル環境・ファイル操作','ファイルシステムやコマンドの実行','done','ノート・メディア・データのローカル/クラウド保存実装済み'],
  ['Claude works','自分株式会社 独自機能','個人資産・収支との統合','— Claude works にはない機能','unique','個人の収支・資産トラッキングを AI 支援と一元化'],
  ['Chatwork','タスク管理','タスクのアサインと通知','メッセージからタスクを作成し担当者へ通知','partial','個人向けタスク管理・リマインダーは実装済み'],
  ['Slack','連携・拡張','外部アプリ連携','Google Drive, GitHubなど多数の連携','partial','Supabase Edge Function経由でのAPI連携を部分実装'],
  ['ジョブカン','自分株式会社 独自機能','個人生産性からのシームレスな統合','— 管理者主体のツール設計','unique','従業員個人のノートやタスク管理の延長でバックオフィスが完結'],
];

serve((req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // 将来的には competitor_features DB テーブルから取得するように拡張可能
    // 現時点ではフロントエンドのハードコードをバックエンドへ退避させて軽量化することを目的とする
    return new Response(JSON.stringify({ features: rawData }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error: unknown) {
    const errorMessage = error instanceof Error ? error.message : String(error);
    return new Response(JSON.stringify({ error: errorMessage }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});