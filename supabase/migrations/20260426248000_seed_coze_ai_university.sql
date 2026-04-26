-- PS#3 S71: AI大学 237→238社化 — Coze 追加
-- Coze: ByteDanceのAIエージェント+チャットボットプラットフォーム / coze.com / アジア圧倒的シェア

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'coze',
  'overview',
  'Coze — ByteDanceのAIエージェント&チャットボットプラットフォーム (coze.com / アジアNo.1 / ノーコード)',
  $$## Coze — ByteDance AIエージェント&チャットボットプラットフォーム

**カテゴリ**: AI Agent Platform / Chatbot Builder / No-Code AI Development
**開発元**: ByteDance (字節跳動) / 本社: Beijing + Singapore + San Jose
**グローバルサービス**: coze.com (海外版) / coze.cn (中国版)
**リリース**: 2024年1月 (グローバル) / 2023年11月 (中国β)
**月間アクティブユーザー**: 数百万人 (Asia中心) / 日本ユーザー急増中
**評価**: 8/9

### 概要
Coze は **TikTok・Douyin を運営する ByteDance** が開発したAIエージェント&チャットボット構築プラットフォーム。ノーコードUIでAIアシスタント・RAGチャットボット・自律エージェントを作成し、LINE / Slack / Discord / Telegram / WeChat などのメッセージングアプリに1クリックで公開できる。

**日本での特徴**: LINEとの統合が公式対応しており、「LINE公式アカウントにAIチャットボットを繋ぐ」ユースケースで急速普及中。中小企業 / 個人事業主向けAI活用の入門ツールとしてQiita/Zenn記事でも頻出。

Dify との違いは「**デプロイ先メッセージングサービスとの統合の豊富さ**」と「**ByteDanceのインフラによる高可用性・高速性**」。セルフホスト不可だが、無料枠が非常に寛大。

### 主な機能

**Bot Builder (チャットボット作成)**
- システムプロンプト設定: 性格・回答スタイル・制約を日本語で記述
- 対話サンプル: 良い回答例を登録 → Few-shot学習
- メモリ機能: ユーザーごとの記憶を永続保存 (「あなたの好きな食べ物は？」を覚える)

**ナレッジベース (RAG)**
- PDF / Word / URL / Notionページ を取り込んで知識化
- チャンク分割・埋め込み生成を自動処理
- 最大50MBファイル / 最大20ファイル (Proプラン)

**プラグインシステム**
- Web検索 / 画像生成 / コード実行 / 天気 / 翻訳 など100+プラグイン内蔵
- カスタムプラグイン: OpenAPI仕様書を貼るだけで外部API呼び出し可能
- Coze Workflow: ノードベースの視覚的ワークフロー (Dify競合)

**デプロイ先 (チャンネル)**
- **LINE**: LINE公式アカウントとの統合 (日本で最重要)
- **Slack / Discord / Telegram**: ビジネスチャット統合
- **Web Widget**: 自社サイトへの埋め込みチャットボット
- **API**: 独自アプリへの組み込み
- **WeChat / Feishu**: アジア向けメッセージングサービス

### Dify との比較
| 項目 | Coze | Dify |
|------|------|------|
| 対象ユーザー | **非エンジニア〜ライトエンジニア** | エンジニア向け |
| UI | より簡単 (ノーコード重視) | 複雑だが高機能 |
| メッセージング統合 | ✅ LINE/Slack/Discord etc. | △ (webhook経由) |
| セルフホスト | ❌ | ✅ Docker |
| 日本語サポート | ✅ UI・ドキュメント完全日本語 | ✅ |
| 無料枠 | ◎ 非常に寛大 | ○ |
| LLM選択 | ByteDance LLM / GPT-4 / Claude | 30+モデル選択 |
| API提供 | ✅ | ✅ |

### 導入コスト
- **Free**: 毎日トークンリセット / 5ボット / 3ナレッジベース / 主要プラグイン全て利用可
- **Pro**: 月$9 / 大容量トークン / 10ボット / 高度な機能
- **Team**: 月$29 / チーム共有 / 優先サポート
- **Enterprise**: カスタム / セキュリティ強化 / SSO

### 自分株式会社での活用可能性
- **LINEチャットボット構築**: 自分株式会社プロダクトのサポートボットをCoze+LINEで低コスト実現
- **AI大学紹介Bot**: AI大学のコンテンツを Coze ナレッジベース化 → FAQ応答ボット
- **社内ナレッジBot**: docs/ を Coze RAG に取り込み → Slack内で社内AI検索$$,
  NULL,
  NULL,
  1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'coze',
  'api',
  'Coze API — チャットボット呼び出し / ボット実行 / ワークフロー (Python/TypeScript/LINE連携)',
  $$## Coze API / 統合

