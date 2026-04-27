-- PS#3 S73: AI大学 241→242社化 — Make.com 追加
-- Make.com: ビジュアルワークフロー自動化 / 旧Integromat / 1000+統合 / AIモジュール / Zapier競合

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'make_com',
  'overview',
  'Make.com — ビジュアルワークフロー自動化 (旧Integromat / 1000+統合 / AIモジュール / Zapier競合)',
  $$## Make.com — ビジュアルワークフロー自動化プラットフォーム

**カテゴリ**: No-Code Automation / Workflow Orchestration / AI Integration / iPaaS
**開発元**: Make (旧Integromat) / Celonis 傘下
**本社**: プラハ (チェコ) → サンフランシスコ
**設立**: 2012年 (Integromat として) → 2020年 Make に改称
**買収**: 2022年 Celonis が買収 (評価額 非公開)
**統合数**: 1,000+ アプリ
**ユーザー数**: 500,000+ 組織
**価格**: 無料〜月$29 (Teams)
**評価**: 8/9

### 概要
Make.com は **「ドラッグ&ドロップでビジュアルにワークフローを構築」** するノーコード自動化プラットフォーム。2012年にチェコで Integromat として誕生し、2020年に Make へリブランド。競合の Zapier と比較して**複雑なワークフロー**・**データ変換**・**条件分岐**が得意で、エンジニアや上級ユーザーに支持されている。

**AIとの融合**: OpenAI / Anthropic Claude / Google Gemini / Stability AI などの AI サービスを組み込んだ **AIワークフロー** が Make の急成長の核。「AIオーケストレーター」としての役割が拡大中。

**日本での普及**: Zapier に比べて価格が安く、日本語ドキュメントも充実。国内でも中小企業・フリーランスを中心に採用が増加。

### 主な特徴

**1. ビジュアルシナリオエディタ**
- キャンバス上にモジュール (アプリの操作) をドラッグ&ドロップ
- ルーター・フィルター・イテレーター・アグリゲーターで複雑フローを表現
- データマッピング: JSONパス / 正規表現 / 数式でデータ変換
- エラーハンドリング: 失敗時の代替ルート・リトライ設定

**2. AIモジュール群**
| モジュール | 機能 |
|-----------|------|
| OpenAI (ChatGPT) | テキスト生成・分類・翻訳・要約 |
| Anthropic (Claude) | 長文処理・コード生成・分析 |
| Google Gemini | マルチモーダル処理・Workspace連携 |
| Stability AI | 画像生成 (Stable Diffusion) |
| Hugging Face | カスタムモデル呼び出し |
| Make AI Agent | 自律エージェント機能 (2024〜) |

**3. データ変換機能**
- 豊富な組み込み関数: 文字列・日付・数値・配列・JSON操作
- カスタムコード: JavaScript / TypeScript で独自処理
- データストア: Make内のデータベース機能
- 変数: グローバル変数・ローカル変数

**4. トリガー種類**
- **即時**: Webhook受信時 / 新規データ検出時
- **スケジュール**: 毎分〜毎月 (プランによる)
- **手動**: ボタンクリック / API呼び出し

### 競合比較

| 項目 | Make.com | Zapier | n8n | Airflow |
|------|---------|--------|-----|---------|
| UIの直感性 | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐ |
| 複雑なフロー | ✅ 得意 | △ 苦手 | ✅ 得意 | ✅ |
| AI連携 | ✅ 豊富 | ✅ | ✅ | △ |
| 価格 (Free) | 1000 ops/月 | 100 tasks/月 | ✅ セルフホスト | OSS |
| 日本語 | ✅ | △ | △ | ✅ |
| オンプレ | ❌ | ❌ | ✅ | ✅ |
| コード実行 | ✅ JS | ✅ Code by Zapier | ✅ | ✅ Python |

### 価格プラン
| プラン | 月額 | オペレーション | 機能 |
|--------|------|--------------|------|
| Free | $0 | 1,000/月 | 2シナリオ / 15分間隔 |
| Core | $9 | 10,000/月 | 無制限シナリオ / 1分間隔 |
| Pro | $16 | 10,000/月 | カスタム変数 / 優先サポート |
| Teams | $29 | 10,000/月 | チーム機能 / 共有シナリオ |
| Enterprise | カスタム | 無制限 | SSO / SLA / 専任サポート |

