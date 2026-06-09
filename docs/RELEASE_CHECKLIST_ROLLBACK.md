# リリースチェックリスト & ロールバック Runbook — 自分株式会社

Status: v1 (Accepted baseline / 反復運用ドキュメント / **本番運用で更新し続ける living doc**)
Date: 2026-06-09
Owner: Win Claude (L3 設計レーン / architect / release・ops docs lane / [DYNAMIC-CLAIM] で codex→win claim)
WBS: `e601b30f-f86a-4374-9133-0f11c8ec77a2` 「[リリース] リリースチェックリストとロールバック整備」(deploy-prod gate + canary 確認 + rollback runbook を 1 リリース工程に統合)
Sources: 実 [`/.github/workflows/deploy-prod.yml`](../.github/workflows/deploy-prod.yml) / [`ci.yml`](../.github/workflows/ci.yml) / `e2e-smoke.yml` / gate scripts (`check_minimal_e2e_gate.py` ほか) / [`ONCALL_INCIDENT_SOP.md`](ONCALL_INCIDENT_SOP.md) (障害対応) / [`GA_LAUNCH_READINESS_GATE_SPEC.md`](GA_LAUNCH_READINESS_GATE_SPEC.md) (一度きりの GA 可否)

---

## 0. このドキュメントについて

- **目的**: 「**毎回の本番リリース**を安全に回す**反復手順**」の SSOT。タスク記述どおり deploy-prod gate / リリース後確認 / **rollback runbook** / バージョン検証を 1 工程に統合する。
- **境界 (重複しない)**:
  - [`GA_LAUNCH_READINESS_GATE_SPEC.md`](GA_LAUNCH_READINESS_GATE_SPEC.md) = **一度きりの GA (一般公開) 可否** の 5 軸ゲート (MVP scope / pricing / legal / banking / video secrets)。本書は **GA 後も含む毎リリースの反復手順**。
  - [`ONCALL_INCIDENT_SOP.md`](ONCALL_INCIDENT_SOP.md) = 障害**発生後**の検知・対応・事後分析。本書 §5 はそこへの入口 (ロールバック判断) を担い、詳細は SOP に委譲。
  - `docs/technical/DEPLOYMENT_GUIDE.md` は **アーカイブ済 (2025-11 / 旧手動手順)**。本書がロールバックの現行正本としてそれを**置き換える** (旧 guide の `git reset --hard` + `--force` push は本書では**禁止**: §5)。
- **前提 (現状の真実 / [REAL-DATA])**: 本番は **Firebase Hosting (Flutter Web) + Supabase (PostgreSQL / Edge Functions)**。リリースは `main` への push を起点に [`deploy-prod.yml`](../.github/workflows/deploy-prod.yml) が自動実行。**プログレッシブ canary 基盤は無い** (Firebase Hosting は原子的入れ替え) → 「canary 確認」は **staging 段階 + リリース後スモーク + 高速ロールバック**で代替する (§4-§5)。

## 1. リリースパイプライン全体像 (as-is)

`main` への push (※ `docs/**` `memory/**` `.claude/**` `*.md` 等は `paths-ignore` で **deploy-prod 非起動**) →

1. **`ci` job** ([`ci.yml`](../.github/workflows/ci.yml) 再利用) — Lint / Format / Test。
2. **`deploy` job** (`needs: ci` / timeout 45min / `environment: production`):
   - version 自動採番 (直近 tag の patch +1) → `pubspec.yaml` 反映 → リリースノート生成。
   - `check_migration_timestamps.py` (衝突検査) → Supabase CLI link → **migration `db push`** (既知の stuck migration は冪等 `migration repair` 後に適用)。
   - 不要 EF cleanup → **EF デプロイ (22 本 / hub モデル / 各 3 回リトライ)** ([EF-CAP-50] 維持)。
   - **Flutter Web build (production)** → `version.json` 書き出し (version / **commit** / buildNumber / deployedAt) → OGP cache-bust。
   - **Firebase Hosting デプロイ** (`--only hosting` / `continue-on-error: true` ← 509 Bandwidth 暫定対策) → **デプロイ反映検証** (`version.json` の `commit` == `github.sha` を 4×15s ポーリング)。
   - リリース tag push (continue-on-error) → GitHub Release 作成 → リリース通知 broadcast。
