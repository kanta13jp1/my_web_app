# 四半期ロードマップ — 自分株式会社

Status: v1 (2026 Q3 計画 baseline)
Date: 2026-06-06
Owner: Win Claude (L3 設計レーン / architect)
WBS: `be0354f6-10fb-4b77-a77a-52515e5b4fd7` [企画] 四半期ロードマップ策定
Sources: [`PRD.md`](PRD.md) / [`PHILOSOPHY.md`](PHILOSOPHY.md) / [`AI_DRIVEN_DEV_OPERATING_MODEL.md`](AI_DRIVEN_DEV_OPERATING_MODEL.md) (SDLC 7 工程) / WBS 実データ (3,143 tasks / 2026-06-06 anon REST 実測) / 競合 21 社 / [`GROWTH_STRATEGY_ROADMAP.md`](GROWTH_STRATEGY_ROADMAP.md)

---

## 0. このドキュメントについて

- **目的**: 競合監視・ユーザー要望・WBS 進捗を反映し、次四半期の優先順位を **SDLC 7 工程別に再配置**する。タスク `be0354f6` の要件そのもの。
- **位置づけ**: [`PHILOSOPHY.md`](PHILOSOPHY.md) (恒久理念) → [`PRD.md`](PRD.md) (製品定義 = 何を作るか) → **本ロードマップ (四半期の優先順 = いつ・どの順で寄せるか)** → WBS (個々のタスク実行)。理念と実行の間にある「四半期の意思決定」層。
- **運用 (living doc)**: 四半期ごとに v(n+1) へ改訂。月次で §3 フェーズバランスと §4 進捗を見直し、薄く保つ。
- **v1 注記**: 既存 canon (PRD / 運用モデル / WBS 実測 / 競合) から codify した baseline。L1 (Antigravity+Gemini) 探索結果が出たら persona/機能優先度を継続精緻化する (= 原則どおり「固定 → 検証 → 改訂」)。

## 1. 計画ホライズン

- **基準日**: 2026-06-06。現四半期 Q2 (4–6 月) は収束間際。
- **主対象 = Q3 2026 (7–9 月) = MVP ローンチ四半期** (milestone `mvp-launch` / **1,000 users** / 2026-09-30)。
- **副 = Q4 2026 (10–12 月)** = ローンチ後ハードニング + 課金準備 (milestone `paying-100` / 2027-03-31 への助走)。
- **マイルストーン軸**: legal-setup → **mvp-launch (Q3 山場)** → seed-round → paying-100 → series-a → audit-ready → ipo-listed。

## 2. インプット要約 (3 軸)

タスク記述「競合監視・ユーザー要望・WBS 進捗を反映」に対応。

- **競合監視 (21 社)**: 差別化は 2 点 — ① 競合 (Notion/Evernote/MoneyForward 等) からの**移行容易性**、② **AI が自然に価値を生む**こと。詳細は [`roadmaps/COMPETITOR_ANALYSIS_2025.md`](roadmaps/COMPETITOR_ANALYSIS_2025.md) / [`GROWTH_STRATEGY_ROADMAP.md`](GROWTH_STRATEGY_ROADMAP.md)。
- **ユーザー要望**: WBS の Feature Request 系 (category「GitHub Issue / Feature Request」140 件)。高優先の代表は **#1495** (iOS/Android 同時リリース) と **#1950** (ブログ/ニュース配信の本番 E2E + 完全自動化)。
- **WBS 進捗**: §3 のフェーズバランスレビューに集約。

## 3. WBS フェーズバランスレビュー (実データ / 2026-06-06)

remaining_work「WBS phase balance review」に対応。Supabase anon REST で実測。

| 指標 | 値 |
|------|----|
| 総タスク | 3,143 |
| 完了 | 2,211 (70.3%) |
| 未完了 | 932 |
| └ うち SDLC `phase` 未設定 (null) | **879 / 932 = 94.3%** |
| └ うち phase 設定済 | 53 |
| 未完了の高優先 (priority=high) | 75 |

- **phase 設定済 53 件の内訳**: impl 23 / ops 18 / test 5 / design 4 / planning 1 / release 1 / maintenance 1。タグ済みでも **impl+ops に集中** (41/53)、上流 (企画/設計) と下流 (リリース/保守) は薄い。
- **所有者別 (未完了)**: codex 系 (実装) が最多、次いで自動生成ルーチン (schedule/gha) 64+。Win (L3) は本タスクを含めごく少数 = L3 が設計/レビュー主体である証で正常。
- ⚠️ **中心的所見**: 未完了の **94% が SDLC phase 未タグ**。→「SDLC 工程別に再配置」をデータ駆動で行う土台が今は無い。**Q3 の前提整備として phase バックフィルを設計タスク化**する (§4-設計 / §6-R2)。それまで本ロードマップの工程配分は **近似値**として扱う。

## 4. 次四半期 (Q3 2026) 優先順位 — SDLC 7 工程別

