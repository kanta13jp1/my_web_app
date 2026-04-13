---
title: "Bash の '"'"' がSQLファイルに混入して本番デプロイを破壊した話"
emoji: "🐚"
type: "tech"
topics: ["PostgreSQL", "Supabase", "GitHubActions", "bash", "個人開発"]
published: true
---

# Bash の `'"'"'` が SQL ファイルに混入して本番デプロイを破壊した話

## はじめに

自分株式会社の本番 Supabase migration デプロイが突然 `SQLSTATE 42601` で失敗し始めました。
エラーメッセージは謎めいており、原因特定に時間がかかりました。

```
ERROR: syntax error at or near "'"" (SQLSTATE 42601)
At statement: 0
-- Windows版#61: AI大学43社目 — Hailuo AI (MiniMax)
```

同一ファイルを目視で確認しても問題がわからない…。最終的に判明した原因は **bash シェルのクォーティングパターン `'"'"'` が SQL ファイルにそのまま混入していた**ことでした。

## bash の `'"'"'` とは何か

bash でシングルクォート文字列の中にシングルクォート `'` を入れるには、一度クォートを閉じて文字を挟んで再開する必要があります：

```bash
# bash での書き方: 3部構成
'...'   # シングルクォート文字列
"'"     # ダブルクォート内のシングルクォート (= ' 文字)
'...'   # 再開

# これを連結すると:
echo '{"key": "value"}'  # → {"key": "value"}

# curl の -d オプションでよく使われるパターン:
curl -d '"'"'{"key":"value"}'"'"'
# これは: ' + {"key":"value"} + ' と展開され
# → '{"key":"value"}' となる
```

この `'"'"'` というパターンは bash スクリプトのエスケープ技法です。

## 何が問題だったのか

AI大学コンテンツの migration ファイルに、curl の使用例を含む API ガイドが入っていました：

```sql
-- 問題のある SQL (shell quoting artifact が混入)
INSERT INTO ai_university_content (...) VALUES
(
  'hailuo', 'api', 'API Guide',
  E'...curl examples...\n  -d '"'"'{\n    "model": "video-01"\n  }'"'"'\n...',
  ...
)
```

**markdown や Shell で書かれたコンテンツをそのまま SQL の文字列値に埋め込む際に、bash quoting がそのままコピーされてしまった**のです。

PostgreSQL に `'"'"'` を渡すと：

1. `'` → 文字列開始
2. `"` → `"` 文字
3. `'` → 文字列終了！（ここで SQL パーサーは文字列が終わったと解釈）
4. `"'` → **構文エラー** `42601`

## 修正方法

### オプション1: `''` でエスケープ (採用)

SQL の E-string 記法 (`E'...'`) では、シングルクォートは `''`（2つ連続）でエスケープします：

```sql
-- 修正後
E'...-d ''{\\n    "model": "video-01"\\n  }''\\n...'
```

Python でバッチ修正：

```python
content = open('migration.sql', 'r', encoding='utf-8').read()
# '"'"' を '' に置換
content = content.replace("'\"'\"'", "''")
open('migration.sql', 'w', encoding='utf-8').write(content)
```

### オプション2: ドル引用符を使う

```sql
-- ドル引用符ならシングルクォートをエスケープ不要
$$
-d '{"model": "video-01"}'
$$
```

大量のシングルクォートを含む長文コンテンツには、ドル引用符の方が読みやすいです。

## 再発防止策

### Supabase migration ファイルを生成するときの注意

1. **Shell スクリプトのコードサンプルは避けるか、事前変換する**
   - `'"'"'` → `''` に変換してから埋め込む
   - または `$$...$$ ` ドル引用符を使う

2. **CI で事前 lint する**
   - `grep -n "'\"'\"'" supabase/migrations/*.sql` で artifact を検出
   - PR チェックに追加する

3. **ローカルで dry-run 実行**
   ```bash
   supabase db push --dry-run
   ```

## まとめ

| 現象 | 原因 | 修正 |
|------|------|------|
| `SQLSTATE 42601` | bash `'"'"'` がSQL文字列に混入 | `''` に置換 |
| deploy-prod 連続失敗 | migration ファイルに構文エラー | 対象ファイルを修正してプッシュ |

**教訓**: SQL migration ファイルに Shell スクリプトのコードサンプルを埋め込む場合は、bash クォーティング変換が不要になるドル引用符 (`$$`) を使うか、`'"'"'` → `''` を確認してから push する。

---

自分株式会社: https://my-web-app-b67f4.web.app/

#PostgreSQL #Supabase #bash #buildinpublic #個人開発
