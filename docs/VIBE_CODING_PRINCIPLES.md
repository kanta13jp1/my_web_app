# Vibe Coding 7 原則 — 自分株式会社 Production AI 開発責任ガイドライン

> このドキュメントは、自分株式会社の **12 インスタンス並行 AI 開発 (10 Claude + 2 Codex)** が **Production 環境で破綻しないため** の責任設計原則を定義する **必守原則** である.
>
> **ソース**: NotebookLM Notebook [Vibe Coding: Responsible Engineering in the Era of AI Agents](https://notebooklm.google.com/notebook/ddde5a4b-ce1a-405d-8291-a334a9371454)
> Anthropic engineer 解説動画 "Vibe coding in prod | Code w/ Claude" を題材とした、AI agents 時代の責任あるエンジニアリング原則 (2026-04-28 取り込み)
>
> **位置づけ**: 既存 7 設計軸 + **メタレイヤー (= AI 開発を持続させる運用方法論)** として追加 (= 8 番目軸)
> - PHILOSOPHY (why) / AI_DEV (how) / AI_CHARACTER (who) / IMBUE (how it feels)
> - COLLAB_AI (how it evolves) / MCP_AUTH (how it opens) / AI_VIDEO (how it appears as media)
> - **VIBE_CODING (how it stays responsible in production)** ← 新規 8 番目

---

## なぜ必要か

自分株式会社は既に **12 インスタンス AI 並行開発** + **OPS-28 charter** + **6 設計軸 + AI_VIDEO** で巨大な AI 駆動システムを運営している. しかし:

- AI が **production code を直接書く** 事象が頻発 (= Vibe Coding 状態)
- 人間 (CEO) が **全コードを読む時間** はない (= 12 インスタンス × 数百 commit/日)
- AI の **暴走 / hallucination / context drift** が起きた時のセーフネットが分散している
- 「AI を信頼してマージするか / 自分でレビューするか」の **判断軸が言語化されていない**

Anthropic engineer 視点では「Vibe Coding は不可避」だが、**Production で破綻しない条件** がある. それを 7 原則化して自分株式会社の運用に組み込む必要がある.

= 既存 7 設計軸が「**何を作るか / どう作るか / どう振る舞うか**」を定めるなら、Vibe Coding は「**作った後どう責任を保つか**」を定める **メタレイヤー**.

---

## 7 原則

### 原則 1: 幹 (Core) と葉 (Leaf) の厳格な分離アーキテクチャ (Trunk/Leaf Separation)

**ルール本文**: 他が依存する **コア** は人間が保護し、技術的負債が許容される末端の **リーフノード** にのみ Vibe Coding を全委任する. コア / リーフの境界線をアーキテクチャで明示する.

**なぜ重要か**: AI が DB スキーマ / Edge Function 基盤 / MCP_AUTH を直接書き換えると、依存する全機能が連鎖的に壊れる. Vibe Coding を許す範囲を **物理的にリーフに閉じ込める** ことで爆発半径を制限.

**どう適用するか**:
- **コア (人間管理 / Vibe Coding 禁止)**:
  - `supabase/migrations/` の **schema 変更** (= 全 EF / Flutter が依存)
  - `supabase/functions/_shared/` の **共通モジュール** (= EF 全体に依存)
  - `lib/main.dart` の **routing 設計**
  - `~/.claude/hooks/inject-rules.txt` の **rule 設計**
  - `docs/PHILOSOPHY.md` 等の **設計軸 docs**
- **リーフ (12 fleet 全委任 OK)**:
  - `lib/widgets/*` 単独 widget (= 他 widget から import されない)
  - `supabase/functions/<EF>/<action>` の単独 action 追加 (既存 hub 内)
  - `supabase/migrations/YYYYMMDD_seed_*.sql` の seed 追加 (= データのみ)
  - `docs/blog-drafts/*` 等の **生成コンテンツ**
- ❌ NG: AI が `_shared/ai_character_preamble.ts` を勝手にリファクタリング
- ✅ OK: AI が `lib/widgets/quiz_card_widget.dart` を新規作成・編集

### 原則 2: AI のプロダクトマネージャー (PM) としての振る舞い (AI as PM)

**ルール本文**: AI にいきなりコードを書かせない. 最初の 15-20 分は **計画用インスタンス** が context 探索・要件定義・実装計画を **Plan アーティファクト** として書き、それを実装用インスタンスに渡す.

**なぜ重要か**: コンテキスト不足のままコード生成すると、**既存 pattern と整合しない実装** や **重複機能** が生まれる. 計画フェーズの 15 分が、後の数時間のリワークを救う.

**どう適用するか**:
- 12 fleet のうち **1-2 インスタンス** を「事前計画専任」として稼働 (= "Plan" agent)
- Plan アーティファクト形式: `docs/plans/<task-id>.md` に「現状 / 要件 / 制約 / 影響範囲 / 実装ステップ」
- Plan が承認されたら **別の Codex/Claude インスタンス** に渡して実装開始 (= "Implement" agent)
- **新規 cross-instance-pr** の起票時はこの形式に倣う (= 既に `docs/cross-instance-prs/*` で実践中)
- ❌ NG: 「修正してください」だけ言って即コード生成
- ✅ OK: 「Plan して」 → アーティファクト → レビュー → 「Implement」

### 原則 3: 証明可能な安全性を持つサンドボックス (Provably Correct Sandbox)

**ルール本文**: フロントエンド (リーフ) で AI が暴走しても、バックエンド (コア) のセキュリティ / データが **絶対に侵害されない構造** を物理的に作る. RLS / Auth / 権限境界をフロントエンド任せにしない.

**なぜ重要か**: AI が `lib/widgets/quiz_card.dart` で `Supabase.rpc('admin_delete_all', {})` を生成しても、サーバー側で拒否される構造が必要. Vibe Coding を許す前提として **侵害不可能な防壁** が要る.

**どう適用するか**:
- **Supabase RLS** を **全 table に強制** (deny-by-default / 例外は明示的 GRANT のみ)
- **Edge Function** に **all auth check via mcp_auth_guard.ts**
- **API key / secret** は Flutter Web に絶対埋め込まない (= EF 経由のみ)
- 新規 RLS migration は **Win版 + Codex#1 二重レビュー** (= part 1 のコア管理)
- 定期 RLS audit script 追加候補: `scripts/audit_supabase_rls.py`
- ❌ NG: Flutter で `Supabase.from('users').delete()` 直接呼出 (= RLS なし pass)
- ✅ OK: `Supabase.rpc('user_self_delete', ...)` (= RLS で本人 only 検証)

### 原則 4: 抽象化レイヤーの入出力 (I/O) 検証 (Black-Box I/O Verification)

**ルール本文**: 実装詳細 (コード) の存在は忘れても **プロダクトの存在は忘れない**. 人間 (CEO) は **入出力の結果のみで検証** を行う. コードを 1 行ずつ読むボトルネックを意図的に放棄.

**なぜ重要か**: 12 インスタンス × 数百 commit/日 を全て読むのは物理的に不可能. CEO の役割は **プロダクト挙動の検証** (= UI 操作で要件を満たすか) であって、コードレビューではない.

**どう適用するか**:
- 各機能リリース時の human-side 検証は **本番 UI で操作 → 期待 I/O か確認** のみ
- Playwright + design-skills agent で UI を **AI に検証させる** (= Rule [UI-VERIFY])
- コードレビューは **同 territory の他 instance** に委譲 (= human はマージ承認のみ)
- メンタルモデル: 「Flutter / Supabase は **下請会社**. 私は **発注者** = 出来上がりだけ見る」
- ❌ NG: AI 生成 PR を 1 行ずつ読んで認知負荷で詰まる
- ✅ OK: `https://my-web-app-b67f4.web.app/<feature>` 操作 → 期待動作 → ✅

### 原則 5: ミニマル E2E テストによる実装理解の代替 (Minimal E2E Tests Replace Code Reading)

**ルール本文**: 人間は実装コードを読まず、**AI に書かせたシンプルなテストケース** を読んで合意できればコードを信頼する. 単体テストではなく **integration / E2E テスト** が信頼の最終手段.

**なぜ重要か**: 単体テストは実装詳細に密結合 → AI が refactor すると必ず壊れる. E2E は **「ユーザー視点での挙動」** を測るので AI の Vibe Coding でも壊れない. 人間は E2E のシナリオ列だけ見れば十分.

**どう適用するか**:
- **Flutter Integration Test (`integration_test/`)**: 主要ユーザー操作 (login → 機能利用 → logout) を 1 シナリオ = 1 ファイル
- **EF Integration Test**: Supabase REST + EF endpoint 結合を 1 機能 = 1 test (= 既に `test/web_import_smoke_test.dart` で実践中)
- **新規機能 PR の merge 条件**: E2E test 1 ケース追加 + GHA で 24h soak 安定 → 自動 merge OK
- 単体テスト (test/widget) は **AI 自由 / 安定性ベンチマークではない**
- ❌ NG: PR ごとに widget test 100 ケース要求 → AI が refactor で全壊
- ✅ OK: PR ごとに E2E 1 ケース → CI で 24h 安定 → merge

### 原則 6: セッションの定期的なコンパクション (Periodic Session Compaction)

**ルール本文**: セッションが長引くことによる AI のハルシネーション / 軌道逸脱を防ぐため、**キリの良いタイミングで状態を要約して仕切り直す**. 数十万トークン消費 → 数千トークンの要約 → 新クリーンインスタンスへ.

**なぜ重要か**: 1 セッション 600K+ トークン消費すると AI は古いコンテキストを優先し、**最新の state を見失う** (= 関数名を勝手に変更 / 削除済 file を再追加 等). 既に Win版#132 part 50 wakeup や session_summary で実践中だがルール化されていなかった.

**どう適用するか**:
- **コンパクション基準**:
  - 600K+ tokens 消費
  - 1 セッション 10+ part 経過
  - 機能区切り (= 設計軸確立 / 大型 cross-instance-pr 完了)
- **コンパクション形式**: `memory/project_YYYYMMDD_<inst>_<part>_session_summary.md`
  - 14 part × 4 軸 learning + 翌日確認 list (= 既に Win版#132 session_summary で実践)
- **新インスタンス起動時**: summary file を最初に読ませる
- 月 1 回 PS#1 が `consolidate-memory` skill で旧 summary を MEMORY.md 編入
- ❌ NG: 1 セッション 14 part 後にコンパクションせず継続 → AI 軌道逸脱
- ✅ OK: 14 part 達成 → session_summary.md 作成 → 新セッション = summary ベースで再開

### 原則 7: 指数関数的進化の受容 (Embrace Exponentials)

**ルール本文**: AI のタスク処理能力が **7 ヶ月で倍増** し、いずれ **数百万倍賢く** なる未来を見据え、自分自身がコードを読む「ボトルネック」になることを **意図的に放棄** する. 検証システム (原則 4, 5) の構築にのみリソースを集中投資.

**なぜ重要か**: AI が 1 日で 1 週間の仕事を自律処理できる未来に、人間が **コードレビュー速度** で律速されるのは破滅的. 「AI を信頼するシステム」を構築することが、CEO の仕事の本質.

**どう適用するか**:
- CEO の作業時間を以下に再配分:
  - 30% = 設計軸 docs 更新 (PHILOSOPHY/AI_DEV 等の **judgment 部分**)
  - 30% = E2E test シナリオ設計 (= 原則 5 の検証システム)
  - 20% = OPS-28 charter / cross-instance-pr routing (= 原則 2 の Plan)
  - 10% = production UI 操作検証 (= 原則 4)
  - 10% = エコシステム外 (= NotebookLM 蒸留 / 競合調査 / fleet 拡大)
- **コードを書かない / 読まない** ことを罪悪感なく受容
- 12 fleet → 24 fleet → 100 fleet への拡大計画は **半年単位** で見直し
- ❌ NG: 「全コード読まないと不安だから fleet を 6 に縮小」 (= 指数進化を逆走)
- ✅ OK: 「fleet を 24 に増やすため、検証システムを先に整備」

---

## 7 原則の相互依存

```
[#1 Trunk/Leaf 分離]      ← 物理的境界
     ↓ コアを守る前提で
[#3 Sandbox]              ← 侵害不可能な防壁
     ↓ 安全な土台で
[#2 AI as PM]             ← Plan → Implement の順序
     ↓ 計画ありで
[#5 Minimal E2E test]     ← 検証の最終手段
     ↓ 検証ありで
[#4 I/O verification]     ← 人間は出口だけ見る
     ↓ 検証スループット向上で
[#6 Periodic Compaction]  ← 持続性確保
     ↓ 持続性ありで
[#7 Embrace Exponentials] ← 指数進化を受容
```

= **境界 → 防壁 → 計画 → 検証 → 抽象化 → 持続 → 進化** の 7 段ラダー. 1 段抜けると上位段が成立しない.

---

## 既存 7 設計軸との関係

| 既存軸 | Vibe Coding 7 原則の augmentation 関係 |
| --- | --- |
| PHILOSOPHY (why) | 原則 4 (I/O) + 原則 7 (Exponentials) で「CEO の本質的役割再定義」を補強 |
| AI_DEV (how) | 原則 1 (Trunk/Leaf) + 原則 5 (E2E) で「AI 駆動開発の物理的安全装置」を提供 |
| AI_CHARACTER (who) | (直接関連なし — character は AI の人格 / Vibe Coding は AI の運用方法) |
| IMBUE (how it feels) | (直接関連なし) |
| COLLAB_AI (how it evolves) | 原則 2 (AI as PM) で「Plan → Implement の Pattern」を追加 |
| MCP_AUTH (how it opens) | 原則 3 (Sandbox) で「侵害不可能な防壁」を補強 |
| AI_VIDEO (how it appears) | (直接関連なし — 動画特化軸) |

= 7 軸中 5 軸に対して 1+ 原則ずつ augmentation を提供. 残り 2 軸 (CHARACTER / IMBUE / VIDEO) には Vibe Coding は直接介入しない (= 設計軸の専門領域を侵犯しない).

---

## 自分株式会社 既存ベースライン評価

| 原則 | 現状 | gap |
| --- | --- | --- |
| #1 Trunk/Leaf 分離 | 部分 ✅ (WORKDIR-ISOLATION rule + EF-CAP-50 rule) | 「コア / リーフ」明示 docs なし → 本 docs で解消 |
| #2 AI as PM | ✅ (cross-instance-pr が Plan アーティファクト機能) | 「事前計画専任 instance」役割未明示 |
| #3 Sandbox | ✅ (RLS + mcp_auth_guard.ts + EF auth) | RLS audit script 未実装 |
| #4 I/O verification | 部分 ✅ ([UI-VERIFY] rule + Playwright MCP) | コードを読んでしまう癖が残る |
| #5 Minimal E2E test | 部分 ✅ (web_import_smoke_test.dart) | 主要 user flow の E2E カバレッジ不足 |
| #6 Periodic Compaction | ✅ (session_summary.md + memory/MEMORY.md インデックス) | コンパクション基準未明示 |
| #7 Embrace Exponentials | △ (12 fleet 達成済 / 24 fleet 計画なし) | fleet 拡大計画 + CEO 作業時間配分 docs なし |

= **4.5/7** ベースライン. 残 gap = 「明示 docs 化」「audit script」「fleet 拡大計画」の 3 種.

---

## チェックリスト (新機能 PR 時)

- [ ] **#1 Trunk/Leaf**: この変更はコア / リーフどちらか? コアならレビュー強化
- [ ] **#2 AI as PM**: Plan アーティファクト先行作成済か?
- [ ] **#3 Sandbox**: RLS で防壁が効くか? Flutter 直接書込なし?
- [ ] **#4 I/O verification**: UI 操作で要件確認済か?
- [ ] **#5 Minimal E2E test**: E2E 1 ケース追加 + 24h soak 安定?
- [ ] **#6 Compaction**: 600K+ tokens 消費なら session_summary 作成?
- [ ] **#7 Exponentials**: コードを読まずマージ判断できるか?

---

## 整合性監査 (定期セルフレビュー)

`scripts/check_vibe_coding_compliance.py` (将来追加):
- `lib/main.dart` 等 **コアファイル** の編集 commit を週次集計し、人間レビューが 100% か確認
- `integration_test/*` の E2E カバレッジを週次レポート (主要 flow / coverage)
- session_summary 作成頻度を月次集計 (= 600K+ token セッション数 / コンパクション率)
- 違反検出時は GitHub Issue 自動作成 (= COLLAB_AI Verifier-Generator + OPS-28 改善トリガー連携)

---

## 原則 #4 強化: Black-Box I/O Verification セルフチェック (Win版#132 part 81 / 2026-04-29)

VIBE #4 (Black-Box I/O Verification) の **dogfood セルフチェック** を確立する. CEO が「コードを読まない宣言」を破る兆候を **常時検出** + **自動修正圧力** をかける.

### 4.1 「コード読み」アンチパターン早期検出

| アンチパターン | 検出方法 | 修正圧力 |
| --- | --- | --- |
| **AI 生成 PR を 1 行ずつ読む** | session log で `Read` tool が同 file 5+ 回 | → integration_test を AI に書かせて test 内容のみ読む (= 原則 #5) |
| **diff を全部読む** | session log で `git diff` が 100+ 行 stdout | → 本番 UI 操作で要件確認 (= UI-VERIFY rule) |
| **「念のため」の関数追跡** | session log で symbol 検索が 10+ 回 | → 関数追跡せず I/O テストで代替 |
| **未使用コード探索** | session log で grep `unused` 多発 | → COLLAB_AI Verifier-Generator (= feature-review.yml) に委譲 |

= AI session log 自体が **#4 違反の証跡**. 自己 audit 可能.

### 4.2 PR merge 判断フロー (= コード読まない決定木)

```
[AI 生成 PR 提示]
        ↓
[Q1: integration_test 1 シナリオ含むか?]
   NO → reject (= 原則 #5 違反 / 受入禁止)
   YES ↓
[Q2: 本番 UI で機能動作確認できるか?]
   NO → 動作確認できる feature flag + manual UAT 経由
   YES ↓
[Q3: schema / RLS 変更を含むか?]
   YES → CEO レビュー必須 (= Tier 1 = CORE_LEAF_BOUNDARY 参照)
   NO ↓
[Q4: 24h soak で CI green 維持?]
   NO → wait 24h
   YES ↓
[merge OK]
```

= **コードを 1 行も読まずに 4 質問で判定**. 全質問が I/O 観測のみ.

### 4.3 月次セルフチェック (= future automation)

`scripts/check_vibe4_compliance.py` (= 将来 PS#1 month-end skill 統合):
- 直近 30 日の Win版 セッション log から:
  - `Read` tool 呼出回数 / 同 file 重複読
  - `git diff` 出力行数 (累計)
  - integration_test を読まずに merge した PR 件数
- 集計値が閾値超過 = GitHub Issue 自動起票 (= 「Win版 #4 違反検出 / コード読み復活兆候」)

### 4.4 12 fleet 共通展開

Win版以外の 11 fleet にも本セルフチェックを展開. 各 instance の inject-rules.txt に [VIBE-30] block 経由で 4.1-4.2 の判断フロー注入済 = 自動的に伝播.

= **CEO 1 人ではなく 12 fleet 全体が「コード読まない」習慣** を維持.

### 4.5 PHILOSOPHY 接続

PHILOSOPHY 原則 #6 (資本=時間) との直結:
- コード読み 1h = CEO の戦略時間 1h を消費
- I/O 検証 5 分 = 同等品質判定 + 残 55 分を戦略に投資
- 月 100h 戦略時間捻出 = 設計軸 docs / NotebookLM 蒸留 / E2E 設計に再配分

= VIBE #4 は **CEO 時間配分の根本原則**. 単なる効率化ではなく、自分株式会社の **存在意義**.

### 4.6 ターミナル監視からの解放 (= Claude Code mobile push 採用 / Win版#132 part 85 / 2026-04-29)

「コード読み」と並ぶ **第 2 の old habit** = **ターミナル監視**. AI fleet が実行中、ずっと CLI を見ていることは、コード 1 行ずつ読むのと同等の戦略時間消費.

#### 解放手段: Claude Code mobile push notification (= 2026-04 公式機能)

```
1. Claude モバイルアプリ install
2. 各 instance で /remote-control (= デバイスペアリング)
3. /config で「Push when Claude decides」有効化
```

= **長時間タスク完了 / Claude が入力待ち** で **スマホ push 通知**. ターミナルから離れて OK.

#### CEO 視点での価値

| 観点 | Before (= ターミナル監視) | After (= push 通知) |
| --- | --- | --- |
| monitoring time | 月 20-40h | **0h** |
| fleet 拡大限界 | 12 instance (= 物理監視 限界) | 24-100 instance (= push 通知のみ) |
| 戦略時間 | 30% | **+10-15%** (= 月 16-24h 上振れ) |
| 場所制約 | デスク常駐 | スマホ持参で OK |

= **VIBE #4 の Phase 2 完成形** (= コード読み 0% + ターミナル監視 0%).

#### 12 fleet 全展開 (= cross-instance-pr 起票 / Win版#132 part 85)

- 全 11 instance (= Win 以外 / VSCode + PS#1-6 + WEB + 📱モバイル + Codex#1-2) で同設定 routine 実施
- 各 instance log に「mobile push 設定済」記録
- 詳細: `docs/cross-instance-prs/20260429_mobile_push_fleet_rollout.md`

#### FLEET_SCALING_ROADMAP Phase 2 への接続

「コード読み 0%」目標 (= 1 年以内達成計画) の **必須インフラ**:
- 12 → 24 fleet (Phase 2): monitoring 物理不可能 → push 必須
- 24 → 100 fleet (Phase 4 IPO 期): push なしでは fleet 運用崩壊

= mobile push **採用は Phase 2 ブロッカー第 6 件目** (= 既存 5 件 + 1 = 6 件).

---

## 実装履歴

| 日付 | part | 実装 | 達成原則 | baseline |
| --- | --- | --- | --- | --- |
| 2026-04-28 | Win版#132 part 66 | 軸確立 (docs + Rule [VIBE-30]) | — | 4.5/7 |
| 2026-04-29 | Win版#132 part 72 | `docs/CORE_LEAF_BOUNDARY.md` 新規 (4 Tier 統合表現 / Schema / Core / Leaf / Auto-Generated 明示) — SECOND_BRAIN #1 と同時 dogfood (1 doc 2 軸押上 第 1 例) | #1 Trunk/Leaf 厳格分離 | 4.5 → **5.5/7** |
| 2026-04-29 | Win版#132 part 73 | `docs/FLEET_SCALING_ROADMAP.md` 新規 (4 Phase milestone 12→18→24→50→100 / CEO 作業時間配分目標 / bottleneck 5 件分析 / scaling 哲学) | #7 Embrace Exponentials | 5.5 → **6.5/7** |
| 2026-04-29 | Win版#132 part 81 | 原則 #4 強化セクション追加 (= 4.1 アンチパターン早期検出 / 4.2 PR merge 4 質問判定フロー / 4.3 月次セルフチェック / 4.4 12 fleet 共通展開 / 4.5 PHILOSOPHY 接続) | #4 Black-Box I/O Verification | 6.5 → **7.0/7** |
| 2026-04-29 | Win版#132 part 85 | 4.6 セクション追加 (= ターミナル監視解放 / Claude Code mobile push 採用 / 12 fleet 全展開 cross-instance-pr 起票) | #4 拡張 (= Phase 2 完成形 への接続) | 7.0/7 維持 |

**🎉 第 1 軸 完全達成 (= 7/7)**: VIBE_CODING が 10 設計軸の中で **最初に baseline 7/7 完成** に到達.

**次回ターゲット**:
- #3 Sandbox 強化: `scripts/audit_supabase_rls.py` 新規 → Codex#1 cross-instance-pr 候補
- #5 E2E カバレッジ: `integration_test/golden_path_test.dart` 新規 → VSCode版 cross-instance-pr 候補
- #7 fleet 拡大計画: `docs/FLEET_SCALING_ROADMAP.md` 新規 → Win版 territory

---

*Win版#132 part 66 / 2026-04-28 起票 / NotebookLM ddde5a4b ("Vibe coding in prod | Code w/ Claude") ソース蒸留 / Rule [VIBE-30] / 8 番目の設計軸 (= メタレイヤー: AI 開発を持続させる運用方法論)*
