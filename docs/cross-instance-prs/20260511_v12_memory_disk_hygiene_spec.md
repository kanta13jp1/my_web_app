# v12 Memory & Disk Hygiene Spec — User iterative ask v12 (= 累積 11 layer)

> **Date**: 2026-05-11 JST (= part 198 / Win Claude / [COMPACTION-RESUME] 第 3 例)
> **Scope**: 「毎回のセッションで必ずメモリ/ハードディスク容量を圧縮する施策」第 12 layer
> **Owner**: Win Claude (= spec) → Win Codex (= impl) → Win Claude (= verify)
> **DISK_HYGIENE_RUNBOOK target section**: §17.17 v12 (= cascade post-merge 着地 / part 199 想定)

## v3-v11 累積 baseline

| layer | spec ship | content | status |
|-------|-----------|---------|--------|
| v3 | part 194 §17.14 | SessionStart 7 hook auto-fire | ✅ shipped + verified |
| v4 | part 188 §16 | mid-session PostToolUse hook | ⚠️ unwired / Codex 5/23-5/28 |
| v5 | part 190 §17 | hook wiring 5 task (Tier A-E) | ⚠️ in-flight / Codex 5/23-5/28 |
| v6 | part 191 §17.11 | immediate manual fire recipe | ✅ shipped |
| v7 | part 192-b §17.12 | immediate fire delta dogfood | ✅ shipped |
| v8 | part 193 §17.13 | dev_cache 4 cmd Win compat | ⚠️ Issue #2186 / Codex 5/23 |
| v9 | part 194 §17.14 | SessionStart auto-fire wiring | ✅ shipped + verified part 195 |
| v10 | part 196 phase 2 §17.15 | mid-session build-up rate KPI | ⚠️ PR #2323 unmerged |
| v11 | part 197 §17.16 | 85% threshold lower + post-resume mandatory | ⚠️ PR #2328 unmerged |

## v12 layer — 3 finding consolidation

### Finding A: MEMORY.md monthly consolidation 第 3 例 dogfood ✅ (part 198)

```
27.35 KB → 9.90 KB / -63% trim
backup: MEMORY.md.bak.20260510-part198 (27349 B)
moved: part 182-193 entries (= 30 lines / 17454 B) → MEMORY_202605_archive.md
```

**Pattern 累積**:
| 第 N 例 | session | trim | reduction |
|---------|---------|------|-----------|
| 1 | part 162 (2026-05-07) | 87.4 → 11.4 KB | -87% |
| 2 | part 194 (2026-05-09) | 36 → 19 KB | -47% |
| 3 | **part 198 (2026-05-11)** | **27.35 → 9.90 KB** | **-63%** |

→ burst rate = 月内 3 例 / 5/7-5/11 = 4 day interval / consolidation 必要性 increasing.

### Finding B: per-session MEMORY.md size hook spec (= future automation)

**Gap 5 解消候補** (= §17.14.3 「MEMORY.md auto-consolidation」 / 残 future):

```powershell
# SessionStart hook: ~/.claude/scripts/memory_size_check.ps1
$mempath = "$env:USERPROFILE\.claude\projects\C--Users-kanta-GitHub-my-web-app\memory\MEMORY.md"
if (Test-Path $mempath) {
    $size = (Get-Item $mempath).Length
    if ($size -gt 24400) {
        Write-Host "[MEMORY-SIZE] WARNING: $([math]::Round($size/1024, 2)) KB > 24.4 KB threshold"
        Write-Host "[MEMORY-SIZE] consolidation candidate: run /wrap-up consolidation step or manual trim"
    } else {
        Write-Host "[MEMORY-SIZE] OK: $([math]::Round($size/1024, 2)) KB"
    }
}
```

**配線**:
```json
"SessionStart": [{ "type": "command", "command": "powershell -ExecutionPolicy Bypass -File C:\\Users\\kanta\\.claude\\scripts\\memory_size_check.ps1", "timeout": 10 }]
```

→ **Win Codex impl 候補 / 期限 5/30** (= Tier A 完了後).

