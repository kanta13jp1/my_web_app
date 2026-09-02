---
name: local-election-candidate-release
description: >-
  Refresh the Kokumin Democratic Party local-election endorsement snapshot from the official PDF, regenerate the Flutter JSON and Dart fallback, preserve the repository/ViewModel architecture, validate the change, prepare a compliant pull request, monitor required checks, merge to main, and verify the Firebase production commit. Use when users ask to reflect newly announced 地方選の公認候補・推薦候補, update official candidate counts or prefecture aggregates, or complete that update through main merge and production deployment.
---

# Local Election Candidate Release

公式発表を唯一の根拠として、候補データ更新を本番反映まで完遂する。

## 必須資料

- 編集前に [project-contract.md](references/project-contract.md) を読む。
- PR作成、マージ、デプロイまで求められた場合は [release-monitoring.md](references/release-monitoring.md) も読む。

## 1. 安全な作業場所を確保する

1. リポジトリの `AGENTS.md` と適用対象の追加指示を読む。
2. `git status -sb`、`python scripts/codex_session_check.py`、`python scripts/ai_tool_watch.py --print-only` を実行する。
3. ルートがdirtyなら、既存変更を触らず `origin/main` から専用worktreeと `codex/` ブランチを作る。
4. 同じ候補更新を扱う未完了PRや近接worktreeがないか確認する。

## 2. 公式スナップショットを更新する

1. 公式候補者一覧をインターネットで開き、公開日、PDF、ページ数を確認する。過去の件数や検索結果だけを根拠にしない。
2. 必要なPython依存を導入し、既存ジェネレーターを実行する。
3. 生成JSONとDart fallbackを手編集しない。差分が必要ならジェネレーターまたはパーサーテストを修正して再生成する。
4. 更新前後について次を記録する。
   - `sourceAsOf`
   - `sourceDocumentSha256`
   - 公認総数と現職・新人・元職の内訳
   - 公認都道府県数
   - 推薦総数
   - 都道府県別の増減
5. 件数合計と内訳、都道府県集計、公式PDFの代表行を照合する。
6. 25%を超える減少を `--allow-large-drop` で通すのは、選挙サイクル切替や公式一覧の再編を人手で確認できた場合だけにする。根拠をPRへ残す。

## 3. Flutterの責務分離を守る

- JSON assetを正規スナップショット、生成Dartをオフラインfallbackとして維持する。
- Data層のrepositoryでlive snapshotとfallbackを解決する。
- UI状態と通知をViewModelへ置き、ページや共有サービスへ件数ロジックを複製しない。
- 公式PDFの形式またはJSON schemaが変わった場合だけ、parser、model、repository、ViewModelを必要最小限で更新する。
- UI表示や操作を変えた場合は、データ更新扱いにせずブラウザ・レスポンシブ検証を追加する。

## 4. 段階的に検証する

1. Pythonパーサー、生成データ、repository、ViewModel、ページ、共有サービスの対象テストを先に実行する。
2. 変更したDartファイルのformat checkと `flutter analyze` を実行する。
3. UI変更がなければ、ユーザー表示値と公式集計の一致を黒箱I/Oとして説明し、Minimal E2Eの例外理由をPRへ記録する。
4. UI変更があれば、最小約3ケースのFlutter integration testまたはPlaywright E2Eと、desktop/mobileの証拠を追加する。
5. full testまたはpre-push品質ゲートは、コミット内容が確定してから1回実行する。同じcommitに対して重いローカルテストを繰り返さない。

## 5. PRを作成する

1. 候補更新に関係するファイルだけをstage・commitする。
2. PR本文に公式URL、基準日、SHA-256、更新前後の件数、都道府県差分、アーキテクチャ、検証結果、rollbackを記載する。
3. リポジトリのスクリプトでMinimal E2EとHigh-risk Ultrareviewの合格スニペットを生成し、PR作成前に本文へ入れる。実施していないultrareviewを証拠として記載しない。
4. CIが対象にするhead SHAを控える。

## 6. CI、マージ、デプロイを完遂する

1. 必須チェックを監視し、failure、cancelled、timed_outを成功扱いしない。
2. PRが `BEHIND` ならGitHubのupdate-branchで最新mainを取り込み、新しいhead SHAのチェックを最初から待つ。
3. CI失敗時はログから最初の実原因を特定し、利用可能なら `github:gh-fix-ci` を使って最小修正を行う。
4. PRがready、mergeable、`CLEAN` で全必須チェック成功の場合だけsquash mergeする。
5. merge commitに紐づく `Deploy to Production` runを特定し、terminal statusまで監視する。
6. run成功後も本番URLを直接確認し、`version.json.commit` がmerge commitと完全一致することを確認する。
7. 一致しない場合は、後続のmain deployに上書きされたか、Hosting工程がsoft-failしたかを調べる。正しいcommitが公開されるまで完了と報告しない。

## 安全規則

- 公式資料にない氏名、区分、件数を推測しない。
- 生成物だけを直してジェネレーターとの不整合を作らない。
- 必須CIが未完了または失敗中のPRをmergeしない。
- 監視を依頼されたら、成功、修正可能な失敗、または外部権限による真のblockerまで継続する。
- 監視中はGitHub APIの軽量照会を使い、ローカルのFlutter build/testを再起動しない。
- ユーザーのdirty tree、別worktree、生成物以外の変更を削除・復元しない。

## 完了報告

次を簡潔に報告する。

- 公式基準日と公認・推薦・都道府県数
- 主要な都道府県差分
- PR URL、merge commit、全必須チェック結果
- production run URLと結論
- 本番HTTP status、公開version、公開commit
- 未完了事項または例外判断
