# MUSUBI manual validation

## GitHub Secrets設定

1. GitHubの対象リポジトリを開く。
2. **Settings → Secrets and variables → Actions** を開く。
3. `release-gates.md` のstaging用secret名を1件ずつ登録する。
4. Supabase dashboardでstaging project refとURLを表示し、Production projectと異なることを確認する。
5. secret値をIssue、PR、チャット、スクリーンショットへ貼らない。
6. `preflight.py --environment staging --check-github-secrets` で名前の存在だけを再確認する。

## 専用stagingユーザー

1. staging Supabase Authへ負荷試験専用ユーザーを作る。
2. 実ユーザーと同じメールアドレスやパスワードを使わない。
3. テストユーザーでstagingへログインし、短寿命のaccess tokenを取得する。
4. JWTはセッション限定の環境変数またはsecret storeへ保存する。
5. JWTをコマンド引数、ソース、fixture、checkpoint、CIログへ書かない。
6. 試験後にセッションを失効させ、不要ならユーザーを削除する。

## 2ブラウザーRealtime検証

ChromeとEdgeまたはFirefoxを使い、別々のstagingテストアカウントでログインする。

1. 両ブラウザーで開発者ツールの時計を揃える。
2. ブラウザーAで公開投稿を作る。
3. ブラウザーBで表示されるまでを複数回測る。
4. 共鳴・保存・削除など対象操作を行い、再読み込み後の状態を確認する。
5. オフライン復帰、タブ復帰、二重クリックでも不整合がないことを確認する。
6. 測定回数、中央値、p95、欠落回数を記録する。JWTや本文の個人情報は記録しない。

## DM RLS検証

テストアカウントA・B・Cを用意する。

1. AとBのDM threadを作る。
2. Aから送信し、Bが受信できることを確認する。
3. Bから返信し、Aが受信できることを確認する。
4. threadへ参加していないCで、一覧・直接URL・API相当操作のいずれでも読めないことを確認する。
5. 未認証状態でも読めないことを確認する。
6. AまたはB以外が送信・更新・削除できないことを確認する。

拒否結果は正常な証拠として残す。ただしレスポンス本文にtokenや個人情報を含めない。

## 第1ユーザーコホート

募集先としてX、Slack、メール、既存コミュニティのいずれかを指定する。

募集文へ次を含める。

- 5〜8名限定であること
- staging版の検証であること
- 所要時間と検証期間
- 投稿、Realtime、DMなど確認してほしい機能
- 不具合報告方法
- 取得データと利用目的
- いつでも参加を止められること

Codexは文案と送信対象一覧を提示する。人間が宛先と最終文面を承認するまで投稿・送信・招待を実行しない。

## 手動結果の記録

次の形式で、secretを含まない証拠を残す。

```text
環境: staging
ブラウザー: Chrome <version> / Edge or Firefox <version>
アカウント: test-a / test-b / test-c
Realtime: N回、中央値 N ms、p95 N ms、欠落 N回
DM RLS: A↔B allow、C deny、anonymous deny
負荷試験: 同時数 N、成功率 N%、p95 N ms
残課題: ...
```
