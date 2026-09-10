---
title: "ユーザーマニュアルは動くコードか? — 「手順通りにやったのに動かない」を静的解析で潰す"
tags: Flutter,個人開発,ドキュメント,webdev
published: true
---

# ユーザーマニュアルは動くコードか? — 「手順通りにやったのに動かない」を静的解析で潰す

自分株式会社 (Jibun Inc.) には、Notion・Evernote・MoneyForward・X (Twitter)・GitHub からデータを移行できると謳うユーザーマニュアルページがある。今回、実際のインポート画面のコードと突き合わせたところ、6つの手順のうち4つが**そのままでは実行不可能**だったことが判明した。原因と直し方を記録する。

## 発端: 「対応しています」の一文を信じない

マニュアルにはこう書いてあった。

> 自分株式会社は Notion / Evernote / MoneyForward / X (Twitter) / GitHub / Markdown ファイルからのインポートに対応しています。

もっともらしい。しかし実装側 (`import_page.dart`) を読むと、ファイル選択ダイアログは `sourceType` ごとに許可拡張子をハードコードしていた。

```dart
List<String> _extensionsFor(String sourceType) {
  switch (sourceType) {
    case 'notion':
      return const <String>['csv'];
    case 'evernote':
      return const <String>['enex', 'xml'];
    case 'markdown':
      return const <String>['md', 'markdown', 'txt'];
    case 'xlsx':
      return const <String>['xlsx'];
    case 'docx':
      return const <String>['docx'];
    case 'business_csv':
      return const <String>['csv'];
    default:
      return const <String>[];
  }
}
```

`sourceType` に存在するのは `notion` / `evernote` / `markdown` / `xlsx` / `docx` / `business_csv` の6種類だけ。`moneyforward` も `twitter` も `github` も **カードごと存在しない**。

## 見つかった4つの齟齬

1. **Notion**: マニュアルは「ZIP をダウンロードしてそのまま選択」と書いていたが、`notion` の許可拡張子は `csv` のみ。ZIP はファイル選択ダイアログに表示すらされない。
2. **MoneyForward**: そもそも `moneyforward` という `sourceType` が存在しない。CSV をそれっぽく `notion` カードに投げても、列見出しの一致ロジックが `title/name/ページ/タイトル` と `content/text/本文` しか見ておらず、MoneyForward の日本語ヘッダー (日付・内容・金額) は一つも拾えない。結果は **取り込み0件の無言失敗**。
3. **X (Twitter)**: 公式アーカイブは ZIP 内に JavaScript ファイルを詰めた形式。受理される拡張子がそもそも存在しない。
4. **GitHub**: アカウントデータのエクスポートは `.tar.gz`。同様に受理する `sourceType` がない。

厄介なのは (2) だ。ファイルが弾かれる (1)(3)(4) は「選べない」ので**すぐ気づける**。しかし (2) は一見成功して見えて中身が空、という一番タチの悪いパターンだった。

## 直し方: 「動く経路」を実装コードから逆算する

新機能を作る余力のない日でも、既存コードの中に **実は動く迂回路** が眠っていることがある。今回は汎用テーブルパーサー (`_rowsToNotes`, `xlsx` 用) の列マッチ候補を読んだところ、`内容` や `メモ` が既に候補に入っていた。

```dart
final contentIndex = _findColumnIndex(
  header,
  const <String>['content', 'text', 'body', 'plain text', '本文', '内容', 'メモ'],
);
```

つまり **CSV を Excel (.xlsx) に変換してから `xlsx` カードでアップロードすれば、MoneyForward の「内容」列がそのままノート本文になる**。コードは1行も変えず、マニュアルの手順を「動く手順」に書き換えるだけで直せた。

X と GitHub はアーカイブ形式そのものが複雑すぎて同じ迂回路は使えなかったので、正直に「直接インポートは未対応」と明記した上で、テキストを手動で `.md` に落として Markdown インポートを使う代替手順に差し替えた。ウソをつかないことを優先した。

## 学び

- 「対応しています」はドキュメントの願望であって、コードのソースオブトゥルースではない。マニュアルを直す前に、必ず picker のホワイトリストと列名マッチングを実装から読む。
- 一番危険なのはエラーで弾かれる手順ではなく、**成功したように見えて中身が空になる手順**。差分レビューでは「0件import」を異常系として検出する仕組みが要る。
- 大規模な自動化基盤 (今回は100を超える並行 worktree が動くリポジトリ) では、新機能を足すより先に「宣言されている機能と実装の乖離」を洗い出すほうがROIが高いことが多い。
