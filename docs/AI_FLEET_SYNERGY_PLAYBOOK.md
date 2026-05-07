# AI Fleet Synergy 7 原則 — Claude Code × Codex 協調運用方法論

> このドキュメントは、自分株式会社の **2 instance fleet (Win版 Claude Code + Win版 Codex CLI / 旧 12 instance は 2026-05-04 dormant 化)** が **互いの強みを引き出して合計最大出力** を出すための **fleet 運用 playbook** である. 7 原則は instance 数に依存せず、2 instance 体制でも完全に妥当.
>
> **ソース**: NotebookLM Notebook [Codex vs Claude Code: The Ultimate AI Development Synergy](https://notebooklm.google.com/notebook/bc58b50b-5fc4-4840-9a62-b397d6d3b65a)
> Claude Code と Codex CLI の最適な使い分け・連携・モニタリング・guardrail 設計のベストプラクティス (2026-04-30 取込).
>
> **位置づけ**: 既存 11 設計軸 + **12 番目** として **fleet 運用方法論層** に追加.
> - PHILOSOPHY (why) / AI_DEV (how) / AI_CHARACTER (who) / IMBUE (how it feels)
> - COLLAB_AI (how it evolves) / MCP_AUTH (how it opens) / AI_VIDEO (how it appears as media)
> - VIBE_CODING (how it stays responsible) / PLATFORM_EVOLUTION (how it grows)
> - SECOND_BRAIN (how knowledge stays healthy at scale)
> - INDIE_DEV_VELOCITY (how an indie dev keeps shipping with AI velocity)
> - **AI_FLEET_SYNERGY (how Claude Code + Codex CLI orchestrate as one)** ← 新規 12 番目

---

## なぜ必要か

自分株式会社の fleet は **Win版 Claude Code + Win版 Codex CLI = 2 instance** という構成 (2026-05-04 〜 / 旧 12 instance は dormant). それぞれの AI が持つ **異なる得意領域** を理解せずに使い分けないと:

- **Claude Code を batch CI に使う** = 高度モデルで定型作業 = cost 浪費 (= INDIE #2 違反)
- **Codex に architecture design を任せる** = 浅い設計で deploy 失敗 = 連鎖 fix (= part 91 cascade のような)
- **fleet drift** = CLAUDE.md 巨大化で各 instance が古い state を hallucinate = 矛盾 commit
- **memory 不連続** = compact 時に context 蒸発 → 次 session で前回判断を再説明
- **Visual validation 不在** = UI 改修が API 観点だけで進む → ユーザー目線確認漏れ
- **新機能 watch 抜け** = Claude Code / Codex CLI 月次新機能を見逃し → 古い使い方継続

= 「**2 instance を 1 つの organism として動かす**」(= 旧 12 instance 時代の運用方法論を継承) 運用方法論が必要.

INDIE_DEV_VELOCITY (= indie 視点の規律) と直交する **「fleet 視点の運用」** を独立軸として確立.

---

## 7 原則

### 原則 1: Strict Instance Routing (= AI 別役割分担の厳格化)

**ルール本文**: 各 task を 2 instance (Win Claude / Win Codex) のどちらに振るかを **5 質問 + WORKDIR-ISOLATION dual-axis** で機械的に判定. 直感判断禁止.

| task 性質 | route 先 | 理由 |
| --- | --- | --- |
| アーキテクチャ判断 / 長期 refactor / 深い reasoning | **Claude Code (Win / VSCode)** | best coder |
| 高 throughput batch / CI/CD pipeline / 端末重作業 | **Codex CLI #1 / #2** | best worker |
| Flutter UI / DESIGN.md 適用 | **VSCode** | UI 専任 |
| migration SQL / docs / 動画 pipeline | **Win** | docs + schema territory |
| WF health / Rule17 audit | **PS#1** | WF health 専任 |
| T-1 dispatch / dev.to | **PS#2** | publication 専任 |
| AI 大学 provider 追加 | **PS#3** | AI 大学 routine 専任 |
| EF (Deno) / GHA workflow | **Codex#2** | GHA 専任 |

**なぜ重要か**: best coder で batch をやらせるのは時間と cost の浪費. best worker に architecture を任せるのは 後 hotfix 連鎖の入口. 役割を機械的に振り分けることで **fleet 全体の velocity が最大化**.

**どう適用するか**:
- 既存 CLAUDE.md routing matrix + WORKDIR-ISOLATION rule を継続強化
- 月次 audit cron: 過去 30 日の commit を instance 別に集計し、想定役割と乖離があれば警告
- **cross-ref**: INDIE_DEV_VELOCITY #2 (Instruction Quality) / PLATFORM_EVOLUTION #5 (Effort Router)

### 原則 2: Plan-Execute-Review Synergy

**ルール本文**: 重要 task は **Claude が plan → Codex が実行 → Claude が validate** の 3 段 pipeline. 単一 AI で完結させない.

```
[Step 1: Claude]   architecture design + ADR record
       ↓
[Step 2: Codex]    rapid scaffolding + parallel test
       ↓
[Step 3: Claude]   /ultrareview による rigorous check
```

**なぜ重要か**: 1 AI 単独では「**設計 bias**」「**実装 bias**」「**review bias**」の 3 種混在. 役割を分離することで **bias を相互打消** + **cost 最適化** (= 高 throughput 実装は安価な Codex / 深層 review は Claude).

**どう適用するか**:
- 重要 cross-instance-pr (= 機能新規 / migration schema) で本 pipeline を必須化
- 簡単 task (= 1 file 完結 / typo fix) は 単一 AI 完結 OK
- ADR (Architecture Decision Record) を `docs/adrs/<YYYYMMDD>_<slug>.md` 形式で蓄積
- **cross-ref**: VIBE_CODING #5 (Minimal E2E) / COLLAB_AI #4 (Co-Reasoning)

### 原則 3: Automate Feature Monitoring via Codex (= Claude/Codex 自身の新機能 watch)

**ルール本文**: Codex の Automation/Schedule 機能を使って **Claude Code + Codex CLI の changelog を月次 scrape** → 新機能を Issue 化 → 自動 PR 候補. fleet 自身が **fleet 自身を進化** させる loop.

**なぜ重要か**: Anthropic / OpenAI Codex は **月次で新機能 release**. 手動チェックでは見逃す → 古い使い方継続 → fleet velocity 停滞.

**どう適用するか**:
- 新規 GHA workflow `.github/workflows/ai-tool-changelog-watch.yml` (= cron monthly):
  - Anthropic blog + Codex CLI changelog を fetch
  - 新機能 candidate を Claude API で要約
  - GitHub Issue 自動起票 (label: `ai-tool-update`)
  - 重要度高なら cross-instance-pr 自動生成 candidate
- Codex#2 territory で実装 (= GHA + Deno EF 担当)
- **cross-ref**: PLATFORM_EVOLUTION #2 (Distill Best Practices) / INDIE_DEV_VELOCITY #7 (Community Engagement)

### 原則 4: Pointer-Based Configuration (= CLAUDE.md / AGENTS.md ≤ 50 lines)

**ルール本文**: 各 instance が読む configuration file (= CLAUDE.md / AGENTS.md / inject-rules.txt) は **巨大化禁止 / 50-200 行上限**. それ以上は **pointer 化** (= "details: docs/X.md") して immutable ADR + executable test suite を **single source of truth** とする.

**2026-05-07 #1706 update**: Codex 側の persistent memory / instruction pointer は **`AGENTS.md` + `~/.codex/AGENTS.md` + `~/.codex/config.toml`** を検出対象に含める. 2 instance 制では Claude Code #1 が policy/review, Codex #1 が `scripts/check_versions.py` evidence と scoped PR を担当する.

**なぜ重要か**: configuration 巨大化 = 各 instance が古い state を hallucinate して矛盾 commit を発する **fleet drift** の根本原因.
- 現状診断: CLAUDE.md ~200 行 / inject-rules.txt 30+ rules → **境界線**
- 各 rule に詳細 docs を pointer 化することで **bloat 防止**

**どう適用するか**:
- 月次 audit cron: CLAUDE.md / inject-rules.txt の行数監視 (= 200 / 500 行超過で警告)
- 詳細 (= 9 原則のチェックリスト等) は docs/*.md に pointer 化
- ADR pattern: `docs/adrs/<YYYYMMDD>_<decision>.md` で immutable な意思決定記録
- **cross-ref**: SECOND_BRAIN #1 (階層型ナレッジ厳格分離) / hook-rule-audit skill

**競合 Pointer-Based Config 比較** (2026 Q2 / `docs/STRATEGIC_INTELLIGENCE_2026Q2.md` §1 より):

| 競合 | Config 方式 | fleet drift リスク |
|------|-----------|------------------|
| Cursor Team | editor settings + .cursorrules (= 単一 flat file) | 1 instance のみ / drift なし but 拡張不可 |
| Devin | 完全自律 / config なし (= agent が自己判断) | 不透明 / hallucinate 検知不能 |
| Cline / RooCode | `.clinerules` (= 単一 flat) | multi-instance 未対応 |
| **自分株式会社** | **CLAUDE.md (80 行) + pointer → docs/ + inject-rules.txt** | **2 instance で drift 最小 / pointer 分散で bloat 防止** |

**自分株式会社優位**: 唯一 multi-instance を想定した pointer hub 設計. 競合が 1 instance flat config の間に、2 instance × pointer 分散 × 月次 audit cron の 3 層防衛を実装.

### 原則 5: Memory & State Continuity Hooks (= 12 fleet の記憶連続性)

**ルール本文**: Claude Code の **PreCompact + StatusLine hooks** を全 instance で標準化し、context 蒸発前に transcript を自動 backup. **Git commit を fleet 間 state passing の primary bridge** として強制.

**なぜ重要か**: Claude Code の context window は有限. compact が走るたびに **「前回これを決めた」** の記憶が蒸発し、次 session で再説明 cost. fleet 全体で乗算.

**どう適用するか**:
- `~/.claude/settings.json` に PreCompact hook 追加 (= 全 2 instance):
  ```json
  "hooks": {
    "PreCompact": "powershell -ExecutionPolicy Bypass -File ~/.claude/hooks/backup-transcript.ps1"
  }
  ```
- StatusLine hook で current task を表示 (= 現在の routing 判断を可視化)
- Git commit message を **descriptive** に (= "WIP: <next instance reads this>" 形式)
- claude-mem (SQLite + Gemini 圧縮) との連携継続
- **cross-ref**: SECOND_BRAIN #3 (Master Index + Daily Notes) / SECOND_BRAIN #5 (Query 永続化)

### 原則 6: Deterministic Guardrails (= AI 自己認証禁止)

**ルール本文**: Claude も Codex も **自己認証禁止**. 必ず外部 deterministic check を hook で強制. Claude Code `PostToolUse` hook で linter (Oxlint / Ruff / dart format) を実行 → JSON で error を返す → AI が自動 self-correct.

Codex は **Stop Hooks** で CI/CD pipeline pass まで task 完了をブロック.

**なぜ重要か**: AI は「**それっぽく完了**」を返すことがある. 人間 review もスケールしない → fleet 規模では **deterministic gate** だけが信頼可能な validation.

**どう適用するか**:
- Claude Code `~/.claude/hooks/post-tool-use.sh` (= 全 instance):
  - file edit 後に dart format / flutter analyze を強制
  - error あれば JSON return → Claude が自動修正 retry
- Codex Stop Hook: `gh run wait` で CI/CD pass 確認まで block
- ファイル種別ごとの linter 標準化:
  - Dart → `dart format --set-exit-if-changed` + `flutter analyze --fatal-infos`
  - TS/JS → `oxlint`
  - Python → `ruff`
- **cross-ref**: VIBE_CODING #4 (Black-Box I/O) / INDIE_DEV_VELOCITY #2 (Instruction Quality)
- **Budget cap rule (2026-06-01〜)**: Copilot Code Review が Actions minutes 消費開始。
  `quota-monitor.yml` で Copilot review minutes をガード。CI budget = Actions minutes であることを認識し、不要な Copilot review トリガーを避ける。

### 原則 7: Visual/GUI Validation Routing to Codex

**ルール本文**: rendered application との対話 / E2E test / UI 視覚確認 は **Codex の Computer Use + integrated browser** に強制 routing. Claude Code (= API ベース) は visual validation 不可 (= flutter web の screen 出力を実際に観察できない).

**なぜ重要か**: UI bug の多くは **visual で初めて気づく** (= part 86 column resize / tooltip fix が典型例). API 出力では検出不能.

**どう適用するか**:
- 全 UI 改修 PR で **「Codex visual validation」 step** 必須:
  - Codex#1 が implementation 後 Codex#1 自身が browser で screenshot 取得 → 比較
- Playwright integration test を Codex routing 標準化
- 📱 mobile 版 (Claude Code mobile push 設定済) と連携: 実機 UAT は人間 + 📱
- **cross-ref**: AI_VIDEO #5 (Provenance) / IMBUE #6 (UX 体験設計)

---

## 既存 11 軸との関係

```
[Layer 1 メタ層]
  VIBE_CODING (production AI coding 責任)
  AI_FLEET_SYNERGY (12 fleet 協調運用) ← 新規 12 番目 / メタ層に追加

[Layer 2 戦略+技術層]
  PLATFORM_EVOLUTION (Anthropic ecosystem 進化)

[Layer 3 設計層 + 応用]
  PHILOSOPHY ─ AI_DEV ─ AI_CHARACTER ─ IMBUE
  COLLAB_AI ─ MCP_AUTH ─ AI_VIDEO
  SECOND_BRAIN (過去) ─ INDIE_DEV_VELOCITY (未来) ─ AI_FLEET_SYNERGY (横断) ← 横断 layer
```

**AI_FLEET_SYNERGY** は VIBE_CODING と並ぶ **メタ層 第 2 軸**:
- VIBE_CODING = 「production AI coding **責任**」
- AI_FLEET_SYNERGY = 「12 fleet **協調運用**」

両者は **対**: VIBE = 個別 instance の責任 / SYNERGY = 集合体の運用. これで **メタ層に「責任 ↔ 運用」のペア構造** 完成.

---

## dogfood 適用優先 (= 自分株式会社 fleet 即時実装可能)

| 原則 | 状態 | 次 action |
| --- | --- | --- |
| #1 Strict Instance Routing | 🟢 既存 CLAUDE.md routing matrix で部分実装 | 月次 audit cron |
| #2 Plan-Execute-Review Synergy | 🟡 cross-instance-pr で部分実装 | ADR 蓄積開始 |
| #3 Automate Feature Monitoring | 🔴 未実装 | **本 part で Codex#2 cross-instance-pr 起票** |
| #4 Pointer-Based Configuration | 🟡 CLAUDE.md ~200 行 / inject-rules ~500 行 | 月次行数監視 cron |
| #5 Memory & State Continuity Hooks | 🟡 claude-mem 既存 / PreCompact hook 未 | hook 設定共有化 |
| #6 Deterministic Guardrails | 🟢 dart format / flutter analyze 部分実装 | PostToolUse hook 標準化 |
| #7 Visual/GUI Validation Routing | 🔴 未実装 | UI PR で Codex visual step 必須化 |

---

## 12 設計軸 完成度マトリクス (本 doc 追加時点)

| 軸 | baseline | 完成度 |
| --- | --- | --- |
| PHILOSOPHY | 9/9 ✅ | 100% |
| AI_DEV | 7/7 | 100% |
| AI_CHARACTER | 8/8 | 100% |
| IMBUE | 7/7 | 100% |
| COLLAB_AI | 7/7 | 100% |
| MCP_AUTH | 10/10 ✅ | 100% |
| AI_VIDEO | 6/7 | 85% |
| VIBE_CODING | 7/7 ✅ | 100% |
| PLATFORM_EVOLUTION | 4/7 | 57% |
| SECOND_BRAIN | 4.5/7 | 64% |
| INDIE_DEV_VELOCITY | 4.5/7 | 64% |
| **AI_FLEET_SYNERGY** (本 doc) | **3/7 baseline** | **43%** |
| 合計 | 75/84 | 89.3% |

---

## ROADMAP next steps

1. **本 doc commit** (= 12 番目軸 docs 化 / Win版#132 part 98)
2. CLAUDE.md / inject-rules.txt に Rule [SYNERGY-30] 追加
3. cross-instance-pr → Codex#2: `ai-tool-changelog-watch.yml` 実装 (= 原則 #3)
4. monthly cron: instance 役割 audit + CLAUDE.md 行数監視 (= 原則 #1 + #4)
5. ADR 形式確立: `docs/adrs/<YYYYMMDD>_<decision>.md` (= 原則 #2)
6. PreCompact hook 全 2 instance 標準化 (= 原則 #5)
7. PostToolUse linter hook 全 instance 標準化 (= 原則 #6)
8. UI PR で Codex visual validation step 必須化 (= 原則 #7)

---

*Win版#132 part 98 / 2026-04-30 / NotebookLM `bc58b50b` 蒸留 → AI_FLEET_SYNERGY 12 番目軸確立 / Claude Code × Codex CLI 協調運用方法論 / メタ層 「責任 (VIBE) ↔ 運用 (SYNERGY)」ペア完成 / 5 日 12 軸 89+ 原則到達*
