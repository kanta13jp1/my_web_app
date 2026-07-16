---
name: WBS 誠実バーンダウンの手順と検証不能環境での honest verification
description: 偽完了せず WBS を減らす順序 + Dart/Deno 不在環境での JS ミラー検証パターン
type: feedback
---

## 成功パターン

### 1. WBS 誠実バーンダウンの順序 (最速・最も正当)
1. **stale row 修復**: GitHub で既に closed の Issue に紐づく WBS 行を completed 化 (承認不要・runbook drift 修復)。資産クラスタで 5 件即完了。
2. **実装済み verify close**: 受け入れ条件を実コード (`file:line`) で verify してから close。資産 #3343/#3384 等。
3. **近重複の集約**: canonical parent を close、残差分だけを 1 本の consolidated Issue (#4059) に畳む。5 重複 → 1 追跡。
4. **検証可能 core の実装**: 実機不要な純ロジックを実装 → progress 更新 (完了主張せず)、UI/QA は Codex へ handoff。
5. **供給 throttle**: 自動生成 Issue (NotebookLM) は relevance gate + cap で蛇口を止めないと再氾濫。

### 2. 検証不能言語の honest verification (dart/deno 不在の remote env)
- 純ロジックを Flutter/Supabase 非依存に切り出す → **faithful に JS へミラーして Node で実行** → 全ケース通過を確認。
- 正本テスト (`flutter test` / `deno test`) は CI (`ci.yml`) を gate に。migration/報告で「ローカルは JS ミラー、正本は CI」と honest scope 明記。
- TS モジュールは `node --experimental-strip-types` で実モジュールを直接実行できる (#1287 で 13 グループ実行)。
- 構文健全性は `node --check --experimental-strip-types <file.ts>` で確認可 (URL import があっても parse は通る)。

### 3. 大規模コード監査の parallel Explore agents
- 29k 行の巨大ページ + 複数 service をテーマ別に 3 agent へ分担 → 各 agent が `file:line` エビデンス + verdict を返却 → 親が集約。individual read より圧倒的に速く context 節約。

**Why:** ユーザー自身が偽完了防止 guard を組んでおり、誠実さが最優先。実機検証できない remote でも「本当に動く/実装済み」を担保する手段が要る。
**How to apply:** 次回も WBS 削減は上記 5 段で。Dart/Deno コアは JS ミラー + Node + CI gate で検証し、完了と進捗を honest に区別する。
