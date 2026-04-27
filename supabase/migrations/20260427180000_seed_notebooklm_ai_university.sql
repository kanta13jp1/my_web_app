-- PS#3 S76: AI大学 246→247社化 — Google NotebookLM 追加
-- Google NotebookLM: AIリサーチツール / ソースグラウンディング / Audio Overview / Deep Research / 無料

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'notebooklm',
  'overview',
  'Google NotebookLM — AIリサーチ・ノートツール (ソースグラウンディング / Audio Overview / Deep Research / 無料)',
  $$## Google NotebookLM — AI Powered Research & Note Taking

**カテゴリ**: AI Research Tool / Knowledge Management / Document Analysis / Podcast Generation
**開発元**: Google Labs / Google DeepMind
**本社**: Mountain View, California (Google LLC)
**リリース**: 2023年7月 (限定ベータ) → 2023年12月 (一般公開) → 2024年 グローバル展開
**モデル**: Gemini 1.5 Pro (長文コンテキスト対応)
**価格**: 無料 (Googleアカウント) / NotebookLM Plus (有料)
**日本語対応**: ✅ (2024年〜)
**評価**: 9/9

### 概要
Google NotebookLM は **「アップロードしたソースだけに基づいて回答する」** AIリサーチツール。ChatGPT との最大の違いは **ソースグラウンディング** — LLM の学習データではなく、ユーザーが指定した文書・URL・動画のみを参照して回答するため、ハルシネーションを大幅に抑制できる。

**革命的機能 "Audio Overview"**: 複数の文書を自動的に10〜20分のポッドキャスト対話形式に変換。2024年に登場してから世界中で話題になり、教育・ビジネス用途での採用が急増。日本語版も2024年に対応。

**自分株式会社での実用**: このプロジェクトでは `jibun-master-brain` ノートブックに全セッションの知見を蓄積し、NotebookLM を「プロジェクト横断メモリ」として活用中。

### 主要機能

**1. ソース (情報源) 管理**
```
対応ソース形式:
  ✅ PDF / テキストファイル
  ✅ Google ドキュメント / スプレッドシート
  ✅ Google スライド
  ✅ Web URL (スクレイピング)
  ✅ YouTube 動画 (字幕から)
  ✅ 音声ファイル (MP3/WAV)
  ✅ コピー&ペーストテキスト

制限:
  無料: ノートブック 100 個 / ソース 50 個/ノートブック
  Plus: ノートブック 500 個 / ソース 300 個/ノートブック
```

**2. ノートブックガイド (自動生成)**
| 機能 | 内容 |
|------|------|
| 要約 | ソース全体の簡潔なサマリー |
| FAQ | よくある質問と回答を自動生成 |
| 勉強ガイド | 重要概念のリスト / 小テスト形式 |
| タイムライン | 時系列イベントを自動抽出 |
| ブリーフィング文書 | エグゼクティブサマリー形式 |
| マインドマップ | 概念の関係図 (2024〜) |

**3. Audio Overview (ポッドキャスト生成)**
```
[仕組み]
ソース文書 (複数可)
    ↓ Gemini が内容を分析
2人の会話形式スクリプトを生成
    ↓ Google Text-to-Speech (自然な音声)
10〜20分のポッドキャスト音声を出力

[特徴]
  - 2人の司会者が対話形式で内容を解説
  - 専門用語をわかりやすく噛み砕いて説明
  - 聴衆の質問に回答するシーンも挿入
  - 日本語ソース → 日本語ポッドキャスト生成可能
  - ダウンロード可能 (MP3)

[活用例]
  - 長い論文を通勤中に音声で学習
  - 会議資料を事前にポッドキャストで把握
  - 競合調査レポートを音声でブリーフィング
```

