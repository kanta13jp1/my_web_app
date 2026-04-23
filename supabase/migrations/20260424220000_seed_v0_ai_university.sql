-- Session Win#132 part 2: AI大学 149 社化 — v0 by Vercel 追加
-- vibe-coding クラスタ完結のため、生成物が Next.js/React 本番コード化される
-- 代表的プラットフォームを追加。Lovable (GitHub export) / Bolt.new (WebContainer) /
-- Replit (独自 cloud IDE) / Cursor (local IDE) に対し v0 は「Vercel deploy との直結」
-- による最短本番投入が独自軸。

INSERT INTO ai_university_content (provider, category, title, content, updated_at)
VALUES
  (
    'v0',
    'overview',
    'v0 by Vercel — AI UI generator to Vercel production',
    $md$
# v0 by Vercel — AI UI generator + 即 Vercel 本番 deploy

Vercel が 2023-10 に β 公開した AI UI/コード生成プラットフォーム。
テキストプロンプト → React + Next.js + Tailwind の生成 → `v0.dev` で即プレビュー →
Vercel へ 1 click deploy の統合 UX が特徴。

## 既存 148 社との差別化

| 観点 | v0 | Lovable | Bolt.new | Replit |
|------|----|---------|----------|--------|
| 出力形式 | **React + Next.js** (shadcn/ui) | Vite + Supabase | Node.js full-stack | 任意 runtime |
| deploy 先 | **Vercel 直結** | Netlify/Supabase | Netlify/StackBlitz | replit.app |
| GitHub | ✅ export | ✅ native | △ DL | △ |
| モデル | OpenAI + Anthropic mix | Claude Sonnet | Claude Sonnet + GPT-4o | Claude + GPT-4o |
| 対象 | **UI/コンポーネント特化** | SaaS 1st draft | full-stack prototype | 学習 + prod |

## 主要機能

- **Chat-first UI generation**: 自然言語 → React + shadcn/ui コンポーネント
- **v0.dev live preview**: 生成物を共有 URL で公開プレビュー (no-auth 可)
- **Vercel deploy button**: 1 click で `<project>.vercel.app` 即本番
- **Next.js App Router ネイティブ**: server components + streaming 対応コード生成
- **shadcn/ui integration**: デザインシステム標準化で「それっぽい UI」品質保証

## 業績 (2026-04 推定)

- Vercel の AI 製品群の旗艦 (AI SDK + v0 + Vercel AI Gateway)
- 累計 100M+ プロジェクト生成 (Vercel 公式ブログ 2025)
- Pro $20/month + Premium $50/month の seat pricing
- Enterprise は Vercel と統合

## 自分株式会社での活用

- **LP / admin UI prototype**: 2026-Q2 新機能 LP の shadcn ベース draft を v0 で生成
- **Cursor Composer で port**: v0 出力 → main repo (Flutter) への移植は Cursor で対応
- **A/B 変異体生成**: 同一仕様で 3 バリエーション生成 → 最良版を採用パターン

## 関連リンク

- 公式: <https://v0.dev/>
- Vercel blog: <https://vercel.com/blog/v0>
- shadcn/ui: <https://ui.shadcn.com/>
$md$,
    NOW()
  ),
  (
    'v0',
    'models',
    'v0 モデル構成 — OpenAI + Anthropic multi-LLM',
    $md$
# v0 モデル構成

v0 は単一モデルではなく用途別に LLM を routing する multi-model 戦略。

## 主要モデル (2026-04 時点)

| 用途 | 採用モデル | 備考 |
|------|-----------|------|
| UI コード生成 (主) | **Claude Sonnet 4.5** | 長 context + JSX 理解 |
| 高速 iteration | GPT-4o | chat-style 修正 |
| 画像→UI (v0 sketch mode) | GPT-4V + Claude Vision | スクリーンショット解析 |
| デザインシステム提案 | 内製 fine-tune | shadcn 準拠スタイル選定 |

## 特徴的な仕組み

- **Vercel AI SDK 統合**: 生成コードは自動で AI SDK を import 済
- **Streaming output**: コード生成中に preview が逐次更新される UX
- **Version history**: 各 prompt 反復を branch として保持 → rollback 可能
$md$,
    NOW()
  ),
  (
    'v0',
    'use_cases',
    '自分株式会社での活用パターン',
    $md$
# 自分株式会社での活用パターン

## 1. LP 改修の high-fidelity draft

新機能 LP 改修時に 3 variant を v0 で生成して最良を採用。
- 入力: 機能概要 + 参考競合 URL
- 出力: shadcn + Tailwind の Landing Page (hero / feature / CTA / FAQ)
- 所要: 5-10 分で 3 variant 比較可能

## 2. admin UI prototype

ユーザー管理・統計ダッシュボード等の内部 admin UI を v0 で 1st draft。
- Flutter admin_analytics_page.dart の代替ではなく補完
- 社内デモ用の「動く画面」を v0.dev URL で共有

## 3. Cursor / Claude Code への受け渡し

v0 出力 → Claude Code / Cursor が Flutter widget に port。
- v0 = UI 提案エンジン / Flutter = 本番コード生成
- Vercel deploy された v0 URL は「要件定義の動く figma」として活用
$md$,
    NOW()
  )
ON CONFLICT (provider, category) DO UPDATE
SET title = EXCLUDED.title,
    content = EXCLUDED.content,
    updated_at = EXCLUDED.updated_at;
