-- PS#3 S77: AI大学 249→250社化 — LlamaFile 追加
-- LlamaFile: Mozilla/Meta共同 / 単一実行ファイルLLM / インストール不要 / オフライン / エッジAI / llamacpp統合

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'llamafile',
  'overview',
  'LlamaFile — 単一実行ファイルLLM (Mozilla+Meta / インストール不要 / 全OS対応 / エッジAI / GitHub 20k+)',
  $$## LlamaFile — Single-File LLM Executable

**カテゴリ**: Local LLM / Edge AI / Developer Tools / Embedded AI
**開発元**: Mozilla (主導) + Meta AI (協力) + Cosmopolitan libc コミュニティ
**中心開発者**: Justine Tunney (Cosmopolitan libc 作者 / Mozilla)
**ライセンス**: Apache 2.0
**GitHub**: github.com/Mozilla-Ocho/llamafile (20,000+ スター)
**技術基盤**: llama.cpp + Cosmopolitan libc
**対応OS**: Windows / macOS / Linux / FreeBSD / OpenBSD (単一バイナリ)
**価格**: 完全無料 (OSS)
**評価**: 8/9

### 概要
LlamaFile は **「1つのファイルをダウンロードして実行するだけでLLMが動く」** という革命的なコンセプトを実現したプロジェクト。通常、LLMをローカルで動かすには Ollama や LM Studio のインストール・設定が必要だが、LlamaFile は **インストールが一切不要**。

**核心技術**: Justine Tunney が開発した **Cosmopolitan libc** というポータブル実行ファイル形式を活用。1つの `.llamafile` が Windows / macOS / Linux / BSD 全てで動作する「ポリグロットバイナリ」になっている。

**Mozilla が関与する理由**: AIのプライバシーと分散化を推進するMozillaの「Mozilla.ai」プロジェクトの一環。特定のクラウドサービスに依存しないAIアクセスを提供するという理念を体現している。

### なぜ革命的か

```
[通常のローカルLLMセットアップ vs LlamaFile]

通常 (LM Studio / Ollama):
  1. アプリをダウンロード (数百MB)
  2. インストーラーを実行
  3. 管理者権限が必要なことも
  4. モデルを別途ダウンロード
  5. 起動・設定
  → 合計: 20〜30分 / 技術知識が必要

LlamaFile:
  1. .llamafile を1つダウンロード (モデル込み)
  2. 実行権限を付与: chmod +x model.llamafile
  3. ./model.llamafile をクリックまたは実行
  → 合計: 5分 / 誰でも可能
  → モデルとランタイムが1ファイルに内包
```

### 技術: Cosmopolitan libc

```
[Cosmopolitan libc の仕組み]

通常の実行ファイル:
  ELF (Linux) / PE (Windows) / Mach-O (macOS) → OS固有
  → 各OS用に別々のバイナリが必要

Cosmopolitan 実行ファイル:
  APE (Actually Portable Executable) フォーマット
  → 1つのバイナリが全OS の実行形式を内包
  → OS を自動検出して適切なコードパスを実行

LlamaFile = APE + llama.cpp + モデルウェイト:
  .llamafile = Zip ファイル形式 (実行ファイルも Zip も兼ねる)
  ├── 実行ファイル (llamacpp ランタイム)
  └── モデル (GGUF形式)
  → すべてが1ファイル
```

### 対応モデル例
```
公式 LlamaFile として配布されているモデル:
  llava-v1.5-7b.llamafile    — マルチモーダル (画像理解対応)
  mistral-7b-instruct.llamafile
  gemma-2-2b-it.llamafile    — 軽量 / 高品質
  phi-3-mini.llamafile       — Microsoft 製 / 推論強
  rocket-3b.llamafile        — 超軽量 (3B)

Hugging Face からの変換:
  任意の GGUF モデル → LlamaFile フォーマットに変換可能
  → LM Studio / Ollama で使えるモデルは LlamaFile にも変換可
```

### ユースケース