### 概要
Coze でビルドしたボットは REST API 経由で外部アプリから呼び出せる。APIトークンは coze.com のアカウント設定で発行。

### セットアップ
```bash
export COZE_API_TOKEN="pat_xxxxxxxxxxxxxxxxxxxx"
export COZE_BOT_ID="73428668XXXXXXXXXX"  # ボット設定画面から確認
export COZE_BASE_URL="https://api.coze.com"
```

### チャットメッセージ送信 (Python)
```python
import os
import requests

COZE_API_TOKEN = os.environ["COZE_API_TOKEN"]
COZE_BOT_ID = os.environ["COZE_BOT_ID"]
COZE_BASE_URL = os.environ.get("COZE_BASE_URL", "https://api.coze.com")

HEADERS = {
    "Authorization": f"Bearer {COZE_API_TOKEN}",
    "Content-Type": "application/json",
}

def chat_with_bot(
    message: str,
    user_id: str,
    conversation_id: str = "",
) -> str:
    """Coze ボットにメッセージを送信して返答を取得"""
    payload = {
        "bot_id": COZE_BOT_ID,
        "user_id": user_id,
        "stream": False,
        "auto_save_history": True,
        "additional_messages": [
            {"role": "user", "content": message, "content_type": "text"}
        ],
    }
    if conversation_id:
        payload["conversation_id"] = conversation_id

    resp = requests.post(
        f"{COZE_BASE_URL}/v3/chat",
        headers=HEADERS,
        json=payload,
    )
    resp.raise_for_status()
    data = resp.json()

    # ポーリングで完了を待つ
    chat_id = data["data"]["id"]
    conv_id = data["data"]["conversation_id"]

    import time
    while True:
        poll_resp = requests.get(
            f"{COZE_BASE_URL}/v3/chat/retrieve",
            headers=HEADERS,
            params={"chat_id": chat_id, "conversation_id": conv_id},
        )
        poll_resp.raise_for_status()
        status = poll_resp.json()["data"]["status"]
        if status == "completed":
            break
        elif status in ("failed", "requires_action"):
            raise RuntimeError(f"Chat {status}")
        time.sleep(1)

    # メッセージ一覧から assistant の返答を取得
    msg_resp = requests.get(
        f"{COZE_BASE_URL}/v3/chat/message/list",
        headers=HEADERS,
        params={"chat_id": chat_id, "conversation_id": conv_id},
    )
    msg_resp.raise_for_status()
    messages = msg_resp.json()["data"]
    for msg in messages:
        if msg["role"] == "assistant" and msg["type"] == "answer":
            return msg["content"]
    return ""

# CS チケット返信 (Coze RAGボット使用)
answer = chat_with_bot(
    message="パスワードリセットの方法を教えてください",
    user_id="user_456",
)
print(f"Bot: {answer}")
```

### LINE Webhook + Coze 統合 (Deno Edge Function)
```typescript
// supabase/functions/line-coze-webhook/index.ts
// LINE から受信したメッセージを Coze ボットに転送して返信

const LINE_CHANNEL_ACCESS_TOKEN = Deno.env.get("LINE_CHANNEL_ACCESS_TOKEN")!;
const COZE_API_TOKEN = Deno.env.get("COZE_API_TOKEN")!;
const COZE_BOT_ID = Deno.env.get("COZE_BOT_ID")!;

async function callCoze(message: string, userId: string): Promise<string> {
  const chatResp = await fetch("https://api.coze.com/v3/chat", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${COZE_API_TOKEN}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      bot_id: COZE_BOT_ID,
      user_id: userId,
      stream: false,
      auto_save_history: true,
      additional_messages: [
        { role: "user", content: message, content_type: "text" },
      ],
    }),
  });
  const { data } = await chatResp.json();
  // ... ポーリングして返答取得 (上記 Python と同様ロジック)
  return data.id; // task_id を返して非同期処理
}

async function replyToLine(replyToken: string, message: string) {
  await fetch("https://api.line.me/v2/bot/message/reply", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${LINE_CHANNEL_ACCESS_TOKEN}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      replyToken,
      messages: [{ type: "text", text: message }],
    }),
  });
}

Deno.serve(async (req: Request) => {
  const { events } = await req.json();
  for (const event of events) {
    if (event.type === "message" && event.message.type === "text") {
      const answer = await callCoze(event.message.text, event.source.userId);
      await replyToLine(event.replyToken, answer);
    }
  }
  return new Response("OK");
});
```

