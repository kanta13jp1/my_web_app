# 依存パッケージ マルチライセンス自動監査および法的リスク管理ポリシー (#2623)

**関連 Issue**: `#2623`
**適用範囲**: Flutter/Dart (`pubspec.yaml`, `pubspec.lock`)、Node/NPM (`package.json`, `package-lock.json`)、Supabase Edge Functions (`deno.json`, `deno.jsonc`)、Python 運用スクリプト (`requirements*.txt`)

> **法的レビューに関する重要注記**: 本ポリシーおよび自動監査ツール (`scripts/audit_dependency_licenses.py`) は SPDX ライセンス式およびマニフェスト記載メタデータに基づく一次機械スクリーニングであり、法的助言ではありません。商用配信・再配布・リンク形態を含む最終的なコンプライアンス妥当性には、法務担当者による個別レビューを必須とします。

---

## 1. ライセンス分類基準

| 分類 | 判定結果 | 代表的 SPDX 識別子 | 運用ポリシー |
| :--- | :--- | :--- | :--- |
| **Permissive（許可・自動通過）** | `permissive` | `MIT`, `BSD-2-Clause`, `BSD-3-Clause`, `Apache-2.0`, `ISC`, `Zlib`, `CC0-1.0`, `Unlicense` | 著作権表示・ライセンス条文の保持を前提として自動通過。 |
| **Weak Copyleft（条件付き・要レビュー）** | `weak_copyleft_review` | `LGPL-2.1`, `LGPL-3.0`, `LGPL-*`, `MPL-2.0`, `EPL-1.0`, `EPL-2.0`, `CDDL-1.0` | ファイル単位・ライブラリ単位の開示義務や静的リンク影響を要レビュー。`--fail-on-weak-copyleft` 指定時または通知基準に応じて管理 Issue へ記録。 |
| **Forbidden（禁止・PR 自動ブロック）** | `forbidden` | `AGPL-3.0`, `AGPL-*`, `GPL-2.0`, `GPL-3.0`, `GPL-*`, `SSPL-1.0`, `SSPL-*`, `CPAL-1.0`, `WTFPL` | ネットワーク越しのソース開示義務（AGPL 等）や強いコピーレフト伝播リスクのため導入原則禁止。検出時は PR CI (`license-audit-pr`) を非ゼロ終了で自動ブロック。 |
| **未分類 / 外部メタデータ未取得** | `unverified` | `NONE` / 未記載 | ロックファイル単体にライセンス文字列を含まない依存関係は一覧化し、外部 SPDX メタデータ付与時または定期スキャンで継続確認。 |

### 複合 SPDX 式の扱い

- `A AND B`: 全構成ライセンスのうち最も厳格なリスク区分（`forbidden` > `weak_copyleft_review` > `permissive`）を適用する。
- `A OR B`: デュアルライセンスのうち `permissive` な選択肢が存在する場合は選択可能性を考慮し最も緩やかな許可区分を採用し、`forbidden` のみで構成される場合のみブロックする。

---

## 2. GitHub Actions 自動監査・通知パイプライン

ワークフロー `.github/workflows/dependency-license-audit.yml` は最小権限分離原則に基づき 2 ジョブ構成とする。

1. **`license-audit-pr` (`permissions: contents: read`)**:
   - `pull_request` / `schedule` / `workflow_dispatch` で実行し、`scripts/audit_dependency_licenses.py` により全エコシステムマニフェストを検証。
   - `forbidden`（例: `AGPL-3.0`, `GPL-3.0`）を 1 件でも検出した場合は終了コード `1` で失敗し、PR マージを自動ブロックする。
2. **`license-audit-notify` (`permissions: contents: read, issues: write`)**:
   - `pull_request` 以外 (`github.event_name != 'pull_request' && failure()`) での監査失敗時に起動し、検出された違反パッケージ・リスク区分・法務レビュー依頼を含む重複抑止済み GitHub Issue を起票または既存オープン Issue へ追記する。
   - GitHub API 認証情報が未設定の場合は無言成功せず終了コード `2`（fail-closed）で明示的に失敗する。
