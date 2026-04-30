# Cross-Instance PR: Top 10 期限超過 task batch handoff (= part 103 / N 回 alarm 第 5 phase)

**作成**: Win版#132 part 103 / 2026-04-30
**FROM**: Win版 (User 「上から順番に」要望 + screenshot top tasks 観測)
**TO**: 複数 instance (= 各 task 別 territory)
**優先度**: HIGH (= User 5 度目要望 / 期限超過 04/27-04/30)
**期限**: 2026-05-07 (1 週間)
**親軸**: AI_FLEET_SYNERGY #1 (Strict Instance Routing) + N-time alarm Phase 5

---

## 1. 背景

User 5 度目要望:
> 「WBS には期限が超過しているタスクや、期限がせまっているタスクがたくさんあります。**上から順番に**進めて行ってください。**このインスタンスで対応できないものは必要な対応を報告**してください」

= N-time alarm Phase 5 = **「明示指示遵守 + 透明 handoff」phase**.

screenshot (= /project-gantt 918 tasks) の **上位 12 task** を triage:

| # | Title (excerpt) | Owner instance | Win 対応? | 状態 |
| --- | --- | --- | --- | --- |
| 845 | AI役員 MCP OAuth/DCR 認証ハブ | Codex#2 | NO (= MCP_AUTH 軸) | handoff 必要 |
| 846 | AI役員 ツール実行 権限スコープ承認ゲート | Codex#2 | NO | handoff 必要 |
| 1265 | 機密データ向けエッジデバイス対応オフライン (Pleias) | VSCode | NO (= UI 重) | handoff 必要 |
| 1267 | セッション名プレフィックス by my_web_app | Win | **YES** ✅ | **part 103 で完了** |
| 1268 | 対話型 セッションリモートコントロール | Codex#2 | NO | handoff 必要 |
| 1269 | 食生活改善 食事内容記録 栄養バランス | VSCode | NO (= 新 lib/page) | handoff 必要 |
| 1036 | N3 schedule-hub:notion.sync_roadmap action | Codex#2 | NO (= EF) | handoff 必要 |
| 1037 | N4 schedule-hub:notion.sync_memory_index action | Codex#2 | NO (= EF) | handoff 必要 |
| 1123 | LRM 自己修正プランナー AI役員 Goal-Plan-Action | Codex#2 + VSCode | partly | handoff 必要 |
| 1124 | AI役員 GPA 評価ダッシュボード トレースデバ | VSCode | NO (= UI) | handoff 必要 |
| 926 | 12インスタンス並行開発 リアルタイム競合予測 | Win | **YES** ✅ | **part 103 で完了** |

**Win territory done in part 103** (= 直接実装):
- ✅ #1267: docs/CLAUDE_CODE_SESSION_PREFIX.md 文書化 + env var convention 確立
- ✅ #926: scripts/instance_conflict_predictor.py 実装 + 初回 audit (= risk High 検出 / 6 file overlap + multi migration cluster)

**handoff 必要** (= 残 9 task):

## 2. Codex#2 territory (= 6 件)

### #845 / #846: MCP_AUTH 認証ハブ + 承認ゲート

**期待 implementation**:
- `supabase/functions/_shared/mcp_auth_guard.ts` 拡張 (= 既存 part 49 skeleton 強化)
- OAuth + DCR + WorkOS AuthKit 統合
- AI 役員 (= ai-hub virtual_organization action) 用 scope 承認 gate
- MCP_AUTH 10 原則 (= docs/MCP_AUTH_SECURITY_PRINCIPLES.md) baseline 維持

**期限**: 2 週間 (= 5/14)

### #1268: 対話型 セッションリモートコントロール

**期待**: Claude Code v2.1+ remote control 機能を fleet 横断で標準化. settings 系 + GHA worker 連携.

### #1036 / #1037: schedule-hub Notion sync action

**期待**:
- `notion.sync_roadmap` action (= ROADMAP-LOG → Notion roadmap database)
- `notion.sync_memory_index` action (= MEMORY.md → Notion knowledge base)
- 既存 schedule-hub EF に action 追加 (= EF カウント影響なし)

