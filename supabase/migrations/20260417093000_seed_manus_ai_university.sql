-- Windowsアプリ版#68: Manus AI 大学コンテンツ seed
-- 汎用AIエージェント — Meta買収・最初の"本物の汎用AIエージェント"

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES

('manus', 'overview',
'Manus AI: 世界初の"真の汎用AIエージェント"',
$$# Manus AI

Manusは「**あらゆる複雑なタスクを自律的に実行できる汎用AIエージェント**」として
2025年3月に世界的バイラルを起こした中国発AIプラットフォーム。
「AGIへの最初の実用的なステップ」と評され、2025年末にMetaが$2-3Bで買収。

## 設立背景

- **開発元**: Monica AI / Butterfly Effect (中国・北京)
- **公開**: 2025年3月 (招待制β → 爆発的バイラル)
- **Meta買収**: 2025年末 (推定$2-3B)
- **哲学**: 「ユーザーの代わりにタスクを実行する — ツールを使うだけでなく、仕事をする」

## "汎用エージェント"の実力

Manusが衝撃を与えた理由は、これまでのAIが「情報提供」に留まっていたのに対し、
**実際に仕事を完了させる**点にある:

```
従来のAI: 「ウェブ旅行計画の作り方を教えます」
Manus:    「旅行計画を実行し、ホテル検索・比較・最安値を表にまとめ、
           カレンダーに登録し、確認メールを送信する」
```

## 主要機能

| 能力 | 詳細 |
|------|------|
| **Webブラウジング** | 実際のブラウザ操作 (ログイン・フォーム入力・スクレイピング) |
| **コード実行** | Pythonスクリプト実行・データ分析・グラフ生成 |
| **ファイル操作** | 作成・編集・変換・ZIP圧縮 |
| **マルチステップ計画** | 複雑なタスクを自動分解→並列実行→統合 |
| **長時間自律動作** | 数時間かかるタスクをバックグラウンド実行 |

## Meta買収後の展開

Meta傘下に入り、MetaのAIインフラ・LLaMA 4との統合が進む。
Manus Skillsにより、チームでの自動化ワークフロー共有が可能に。
$$,
'https://manus.im/',
'2026-04-17', 1),

('manus', 'models',
'Manus のエージェントアーキテクチャ',
$$# Manus エージェントアーキテクチャ

## コアコンセプト: "Hands On AI"

Manusの技術的特徴は**ツールオーケストレーション + 自律計画**の組み合わせ:

```
ユーザー入力
    ↓
[計画エンジン] タスクを最小単位に分解
    ↓
[ツール選択] Browser / Code / Files / APIs から選択
    ↓
[並列実行]  複数ツールを同時実行
    ↓
[検証ループ] 結果を確認し、失敗時は自動リトライ
    ↓
[統合・出力] 最終成果物をユーザーに提示
```

## 使用しているLLM

Manusは独自LLMではなく、**複数の最先端モデルを組み合わせて使用**:

| 用途 | 使用モデル (推定) |
|------|-----------------|
| 計画・推論 | Claude Sonnet / GPT-4.1 / LLaMA 4 (Meta傘下後) |
| コード生成 | Claude Code / Codex |
| ブラウザ制御 | 独自のVision-LLM |

## Manus Skills (自動化ワークフロー)

```python
# Manus Skillsを使ったチーム共有可能なワークフロー定義
skill = {
    "name": "競合調査レポート生成",
    "trigger": "competitor_name",
    "steps": [
        {"tool": "web_search", "query": f"{competitor} latest news 2026"},
        {"tool": "web_scrape", "urls": ["official_site", "crunchbase", "twitter"]},
        {"tool": "code", "lang": "python", "action": "summarize_and_compare"},
        {"tool": "file_create", "format": "markdown", "name": "report.md"}
    ]
}
```

## Devin / Claude Code との比較

| ツール | 強み | 弱み |
|--------|------|------|
| **Manus** | 汎用タスク自動化・非エンジニア向け | コード品質はClaude Code以下 |
| **Devin** | ソフトウェア開発専用・高精度 | 非コーディングタスクは苦手 |
| **Claude Code** | プロジェクト文脈・Multi-AI協調 | GUIブラウジングは不可 |
$$,
'https://manus.im/',
'2026-04-17', 2),