**4. Deep Research (Web リサーチ)**
```
[2024年追加の機能]
指定したトピック → NotebookLM が Web を自律的に調査
    ↓
  収集ページ数: 〜数百ページ (自動)
  調査時間: 5〜20分
  出力: 構造化レポート + 引用リスト
    ↓
ノートブックに追加してさらに質問可能

[用途]
  - 競合21社の最新動向調査
  - 技術トレンドの網羅的リサーチ
  - 投資先企業の情報収集
  - 学術論文の先行研究調査
```

**5. ソースグラウンディング (Grounding)**
```
通常のLLM:              NotebookLM:
  学習データで回答          ↑ 指定ソースのみで回答
    ↓                        ↓
  ハルシネーションリスク高    回答に必ず出典を添付
  過去情報で回答            最新情報をソースで補完
  機密データを学習リスク      機密文書をアップしても安全
```

### 価格
| プラン | 月額 | ノートブック | ソース数 | 追加機能 |
|--------|------|------------|---------|---------|
| 無料 | $0 | 100 | 50/冊 | 基本機能 |
| NotebookLM Plus | $20 | 500 | 300/冊 | 優先処理 / Analytics / カスタムAudio |
| Google Workspace 追加機能 | 組織料金 | 共有 | — | 管理者制御 |

### 自分株式会社での活用実績
```
実際の使用パターン (jibun-master-brain ノートブック):
  1. 各開発セッション終了後 → memory/project_*.md をソースとして追加
  2. 次のセッション開始時 → "過去の成功パターンは？" と質問
  3. Deep Research → 競合21社の最新動向を定期調査
  4. Audio Overview → 長いドキュメント (ROADMAP/DESIGN.md) を音声で確認
  5. 技術記事執筆 → ソース全体の要約 → ブログのたたき台生成

AI大学コンテンツとしての価値:
  「NotebookLM で研究・学習が革命的に変わる理由」
  「NotebookLM × Supabase でナレッジマネジメントシステムを作る」
  日本でも Google 製品への信頼から普及率が高い
```$$,
  NULL,
  NULL,
  1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'notebooklm',
  'api',
  'Google NotebookLM API — notebooklm-py CLI / Python統合 / Supabase × NotebookLM パイプライン',
  $$## Google NotebookLM API / 統合ガイド

### 概要
NotebookLM には2026年時点で公式REST APIは未提供。実用的な統合手段として **notebooklm-py** (非公式Python CLIラッパー) が広く使われている。

### notebooklm-py CLI (推奨)
```bash
# インストール
pip install "notebooklm-py[browser]"
playwright install chromium

# 初回認証 (Googleアカウント)
notebooklm login

# ノートブック操作
notebooklm create "競合リサーチ 2026"
notebooklm list

# ソース追加
notebooklm source add "./docs/competitor_report.pdf"
notebooklm source add "https://techcrunch.com/article/..."
notebooklm source add --type youtube "https://youtube.com/watch?v=..."

# 質問
notebooklm ask "競合3社の主な差別化要素は何か？"

# 成果物生成
notebooklm generate audio "主要テーマを深掘りするポッドキャスト" --wait
notebooklm generate slide-deck "エグゼクティブ向けプレゼン"
notebooklm generate mind-map

# Deep Research
notebooklm source add-research "2026年の生成AI市場トレンド"
notebooklm research wait
notebooklm ask "調査結果の要点を3つ挙げて"
```

### Python スクリプト統合
```python
import subprocess
import json
import os

def notebooklm_ask(notebook_title: str, question: str) -> str:
    """NotebookLM に質問して回答を取得"""
    # ノートブック選択
    subprocess.run(["notebooklm", "use", notebook_title], check=True)

    # 質問
    result = subprocess.run(
        ["notebooklm", "ask", question, "--format", "json"],
        capture_output=True,
        text=True,
        encoding="utf-8",
    )
    data = json.loads(result.stdout)
    return data.get("answer", "")

def add_source_and_query(pdf_path: str, question: str) -> str:
    """PDFをアップして質問"""
    subprocess.run(["notebooklm", "source", "add", pdf_path], check=True)
    return notebooklm_ask("default", question)

# 使用例: 週次競合レポートを自動生成
def generate_weekly_competitor_report(urls: list[str]) -> str:
    """競合URLを追加して週次レポートを生成"""
    for url in urls:
        subprocess.run(["notebooklm", "source", "add", url], check=True)

    result = subprocess.run(
        ["notebooklm", "ask",
         "今週の競合各社の主要アップデートを箇条書きでまとめて"],
        capture_output=True,
        text=True,
        encoding="utf-8",
    )
    return result.stdout
```