### Finding C: docs-only label auto-tag GHA workflow spec (= bonus)

**契機**: part 198 PR #2328 + #2323 minimal-e2e gate FAIL recovery で `docs-only` label 手動付与. Auto-tag GHA で次回以降 manual step skip.

```yaml
# .github/workflows/auto-label-docs-only.yml (新規)
name: Auto-label docs-only PRs
on:
  pull_request:
    types: [opened, synchronize]
jobs:
  detect-and-label:
    runs-on: ubuntu-latest
    steps:
      - name: Detect docs-only changes
        id: detect
        run: |
          gh pr diff ${{ github.event.pull_request.number }} --name-only > changed.txt
          if grep -qE "^(lib/|supabase/functions/|web/|android/|ios/|windows/|macos/|linux/)" changed.txt; then
            echo "is_docs_only=false" >> $GITHUB_OUTPUT
          else
            echo "is_docs_only=true" >> $GITHUB_OUTPUT
          fi
        env:
          GH_TOKEN: ${{ github.token }}
      - name: Add docs-only label
        if: steps.detect.outputs.is_docs_only == 'true'
        run: gh pr edit ${{ github.event.pull_request.number }} --add-label docs-only
        env:
          GH_TOKEN: ${{ github.token }}
```

→ **Win Codex impl 候補 / 期限 5/30** (= 5 task hook wiring sprint 完了後).

## Recommended ship plan

### Phase 1 (= part 199 想定 / cascade post-merge / Win Claude)

1. PR #2323 + #2328 merge verify (= cascade 完了 / mergeStateStatus=CLEAN 待ち)
2. ROADMAP part 196/197/198 batch backfill (= placeholder 解消)
3. DISK_HYGIENE_RUNBOOK §17.17 v12 章追加 (= 既存 doc 章追加 pattern 第 12 例 / Finding A-C summary inline)

### Phase 2 (= Win Codex sprint 5/30 / Tier F+G)

4. Finding B impl: `memory_size_check.ps1` ship + SessionStart wiring
5. Finding C impl: `auto-label-docs-only.yml` ship + first PR test

### Phase 3 (= Win Claude verify / part 200+)

6. Finding B verify: 部分 199 起動時 [MEMORY-SIZE] warning / OK 表示
7. Finding C verify: 次回 docs-only PR で manual `--add-label docs-only` 不要化

## DoD

- [x] **part 198 dogfood**: MEMORY.md consolidation 第 3 例 -63% trim shipped (= Finding A)
- [ ] §17.17 v12 章追加 PR (= part 199 / cascade post-merge)
- [ ] Finding B impl PR (= Win Codex / 5/30)
- [ ] Finding C impl PR (= Win Codex / 5/30)
- [ ] 部分 200 verify: SessionStart [MEMORY-SIZE] warning 動作確認

## Philosophy Alignment

- 該当原則: #4 (mentor=verify) #5 (商品=価値=automation 100%) #6 (時間=資本=hook 自走) #7 (資産負債=manual fire 削減) #8 (KPI=size threshold) #9 (IPO=audit-ready hygiene)
- 整合性スコア: **6/9 ✅** (= [PHILOSOPHY-22] gate 通過)

## next session 第 1 候補

→ **Phase 1 (= cascade post-merge + ROADMAP batch backfill + §17.17 v12 ship)**

## dogfood pattern (= part 198 v12 累積 6 件)

- 「**v12 spec ship via cross-instance-pr doc**」第 1 例 (= cascade 待ち pattern 補完 / DISK_HYGIENE inline conflict 回避)
- 「**MEMORY.md consolidation 第 3 例**」(= -63% trim / burst rate 月内 3 例)
- 「**5-step monthly consolidation pattern**」第 3 適用 (= backup → archive append → trim → note update → verify)
- 「**user iterative ask v12 累積 11 layer**」第 1 例
- 「**docs-only PR auto-label spec**」第 1 例 (= part 198 manual recovery → automation candidate)
- 「**SessionStart MEMORY.md size hook spec**」第 1 例 (= gap 5 解消候補)
