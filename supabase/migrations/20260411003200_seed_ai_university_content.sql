-- AI大学 初期コンテンツシード (2026-04-11)
-- 6大AIプロバイダーの概要・モデル・API・活用事例を収録
-- Claude Schedule ai-university-update タスクが毎週上書き更新する

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order) VALUES

-- ══════════════════════════════════════════════
--  Google (Gemini 系)
-- ══════════════════════════════════════════════
('google', 'overview', 'Google AI 概要',
$$Googleが提供するAI群。**Gemini**シリーズをフラッグシップに、検索・Workspace・Cloud全体に統合されています。

## 主要サービス
- **Gemini**: Google DeepMindのマルチモーダルLLM
- **Google AI Studio**: APIを無料で試せる開発者向けツール
- **Vertex AI**: GCPのエンタープライズAIプラットフォーム
- **NotebookLM**: ドキュメント特化型AIリサーチツール

## 強み
- 圧倒的なロングコンテキスト（最大200万トークン）
- Googleエコシステム（検索・Maps・Gmail・Docs）との統合
- 動画・音声・画像・テキストの真のマルチモーダル$$,
'https://ai.google.dev/', '2026-01-01', 1),

('google', 'models', 'Gemini モデル一覧 (2026)',
$$## Gemini 2.5 シリーズ (最新世代)

| モデル | 入力 | 出力 | Thinking | 用途 |
| :--- | :--- | :--- | :--- | :--- |
| **Gemini 2.5 Pro** | 100万 token | 65,536 | ✅ | 高精度推論・長文処理 |
| **Gemini 2.5 Flash** | 100万 token | 65,536 | ✅ | 高速・コスパ重視 |
| **Gemini 2.0 Flash** | 100万 token | 8,192 | ❌ | 旧世代・安定版 |

## 特徴
- **Thinking モード**: 回答前に推論プロセスを経て精度向上
- **コード実行**: Python コードをサンドボックス内で実行
- **Google検索グラウンディング**: リアルタイム情報取得$$,
'https://ai.google.dev/models/gemini', '2026-01-21', 2),

('google', 'api', 'Google AI API 入門',
$$## Gemini API の始め方

```python
import google.generativeai as genai

genai.configure(api_key="YOUR_API_KEY")
model = genai.GenerativeModel("gemini-2.5-flash")
response = model.generate_content("AIとは何ですか？")
print(response.text)
```

## 料金 (2026年1月時点)
- **無料枠**: 毎日15リクエスト / 100万token
- **Flash 1.5**: $0.075 / 100万入力token
- **Pro 2.5**: $1.25 / 100万入力token$$,
'https://ai.google.dev/pricing', '2026-01-01', 3),

