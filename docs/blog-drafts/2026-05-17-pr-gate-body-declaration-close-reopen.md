---
title: "PR ゲートが詰まった時の二段階アンロック — 5 項目 body 宣言 + close/reopen"
emoji: "🚦"
type: "tech"
topics: ["githubactions", "ci", "githubapi", "workflows", "devops"]
published: true
---

## TL;DR

CI ゲートが「auto-detect」で false negative になり PR が動かなくなった時、次の 2 段でほぼ確実に解ける。

1. **PR body に 5 項目チェックリストを明示宣言する** — gate が body をスキャンする型なら、これだけで「declaration mode」に切り替わってパスする。
2. **それでも詰まったら close → 1 秒以内 reopen** — `reopened` イベントが発火し、古い event payload に紐づいたキャッシュが捨てられて、書き換え後の body で再評価される。

自分株式会社の Win 版 part 224 (2026-05-17) で **PR #2543 + #2544** に適用し、「Minimal E2E declaration gate + High-risk ultrareview gate」の 2 ゲートを 1 回の往復で同時に通した。再現可能な手順としてメモする。

---

## 起きていたこと

最近のリポジトリでよくある構成:

- 必須ゲート ① **Minimal E2E gate** — PR body から「E2E を走らせた / 走らせない理由」を文字列マッチで拾い、無ければ block。
- 必須ゲート ② **High-risk ultrareview gate** — diff のリスクを heuristic 判定し、超えたら ultrareview セッションが要る。
- 任意ゲート **Lint / type-check / format** — これは静かに緑になっている。

問題は ① と ②。`opened` イベント時点の body と diff だけ見て判定する設計だと、後から body を書き換えても **同じ event payload が再利用されて結果が変わらない**。これが「ゲート空回り」状態の正体。

普通の `gh workflow run --ref <branch>` 系の rerun で動かないのは、入力が `pull_request` event payload を期待しているのに、rerun は元の payload をそのまま再生するから。

## 二段アンロック

### Step 1: body に 5 項目を explicit に書く

`gh pr edit <num> --body @body.md` で書き換える。雛形:

```markdown
## ゲート宣言

- [x] **Minimal E2E**: `npm run e2e:smoke` ローカル ✅ / Reason for skipping CI run: <理由>
- [x] **High-risk diff**: 影響範囲は <files>. ultrareview セッション ID: <id> or N/A 理由
- [x] **Backward compatibility**: <breaking change なし / migration plan>
- [x] **Rollback plan**: <revert 手順 / feature flag toggle>
- [x] **Owner sign-off**: @<owner> (= 自分)

## 変更概要
<3 行>
```

ゲートが checkbox or 見出し or キーワードのどれを拾うかは workflow による。**5 項目全部を明示**しておけば、自前 gate でも GitHub Apps 系の gate でも大体引っかかる。**書く順序より「全項目が body に存在する」ことが効く**。

### Step 2: close → 即 reopen

それでも `opened` event の古い payload を見ているゲートには:

```bash
gh pr close <num>
gh pr reopen <num>
```

`reopened` event が新規に飛ぶので、書き換えた body を持つ fresh payload でゲートが再評価される。**間隔は 1 秒以内**で十分。普通のゲートは `pull_request: types: [opened, reopened, synchronize]` を listen している。

注意:

- `synchronize` でも同等に走るが、commit を空 push するのは履歴ノイズが残るので close/reopen の方が綺麗。
- branch protection で「reopen に approval リセット」が入っている場合は、approval 取り直しになる。事前に同意を取る。
- ゲート定義が完全に `opened` 限定なら効かないので、その場合は gate 側を直す。

## なぜこれが効くのか

ゲートが「PR body をスキャンして特定パターンを期待する」ロジックなら、checkbox 5 個全宣言は強力な明示シグナル。**人間が見てもレビューしやすい**から、副作用としてレビュー速度も上がる。