### Supabase × NotebookLM パイプライン
```typescript
// GHA / Supabase EF から notebooklm CLI を呼び出すパターン
// (Node.js / Deno 環境では child_process / Deno.Command を使用)

// Node.js版
import { execSync } from "child_process";

function askNotebookLM(question: string): string {
  const result = execSync(
    `notebooklm ask "${question.replace(/"/g, '\\"')}"`,
    { encoding: "utf-8" },
  );
  return result.trim();
}

// GitHub Actions ワークフローでの使用例
// .github/workflows/weekly-ai-research.yml
// steps:
//   - name: NotebookLM Deep Research
//     run: |
//       notebooklm use jibun-master-brain
//       notebooklm source add-research "生成AI業界 週次ニュース"
//       notebooklm research wait
//       notebooklm ask "今週の重要ニューストップ5は？" > research_summary.txt
//   - name: Save to Supabase
//     run: python scripts/save_research_to_supabase.py research_summary.txt
```

### Audio Overview 活用パターン
```python
import subprocess
import time

def create_audio_overview(sources: list[str], prompt: str, output_path: str) -> str:
    """複数ソースからポッドキャスト音声を生成"""
    # ソースを追加
    for source in sources:
        subprocess.run(["notebooklm", "source", "add", source], check=True)

    # Audio Overview 生成 (非同期)
    subprocess.run(
        ["notebooklm", "generate", "audio", prompt],
        check=True,
    )

    # 完了を待機 (最大10分)
    for _ in range(60):
        result = subprocess.run(
            ["notebooklm", "download", "audio", "--path", output_path],
            capture_output=True,
        )
        if result.returncode == 0:
            return output_path
        time.sleep(10)

    raise TimeoutError("Audio generation timed out")

# 使用例: DESIGN.md を音声化
create_audio_overview(
    sources=["docs/DESIGN.md", "docs/PHILOSOPHY.md"],
    prompt="デザインシステムと開発哲学を開発者向けに解説するポッドキャスト",
    output_path="./audio/design_overview.mp3",
)
```$$,
  NULL,
  NULL,
  2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'notebooklm',
  'models',
  'Google NotebookLM 技術詳細 — Gemini 1.5 Pro統合 / RAGアーキテクチャ / Audio Overview生成技術 / 競合比較',
  $$## Google NotebookLM 技術詳細

### バックエンド: Gemini 1.5 Pro

```
[NotebookLM の技術構成]

フロントエンド: React (Google Labs カスタム)
      ↓
バックエンド: Google Cloud (非公開)
  ├── 文書処理: PDF → テキスト抽出 (Document AI)
  ├── 埋め込み: text-embedding-004 (768次元)
  ├── ベクターDB: Google Vector Search (Matching Engine)
  ├── LLM: Gemini 1.5 Pro (最大100万トークンコンテキスト)
  └── 音声合成: WaveNet / Neural2 (TTS)
      ↓
ソースグラウンディング: 全ての回答に出典リンク付与
```

### RAGアーキテクチャ

```
[NotebookLM の RAG パイプライン]

1. ソース取り込み
   PDF → Google Document AI → テキスト抽出
   YouTube → 字幕API → テキスト化
   URL → ウェブスクレイピング → クリーニング

2. チャンク分割
   意味的な段落単位でチャンク化 (固定長ではなく意味論的)
   各チャンクにページ番号・段落番号をメタデータとして付与

