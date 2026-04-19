---
title: "FlutterのDESIGNトークン移行を100%完了した — 300+ファイルのMaterial色定数を全排除"
tags: Flutter,UI,個人開発,buildinpublic,ClaudeCode
published: true
---

# FlutterのDESIGNトークン移行を100%完了した

## 目標: Material色定数をHEXトークンに完全移行

`Colors.orange`, `Colors.indigo`, `Colors.white` などの Material 色定数を
すべてデザイントークン (HEX値) に置き換えるプロジェクト。

**目的**: `docs/DESIGN.md` の Orange+Indigo ダークテーマを UI に一貫適用する。

## 移行前後の比較

```dart
// ❌ 移行前: Material ブランド色
Container(
  color: Colors.orange,
  child: Text('タイトル', style: TextStyle(color: Colors.white)),
)

// ✅ 移行後: HEX デザイントークン
Container(
  color: const Color(0xFFFF6B35),  // orange primary
  child: Text('タイトル', style: TextStyle(color: const Color(0xFFF1F5F9))),
)
```

## 移行規模

| 指標 | 値 |
|------|-----|
| 対象ファイル数 | 300+ |
| 移行開始時の準拠率 | 60% |
| 最終準拠率 | **100%** |
| 所要セッション数 | 8セッション (VSCode#94〜#109) |

## 難しかった3ケース

### ケース1: `Colors.grey.shade700` — shade系

```dart
// ❌ shade系はトークン置換後に invalid syntax になる
color: const Color(0xFFB0B0B0).shade700,  // → コンパイルエラー

// ✅ 正しい対処: PdfColors または固定 HEX
color: PdfColors.grey700,        // PDF パッケージ内
color: const Color(0xFF616161),  // 通常の Dart
```

`dart analyze` を通っても CI で `undefined_getter` が出るケース。
`.shadeXXX` は `MaterialColor` にしかないため、`Color` に適用すると実行時エラー。

### ケース2: `Colors.white` と `Colors.black` — 特殊な白黒

```dart
// ❌ 単純置換するとコンテキストによっては崩れる
const Color(0xFFFFFFFF)  // Colors.white の直接置換

// ✅ テーマに合わせた値を選ぶ
const Color(0xFFF1F5F9)  // slate-100 (テキスト白)
const Color(0xFF0F172A)  // slate-900 (テキスト黒)
```

純白・純黒より DESIGN.md のスレートスケールの方がテーマに合う。

### ケース3: `Colors.transparent` — 透明

```dart
// ✅ これだけはそのまま維持 (HEX 表現で同等)
Colors.transparent == const Color(0x00000000)
// 両方使えるが Colors.transparent の方が意図が明確
```

透明はトークン化不要。

## Claude Code で自動化した手順

```bash
# 1. 全ファイルの違反を一括確認
grep -r "Colors\." lib/ --include="*.dart" | wc -l

# 2. Python でバッチ置換
python3 -c "
import re, pathlib
for f in pathlib.Path('lib').rglob('*.dart'):
    src = f.read_text()
    # Colors.orange → Color(0xFFFF6B35)
    src = re.sub(r'Colors\.orange(?!Accent)', 'const Color(0xFFFF6B35)', src)
    f.write_text(src)
"

# 3. dart format → flutter analyze の順で検証
dart format lib/ --set-exit-if-changed
flutter analyze lib/
```

各セッションで10〜30ファイルをバッチ処理し、
`flutter analyze 0エラー` を確認してから push。

## 100%到達の確認コマンド

```bash
# 残存違反を確認 (0件 = 完了)
grep -r "Colors\.orange\|Colors\.indigo\|Colors\.amber\|Colors\.blue" lib/ \
  --include="*.dart" | grep -v "//\|test" | wc -l
```

`0` になったら完了。

## まとめ

300ファイルの一括移行は **小さいバッチ + 毎回 analyze** が安全。
1ファイルずつ手動は非効率だが、一気に全置換するとコンパイルエラーの修正が大変。
20〜30ファイル単位のバッチが最適だった。

---
自分株式会社: https://my-web-app-b67f4.web.app/
#Flutter #UI #buildinpublic #ClaudeCode #個人開発
