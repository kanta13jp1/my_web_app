# /design-check — デザイン品質チェック

このコマンドは変更したDartファイルのデザイン品質を自動チェックします。

## 実行手順

### Step 1: letterSpacing 違反チェック

```bash
# 本文系テキストの letterSpacing 違反を検出
grep -rn "letterSpacing" lib/ --include="*.dart" | \
  grep -v "//.*letterSpacing" | \
  grep -v "headlineLarge\|headlineMedium\|headlineSmall" | \
  grep -v "LIVE\|NEW\|BETA\|PRO\|HOT\|FREE"
```

違反があれば `letterSpacing` を削除する（見出し以外）。

### Step 2: Colors.black54 / Colors.black45 チェック

```bash
grep -rn "Colors\.black5\|Colors\.black4\|Colors\.black3" lib/ --include="*.dart" | \
  grep -v "//.*Colors\.black"
```

発見したら `Color(0xFF64748B)` (テキストセカンダリ) に置換。

### Step 3: border-radius 異常値チェック

```bash
# 10, 14, 18, 20, 24 などの非標準値を検出
grep -rn "circular(1[0-9]\|2[0-9])" lib/ --include="*.dart" | \
  grep -v "//.*circular" | \
  grep -v "circular(12)\|circular(16)\|circular(18)\|circular(999)"
```

発見したら 8/12/16/999 のいずれかに統一。

### Step 4: line-height 不足チェック

```bash
# body text で height が 1.5 未満の可能性
grep -rn "height: 1\.[0-4]" lib/ --include="*.dart" | \
  grep -v "//.*height"
```

本文系は 1.6 以上に修正。見出し系(1.4)は許容。

### Step 5: flutter analyze

```bash
flutter analyze lib/ 2>&1 | tail -10
```

0エラーを確認。

## 自動修正モード

```bash
# flutter analyze の自動修正可能な問題を修正
dart fix --apply lib/
```

## チェック完了後

.claude/skills/ui-design/SKILL.md のアンチパターンセクションと照らし合わせて
問題がないことを確認してからコミット。