-- ══════════════════════════════════════════════
--  OpenAI (GPT / o1 / Sora 系)
-- ══════════════════════════════════════════════
('openai', 'overview', 'OpenAI 概要',
$$AIの産業化をリードする企業。**ChatGPT**で一般普及を実現し、**GPT-4o**/**o1**シリーズで技術フロンティアを塗り替えています。

## 主要サービス
- **ChatGPT**: 世界最大のAIチャットサービス（月間1億ユーザー超）
- **GPT-4o**: マルチモーダルフラッグシップモデル
- **o1 / o3**: 推論特化（math/coding/science で人間専門家超え）
- **DALL-E 3**: テキストから画像生成
- **Sora**: テキストから動画生成
- **Whisper**: 音声認識・翻訳

## 強み
- 最大のエコシステムとサードパーティ連携
- Function Calling / Structured Output が業界標準
- APIドキュメントの充実度$$,
'https://platform.openai.com/', '2026-01-01', 1),

('openai', 'models', 'GPT・o1 モデル一覧 (2026)',
$$## 主要モデル比較

| モデル | コンテキスト | 推論 | 速度 | 用途 |
| :--- | :--- | :--- | :--- | :--- |
| **o3** | 200K | ★★★★★ | 遅い | 数学・科学・コード |
| **o3-mini** | 200K | ★★★★ | 中速 | コスパ推論 |
| **GPT-4o** | 128K | ★★★★ | 高速 | 汎用・マルチモーダル |
| **GPT-4o mini** | 128K | ★★★ | 超高速 | 軽量・低コスト |

## o1 / o3 シリーズの特徴
- **Chain of Thought 内蔵**: 回答前に自動で多段推論
- **数学オリンピック金メダル相当**の問題解決能力
- **SWE-bench**: ソフトウェアエンジニアリングベンチマーク最高スコア$$,
'https://platform.openai.com/docs/models', '2026-01-01', 2),

('openai', 'api', 'OpenAI API 入門',
$$## OpenAI API の始め方

```python
from openai import OpenAI
client = OpenAI(api_key="YOUR_API_KEY")

response = client.chat.completions.create(
    model="gpt-4o",
    messages=[{"role": "user", "content": "AIとは何ですか？"}]
)
print(response.choices[0].message.content)
```

## 料金 (2026年1月時点)
- **GPT-4o**: $2.50 / 100万入力token
- **GPT-4o mini**: $0.15 / 100万入力token
- **o3-mini**: $1.10 / 100万入力token$$,
'https://platform.openai.com/pricing', '2026-01-01', 3),

-- ══════════════════════════════════════════════
--  Anthropic (Claude 系)
-- ══════════════════════════════════════════════
('anthropic', 'overview', 'Anthropic 概要',
$$安全性と有益性を両立するAI開発を使命とする企業（元OpenAI研究者が設立）。**Claude**シリーズは文章品質・コーディング・長文処理で高い評価を得ています。

## 主要製品
- **Claude 3.5 Sonnet**: バランス型フラッグシップ（コーディング最強クラス）
- **Claude 3.5 Haiku**: 高速・低コスト
- **Claude 3 Opus**: 複雑な推論・分析
- **Claude.ai**: 一般向けチャットインターフェース
- **Claude Code**: AIコーディングエージェント（本アプリ開発に使用！）

## 強み
- **Constitutional AI**: 安全性を設計段階から組み込む手法
- 自然で人間的な文章出力
- コーディング能力（SWE-bench 上位）
- 20万トークンのコンテキスト（Standard）$$,
'https://docs.anthropic.com/', '2026-01-01', 1),

('anthropic', 'models', 'Claude モデル一覧 (2026)',
$$## Claude 3.5 シリーズ (最新世代)

| モデル | コンテキスト | 速度 | 用途 |
| :--- | :--- | :--- | :--- |
| **Claude 3.5 Sonnet** | 200K | 中速 | コード・分析・創作 |
| **Claude 3.5 Haiku** | 200K | 超高速 | 軽量タスク・チャット |
| **Claude 3 Opus** | 200K | 低速 | 複雑な多段推論 |

## 特徴的な機能
- **Artifacts**: コード・SVG・HTMLをリアルタイムプレビュー
- **Projects**: 長期的なコンテキスト保持
- **Computer Use (beta)**: PCを自律操作するエージェント機能
- **Tool Use**: 関数呼び出し・JSON出力の高い精度$$,
'https://docs.anthropic.com/en/docs/about-claude/models', '2026-01-01', 2),

('anthropic', 'api', 'Claude API 入門',
$$## Anthropic API の始め方

```python
import anthropic
client = anthropic.Anthropic(api_key="YOUR_API_KEY")

message = client.messages.create(
    model="claude-3-5-sonnet-20241022",
    max_tokens=1024,
    messages=[{"role": "user", "content": "AIとは何ですか？"}]
)
print(message.content[0].text)
```

## 料金 (2026年1月時点)
- **Claude 3.5 Sonnet**: $3.00 / 100万入力token
- **Claude 3.5 Haiku**: $0.80 / 100万入力token
- **Claude 3 Opus**: $15.00 / 100万入力token$$,
'https://docs.anthropic.com/en/api/', '2026-01-01', 3),

-- ══════════════════════════════════════════════
--  Microsoft (Copilot / Azure OpenAI 系)
-- ══════════════════════════════════════════════
('microsoft', 'overview', 'Microsoft AI 概要',
$$OpenAIに多額投資し、全製品に**Copilot**としてAIを統合。企業向けAI普及のリーダーです。

## 主要サービス
- **Microsoft Copilot**: Windows/Office/Bing に統合されたAIアシスタント
- **Azure OpenAI Service**: エンタープライズ向けGPT-4oホスティング
- **GitHub Copilot**: コード補完AIツール（開発者1億人以上が利用）
- **Copilot Studio**: ノーコードAIエージェント構築ツール
- **Phi-3**: Microsoft独自の小型高効率モデル

## 強み
- **Office 365 完全統合**: Word・Excel・Teams・Outlook に直接組み込み
- **エンタープライズセキュリティ**: データ主権・コンプライアンス対応
- **GitHub Copilot**: 世界最大の開発者向けAIツール$$,
'https://azure.microsoft.com/ai/', '2026-01-01', 1),

('microsoft', 'models', 'Microsoft AI モデル・サービス (2026)',
$$## 主要サービス比較

| サービス | ベースモデル | 対象 | 特徴 |
| :--- | :--- | :--- | :--- |
| **Azure OpenAI** | GPT-4o / o1 | 企業 | プライベート環境でGPT利用 |
| **Copilot** | GPT-4o | 一般・企業 | Office・Bing統合 |
| **GitHub Copilot** | GPT-4 + Codex | 開発者 | コード補完・Chat |
| **Phi-3-mini** | 独自 | 組込み | 低リソース・オンデバイス |
| **Phi-3.5 MoE** | 独自MoE | 軽量推論 | モバイル・エッジ向け |

## GitHub Copilot の実績
- 開発速度 **55% 向上**（GitHub調査）
- コード提案の受け入れ率 **30%以上**$$,
'https://azure.microsoft.com/en-us/products/ai-services/', '2026-01-01', 2),

-- ══════════════════════════════════════════════
--  Meta (LLaMA / Llama 系)
-- ══════════════════════════════════════════════
('meta', 'overview', 'Meta AI 概要',
$$**オープンソースAI**の旗手。**LLaMA**シリーズを無料公開し、AI民主化をリードしています。Facebook・Instagram・WhatsAppへのAI統合も積極展開。

## 主要プロダクト
- **Llama 3.3 / 3.1**: 最高クラスのオープンソースLLM
- **Meta AI**: Facebook・Instagram等のSNS内蔵AIアシスタント
- **Code Llama**: コーディング特化版Llama
- **SAM 2**: 動画内の物体セグメンテーションAI
- **Segment Anything Model**: 汎用画像セグメンテーション

## 強み
- **完全オープンソース**: 商用利用可・自社サーバーにデプロイ可
- **無料**: モデルウェイトが公開
- **カスタマイズ自由**: ファインチューニングで特化型モデル構築
- **プライバシー**: クラウドに送信不要のオンプレ運用$$,
'https://ai.meta.com/', '2026-01-01', 1),

('meta', 'models', 'Llama モデル一覧 (2026)',
$$## Llama 3 シリーズ

| モデル | パラメータ | コンテキスト | 用途 |
| :--- | :--- | :--- | :--- |
| **Llama 3.3 70B** | 70B | 128K | 最高品質オープンソース |
| **Llama 3.1 405B** | 405B | 128K | 最大規模・GPT-4o同等 |
| **Llama 3.1 8B** | 8B | 128K | 軽量・エッジ向け |
| **Code Llama 70B** | 70B | 100K | コード生成特化 |

## オープンソースの活用方法
```bash
# Ollama でローカル実行
ollama run llama3.3:70b
# Hugging Face で推論
pip install transformers && python -c "from transformers import pipeline; ..."
```$$,
'https://llama.meta.com/', '2026-01-01', 2),

-- ══════════════════════════════════════════════
--  X / xAI (Grok 系)
-- ══════════════════════════════════════════════
('x', 'overview', 'xAI (Grok) 概要',
$$Elon MuskがOpenAI退任後に設立した**xAI**が開発。X(旧Twitter)のリアルタイムデータと連携し、最新情報へのアクセスが強み。

## 主要サービス
- **Grok 3**: xAIのフラッグシップモデル
- **Grok 3 mini**: 軽量推論モデル
- **Grok Vision**: 画像理解機能
- **Aurora**: 画像生成AI
- **X Premium+**: Grokを含む最上位プラン

## 強み
- **リアルタイム情報**: Xのポスト・トレンドに即時アクセス
- **検閲フリーポリシー**: より自由な表現
- **xAI API**: OpenAI互換APIで既存コードからの移行が容易
- **Colossus**: 世界最大規模のGPUクラスター（10万台のH100）$$,
'https://x.ai/', '2026-01-01', 1),

('x', 'models', 'Grok モデル一覧 (2026)',
$$## Grok 3 シリーズ

| モデル | 特徴 | 用途 |
| :--- | :--- | :--- |
| **Grok 3** | 最高性能・思考モード搭載 | 複雑な分析・研究 |
| **Grok 3 mini** | 高速・軽量 | 日常タスク・リアルタイム |
| **Grok 2** | 旧世代・安定版 | 後方互換 |

## xAI API の特徴
```python
# OpenAI SDK で Grok にアクセス可能
from openai import OpenAI
client = OpenAI(api_key="XAI_API_KEY", base_url="https://api.x.ai/v1")
response = client.chat.completions.create(
    model="grok-3",
    messages=[{"role": "user", "content": "最新のAIニュースは？"}]
)
```
- **リアルタイム検索**: X上の最新投稿を参照
- **ベンチマーク**: MATH・GPQA で GPT-4o を上回る$$,
'https://docs.x.ai/', '2026-01-01', 2)

ON CONFLICT DO NOTHING;
