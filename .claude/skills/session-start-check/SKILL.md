---
name: session-start-check
description: |
  自分株式会社の全インスタンス (VSCode版 / PowerShell版 / Windowsアプリ版) でセッション開始時に
  必ず実行する Rule 14 (ツールバージョン) + Rule 10 (docs健全性) + 並行衝突チェックを
  一括実行する。

  Triggers on: "/session-start-check", "セッション開始チェック", "Rule14 + Rule10 確認",
  "並行インスタンス状態確認".

  引数なし。数十秒で完了する軽量スキル。
---

# session-start-check スキル

## 概要

セッション開始時に必ず必要な 3 つの確認を 1 コマンドで終わらせる。

1. **Rule 14**: `PYTHONUTF8=1 python3 scripts/check_versions.py` で主要ツールバージョン確認
2. **Rule 10 lite**: cross-instance-prs の pending / stale 検出
3. **並行衝突検出**: 直近 10 コミットからアクティブインスタンスを特定

## 手順

### Step 1: ツールバージョン (Rule 14)

```bash
PYTHONUTF8=1 python3 scripts/check_versions.py
```

- 結果に「バージョン変更なし」が出れば OK
- 変更があれば `docs/tool-versions.md` 更新 + 制約解消チェック
- Windows でない (WEB版) の場合は `scripts/check_versions.py --web` は不可 → WebFetch で手動確認

### Step 2: cross-instance-prs の状態

```bash
ls docs/cross-instance-prs/ | grep -v done/
```

- root と `done/` の重複ファイルを検出: 内容一致なら root 削除 (stale)
- pending の PR がある → 本セッションで対応可能か判定

### Step 3: 並行衝突検出

```bash
git log origin/main --oneline -10
```

- 直近10コミットの末尾 `(XXX版#N)` を数える
- 同インスタンスが連続している → 他インスタンスは待機中 or クラッシュ
- 複数インスタンスが交互 → 並行作業中 → ROADMAP 末尾追記時の conflict 警戒

### Step 4: レポート生成

以下の形式でユーザーに報告:

```
## セッション開始チェック (YYYY-MM-DD HH:MM)

### Rule 14 ツールバージョン
- ✅ すべて最新 (または ⚠️ X件変更)

### cross-instance-prs
- pending: N件 ([title])
- stale (root+done重複): M件 → 削除推奨

### 並行インスタンス
- 直近アクティブ: VSCode#N, PS#N, Win#N
- 衝突リスク: {低|中|高}

### 次の推奨タスク
1. ...
2. ...
```

## 運用上の注意

- **Auto Mode 必須**: セッション冒頭で許可確認スキップのため settings.local.json 確認
- **現在のインスタンス確認**: ユーザーの最新発話 (例: "現在のインスタンスはWindowsアプリ版です") を基準にする
- **高衝突リスク時**: ROADMAP 書き込みは最後にまとめて rebase+push
- **stale PR は即削除**: 並行インスタンスが archive commit しても root 残すケースが頻発
