---
description: セッション終了前に学習を抽出し、永続メモリ (memory/) に保存する。未完了タスクがない場合は次回タスク候補を必ず提案する。次回セッションの Master Brain として機能する。NotebookLM にセッション要約を蓄積して長期的な学習を実現。
---

# /wrap-up — Master Brain セッション終了処理

このセッションを振り返り、永続メモリとして保存する。**未完了タスクが 0 件の場合は、必ず次回実施タスク候補を提案すること。**

---

## Step 1: セッション分析

会話履歴全体を振り返り、4カテゴリに分類する:

### A. 成功パターン

- うまくいったアプローチ・コマンド・設計判断
- ユーザーが「yes」「完璧」「これ」と反応したもの
- 予想より少ないステップで解決できたもの

### B. 失敗・訂正

- ユーザーに「違う」「やめて」「元に戻して」と言われたこと
- ツール呼び出しが拒否されたこと
- 間違えたファイルパス・関数名・数値

### C. 新規発見

- このセッションで初めて知ったプロジェクト固有の仕様
- 想定と異なっていた実装の詳細
- 今後注意すべき制約・依存関係

### D. ルール候補

- CLAUDE.md / COMPRESSED_PROMPT_V3.md に追記すべき新ルール・数値更新
- インスタンス分担の変更点

---

## Step 2: memory/ にローカル保存

**保存先**: `C:\Users\kanta\.claude\projects\C--Users-kanta-GitHub-my-web-app\memory\`

今日の日付 (YYYYMMDD) を使ってファイルを作成する。
内容があるカテゴリのみファイル化する（空なら作らない）:

- 成功パターンがある場合: `feedback_success_YYYYMMDD.md`
- 失敗・訂正がある場合: `feedback_correction_YYYYMMDD.md`
- 新規発見がある場合: `project_YYYYMMDD.md`

各ファイルのフォーマット:

```markdown
---
name: [簡潔なタイトル]
description: [1行の説明 — 未来の自分が参照判断できる粒度で]
type: [feedback または project]
---

[内容]

**Why:** [なぜこれが重要か]
**How to apply:** [次回どう適用するか]
```

MEMORY.md インデックスにも1行追加する。

---

## Step 3: NotebookLM Master Brain に蓄積 (認証済みの場合)

`notebooklm status` で認証状態を確認してから実行:

```bash
notebooklm status
```

認証済みの場合、Step 2 で保存したメモリファイルを Master Brain ノートブックにソースとして追加する:

```bash
# Master Brain ノートブックに切り替え
# 注意: use は notebook **ID prefix のみ** マッチ (title 不可 / CLI v0.3.4 実測)。
# ea6cff25... = jibun-master-brain (kanta13jp@gmail.com 側 / NOTEBOOKLM_HOME は
# .claude/settings.json env で gmail home に自動適用済み)
notebooklm use ea6cff25
notebooklm status   # Title = jibun-master-brain を verify してから add (誤着地防止)

# 今セッションで作成したメモリファイルをすべてソース追加
# (該当ファイルのみ実行。存在しないファイルはスキップ)
notebooklm source add "C:/Users/kanta/.claude/projects/C--Users-kanta-GitHub-my-web-app/memory/feedback_success_YYYYMMDD.md"
notebooklm source add "C:/Users/kanta/.claude/projects/C--Users-kanta-GitHub-my-web-app/memory/feedback_correction_YYYYMMDD.md"
notebooklm source add "C:/Users/kanta/.claude/projects/C--Users-kanta-GitHub-my-web-app/memory/project_YYYYMMDD.md"
```

これにより:
- 複数セッションにまたがる学習がファイル単位で蓄積される
- 次回 `/deep-research` で `notebooklm use ea6cff25 && notebooklm ask "..."` で過去の知見を横断検索できる
- NotebookLM の Gemini が全セッション履歴から関連情報を自動抽出する

**認証未完了・cookie 期限切れの場合はスキップ**し、`notebooklm login` で再認証を促す（ローカルの memory/ 保存は必ず実行）。

---

## Step 4: 未完了タスクの記録 / 次回タスク候補提案

### ケース A: 未完了タスクがある場合

このセッションで着手したが完了しなかったタスクを MEMORY.md の末尾に追記:

```markdown
<!-- wrap-up YYYYMMDD
未完了:
- [タスク名]: [状態と次のステップ]