### 自分株式会社での活用可能性
- **業務自動化**: 新規ユーザー登録 → Slack通知 → Supabase更新 → ウェルカムメール を自動化
- **AIパイプライン**: ユーザーフィードバック → Claude分析 → Supabase保存 → Slack報告 を Make で構築
- **競合モニタリング**: RSSフィード → ChatGPT要約 → Notion/Slack配信 を Make シナリオで実装
- **競合21社**: zapier (直接競合) / n8n (OSS競合) / Make自体が統合プラットフォームとして競合候補$$,
  NULL,
  NULL,
  1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'make_com',
  'api',
  'Make.com API — Webhook / HTTP連携 / Supabase統合 / AIワークフロー構築',
  $$## Make.com API / 統合ガイド

### 概要
Make.com は REST API (Webhook / HTTP モジュール) と組み込みアプリモジュールの2つの接続方法を提供。Supabase との連携は Webhook + PostgreSQL モジュール、または HTTP モジュールで実現できる。

### 1. Webhook トリガー (Make → 外部サービスを呼び出す)

```typescript
// Supabase Edge Function として Webhook エンドポイントを構築
// Make が HTTP モジュールでこの URL を呼び出す

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405 });
  }

  const payload = await req.json();
  // Make から送られてくるデータを処理
  const { user_id, action, data } = payload;

  // Supabase DB への保存
  const { createClient } = await import("https://esm.sh/@supabase/supabase-js@2");
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  await supabase.from("automation_logs").insert({
    user_id,
    action,
    payload: data,
    source: "make_com",
    created_at: new Date().toISOString(),
  });

  return new Response(JSON.stringify({ success: true }), {
    headers: { "Content-Type": "application/json" },
  });
});
```

### 2. Supabase → Make Webhook 送信

```typescript
// Supabase Edge Function から Make の Webhook を呼び出す
const MAKE_WEBHOOK_URL = Deno.env.get("MAKE_WEBHOOK_URL")!;

async function triggerMakeScenario(data: Record<string, unknown>): Promise<void> {
  const response = await fetch(MAKE_WEBHOOK_URL, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(data),
  });

  if (!response.ok) {
    console.error(`Make webhook failed: ${response.status}`);
  }
}

// 使用例: 新規ユーザー登録時に Make シナリオをトリガー
Deno.serve(async (req: Request) => {
  const { user } = await req.json();

  // Make シナリオ起動 (ウェルカムメール / Slack通知 / CRM登録 等)
  await triggerMakeScenario({
    event: "user_registered",
    user_id: user.id,
    email: user.email,
    created_at: new Date().toISOString(),
  });

  return new Response(JSON.stringify({ ok: true }));
});
```

### 3. Make API (シナリオ管理)

```python
import requests
import os

MAKE_API_KEY = os.environ["MAKE_API_KEY"]
MAKE_TEAM_ID = os.environ["MAKE_TEAM_ID"]
BASE_URL = "https://eu1.make.com/api/v2"  # または us1

headers = {
    "Authorization": f"Token {MAKE_API_KEY}",
    "Content-Type": "application/json",
}

def list_scenarios() -> list[dict]:
    """全シナリオ一覧を取得"""
    resp = requests.get(
        f"{BASE_URL}/scenarios",
        headers=headers,
        params={"teamId": MAKE_TEAM_ID},
    )
    return resp.json().get("scenarios", [])

def run_scenario(scenario_id: int, data: dict) -> dict:
    """シナリオを即時実行"""
    resp = requests.post(
        f"{BASE_URL}/scenarios/{scenario_id}/run",
        headers=headers,
        json={"data": data},
    )
    return resp.json()
```

### 4. AI + Make 実践シナリオ例

```
[AIフィードバック分析パイプライン]

① Supabase → Make Webhook (新規フィードバック検出)
② Make: OpenAI GPT-4o でフィードバックを分類・要約
③ Make: 感情スコアを Supabase に書き戻し
④ 否定的フィードバック (score < 3) → Slack #support へ通知
⑤ 月次レポート: Google Sheets に集計データを自動追記
```

```
[競合モニタリング自動化]

① Make: RSSフィード監視 (Notion/Evernote/Slack等のブログ)
② Make: 新規記事を ChatGPT で日本語要約
③ Make: 要約を Supabase の competitor_news テーブルに保存
④ 週次: 上位ニュースを Slack に配信
```

### Make Webhook の URL フォーマット
```
https://hook.eu1.make.com/xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
                ↑ リージョン (eu1 / us1 / us2)
```$$,
  NULL,
  NULL,
  2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'make_com',
  'models',
  'Make.com 技術詳細 — シナリオアーキテクチャ / データフロー / AIエージェント機能 / エラーハンドリング',
  $$## Make.com 技術詳細