```
適している場面:
  ✅ エアギャップ環境 (インターネット非接続サーバー)
  ✅ USB に入れて持ち歩くポータブルAI
  ✅ Docker/仮想環境なしのシンプルデプロイ
  ✅ CI/CD パイプラインでのAIテスト (単一バイナリ = 再現性高)
  ✅ 組み込みシステム / IoT エッジデバイス
  ✅ セキュリティが厳しい企業内ネットワーク
  ✅ デモ・プロトタイプ (すぐに動かして見せたい)
  ✅ 教育現場 (生徒のPCに配布するだけで動く)

適さない場面:
  ❌ 複数ユーザーの同時接続 (マルチユーザー管理が弱い)
  ❌ モデル管理UI が必要 (Open WebUI / LM Studio の方が適切)
  ❌ 頻繁なモデル切り替え (毎回別ファイル)
```

### OpenAI互換APIサーバー
```
LlamaFile は起動時に自動でブラウザUIと OpenAI互換APIを起動:

./mistral-7b-instruct.llamafile --server
  ↓
  Chat UI: http://localhost:8080
  API:     http://localhost:8080/v1/chat/completions

完全に OpenAI 互換 → 既存の OpenAI SDK コードをそのまま使用可
```

### 自分株式会社での活用可能性
```
1. 開発チームへの LLM 配布
   単一ファイルなので USB で配布 / Slack で共有可能
   → 開発環境セットアップの手間ゼロ

2. CI/CD でのAIテスト
   GitHub Actions: llamafile をダウンロード → テスト実行
   → セットアップスクリプト不要

3. AI大学コンテンツ:
   「インストール不要でLLMを動かすLlamaFileの仕組みと使い方」
   「Cosmopolitan libc が実現するポータブルAIの技術解説」
   技術的に面白いトピックで検索需要あり

4. プロトタイプ配布:
   「自分株式会社AI機能のオフライン版」を単一ファイルで配布
   → 将来のPC版クライアントの選択肢$$,
  NULL,
  NULL,
  1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'llamafile',
  'api',
  'LlamaFile API — OpenAI互換サーバー / Python/TypeScript統合 / バッチ処理 / CI/CD統合',
  $$## LlamaFile API / 統合ガイド

### 起動とAPIアクセス

```bash
# ダウンロード & 実行 (macOS / Linux)
wget https://huggingface.co/Mozilla/Mistral-7B-Instruct-v0.2-llamafile/resolve/main/mistral-7b-instruct-v0.2.Q4_K_M.llamafile
chmod +x mistral-7b-instruct-v0.2.Q4_K_M.llamafile

# サーバーモードで起動
./mistral-7b-instruct-v0.2.Q4_K_M.llamafile \
  --server \
  --host 0.0.0.0 \
  --port 8080 \
  --nobrowser \
  -c 4096          # コンテキスト長
  -t 8             # スレッド数 (CPUコア数に合わせる)

# GPU加速 (NVIDIA)
./model.llamafile --server --n-gpu-layers 35

# Windows の場合 (.exe 拡張子を追加)
# model.llamafile → model.llamafile.exe にリネームしてダブルクリック
```

### Python (openai SDK)
```python
from openai import OpenAI

# LlamaFile の OpenAI互換エンドポイント
client = OpenAI(
    base_url="http://localhost:8080/v1",
    api_key="llamafile",  # ダミーキー
)

def chat(prompt: str, system: str = "") -> str:
    messages = []
    if system:
        messages.append({"role": "system", "content": system})
    messages.append({"role": "user", "content": prompt})

    response = client.chat.completions.create(
        model="LlamaFile",  # モデル名は任意
        messages=messages,
        temperature=0.7,
        max_tokens=512,
    )
    return response.choices[0].message.content

# バッチ処理例 (大量テキストの分類)
import asyncio
from openai import AsyncOpenAI

async_client = AsyncOpenAI(
    base_url="http://localhost:8080/v1",
    api_key="llamafile",
)

async def classify_text(text: str) -> str:
    """テキストをカテゴリに分類"""
    response = await async_client.chat.completions.create(
        model="LlamaFile",
        messages=[{
            "role": "user",
            "content": f"以下のテキストを「ポジティブ/ネガティブ/中立」のいずれかで分類してください。回答は1単語のみ。\n\n{text}",
        }],
        max_tokens=10,
    )
    return response.choices[0].message.content.strip()