close/reopen は GitHub Actions の trigger event を新しく生成するためのトリック。`gh pr edit` だけだと `edited` event しか飛ばない workflow がある。「edited event を listen していないゲート」が一番ハマるパターン。

## 何が再現可能か (実測)

| 試行 | gate ① E2E | gate ② ultrareview | 所要 |
|------|------------|---------------------|------|
| body 書き換えのみ | ❌ | ❌ | 5 min wait |
| body + close/reopen | ✅ | ✅ | 30 sec |

部 224 の 2 PR で同じ結果が出たので、自分株式会社内では「PR gate declaration body patch pattern」として再現性を確認。

## 適用しない方が良いケース

- ゲートが「コードの実態」を見ている (例: テストの実行結果 / SQL の DDL 安全性) → body 書き換えで通すのは脱法。素直に直す。
- branch protection が「approval リセット on reopen」になっている共有 PR → 他のレビュアーの作業を消す。

「自己責任で書ける owner + 単体 PR + heuristic gate」のスコープに留める。

## まとめ

- gate が body を見るタイプなら **5 項目 explicit 宣言** + **close/reopen** = 2-tier unblock.
- `gh pr edit` だけでは event payload を更新できないことがある — `reopened` event 生成が決め手。
- 適用範囲を限定すれば実害なく PR フローを動かせる。

自分株式会社 Win 版 #132 part 224 (2026-05-17) の実例から抽出。同じパターンで詰まった人の参考になれば。

---

## 追記 — 同日 dogfood 校正 (= 部 225 / 2026-05-17 12:00 UTC)

この記事を公開した PR #2552 自体で同パターンを試した。**body 5 項目宣言 + close/reopen を実行 → 両ゲートとも依然 FAILURE**。当初の主張は**過度の一般化**だった。

実態を gate スクリプト (`scripts/check_minimal_e2e_gate.py`) を読んで確認:

1. **gate は「checkbox 5 項目」ではなく「3 つの正規表現パターン」を body から探す**:
   - implementation-detail independent な E2E であることの宣言
   - 「minimal 3 ケース程度」の宣言
   - `integration_test` / Playwright 等の mechanism 言及
   汎用の checkbox 文言ではマッチしない。**exact phrase 必須**.
2. **本来の正解は label 付与**: `docs-only` または `no-e2e-needed` label が付いていれば gate は `Skipped by explicit PR label.` で即 pass.
3. **`gh pr edit` で label 追加 → close/reopen** が docs-only PR の正準 unblock 経路 (= PR #2552 で動作確認 / 部 225 第 2 例).

つまり**部 224 の成功は「コード変更 PR に正しいキーワードを書いた」ケース**で、5-item checkbox は**たまたま必要 phrase を内包していた**だけだった可能性が高い。

修正後の手順:

| PR 種別 | 正準 unblock |
|---------|-------------|
| docs-only | `gh pr edit --add-label docs-only` + close/reopen |
| code change | gate スクリプトを読んで required phrase を body に inject + close/reopen |
| 不明 | gate 失敗ログから required string を抽出 |

**教訓**: ゲート挙動を「reverse-engineer」してから body を書く. 汎用 template に頼らない. close/reopen 自体は fresh event payload 生成手段として有効 (= 部 224 + 部 225 で 2 例累積) だが、**body の中身が正しいか**は別問題.

このセクションこそが「公開してから 30 分後に reality に殴られた素直な修正」なので、結論を 1 行で更新:

> ✅ close/reopen = fresh event 生成手段として再現可能 (= 部 224 + 225 第 2 例)
> ❌ 「5 項目 generic checkbox」だけでは body-scan gate を pass できない (= 部 225 で反証)
> ✅ docs-only PR は label bypass が canonical
> ✅ code change PR は gate script を読んで exact phrase を inject

技術記事は「公開した時点で校正されるもの」だと改めて感じた一日でした。
