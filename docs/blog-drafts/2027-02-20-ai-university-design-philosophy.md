---
title: "AI大学 274社を体系化する設計思想 — なぜ「競合」ではなく「教材」として扱うか"
tags: AI,個人開発,buildinpublic,postgresql
published: true
---

# AI大学 274社を体系化する設計思想 — なぜ「競合」ではなく「教材」として扱うか

このプロジェクトには「AI大学」という機能があります。274社のAIツール・サービスをデータベース化し、ユーザーが体系的に学べるようにしています。なぜ「競合情報」ではなく「教材」として設計したか、その思想を公開します。

## きっかけ: 自分自身が困っていた

AIツールが爆発的に増えて、何から学べばいいかわからなくなった。
- Claude / GPT-4 / Gemini は知っている
- でも MLflow / Ray / BentoML / Feast は？
- Hugging Face と Weights & Biases の違いは？

「AIを使う人」から「AIを設計する人」へ進化するには、ツールの体系知識が必要。これを自分で学びながら、プロダクトの機能にもなる設計を考えた。

## 分類体系: 12カテゴリ

| カテゴリ | 例 | 社数 |
|---|---|---|
| 基盤モデル・API | Claude, GPT-4, Gemini | 約40社 |
| LLMフレームワーク | LangChain, LlamaIndex | 約25社 |
| ファインチューニング | TRL, PEFT, Unsloth | 約20社 |
| MLOps / 実験管理 | MLflow, wandb, Neptune | 約30社 |
| モデルサービング | vLLM, TorchServe, BentoML | 約20社 |
| オブザーバビリティ | Arize Phoenix, TruLens | 約15社 |
| ベクターDB | Pinecone, Weaviate, pgvector | 約20社 |
| AIエージェント | AutoGPT, CrewAI, Dify | 約25社 |
| 音声・動画AI | ElevenLabs, Sora, Runway | 約30社 |
| コーディングAI | Claude Code, Copilot, Codex | 約15社 |
| マルチモーダル | GPT-4V, Gemini Vision | 約20社 |
| クラウドMLプラットフォーム | SageMaker, Vertex AI, Azure ML | 約10社 |

## データスキーマの設計

```sql
CREATE TABLE ai_university (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_name TEXT NOT NULL,
  category TEXT NOT NULL,
  description TEXT NOT NULL,           -- 一行説明
  key_features JSONB NOT NULL,         -- 主要機能リスト
  github_stars TEXT,                   -- "33k+" 形式
  difficulty_level INTEGER,            -- 1-10
  relevance_score INTEGER,             -- このプロジェクトとの関連度 1-10
  official_url TEXT,
  content_md TEXT,                     -- 詳細解説 Markdown
  created_at TIMESTAMPTZ DEFAULT now()
);
```

`difficulty_level` と `relevance_score` の2軸が重要。
- 難易度1-3: 初学者 (API呼び出すだけで使える)
- 難易度7-10: 上級者 (分散システムの設計が必要)
- 関連度9-10: このプロジェクトで直接使用中

## 「競合」ではなく「教材」にした理由

### 競合として扱う問題点
- ElevenLabs を「競合」と定義すると「倒すべきもの」になる
- 実態は「音声AI のベストプラクティスを学べる教材」
- 適切な敬意を持って学ぶほうが吸収が速い

### 教材として扱うメリット
- 「なぜ wandb が ML実験管理のデファクトなのか」を分析 → 自プロダクトの設計に応用
- 競合の成功パターンを学ぶ → 機能設計の参考
- ユーザーにとっても「AIツールの地図」として価値提供

## AI を使った content 生成

274社のコンテンツを手動で書くのは非現実的。AI フローを設計:

```
1. 企業名 + カテゴリ → Claude に解説文生成を依頼
2. GitHub スター数 → GitHub API で取得
3. difficulty / relevance → プロジェクト文脈で採点
4. Supabase migration → SQL seed ファイルで管理
```

PS#3 インスタンスが専任で seed SQL を毎日作成。2-3社/セッションのペースで累積。

## 学習パスの設計

難易度 × 関連度でユーザーを案内:

```
入門コース (difficulty 1-3):
  Claude API → OpenAI API → Gemini API

実践コース (relevance 8-10):
  Supabase → Flutter → Firebase → GitHub Actions

上級コース (difficulty 8-10):
  Ray/Anyscale → Kubeflow → Seldon Core
```

## 274社から得た洞察

**LLMフレームワーク戦争**: LangChain vs LlamaIndex vs raw API。2026年時点では raw API + 薄いラッパーが本番安定。

**MLOps の収束**: 実験管理は wandb か MLflow の二択。OSS なら MLflow、クラウド連携なら wandb。

**サービングの分化**: リアルタイムは vLLM / バッチは BentoML / エッジは Ollama と用途で分かれてきた。

## まとめ

AI大学を「教材」として設計したことで:
1. ユーザーが体系的に学べる「AIツールの地図」が完成
2. 自分が各ツールを深く理解 → 設計判断の質が向上
3. コンテンツとして成立 → SEO・集客の資産に

274社を「倒すべき敵」ではなく「先生」として扱う。この視点が個人開発者の強みになります。
