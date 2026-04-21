# BYPASS_RULES Secret Setup

担当: Codex (Claude quota fallback)

`BYPASS_RULES` は、GitHub Actions が保護ブランチへの自動 push を行うための repository secret です。2026-04-21 時点で `kanta13jp1/my_web_app` には secret の存在を確認済みです。値は GitHub から読み出せないため、権限不足や期限切れが疑われる場合だけローテーションしてください。

## 確認

```powershell
.\scripts\set_bypass_rules_secret.ps1 -Repo "kanta13jp1/my_web_app" -VerifyOnly
```

期待結果:

```text
OK: BYPASS_RULES exists in kanta13jp1/my_web_app
```

## ローテーション

新しい PAT を用意してから実行します。値はプロンプトで入力し、コマンド履歴には残しません。

```powershell
.\scripts\set_bypass_rules_secret.ps1 -Repo "kanta13jp1/my_web_app"
```

PAT の目安:

- 対象リポジトリ: `kanta13jp1/my_web_app`
- Repository permissions: `Contents: Read and write`
- Workflow 更新が必要な場合: `Workflows: Read and write`
- 保護ブランチへ直接 push する workflow で使うため、所有者または branch protection bypass 権限を持つアカウントの token を使う

## 利用箇所

- `.github/workflows/ai-university-update.yml`
- `.github/workflows/blog-publish.yml`
- `.github/workflows/blog-draft.yml`
- `.github/workflows/blog-verify.yml`

## 注意

- secret 値を docs、migration、issue、チャットに貼らない。
- `gh secret set --body "..."` のような平文引数は避ける。
- ローテーション後は、対象 workflow の次回実行で GH006 が再発しないか確認する。