3. **`notify` job** — Slack 成功/失敗通知 + commit コメント。
- **並行性** ([CONCURRENCY] / Win#109): `concurrency: deploy-prod` + `cancel-in-progress: false` → 並行 push は**順次** deploy (1 本ずつ / 最大 ~11min × 並行数 待機 / 全 commit 必ず反映)。

## 2. リリース前チェックリスト (merge to main の前)

- [ ] **CI green**: PR の `Lint, Format, Test` + 各 gate が pass ([DART-FORMAT]: Dart 変更時は `dart format --set-exit-if-changed` + `flutter analyze` 0)。
- [ ] **migration 健全性**: 命名 `YYYYMMDDHHMMSS_*.sql` / timestamp 衝突なし / **冪等** (IF NOT EXISTS / ON CONFLICT / 固定値 UPDATE) / down 不要な前進専用設計。
- [ ] **EF 本数** ≤ 50 ([EF-CAP-50]) — 新規は既存 hub への action 追加を最優先。
- [ ] **secrets 変更なし** or 追加済 (新 secret が必要なら deploy 前に登録)。
- [ ] **破壊的変更の確認**: スキーマ後方互換 / API 互換 / 既存ユーザーデータへの影響。
- [ ] **ロールバック想定**: この変更が問題化したら §5 のどの手段で戻すかを 1 行で言える。
- [ ] **stagingで確認** (可能な場合): `staging` ブランチで主要動線スモーク。
- [ ] **タイミング**: 深夜・無人帯のリスキーな大型リリースを避ける (障害時に人が動けるか)。

## 3. リリース実行 (merge → deploy 監視)

1. PR を `main` に merge (squash) → `deploy-prod.yml` 起動。
2. Actions で `deploy` job を監視: **migration → EF → build → Firebase deploy → 反映検証** の各ステップ。
3. 並行 deploy がある場合は順次待ち (`cancel-in-progress:false`)。**後発 push は自分の commit が live になるまで version.json で確認**。
4. `notify` の Slack 成功通知 + commit コメントを確認。

## 4. リリース後検証 (canary 代替スモーク)

- [ ] **commit 反映**: `https://my-web-app-b67f4.web.app/version.json` の `commit` が今回の `github.sha` と一致 (deploy job の自動検証と同じ / 手動再確認可)。
- [ ] **liveness**: `health-check` EF (public / no-verify-jwt) が 200。
- [ ] **スモーク E2E**: `Public E2E stability smoke` / `DB + Edge smoke` が green (主要公開動線が壊れていない)。
- [ ] **UI verify** ([UI-VERIFY]): home / AI 大学 / LP / ranking を Web + モバイルで目視 (Playwright MCP screenshot 可)。
- [ ] **エラー監視**: デプロイ後数分、コンソールエラー / EF ログ / Supabase ログに新規異常がないか。
- 異常を検知したら **即 §5 のロールバック判断**へ。

## 5. ロールバック Runbook

### 5.1 判断 (トリガー)

以下のいずれかで**ロールバックを第一候補**にする: 主要動線 (ログイン / ダッシュボード / 課金) が壊れた / データ破損リスク / セキュリティ露出 / エラー率の明確な急increase。軽微・限定的なら **前進修正 (hotfix)** の方が速いこともある — どちらが安全かで選ぶ。判断・連絡・事後分析の流れは [`ONCALL_INCIDENT_SOP.md`](ONCALL_INCIDENT_SOP.md) に従う。

### 5.2 フロント (Firebase Hosting) — 最速・第一手

Firebase Hosting は原子的入れ替えなので**前バージョンへの復帰が最速のロールバック**:
- Firebase Console → Hosting → リリース履歴 → 直前の正常リリースを **ロールバック**、または直前正常 commit を `main` に `git revert` で戻して再デプロイ。
- これで**ユーザーが見るアプリ**は即座に正常へ戻せる (DB を触らずに表層回復)。

### 5.3 コード — `git revert` 前進専用

```bash
# 問題コミットを打ち消す新コミットを作る (履歴を壊さない)
git revert <BAD_SHA>
git push origin main      # deploy-prod が再実行され前状態へ
```

- **禁止** (旧 archived guide の手順): `git reset --hard` + `git push --force`。共有 `main` の歴史改変・他インスタンスの作業破壊・deploy 不整合を招く ([STASH-SAFETY] の精神)。**必ず `revert`**。

### 5.4 Supabase migration — 前進専用 fix (down migration なし)

- migration は**前進専用**。「戻す」= **逆操作を行う新しい冪等 migration を追加**する (例: 追加した列を `DROP COLUMN IF EXISTS`、誤更新は再 UPDATE)。`deploy-prod.yml` の `migration repair` 群は stuck 復旧の実例。
- データ破損が絡む場合は Supabase バックアップからの復元を検討 (本番適用前に必ずローカル/staging で復元テスト)。
- **コードのロールバックと DB の整合**: フロントを前バージョンに戻すなら、その版が**新スキーマでも壊れない**ことを確認 (前方互換な migration 設計が前提)。

### 5.5 ロールバック後

- `version.json` で意図した版が live か再確認 (§4) → スモーク再実行。
- [`ONCALL_INCIDENT_SOP.md`](ONCALL_INCIDENT_SOP.md) に沿って記録 + 原因調査 → 修正は通常フロー (PR → gate → deploy) で再リリース。

## 6. バージョン検証

- **正本**: 本番 `version.json` (`version` / `buildNumber` / `commit` / `deployedAt`) — 「今 live なのはどの commit か」の一次情報。
- **tag / Release**: `v<major.minor.patch>` (patch 自動 +1) + GitHub Release (commit / リリースノート)。tag push は GH_PAT 不足時 warning で skip され得る → **Firebase 反映が本体・tag は補助**。
- リリース後は `version.json.commit == github.sha` を必ず確認 (後発 queued run に上書きされていないか)。

## 7. 既知の落とし穴 (gotchas)

- **docs-only は deploy-prod を起動しない** (`paths-ignore`)。docs/migration 混在 PR は migration があるので起動する。
- **509 Bandwidth Exceeded** 対策で Firebase deploy step は `continue-on-error: true` → **step 緑でも反映未済の可能性**。必ず `version.json` で実確認。
- **CI Flutter 3.38.x ≠ ローカル版**: `dart format` の差異で CI のみ fail し得る (part 244 例)。push 前にローカル整形。
- **並行 deploy 待ち**: `cancel-in-progress:false` で順次。急ぎでも他 run 完了を待つ。
- **migration stuck**: aborted deploy の重複キーは冪等設計 + `migration repair` 前提。新規 migration は必ず冪等に。

## 8. 役割 (Roles)

- **Win Claude (L3)**: 本書 (release SOP / rollback runbook) の設計・維持。リリース後 UI verify / triage。
- **Win Codex (L2)**: `deploy-prod.yml` / `ci.yml` / gate scripts / migration / EF の実装・修正。
- **CEO (User)**: GA など重大リリースの go 判断 ([`GA_LAUNCH_READINESS_GATE_SPEC.md`](GA_LAUNCH_READINESS_GATE_SPEC.md))。

## 9. Deferred / 非スコープ

- **プログレッシブ canary / blue-green 基盤の構築** (現状 Firebase 原子入れ替え + スモークで代替 / 必要なら別 feature Issue)。
- **deploy-prod.yml 等の実装変更** (本書は手順の正本 / 実装は L2 Codex)。
- **障害対応の詳細フロー** ([`ONCALL_INCIDENT_SOP.md`](ONCALL_INCIDENT_SOP.md) が正本)。
- **一度きりの GA 可否判定** ([`GA_LAUNCH_READINESS_GATE_SPEC.md`](GA_LAUNCH_READINESS_GATE_SPEC.md) が正本)。

## 10. 原則整合 (Philosophy Alignment)

[`PHILOSOPHY.md`](PHILOSOPHY.md) 9 原則で **7+/9 ✅**: 原則 1 (重大リリースの go は CEO) · 原則 3-4 (mentor / チェックリストで負荷軽減) · 原則 6 (時間資本 = 障害復旧時間の短縮) · 原則 7 (資産負債 = 安定運用は資産 / 不安定は負債) · 原則 8 (KPI = リリース成功率・MTTR を昨日の自分基準で改善) · 原則 9 (ウェルビーイング = 無人帯の無理なリリースを避ける)。[AI_DEV_PRINCIPLES](AI_DEV_PRINCIPLES.md) (circuit-breaker / quality-gate) + [VIBE-30] (責任ある production 運用) に整合。

## 11. 運用 (Living Document) / Links

- 実リリースで判明した手順差分を都度反映 (薄く保つ)。canary 基盤を入れたら §0/§4/§9 を更新。
- リリース工程: [`deploy-prod.yml`](../.github/workflows/deploy-prod.yml) / [`ci.yml`](../.github/workflows/ci.yml) / 障害: [`ONCALL_INCIDENT_SOP.md`](ONCALL_INCIDENT_SOP.md) / GA 可否: [`GA_LAUNCH_READINESS_GATE_SPEC.md`](GA_LAUNCH_READINESS_GATE_SPEC.md) / MVP: [`MVP_SCOPE.md`](MVP_SCOPE.md)
- 実行計画: WBS (project-gantt) / task `e601b30f-f86a-4374-9133-0f11c8ec77a2`