### シナリオアーキテクチャ

```
[Make シナリオの構造]

トリガーモジュール (1個)
  ↓ データ (バンドル)
ルーター (条件分岐)
  ├── ルートA: 条件Aを満たす場合
  │     → モジュール → モジュール
  └── ルートB: 条件Bを満たす場合
        → モジュール → エラーハンドラー

[バンドル (Bundle)]
Make の処理単位。1回のシナリオ実行で複数バンドルを処理可能。
例: Googleスプレッドシートの100行 → 100バンドル → 100回処理
```

### データフロー制御

```
イテレーター: 配列を個々の要素に分解
  Input: [item1, item2, item3]
  Output: item1 → item2 → item3 (別々に処理)

アグリゲーター: 複数バンドルを1つに集約
  Input: item1, item2, item3 (別々のバンドル)
  Output: [item1, item2, item3] (配列として後続へ)

ルーター: 条件に応じてフローを分岐
  条件: {{1.status}} = "active" → ルートA
  条件: {{1.status}} != "active" → ルートB
```

### AIエージェント機能 (Make AI Agent)

2024年から提供された自律エージェント機能:

```
[Make AI Agent の仕組み]

ユーザー入力 or トリガー
      ↓
Make AI Agent モジュール
  ├── LLM: OpenAI GPT-4o / Anthropic Claude
  ├── ツール: Make内の他モジュールを「ツール」として使用
  │     例: Google検索 / Webスクレイピング / DB読み書き
  └── ループ: 目標達成まで自律的にツールを呼び出し
      ↓
最終回答を返す

→ 従来の固定フロー → 動的に判断するエージェント への進化
```

### エラーハンドリング設計

```
[エラーハンドリングルート]

メインルート: 正常処理
  ↓ エラー発生
エラーハンドラールート (任意設定)
  ├── Resume: エラーを無視して次のバンドルへ
  ├── Ignore: エラーを記録して処理を停止
  ├── Break: 残りバンドルをキューに保存 (後でリトライ)
  └── Retry: 最大5回まで自動リトライ (指数バックオフ)

[Make推奨パターン]
  外部API呼び出し → Retry (一時的なエラーに対応)
  DB書き込み → Break (データ整合性を保証)
  通知送信 → Ignore (通知失敗はビジネスに致命的でない)
```

### Make vs Zapier: 技術的な違い

```
[複雑なデータ変換]
Zapier: パスの指定のみ (変換は限定的)
Make:   式言語で変換可能
        {{formatDate(1.created_at; "YYYY-MM-DD")}}
        {{round(1.amount * 1.1; 2)}}  // 小数点2桁に丸める
        {{join(map(1.tags; "name"); ", ")}}  // 配列をCSV化

[実行コスト]
Zapier: 1 Task = 1 アクション (マルチステップも1タスク)
Make:   1 Operation = 1 モジュール実行
        → 複雑なフローほど Make が割安

[デバッグ]
Zapier: 直近3回の実行ログのみ
Make:   全バンドルのデータフローを視覚化 / 任意の時点からリラン可能
```

### 自分株式会社との関連性

```
現状分析:
  自分株式会社のGHA + Claude Schedule + Supabase EF は
  Make.com と同等の「AIオーケストレーション」を自前実装している。

比較:
  自前: コード管理 / 完全カスタム / インフラコスト低 / 技術力必要
  Make: ノーコード / 迅速構築 / 月$9〜 / 非エンジニアでも操作可能

活用シナリオ:
  1. ユーザーサポートチームがノーコードでCSフローを追加
     (現状: 全てエンジニアが実装 → ボトルネック)
  2. パートナー企業向けにデータ連携を Make シナリオで提供
  3. AI大学コンテンツ: 「Make.com × ChatGPT で業務自動化入門」
     → 非エンジニア向け記事として高アクセスが見込まれる
```$$,
  NULL,
  NULL,
  3
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 241→242社化: Make.com 追加',
  'PS#3 S73。Make.com (旧Integromat/ビジュアルワークフロー自動化/1000+統合/OpenAI+Claude+Gemini AIモジュール/Zapier競合/月$9〜/AIエージェント機能/日本語対応/8/9) を ai_university_content に追加。',
  '2026-04-27'
)
ON CONFLICT DO NOTHING;