次回優先:
- [最優先タスク]
-->
```

### ケース B: 未完了タスクが **0 件** の場合（**必須**）

未完了タスクがない場合は Step 6 の「次回タスク候補の提案」を必ず実行し、
MEMORY.md にも候補リストを記録すること。

---

## Step 5: GROWTH_STRATEGY_ROADMAP.md 更新

`docs/GROWTH_STRATEGY_ROADMAP.md` の末尾にセッション記録を追記し、git commit する。

---

## Step 5.5: WBS-SYNC 必須更新 (Win版#131 part 12 / Option B · PS#1 S22 blocking 化)

**全インスタンス必須・blocking**: 本セッションで進めた WBS タスクを `tools-hub:wbs.update_progress` で更新する。

### (1) タスク更新 curl

```bash
INSTANCE=<vscode|win|ps1|ps2|ps3|ps4|ps5|ps6|web|mobile>

# 完了 / 進行中 / 遅延 (recovery_plan 必須) / リスケ (end_date 更新)
curl -s -X POST 'https://smmkxxavexumewbfaqpy.supabase.co/functions/v1/tools-hub' \
  -H 'Authorization: Bearer <ANON_KEY>' -H 'Content-Type: application/json' \
  -d '{"action":"wbs.update_progress","id":"<task_id>","progress":100,"status":"completed"}'
```

### (2) 自インスタンスの更新有無を自己検証 (blocking)

`wrap-up` skill は以下 check を実行し、**直近 1h で自インスタンス該当タスクの更新が 0 件なら exit 1** する:

```bash
INSTANCE=<自インスタンス名>
SINCE=$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ)
UPDATED_COUNT=$(curl -s -X POST 'https://smmkxxavexumewbfaqpy.supabase.co/functions/v1/tools-hub' \
  -H "Authorization: Bearer ${SUPABASE_ANON_KEY_PROD:?missing}" \
  -H 'Content-Type: application/json' \
  -d "{\"action\":\"wbs.list_tasks\",\"instance\":\"$INSTANCE\",\"updated_since\":\"$SINCE\"}" \
  | python3 -c "import sys,json; print(len(json.load(sys.stdin).get('tasks',[])))")

if [ "$UPDATED_COUNT" = "0" ]; then
  echo "❌ [WBS-SYNC] blocking — 本セッションで wbs.update_progress 未実行 (instance=$INSTANCE)"
  echo "   wrap-up 続行前に以下いずれかを実施:"
  echo "   (a) 進行中タスクに progress 数値更新 (wbs.update_progress)"
  echo "   (b) 新規タスクを wbs.add_task で追加"
  echo "   (c) skip-wbs-sync=true を明示 (純粋 docs 修正のみ等の合理的理由)"
  exit 1
