---
title: "200ページのFlutter Webアプリでデザイントークンを一括適用した話"
tags: Flutter,個人開発,UI,buildinpublic,Dart
published: false
---

# 200ページのFlutter Webアプリでデザイントークンを一括適用した話

## 背景

[自分株式会社](https://my-web-app-b67f4.web.app/)は約200ページのFlutter Webアプリです。
開発が進むにつれて、ページごとにバラバラな色指定が増えていきました。

```dart
// ページAではこう書いてある
color: Colors.grey,

// ページBではこう
color: Color(0xFF9E9E9E),

// ページCではこう
color: Colors.grey[600],
```

デザインシステム (`docs/DESIGN.md`) では `Color(0xFFB0B0B0)` に統一と決まっているのに、200ページに散らばったハードコード色を手作業で修正するのは現実的ではありません。

## 解決策: grep + sed による一括置換 + flutter analyze 検証

### Step 1: 違反箇所を洗い出す

```bash
# Colors.grey (サフィックスなし) の全箇所を一覧
grep -rn "Colors\.grey\b" lib/ --include="*.dart" | wc -l
# → 例: 312件

# 特定のファイルで確認
grep -rn "Colors\.grey\b" lib/pages/ --include="*.dart" | head -10
```

### Step 2: Python で安全に一括置換

`sed` は正規表現の扱いが OS によって差異があるため、Pythonを使います。

```python
import os
import re

# 対象ディレクトリ
target_dir = "lib/"

# 置換ルール (old → new)
replacements = [
    (r'\bColors\.grey\b(?!\[)', 'const Color(0xFFB0B0B0)'),
    (r'\bColors\.grey\[700\]', 'const Color(0xFF616161)'),
    (r'\bColors\.grey\[600\]', 'const Color(0xFF757575)'),
    (r'\bColors\.grey\[400\]', 'const Color(0xFFBDBDBD)'),
    (r'\bColors\.grey\[200\]', 'const Color(0xFFEEEEEE)'),
]

# 全 .dart ファイルを処理
for root, dirs, files in os.walk(target_dir):
    for file in files:
        if not file.endswith('.dart'):
            continue
        path = os.path.join(root, file)
        with open(path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        new_content = content
        for pattern, replacement in replacements:
            new_content = re.sub(pattern, replacement, new_content)
        
        if new_content != content:
            with open(path, 'w', encoding='utf-8') as f:
                f.write(new_content)
            print(f"Updated: {path}")
```

### Step 3: dart format で整形

```bash
dart format lib/ --set-exit-if-changed
# → 変更されたファイル数を出力
```

### Step 4: flutter analyze で検証

```bash
flutter analyze lib/
# → No issues found! (ran in Xs)
```

`flutter analyze` が 0エラーになるまで繰り返す。よくある残課題:

```
error • Only static fields can be declared as const • page.dart:30 • const_instance_field
```

これは `const Color _xxx` → `static const Color _xxx` に変更するだけ。

### Step 5: commit

```bash
git add lib/
git commit -m "style: DESIGN.md token置換 — Colors.grey→Color(0xFFB0B0B0) 43ページ一括"
git push origin main
```

## 落とし穴: `Colors.greyXX` の誤置換

`Colors.white12` や `Colors.white38` を `Colors.white` + 数値と誤認しないよう、正規表現の境界指定が重要です。

```python
# ❌ Bad: white12 が "white" + "12" に分解される
r'\bColors\.white\b'  # → Colors.white12 も誤マッチ

# ✅ Good: 単語境界 + 否定先読みで数字サフィックスを除外
r'\bColors\.white\b(?!\d)'
```

実際に `Colors.white12` → `Color(0x1FFFFFFF)` と `Colors.white38` → `Color(0x61FFFFFF)` を誤置換するバグが発生し、13箇所のCI修正が必要になりました。

## 成果

| 指標 | before | after |
|------|--------|-------|
| DESIGN.md 準拠率 | ~65% | ~95% |
| ハードコード色 | 312件 | 12件 |
| CI Lint エラー | 0 | 0 |
| 修正ページ数 | - | 43ページ/1コミット |

## まとめ

200ページのFlutter Webアプリでも、grep + Python置換 + flutter analyze の組み合わせで
デザイントークン準拠を大規模に自動化できます。

重要なのは:
1. **一括置換は必ず flutter analyze 0エラーで締める** (linterが次回巻き戻すため)
2. **正規表現は単語境界を厳密に** (誤置換は連鎖修正コミットを生む)
3. **dart format は必ずセット** (CIの `Check formatting` が落ちる)

---
自分株式会社: https://my-web-app-b67f4.web.app/
#FlutterWeb #Dart #buildinpublic #個人開発