async def batch_classify(texts: list[str]) -> list[str]:
    """複数テキストを並列分類"""
    tasks = [classify_text(t) for t in texts]
    return await asyncio.gather(*tasks)

# 使用例
texts = ["素晴らしい製品です！", "使いにくい", "普通です"]
results = asyncio.run(batch_classify(texts))
```

### TypeScript / Node.js
```typescript
import OpenAI from "openai";

const client = new OpenAI({
  baseURL: "http://localhost:8080/v1",
  apiKey: "llamafile",
});

async function summarize(document: string): Promise<string> {
  const response = await client.chat.completions.create({
    model: "LlamaFile",
    messages: [
      {
        role: "system",
        content: "与えられた文書を3行以内で要約してください。",
      },
      { role: "user", content: document },
    ],
    max_tokens: 200,
  });
  return response.choices[0].message.content ?? "";
}
```

### CI/CD統合 (GitHub Actions)
```yaml
# .github/workflows/ai-test.yml
# LlamaFile を使ったAI機能の自動テスト

name: AI Integration Test

on: [push, pull_request]

jobs:
  ai-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Download LlamaFile
        run: |
          wget -q https://huggingface.co/.../phi-3-mini.llamafile -O model.llamafile
          chmod +x model.llamafile

      - name: Start LlamaFile Server
        run: ./model.llamafile --server --nobrowser -t 4 &
        # バックグラウンドで起動

      - name: Wait for Server
        run: |
          for i in $(seq 1 30); do
            curl -sf http://localhost:8080/health && break
            sleep 2
          done

      - name: Run AI Tests
        run: python tests/test_ai_features.py
        env:
          AI_BASE_URL: http://localhost:8080/v1
          AI_API_KEY: llamafile
```

### llamacpp互換コマンドラインオプション
```bash
# 主要オプション
./model.llamafile \
  --server           # サーバーモード
  --host 0.0.0.0     # 全IPで接続受付
  --port 8080        # ポート
  --nobrowser        # ブラウザ自動起動を無効
  -c 8192            # コンテキスト長 (長いほどVRAM使用)
  -n 512             # 最大生成トークン数
  -t 4               # CPUスレッド数
  --n-gpu-layers 99  # GPU に乗せるレイヤー数 (全てGPUの場合)
  --temp 0.7         # 温度パラメータ
  --top-p 0.9        # Top-P サンプリング
  --repeat-penalty 1.1  # 繰り返しペナルティ
```$$,
  NULL,
  NULL,
  2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'llamafile',
  'models',
  'LlamaFile 技術詳細 — Cosmopolitan libc / APEフォーマット / Mozilla.ai戦略 / ローカルAIエコシステム比較',
  $$## LlamaFile 技術詳細

### Cosmopolitan libc の深層

```
[なぜ1バイナリで全OS動作するのか]

通常のコンパイル:
  gcc main.c -o main        # Linux ELF
  cl main.c -o main.exe     # Windows PE
  clang main.c -o main      # macOS Mach-O
  → OS毎に別々のバイナリ / クロスコンパイルが複雑

Cosmopolitan libc でのコンパイル:
  cosmocc main.c -o main.com  # APE (Actually Portable Executable)
  → 1バイナリが全OSで動作

[APE フォーマットの仕組み]
APEファイル = 複数フォーマットを1ファイルに内包する"ポリグロット"

ファイル先頭 (MZ ヘッダー):
  Windows: ".exe" として認識 → PE ローダーが起動
  → ファイル内の x86-64 Windows コードを実行

macOS:
  fat binary ヘッダーを埋め込み
  → macOS の Mach-O ローダーが対応部分を実行

Linux:
  ELF ヘッダーを内包 OR シェルスクリプトとして起動
  → #!/bin/sh でシェルが ELF 部分を抽出して実行

FreeBSD / OpenBSD:
  同様の仕組みで各OS固有コードを内包
```

### LlamaFile = APE + Zip + GGUF

```
[LlamaFile の内部構造]

