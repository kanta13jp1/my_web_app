#!/usr/bin/env python3
"""AI大学 gemini_university_v2_page.dart に databricks/samsung/zhipu/character_ai/inflection を追加する。"""

FILE = "lib/pages/gemini_university_v2_page.dart"

META_ENTRIES = """\
  'databricks': _ProviderMeta(
    name: 'Databricks',
    emoji: '🧱',
    color: const Color(0xFFFF3621),
    officialUrl: 'https://www.databricks.com/product/machine-learning',
  ),
  'samsung': _ProviderMeta(
    name: 'Samsung Galaxy AI',
    emoji: '📱',
    color: const Color(0xFF1428A0),
    officialUrl: 'https://www.samsung.com/ai',
  ),
  'zhipu': _ProviderMeta(
    name: 'Zhipu AI (GLM)',
    emoji: '🔮',
    color: const Color(0xFF4E5FFF),
    officialUrl: 'https://www.zhipuai.cn',
  ),
  'character_ai': _ProviderMeta(
    name: 'Character.AI',
    emoji: '🎭',
    color: const Color(0xFF000000),
    officialUrl: 'https://character.ai',
  ),
  'inflection': _ProviderMeta(
    name: 'Inflection AI (Pi)',
    emoji: '💙',
    color: const Color(0xFF6B48FF),
    officialUrl: 'https://pi.ai',
  ),
"""

QUIZ_ENTRIES = """\
  'databricks': _Quiz(
    question: 'Databricks の LLM DBRX のアーキテクチャは？',
    options: ['MoE (Mixture of Experts)', 'Dense Transformer', 'CNN', 'RNN'],
    correct: 0,
  ),
  'samsung': _Quiz(
    question: 'Samsung Galaxy AI で搭載されているオンデバイスモデルは？',
    options: ['Gemini Nano', 'GPT-4o mini', 'Claude Haiku', 'Llama 3'],
    correct: 0,
  ),
  'zhipu': _Quiz(
    question: 'Zhipu AI (GLM-4) の最大コンテキスト長は？',
    options: ['128K', '32K', '8K', '64K'],
    correct: 0,
  ),
  'character_ai': _Quiz(
    question: 'Character.AI の月間アクティブユーザー数は？',
    options: ['1.5億人', '1,000万人', '5,000万人', '3億人'],
    correct: 0,
  ),
  'inflection': _Quiz(
    question: 'Inflection AI の Pi が最も特化している領域は？',
    options: ['感情的知性・共感的対話', '数学・推論', 'コード生成', '画像生成'],
    correct: 0,
  ),
"""

