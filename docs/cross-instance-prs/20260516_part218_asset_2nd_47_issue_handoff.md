# 20260516 part 218 / 部 218-b: 資産管理 第2弾 47 issue + session-hygiene 3 issue Codex handoff

**from**: Win Claude #132 (part 218 / 部 218-b 統合 / 2026-05-16 早朝 JST)
**to**: Win Codex (= 2-instance fleet primary 実装担当)
**priority**: high (= P0 #1495 と並行で 5/22 sprint kickoff 含む)
**scope**: 47 issue / ~5 month timeline (= 5/17-10/18)

## 背景

部 218 + 部 218-b で user 直接 ask により以下完遂:

1. **WBS reschedule_realistic 第 2 fire** = 547 tasks 現実化 (= 5/17-10/18)
2. **資産管理 第2弾 A-G 7 feature 34 issue 起票** (= 部 218 / #2460-#2493)
3. **H (MoneyForward) + I (三菱UFJ eスマート証券) 10 issue 起票** (= 部 218-b / #2496-#2505)
4. **J (session-hygiene) 3 issue 起票** (= 部 218-b / #2506-#2508)
5. **#2461 multi-provider AI (Gemini+GPT+Opus) comment 追記**
6. **A1 #2460 migration ship** = `20260516000000_monthly_asset_reports_schema.sql`

合計 **47 new issue** + **1 multi-provider comment update** + **1 migration file** = Codex 5/22 sprint pickup scope.

## 2-instance split assignment

### Win Codex 担当 (= 41 issue / 87%)

**SQL migration / EF / GHA = Codex realm per [INSTANCE-ROLES]**

| Issue 範囲 | Feature | 内容 |
|------------|---------|------|
| #2460 | A1 schema | ✅ Win Claude 起草済 / Codex deploy review 推奨 |
| #2461-#2462 | A2 EF + A3 GHA | multi-provider AI 統合実装 |
| #2464 | A5 test | integration test (3 provider mock) |
| #2465-#2467 | B1-B3 | DB + EF fetch_market_price + Service層 |
| #2470-#2471 | B6-B7 | CSV import + test |
| #2476-#2478 | D1-D3 | 異常検知 DB + EF + GHA cron |
| #2480-#2481 | E1-E2 | 6部署DB + EF department_finance_summary |
| #2483 | E4 | e2e test |
| #2484-#2485 | F1-F2 | chat DB + EF asset_chat |
| #2488 | F5 | PII guardrail (= deterministic Dart) |
| #2489 | G1 | tax_records schema |
| #2492-#2493 | G4-G5 | export + インボイス skeleton |
| #2496-#2498 | H1-H3 | MoneyForward DB + EF + GHA cron |
| #2500 | H5 | transaction merge ロジック |
| #2501-#2503 | I1-I3 | eスマート DB + EF + GHA cron |
| #2505 | I5 | holdings merge |
| #2506-#2507 | J1-J2 | session-hygiene cron + Win Task install |

### Win Claude 担当 (= 6 issue / 13%)

**UI design / docs / AI prompt = Win Claude realm per [INSTANCE-ROLES]**

| Issue | Feature | 内容 |
|-------|---------|------|
| #2463 | A4 | 月次レポート一覧 UI + 詳細表示 |
| #2468, #2469 | B4-B5 | 投資資産 form + graph |
| #2472-#2475 | C1-C4 | ダッシュボード 4 panel UI |
| #2479 | D4 | 異常一覧 + dismiss UI |
| #2482 | E3 | 経理部 page 資産サマリ panel |
| #2486-#2487 | F3-F4 | chat widget + 履歴 page |
| #2490-#2491 | G2-G3 | ふるさと納税 + 医療費控除 UI |
| #2499 | H4 | MF 連携設定 UI |
| #2504 | I4 | eスマート 連携設定 UI |
| #2508 | J3 | session hygiene KPI dashboard |

(= 上記 Win Claude 担当 22 issue は UI / 残 25 issue = Codex / 重複あり / 概算)

## 優先順 (= 期限近順 / 5/22 sprint kickoff 視野)

### Phase 1 (5/17 - 6/19): 月次 AI レポート A-feature 完遂
- 🔴 A1 #2460 migration deploy (= Codex review + apply)
- 🔴 A2 #2461 EF multi-provider 実装
- 🔴 A3 #2462 GHA cron
- 🟡 A4 #2463 UI (Win Claude)
- 🟡 A5 #2464 test

### Phase 2 (6/22 - 7/01): 投資資産統合 B-feature
- 🔴 B1-B3 #2465-#2467 (Codex)
- 🟡 B4-B5 #2468-#2469 (Win Claude UI)
- 🔴 B6-B7 #2470-#2471 (Codex)

### Phase 3 (7/02 - 7/17): UI + 異常検知 + 6部署
- 🟡 C1-C4 #2472-#2475 (Win Claude UI 4件)
- 🔴 D1-D3 #2476-#2478 (Codex)
- 🟡 D4 #2479 (Win Claude UI)
- 🔴 E1-E2 #2480-#2481 (Codex)
- 🟡 E3 #2482 (Win Claude UI)
- 🔴 E4 #2483 (Codex test)

### Phase 4 (7/20 - 7/30): AI chat + 税務
- 🔴 F1-F2 #2484-#2485 (Codex)
- 🟡 F3-F4 #2486-#2487 (Win Claude UI)
- 🔴 F5 #2488 (Codex)
- 🔴 G1 #2489 (Codex)
- 🟡 G2-G3 #2490-#2491 (Win Claude UI)
- 🔴 G4-G5 #2492-#2493 (Codex)

### Phase 5 (8/04 - 8/26): 外部連携 H + I
- 🔴 H1-H3 #2496-#2498 (Codex / MoneyForward)
- 🟡 H4 #2499 (Win Claude UI)
- 🔴 H5 #2500 (Codex)
- 🔴 I1-I3 #2501-#2503 (Codex / eスマート)
- 🟡 I4 #2504 (Win Claude UI)
- 🔴 I5 #2505 (Codex)

### Phase 0 緊急 (5/17 - 5/20): session-hygiene J-feature
- 🚨 J1 #2506 (Codex / GHA cron)
- 🚨 J2 #2507 (Codex / PS install script)
- 🟡 J3 #2508 (Win Claude UI)

→ **J-feature を最優先で着手** (= 部 217-b + 部 218 で RAM 95-97% 持続 / v24 SS 連続違反 / 根本対策必要)

## Codex 5/22 sprint 統合 (= 累積 67 + 47 = 114 deliverable)

部 215 + 部 216 で v25-v27 spec 67 deliverable 設計済. 部 218 + 218-b で 47 issue 追加.
合計 **114 deliverable** = 9 day sprint (5/22-5/30) では完遂不可.

**Codex 振分 5/22-5/30 sprint scope 提案**:
- Phase 0 J-feature 3 issue (= 5/22-5/24 緊急)
- Phase 1 A-feature 5 issue (= 5/25-5/29)
- A1 migration deploy review = 5/22 Day 1

残 39 issue (= H/I/G/F/E/D/C/B) は 6/1+ 順次.

## 重要 EF discovery (= 部 218 検出 / Codex 修正担当)

### wbs.list_tasks pagination broken
- offset 引数 無視 (= 同 200 unique を return 25x)
- 影響: tools-hub 経由全件取得不可 (= reschedule_realistic 内部 own pagination で workaround)
- **Codex 修正候補 = 新規 Issue 起票推奨** (= 部 219+)

## 関連 commit
- `dda1e52c8` (= 部 218 / Win版#132 / 7-step 強行 / 533 reschedule + #2460-#2493 + A1 migration)
- (= 本 doc commit hash 後追記)

## next session prompt 連携
本 handoff doc + 次 session prompt (= MEMORY.md + ROADMAP に記録) で 部 219 開始時に context 完全引継.
