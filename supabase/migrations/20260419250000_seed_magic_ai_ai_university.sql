-- Magic AI 初期コンテンツシード (2026-04-19)
INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order) VALUES

('magic_ai', 'overview', 'Magic AI 概要',
$$Magic.dev はソフトウェア開発特化の AI 研究企業。**100M token context window** の LTM (Long-Term Memory) モデルで業界に衝撃。2024 年 Google Cloud と提携し G4 (NVIDIA H100) + G5 (Grace Blackwell) スーパーコンピューターを共同構築。

**LTM-2-mini** = Llama 3.1 405B の 1000x 効率で 100M token context (≈ 10M 行のコード or 750 冊の小説) を処理可能。コード補完・全コードベース理解・大規模ドキュメント処理を主目的。

累計調達額 $320M (2024 時点)。production deploy は限定的だが研究プレビューで業界 attention 最高潮。

## 主要サービス
- **LTM-2-mini**: 100M token context モデル (research preview)
- **コード補完**: 全 codebase + docs + libraries を context 入れた状態で生成
- **Code Reasoning**: 大規模 monorepo での dependency 理解

## 強み
- **100M token context**: 業界最大 (次点 Gemini 2M)
- **超効率**: Llama 3.1 405B 比 1000x 安価 (per token decode)
- **Google Cloud 提携**: G4/G5 スーパーコンピューター
- **コード AI 特化**: software engineering ユースケース最適$$,
'https://magic.dev/', '2026-04-19', 1),

('magic_ai', 'models', 'Magic AI モデル一覧 (2026)',
$$## LTM (Long-Term Memory) シリーズ

| モデル | コンテキスト | 用途 | ステータス |
| :--- | :--- | :--- | :--- |
| **LTM-2-mini** | 100M token | コード補完 + 大規模 reasoning | research preview |
| **LTM-2** (予定) | 100M+ token | プロダクション版 | 開発中 |

## 100M token とは

| 単位 | 数量 |
| :--- | :--- |
| 行数 (コード) | ≈ 10,000,000 行 |
| 小説 | ≈ 750 冊 |
| Llama 比 attention cost | 1000x 安い |
| Llama 比 HBM 使用量 | 638x 効率 (1 H100 一部 vs 638 H100) |

## 特徴的な機能
- **HashHop benchmark**: 長文 context 内の特定情報検索性能で SOTA
- **コード理解**: 全リポジトリ + docs + 依存ライブラリを 1 prompt で扱う
- **dependency reasoning**: 巨大 monorepo の関数間依存を正確追跡
- **G4/G5 supercomputer**: Google Cloud との共同開発
- **research preview**: production API はまだ限定的$$,
'https://magic.dev/blog/100m-token-context-windows', '2026-04-19', 2),

('magic_ai', 'api', 'Magic AI API 入門',
$$## Magic AI の現状 (2026-04 時点)

- **production API**: 一般公開はまだ (research preview のみ)
- **LTM-2-mini デモ**: 公式サイトでサンプル試用可能
- **Google Cloud G4 supercomputer**: 大規模 inference 用に構築中
- **G5 (Grace Blackwell)**: 次世代へ移行予定 (NVIDIA Vera Rubin 期)

## 想定 API (将来公開時)

```python
# 想定インターフェース (公式リリース時に確定)
import magic

client = magic.Client(api_key="<MAGIC_API_KEY>")

# 100M token context で全コードベース + docs を context に入れる
response = client.chat.completions.create(
    model="ltm-2-mini",
    messages=[
        {"role": "system", "content": "<entire monorepo code + docs>"},
        {"role": "user", "content": "Add a feature X using existing patterns"},
    ],
    max_context_tokens=100_000_000,
)
```

## 料金 (見込み)
- **research preview**: 個別問い合わせ
- **production 価格**: 未公開 (Llama 比 1000x 効率 = 同 context で安価想定)

## 公式リソース
- [Magic.dev Blog (100M Token Context)](https://magic.dev/blog/100m-token-context-windows)
- [Google Cloud Magic Partnership](https://cloud.google.com/blog/products/ai-machine-learning/magic-ai-100m-tokens-cloud-supercomputer)

## 注意
- 一般公開 API は未提供 (research preview のみ)
- 自分株式会社では待機状態 (公開され次第追加検討)$$,
'https://magic.dev/', '2026-04-19', 3)

ON CONFLICT DO NOTHING;
