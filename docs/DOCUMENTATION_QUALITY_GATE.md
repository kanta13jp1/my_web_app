# 文書品質検査

Issue #2625 の文書検査は GitHub Actions の Documentation Quality Gate で実行します。
Flutterの分析・テストは既存CI、ローカルの早期検査は既存Lefthookを使用します。
文書変更のためにローカルでFlutterの依存関係取得やビルドを繰り返しません。

## 検査と結果

追跡対象のMarkdownをCommonMarkとして解析し、リンクと画像の内部ファイル参照を確認します。
コード例内のリンクは対象外です。スペル検査は英語の既知の誤記を対象にします。
外部URL、見出しアンカー、アプリのルートURL、日本語文法の正常性を証明する検査ではありません。
Wikiリンクは既存のKnowledge Vault Lintで別に確認します。

PRでは固定したbase commitと比較し、新規指摘を検出すると失敗します。
同じ誤りの追加出現も新規として数え、行移動だけは新規として数えません。
既存指摘を含めた全件はJSON artifactに保存し、新規の最大50件と修正方法をjob summaryに表示します。
週次と手動実行では全件の指摘を失敗として報告します。過去の問題を正常と扱うbaselineではありません。

## 修正と通知

リンク先の移動や削除を確認し、参照先を修正または復旧してください。
スペル候補は文脈と専門語を確認して修正します。誤検出のために広範囲を無視する設定は追加しません。
検出器の異常終了は文書指摘と区別し、依存関係・文字コード・解析結果のログを確認してください。
既存Workflow Failure Handlerで失敗を集約し、Issueに実行へのリンクと修正の手がかりを通知します。
有料AI、秘密情報、外部URLへのアクセス、文書の自動修正は使用しません。

## 開発時の早期確認

既存Lefthookはコミット時の軽量検査を担当します。
文書検査器の依存関係を既に用意した環境では、次を実行できます。

```text
python scripts/documentation_links.py docs/DOCUMENTATION_QUALITY_GATE.md
python scripts/documentation_quality_gate_test.py
```

端末が逼迫している場合は新規インストールせず、PRのクラウド検査を使います。

検査器の仕様: https://pypi.org/project/markdown-it-py/4.0.0/
スペル検査: https://github.com/codespell-project/codespell/releases
