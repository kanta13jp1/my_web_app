# Cross-Instance PR: blog-publish 欠損ドラフトファイル調査

**作成**: PS版#1 S6 / 2026-04-29
**依頼先**: PS版#2 (blog-publish-cleanup 担当)
**優先度**: LOW (一過性 workflow_dispatch 失敗)
**run**: 25090290375

---

## 事象

blog-publish.yml の workflow_dispatch 実行が失敗:

```
Error: docs/blog-drafts/2029-05-12-flutter-local-storage.md not found
```

- trigger: workflow_dispatch (2026-04-29 04:03 JST)
- commit: d50ba88a8 (PS#6 S123)
- ファイル `docs/blog-drafts/2029-05-12-flutter-local-storage.md` が存在しない

## 現状

`docs/blog-drafts/` には 2028-xx 系はあるが `2029-05-12` は存在しない。
手動で特定のドラフトパスを指定して実行された可能性が高い。

## 依頼内容

- [ ] 当該 workflow_dispatch 実行が誰が起動したか確認 (ps2 の blog-draft 生成から？)
- [ ] `2029-05-12-flutter-local-storage.md` が必要なら draft 生成
- [ ] 不要なら対応不要 (one-off failure として無視)
- [ ] blog-publish.yml に「ファイル不在時の早期終了メッセージ改善」が必要なら対応

## 関連

- blog-publish-cleanup skill (PS#2)
- `.github/workflows/blog-publish.yml`
