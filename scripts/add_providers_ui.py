#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Add 17 missing providers to gemini_university_v2_page.dart"""

import re

FILE = "lib/pages/gemini_university_v2_page.dart"
content = open(FILE, encoding="utf-8").read()

# ─── 1. _providerMeta entries ───────────────────────────────────────────────

NEW_META = """  'ai21': _ProviderMeta(
    name: 'AI21 Labs',
    emoji: '🧬',
    color: const Color(0xFF1E40AF),
    officialUrl: 'https://docs.ai21.com/',
  ),
  'aleph_alpha': _ProviderMeta(
    name: 'Aleph Alpha',
    emoji: '🇩🇪',
    color: const Color(0xFF1A1A2E),
    officialUrl: 'https://docs.aleph-alpha.com/',
  ),
  'baidu': _ProviderMeta(
    name: 'Baidu ERNIE',
    emoji: '🔴',
    color: const Color(0xFF2932E1),
    officialUrl: 'https://cloud.baidu.com/',
  ),
  'elevenlabs': _ProviderMeta(
    name: 'ElevenLabs',
    emoji: '🎙️',
    color: const Color(0xFF1A1A1A),
    officialUrl: 'https://elevenlabs.io/docs',
  ),
  'fireworks_ai': _ProviderMeta(
    name: 'Fireworks AI',
    emoji: '🎆',
    color: const Color(0xFFFF6B00),
    officialUrl: 'https://docs.fireworks.ai/',
  ),
  'ideogram': _ProviderMeta(
    name: 'Ideogram AI',
    emoji: '🖼️',
    color: const Color(0xFF6B21A8),
    officialUrl: 'https://developer.ideogram.ai/',
  ),
  'ollama': _ProviderMeta(
    name: 'Ollama',
    emoji: '🦙',
    color: const Color(0xFF1A1A1A),
    officialUrl: 'https://ollama.com/',
  ),
  'openrouter': _ProviderMeta(
    name: 'OpenRouter',
    emoji: '🔀',
    color: const Color(0xFF6240C8),
    officialUrl: 'https://openrouter.ai/docs',
  ),
  'oracle': _ProviderMeta(
    name: 'Oracle',
    emoji: '🔴',
    color: const Color(0xFFC74634),
    officialUrl: 'https://www.oracle.com/artificial-intelligence/',
  ),
  'reka': _ProviderMeta(
    name: 'Reka',
    emoji: '⚡',
    color: const Color(0xFF6C47FF),
    officialUrl: 'https://docs.reka.ai/quick-start',
  ),
  'replicate': _ProviderMeta(
    name: 'Replicate',
    emoji: '🔄',
    color: const Color(0xFF0F0F0F),
    officialUrl: 'https://replicate.com/docs',
  ),
  'runway': _ProviderMeta(
    name: 'Runway',
    emoji: '🎬',
    color: const Color(0xFF0F0F0F),
    officialUrl: 'https://docs.runwayml.com/',
  ),
  'suno': _ProviderMeta(
    name: 'Suno AI',
    emoji: '🎵',
    color: const Color(0xFF1C1C2E),
    officialUrl: 'https://suno.com/',
  ),
  'together_ai': _ProviderMeta(
    name: 'Together AI',
    emoji: '🤝',
    color: const Color(0xFF0066CC),
    officialUrl: 'https://docs.together.ai/',
  ),
  'udio': _ProviderMeta(
    name: 'Udio',
    emoji: '🎸',
    color: const Color(0xFF1A1A2E),
    officialUrl: 'https://www.udio.com/',
  ),
  'voyage': _ProviderMeta(
    name: 'Voyage AI',
    emoji: '⚓',
    color: const Color(0xFF0F4C81),
    officialUrl: 'https://docs.voyageai.com/',
  ),
  'writer': _ProviderMeta(
    name: 'Writer',
    emoji: '✍️',
    color: const Color(0xFF7C3AED),
    officialUrl: 'https://dev.writer.com/docs',
  ),"""

# Insert before the closing }; of _providerMeta
# Marker: the last entry before };
META_MARKER = "  'sakana': _ProviderMeta(\n    name: 'Sakana AI',\n    emoji: '🐟',\n    color: const Color(0xFF00B4D8),\n    officialUrl: 'https://huggingface.co/SakanaAI',\n  ),\n};"
META_REPLACEMENT = "  'sakana': _ProviderMeta(\n    name: 'Sakana AI',\n    emoji: '🐟',\n    color: const Color(0xFF00B4D8),\n    officialUrl: 'https://huggingface.co/SakanaAI',\n  ),\n" + NEW_META + "\n};"

