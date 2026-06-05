# Architecture Decision Records (ADR) — 運用ガイド

> Win版#132 part 241 (2026-06-05): WBS 設計タスク「アーキテクチャ判断ログ運用 (ADR)」着地。
> 目的 = 主要な設計判断を ADR 化し、NotebookLM / WBS に紐づけて **後続実装が迷わない状態** を作る。

ADR (Architecture Decision Record) は「いつ・なぜ・どの設計を選んだか」を 1 ファイル 1 判断で
不変記録する仕組み。原則 docs (= 12 軸 / 恒常的な指針) と違い、ADR は **特定時点の具体判断**
(= alternatives を比較して 1 つに decide した記録) を残す。

## いつ ADR を書くか

以下のいずれかに当てはまる判断は ADR 化する:

- アーキテクチャ / 技術スタック / データモデルの選択 (= 後から覆すコストが高い)
- 複数の妥当な選択肢があり、1 つを選んだ理由を残す価値がある
- セキュリティ境界 / 認証方式 / 権限モデルの決定
- 運用上の制約 (= EF 数上限 / instance 役割分担 等) を恒久ルール化するとき
- 過去の incident を受けた再発防止の構造変更

書かなくてよいもの: 自明な実装詳細 / 1 行修正 / 可逆な微調整 / 個別バグ fix。
(= 原則 [NO-SCOPE-CREEP] と同じ精神。迷ったら「3 ヶ月後の自分/他 instance が理由を知りたいか」で判断)

## ファイル命名

```
docs/adr/YYYY-MM-DD-kebab-case-title.md
```

- 日付プレフィックス = 時系列順に自然ソート (= fleet が高速に判断を積む本プロジェクトに適合)
- 既存 [`2026-04-30-edge-function-dependency-resolution.md`](2026-04-30-edge-function-dependency-resolution.md) がこの形式の先行例
- 1 判断 = 1 ファイル。後で覆す場合も既存 ADR は編集せず Status を `Superseded` にして新 ADR を追加 (= 不変記録)

## Status ライフサイクル

| Status | 意味 |
|--------|------|
| `Proposed` | 提案中。レビュー / 合意待ち |
| `Accepted` | 採用。実装の前提として有効 |
| `Deprecated` | 非推奨化。新規には使わないが履歴として残す |
| `Superseded by <ファイル名>` | 別 ADR に置き換え。本文は不変のまま残す |

Status を変えるときは本文を書き換えず、`Status:` 行と必要なら冒頭 1 行の注記のみ更新する。

## 構造 (= テンプレート)

新規 ADR は [`TEMPLATE.md`](TEMPLATE.md) をコピーして書く。最小セクション:

1. **タイトル** (`# ADR: <判断の要約>`)
2. **Date / Status**
3. **Context** — なぜこの判断が必要だったか (制約 / 問題)
4. **Decision** — 何を決めたか (具体的に / コード片や数値があれば含める)
5. **Consequences** — 結果として何が起きるか (得たもの・トレードオフ・後続への影響)
6. **Links** (任意) — 関連 WBS task id / GitHub Issue / 原則 docs / 先行 ADR

## WBS / Issue / NotebookLM への紐づけ

後続実装が迷わないために、ADR は単体で終わらせず接続する:

- **WBS**: ADR が実装タスクを生むときは `Links` に WBS task id を記載。逆に WBS の設計タスク完了時は
  成果として該当 ADR を参照する (= 本 README は WBS task `2e41ebca-36bd-4c47-a87f-90b7b5948ece` の成果物)。
- **GitHub Issue**: incident / feature 起点の判断は Issue 番号を `Links` に残す ([ISSUE-PRECHECK] と整合)。
- **NotebookLM (Karpathy 外部脳)**: `docs/adr/` は Compile サイクル (`scripts/wiki_compile.py`) と
  NotebookLM ingest の対象。過去判断は `notebooklm` CLI / `/wiki-query` でゼロトークン検索できる
  (= 詳細 [`../NOTEBOOKLM_GUIDE.md`](../NOTEBOOKLM_GUIDE.md))。設計判断前に既存 ADR を query するのが推奨儀式。

## 原則 docs との関係

- **原則 docs** (= [`../PHILOSOPHY.md`](../PHILOSOPHY.md) ほか 12 軸) = 恒常的な「どう判断すべきか」の指針。
- **ADR** = その指針を特定状況に適用した「実際にこう判断した」記録。

ADR は原則 docs を置き換えない。原則に沿って下した個別判断のログ。原則自体を変える提案は原則 docs の PR で行う。

## ADR 一覧 (Index)

| Date | ADR | Status |
|------|-----|--------|
| 2026-04-30 | [Supabase Edge Function Dependency Resolution](2026-04-30-edge-function-dependency-resolution.md) | Accepted |
| 2026-06-05 | [Flutter Web + Supabase + Firebase Hosting スタック選定](2026-06-05-flutter-web-supabase-firebase-stack.md) | Accepted |
| 2026-06-05 | [Edge-Function-first アーキテクチャ (EF-FIRST / EF-CAP-50)](2026-06-05-edge-function-first-architecture.md) | Accepted |
| 2026-06-05 | [2-instance fleet: Architect + Implementer 役割分担](2026-06-05-two-instance-fleet-architect-implementer.md) | Accepted |

> 新しい ADR を追加したら、この表に 1 行追記する (= Index を単一の入口に保つ)。
