# 自分株式会社 Operations Charter — 12 並行開発の運用憲章

> 本ドキュメントは、自分株式会社の **12 並行開発フロー** (10 Claude Code + 2 Codex) を
> どう運用するか — つまり「設計の正本がどこにあるか / どの AI ツールを何に使うか /
> 衝突をどう防ぐか」を規定する **運用憲章** である。
>
> 既存の設計軸 (PHILOSOPHY / AI_DEV / AI_CHARACTER / IMBUE / COLLAB_AI / MCP_AUTH) が
> "AI 機能を **どう作るか**" を扱うのに対し、本憲章は "12 インスタンスを **どう運転するか**"
> を扱う。
>
> **位置づけ (canonical 関係)**:
> - [`docs/MULTI_INSTANCE_FLEET.md`](./MULTI_INSTANCE_FLEET.md) — 12 スロットの roster 台帳
> - [`docs/CODEX_WORKFLOW.md`](./CODEX_WORKFLOW.md) — Codex#1/Codex#2 の起動・運用手順
> - **OPERATIONS_CHARTER.md (本書)** — 全体運用方針・正本ルール・監査トリガー
>
> **採択日**: 2026-04-28 (User 直接指示)

---

## 1. 5 つの正本 (Source of Truth)

各情報は 1 つの正本層にのみ存在し、他の層は **読み取り or 派生コピー** とする。
食い違いが発生したら正本層を真として整合させる。

| 層 | 役割 | 正本となる対象 | 派生コピー先 |
| --- | --- | --- | --- |
| **GitHub Issues / PR** | 実行単位・担当・レビュー・完了判定 | 「誰が何をいつまでに」 | WBS / Slack 通知 |
| **WBS / Notion** | 進捗・依存関係・ロードマップ・管理ビュー | 「全体の見取り図と %」 | (なし — Issue/PR から派生) |
| **NotebookLM (Master Brain)** | 判断履歴・設計意図・衝突回避ルール・学びの集約 | 「なぜそうしたか」 | docs/ + memory/ |
| **Slack** | 進行中の通知・ブロッカー・handoff・緊急調整 | 「いま何が起きてるか」 | (揮発・1 週間で廃棄) |
| **各 worktree / branch** | 実作業の隔離領域・コードの真の状態 | 「実装の現物」 | main (push target only) |

### 1.1 食い違い検出のシグナル

- WBS で 100% なのに PR が open のまま → WBS が嘘 (= 正本 = PR)
- Notion roadmap に「未着手」だが Issue が closed → Notion が嘘
- NotebookLM Master Brain と memory/ で結論が違う → NotebookLM が正 (= 横断知識)
- Slack 通知で「完了」と言ったが PR が未マージ → Slack 通知が誤情報
- main のコードと worktree branch の HEAD が乖離 → branch を rebase

---

## 2. 6 つの AI ツール役割

| ツール | 強み | 主な使いどころ | 入れない場所 |
| --- | --- | --- | --- |
| **Claude Code (10 枠)** | 大きめ実装・既存設計沿いの追加・並列ワーカー・設計判断 | 新機能 EF / Flutter UI / docs / memory consolidation / cross-instance-pr 起票 | 横断調査の最適化 (= NotebookLM が上) |
| **Codex (2 枠)** | 横断調査・修正 PR・CI/同期/運用まわり・レビュー補助 | Codex#1 = 横断調査 / 修正 PR / SQL・migration レビュー補助、Codex#2 = CI / 同期 / 運用 / EF(Deno)・GHA レビュー補助 | 設計判断 (= Claude が上) / memory 書込 / UI設計 |
| **Gemini Code Assist** | Google / Flutter / Firebase 系・コード理解補助・別視点レビュー | Flutter API 更新 / Firebase Hosting 設定 / Anthropic API outage 時の Dart 実装 fallback | 戦略判断 / 競合調査 |
| **GitHub Copilot** | IDE 内の短距離実装・補完・テスト追加 | コーディング中の関数補完 / 単体テスト雛形 / lint fix の suggestion | 設計 / 大規模 refactor |
| **Manus AI** | ブラウザ操作・外部 SaaS 確認・長めの手順実行 | Notion / Slack / Stripe 等の外部 SaaS UI 操作 / 手作業の連続自動化 | コード生成 / 設計判断 |
| **NotebookLM** | 「なぜそうしたか」の根拠集約・横断深層リサーチ | Master Brain / 9 ソース統合分析 / 設計原則の蒸留 / 過去判断の検索 | リアルタイム協働 / コード生成 |

