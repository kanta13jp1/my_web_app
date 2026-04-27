# Cross-Instance PR: 12-Instance Fleet — レガシー docs reconciliation

**作成**: Win版#132 part 44 / 2026-04-28
**依頼先**: PS版#1 (Rule 17 / instance config oversight)
**優先度**: MEDIUM — 体系整理 / 既存運用に影響なし
**推定工数**: 30-60 min / 3 ファイル更新

---

## 背景

ユーザー指示: 「Claude Code を 10 インスタンス + Codex を 2 インスタンス並行させる
開発フローとしたい」

Win版#132 part 44 で **canonical 12-instance manifest** を新規作成済:
[`docs/MULTI_INSTANCE_FLEET.md`](../MULTI_INSTANCE_FLEET.md)

合わせて以下を更新済:
- `CLAUDE.md` の `[WORKDIR-ISOLATION]` / `[INSTANCE-ROLES]` 行 → "12 スロット" 表記に
- `~/.claude/hooks/inject-rules.txt` `[WORKDIR-ISOLATION]` → 12 スロット roster + Codex 特有ルール

しかし以下の **レガシー docs** が古い構成を保持している:

| ファイル | 現状 | 問題 |
| --- | --- | --- |
| `docs/INSTANCE_CONFIG.md` | 3 インスタンス制 (2026-04-17 / WEB版廃止と書いてある) | 実際は 10 + 2 = 12 |
| `docs/MULTI_INSTANCE_COORDINATION.md` | 5 インスタンス制 (2026-04-19 / 📱スマホ版追加) | 実際は 10 + 2 = 12 |
| `docs/instance-constraints.md` | 制約発見ログ (時系列で正しい) | "10 インスタンス" 表記がなく 12 への言及もなし |

各 doc が **異なる時代のスナップショット** を取っているため、新人 / 他インスタンスが
読むとどれが正なのか分からない。

---

## 依頼内容

### 1. `docs/INSTANCE_CONFIG.md` 更新

- 冒頭の「3 インスタンス制」記述を「12 スロット fleet — canonical: MULTI_INSTANCE_FLEET.md」に置換
- `## インスタンス制約カタログ` セクションを **VSCode版 / Win版 / PS版#1-#6 / WEB版 / 📱スマホ版 / Codex#1 / Codex#2** の 12 行構成に拡張
- バージョン確認 (Step 1-3) は既存内容を維持
- 末尾「変更ログ」に 2026-04-28 行追加 (12 スロット fleet 統合)

### 2. `docs/MULTI_INSTANCE_COORDINATION.md` 更新

- 冒頭の「5インスタンス + マルチAI」を「**12 スロット fleet (10 Claude + 2 Codex)**」に書き換え
- `## インスタンス分担` 表に **PS版#5 / PS版#6 / Codex#1 / Codex#2** の 4 行を追加
- 既存 📱 スマホ版セクションは保持
- Codex の協働パターン (= MULTI_INSTANCE_FLEET.md "Codex 特有の運用" 4 ルール) を要約セクションとして追加

### 3. `docs/instance-constraints.md` 末尾追記

- `## インスタンス別 現行仕様` セクションに **Codex#1 / Codex#2** の 2 行追加
  - モデル: GPT-5.2-Codex
  - 主担当領域: docs/MULTI_INSTANCE_FLEET.md 参照
  - 制約: session 持たない / CLAUDE.md 全文 context 不可 / memory 書き込み禁止 (Claude が代行)

### 4. (任意) Codex worktree migration の実行

`docs/MULTI_INSTANCE_FLEET.md` 末尾「Codex 4 worktree → 2 スロット統合プラン」
セクションに移行手順がある。User 操作 1 回のみで済む安全なオペレーション。
PS版#1 が user に確認後に実行 (= main にマージ済の codex/* ブランチを削除して
標準 codex1/codex2 slot を作成)。

ただし既存 ad-hoc codex worktree (4 本) に **未マージの差分があれば実施しない**
こと (= 既存作業の喪失リスクあり)。事前 `git status` 確認必須。

---

## 完了条件

- [ ] INSTANCE_CONFIG.md / MULTI_INSTANCE_COORDINATION.md / instance-constraints.md の
      3 ファイルが 12 スロット fleet と一致
- [ ] 各 doc の冒頭に "**canonical: docs/MULTI_INSTANCE_FLEET.md**" cross-reference
      追加 (single source of truth の明示)
- [ ] commit message: `docs: 12-instance fleet reconciliation (PS#1)`
- [ ] push 後この cross-instance-pr を `docs/cross-instance-prs/done/` に移動

---

## 完了不要 (= Win版#132 part 44 で既に終了)

- ✅ `docs/MULTI_INSTANCE_FLEET.md` 新規作成 (245 行)
- ✅ CLAUDE.md hook table 2 行更新
- ✅ inject-rules.txt `[WORKDIR-ISOLATION]` フル書き換え

---

*Win版#132 part 44 / 2026-04-28 起票 / commit はまだ pending*
