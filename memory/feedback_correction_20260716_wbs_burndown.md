---
name: remote env の落とし穴 (AskUserQuestion 失敗 / gawk / commit 署名 / JS ミラー fidelity)
description: このセッションで遭遇した remote 環境・ツールの訂正点
type: feedback
---

## 失敗・訂正

- **AskUserQuestion が remote で失敗**: `Tool permission stream closed` で権限ストリームが閉じた。→ text で選択肢 (①②③④) を提示する方式に切替。remote/async では blocking な質問より text 選択が確実。
- **gawk の 3-arg `match()` 非対応**: `match($0, /re/, arr)` が syntax error。→ Python で `re.split(r'\n### ', ...)` して block 単位で id を正確抽出。
- **grep `-A6` が block 境界を跨ぐ**: Issue→WBS id マッピングで隣接 block の id を誤取得。→ block split して「同一 block 内の id と issue URL」を対応付ける。
- **JS ミラーの fidelity バグ**: early-return object に derived field (`hasHeaderErrors`) を入れ忘れて 1 テスト fail。Dart 本体は正しい。→ ミラーは本体の全 getter を再現する。ミラー fail = 本体 bug とは限らないので切り分ける。
- **commit が Unverified**: remote に signing key が無く、committer email/name は正しいのに署名が無いため GitHub が Unverified 表示。`reset-author` では解消しない (環境制約)。push 済みの過去 commit の履歴書換えはしない。
- **deno.land / deno install が proxy 403**: remote proxy が deno インストーラを弾く。→ deno はローカル導入せず、Node ミラー + CI に委ねる。

**Why:** remote cloud 環境は local Windows fleet 前提の手順 (curl WBS 更新 / notebooklm CLI / dart) がそのままでは動かない。
**How to apply:** remote では WBS 更新は migration で、検証は Node、質問は text 選択、抽出は Python block split。commit 署名の Unverified は環境制約として受容。