fi
echo "✅ [WBS-SYNC] passed — instance=$INSTANCE 更新 $UPDATED_COUNT 件 / 過去 1h"
```

### (3) skip-wbs-sync 明示オプション

純粋 docs 修正 (1 行誤字訂正等) で触る WBS タスクがない場合は `wrap-up --skip-wbs-sync` で bypass。
**合理的理由を memory に記録**:

```bash
# memory/project_YYYYMMDD_<instance>_s<N>.md に以下を追記:
# "WBS-SYNC skip 理由: <docs typo fix / README 修正等>"
```

### 違反時 (3 層 defense-in-depth)

- **Layer 1 (Option B · 本 step)**: skill 内で即 blocking (exit 1 で wrap-up 中断)
- **Layer 2 (Option A · SessionStart)**: 次回 session 開始時 TOP 5 自動注入で未更新タスクを見せる
- **Layer 3 (Option C · 24h cron)**: `wbs-staleness-audit.yml` が `docs/cross-instance-prs/<YYYYMMDD>_wbs_<instance>_overdue.md` 自動作成 → PS#1 Rule17 で拾う

### PREREQ

- PS#6 S22 (commit 232b2783) の wbs.* dispatch bug fix が deploy 済であること
- `SUPABASE_ANON_KEY_PROD` 環境変数が設定済 (inject-rules hook + auto-capture で既定)
- EF `wbs.list_tasks` が `updated_since` filter 対応 (PS#1 S22 commit で拡張済)

---

## Step 6: 次回セッション タスク候補の提案（必須）

**未完了タスクの有無に関わらず**、必ず次回実施タスク候補を提案する。

以下の優先順で候補を選定し、3〜5件を箇条書きで提示する:

1. **未完了タスク** — このセッションで完了しなかったもの
2. **COMPRESSED_PROMPT_V3.md「実装待ち」セクション** — 優先度🔴→🟡→🟢の順
3. **GROWTH_STRATEGY_ROADMAP.md「次回優先」セクション** — 最新セッション記録末尾
4. **競合脅威対応タスク** — 未完了の競合対抗機能
5. **タスク T-1「技術記事投稿」** — ユーザー獲得に最も直結する施策

提案フォーマット:

```
## 🚀 次回セッション タスク候補

| 優先度 | タスク | 推定規模 | 担当インスタンス |
|--------|--------|----------|-----------------|
| 🔴 最高 | [タスク名] | [S/M/L] | [VSCode/Web/Windows/PowerShell/daily-dev] |
| 🟡 高  | [タスク名] | [S/M/L] | [インスタンス] |
| 🟢 中  | [タスク名] | [S/M/L] | [インスタンス] |

**推奨: [最優先タスク名]**
理由: [なぜこれが次のアクションとして最適か 1〜2文]
```

---

## Step 6.5: Philosophy Alignment 記録 (Rule 22・必須)

本セッションで実施した作業について、`docs/PHILOSOPHY.md` の **9 原則** との整合性を記録する。

### 記録方法

`docs/daily-reports/YYYY-MM-DD.md` または該当 ROADMAP entry の末尾に以下を追記:

```markdown
### Philosophy Alignment ([インスタンス]#NN)

本セッション作業の理念整合性:

- 主要な実装/改修: [機能名・変更内容]
- 該当する原則: [原則 X, Y, Z]
- 整合性スコア: [9 項目中 N+ ✅]
- 理念的貢献: [どの原則を体現したか・どの懸念を持つか]
- 懸念事項 (該当時): [理念ずれの可能性 + 次回再評価]
```

### 例

```markdown
### Philosophy Alignment (Win#97)

- 主要実装: 基本理念ページ + LP動線追加 (動画5本+9原則+transcript)
- 該当原則: 1 (CEO感) + 2 (ミッション駆動) + 5 (商品=ユーザー価値)
- 整合性スコア: 9/9 ✅ (理念そのものを可視化する meta-機能)
- 理念的貢献: ユーザーが「自分が CEO」を最初に知る入口を作成
- 懸念: なし
```

### 9 原則 (チェック用)

1. CEO 感 (最終決定権) / 2. ミッション駆動 / 3. 優しい mentor / 4. 6 部署バランス (人事最優先) /
5. 商品=ユーザー価値 / 6. 資本=時間 / 7. 資産負債バランスシート /
8. KPI=昨日の自分 / 9. ゴール=IPO/ウェルビーイング

**判定基準**:
- 7+ ✅ → 即実装可・理念貢献度高
- 4-6 ✅ → 設計再考の余地あり
- 3 以下 ✅ → 理念ずれ警告 → 次回大幅再設計または機能撤回検討

---

## Step 7: 完了報告

以下の形式で報告する:

```
✅ wrap-up 完了
- 成功パターン: X件 → feedback_success_YYYYMMDD.md
- 訂正: X件 → feedback_correction_YYYYMMDD.md
- 新規発見: X件 → project_YYYYMMDD.md
- NotebookLM Master Brain: [蓄積済み / スキップ(未認証)]
- 未完了タスク: X件
- 次回優先: [タスク名]
- Philosophy Alignment: [N/9 ✅] / 主要原則: [X, Y, Z]
```
