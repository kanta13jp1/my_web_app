-- PS#3 S130: AI大学 355→356社化 — MetaGPT (マルチエージェントフレームワーク / ソフトウェア会社シミュレーション)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'metagpt', 'overview',
  'MetaGPT — マルチエージェントフレームワーク・ソフトウェア会社シミュレーション・役割分担 AI (9/9)',
  $$## MetaGPT とは

**MetaGPT** は「AI エージェントがソフトウェア会社をシミュレートする」マルチエージェントフレームワーク。プロダクトマネージャー・アーキテクト・エンジニア・QA など、**ソフトウェア開発の各役割を AI エージェントが担当**する独特のアーキテクチャ。

論文「MetaGPT: Meta Programming for A Multi-Agent Collaborative Framework」として発表され、**40,000+ GitHub stars** を獲得。マルチエージェント AI 開発の重要な学術・実装基盤。

## MetaGPT のアーキテクチャ

```
MetaGPT の組織構造:

  ProductManager Agent:
    ・ユーザー要件を分析
    ・PRD (製品要件書) を作成
    ・ユーザーストーリーを定義

  Architect Agent:
    ・技術アーキテクチャを設計
    ・システム設計書を作成
    ・API インターフェースを定義

  Engineer Agent:
    ・設計書に基づいてコードを実装
    ・ファイルを作成・編集
    ・依存関係を管理

  QaEngineer Agent:
    ・テストコードを作成
    ・バグを検出・報告
    ・品質を保証

  → 各エージェントが成果物を次に引き継ぐ
    「バトン式」の協調開発
```

## 実際の動作例

```python
# MetaGPT を使って「Flappybird クローン」を作る
from metagpt.software_company import SoftwareCompany

company = SoftwareCompany()
company.hire([
    ProductManager(),
    Architect(),
    Engineer(),
    QaEngineer()
])

# 自然言語の仕様を渡すだけ
await company.run(
    idea="Make a 2048 game in Python",
    investment=3.0  # USD (APIコスト上限)
)

# → docs/ にPRD, システム設計書
# → game/ にPython実装コード
# → tests/ にテストコード
# が自動生成される
```

## MetaGPT が証明したこと

```
マルチエージェント > シングルエージェントの例:

  タスク: "ECサイトを作って"

  シングルエージェント:
    LLM が直接コードを書く
    → コンテキスト不足で整合性が崩れる

  MetaGPT (マルチエージェント):
    PM → 要件定義書
    Architect → システム設計
    Engineer → 要件+設計を参照してコーディング
    QA → 設計+コードを参照してテスト
    → 各フェーズの成果物が次の入力になる
    → ドキュメントが「エージェント間の通信」として機能
```

## SoftwareCompany パターンの応用

MetaGPT の「役割分担エージェント」パターンは多くのプロジェクトに影響を与えた:

- **ChatDev**: 別の学術研究チームが同様パターンで実装
- **CrewAI**: 商用マルチエージェントフレームワーク
- **AutoGen (Microsoft)**: エージェント協調の汎用フレームワーク

## 自分株式会社との関連

自分株式会社の **12 インスタンスフリート** は MetaGPT の「ソフトウェア会社シミュレーション」の進化版。MetaGPT が 1 プロセス内で役割分担するのに対し、自分株式会社は実際の git worktree / branch / PR レビューで役割分担する「本物のソフトウェア会社」として動作する。PS版#3 (AI大学担当) / PS版#6 (競合分析担当) / Codex#2 (CI担当) という役割分担はまさに MetaGPT の Engineer / QA / PM 役割に対応している。
$$,
  'https://github.com/geekan/MetaGPT',
  NOW(),
  356
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  updated_at = NOW();