### ワークフロー API (Coze Workflow 実行)
```python
def run_coze_workflow(
    workflow_id: str,
    parameters: dict,
) -> dict:
    """Coze ワークフローを API から実行"""
    resp = requests.post(
        f"{COZE_BASE_URL}/v1/workflow/run",
        headers=HEADERS,
        json={
            "workflow_id": workflow_id,
            "parameters": parameters,
        },
    )
    resp.raise_for_status()
    return resp.json()["data"]

# AI大学コンテンツ生成ワークフロー
result = run_coze_workflow(
    workflow_id="73428668XXXXXXXX",
    parameters={
        "provider_name": "新しいAIツール",
        "provider_url": "https://example.com",
    },
)
print(result["output"])
```$$,
  NULL,
  NULL,
  2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'coze',
  'models',
  'Coze 技術詳細 — ByteDance AI戦略 / Doubao LLM / 日本市場展開 / AIエージェントプラットフォーム競合比較',
  $$## Coze 技術詳細

### ByteDance のAI戦略における Coze の位置付け

```
ByteDance AI エコシステム (2024〜2025年)

コンシューマー:
  TikTok / Douyin → AI推薦・生成コンテンツフィルタ
  Lark (Feishu) → ビジネスAIアシスタント
  Dreamina → 画像生成AI (海外版)

デベロッパー向け:
  Coze ────────────── AIエージェント・ボット構築
  Doubao API ────────── LLM API (GPT-4相当)
  Volcano Engine ────── GPU クラウド (AI学習・推論)
  BytePlus ───────────── 機械学習 PaaS (海外向け)

社内モデル:
  Doubao-1.5-Pro ── ByteDance 独自LLM
  Doubao-vision ──── 画像認識モデル
  Seed TTS ──────── 音声生成モデル
```

### Doubao LLM (ByteDance 独自モデル)

Coze は内部的に **Doubao** シリーズを使用:

| モデル | 特徴 | GPT-4比較 |
|--------|------|-----------|
| Doubao-1.5-Pro-32k | 高品質・長文脈 | GPT-4o 相当 |
| Doubao-1.5-Lite-32k | 高速・低コスト | GPT-4o mini 相当 |
| Doubao-1.5-Pro-256k | 超長文脈 (256k tokens) | Claude 3.5 相当 |
| Doubao-vision-pro | 画像理解 | GPT-4V 相当 |

Coze の無料プランでは Doubao が使用される。Pro プランでは **GPT-4 / Claude 3.5** も選択可能。

### 日本市場での Coze 特徴

```
日本での急成長要因:
  1. LINE統合: 日本最大のメッセージングアプリとの公式連携
     → 「LINE公式アカウントをAI化」は日本中小企業の強いニーズ
     → 飲食店 / 美容院 / 不動産 などの予約・FAQ自動化に活用

  2. 日本語UI完全対応:
     → Dify / LangChain 等は英語UIが多く日本中小企業には敷居高い
     → Coze は設定画面・ドキュメント・チュートリアル全て日本語

  3. 無料枠の寛大さ:
     → 月$0 で本番利用可能なレベルのボットを運用できる
     → 「試してみて良かったら使い続ける」導線がAI初心者に刺さる

Coze が弱い点:
  - セルフホスト不可 → データがByteDance (中国系企業) のサーバーに保存
  - 金融・医療・官公庁などセキュリティ要件が高い業種では採用困難
  - エンジニア向けのカスタマイズ性はDifyに劣る
```

### AIエージェントプラットフォーム全体比較

| 項目 | **Coze** | **Dify** | **Flowise** | **n8n** |
|------|---------|---------|------------|--------|
| 対象 | 非エンジニア | エンジニア | エンジニア | 自動化担当 |
| セルフホスト | ❌ | ✅ | ✅ | ✅ |
| LINE統合 | ✅ 公式 | △ webhook | △ | △ |
| ノーコード度 | ◎ | ○ | ○ | ○ |
| エンタープライズ | △ | ✅ | △ | ✅ |
| 日本語UI | ✅ | ✅ | △ | △ |
| データ保管 | ByteDance | 選択可 | 自社 | 自社 |
| 月額最安 | 無料 | 無料 | 無料 | 無料 |

### 自分株式会社での推奨採用パターン

```
推奨:
  外部向けサポートボット (LINE / Slack 公開) → Coze
    理由: 運用コスト最小 / LINE統合が簡単 / 非エンジニアでも更新可能

  社内AI基盤 / セキュリティ要件あり → Dify (セルフホスト)
    理由: データを自社インフラに保管 / 完全カスタマイズ

  現在の cs-check.yml (Claude Code) との棲み分け:
    FAQ自動返信 (定型) → Coze RAG に移行 → Claude API コスト削減
    複雑なエスカレーション判断 → Claude Code 継続
```$$,
  NULL,
  NULL,
  3
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 237→238社化: Coze 追加',
  'PS#3 S71。Coze (ByteDance AIエージェント+チャットボットプラットフォーム/ノーコード/Doubao LLM/LINE統合/100+プラグイン/Coze Workflow/日本語完全対応/アジアNo.1シェア/8/9) を ai_university_content に追加。',
  '2026-04-26'
)
ON CONFLICT DO NOTHING;
