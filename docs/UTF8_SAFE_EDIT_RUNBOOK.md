# マルチバイト UTF-8 安全置換フォールバック手順 (`scripts/utf8_safe_replace.py`)

関連 Issue: `#1387`

## 1. 基本方針

- 通常のファイル編集では、利用中のエディタ・パッチ機構（`edit_file` / `apply_patch` など）を一次手段として使用します。
- 日本語・全角記号・絵文字を多く含む大容量ファイル（例: `COMPRESSED_PROMPT_V3.md`）で文字化けやコンテキスト一致失敗が発生した場合にのみ、明示的なフォールバックとして `scripts/utf8_safe_replace.py` を使用します。

## 2. 実行前提 (`PYTHONUTF8=1`)

Windows (PowerShell) を含む全環境で文字化け・エンコーディング例外を防ぐため、必ず `PYTHONUTF8=1`（または Python `-X utf8`）を有効にして実行してください。

```powershell
$env:PYTHONUTF8 = '1'
python -B scripts/utf8_safe_replace.py `
  --file docs/TARGET.md `
  --find "置換前テキスト" `
  --replace "置換後テキスト" `
  --expected-count 1 `
  --backup `
  --require-utf8-env `
  --dry-run
```

## 3. 安全ガードと運用チェックリスト

1. **事前確認 (`--dry-run` / `--expected-count`)**: 本番更新前に一致件数を検査し、想定件数と一致しない場合はフェイルクローズ（非書き換え終了）させます。
2. **長文・引用符回避 (`--find-file` / `--replace-file`)**: シェルのクォート展開を避けるため、複数行や記号を含む場合は UTF-8 ファイル経由で渡します。
3. **バックアップと差分確認 (`--backup`)**: `<file>.bak` で変更前スナップショットを保持し、編集後は必ず `git diff`（および一時 `.bak` の削除）を確認します。
4. **改行保持**: 入出力は UTF-8 バイト列・純 LF ベースで処理し、不正な UTF-8 ファイルはデコード段階で拒否します。
