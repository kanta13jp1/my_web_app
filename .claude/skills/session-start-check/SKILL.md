---
name: session-start-check
description: |
  自分株式会社の全インスタンス (VSCode版 / PowerShell版 / Windowsアプリ版) でセッション開始時に
  必ず実行する Rule 14 (ツールバージョン) + Rule 10 (docs健全性) + 並行衝突チェックを
  一括実行する。

  Triggers on: "/session-start-check", "セッション開始チェック", "Rule14 + Rule10 確認",
  "並行インスタンス状態確認".

  引数なし。数十秒で完了する軽量スキル。
---

# session-start-check スキル

## 概要

セッション開始時に必ず必要な 4 つの確認を 1 コマンドで終わらせる。

1. **Rule 14**: `PYTHONUTF8=1 python3 scripts/check_versions.py` で主要ツールバージョン確認
2. **Rule 10 lite**: cross-instance-prs の pending / stale 検出
3. **並行衝突検出**: 直近 10 コミットからアクティブインスタンスを特定
4. **Rule 22 (PHILOSOPHY)**: 基本理念 9 原則の見出しを確認 (本セッション全機能判断の前提)

## 手順

### Step 0: workdir 検証 (WORKDIR-ISOLATION・必須)

```bash
# 自 cwd が worktree か確認 (main repo 直接編集禁止)
WORKTREE=$(git rev-parse --show-toplevel)
echo "現在の workdir: $WORKTREE"
case "$WORKTREE" in
  */worktrees/instance-*) echo "✅ 専用 worktree で作業中" ;;
  */worktrees/*) echo "⚠️ auto-generated worktree (固定名 worktree 推奨)" ;;
  *)
    echo "🚨 main repo 直接編集の危険! 即 worktree に切替えてください:"
    echo "   bash .claude/scripts/setup-instance-worktree.sh <vscode|win|ps>"
    echo "   cd .claude/worktrees/instance-<NAME>"
    ;;
esac
```

**期待結果**: `.claude/worktrees/instance-<NAME>` で作業中。それ以外は即切替。
別インスタンスの `git stash` / `git pull --rebase` で uncommitted 変更が消えるリスクを根本回避。

### Step 0.5: inject-rules.txt drift 確認 (Win版#132 part 135)

```bash
# canonical (= repo) と home (= ~/.claude/hooks/) の drift 確認
PYTHONUTF8=1 python scripts/sync_inject_rules.py --verify
```

期待: `✅ canonical kpi_pass=True / home kpi_pass=True / drift=False`.

drift 検出時:
- `--apply` で canonical → home (= 他 instance 編集を取り込む)
- `--reverse` で home → canonical (= 自分の編集を repo へ push 用 / PR レビュー後 commit)

詳細: [`docs/RULES_INDEX.md`](../../docs/RULES_INDEX.md)

### Step 1: ツールバージョン (Rule 14)

```bash
PYTHONUTF8=1 python3 scripts/check_versions.py
```

- 結果に「バージョン変更なし」が出れば OK
- 変更があれば `docs/tool-versions.md` 更新 + 制約解消チェック
- Windows でない (WEB版) の場合は `scripts/check_versions.py --web` は不可 → WebFetch で手動確認

### Step 1.5: Worktree 確認 (PS版・Win版 必須)

```bash
# PS版
pwd  # → C:/Users/kanta/GitHub/my_web_app_ps であることを確認
git branch --show-current  # → ps-main

# Win版
pwd  # → C:/Users/kanta/GitHub/my_web_app_win であることを確認
git branch --show-current  # → win-main
```

**main repo (`my_web_app`) にいる場合は即移動**:
```bash
# PS版ならここで cd して以後全ての操作は ps worktree で行う
cd C:/Users/kanta/GitHub/my_web_app_ps
git pull --rebase origin main
```

VSCode版のみ main repo での作業が許可されている。

### Step 2: cross-instance-prs の状態

```bash
ls docs/cross-instance-prs/ | grep -v done/
```

- root と `done/` の重複ファイルを検出: 内容一致なら root 削除 (stale)
- pending の PR がある → 本セッションで対応可能か判定

### Step 3: 並行衝突検出

```bash
git log origin/main --oneline -10
```