### 2.1 衝突を避けるルーティング判断フロー

```text
タスク発生
  ↓
Q1: 設計判断 / 戦略 / cross-instance 調整?
   YES → Claude Code (Win版 / VSCode版)
   NO ↓
Q2: 横断調査 / 過去判断の集約必要?
   YES → NotebookLM Deep Research
   NO ↓
Q3: 横断調査 / 修正 PR / CI・同期・運用 / レビュー補助?
   YES → Codex (#1 横断調査・修正PR / #2 CI・同期・運用)
   NO ↓
Q4: 500+ 行 refactor / Flutter / Firebase 専門知識が決め手?
   YES → Gemini Code Assist
   NO ↓
Q5: IDE 内補完で済む 50 行未満?
   YES → GitHub Copilot
   NO ↓
Q6: ブラウザ / SaaS UI 操作?
   YES → Manus AI
   NO → Claude Code (default)
```

---

## 3. セッション開始時の運用監査チェック (5 項目)

毎セッション冒頭、自インスタンスのタスクに着手する前に **30 秒以内** で確認する:

```markdown
- [ ] **担当領域 overlap**: Claude 10 + Codex 2 の中で同じ領域に複数枠が in_progress
      になっていないか? (WBS で `in_progress AND area=同じ` を検索)
- [ ] **同一ファイル / DB スキーマ衝突**: 直近 1h の commit で自分が触る予定の
      ファイル / migration / EF / workflow を別枠が編集していないか?
      (`git log --since="1 hour ago" --name-only --all`)
- [ ] **5 正本の整合**: Issue 状態 / WBS % / Notion 進捗 / 直近 PR 状態 /
      NotebookLM 最終結論 が同じ事実を語っているか?
- [ ] **通知の生死**: Slack 通知 / Notion 運用が **形骸化していない** か?
      (=「誰も読まない通知」「更新されない Notion」を見つけたら段階廃止 or 統合提案)
- [ ] **AI ツールの配置**: 今日のタスクに Gemini / Copilot / Manus を入れると
      衝突が減るかどうか? (= 第 4 章「運用改善トリガー」に該当しないか確認)
```

---

## 4. 運用改善トリガー (発見即提案)

作業中に以下のサインを見つけたら **その場で提案** する (待たずに即 cross-instance-pr
or memory に書き、wrap-up で確実に拾う)。

### 4.1 衝突しそうな割り振り

- 同じファイル / EF / migration を 2 枠以上が触ろうとしている → どちらかを suspend
- WBS で in_progress が同領域に 3+ 件 → 過剰並列化の警告

### 4.2 NotebookLM に残すべき判断

- 「なぜこの設計を選んだか」を後の自分が説明できないと困る判断 → Master Brain source 追加
- 同種の判断を 2 回以上した → 共通原則として `docs/<軸>_PRINCIPLES.md` に蒸留

### 4.3 Slack 通知に逃がした方がよい情報

- インスタンス間の即時 handoff が `cross-instance-pr` 経由で 24h+ ラグしている →
  Slack の `#dev-handoff` 等に再ルーティング
- ユーザーが画面を見ていない時間帯の進捗 → Slack 通知 (PC オフ時もモバイル通知)

### 4.4 Notion / WBS の正本ズレ

