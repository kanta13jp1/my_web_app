# Handoff Bundle Spec — 自分株式会社 全 Stack 統合委譲形式

> このドキュメントは、自分株式会社の **新機能設計から本番実装までを 1 PR で完結** させる **Handoff Bundle 形式** を定義する.
>
> **PLATFORM_EVOLUTION 原則 #4 (Handoff Bundle Driven)** dogfood. Claude Design + Claude Code 連携 を **全 stack (Flutter + Supabase + EF + Test)** に拡張.
>
> = VIBE_CODING #2 (AI as PM / Plan アーティファクト) + cross-instance-pr の **進化形態**.

---

## なぜ必要か

現状の自分株式会社の機能追加 flow:

```
[ユーザー要望 / バグ報告]
  ↓ Plan (= cross-instance-pr / Win territory)
[VSCode版 territory: Flutter widget 追加]
  ↓ 別 commit
[Codex#2 territory: Supabase EF action 追加]
  ↓ 別 commit
[Codex#1 territory: schema migration]
  ↓ 別 commit
[VSCode版 territory: integration test]
```

= **1 機能 = 4 instance × 4 commit = 4 cross-instance-pr** を要する場合がある.

問題:
- 設計判断が **複数 PR に分散** → 整合性管理が困難
- review 文脈が **複数 territory にまたがる** → ボトルネック発生
- **未着手 stack** が出ると機能が宙吊り (= EF はあるが migration なし等)

= **1 PR = 1 bundle = 1 機能** で全 stack を **同 commit / 同 review** に統合する形式が必要.

---

## Handoff Bundle 構造

### ディレクトリ構造

```
docs/handoff-bundles/
  └── <YYYYMMDD>_<task-slug>/
        ├── README.md                   # bundle メタ + Plan アーティファクト
        ├── design.json                 # UI design (= Claude Design / Figma export)
        ├── flutter_widgets/            # Flutter 実装
        │   ├── <widget>.dart
        │   └── <page>.dart
        ├── supabase/
        │   ├── schema.sql              # 必要 table / RLS policy
        │   ├── migrations/
        │   │   └── <YYYYMMDDHHMMSS>_<name>.sql
        │   └── functions/
        │       └── <hub>/<action>.ts   # EF action 単位
        ├── integration_test/
        │   └── <feature>_test.dart     # E2E test 1 シナリオ
        ├── docs_diff/
        │   └── (= 設計軸 docs 更新案 / DESIGN.md 等の差分)
        └── routing.md                  # territory 割り振り (= 誰がどの section 担当か)
```

### 必須セクション