各工程の Q3 重点と主レーン。L3 (本インスタンス) は設計/レビュー/運用/ゲートを駆動し、実装系は L2 (Codex) への handoff。

| # | 工程 | Q3 重点 | 主レーン |
|---|------|--------|---------|
| 1 | 企画 (planning) | MVP スコープ確定 (PRD 週次更新 / L1 探索の persona 検証反映)。本ロードマップ。 | L1 / L3 review |
| 2 | 設計 (design) | **phase タグ taxonomy バックフィル設計** (§3 所見の解消)。新機能 ADR (ADR 運用は part 241 稼働)。 | L3 |
| 3 | 実装 (impl) | 6 部署コア機能の MVP 仕上げ (**人事=健康 最優先**)。モバイル #1495 / 配信自動化 #1950。 | L2 (Codex) |
| 4 | テスト (test) | ブログ/ニュース配信の**本番 E2E** (#1950)。minimal-E2E gate 維持。 | L2 / L3 gate |
| 5 | リリース (release) | モバイル**同時リリース自動化** (#1495 iOS/Android)。deploy-prod gate 堅牢化。 | L2 / L3 gate |
| 6 | 運用 (ops) | cron ルーチン健全性 (Rule 17) / CI-CD コスト監査 (part 240c routine) / residuals。 | L3 + routines |
| 7 | 保守 (maintenance) | バックログ衛生: 879 未タグへの phase 付与、WBS 重複解消、stale worktree 整理。 | L3 triage / L2 impl |

**優先順の原則**: **人事 (健康) > 生存指標 (MVP 1,000 users) > 機能拡張**。テスト/リリース工程 (delivery) を最優先で守り、不確実な機能レーンは後段に置く。

## 5. Q4 2026 概観 (軽量)

- ローンチ後の安定化 + 課金導線 (paying-100 への助走)。
- phase タグ運用が定着していれば、Q4 は工程バランスを**データ駆動で再配置** (本ロードマップ v2)。
- 詳細は Q3 ローンチ実績を見て v2 で確定する (固定 → 検証 → 改訂)。

## 6. リスクと対応 (Risk Notes)

recovery_plan「ロードマップが遅延したら配信タスクを動かす前に低確度の機能レーンを削る」を中核に据える。

- **R1 MVP 期日 (2026-09-30)**: 遅延時は **低確度の機能レーンを先に削り、テスト/リリース (delivery) タスクを死守**する。北極星 (ウェルビーイング) を犠牲に短期 DAU を追わない (原則 8・9)。
- **R2 phase 94% 未設定**: 工程別再配置がデータ駆動でできない。→ phase バックフィルを Q3 設計タスク化 (§4-2)。完了までは工程配分を近似で運用。
- **R3 レーン駆動の制約 (正直)**: L3 (Win Claude) は L1/L2 を**駆動できない**。実装の前進は user が各 IDE で L1/L2 を回すことに依存する。本ロードマップは命令でなく **handoff 用の計画成果物**。
- **R4 バックログ肥大**: 未完了 932 件、自動生成ルーチン (schedule/gha) が継続増。→ WBS 重複解消 + stale 自動 close で信号対雑音比を維持。
- **R5 単独創業者キャパ / FATIGUE**: 英雄的バーストより持続可能なペース。疲労時は scope を 1 タスクに絞る (本セッションの運用方針と整合)。

## 7. 原則整合 (Philosophy Alignment)

[`PHILOSOPHY.md`](PHILOSOPHY.md) 9 原則で **7+/9 ✅**。優先順は原則 8 (KPI = North-Star 優先) / 原則 4 (mentor = 最終決定権はユーザー) / 原則 9 (IPO = ウェルビーイング) から導出。delivery 死守は原則 6 (商品 = 価値)。

## 8. 運用 (Living Document)

- 四半期ごとに改訂し、月次で §3 フェーズバランスと §4 進捗を見直す。常に薄く保つ。
- スコープ拡大は feature Issue に分割 (本体には書かない)。重要な設計判断は [`adr/`](adr/README.md) に ADR 化。
- §3 の実測値は anon REST から再取得して更新する。

## Links

- 理念: [`PHILOSOPHY.md`](PHILOSOPHY.md)
- 製品定義: [`PRD.md`](PRD.md)
- 運用モデル (SDLC 7 工程 / 3 レーン): [`AI_DRIVEN_DEV_OPERATING_MODEL.md`](AI_DRIVEN_DEV_OPERATING_MODEL.md)
- 成長戦略 / ビジョン: [`GROWTH_STRATEGY_ROADMAP.md`](GROWTH_STRATEGY_ROADMAP.md)
- 競合分析: [`roadmaps/COMPETITOR_ANALYSIS_2025.md`](roadmaps/COMPETITOR_ANALYSIS_2025.md)
- 実行計画: WBS (project-gantt) / task `be0354f6-10fb-4b77-a77a-52515e5b4fd7`
