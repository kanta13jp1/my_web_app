# Cross-Instance PR: Codex#1 inactive 30 日 ヘルスチェック

**作成**: Win版#132 part 102 / 2026-04-30
**FROM**: Win版 (instance_role_audit.py 検出)
**TO**: Codex#1 (= 横断調査 / 修正 PR / SQL レビュー補助 territory)
**優先度**: HIGH (= fleet capacity 8% 喪失 / 12 instance fleet が事実上 11 instance 化)
**期限**: 2026-05-07 (1 週間)
**親軸**: AI_FLEET_SYNERGY #1 (Strict Instance Routing)

---

## 1. 背景

Win版#132 part 99 で導入した `scripts/instance_role_audit.py` の monthly audit (= 過去 30 日 4526 commits 集計):

```
| codex1 | 0 commits | 0.0% share |
```

= **Codex#1 は過去 30 日完全に活動なし**. 12 instance fleet で 1 instance dormant = capacity 8% 喪失.

## 2. 想定原因 (= 5 hypothesis)

### Hypothesis A: Codex CLI install 状態異常

- `codex --version` が動かない
- `codex auth status` が expired
- worktree (`/c/Users/kanta/GitHub/my_web_app/.claude/worktrees/instance-codex1`) が破損

### Hypothesis B: branch 未 push

- ローカルで作業しているが `git push` していない (= visible commits なし)
- branch `codex/codex1-wip` が長期 stale

### Hypothesis C: 担当 task 不在

- CLAUDE.md routing matrix で「Codex#1 = 横断調査 / 修正 PR / レビュー補助」だが、実際の routing が Codex#2 / VSCode / PS#3 に流れている
- Codex#1 territory に該当する task が 30 日間発生していない

### Hypothesis D: 別名で活動

- commit author が `Codex#1` ではなく別名 (= `kanta13jp1` 等)
- audit script の identifier pattern (`codex/codex1-`) と branch 命名規則が乖離

### Hypothesis E: Codex CLI usage limit

- 月間 token limit 超過で disabled 状態
- restart で復活する可能性

## 3. 期待する Codex#1 audit

### Step 1: ヘルスチェック CLI 系

```bash
# Codex#1 worktree で実行
cd /c/Users/kanta/GitHub/my_web_app/.claude/worktrees/instance-codex1
codex --version
codex auth status
git status
git branch --show-current
git log -5 --oneline
```

各 output を本 cross-instance-pr のコメントに投稿.

### Step 2: 直近 30 日の作業 (= ローカル only でも) を確認

```bash
git log --all --since="30 days ago" --author=$(git config user.email) --oneline | head -20
```

= **ローカルで作業はあるが push 未済** が判明したら、Hypothesis B 確定.

### Step 3: branch 状態確認 + 必要なら push

```bash
git push origin codex/codex1-wip 2>&1 | head
# または
git fetch origin && git log origin/codex/codex1-wip..HEAD --oneline 2>&1 | head
```

### Step 4: routing 再確認

CLAUDE.md routing matrix (= AI_DEV ファイル / Win版 territory) で Codex#1 担当の task を確認:
- 「横断調査 / 修正 PR / レビュー補助」が現在 fleet に発生しているか
- もし発生していない → Codex#1 を **別 task に re-allocate** 候補
  - 例: `feature-review.yml` の Schedule task helper
  - 例: `claude-agent-review.yml` の audit support
  - 例: AI 大学 学部別 provider seed (= part 93 cross-instance-pr の overflow 受け皿)

## 4. 解決パス (= 想定 outcome)

### A: 単純復帰

`codex auth login` 等で復活 → 1 週間以内に commit が visible に.

### B: branch 命名規則更新

audit script の identifier pattern と Codex#1 actual branch が乖離 → audit script を更新 (= Win territory で対応).

### C: 役割再 assign

Codex#1 territory が空気化 → CLAUDE.md routing matrix で役割を更新 + 新 task 配分 (= cross-instance-pr で個別委譲).

### D: 12 → 11 fleet 公式化

Codex#1 を引退 → docs/MULTI_INSTANCE_FLEET.md 更新 (= 11 instance fleet として再定義).

## 5. 受入基準

- [ ] Step 1-4 を Codex#1 が実施 + 本 PR にコメント
- [ ] 想定原因 A-E のうちどれが該当するか identification
- [ ] 解決パス A-D のどれを採用するか CEO judgement
- [ ] 30 日以内に Codex#1 の commit が再度 main に visible に (= 復帰確認) もしくは公式引退
- [ ] cross-instance-pr 完了時 `done/` 移動

## 6. 既存 audit 結果

### `instance_role_audit.py` 詳細 (= 2026-04 monthly):

```
| codex1 | 0 commits | 0.0% share | 0/0 territory match |
```

vs 他 codex:

```
| codex2 |    5 commits | 0.1% share | 53.6% (15/28) territory match |
```

= Codex#2 は active (= GHA 補助で稼働) / Codex#1 だけが完全 inactive.

## 7. AI_FLEET_SYNERGY 原則 #1 dogfood

「Strict Instance Routing」が機能するためには **「全 instance が active」** が前提.
1 instance dormant = routing rule が破綻し始める signal. 早期対応で fleet 全体の health 維持.

---

*Win版#132 part 102 / 2026-04-30 起票 / Codex#1 inactive 30 日 / Win → Codex#1 lane / AI_FLEET_SYNERGY #1 dogfood*