| セクション | 必須 | 任意 | 内容 |
| --- | --- | --- | --- |
| README.md | ✅ | | bundle メタ + Plan + 受け入れ基準 |
| design.json | △ | UI 機能のみ | Claude Design / Figma export |
| flutter_widgets/ | △ | UI 機能のみ | 1+ widget / page |
| supabase/schema.sql | △ | DB 機能のみ | CREATE TABLE + RLS |
| supabase/migrations/ | △ | DB 機能のみ | 1+ migration |
| supabase/functions/ | △ | EF 機能のみ | 1+ EF action |
| integration_test/ | ✅ | | 1 シナリオ最低 (= VIBE #5) |
| docs_diff/ | △ | 設計軸更新時のみ | 関連 docs 差分 |
| routing.md | ✅ | | territory 割り振り表 |

= **README + integration_test + routing は必須**. 他は機能性質に応じて.

---

## Bundle 作成 flow

### Step 1: User 要望 → Plan アーティファクト

```bash
# Win版 (= Plan agent)
mkdir -p docs/handoff-bundles/20260429_<feature-slug>
# README.md 作成 (= 後述形式)
```

### Step 2: 各 stack の skeleton 配置

```bash
# Plan agent が各 stack の **skeleton + 仕様** を bundle 内に配置
# 実装は空 / interface のみ / TODO コメント
```

### Step 3: routing.md で territory 割り振り

```markdown
# routing.md
| Section | Territory | Status |
| --- | --- | --- |
| flutter_widgets/ | VSCode版 | ⏳ pending |
| supabase/migrations/ | Codex#1 | ⏳ pending |
| supabase/functions/ | Codex#2 | ⏳ pending |
| integration_test/ | VSCode版 | ⏳ pending |
| docs_diff/ | Win版 | ✅ done |
```

### Step 4: 1 PR で bundle 提出

```bash
git add docs/handoff-bundles/20260429_<slug>/
git commit -m "feat(handoff): <feature> bundle skeleton (Win版#132 part X)"
git push origin HEAD:main
```

### Step 5: 各 territory が並行実装

各 instance が routing.md を見て自担当 section を実装. **同 PR 内** に commit を追加 (= bundle 単位の atomic merge).

### Step 6: Bundle 完成判定

```markdown
# routing.md (完成時)
| Section | Territory | Status |
| --- | --- | --- |
| flutter_widgets/ | VSCode版 | ✅ done (commit abc123) |
| supabase/migrations/ | Codex#1 | ✅ done (commit def456) |
| supabase/functions/ | Codex#2 | ✅ done (commit ghi789) |
| integration_test/ | VSCode版 | ✅ done (commit jkl012) |
| docs_diff/ | Win版 | ✅ done (commit mno345) |
```

= 全 section ✅ で bundle 完成 → main merge → `docs/handoff-bundles/done/<slug>/` 移動.

---

## README.md フォーマット (= bundle Plan アーティファクト)

```markdown
# Handoff Bundle: <タイトル>

**作成**: <instance>#<NNN> part <NN> / <YYYY-MM-DD>
**機能種別**: UI / DB / EF / Cross-stack
**優先度**: high / medium / low
**期限**: <YYYY-MM-DD>
**親軸**: <該当設計軸 N 個>

---

## 1. ユーザー要望 / バグ報告

(= 元の要望全文)

## 2. Plan (= 設計判断)

### 2.1 採用案
<選定案 + trade-off>

### 2.2 不採用案
<検討した代替案 + 不採用理由>

### 2.3 影響範囲
<どの page / EF / schema / docs を更新するか>

## 3. 受け入れ基準

- [ ] <feature> が production で動作
- [ ] integration test pass
- [ ] flutter analyze / deno lint 0 エラー
- [ ] 関連設計軸 baseline 更新

## 4. Routing (= 割り振り)

詳細: [[routing.md]]

## 5. 連携軸

| 軸 | 連携 |
| --- | --- |
| ... | ... |
```

---

## 既存 cross-instance-pr との違い

| 観点 | cross-instance-pr | Handoff Bundle |
| --- | --- | --- |
| 単位 | 1 territory 1 task | 1 機能 N territory 横断 |
| Plan 詳細度 | 中 | 高 (= skeleton 配置) |
| atomic merge | × (= 個別 commit) | ✅ (= bundle 単位) |
| review 文脈 | 分散 | 集約 |
| 適用場面 | 単一 territory タスク | 全 stack 機能 |

= cross-instance-pr は **継続使用** (= 単一 territory タスク向け). Bundle は **全 stack 機能** 専用.

---

## Bundle vs cross-instance-pr の選択基準

```
新機能を提案する時:
  └─ 影響 stack が 1 つだけ?
       └─ ✅ → cross-instance-pr (既存形式)
       └─ ❌ → Handoff Bundle
  └─ 1 PR で全 stack 完結したい?
       └─ ✅ → Handoff Bundle
       └─ ❌ → cross-instance-pr
  └─ 異 territory 間の整合性が critical?
       └─ ✅ → Handoff Bundle
       └─ ❌ → cross-instance-pr
```

---

## 想定 Use Case

### Case 1: 新規ページ追加 (= UI + EF + schema)

例: 「サブスク解約ページ」を追加

| Section | 担当 |
| --- | --- |
| flutter_widgets/cancel_subscription_page.dart | VSCode |
| supabase/schema.sql (= cancellations table) | Codex#1 |
| supabase/functions/billing-hub/cancel.ts | Codex#2 |
| integration_test/cancel_flow_test.dart | VSCode |
| docs_diff/PHILOSOPHY.md (= 顧客との関係) | Win |

= 5 territory 横断 1 PR.

### Case 2: 動画パイプライン拡張 (= AI_VIDEO 軸)

例: AI アバター動画生成 (= AI_VIDEO #1)

| Section | 担当 |
| --- | --- |
| scripts/video/build_avatar.py | Win |
| .github/workflows/notebooklm-video-pipeline.yml | Win |
| flutter_widgets/avatar_video_player.dart | VSCode |
| integration_test/avatar_video_e2e_test.dart | VSCode |
| docs_diff/AI_VIDEO_PRINCIPLES.md (= #1 完成) | Win |

= scripts + GHA + UI + test の 4 stack.

### Case 3: MCP server 公開 (= MCP_AUTH 10 原則)

例: memory-search-hub MCP 公開

| Section | 担当 |
| --- | --- |
| supabase/migrations/...create_memory_index.sql | Codex#1 |
| supabase/functions/memory-search-hub/ | Codex#2 |
| supabase/functions/_shared/mcp_auth_guard.ts (= 拡張) | Codex#2 |
| integration_test/mcp_search_test.ts | Codex#2 |
| docs_diff/MCP_AUTH_SECURITY_PRINCIPLES.md (= 10/10) | Win |

= 大規模 migration + EF + test + docs.

---

## Done 移動 + 完了確認

```bash
# 全 section ✅ + main merge 後
git mv docs/handoff-bundles/<slug> docs/handoff-bundles/done/<slug>
git commit -m "chore(handoff): <slug> bundle complete → done/"
```

`done/` 移動で **5 正本層 #1 (= GitHub PR / Issues) 整合復活**. cross-instance-pr の done/ 移動と同型.

---

## 整合性監査 (定期セルフレビュー)

`scripts/check_handoff_bundle.py` (将来追加):
- root の bundle が **30 日以上停滞** していないか (= 着手忘れ検出)
- routing.md の status と git log が整合しているか
- integration_test がない bundle を検出 (= VIBE #5 違反)
- 違反検出時は GitHub Issue 自動作成

---

## 連携軸

| 軸 | 連携内容 |
| --- | --- |
| **PLATFORM_EVOLUTION #4** (Handoff Bundle) | 本 docs = #4 dogfood. baseline 3.0 → 4.0/7 |
| **VIBE_CODING #2** (AI as PM) | bundle README = Plan アーティファクト |
| **VIBE_CODING #5** (Minimal E2E Tests) | integration_test/ 必須 |
| **SECOND_BRAIN #5** (Query 永続化) | 採用 / 不採用案 = query_artifact 候補 |
| **OPS-28 charter** | bundle 完成判定 = 5 正本層 #1 整合復活と同型 |
| **AI_DEV** (= 7 原則) | 全 stack 統合 = AI_DEV の高度化 |

= 6 軸に明示的接続.

---

## 実装履歴

| 日付 | part | 実装 | 達成原則 | baseline |
| --- | --- | --- | --- | --- |
| 2026-04-29 | Win版#132 part 76 | `docs/HANDOFF_BUNDLE_SPEC.md` 新規 (= ディレクトリ構造 + 6 Step flow + README フォーマット + cross-instance-pr 比較 + 3 Use Case + done 移動) | PLATFORM #4 dogfood | PLATFORM 3.0 → **4.0/7** |

---

*Win版#132 part 76 / 2026-04-29 起票 / PLATFORM #4 (Handoff Bundle Driven) dogfood / 全 stack 統合委譲形式 / cross-instance-pr 進化形態 / 9 part 連続 dogfood (part 68-76)*
