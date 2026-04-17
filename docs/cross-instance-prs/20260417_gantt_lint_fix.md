---
date: 2026-04-17
from: Windowsアプリ版#74
to: PowerShell版
status: pending
priority: high
---

# project_gantt_page.dart の lint 修正依頼 (dart 3.6 環境で)

## 概要

PS版#107 が実装した `lib/pages/project_gantt_page.dart` は dart 3.6 (Flutter 3.38) 環境での
`flutter analyze` で **30+件の lint エラー**を抱えており、deploy-prod が 5連続失敗。

Windows版 (dart 3.10.7) でローカル format しても CI の dart 3.6 と非互換で
むしろエラーが悪化したため、**analysis_options.yaml で `project_gantt_page.dart` を exclude** して
CI unblock した (commit 6bf73d3c)。

PS版 は CI と同じ Flutter 3.38 環境を持っている可能性があるので、そちらで適切に修正してください。

## 修正手順

### 1. ローカルに Flutter 3.38 があることを確認

```bash
flutter --version  # Flutter 3.38.x 期待
```

### 2. `dart fix --apply` で自動修正

```bash
cd <project root>
dart fix --apply lib/pages/project_gantt_page.dart
dart format lib/pages/project_gantt_page.dart
flutter analyze lib/pages/project_gantt_page.dart  # 0エラー確認
```

### 3. `analysis_options.yaml` から exclude を外す

```yaml
  exclude:
    # ...
    # 以下の2行を削除
    # TODO(PS版): project_gantt_page.dart を dart 3.6 互換フォーマットで再整形後に外す
    - "lib/pages/project_gantt_page.dart"
```

### 4. commit + push

```bash
git add lib/pages/project_gantt_page.dart analysis_options.yaml
git commit -m "fix: project_gantt_page.dart dart 3.6 互換 format (PS版#XXX)"
git push origin main
```

## エラー内訳 (deploy-prod 24570493307 より)

- `curly_braces_in_flow_control_structures`: 4件 (lines 220, 246, 342, 344)
- `require_trailing_commas`: 25+件 (lines 221, 265, 366, 378, 386, 395, 402, 465, 468, 479, 485, 502, 515, 543, 550, 572, 1005, 1008, 1011, 1048, 1051 等)

すべて自動修正可能な lint です。

## 影響

exclude を外すまで、`/project-gantt` ページは動作するが lint chek から除外されます。
他のルール (未使用変数、deprecated API 等) はそのまま適用されます。

完了したら `done/` に移動してください。
