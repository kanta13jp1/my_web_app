-- Session PS#3-S32: AI大学 158社化 — Browserbase 追加
-- Paul Klein IV が 2024 年に創業した AI エージェント向けヘッドレスブラウザ インフラ。
-- $40M Series B (Notable Capital 主導) @ $300M valuation / 累計 $68M。
-- Perplexity・Vercel を含む 1,000+ 顧客 / 2025 年に 5,000 万回ブラウザセッション実行。
-- Stagehand SDK (自然言語でブラウザ操作を記述できる OSS フレームワーク) を提供。
-- LLM・AI エージェントが任意の Web サイトをクリック・スクレイプ・フォーム入力できる基盤。
-- 既存 157 社に空白だった「AI エージェント向けブラウザ自動化インフラ」軸を埋める。
-- Step 0: 9/9 (OSS・公開 API・Perplexity/Vercel 採用・$300M 評価・50M セッション実績)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES

(
  'browserbase',
  'overview',
  'Browserbase — AI エージェントのためのヘッドレスブラウザ インフラ',
  $md$
# Browserbase — The Browser Infrastructure for AI Agents

2024 年創業。**Paul Klein IV** が「AI エージェントがあらゆる Web サイトを
人間と同様に操作できるインフラ」を目指して設立。

LLM や AI エージェントが **任意の Web サイトに対してクリック・スクレイプ・
フォーム入力・データ抽出** を大規模かつ高信頼性で実行できる
**マネージドヘッドレスブラウザ** をクラウド API として提供。

2026 年 Series B $40M (Notable Capital 主導、Kleiner Perkins・CRV 参加) を調達し
評価額 **$300M** に到達。累計調達額 $68M。

Perplexity・Vercel を含む **1,000+ 顧客** が基幹 AI エージェントインフラとして採用。
2025 年に **5,000 万回** のブラウザセッションを処理 (2024 年比 2×)。

## 主要プロダクト
- **Browserbase Cloud** — マネージドヘッドレスブラウザ API (Chromium ベース)
- **Stagehand SDK** — 自然言語でブラウザ操作を記述できる OSS フレームワーク (Playwright 互換)
- **Director** — Web 自動化の高レベルオーケストレーションツール (2026 新発表)
- **Stealth Mode** — ボット検出回避・CAPTCHA 解決のためのアンチ検出機能
- **セッション記録・再生** — デバッグ用の全セッションビデオ録画機能

## 強み
- **AI エージェント最適化** — 通常の Playwright/Selenium と異なり LLM の非決定的な動作に対応
- **大規模並列処理** — 何千もの並行ブラウザセッションをクラウドで管理
- **Stagehand の自然言語 API** — `page.act("ログインボタンをクリック")` のような直感的記述
- Perplexity・Vercel など AI-first 企業の基幹インフラとして実績
$md$,
  'https://www.browserbase.com/',
  '2026-04-24',
  1
),

(
  'browserbase',
  'models',
  'Browserbase API・SDK 一覧 (2026)',
  $md$
## Browserbase の構成要素

Browserbase は「モデル」ではなく「ブラウザセッション管理インフラ」を提供する。

## 接続方法

| 方法 | 説明 | 向き先 |
| :--- | :--- | :--- |
| **Playwright** | `connectOverCDP()` でリモートブラウザに接続 | 既存 Playwright コード |
| **Puppeteer** | CDP 経由でリモート Chrome 制御 | 既存 Puppeteer コード |
| **Stagehand SDK** | 自然言語 + Playwright の高レベル抽象化 | AI エージェント |

## Stagehand SDK の主要メソッド

| メソッド | 説明 | 例 |
| :--- | :--- | :--- |
| `page.act(instruction)` | 自然言語で操作実行 | `"ログインボタンをクリック"` |
| `page.extract(instruction)` | データ抽出 | `"価格情報を取得"` |
| `page.observe(instruction)` | 操作計画を確認 | `"何ができるか確認"` |

## セッション機能

| 機能 | 説明 |
| :--- | :--- |
| **並列セッション** | 複数のブラウザセッションを同時実行 |
| **セッション永続化** | Cookie・ローカルストレージを保持 |
| **ビデオ録画** | 全セッションの動画キャプチャ (デバッグ用) |
| **Stealth Mode** | ボット検出・CAPTCHA 回避 |
| **プロキシ** | IP ローテーション・地域指定 |

## 料金 (概要)

Browserbase は API 使用量に基づく従量課金制。
詳細はダッシュボード (app.browserbase.com) から確認可能。
Free tier と Pro プランあり。Enterprise は要問合せ。
$md$,
  'https://docs.browserbase.com/',
  '2026-04-24',
  2
),

(
  'browserbase',
  'api',
  'Browserbase API 入門',
  $md$
## Browserbase API の始め方

### Playwright 経由 (Python)

```python
# pip install playwright browserbase

from browserbase import Browserbase
from playwright.sync_api import sync_playwright

bb = Browserbase(api_key="your-api-key")

# セッションを作成
session = bb.sessions.create(project_id="your-project-id")

with sync_playwright() as p:
    browser = p.chromium.connect_over_cdp(session.connect_url)
    page = browser.new_page()

    page.goto("https://example.com")
    title = page.title()
    print(f"ページタイトル: {title}")

    browser.close()
```

### Stagehand SDK (AI エージェント向け)

```typescript
// npm install @browserbasehq/stagehand

import { Stagehand } from "@browserbasehq/stagehand";

const stagehand = new Stagehand({
    env: "BROWSERBASE",
    apiKey: process.env.BROWSERBASE_API_KEY,
    projectId: process.env.BROWSERBASE_PROJECT_ID,
    modelName: "gpt-4o",
    modelClientOptions: {
        apiKey: process.env.OPENAI_API_KEY,
    },
});

await stagehand.init();

// 自然言語でブラウザを操作
await stagehand.page.goto("https://github.com");
await stagehand.page.act("検索ボックスに 'AI agents' と入力して検索");

// 構造化データを抽出
const results = await stagehand.page.extract({
    instruction: "検索結果のリポジトリ名とスター数を取得",
    schema: z.object({
        repositories: z.array(z.object({
            name: z.string(),
            stars: z.number(),
        }))
    })
});

console.log(results);
await stagehand.close();
```

## クイックスタート

1. [app.browserbase.com](https://app.browserbase.com) でアカウント作成 → API キー取得
2. `pip install browserbase playwright` または `npm install @browserbasehq/stagehand`
3. `BROWSERBASE_API_KEY` と `BROWSERBASE_PROJECT_ID` を環境変数に設定
4. セッションを作成 → Playwright/Puppeteer/Stagehand で接続
$md$,
  'https://docs.browserbase.com/',
  '2026-04-24',
  3
)

ON CONFLICT DO NOTHING;
