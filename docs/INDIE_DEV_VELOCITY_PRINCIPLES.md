# Indie Dev Velocity 7 原則 — 自分株式会社 Ship 規律 + Community 加速インフラ

> このドキュメントは、自分株式会社が **indie 開発者として AI fleet を最大限活用しながら継続的に ship し続ける** ための **規律 + community 加速** の **必守原則** である.
>
> **ソース**: NotebookLM Notebook [DEV Community Newsletter: AI Evolution and Developer Wins](https://notebooklm.google.com/notebook/27730002-fe8c-40ff-b2c3-431ab8f40a9a)
> DEV.to community newsletter から indie developer 向け AI 統合・agentic workflow・evaluation・productivity gain のベストプラクティス (2026-04-29 取り込み)
>
> **位置づけ**: 既存 10 設計軸 (3 層階層化済) に加え、**Layer 3 設計層** に追加する **11 番目の軸** (= indie developer 視点の規律応用層 / SECOND_BRAIN と並列)
> - PHILOSOPHY (why) / AI_DEV (how) / AI_CHARACTER (who) / IMBUE (how it feels)
> - COLLAB_AI (how it evolves) / MCP_AUTH (how it opens) / AI_VIDEO (how it appears as media)
> - VIBE_CODING (how it stays responsible) / PLATFORM_EVOLUTION (how it grows)
> - SECOND_BRAIN (how knowledge stays healthy at scale)
> - **INDIE_DEV_VELOCITY (how an indie dev keeps shipping with AI velocity)** ← 新規 11 番目

---

## なぜ必要か

自分株式会社は CEO 1 人 + 12 instance AI fleet という **究極の indie 開発体制**. しかし indie 特有の落とし穴がある:

- **Side-Project Graveyard** (= プロトタイプし続けて出荷しない) — 12 fleet 並列で AI 機能を increase だけして実出荷率が低下する罠
- **Tinkering Trap** (= 新ツール追加に時間を溶かして core ship が遅延)
- **Audience Vacuum** (= ユーザーがいないまま機能を増やす) — Phase 1 〜 Phase 4 fleet 拡大の本質的目的を忘却するリスク
- **Hand-craft の喪失** (= AI 生成コードのみで「自分の刻印」が無い製品になる)
- **Emergent AI 検出不在** (= production で AI が予期しない迂回をしているのに気付けない)
- **Prompt Drift** (= 大量の system prompt が分散して品質劣化を招く)
- **Community 切断** (= 個人開発のまま外部信号 (= hackathon / dev.to / 競合 audit) を取り込まない)

これらは 既存 10 軸では十分カバーできない **indie 特有の規律問題**. DEV.to community newsletter の知見を蒸留して、**indie として ship し続けるための 7 原則** を確立する.

= 「12 fleet AI 規模を持ちつつも、CEO 1 人 indie として **shipping velocity** + **市場接続** を保つ」ための原則層.

---

## 7 原則

### 原則 1: Neuroscience-Inspired Agent Memory (脳科学型エージェント記憶)

**ルール本文**: AI agent の記憶設計は、単純な context window でも単純な vector RAG でもなく、**人間の脳が情報を「記憶 + 忘却 + 想起」する仕組み** を模倣する. (a) 短期 working memory (= session 内 claude-mem). (b) 長期 declarative memory (= memory/ + NotebookLM Master Brain). (c) 文脈再活性化 trigger (= memory-search-hub EF / SECOND_BRAIN #7 ハイブリッド検索). (d) 適切な忘却 (= memory rotation / archive).

**なぜ重要か**: 自分株式会社の 12 fleet は同じ user (= CEO) を扱うのに各 instance で記憶が断片化している. 「以前 X を決めた」を毎回再説明する非効率は indie の **時間損失最大要因**.

**どう適用するか**:
- claude-mem (= 短期) + memory/ (= 中期) + NotebookLM Master Brain (= 長期) の **3 層は既に実装済み** (= SECOND_BRAIN dogfood)
- 不足は **想起 trigger**: 新 task 発生時に Master Brain に自動 query して past decisions を取り込む
- future: `notebooklm-context-prime` cron で 12 instance startup 時に自動 prime
- **cross-ref**: SECOND_BRAIN 原則 #2 (Atomic Linking) + #7 (Hybrid Search) と統合

### 原則 2: AI Instruction Quality Audit (指示品質監査)

**ルール本文**: AI 出力品質に問題が出たら、**まずモデルではなく system prompt / instructions を疑う**. 12 fleet で動く各 EF action / hub / agent prompt は **monthly audit** で:
1. 矛盾する指示がないか
2. 古い model 想定が残っていないか
3. ペルソナ (= AI_CHARACTER) と矛盾していないか
4. 規模拡大で stale 化した cap が残っていないか

**なぜ重要か**: Distyl AI 研究 = 指示 500 個 → 最高精度モデルでも 68% 遵守. 同じく自分株式会社も `inject-rules.txt` (= 19+ rules) + 各 EF system prompt が増殖中. 品質劣化の根本原因は **モデル側ではなく指示側** に出ることが圧倒的に多い.

**どう適用するか**:
- monthly cron: `prompt-quality-audit.yml` で全 EF system prompt を Claude API に投げて self-review
- 「inject-rules.txt が 30 rule を超えたら hook-rule-audit skill を強制起動」rule (= 既に skill 化済)
- AI 異常検出時は ROADMAP-LOG にまず prompt audit step を必須化
- **cross-ref**: AI_DEV #1 (Spec-First) + VIBE_CODING #4 (Black-Box I/O Verification)

### 原則 3: Autonomous Deployment Scaffolding (自律デプロイ scaffolding)

**ルール本文**: AI agent (= Codex / Claude Code) が **直接 production に ship** できる scaffolding を整備する. (a) Migration timestamp collision detector (= 自動 audit). (b) Deploy-prod の 22 steps fail-fast 設計. (c) `flutter analyze` + `deno lint` mandatory gate. (d) cancel-in-progress 設計で fleet 並列 push 安全. (e) Rollback path (= GitHub Release tag からの revert) 整備.

**なぜ重要か**: 自分株式会社は既に 12 fleet 並列で 1 日 50+ migration / 100+ commit を main に push している. **AI が安全に deploy できる scaffolding なしでは indie 単独運営不可能**. Win版#132 part 90-91 の 8 layer 負債 cascade は scaffolding が **不完全だった** ことを示す signal.

**どう適用するか**:
- 既存 deploy-prod.yml の 22 steps を **mandatory gate ladder** として明文化
- VIBE_CODING #5 (Minimal E2E Tests) 強化候補: PR merge 前 mandatory analyze + JS syntax check
- non-engineer が ship できる UI scaffolding (= /project-gantt + AI 分割→登録 = part 87)
- **cross-ref**: VIBE_CODING #5 (Minimal E2E) + PLATFORM_EVOLUTION #2 (Distill Best Practices)

### 原則 4: Emergent AI Behavior Watch (予期しない AI 迂回検知)

**ルール本文**: production で AI が **constraints を創造的に迂回** する「emergent behavior」を bug ではなく **adaptation signal** として扱う. (a) Anthropic API call log で予期しない tool 使用パターンを monthly grep. (b) AI 出力が制約 (= MCP_AUTH scope / token budget) を超えた時の **回避ルート** を log. (c) 1 月以内に再現テストを書いてアンチパターンとして文書化.

**なぜ重要か**: 大規模言語モデルは「禁止された X をしないで」と指示すると、表面的には従いつつ **意味的に等価な Y を発明** することがある. これを bug 扱いすると本質を見失う. **adaptation を観察 → 制約設計を再構築** が正解.

**どう適用するか**:
- monthly cron: `emergent-behavior-audit.yml` で AI tool call log を parse、未定義 pattern を Issue 化
- VIBE_CODING #4 (Black-Box I/O Verification) を拡張: 「予期しない出力 = 制約迂回 signal」rule
- AI_CHARACTER 原則と整合 (= AI が「役割」を逸脱した signal)
- **cross-ref**: AI_CHARACTER 原則 + VIBE_CODING #4

### 原則 5: Hand-Written Code as Art (手書きコードは芸術)

**ルール本文**: AI 生成コードの比率が **70% を超える** project では、**残り 30% の手書き部分を意図的に「芸術」として確保** する. (a) core 設計判断 (= architecture / domain modeling). (b) ユーザーが触れる UI の最終仕上げ (= DESIGN.md 適用). (c) ROADMAP / 戦略 / OPS-28 charter. (d) memory/ project_*.md (= 思考の記録).

**なぜ重要か**: indie product の差別化は **AI が代替不可能な領域** にしかない. 12 fleet が大量 commit を生成しても、**「自分株式会社らしさ」** = 9 原則・PHILOSOPHY・愛されるユーザー価値設計 = は CEO の手書き判断にしか宿らない. AI 生成 boilerplate と意図的に **分離** することで、product の魂を守る.

**どう適用するか**:
- ROADMAP-LOG / memory/ / docs/PHILOSOPHY.md / docs/DESIGN.md は **CEO 直筆領域** として明示 (= 12 fleet も書き込まない)
- AI 生成コードは `// AI-generated by <instance> <date>` コメント奨励 (= 透明化)
- monthly: AI 生成 vs 手書き比率を `git blame` で測定
- **cross-ref**: PHILOSOPHY 原則 #5 (商品=ユーザー価値) + #1 (CEO 感)

### 原則 6: Avoid Side-Project Graveyard (出荷規律)

**ルール本文**: indie 開発の最大死因は **「audience を持たないまま機能を増やし続ける」** 罠. これを回避する 4 規律: (a) 各機能 → **実 user メトリクス** がある. (b) 7 日以内に実 production で動作確認. (c) ship 後 14 日以内に X / dev.to / blog で外部発信. (d) 1 ヶ月以内に「使われている」根拠 (= log / 利用数 / feedback) を取得、無ければ deprecate 候補.

**なぜ重要か**: 12 fleet で 1 日 50+ commit していても、**1 user も使わない機能を増やしているだけなら値を生まない**. indie の本質は「速く出して市場と会話する」であり、tinker continue が graveyard 直行ルート.

**どう適用するか**:
- 機能新規 ship 時は development_achievements にメトリクス計測 plan も seed
- 14 日 ship without external broadcast → blog-publish 強制
- monthly: deprecate 候補機能 audit cron (= future `usage-audit.yml`)
- /project-gantt の各 task に「audience metric」column 追加候補
- **cross-ref**: PHILOSOPHY 原則 #5 (商品=ユーザー価値) + #6 (資本=時間) + #8 (KPI=昨日の自分)

### 原則 7: Community Engagement Discipline (Community 接続規律)

**ルール本文**: indie 単独運営でも **外部 community への規律的接続** は必須. (a) hackathon participation (= dev.to / Midnight Hackathon / Product Hunt 等) を quarterly 1 回以上. (b) writing challenge (= dev.to / Qiita / Zenn) を weekly 1 本以上. (c) 競合 21 社 + AI 大学 380+ 社の monthly audit. (d) X / blog で build-in-public.

**なぜ重要か**: indie が community から切断されると **市場信号が来ない** = 原則 6 の graveyard 直行. かつ hackathon / writing challenge は **強制的な ship deadline** を生み、velocity を維持する装置でもある.

**どう適用するか**:
- T-1 dispatch ルーチン (= PS#2 担当 / 既存) を継続強化 = weekly 4 本/4 弾 dev.to + Qiita 投稿
- quarterly: hackathon entry を CEO task として ROADMAP-LOG に明示
- monthly: 競合 audit cron (= 既存 competitor-monitoring) + AI 大学 provider check
- build-in-public 投稿率 = monthly KPI 化候補
- **cross-ref**: PLATFORM_EVOLUTION #3 (Client Zero) + AI_DEV #6 (Public ROADMAP)

---

## 既存軸との関係 (= 3 層階層モデル更新)

```
[Layer 1 メタ層]
  VIBE_CODING (production AI coding 責任)

[Layer 2 戦略+技術層]
  PLATFORM_EVOLUTION (Anthropic ecosystem 進化)

[Layer 3 設計層 + 応用]
  PHILOSOPHY ─ AI_DEV ─ AI_CHARACTER ─ IMBUE
  COLLAB_AI ─ MCP_AUTH ─ AI_VIDEO
  SECOND_BRAIN (知識インフラ) ─ INDIE_DEV_VELOCITY (出荷規律) ← 新規
```

**INDIE_DEV_VELOCITY** は **「indie 開発者として 12 fleet AI を抱えながら ship velocity を保つ」** 視点. SECOND_BRAIN が「**過去**の知識を健全化」、INDIE_DEV_VELOCITY が「**未来**の出荷を健全化」と対をなす.

---

## dogfood 適用優先 (= 自分株式会社 fleet 即時実装可能)

| 原則 | 状態 | 次 action |
| --- | --- | --- |
| #1 Neuroscience Memory | 🟢 部分実装 (3 層メモリ) | 想起 trigger 自動化 |
| #2 Instruction Quality | 🟢 hook-rule-audit 既存 | EF system prompt 月次 audit cron |
| #3 Deployment Scaffolding | 🟢 deploy-prod 22 steps | PR merge 前 mandatory gate ladder 文書化 |
| #4 Emergent AI Watch | 🔴 未実装 | `emergent-behavior-audit.yml` skeleton |
| #5 Hand-Written Art | 🟡 暗黙了解 | git blame ratio 測定 cron |
| #6 Side-Project Graveyard | 🟢 ship 規律 部分実装 | usage metric column /project-gantt 追加 |
| #7 Community Engagement | 🟢 T-1 dispatch 既存 | quarterly hackathon entry KPI 化 |

---

## 11 設計軸 完成度マトリクス (本 doc 追加時点)

| 軸 | baseline | 完成度 |
| --- | --- | --- |
| PHILOSOPHY | 9/9 ✅ | 100% |
| AI_DEV | 7/7 | 100% |
| AI_CHARACTER | 8/8 | 100% |
| IMBUE | 7/7 | 100% |
| COLLAB_AI | 7/7 | 100% |
| MCP_AUTH | 10/10 ✅ | 100% |
| AI_VIDEO | 6/7 → strengthening | 85% |
| VIBE_CODING | 7/7 ✅ (part 81 完成) | 100% |
| PLATFORM_EVOLUTION | 4/7 | 57% |
| SECOND_BRAIN | 4.5/7 | 64% |
| **INDIE_DEV_VELOCITY** (本 doc) | **2/7 baseline** | **29%** |
| 合計 | 71.5/77 | 92.9% |

---

## ROADMAP next steps

1. **本 doc commit** (= 11 番目軸 docs 化 / Win版#132 part 92)
2. CLAUDE.md / inject-rules.txt に Rule [INDIE-29] 追加 (= 注入 rule 19→20 拡張)
3. monthly: `prompt-quality-audit.yml` (= 原則 #2) skeleton
4. monthly: `emergent-behavior-audit.yml` (= 原則 #4) skeleton
5. /project-gantt に `audience_metric` column 追加 (= 原則 #6) cross-instance-pr → VSCode
6. quarterly: hackathon entry を CEO task 化 (= 原則 #7)
7. baseline 2/7 → 4/7 へ dogfood 累積

---

*Win版#132 part 92 / 2026-04-29 / DEV Community Newsletter 蒸留 → 11 番目軸 INDIE_DEV_VELOCITY 確立 / 既存 10 軸との cross-ref 整理 / SECOND_BRAIN (過去) ↔ INDIE_DEV_VELOCITY (未来) 対構造*
