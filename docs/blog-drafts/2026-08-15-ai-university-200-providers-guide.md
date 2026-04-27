---
title: "AI大学 230社ガイド — 「どのAIを使えばいいか」迷わなくなる分類法"
tags: AI,education,個人開発,productivity
published: true
---

# AI大学 230社ガイド — 「どのAIを使えばいいか」迷わなくなる分類法

## 「AIが多すぎてどれを使えばいいかわからない」

2026年、自分株式会社の AI 大学には 230社以上の AI プロバイダーが登録されている。

「全部調べるのは無理」「自分に合うものがわからない」という声は理解できる。

だが、全部を知る必要はない。**自分のユースケースに合う20社を知れば十分**だ。その選び方を体系的に整理する。

---

## AI大学の分類軸

自分株式会社 AI 大学では 230社を以下の9カテゴリに分類している:

| カテゴリ | 代表的なプロバイダー | 用途 |
|----------|---------------------|------|
| **コーディング支援** | Claude Code, Cursor, GitHub Copilot, Codex | コード生成・補完・レビュー |
| **LLM基盤** | OpenAI, Anthropic, Google Gemini, Mistral | API・モデル選定 |
| **エージェント・オーケストレーション** | LangGraph, LangChain, Composio, AutoGen | 複雑タスク自動化 |
| **RAG・検索** | Weaviate, Chroma, Tavily, Nomic | ベクトル検索・ドキュメント連携 |
| **音声・動画AI** | Otter.ai, Murf, VAPI, ElevenLabs | 文字起こし・音声合成 |
| **ビジュアル生成** | Midjourney, DALL-E, Meshy, Higgsfield | 画像・動画生成 |
| **データ・分析** | Databricks, Modal, E2B, Firecrawl | データパイプライン・サンドボックス |
| **ビジネス業務** | Glean, Clay, Moveworks, Gong | 社内検索・営業・カスタマーサポート |
| **学習・教育** | NotebookLM, Consensus, Perplexity | リサーチ・学術論文・学習 |

---

## 個人開発者が最初に使うべき10社

### コーディング (3社)
1. **GitHub Copilot** ($10/月) — インライン補完の標準
2. **Claude Code** ($100/月) — 自律タスク実行・memory システム
3. **OpenAI Codex** (従量課金) — SQL・バッチ生成に特化

### LLM API (2社)
4. **Anthropic Claude** (API) — 長文・コード・推論
5. **Google Gemini** (API) — 画像・動画・マルチモーダル

### エージェント (1社)
6. **LangGraph** (OSS) — ステートマシンで制御可能なエージェント

### 検索・データ (2社)
7. **Tavily** — LLM 向けリアルタイム Web 検索
8. **Firecrawl** — Web スクレイピング・Markdown 変換

### リサーチ (2社)
9. **NotebookLM** (無料) — ドキュメント分析・Deep Research
10. **Perplexity** ($20/月) — リアルタイム情報付き回答

この10社で個人開発の 90% のユースケースはカバーできる。

---

## 用途別 クイックセレクター

### 「コードを書くのを速くしたい」
→ GitHub Copilot (補完) + Claude Code (複雑タスク)

### 「Web情報を調べてコードに使いたい」
→ Tavily API (検索) + Firecrawl (スクレイピング) + Perplexity (情報整理)

### 「文書・PDF を AI に読ませたい」
→ NotebookLM (無料・最大50ソース) → 大量なら Weaviate / Chroma (OSS RAG)

### 「音声を文字起こし・要約したい」
→ Otter.ai (会議録) / VAPI (電話AI) / ElevenLabs (音声合成)

### 「社内 Slack / ドキュメントを検索したい」
→ Glean (エンタープライズ向け) / Notion AI (Notion 内)

### 「セールス・CRM を自動化したい」
→ Clay (データエンリッチ) / Gong (商談分析) / Moveworks (IT内部)

---

## AI大学の使い方

自分株式会社の AI 大学では:

1. **プロバイダー検索** — 名前・カテゴリ・評価で絞り込み
2. **比較機能** — 2-3社を横並び比較 (料金・機能・制限)
3. **評価スコア** — 実際の利用者評価 (1-9点)
4. **ユースケース別フィルター** — 「個人開発」「スタートアップ」「エンタープライズ」

```
アクセス: https://my-web-app-b67f4.web.app/
→ AI大学タブ → カテゴリ選択 → フィルター適用
```

---

## 2026年の AI プロバイダー地図

**成熟ゾーン** (安定・本番向き): OpenAI, Anthropic, Google, GitHub Copilot
**急成長ゾーン** (注目・導入判断期): LangGraph, Composio, Tavily, Firecrawl, VAPI
**実験ゾーン** (面白いが本番は慎重): 各種OSS エージェントフレームワーク

「成熟ゾーン」だけ使っても機能は揃う。「急成長ゾーン」を1-2個追加すると生産性が跳ね上がるケースがある。「実験ゾーン」は趣味・学習目的で。

---

230社の全リストは AI 大学で確認できる。カテゴリ別・評価順・用途別で絞り込めるため、「今の自分に必要なAI」が10分以内に見つかる。

→ [自分株式会社 AI 大学で全プロバイダーを見る](https://my-web-app-b67f4.web.app/)