### #1123: LRM 自己修正プランナー (Goal-Plan-Action)

**期待 EF 部分**:
- ai-hub に `agent.goal_plan_action` action 追加
- 入力: ai 役員 task + 現状 / 出力: revised goal + plan + next action
- LRM (Latent Reasoning Model) 風の自己修正 loop

(UI 部分は VSCode territory)

## 3. VSCode territory (= 4 件)

### #1265: 機密データ向けエッジデバイス対応 オフライン (Pleias)

**期待**:
- オフライン LLM 統合 UI (= Pleias 等)
- ローカルモデル選択画面 / 機密 mode toggle
- ai-hub action `provider.local_invoke` (= Codex#2 並行 PR)

### #1269: 食生活改善 食事内容記録 栄養バランス

**期待**:
- 新 lib/pages/dietary_log_page.dart
- 食事写真 + AI 栄養素抽出 (= ai-hub action `vision.nutrition`)
- 推奨は AI_VIDEO 軸 / IMBUE 軸の dogfood

### #1123 (UI 部分): AI 役員 Goal-Plan-Action UI

**期待**: AI 役員 task 詳細画面に goal_plan_action 自動修正 button 追加.

### #1124: AI 役員 GPA 評価ダッシュボード トレースデバ

**期待**:
- 新 lib/pages/ai_executive_gpa_page.dart
- 各 AI 役員の意思決定 trace 表示 + GPA (Grade Point Average) 算出
- AI_CHARACTER 軸 dogfood

## 4. production console errors (= P0 / 別 PR 必要)

screenshot 観察:
```
Uncaught Error at Object.b_ (main.dart.js:4079:30)
Null check operator used on a null value at Object.aa
Another exception was thrown: Instance of 'minified:nl<void>'
Could not find a set of Noto fonts
```

= part 91 で SyntaxError 解消後の **新 production runtime errors**.

**hypothesis**:
- 最近の VSCode UI 改修で null check 漏れ
- Noto fonts は WARN (= non-blocking)
- minified:nl<void> は cascade

**期待 action (= VSCode territory)**:
1. `flutter run --release --no-tree-shake-icons` でローカル再現
2. browser console error stack trace を `gh issue create` で報告
3. main.dart.js:4079 周辺 + Object.aa の null deref を fix
4. integration test 強化 (= VIBE_CODING #5 dogfood)

= 別 cross-instance-pr 起票候補 (= Win audit + VSCode fix lane).

## 5. 受入基準

各 instance:
- [ ] 担当 task の Issue を `gh issue comment` で「対応開始」宣言
- [ ] 1 週間以内 (= 5/7) に 1 件以上着手 (= 0% → 30%+)
- [ ] 完了時 Issue close + ROADMAP-LOG 追記
- [ ] 本 cross-instance-pr `done/` 移動 (= 全 task 完了時)

## 6. Win 残り action

- [x] **#1267 完了** (= docs/CLAUDE_CODE_SESSION_PREFIX.md)
- [x] **#926 完了** (= scripts/instance_conflict_predictor.py + 初回 audit)
- [x] **本 cross-instance-pr 起票** (= top 10 batch handoff)
- [ ] WBS migration UPDATE (= 本 part 末尾)
- [ ] N-time alarm Phase 5 を docs/N_TIME_ALARM_PATTERN.md に追記

## 7. AI_FLEET_SYNERGY 軸 dogfood

- 原則 #1 (Strict Instance Routing): 11 task を 4 instance に明示 routing
- 原則 #5 (Memory Continuity): 本 cross-instance-pr が **fleet 横断 state** を bridge
- 原則 #7 (Visual Validation): production errors を VSCode へ visual debug 委譲

---

*Win版#132 part 103 / 2026-04-30 起票 / Top 10 期限超過 batch handoff / N-time alarm Phase 5 / Win → 4 instance 並列 lane*
