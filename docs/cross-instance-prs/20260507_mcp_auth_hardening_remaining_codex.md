# Cross-Instance PR: MCP Auth Hardening 残 11 件 omnibus 実装

**作成**: Win版#132 part 176 / 2026-05-07 JST
**依頼先**: **Win版 (Codex CLI)** (= 2 instance 制 / docs/MULTI_INSTANCE_FLEET.md)
**優先度**: HIGH (= P1 / sensitive 第 4 例 #1577 / spec ship 後 2 日経過)
**期限**: 2026-05-21 (= 14 日間 / 段階分割可)
**親 spec**: [docs/MCP_AUTH_HARDENING_SPEC.md](../MCP_AUTH_HARDENING_SPEC.md)
**親 issue**: [#1577](https://github.com/kanta13jp1/my_web_app/issues/1577)
**親 PR (= spec doc)**: [#2022](https://github.com/kanta13jp1/my_web_app/pull/2022) MERGED 2026-05-05

---

## 判定 5 質問

| Q | 答え |
|---|---|
| Q1. 設計判断 / trade-off 検討必要? | **NO** (= 親 spec §4-§7 で全採否決定済) |
| Q2. cross-instance 調整必要? | **NO** (= Win Claude territory は spec only) |
| Q3. 軸 docs 更新必要? | **NO** (= principle docs 影響なし) |
| Q4. docs に残す価値ある判断? | **PARTIAL** (= 3 docs 起票指示あり / hand-off に含む) |
| Q5. NotebookLM 連携要? | **NO** (= 実装後 Win Claude が memory に記録) |

→ 4 NO + 1 PARTIAL → **Codex 適合** (= 主要は実装 / docs 起票も Codex template 化可能領域)

---

## verify finding (= part 176 / Win Claude triage)

PR #2022 MERGED 2026-05-05 後 2 日経過. Codex 14 件 hand-off の進捗 verify:

| # | item | status |
|---|---|---|
| 1 | `supabase/functions/_shared/mcp_auth_guard.ts` 完成 | ✅ (= part 49 skeleton + part 54 PR で WorkOS JWKS 配線済) |
| 2 | `mcp_auth_guard_test.ts` | ✅ |
| 3 | migration extend `mcp_oauth_clients` (= managed_by/reputation/rotation_due_at) | ❌ |
| 4 | migration extend `mcp_audit_log` (= anomaly_score/cross_server_trace/origin_tag) | ❌ |
| 5 | migration `workos_user_link` 新設 | ❌ |
| 6 | `supabase/functions/mcp-well-known/index.ts` (= 新規 EF) | ❌ |
| 7 | `supabase/functions/_shared/internal_hmac.ts` | ❌ |
| 8 | `.github/workflows/mcp-audit-anomaly-cron.yml` (= hourly :07) | ❌ |
| 9 | `terraform/` Custom Provider skeleton | ❌ |
| 10 | `docs/mcp-dcr-vs-cimd-decision.md` | ❌ |
| 11 | `docs/mcp-attest-roadmap.md` | ❌ |
| 12 | `docs/mcp-auth-incident-runbook.md` | ❌ |
| 13 | `memory-search-hub` 5/10 → 10/10 達成 | △ EF 存在 / 10 原則 self-check 未 verify |
| 14 | `docs/DESIGN_SPEC_TEMPLATE.md` §4A 第 4 改訂 | ✅ (= PR #2022 で同梱) |

**進捗 = 3/14 (= 21%) / 11 件未完成**. 親 spec §5-§7 に実装サンプルコード詳細記載済 → Codex は spec doc を参照しつつ実装可能.

---

## hand-off scope (= 11 件 / 段階分割推奨)

### Phase A. SQL migration 3 件 (= 推定 1.5h)

ファイル名 = `YYYYMMDDHHMMSS_descriptive_name.sql` ([DEVELOPMENT_ACHIEVEMENTS_FORMAT.md](../DEVELOPMENT_ACHIEVEMENTS_FORMAT.md) 準拠).

1. `extend_mcp_oauth_clients.sql` — 親 spec §5.2 SQL そのまま. `managed_by` CHECK + `reputation_score` + `metadata_document_url` (CIMD Phase 2) + `rotation_due_at` 4 列追加.
2. `extend_mcp_audit_log.sql` — 親 spec §5.3 SQL そのまま. `anomaly_score` + `cross_server_trace` + `origin_tag` 3 列追加 + `purge_mcp_audit_log()` 90 日 retention 関数.
3. `create_workos_user_link.sql` — 親 spec §4.3 Standalone Connect / 既存 `users` テーブル × WorkOS user id 1:1 mapping. RLS = `auth.uid() = local_user_id`.

### Phase B. EF 2 件 + shared 1 件 (= 推定 2.5h)

4. `supabase/functions/mcp-well-known/index.ts` — 親 spec §5.4 そのまま (= 30 行 / unauthenticated / Cache-Control 1h). `MCP_RESOURCE_URL` + `WORKOS_ISSUER` env 必要.
5. `supabase/functions/_shared/internal_hmac.ts` — 親 spec §4.4. **内部 EF 間のみ** (= 外部 MCP 受け口は OAuth 2.1+PKCE). HMAC-SHA256 + Nonce (UUID) + Timestamp (±5 min skew) 検証.
6. `supabase/config.toml` の `mcp-well-known` 登録 (= unauthenticated / public function).

### Phase C. GHA cron + Terraform skeleton (= 推定 1h)

7. `.github/workflows/mcp-audit-anomaly-cron.yml` — 親 spec §5.5. hourly :07 / `concurrency: cancel-in-progress: false` ([CONCURRENCY] rule). Slack Webhook env で alert.
8. `terraform/mcp_oauth_clients/` skeleton — 親 spec §5.6 + Mercari Tip 1 応用. Custom Provider stub (= GHA で `terraform plan` のみ実行 / apply は別 PR).

### Phase D. docs 3 件 (= 推定 1.5h)

9. `docs/mcp-dcr-vs-cimd-decision.md` — 親 spec §4.1 を docs 化. Phase 1 = DCR / Phase 2 (2027 Q1) = CIMD 移行決定理由.
10. `docs/mcp-attest-roadmap.md` — 親 spec §6.6. AttestMCP 採用条件 (= MCP server 数 5+ / cross-server 攻撃 1+ 件 検知).
11. `docs/mcp-auth-incident-runbook.md` — 親 spec §6.5 escape hatch. Sentinel role 1 SQL で全 client suspend 手順 + Slack channel + 復旧 SOP.

### Phase E. memory-search-hub 10/10 verify (= 推定 30 min)

12. `supabase/functions/memory-search-hub/index.ts` の **MCP-AUTH-27 10 原則 self-check** を JSDoc にて明記. 既存実装が 10/10 を満たすか軸別 ✅/❌ で記録. ❌ あれば追加 issue 起票 (= [ISSUE-PRECHECK] 重複 check 必須).

合計推定工数: **6.5h** / 段階分割推奨 (= Phase A → B → C → D → E).

---

## acceptance criteria

- 11 件全 commit + PR (= 1 omnibus PR or Phase 別 stacked PR どちらも可).
- Phase A migration 適用後 `supabase db reset` で全 idempotent (= [STASH-SAFETY] 観点でも safe).
- Phase B EF deploy 後 `curl -i $URL/mcp-well-known/.well-known/oauth-protected-resource` で 200 + JSON. EF 数 ≤ 50 ([EF-CAP-50] 維持).
- Phase C cron は manual workflow_dispatch で 1 回成功 verify.
- Phase D docs は親 spec の該当 § から自然な subset (= 重複コピペ避ける / link で参照).
- Phase E は self-check 結果を JSDoc + memory に記録.
- 親 issue [#1577](https://github.com/kanta13jp1/my_web_app/issues/1577) に Phase 完了ごと status comment.

---

## 実装注意点 (= 親 spec から抜粋)

- **DCR registration endpoint** = unauthenticated だが rate limit + IP allowlist + reputation check 必須 (= 親 spec §2.1 / 自動登録 bot 攻撃 risk).
- **末尾スラッシュ厳密一致 NG** = `issuer` URL の末尾は環境差 (= 親 spec §2.1 + MCP-AUTH #2 caveat).
- **Audience 罠** = DCR 動的 client_id を JWT `audience` 厳格一致させると失敗 (= 親 spec §2.1).
- **Manual SQL 禁止** = `mcp_oauth_clients` への INSERT は Terraform 経由のみ. `managed_by='manual_admin'` 件数 > 0 で CI fail 推奨 (= 親 spec §5.2).
- **3 段階強制** = production strict / staging warn / dev optional (= 親 spec §2.2 / Postman / MCP Inspector debug 体験).
- **Streamable HTTP + SSE legacy 並走** = `/legacy/sse/*` + `Sunset` ヘッダー (= MCP-AUTH #4 / 親 spec §4.7).

---

## 関連

- 親 spec: [docs/MCP_AUTH_HARDENING_SPEC.md](../MCP_AUTH_HARDENING_SPEC.md) (= 618 行 / 11 section / sensitive 第 4 例)
- 親 PR: [#2022](https://github.com/kanta13jp1/my_web_app/pull/2022) MERGED 2026-05-05
- 親 issue: [#1577](https://github.com/kanta13jp1/my_web_app/issues/1577) [P1] WorkOS AuthKit MCP 認可強化
- 旧 hand-off: [20260428_mcp_auth_guard_workos_jwks_codex.md](20260428_mcp_auth_guard_workos_jwks_codex.md) (= 1 件単体 / 完了済)
- principle docs: [MCP_AUTH_SECURITY_PRINCIPLES.md](../MCP_AUTH_SECURITY_PRINCIPLES.md) 10/10 必須
- NotebookLM source: `1b808a60-85d6-49f7-ab80-0e90a43cf1d8` Streamlining MCP Authentication with WorkOS AuthKit

---

## 期限管理

- **2026-05-21**: 全 Phase 完了目標 (= 14 日 / Phase 別 ~3 日)
- **2026-05-14**: 中間 ping (= [SCHEDULE-WAKEUP] 7 日経過時 progress 確認 / Win Claude side で auto-ping cron 自走化 spec ship 済 = part 169)
- **2026-05-21 超過**: Win Claude が再 triage / dormant grace 30 日 pattern 適用検討 (= part 163)
