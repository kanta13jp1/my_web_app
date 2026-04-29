-- PS#3 S119: AI大学 333→334社化 — Replit Agent (クラウドAI IDE / ブラウザ完結開発)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'replit-agent', 'overview',
  'Replit Agent — クラウドAI IDE・ブラウザ完結・自然言語アプリ生成・即時デプロイ (GitHub 5k+ / 9/9)',
  $$## Replit Agent とは

**Replit Agent** は **ブラウザだけで動く AI アプリ開発エージェント**。「**アイデアを話すだけでアプリが生成される**」体験を提供。インストール不要でブラウザを開けば即座に開発・実行・デプロイが可能。

Replit は教育向けクラウド IDE として有名だったが、**Claude 統合の Agent 機能**で「一般人でも AI アプリを作れる」プラットフォームに進化。自然言語でアプリ要件を伝えるだけでコードを生成・実行・デプロイまで自動化。**月 $20〜の Replit Core** で Agent 機能が使える。

## Replit Agent のアーキテクチャ

```
Replit Agent のコンポーネント:

  クラウド IDE (ブラウザ):
    ・コードエディタ (Monaco/VS Code ベース)
    ・統合ターミナル (Linux 環境)
    ・ファイルエクスプローラー
    ・リアルタイムプレビュー

  AI Agent:
    ・自然言語でアプリ要件を理解
    ・コード生成・修正・デバッグ
    ・パッケージインストール自動化
    ・エラー自動修正ループ

  実行環境:
    ・Python / JavaScript / TypeScript
    ・Flask / FastAPI / Express / Next.js
    ・データベース (PostgreSQL / SQLite)
    ・環境変数管理

  デプロイ:
    ・Replit Deployments (ワンクリック)
    ・カスタムドメイン対応
    ・自動スケーリング
    ・Secrets (環境変数) 管理

  Replit DB / Object Storage:
    ・Key-Value ストア (無料)
    ・PostgreSQL (Core プラン)
    ・ファイルストレージ
```

## 主要機能

```
Agent チャット:
  ・「〇〇のアプリを作って」→ 自動生成
  ・「このバグを直して」→ 自動修正
  ・「デプロイして」→ ワンクリック公開

Checkpoints (バージョン管理):
  ・自動でチェックポイント作成
  ・任意の時点に戻れる
  ・git 相当の機能

Ghostwriter (補完):
  ・インライン AI 補完
  ・GitHub Copilot 相当

Teams & Multiplayer:
  ・リアルタイム共同編集
  ・教育機関向け機能
```

## 自分株式会社での活用

| シーン | 活用方法 | 期待効果 |
|--------|----------|---------|
| **プロトタイプ高速作成** | Replit Agent で競馬分析ツールのプロトを 30 分で作成 | ローカル環境セットアップ不要 |
| **API サーバー構築** | Python FastAPI + Replit でバックエンド API を即時公開 | Supabase EF の補完サーバーとして活用 |
| **AI デモ環境** | Claude API を使った競馬予想デモを Replit でホスト | 投資家・パートナーへのデモ環境 |$$,
  NULL, NULL, 1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'replit-agent', 'api',
  'Replit Agent 実践 — アカウント/Agent操作/Python+Flask/Claude API統合/デプロイ/Secrets管理',
  $$## アカウント作成・起動

```text
セットアップ:
1. replit.com にアクセス
2. Google/GitHub アカウントでサインイン (無料)
3. "+ Create Repl" → 言語を選択
4. Agent 機能は "Core" プラン ($20/月) で利用可能

Agent の起動:
  右サイドパネル → "AI" タブ → チャット入力
  または Repl 作成時に "Describe your app" に要件を入力
```

## Agent でアプリ生成

```text
Agent チャット例:

「競馬の予想スコアを計算する Web アプリを作って。
 入力: 馬名、騎手名、オッズ
 出力: 予測勝率 (%)
 Python Flask で API として実装して」

Agent の動作:
  1. Flask のセットアップ
  2. requirements.txt の更新 (flask インストール)
  3. app.py の生成
  4. エンドポイントの実装
  5. テスト実行
  6. プレビューを表示

→ ブラウザ上で即座に動作確認可能
```

## Claude API 統合

```python
# Replit の Secrets に ANTHROPIC_API_KEY を設定してから:

import os
from anthropic import Anthropic
from flask import Flask, request, jsonify

app = Flask(__name__)
client = Anthropic(api_key=os.environ["ANTHROPIC_API_KEY"])

@app.route("/analyze", methods=["POST"])
def analyze_horse():
    """競馬予想の AI 分析"""
    data = request.json
    horse_name = data.get("horse_name")
    odds = data.get("odds")

    message = client.messages.create(
        model="claude-haiku-4-5",
        max_tokens=1024,
        messages=[
            {
                "role": "user",
                "content": f"""
                以下の馬の出走情報を分析して予想勝率を出してください:
                馬名: {horse_name}
                オッズ: {odds}

                JSON形式で回答:
                {{"win_rate": 0.xx, "comment": "..."}}
                """
            }
        ]
    )

    return jsonify({"result": message.content[0].text})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
```

## Replit Secrets (環境変数) 管理

```text
Secrets の設定:
  左サイドパネル → "Secrets" → "+ New Secret"

設定する Secrets:
  ANTHROPIC_API_KEY = sk-ant-...
  SUPABASE_URL = https://xxx.supabase.co
  SUPABASE_SERVICE_KEY = eyJ...

コードでの読み取り:
  Python: os.environ["ANTHROPIC_API_KEY"]
  Node.js: process.env.ANTHROPIC_API_KEY

注意:
  ・Secrets は公開されない (安全)
  ・Fork されても引き継がれない
  ・本番デプロイにも自動で設定
```

## デプロイ (Replit Deployments)

```text
デプロイ手順:
  1. 右上 "Deploy" ボタン をクリック
  2. "Autoscale" または "Reserved VM" を選択
  3. "Deploy" → 数分で本番公開

デプロイ後:
  ・URL: https://your-app.replit.app
  ・カスタムドメイン: 設定画面で追加
  ・HTTPS: 自動設定

無料枠 vs Core:
  - 無料: Repl は常時実行なし (スリープ)
  - Core ($20/月): 常時実行 + Agent + 高速CPU
```

## Replit vs ローカル開発の使い分け

```text
Replit Agent を使う場面:
  ✅ ブラウザだけで完結したい
  ✅ プロトタイプを素早く作りたい
  ✅ インストール不要の環境が必要
  ✅ 非エンジニアにデモを見せたい
  ✅ Claude API の動作確認

ローカル (Flutter/Supabase) を使う場面:
  ✅ 本番プロダクト開発
  ✅ Flutter (Replit は未対応)
  ✅ 複雑な型安全性が必要
  ✅ GitHub Actions との統合

共存パターン:
  Replit: API バックエンドのプロト → 検証後 Supabase EF に移植
  Replit: AI デモ環境 → 本番は Firebase Hosting
```$$,
  NULL, NULL, 2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 333→334社化: Replit Agent 追加',
  'PS#3 S119。Replit Agent (クラウドAI IDE/ブラウザ完結/自然言語アプリ生成/Claude API統合/即時デプロイ/Checkpoints/Secrets管理/教育向け/9/9) を ai_university_content に追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
