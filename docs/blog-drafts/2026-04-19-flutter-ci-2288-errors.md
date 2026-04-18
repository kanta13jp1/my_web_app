---
title: "Flutter CIが2288エラーで壊れた話 — dart fix --apply 一発回復の手順"
tags: Flutter,Dart,CI/CD,個人開発,buildinpublic
published: false
---

# Flutter CIが2288エラーで壊れた話 — dart fix --apply 一発回復の手順

## 何が起きたか

ある朝 `deploy-prod.yml` が突然失敗した。

```
error • Use 'const' with the constructor to improve performance
lib/pages/landing_page.dart:12:15 • prefer_const_constructors
... (2287 more errors)
```

2288件。200ページのFlutter Webアプリが一晩でCI爆死した。

原因は `analysis_options.yaml` の1行変更だった。

```yaml
# 前日まで: warning
prefer_const_constructors: warning

# 問題のコミット: error に格上げ
prefer_const_constructors: error
```

lintルールの重大度変更1行が、2288件のエラーに化けた。

## 修復手順

### Step 1: lint ルールを元に戻す (即時対応)

```yaml
# analysis_options.yaml
linter:
  rules:
    prefer_const_constructors: warning  # error → warning に戻す
```

これで CI は通るようになるが、**警告が2288件残る**。
警告は次の誰かが `error` に格上げした瞬間また爆発する。
なので完全修復が必要。

### Step 2: dart fix --apply で一括修正

```bash
dart fix --apply lib/
```

**出力例:**

```
pages/landing_page.dart
  prefer_const_constructors - 47 fixes
pages/home_page.dart
  prefer_const_constructors - 89 fixes
...
2276 fixes made in 181 files.
```

181ファイル、2276箇所が自動修正される。

### Step 3: dart format (必須)

`dart fix` 後は必ず `dart format`:

```bash
dart format lib/ --set-exit-if-changed
```

`dart fix` が追加した `const` キーワードで行長が変わりフォーマットが崩れる場合がある。
CI の `Check formatting` ステップが落ちるため必須。

### Step 4: flutter analyze 0エラー確認

```bash
flutter analyze lib/
# → No issues found! (ran in 23.9s)
```

### Step 5: commit

```bash
git add lib/ analysis_options.yaml
git commit -m "fix: prefer_const → warning + dart fix --apply 2276件修正 (181ファイル)"
git push origin main
```

## おまけ: require_trailing_commas も同時に壊れていた

`prefer_const_constructors` が爆発した同じタイミングで、
`require_trailing_commas` も 36件エラーになっていた。

これも `dart fix --apply` で解決:

```bash
dart fix --apply lib/
# → require_trailing_commas - 36 fixes in 12 files
```

**同じコマンドで複数の lint エラーをまとめて修正できる。**

## 落とし穴: dart fix が壊す場合がある

`dart fix --apply` が全て安全なわけではない。

```dart
// ❌ dart fix がこう変換
color: const Color(0xFF9E9E9E)[400]  // Color に [] 演算子はない

// ✅ 正解
color: const Color(0xFFBDBDBD)  // 正しい hex 値を直接指定
```

`Color(0xFFB0B0B0)[400]` のような無効な変換が残ることがある。
これは `dart fix` が古い `Colors.grey[400]` を誤変換したケース。

修正後は必ず `flutter analyze` で確認すること。

## さらにひどい落とし穴: PdfColor を巻き込む

`pdf` パッケージの `PdfColor` を使ったコードでも誤変換が発生した。

```dart
// ❌ dart fix の誤変換:
color: PdfColor(0xFFB0B0B0)700,  // 完全に壊れた構文

// ✅ 正解 (PdfColors の shade 定数を使う):
color: PdfColors.grey700,
```

`PdfColor` は `Color` と異なる API を持つ。
`PdfColors.grey700` / `PdfColors.grey300` などの定数を使う。

## まとめ

| ステップ | コマンド | 効果 |
|---------|---------|------|
| lint 緊急停止 | `analysis_options.yaml` 1行修正 | CI 即回復 |
| 自動修正 | `dart fix --apply lib/` | 数千件を一括 |
| 整形 | `dart format lib/` | CI Check formatting 通過 |
| 検証 | `flutter analyze lib/` | 0エラー確認 |

lintルールを `error` に格上げするときは、**先に `dart fix --apply` を実行してから** 格上げすること。
格上げと修正を同時にやろうとするとCIが爆死する。

---
自分株式会社: https://my-web-app-b67f4.web.app/
#FlutterWeb #Dart #CI/CD #buildinpublic #個人開発