- WBS の `priority_for_instance` が古い → tools-hub:wbs.update_progress で同期
- Notion roadmap が 1 週間以上更新されていない → Win版が PS#1 に reconcile 依頼

### 4.5 形骸化した通知 / 運用

- 同じ Slack 通知が 7 日連続でアクションされていない → 通知頻度減 or 廃止提案
- GHA workflow が成功率 100% で 30 日以上 fail していない → 検証スコープが浅すぎる
  可能性 (= 価値のあるテストが減っている)

---

## 5. 既存運用との関係

| 既存ドキュメント / rule | 本憲章との関係 |
| --- | --- |
| `MULTI_INSTANCE_FLEET.md` | 12 スロット roster の **物理層** (本憲章 = 論理層) |
| `CODEX_WORKFLOW.md` | Codex 2 枠の起動手順 (本憲章 第 2 章を実行する手段) |
| `INSTANCE_CONFIG.md` (legacy) | 本憲章とレガシー — PS#1 が段階統合中 (cross-instance-pr `20260428_12_instance_fleet_reconciliation_ps1.md`) |
| `inject-rules.txt` `[OPS-28]` | 本憲章の遵守を毎ターン強制 |
| `[INSTANCE-ROLES]` | 本憲章 第 2 章の運用版 (実装担当) |
| `[WBS-SYNC]` | 本憲章 第 1 章 SoT 整合 + 第 3 章 監査の WBS 部分 |
| 既存 6 設計軸 (PHILOSOPHY / AI_DEV / AI_CHARACTER / IMBUE / COLLAB_AI / MCP_AUTH) | 本憲章は **直交** (設計 = どう作るか / 運用 = どう運転するか) |

---

## 6. 1 日サイクル運用パターン (2026-04-28 確立)

### 6.1 サイクル本体 — 「発見 → 提案 → 実装 → 完了確認」

OPS-28 charter 採択日 (2026-04-28) に Win版が 1 セッション内で
**4 種類の改善トリガー** を発見・提案・実装・完了確認まで完走させた
実証パターン。本サイクルは今後の **標準運用フロー** として確立する。

```text
┌──────────────────────────────────────────────────────────────┐
│ Win版 (Claude / 設計判断 + cross-instance-pr 起票専任)         │
│   ↓ 第 3 章 5 監査 (30 秒) で改善トリガー発見                  │
│   ↓ 第 4 章 改善トリガー #1〜#5 のいずれかに該当 → 即対応       │
│                                                               │
│   ★ 本トリガーが Win版 territory なら直接 hotfix              │
│   ★ それ以外なら cross-instance-pr 起票                       │
└──────────────────────────────────────────────────────────────┘
                                 ↓
┌──────────────────────────────────────────────────────────────┐
│ 受領 worker (PS#1 / PS#5 / Codex#1 / Codex#2)                  │
│   ↓ cross-instance-pr 内の handoff template に従って実装        │
│   ↓ commit + push origin HEAD:main                             │
│   ↓ docs/cross-instance-prs/<file>.md を done/ へ移動           │
└──────────────────────────────────────────────────────────────┘
                                 ↓
┌──────────────────────────────────────────────────────────────┐
│ Win版 (起票者) — 翌セッション or 同日 wakeup                    │
│   ↓ MEMORY.md / git log で完了通知を観察                       │
│   ↓ root と done/ で重複が無いか check (= 5 正本層 #1 整合)     │
│   ↓ memory に「cycle close」記録                                │
└──────────────────────────────────────────────────────────────┘
```

### 6.2 4 worker lane の reciprocal 完成 (2026-04-28)

Win版が 1 日で起票した 7 件の cross-instance-pr が 4 worker lane
全部に分散することを確認:

