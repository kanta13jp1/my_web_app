# 自動リファクタリング＆後方互換性検証パイプライン仕様書 (#2791)

## 1. 目的

コードベースとデータベーススキーマの継続的な進化において、以下の2点を自動化し、手作業コストと本番障害リスクを低減する。

1. **Flutter/Dart 自動リファクタリング提案（Dry-Run）**: `dart fix --dry-run` および `dart analyze` の出力を構造化データとして抽出し、PR コメントとして安全にフィードバックする。
2. **Supabase SQL 後方互換性 Linter**: `supabase/migrations/*.sql` に対して破壊的スキーマ変更を検知し、[`DUAL_WRITE_TRANSITION_STANDARD.md`](./DUAL_WRITE_TRANSITION_STANDARD.md)（14 日間デュアルライト標準）に沿った段階的移行を促す。

## 2. 検知対象の SQL 破壊的変更

| コード | パターン | 推奨対応 |
|---|---|---|
| `sql-drop-table` | `DROP TABLE` | Expand → Dual-Write → Contract フェーズを経て別 PR で実施 |
| `sql-drop-column` | `DROP COLUMN` | 旧クライアント残存期間（14日）後に削除 |
| `sql-alter-column-type` | `ALTER COLUMN ... TYPE` | 新カラム追加＋デュアルライトで段階移行 |
| `sql-rename-column` | `RENAME COLUMN` | 新カラム追加＋デュアルライト＋Read Failsafe で移行 |
| `sql-truncate` | `TRUNCATE` | 本番データ破壊を防ぐため移行スクリプトでの無条件実行を禁止 |
| `sql-not-null-no-default` | `ADD COLUMN ... NOT NULL` (`DEFAULT` なし) | `NULL` 許容または `DEFAULT` 指定で Expand 実施 |

## 3. CLI 運用

- `python -B scripts/auto_refactor_compat_lint.py --sql-files <files...> --dart-fix-log <log> --markdown`
- `--json` 指定時は構造化 JSON を出力し、`--fail-on-breaking` 指定時は破壊的 SQL 検知時に終了コード `2` を返す。
- 本変更による DB マイグレーションは `0` 件。