if META_MARKER not in content:
    print("ERROR: _providerMeta marker not found")
    exit(1)
content = content.replace(META_MARKER, META_REPLACEMENT, 1)

# ─── 2. _quizzes entries ────────────────────────────────────────────────────

NEW_QUIZZES = """  'ai21': _Quiz(
    question: 'Jamba のアーキテクチャが革新的な理由は何ですか？',
    options: ['SSM と Transformer を融合しO(n)の線形計算量で長文処理', '世界最大のパラメータ数', '画像生成に特化した設計', '量子コンピュータを活用'],
    correct: 0,
  ),
  'aleph_alpha': _Quiz(
    question: 'Aleph Alpha が開発した「説明可能AI」技術の名称は？',
    options: ['AtMan', 'SHAP', 'LIME', 'Grad-CAM'],
    correct: 0,
  ),
  'baidu': _Quiz(
    question: 'Baidu の AI チャットサービス ERNIE Bot の中国語名は？',
    options: ['文心一言', '通义千问', '讯飞星火', '混元'],
    correct: 0,
  ),
  'elevenlabs': _Quiz(
    question: 'ElevenLabs の Eleven Turbo v2.5 の主な特徴は？',
    options: ['低レイテンシ (<250ms) でリアルタイムAI音声に最適', '最高音質の有声本生成専用', '音声認識特化', '画像から音声生成'],
    correct: 0,
  ),
  'fireworks_ai': _Quiz(
    question: 'Fireworks AI が特に強みとする点は？',
    options: ['業界最高水準の推論速度 (150+ tokens/秒)', '最多モデル数', '最安値料金', '独自LLM'],
    correct: 0,
  ),
  'ideogram': _Quiz(
    question: 'Ideogram AI が他の画像生成AIと比べて特に優れている点は？',
    options: ['画像内のテキスト (文字) を正確に生成できる', '動画から静止画を抽出', 'リアルタイム画像ストリーミング', '音声から画像を生成'],
    correct: 0,
  ),
  'ollama': _Quiz(
    question: 'Ollama の最大のメリットは？',
    options: ['データが外部送信されず完全ローカル実行 → プライバシー保護 + API料金ゼロ', 'クラウドで最新GPT-4より高精度', 'リアルタイムWeb検索', '1秒以内の超高速レスポンス保証'],
    correct: 0,
  ),
  'openrouter': _Quiz(
    question: 'OpenRouter の API は既存のどの SDK と互換性がある？',
    options: ['OpenAI SDK (base_url変更のみ)', 'LangChain専用SDK', 'Anthropic SDKのみ', '独自SDK'],
    correct: 0,
  ),
  'oracle': _Quiz(
    question: 'Oracle Database 23ai でベクトル検索を実行する際に使う関数は？',
    options: ['VECTOR_DISTANCE()', 'COSINE_SEARCH()', 'AI_SEARCH()', 'EMBED_QUERY()'],
    correct: 0,
  ),
  'reka': _Quiz(
    question: 'Reka のモデルが他の主要 LLM と大きく異なるマルチモーダル能力とは？',
    options: ['動画ファイルを直接入力して理解できる', 'リアルタイム音声合成', '3Dモデル生成', 'オンライン学習'],
    correct: 0,
  ),
  'replicate': _Quiz(
    question: 'Replicate で自分のカスタムモデルをデプロイするツールは？',
    options: ['cog', 'docker-compose', 'kubectl', 'terraform'],
    correct: 0,
  ),
  'runway': _Quiz(
    question: 'Runway Gen-3 Alpha の最大動画生成時間は？',
    options: ['最大10秒 (4K解像度)', '最大60秒 (1080p)', '最大5秒 (720p)', '無制限'],
    correct: 0,
  ),
  'suno': _Quiz(
    question: 'Suno AI で生成される楽曲に含まれるものは？',
    options: ['ボーカル・伴奏・ミックス・マスタリングが全て含まれる完全楽曲', 'MIDIデータのみ', '歌詞と楽譜のみ', '伴奏のみ'],
    correct: 0,
  ),
  'together_ai': _Quiz(
    question: 'Together AI の主な特徴として正しいものは？',
    options: ['200以上のOSSモデルをひとつのAPIで提供', '独自クローズドモデルのみ', 'テキスト生成のみ', '日本語専用'],
    correct: 0,
  ),
  'udio': _Quiz(
    question: 'Udio が Suno より優れているとされる領域は？',
    options: ['インストゥルメンタル生成と音楽理論の精度', '日本語ボーカルの自然さ', '短い楽曲の高速生成', '無料プランでの生成曲数'],
    correct: 0,
  ),
  'voyage': _Quiz(
    question: 'Voyage AI の Reranker を RAG パイプラインに組み込む目的は？',
    options: ['ベクトル検索の上位N件を精密に再スコアリングしてRAG精度向上', 'テキストを圧縮してコスト削減', 'クエリを自動翻訳', 'DB検索速度向上'],
    correct: 0,
  ),
  'writer': _Quiz(
    question: 'Writer の Palmyra Med / Palmyra Fin はどのような特化モデルですか？',
    options: ['医療・金融ドメインに特化したビジネス文書生成モデル', '音声認識専用', '画像生成専用', 'コード生成専用'],
    correct: 0,
  ),"""