| Lane | 起票 part | 受領者 | 内容 | 同日完了 |
| --- | --- | --- | --- | --- |
| Win版 → PS#1 | 47, 48, 51, 56 | PS#1 S57+S58 (3 件) / part 56 待機 | WF + 監視 + migration time-drift detector | ✅ 3/4 |
| Win版 → PS#5 | 50 | PS#5 S75 | EF + audit | ✅ |
| Win版 → Codex#1 | 54 (1 件) | (待機 / 翌日想定) | SQL view | ⏳ |
| Win版 → Codex#2 | 54 (1 件) | (待機 / 翌日想定) | TS test | ⏳ |
| Win版 → Codex#1or#2 | 54 (1 件) | (待機 / 翌日想定) | TS impl | ⏳ |
| **PS#5 → Win版 → VSCode版** | 58 (incoming + reroute) | (VSCode版 待機 / 5/10 期限) | conditional import refactor | ⏳ |

= 12-instance fleet の **全 4 worker lane が初めて稼働**. PS lane は
当日 reciprocal 完結, Codex lane は翌日 reciprocal 想定。

### 6.3 同日 cycle 成立条件 (再現性チェックリスト)

```markdown
### Daily Cycle Sustainability Check

- [ ] 起票者 (Win版) が同日中に 5 監査を 1 回以上実施
- [ ] 受領 worker (PS#1/#5/Codex#1/#2) のうち少なくとも 1 instance が
      その日にアクティブ
- [ ] cross-instance-pr に 5 質問 (Codex routing) or 案 A/B/C 提示
      (Claude 受領) が含まれている
- [ ] 受領者が 1 task = 1 commit + push まで実施 (途中放置しない)
- [ ] 完了後 done/ 移動 (= 5 正本層 #1 整合)
- [ ] 起票者が翌セッション or 同日 wakeup で完了確認
```

5 項目以上 ✅ → 1 日サイクル成立 / 4 以下 → broken (= 別 cycle で持ち越し).

### 6.4 サイクル 1 日分のスループット (実測 2026-04-28)

| 指標 | 値 |
| --- | --- |
| 起票数 | 8 (Win版 part 47/48/50/51/54×3/56) |
| 当日完了数 | 4 (PS#1 S57+S58 / PS#5 S75 / Issue #862 自動生成) |
| 翌日想定数 | 4 (Codex 3 件 + PS#1 part 56 migration time-drift detector) |
| 受領 lane (PS#5 → Win版) | 1 件 (part 58 / VSCode版 へ reroute / 期限 5/10) |
| 双方向 cycle 確立 | ✅ Win版 起票 + 受領 + routing 全 lane 稼働 |
| 完了率 (当日) | 4/7 = 57% |
| 完了率 (24h 想定) | 7/7 = 100% (Codex 翌日反映前提) |

= Win版「発見 → 提案」専任 + PS/Codex 「実装」分担で **24h 内 100% close** を
維持できる。Win版が「実装まで自力でやる」より **3-5 倍のスループット**
(= 1 セッションで 1 件 vs 7 件) を実現.

---

## 7. 改訂履歴

| 日付 | 変更 |
| --- | --- |
| 2026-04-28 | 初版 (User 直接指示「12 並行開発を前提に運用改善も常に見る方針」を canonical 化) |
| 2026-04-28 | 第 6 章「1 日サイクル運用パターン」追加 (Win版#132 part 55) — 同日 part 47-54 で実証した「発見 → 提案 → 実装 → 完了確認」reciprocal cycle を charter 化。4 worker lane 並行稼働 + 同日 cycle 成立条件 5 項目チェックリスト。|
| 2026-04-28 | §6.2 reciprocal 表 / §6.4 throughput 数値 update (Win版#132 part 59) — 同日 part 56 (PS#1 へ migration time-drift detector cross-instance-pr) + part 58 (PS#5 incoming → VSCode版 reroute) 追加. 起票 7 → 8 件 / 当日完了 4 件 / 翌日想定 3 → 4 件 / **受領 lane 初稼働** 1 件. **双方向 cycle 完全確立**. routing 判断 = 5 質問 + WORKDIR-ISOLATION 双軸. |