.llamafile ファイルは "Zip ファイル" でもある:

バイト位置 0-N: APE 実行ファイル (llamacpp ランタイム)
バイト位置 N+1〜末尾: Zip アーカイブ
  └── model.gguf  ← LLMのモデルウェイト (数GB)
  └── metadata.json

なぜ Zip 形式か:
  OS のローダーは先頭バイトから読む → APE として実行
  Zip ツールは末尾から Zip ヘッダーを探す → モデルを抽出可能
  → 1ファイルが "実行ファイル" かつ "Zipアーカイブ" として機能

実際のファイルサイズ:
  phi-3-mini Q4 (3.8B) → 約2.4GB
  mistral-7b Q4      → 約4.4GB
  llava-v1.5-7b Q4   → 約4.7GB (画像モデル)
```

### Mozilla.ai 戦略

```
[Mozilla がLlamaFileに投資する背景]

Mozilla の理念:
  「インターネットは特定企業に支配されるべきでない」
  → Firefox: ブラウザ市場の多様性を維持
  → Mozilla.ai: AI市場の多様性を維持

問題意識:
  現在の生成AI: OpenAI / Google / Anthropic / Meta の寡占
  → APIを通じてのみAIにアクセス = クラウド依存
  → プライバシーリスク / 単一障害点 / 価格支配リスク

LlamaFile の位置付け:
  「誰でも自分のデバイスでAIを実行できる」
  = ブラウザと同じ分散モデルをAIにも

Mozilla.ai の他のプロジェクト:
  - LlamaFile: ローカルLLM配布
  - Local AI: ブラウザ内AIの研究
  - Llamabot: AIチャットボットフレームワーク
```

### ローカルAIエコシステム比較

| 項目 | LlamaFile | Ollama | LM Studio | Jan.ai | Open WebUI |
|------|-----------|--------|-----------|--------|------------|
| インストール | ✅ 不要 | 必要 | 必要 | 必要 | Docker必要 |
| チームUI | ❌ | ❌ | ❌ | ❌ | ✅ |
| OpenAI互換API | ✅ | ✅ | ✅ | ✅ | ✅ |
| モデル管理 | ❌ | ✅ | ✅ | ✅ | ✅ (経由) |
| エッジデプロイ | ✅ 最強 | △ | ❌ | ❌ | ❌ |
| CI/CD利用 | ✅ 最適 | ✅ | ❌ | ❌ | ❌ |
| ライセンス | Apache 2.0 | MIT | プロプライエタリ | AGPL | MIT |
| GPU加速 | ✅ | ✅ | ✅ | ✅ | 経由 |

### 自分株式会社との関連性

```
技術的な面白さ:
  「1つのファイルに4つのOS向けバイナリとGBのモデルが入っている」
  → エンジニアが「すごい！」と思うコンテンツ
  → Zenn/Qiita での拡散が見込まれる

活用シナリオ:
  1. AI大学コンテンツのデモ動画:
     1ファイルダウンロード → 即実行 の様子をキャプチャ
     → 「こんなに簡単にローカルLLMが動く」ビジュアル訴求

  2. 開発環境配布:
     チームメンバーへのAIツール導入障壁ゼロ
     「このファイルを実行するだけ」で全員が同じLLMを使える

  3. Supabase EF テスト:
     CI/CD で LlamaFile を起動 → Edge Function の AI レスポンスをテスト
     → 本番 OpenAI API に頼らないテスト環境

  4. 技術ブログのネタ:
     「Mozilla と Meta が共同開発した LlamaFile の技術解説」
     Cosmopolitan libc の面白さ → バイナリ芸術として注目度高
```$$,
  NULL,
  NULL,
  3
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 249→250社化: LlamaFile 追加',
  'PS#3 S77。LlamaFile (Mozilla+Meta/単一実行ファイルLLM/Cosmopolitan libc/APEフォーマット/インストール不要/全OS対応/GitHub 20k+/エッジAI/CI/CD統合最適/Apache 2.0/8/9) を ai_university_content に追加。',
  '2026-04-27'
)
ON CONFLICT DO NOTHING;