FALLBACK_ENTRIES = """\
  'databricks': '''
## Databricks
データ+AI統合プラットフォーム。DBRX (MoE LLM) はオープンソース最高性能を達成。
MLflow・Delta Lake・レイクハウスアーキテクチャで企業AIを加速。

## 主要モデル
- **DBRX**: MoE アーキテクチャ・Mixture of 16 Experts・オープンソース
- **DBRX Instruct**: チャット・指示チューニング版
- **MPT-7B/30B**: 初期オープンソースLLM (Databricks製)

## 主要機能
- MLflow: MLライフサイクル管理 (実験追跡・モデル管理・デプロイ)
- Delta Lake: トランザクション対応データレイク
- Unity Catalog: AIガバナンス・データリネージ管理
- Mosaic AI: LLMファインチューニング・RAG構築

[公式サイト](https://www.databricks.com)
''',
  'samsung': '''
## Samsung Galaxy AI
Samsungが開発するオンデバイスAI。Galaxy S24シリーズ以降に搭載。
Gemini Nanoをデバイス内で動かし、プライバシーを保護しながらAI機能を提供。

## 主要機能
- **リアルタイム通訳**: 通話中に双方向同時通訳
- **テキスト要約**: メール・メッセージの自動要約
- **Circle to Search**: 画面上の任意箇所をGoogleで検索
- **生成型編集**: 写真内オブジェクトの削除・移動・拡張

## 特徴
- 2億台以上のGalaxyデバイスに展開
- Gemini Nano (オンデバイス) + Gemini Pro (クラウド) のハイブリッド
- 個人情報はデバイス内で処理 (プライバシー保護)

[公式サイト](https://www.samsung.com/ai)
''',
  'zhipu': '''
## Zhipu AI (GLM)
清華大学発のAIスタートアップ。中国AI御三家の一つ。
GLM-4は128Kコンテキスト対応・GPT-4クラスの性能を持つ。

## 主要モデル
- **GLM-4-Plus**: フラッグシップ・128K・マルチモーダル
- **GLM-4-Air**: 高速・低コスト・日常タスク向け
- **CogVideo X**: 動画生成モデル
- **CogView-3-Plus**: 画像生成モデル (FLUX品質)

## 特徴
- 中国語処理で最高水準 (清華大学の言語研究基盤)
- 128K超長文コンテキスト
- コード生成・数学推論に強み
- CogSeriesでビジョン系も展開

[公式サイト](https://www.zhipuai.cn)
''',
  'character_ai': '''
## Character.AI
ロールプレイ・キャラクター会話に特化したAI。1.5億MAU・1,800万キャラクター以上。
Alphabet (Google) の元DeepMindチームが創業。

## 主要機能
- **キャラクター会話**: 有名人・アニメ・オリジナルキャラとの対話
- **キャラクター作成**: 誰でも自分のAIキャラクターを公開可能
- **グループチャット**: 複数AIキャラクターとの同時会話
- **Character Voices**: 音声付きキャラクター会話

## 特徴
- Z世代に圧倒的人気 (1日平均2時間以上利用)
- 1,800万以上のコミュニティ作成キャラクター
- ウェルビーイング機能: 長時間利用への気づき促進
- Googleとの提携・独自モデル (c1.3) を使用

[公式サイト](https://character.ai)
''',
  'inflection': '''
## Inflection AI (Pi)
Reidほか LinkedIn 創業者が設立。感情的知性に特化したAIアシスタント Pi を提供。
Microsoft に主要チームが移籍後も Pi は独立サービスとして継続。

## 主要機能
- **Pi**: 共感的・感情的知性に特化した会話AI
- **Inflection-3**: GPT-4クラスの基盤モデル
- **音声会話**: 自然な音声での長時間対話

## 特徴
- 感情サポート・コーチング・一般相談に特化
- 「AIの親友」というコンセプト
- 判断より傾聴・共感を重視するアーキテクチャ設計
- Microsoftとの提携 (Copilot for Enterprises に技術提供)

[公式サイト](https://pi.ai)
''',
"""

def main():
    with open(FILE, encoding="utf-8") as f:
        src = f.read()

    # Check if already added
    if "'databricks': _ProviderMeta(" in src:
        print("Already added, skipping.")
        return

    meta_end_pattern = "};\n\n// ─────────────────────────────────────────────────────────────────────────────\n// クイズ"
    meta_end_idx = src.find(meta_end_pattern)
    assert meta_end_idx >= 0
    src = src[:meta_end_idx] + META_ENTRIES + src[meta_end_idx:]

    quiz_end_pattern = "};\n\n// ─────────────────────────────────────────────────────────────────────────────\n// フォールバック"
    quiz_end_idx = src.find(quiz_end_pattern)
    assert quiz_end_idx >= 0
    src = src[:quiz_end_idx] + QUIZ_ENTRIES + src[quiz_end_idx:]

    fb_end_pattern = "\n};\n\n// ─────────────────────────────────────────────────────────────────────────────\n// ページ本体"
    fb_end_idx = src.find(fb_end_pattern)
    assert fb_end_idx >= 0
    src = src[:fb_end_idx + 1] + FALLBACK_ENTRIES + src[fb_end_idx + 1:]

    with open(FILE, "w", encoding="utf-8") as f:
        f.write(src)

    print("Done: 5 providers (databricks/samsung/zhipu/character_ai/inflection) added")


if __name__ == "__main__":
    main()
