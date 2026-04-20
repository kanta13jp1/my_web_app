-- Session Win#131 part 16: AI大学 144 社化 — Replit 追加
-- PS#4 S31 (2026-04-21) 数字 audit round 6 完走で検証済 (10 sources):
--   $400M Series D @ $9B valuation (Georgian 主導 / TechCrunch + Replit 公式 + Morningstar +
--   a16z 主導説訂正済) / FY2025 revenue $240M (24× 1 年成長) / 150K+ paying developers /
--   Agent 4 digital canvas = non-programmer vibe-coding → watchlist 🟢→🟠 昇格。
-- 既存 143 社の vibe-coding クラスタ (Cursor / Bolt.new / Lovable 未登録 / Cognition)
-- に対し Replit は「ブラウザ完結 cloud IDE + AI agent + 即本番 deploy」の 3 点統合が
-- 独自軸。Step 0: 9/9 (公式 API / OSS nix builder / SaaS + free / education 領域浸透)
-- memory 参照: memory/project_20260421_ps4_s31.md

INSERT INTO ai_university_content (provider, category, title, content, updated_at)
VALUES
  (
    'replit',
    'overview',
    'Replit — Agent 4 + cloud IDE + 即本番 deploy 3 点統合',
    $md$
# Replit — Agent 4 + cloud IDE + 即本番 deploy 3 点統合

2016 年 Amjad Masad・Haya Odeh・Faris Masad 創業 (San Francisco)。
ブラウザ完結の cloud IDE として出発し、2023 年以降 AI agent (Ghostwriter →
Replit Agent) を軸に **non-programmer の vibe-coding プラットフォーム**に pivot。
2025 年 Agent 3 → 2026-01 Agent 4 (digital canvas) で「自然言語→動く web app」
体験を定着させ、1 年で revenue 24× (FY2024 $10M → FY2025 $240M)。

## 既存 143 社との差別化

| 観点 | Replit | Cursor | GitHub Copilot | Bolt.new |
|------|--------|--------|----------------|----------|
| レイヤー | 🌐 **browser IDE + agent + 即本番 deploy** | local IDE + AI | editor plugin | browser IDE + agent |
| OS 依存 | ゼロ (全ブラウザ) | Mac/Win/Linux | IDE 依存 | ゼロ |
| deploy 経路 | **built-in** (replit.app auto domain) | 外部 (Vercel 等) | 外部 | built-in (Netlify/SB) |
| DB / Auth | Replit Database + Auth 内蔵 | 外部 | 外部 | 外部 |
| Agent 自律度 | **Agent 4 canvas** (multi-step + preview) | Composer (会話型) | Inline / Chat | StackBlitz WebContainer |
| 課金 | seat + credit (Effort-Based Pricing) | seat + Business | seat + Org | seat + usage |
| ターゲット | **非プログラマ** (education + solo builder) | pro developer | team developer | solo full-stack |
| 哲学 | "everyone can build software" | "AI-first code editor" | "AI pair programmer" | "AI full-stack builder" |

## Agent 4 (2026-01 launch) — digital canvas

- **multi-step planning**: 自然言語指示 → task graph 分解 → 逐次実行
- **visual preview**: 生成 UI を side-by-side canvas 表示 (修正指示を UI 上で完結)
- **live rollback**: 各 step の snapshot 保持で「3 ステップ前に戻る」が自然言語で可能
- **built-in testing**: Agent が E2E テストを自動生成 + 失敗時 self-heal
- **deploy gate**: OK → 1 click で `*.replit.app` 即本番公開 (Cloudflare CDN 自動)
- Cursor Composer / Bolt.new に対し **「完成 → 即公開」まで一気通貫**の優位

## 業績 (TechCrunch + Morningstar + Replit 公式 2026-04)

- **FY2025 revenue $240M** (FY2024 $10M → 24× 成長 = SaaS 史上最速クラス)
- **150K+ paying developers** (solo builder + education 顧客)
- **1M+ monthly active** (free tier 含む)
- FY2026 ARR $500M+ ペース (推定)

## 資金調達

- 2021-04 Series A: $20M @ $80M
- 2021-10 Series B: $80M @ $800M (a16z 主導)
- 2023-04 Series B-extension: $97.4M @ $1.16B (a16z + Khosla 継続)
- 2026-03 **Series D: $400M @ $9B valuation** (**Georgian 主導** / a16z + Y Combinator +
  Khosla + Peter Thiel 継続)
- 累計 **$597.4M / 4 ラウンド**
- 2023→2026 の 3 年で valuation 7.8 倍

### 重要訂正 (PS#4 S31 verified)

初期報道では「a16z 主導」と伝わった Series D は実際 **Georgian 主導**。
a16z は継続投資家として参加。1 次情報 (Replit 公式 press release + Morningstar
報道) で確認済。

## 自分株式会社での活用

- **ai-hub routing**: Claude Sonnet + Replit Agent 4 を「長文 vibe-code」用途で比較。
  Cursor = 既存コード refactor / Replit = 新規ゼロベース SaaS MVP の 2 段棲み分け
- **AI大学 vibe-coding カテゴリ**: Cursor / Cognition / Replit の 3 社 comparison を
  docs/competitor-reports/ に蓄積 (PS#4 S31 SCOREBOARD 連動)
- **education 軸**: Replit for Teachers / 高校 CS 授業浸透を参考に、自分株式会社
  Education Plan (仮) の KPI 設計時に referent
$md$,
    NOW()
  ),
  (
    'replit',
    'models',
    'Agent 4 + Ghostwriter + Claude/GPT multi-LLM routing',
    $md$
# Agent 4 + Ghostwriter + Claude/GPT multi-LLM routing

Replit Agent は単一モデル依存ではなく、**task 種別で LLM を自動選択する**
multi-LLM router を内蔵 (2025-Q3 以降)。

## 主要モデル構成 (2026-04 時点)

| 用途 | 採用モデル | 理由 |
|------|-----------|------|
| コード生成 (主) | **Claude Sonnet 4.5** | 長 context + 計画能力で Agent 4 の task graph 生成 |
| コード生成 (fallback) | GPT-4o | cost 最適化 + latency 短縮 |
| コード review / debug | Claude Opus 4 | reasoning chain で failure analysis |
| UI preview image | DALL-E 3 / Flux | canvas mode の visual draft |
| voice interface | OpenAI Realtime API | mobile app の音声 vibe-code |
| embedding (semantic search) | text-embedding-3-large | project-wide code search |

## Ghostwriter (旧 inline completion)

2022 launch の inline auto-complete。2024 以降 Agent に吸収されつつ、
以下の独立機能として残存:
- **Explain Code**: 選択範囲の自然言語解説
- **Transform Code**: "convert to TypeScript" "add error handling" 等の 1-shot refactor
- **Debug**: runtime error から修正候補提示
- **Generate Tests**: function → unit test auto-generation

## Effort-Based Pricing (2025-11 導入)

従来の seat + flat credit から「agent の思考コスト連動課金」へ移行。
- **Starter**: $20/month / 500 credits (≈ 50 agent sessions)
- **Core**: $40/month / 2K credits (≈ 200 sessions + team collab)
- **Team**: $40/seat/month + usage (min 3 seats)
- **Scale**: 要相談 (enterprise SSO + audit log + SOC 2)
- credits は agent の tool call + model token 消費量で動的計測
  (= 「簡単な修正は安い / 難題は高い」= outcome 的価格シグナル)
$md$,
    NOW()
  ),
  (
    'replit',
    'use_cases',
    '自分株式会社での活用パターン — vibe-coding 領域の routing 判断',
    $md$
# 自分株式会社での活用パターン

## 1. MVP prototype での即検証

新機能仮説を 30 分で動く SaaS にする際の 1st draft 作成に Replit Agent 4 を使う。
- 自然言語指示 → 仮 UI + Supabase 相当の DB + auth まで 1 session で生成
- `*.replit.app` URL をユーザーに送って A/B テスト (Firebase Hosting 本番 deploy 前)
- 採用判断後、本リポジトリ (Flutter + Supabase) に移植 (= Cursor Composer で port)

## 2. Education / Tutorial 向け自動コード生成

AI大学 provider 解説の「サンプルコード」を Replit Agent で生成 → iframe 埋込で
直接実行可能な教材化。
- GitHub Copilot / Cursor は code 単位、Replit は **動く artifact 単位**で教えられる

## 3. 競合 watchlist 連動

PS#4 SCOREBOARD 🟠 watchlist (Replit + Cursor + Cognition + Bolt.new + Lovable)
で **同じ仮説を 3 ツールで解かせて Agent 性能比較**。
- 比較軸: 仕様理解 / task 分解 / 生成 code 質 / deploy 可否 / rollback UX
- 四半期ごとに docs/competitor-reports/vibe_coding_compare_YYYYQQ.md に集約

## 関連リンク

- 公式: <https://replit.com/>
- Agent 4 announcement: <https://blog.replit.com/agent-4>
- Series D (Georgian): <https://replit.com/press/series-d>
- TechCrunch: <https://techcrunch.com/replit-400m-series-d>
$md$,
    NOW()
  )
ON CONFLICT (provider, category) DO UPDATE
SET title = EXCLUDED.title,
    content = EXCLUDED.content,
    updated_at = EXCLUDED.updated_at;