('manus', 'api',
'Manus API: 自アプリにエージェント能力を組み込む',
$$# Manus API

## 概要

Manus Open APIにより、**Manusのエージェント能力を外部アプリに統合**可能。
自分株式会社のEdge Functionから呼び出し、複雑なタスク自動化を実現できる。

## API基本構造

```typescript
// Supabase Edge Function での Manus API 利用例
// supabase/functions/manus-task/index.ts

const MANUS_API_KEY = Deno.env.get('MANUS_API_KEY');

// タスク作成
const task = await fetch('https://api.manus.im/v1/tasks', {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${MANUS_API_KEY}`,
    'Content-Type': 'application/json',
  },
  body: JSON.stringify({
    instruction: "競合サービスのLP・価格・主要機能を調査して比較表を作成して",
    context: {
      target_competitors: ["notion.so", "evernote.com", "moneyforward.com"],
      output_format: "markdown_table",
    },
    tools: ["web_browser", "code_executor"],
  }),
});

const { task_id } = await task.json();

// 完了を待機 (ポーリング or Webhook)
const result = await pollTaskCompletion(task_id);
```

## AI/ML API経由のアクセス

```python
# aimlapi.com経由でのManusアクセス (直接API代替)
from openai import OpenAI

client = OpenAI(
    api_key="AIMLAPI_KEY",
    base_url="https://api.aimlapi.com/v1"
)

response = client.chat.completions.create(
    model="manus/manus-agent",
    messages=[
        {"role": "user", "content": "以下のタスクを実行してください: ..."}
    ]
)
```

## 自分株式会社との統合可能性

| ユースケース | 実装方法 | 期待効果 |
|------------|---------|---------|
| **競合モニタリング強化** | `competitor-monitoring` EF に Manus を統合 | Webスクレイピング精度向上 |
| **AI仮想秘書の拡張** | `ai-assistant` EFでManusをオプション提供 | 複雑タスクの自律実行 |
| **ブログ自動生成** | `blog-auto-publisher` でリサーチ部分をManusに委譲 | NotebookLM代替/補完 |

## プラン

| プラン | 月額 | クレジット |
|--------|------|---------|
| **Free** | $0 | 1,000クレジット/月 |
| **Pro** | $39 | 10,000クレジット/月 |
| **Team** | $49/席 | 無制限 |
$$,
'https://open.manus.im/docs',
'2026-04-17', 3),

('manus', 'news',
'Manus AI 最新ニュース (2026-04-17)',
$$# Manus AI 最新動向 (2026-04-17)

## 主要アップデート

### Meta買収完了 (2025年末)
MetaがManus AIの親会社Butterfly Effectを$2-3Bで買収。
LLaMA 4との統合・MetaのインフラでManusのスケールを加速。

### Manus Skillsのリリース
Anthropicのオープン「Skills」標準をManus上に実装。
チームで自動化ワークフローを共有可能に。月次の手作業を数分で自動化。

### GoHighLevel統合 (2026年2月)
CRM大手GoHighLevelとの統合で、Manusをビジネスオートメーションに活用可能に。
「AIがCRMを操作する」という新しいパラダイムを切り開く。

### PCアプリ版リリース
AIエージェントをユーザーのローカルPC・ファイルにアクセス可能にするデスクトップアプリ。
クラウドのみの制約を超えてローカル業務にまでエージェントを拡張。

## 業界への影響

Manusのバイラルは「AIエージェント元年」を印象付けた:

| 影響 | 内容 |
|------|------|
| **エージェントAI競争の激化** | OpenAI Operator / Claude Computer Use / Devin との競争 |
| **「AGIへの橋渡し」議論** | 汎用タスク実行能力がAGIの実用的な前段階と評価 |
| **非エンジニアへのAI民主化** | コードを書けないユーザーでも複雑なタスクを自動化 |

## このプロジェクトへの示唆

- **マイAIエージェント機能強化**: `my-ai-agent` EFにManusのAPIを選択肢として追加
- **競合モニタリング高度化**: 週次Manus実行でcompetitor-reportsを自動生成
- **「Manus like」機能の差別化**: 自分株式会社内でのマルチステップタスク自動実行機能
$$,
'https://manus.im/',
'2026-04-17', 4)

ON CONFLICT (provider, category) DO UPDATE
  SET content = EXCLUDED.content,
      source_url = EXCLUDED.source_url,
      published_at = EXCLUDED.published_at,
      updated_at = now();