3. 埋め込みベクター化
   Google text-embedding-004 で 768次元ベクターに変換

4. クエリ処理
   ユーザー質問 → クエリ拡張 (HyDE / 多角的クエリ生成)
   → ベクター検索 + BM25 ハイブリッド検索
   → TOP-K チャンク取得

5. 回答生成
   [プロンプト構造]
   SYSTEM: 提供されたソースのみに基づいて回答してください
   CONTEXT: {TOP-K チャンクの内容}
   SOURCE_METADATA: {各チャンクの出典情報}
   QUESTION: {ユーザーの質問}
   → Gemini 1.5 Pro で回答 + 出典リンクを自動付与

6. ソースグラウンディング
   回答の各文に対応するソース箇所をハイライト表示
   → ハルシネーション検出が容易
```

### Audio Overview 生成技術

```
[Audio Overview のパイプライン]

Step 1: コンテンツ分析
  全ソース文書 → Gemini でキーポイント抽出
  → テーマ分類 / 重要度スコアリング

Step 2: スクリプト生成
  Gemini が2人の会話形式スクリプトを生成
  登場人物: Host A (説明役) / Host B (質問役・聴衆代理)
  構成: イントロ → テーマ解説 → 具体例 → まとめ

Step 3: 音声合成
  Google WaveNet / Neural2 で自然な音声を生成
  ピッチ・速度・感情表現を自動調整
  Host A と Host B で異なる声質

Step 4: 後処理
  BGM / 効果音は含まない (シンプルな対話形式)
  MP3 形式でダウンロード可能 (〜20MB/20分)
```

### 競合比較

| 項目 | NotebookLM | Perplexity | Elicit | ChatGPT w/Files | Claude Projects |
|------|-----------|-----------|-------|----------------|----------------|
| ソースグラウンディング | ✅ 最強 | △ | ✅ 学術特化 | △ | △ |
| Audio Overview | ✅ 独自 | ❌ | ❌ | ❌ | ❌ |
| Deep Research | ✅ (2024〜) | ✅ | ❌ | ❌ | ❌ |
| ソース数 | 300/冊 (Plus) | — | 8/プロジェクト | △ | △ |
| 日本語対応 | ✅ | ✅ | △ | ✅ | ✅ |
| 無料利用 | ✅ 充実 | ✅ | ✅ | △ | △ |
| 価格 | 無料〜$20 | 無料〜$20 | 無料〜$12 | ChatGPT Plus | Claude Pro |

### 自分株式会社との関連性

```
実際の活用価値 (本プロジェクト実績):

1. 「jibun-master-brain」ノートブック運用
   - 全セッションの memory/*.md を蓄積
   - "過去の技術的意思決定は？" → 横断検索
   - セッション間の設計一貫性を保証

2. 競合21社調査の効率化
   - 競合21社の公式ブログ/プレスリリースをソースに追加
   - "Notionの最新AI機能を教えて" → 即座に最新情報
   - Deep Research で競合の新機能を自動収集

3. AI大学コンテンツ生成の補助
   - 追加したいAIプロバイダーの文書をNotebookLMに投入
   - "日本のエンジニア向けに解説文を書いて" → たたき台生成
   - Claude Code で refinement → SQL化 → migration

4. ブログ記事制作フロー
   - ソース (競合記事/論文/自社ROADMAP) → NotebookLM
   - "JA/ENブログ記事のアウトライン生成" → 構成案
   - T-1 dispatch ワークフローへ流し込み
```$$,
  NULL,
  NULL,
  3
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 246→247社化: Google NotebookLM 追加',
  'PS#3 S76。Google NotebookLM (AIリサーチツール/ソースグラウンディング/Audio Overviewポッドキャスト生成/Deep Research/Gemini 1.5 Pro/無料/日本語対応/自分株式会社でjibun-master-brainとして実運用/9/9) を ai_university_content に追加。',
  '2026-04-27'
)
ON CONFLICT DO NOTHING;
