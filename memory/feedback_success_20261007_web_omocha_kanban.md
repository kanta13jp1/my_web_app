---
name: grill-me 先行 + 純粋ロジック分離で「見て楽しい」機能を 3 PR 連続 merge
description: OMOCHA WORKS / AI エージェント カンバン盤を Web (cloud) セッションで設計→実装→merge した際に効いた進め方。grill-me による 1 問 1 答の意思決定固め、変換ロジックの純粋関数化、既存実データ (wbs_tasks.instance) の再利用。
type: feedback
---

## 1. `/grill-me` (1 問 1 答) を実装前に通すと設計が固まる

実装に入る前に `.claude/skills/grill-me/SKILL.md` の流儀で**質問を 1 件ずつ・推奨回答付き**で出し、
ユーザーの GO が出るまでコードを書かない。今セッションでは以下が事前に確定し、実装中の手戻りが 0 だった:

- データソース: 実データは**ログイン済みオーナー限定**、未ログイン公開訪問者には現行シミュレーション
- 列の写像: GitHub Actions の `queued` を「レビュー」列に読み替える / WBS は実 status をそのまま 4 列
- 鮮度: 完了列は**直近 24 時間ぶんのみ**、未着手は 20 件上限 + 超過数を別表示
- 更新: Supabase Realtime 購読 + 60 秒フォールバック再取得の二重化
- テスト方針: 純粋ロジックは単体テストで固め、Realtime/認証を含む画面全体 E2E は**例外宣言**

**Why:** 「盤面に何を出すか」はユーザーの体験判断であって実装判断ではない。先に潰すと CI 往復が消える。
**How to apply:** UX の見え方が主役の機能は、必ず `/grill-me` で列・件数・鮮度・更新方式・テスト範囲の 5 点を先に確定させる。

## 2. 変換ロジックを純粋関数ファイルに切り出す

- `supabase/functions/autonomous-ops/transform.ts` — GitHub runs → 盤面 payload (Deno test で固定 now を渡す)
- `lib/models/agent_board_models.dart` — `laneFromStatus` / `normalizeAgentId` / `buildBoardSnapshot(rows, now)` / `formatElapsed(t, now)`

`now` を**引数で受ける**設計にしたので、`DateTime.now()` 依存のフレーキーさが最初から存在しなかった。
画面側は「取得 + 描画」だけになり、重い E2E を付けずに挙動を全部テストで固められた。

**Why:** このコンテナには Flutter/Dart SDK が無く、検証は CI 経由のみ。純粋関数に寄せるほど CI 1 周で確信が得られる。
**How to apply:** 時刻・集計・分類は必ず `(rows, now)` を取る純粋関数へ。ページ内に埋めない。

## 3. 「実データが既にある」ことを疑う — `wbs_tasks.instance`

「AI エージェントがタスクをこなす様子」を作るのに、シミュレーションを書く必要はなかった。
`wbs_tasks` に `instance` / `owner_instance` (claude / codex / gemini / copilot / gha / schedule / ps1-6 / user) が
**すでに実データとして入っていた** (~3,695 行)。これを読むだけで盤面が本物になった。

**Why:** 自分株式会社は「fleet が WBS を回す」運用そのものが実データ源。新規に作らなくても既に記録されている。
**How to apply:** ダッシュボード系の依頼が来たら、まず `wbs_tasks` / `hub_data` / `development_achievements` に
既存列が無いか探す。無い前提でシミュレーションを書き始めない。

## 4. 未知の値は正規化せずそのまま通す (新エージェント追従)

`normalizeAgentId` は別名 (codex1→codex, co-pilot→copilot, ps3→ps) だけ畳み、
**未知の値はそのまま ID として返す**。おかげで `antigravity` のような新エージェントが
DB に現れた時点でコード変更なしに盤面へ出る。

**Why:** fleet 構成は頻繁に変わる。許可リスト方式だと毎回コード修正が要る。
**How to apply:** 表示系の分類は「別名を畳む」だけにして、未知を落とさない。表示名だけ辞書で補う。