- 直近10コミットの末尾 `(XXX版#N)` を数える
- 同インスタンスが連続している → 他インスタンスは待機中 or クラッシュ
- 複数インスタンスが交互 → 並行作業中 → ROADMAP 末尾追記時の conflict 警戒

### Step 4: 基本理念 9 原則 確認 (Rule 22)

```bash
# PHILOSOPHY.md の 9 原則の見出しだけ確認 (本文は必要時のみ)
grep -E "^### 原則 [0-9]" docs/PHILOSOPHY.md | head -10
```

本セッション中の全機能設計・改修判断は以下の 9 原則に照らして方向性を検証する:

1. **CEO 感** — ユーザーが最終決定権を握る (自動化のみは NG)
2. **ミッション・コアバリュー駆動** — 機能はユーザーの価値観に紐付く
3. **取締役会 = 優しい mentor** — 監視・命令ではなく支援
4. **6 部署バランス** — R&D / 財務 / マーケ / 人事 / 本社 (人事最優先)
5. **商品 = ユーザーの価値** — 価値消費ではなく価値増大
6. **資本 = 時間** — 操作時間最小化・配分可視化
7. **資産 vs 負債** — 資産増・負債減を意識
8. **KPI = 昨日の自分** — 他人比較より自己進捗
9. **ゴール = IPO/ウェルビーイング** — 短期 KPI より長期幸福感

新機能設計時は `docs/PHILOSOPHY.md` 末尾のチェックリスト 9 項目を実施 (7+ ✅ で実装可)。

### Step 4.5: WBS 優先タスク取得 (Win版#128 必須・WBS-SYNC rule)

```bash
INST=$(echo $INSTANCE | tr A-Z a-z | sed -E s/版.*//)  # win/vscode/ps
AUTH_KEY="${SUPABASE_SERVICE_ROLE_KEY:-${SUPABASE_ANON_KEY:-}}"
curl -s -X POST https://smmkxxavexumewbfaqpy.supabase.co/functions/v1/tools-hub \
  -H "Authorization: Bearer $AUTH_KEY" \
  -H "apikey: $AUTH_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"action\":\"wbs.priority_for_instance\",\"instance\":\"$INST\",\"notify_slack\":true}" \
  | jq '.top_tasks, .user_tasks'
```

優先タスク TOP 5 を確認 → 本セッションの着手タスクを決定。
WBS 表示: https://my-web-app-b67f4.web.app/project-gantt
ユーザー手動タスクUI: https://my-web-app-b67f4.web.app/user-tasks

### Step 5: レポート生成

以下の形式でユーザーに報告:

```
## セッション開始チェック (YYYY-MM-DD HH:MM)

### Rule 14 ツールバージョン
- ✅ すべて最新 (または ⚠️ X件変更)

### cross-instance-prs
- pending: N件 ([title])
- stale (root+done重複): M件 → 削除推奨

### 並行インスタンス
- 直近アクティブ: VSCode#N, PS#N, Win#N
- 衝突リスク: {低|中|高}

### 次の推奨タスク
1. ...
2. ...
```

## 運用上の注意

- **Auto Mode 必須**: セッション冒頭で許可確認スキップのため settings.local.json 確認
- **現在のインスタンス確認**: ユーザーの最新発話 (例: "現在のインスタンスはWindowsアプリ版です") を基準にする
- **高衝突リスク時**: ROADMAP 書き込みは最後にまとめて rebase+push
- **stale PR は即削除**: 並行インスタンスが archive commit しても root 残すケースが頻発
- **Worktree 違反検出**: `pwd` が main repo を指していて PS版/Win版なら即 `cd` で移動

## Worktree 分離 (PS版・Win版)

| インスタンス | 作業 cwd | ブランチ | push コマンド |
|------------|---------|---------|-------------|
| VSCode版 | `C:/Users/kanta/GitHub/my_web_app` | main | `git push origin main` |
| PS版 | `C:/Users/kanta/GitHub/my_web_app_ps` | ps-main | `git push origin ps-main:main` |
| Win版 | `C:/Users/kanta/GitHub/my_web_app_win` | win-main | `git push origin win-main:main` |

**git stash 禁止**: uncommitted 変更は即 commit (WIP commit で可)。
stash の代わり: `git add -A && git commit -m "WIP" → git pull --rebase → git reset HEAD~1`
