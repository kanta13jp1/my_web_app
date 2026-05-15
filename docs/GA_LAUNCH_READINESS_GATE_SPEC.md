# GA Launch Readiness Gate — 統合 spec

> **Win版#132 part 189 (2026-05-09)**: WBS P1 期限近順 3 件を 1 doc に統合 ship.
> Issue [#1640](https://github.com/kanta13jp1/my_web_app/issues/1640) (MVP scope freeze + GA gate) + [#1662](https://github.com/kanta13jp1/my_web_app/issues/1662) (会社設立・法務・税務・銀行) + [#1724](https://github.com/kanta13jp1/my_web_app/issues/1724) (notebooklm-video secrets).
> 3 issue 共通 root cause = "GA に必要な決定論チェックが分散". 1 page 化で SSOT 確立.

## 1. 統合根拠 (= why 1 doc)

3 issue は別々に開かれているが、いずれも **GA Launch Readiness gate** の一部:

- **#1640** = GA に必要な機能 scope の凍結 + CI 検証
- **#1662** = GA に必要な法務 / 税務 / 銀行 の人間決定 evidence
- **#1724** = GA に必要な動画 pipeline secrets 5 個

→ **GA Launch Readiness gate** = 「全 axis green = GA 可」 の単一 checklist 化が leverage 高い (= 3 issue / 1 PR / SSOT).

## 2. GA Readiness Axes (= 5 軸 + 1 表)

| Axis | Owner | Evidence | Gate command | Issue |
|------|-------|----------|--------------|-------|
| **A. MVP Scope** | Win Claude (architect) | `docs/MVP_SCOPE_FROZEN.md` (= 必須 / 除外 / 保留 機能 list) | `flutter analyze && flutter test` | #1640 |
| **B. Pricing v1.0** | User (= CEO 決定) | Paddle product config + 公開文言 | Paddle審査 status | #1640 / #1633 |
| **C. Legal Entity** | User (= 司法書士契約) | `docs/CORPORATE_FORMATION_RUNBOOK.md` (= 商号 / 本店 / 登記日) | manual evidence URL | #1662 |
| **D. Banking** | User (= 法人口座開設) | bank_account_id (= 暗号化保管) | manual evidence URL | #1662 |
| **E. Video Secrets** | User (= 5 secrets 登録) | `gh secret list` で 5 件 visible | `notebooklm-video-pipeline.yml` green | #1724 |

GA 可否判定 = **全 axis green かつ 直近 7 日間 Paddle audit log 無 critical**.

## 3. Axis A — MVP Scope Freeze (= #1640 詳細)

### 3.1 必須機能 (= GA blocker)

| 機能 | 状態 | EF / page |
|------|------|-----------|
| Auth (= Supabase OAuth + email link) | ✅ | `auth-hub` |
| 自分株式会社 dashboard | ✅ | `home_page.dart` |
| AI 役員 chat | ✅ | `executive_chat_page.dart` |
| 食事ログ MVP | ⏳ | `meal_log_page.dart` (= part 164 spec) |
| Paddle 課金 v1.0 | ⏳ | `paddle-hub` |
| Privacy Policy / Terms | ⏳ (= part 160 draft) | `static/privacy-policy.html` |

### 3.2 除外機能 (= GA 後)

- スマートウォッチ widget (= #1741 → mobile版 hand-off)
- 動画 carousel (= #1724 secrets 着地後)
- AI 大学 advanced 章 (= 100+ provider)
- 競合分析 dashboard (= internal-only)

### 3.3 保留機能 (= MVP 判定保留)

- AI Secretary 自動 invoice 発行 → 法務 entity 確定 (= #1662) 後判定
- ライブ podcast streaming → ElevenLabs cost 評価後

### 3.4 Determine CI gates

```yaml
# .github/workflows/ga-readiness-gate.yml
- name: MVP scope check
  run: |
    flutter analyze --no-fatal-warnings
    flutter test --reporter=compact
    deno task check:edge-functions
    npx playwright test e2e/critical/
```

→ Codex 実装 (= 期限 2026-05-23)

## 4. Axis C+D — Corporate Formation Runbook (= #1662 詳細)

### 4.1 必要な人間決定 + evidence

| Step | 決定者 | 期限 | Evidence URL |
|------|--------|------|--------------|
| 商号 / 本店所在地確定 | User | 2026-06-15 | (= 登記簿 PDF) |
| 司法書士 / 税理士契約 | User | 2026-06-30 | 契約書 PDF |
| 株式会社設立登記 | User + 司法書士 | 2026-09-30 | 登記事項証明書 |
| 法人口座開設 | User + 銀行 | 2026-10-15 | 通帳コピー (= 口座番号 mask) |
| 初期事業計画 3 年 PL | User + 税理士 | 2026-08-31 | PL spreadsheet |
| Seed 投資家リスト | User | 2026-08-31 | Notion DB |
| Pitch Deck v1.0 | User | 2026-08-31 | Google Slides |

### 4.2 Codex / Claude が **やらないこと** (= guardrail)

- ❌ 商号 / 本店住所 を fabricate
- ❌ 司法書士 / 税理士の選定
- ❌ 銀行口座番号の生成
- ❌ 投資家への直接 pitch 送信
- ✅ checklist 維持 / evidence URL collation / WBS 期限管理 のみ

### 4.3 WBS task_id 紐付け (= [WBS-SYNC])

```
108a24dc... 商号・本店所在地    → #1662 axis C step 1
0fa38c4f... 司法書士・税理士契約 → #1662 axis C step 2
5e34304e... 株式会社設立登記     → #1662 axis C step 3
c1436a87... 法人口座開設         → #1662 axis D step 4
282c7660... 初期事業計画 3 年 PL → #1662 axis C step 5
f9c7fd37... Seed 投資家リスト    → axis F (= future)
69d5bbad... Pitch Deck v1.0      → axis F (= future)
```

### 4.4 Paddle / legal SSOT integration (= #1633 / #1330)

法人 entity 確定後:
1. Paddle dashboard に **正式 entity name + 住所 + 法人番号** 登録 (= user 手動 / 1 step)
2. `payments_legal_entities` table に row insert (= 暗号化)
3. `paddle-hub` から評価 EF が参照 (= [REAL-DATA] / 暫定 placeholder 削除)

## 5. Axis E — Video Pipeline Secrets (= #1724 詳細)

### 5.1 必要 secrets (= 5 件)

| Secret name | 用途 | 取得先 |
|-------------|------|--------|
| `GITHUB_PAT` | workflow_dispatch branch push | GitHub Settings → Personal Access Tokens (= scope: `repo`, `workflow`) |
| `NOTEBOOKLM_STORAGE_STATE_JSON` | notebooklm CLI auth | `~/.notebooklm/storage_state.json` (= playwright login 後 export) |
| `ELEVENLABS_API_KEY` | Scribe ASR 字幕 | ElevenLabs dashboard → API Keys |
| `YOUTUBE_CLIENT_SECRET_JSON` | YouTube OAuth client | Google Cloud Console → OAuth 2.0 Client IDs |
| `YOUTUBE_TOKEN_JSON` | YouTube OAuth refresh token | (= client_secret 経由 oauth flow 1 回完了後) |

### 5.2 登録手順 (= user 1 step)

Codex #1 deterministic readiness layer (2026-05-16):

- `video-pipeline-secret-readiness.yml` reports boolean-only presence for the five required secrets.
- `notebooklm-video-pipeline.yml` runs `check_video_pipeline_secret_readiness.py --require-secrets` before any NotebookLM download, ElevenLabs transcription, YouTube upload, or quota-consuming work.
- The checker never prints secret values; it records only `present: true/false` and uploads `video-pipeline-secret-readiness-report`.
- This does not replace the user-owned secret registration step. It changes the old opaque `Input required and not supplied: token` failure into a deterministic readiness report.

```bash
# secret 5 件登録 (= user local PC 上)
gh secret set GITHUB_PAT --body "ghp_..."
gh secret set NOTEBOOKLM_STORAGE_STATE_JSON < ~/.notebooklm/storage_state.json
gh secret set ELEVENLABS_API_KEY --body "sk_..."
gh secret set YOUTUBE_CLIENT_SECRET_JSON < ~/youtube_client_secret.json
gh secret set YOUTUBE_TOKEN_JSON < ~/youtube_token.json

# verify
gh secret list | grep -E "GITHUB_PAT|NOTEBOOKLM|ELEVENLABS|YOUTUBE"
```

### 5.3 動作 verify

```bash
gh workflow run notebooklm-video-pipeline.yml \
  -f notebook=f167dcc3 \
  -f artifact=25423b84 \
  -f series=4 \
  -f slug=multi-agent-convergence
```

→ green = GA gate axis E ✅

### 5.4 secrets 登録後の cleanup

YouTube アップロード成功後:
- `philosophy_page.dart` `_Video(id='multi-agent-convergence')` の `id` を実 YouTube ID に置換
- `mp4Url` field を削除 (= null 戻し)
- `web/assets/videos/multi-agent-convergence.mp4` 削除 (= 12MB repo size 解消)

## 6. GA gate 統合 visualization

```
┌─ GA Readiness Dashboard ─────────────────────────────────┐
│                                                            │
│   A. MVP Scope        [████████░░] 80%   target 2026-06    │
│   B. Pricing v1.0     [██░░░░░░░░] 20%   target 2026-07    │
│   C. Legal Entity     [█░░░░░░░░░] 10%   target 2026-09    │
│   D. Banking          [░░░░░░░░░░]  0%   target 2026-10    │
│   E. Video Secrets    [██░░░░░░░░] 20%   target 2026-05-15 │
│                                                            │
│   GA Eligible: ❌ (= D + E 未着手)                          │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

新規 page 作成不要 — 既存 `home_page.dart` 上部に折り畳み可能 widget で表示.

## 7. Codex hand-off scope (= 期限 2026-05-23)

| Task | 担当 | 期限 |
|------|------|------|
| `.github/workflows/ga-readiness-gate.yml` 作成 | Codex | 2026-05-16 |
| `agent.list_ga_axes` EF action 追加 (= app-hub に追加 / [EF-CAP-50] 維持) | Codex | 2026-05-18 |
| `home_page.dart` GA gate widget (= 折り畳み) | Codex | 2026-05-21 |
| `docs/CORPORATE_FORMATION_RUNBOOK.md` evidence template | Win Claude | 2026-05-12 (= self) |
| Issue #1640 / #1662 / #1724 status comment update | Win Claude | part 189 (= 本 session) |

## 8. PHILOSOPHY-22 alignment (= 7+/9 ✅)

- 主要実装: GA 可否 SSOT 化 + 人間決定 vs AI 担当 boundary 明示 + Codex hand-off scope
- 該当原則:
  - #1 (CEO 感) — 5 axis を user が見て GA timing 決定
  - #2 (mission) — IPO 道筋に必要な GA 体制構築
  - #3 (mentor) — checklist 化で user の負荷軽減
  - #4 (6 部署) — 法務 / 財務 / 商品 / マーケ 4 部署 cover
  - #6 (時間) — 3 issue → 1 doc で audit time 削減
  - #7 (資産負債) — 法人化 = 資産 / 未着手 = 負債 visualize
  - #8 (KPI) — axis %% を昨日の自分と比較
  - #9 (IPO) — GA = IPO への前段
- 整合性スコア: 8/9 ✅ ([PHILOSOPHY-22] gate 通過)

## 9. 関連

- Issues: [#1640](https://github.com/kanta13jp1/my_web_app/issues/1640) [#1662](https://github.com/kanta13jp1/my_web_app/issues/1662) [#1724](https://github.com/kanta13jp1/my_web_app/issues/1724)
- Paddle / legal SSOT: #1330 / #1633
- Corporate formation runbook (= part 189 follow-up): `docs/CORPORATE_FORMATION_RUNBOOK.md`

---

> **Spec ship**: Win版#132 part 189 (2026-05-09 JST). 3 issue / 1 doc / SSOT pattern 第 1 例.