QUIZ_MARKER = "  'sakana': _Quiz(\n    question: 'Sakana AI が開発した独自のモデル作成手法は？',\n    options: ['進化的モデルマージング', 'LoRA ファインチューニング', 'RLHF', '知識蒸留'],\n    correct: 0,\n  ),\n};"
QUIZ_REPLACEMENT = "  'sakana': _Quiz(\n    question: 'Sakana AI が開発した独自のモデル作成手法は？',\n    options: ['進化的モデルマージング', 'LoRA ファインチューニング', 'RLHF', '知識蒸留'],\n    correct: 0,\n  ),\n" + NEW_QUIZZES + "\n};"

if QUIZ_MARKER not in content:
    print("ERROR: _quizzes marker not found")
    exit(1)
content = content.replace(QUIZ_MARKER, QUIZ_REPLACEMENT, 1)

# ─── 3. _fallback entries ───────────────────────────────────────────────────

NEW_FALLBACK = r"""  'ai21': '''
# AI21 Labs — 256K コンテキストの Jamba モデル

AI21 Labs はイスラエル発の AI 企業。Jamba シリーズは SSM (Mamba) と Transformer を
融合した革新的なアーキテクチャで、256K という業界最長クラスのコンテキストを実現しています。

## モデルラインナップ
- Jamba 1.5 Large (256K, 398B params / active 94B, 最高精度)
- Jamba 1.5 Mini (256K, 52B params / active 12B, 高速・低コスト)

## 特徴
- 256K コンテキスト: 法律文書・財務報告書 100ページ超を一括処理
- MoE (Mixture of Experts): 活性化パラメータ数を抑えつつ高い表現力

[AI21 Docs](https://docs.ai21.com/)
''',
  'aleph_alpha': '''
# Aleph Alpha — 欧州AI主権のリーダー

Aleph Alpha は2020年にドイツで創業。ドイツ政府・EU機関が採用する
GDPR完全準拠のエンタープライズAIプラットフォームです。

## モデルラインナップ
- Pharia-1-LLM-7B (OpenAI互換・次世代)
- Luminous Supreme 70B (最高精度)
- Luminous Extended 30B (バランス型)

## 特徴
- AtMan技術でモデルの推論根拠をトークン単位で可視化 (説明可能AI)
- データはドイツ国内のみで処理 — EU外への転送なし

[Aleph Alpha Docs](https://docs.aleph-alpha.com/)
''',
  'baidu': '''
# Baidu ERNIE — 中国最大の AI プラットフォーム

中国版 ChatGPT として数千万ユーザーを獲得した ERNIE Bot の API。
中国語処理において世界最高水準の精度を誇ります。

## 主要モデル
- ERNIE 4.0 Ultra: 最高精度・128K コンテキスト
- ERNIE 4.0 Turbo: 高速バランス型
- ERNIE Speed: 低コスト大量処理
- ERNIE Lite: 完全無料

[Baidu AI Cloud](https://cloud.baidu.com/)
''',
  'elevenlabs': '''
# ElevenLabs — 音声AI最大手のTTS・音声クローンサービス

ElevenLabs は2022年創業の音声AI企業。テキスト読み上げ・音声クローン・
リアルタイム音声変換を提供し、100万人以上の開発者が利用しています。

## モデルラインナップ
- Eleven Multilingual v2 (32言語・最高品質)
- Eleven Turbo v2.5 (低レイテンシ <250ms / AIエージェント向け)
- Eleven Flash v2.5 (超高速 <75ms / バッチ処理向け)

## 主要ユースケース
- YouTubeナレーション・ポッドキャスト・有声本
- AI音声会話Bot (Claude + ElevenLabs)

[ElevenLabs Docs](https://elevenlabs.io/docs)
''',
  'fireworks_ai': '''
# Fireworks AI — 最速オープンソースAI推論

Fireworks AI はオープンソースモデルの高速推論に特化したAIインフラ企業です。
LLaMA 3.3 70B で業界最高水準の 150+ tokens/秒を実現します。

## 対応カテゴリ
- テキスト生成: LLaMA / Mixtral / Qwen / DeepSeek
- 画像生成: FLUX.1 [dev/schnell] / Stable Diffusion XL
- 音声認識: Whisper v3

## 特徴
- OpenAI 互換 API (base_url 変更のみ)
- サーバーレス課金 + 専有エンドポイントの2モード

[Fireworks AI Docs](https://docs.fireworks.ai/)
''',
  'ideogram': '''
# Ideogram AI — 画像内テキスト生成が業界最高精度

Ideogram AIは「画像の中の文字が正確に読める」という他の画像生成AIが
苦手な領域で圧倒的な精度を誇る画像生成サービスです。

## 特徴
- テキスト精度: ポスター・バナーの文字が正確に読める
- Ideogram 2.0: フォトリアル品質・最大2048×2048px
- Magic Prompt: 短いプロンプトを自動で詳細化

[Ideogram API](https://developer.ideogram.ai/)
''',
  'ollama': '''
# Ollama — プライバシー完全保護のローカルLLM実行ツール

Ollamaは自分のPC/サーバー上でLLaMA・Gemma・Mistral・DeepSeekなどの
オープンソースLLMをローカル実行するツールです。

## 特徴
- データが外部に一切送信されない (完全プライバシー)
- OpenAI SDK互換API (localhost:11434/v1)
- ワンコマンド起動: ollama run llama3.2
- 無料・無制限 (API料金ゼロ)

## 主要モデル
- llama3.3 (70B) / qwen2.5 (7B) / gemma2 (9B)

[Ollama 公式](https://ollama.com/)
''',
  'openrouter': '''
# OpenRouter — 200+モデルをひとつのAPIで

OpenRouter は単一のOpenAI互換エンドポイントで
Claude・GPT・Gemini・LLaMA・DeepSeekなど200以上のLLMにアクセスできるAPIルーターです。

## 主な機能
- OpenAI SDK互換 (base_url変更のみ)
- 自動フォールバック: メインモデル失敗時に代替へ
- 無料モデル: LLaMA 3.2 3B / Mistral 7Bなど

[OpenRouter Docs](https://openrouter.ai/docs)
''',
  'oracle': '''
# Oracle OCI Generative AI — エンタープライズ AI プラットフォーム

Oracle は OCI を通じて Generative AI サービスを提供しています。
Oracle Database 23ai に AI Vector Search を内蔵しているため、
外部ベクトルDBなしで RAG を構築できます。

## 主要モデル
- meta.llama-3.3-70b-instruct (128K, 汎用・高精度)
- cohere.command-r-plus (128K, RAG特化)
- xai.grok-2 (131K, リアルタイム推論)

[Oracle AI](https://www.oracle.com/artificial-intelligence/)
''',
  'reka': '''
# Reka AI — マルチモーダル AI (動画理解対応)

Reka は DeepMind・Google Brain 出身のチームが2022年に設立したAIスタートアップです。
テキスト・画像・動画・音声をすべて統一モデルで処理できます。

## モデルラインナップ
- Reka Core (128K, テキスト+画像+動画+音声, 最高精度)
- Reka Flash (128K, テキスト+画像+動画, バランス型)
- Reka Edge (32K, テキスト+画像, 軽量・エッジ向け)

[Reka API](https://docs.reka.ai/quick-start)
''',
  'replicate': '''
# Replicate — 画像・動画・音声AIのモデルホスティング

Replicate は数千のオープンソースAIモデルをAPIで提供するプラットフォームです。

## 主要モデルカテゴリ
- 画像生成: FLUX.1 Pro/dev/schnell / Stable Diffusion 3
- 動画生成: Stable Video Diffusion / AnimateDiff
- 音声: Whisper / MusicGen / Bark

## 特徴
- 秒課金の完全従量制 — アイドル時コストゼロ
- cog ツールで自分のモデルをデプロイして公開可能

[Replicate Docs](https://replicate.com/docs)
''',
  'runway': '''
# Runway — 動画生成AI最大手 (Gen-3 Alpha)

Runwayはテキスト・画像から高品質な動画を生成するAI企業。
ハリウッド映画のVFXにも採用されています。

## 主要機能
- Text-to-Video: テキストから最大10秒・4K動画を生成
- Image-to-Video: 静止画に動きを付けてアニメーション化
- Gen-3 Alpha Turbo: 高速・低コスト版

[Runway Docs](https://docs.runwayml.com/)
''',
  'suno': '''
# Suno AI — テキストから完全楽曲を生成する音楽AI

Suno AIはテキストのプロンプトから、ボーカル・伴奏・ミックスが完成した
楽曲を数十秒で生成します。月間100万人以上が利用しています。

## 特徴
- テキスト→完全楽曲 (ボーカル+伴奏+ミックス)
- 日本語歌詞の楽曲生成に対応
- ポップ・ロック・EDM・ジャズ・演歌など多ジャンル

[Suno AI](https://suno.com/)
''',
  'together_ai': '''
# Together AI — オープンソースAIの統合プラットフォーム

Together AI は 200+ のオープンソースAIモデルをひとつのAPIで提供するインフラ企業です。
OpenAI SDK と互換性があり、base_url を変更するだけで既存コードが動作します。

## 代表モデル
- meta-llama/Meta-Llama-3.3-70B-Instruct-Turbo (高精度・高速)
- deepseek-ai/DeepSeek-V3 (コーディング特化)
- Qwen/Qwen2.5-72B-Instruct-Turbo (多言語対応)

[Together AI Docs](https://docs.together.ai/)
''',
  'udio': '''
# Udio — 音楽理論に忠実な高品質音楽生成AI

UdioはSunoと並ぶ音楽生成AIの双璧。元Google DeepMindのメンバーが創業し、
音楽的精度を重視した設計が特徴です。

## Sunoとの違い
- インストゥルメンタル品質: Udio > Suno
- 音楽理論精度: Udio > Suno
- ボーカル自然さ: Suno > Udio

## Extend機能
生成した32秒の楽曲を前後に自然延長 → 10分以上のBGMも作成可能

[Udio](https://www.udio.com/)
''',
  'voyage': '''
# Voyage AI — RAG精度を最大化するEmbedding専門企業

Voyage AI は2023年創業のEmbedding専門企業。MTEB で
最上位クラスのスコアを達成しており、RAG構築に特化したモデル群を提供しています。

## モデルラインナップ
- voyage-3-large (1024次元, 32K, MTEB上位・最高精度)
- voyage-multilingual-2 (日本語含む多言語対応)
- rerank-2 (2段階RAG用Reranker)

## RAGへの活用
voyage-3-large でベクトル検索 → rerank-2 で精密再ランキング

[Voyage AI Docs](https://docs.voyageai.com/)
''',
  'writer': '''
# Writer — エンタープライズビジネスAI

Writer はビジネス文書生成・コンプライアンス管理に特化したエンタープライズAI企業です。

## モデルラインナップ
- Palmyra X 004 (128K, 最高精度・長文書処理)
- Palmyra Med (医療特化)
- Palmyra Fin (金融特化)

## 特徴
- ブランドボイス学習: 企業の表現スタイルをAIに記憶させ一貫性を担保
- Knowledge Graph: 社内文書をRAGに自動統合

[Writer Docs](https://dev.writer.com/docs)
''',"""

# Insert before the closing }; of _fallback
FALLBACK_MARKER = "[Sakana AI Hub](https://huggingface.co/SakanaAI)\n''',\n};"
FALLBACK_REPLACEMENT = "[Sakana AI Hub](https://huggingface.co/SakanaAI)\n''',\n" + NEW_FALLBACK + "\n};"

if FALLBACK_MARKER not in content:
    print("ERROR: _fallback marker not found")
    exit(1)
content = content.replace(FALLBACK_MARKER, FALLBACK_REPLACEMENT, 1)

open(FILE, "w", encoding="utf-8").write(content)
print(f"SUCCESS added 17 providers ({len(content)} chars)")
