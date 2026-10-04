# /design-check — デザイン品質チェック

`docs/DESIGN.md` の「デザインレビュー手順」を使い、指定された Flutter ファイルまたは現在の差分をレビューする。

1. `docs/DESIGN.md` を読む。
2. `git diff --name-only -- '*.dart'` またはユーザー指定から対象を限定する。
3. 色、タイポグラフィ、レイアウト、コンポーネント、アクセシビリティ、実装品質を順に確認する。
4. 機械検索は候補抽出にだけ使い、文脈確認なしで一括置換しない。
5. 変更を依頼されている場合だけ修正し、`dart format`、`flutter analyze`、対象テストを実行する。
6. `PASS` / `WARN` / `FAIL`、ファイルと行、`docs/DESIGN.md` の該当節、最小修正案を返す。

この command にトークン値や独自の許容値を追加しない。基準変更は `docs/DESIGN.md` で行う。
