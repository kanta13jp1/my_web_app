# NotebookLM セットアップ手順

## 1回だけ必要な認証 (1分)

ターミナルで以下を実行し、開いたブラウザで Google アカウントにログインしてください:

```bash
notebooklm login
```

手順:
1. ブラウザが自動で開く
2. Google アカウントでログイン (notebooklm.google.com が表示されたらOK)
3. ターミナルに戻って **Enter** を押す
4. `✅ Logged in` が表示されれば完了

## 接続テスト

```bash
python notebooklm_research.py --setup
```

`✅ 接続成功` が表示されれば準備完了。

## 使い方

### `/deep-research` — ゼロトークンリサーチ

Claude Code で:

```text
/deep-research 競合21社の最新機能比較
/deep-research docs/DESIGN.md の改善点を教えて
/deep-research --files lib/pages/landing_page.dart lib/pages/home_page.dart --query パフォーマンス改善点
```

**いつ使う?**
- 3ファイル以上を同時分析するとき
- 競合リサーチ・URL調査
- 大きな設計書の俯瞰 (GROWTH_STRATEGY_ROADMAP.md 等)
- Claude の limit に近づいてきたとき

### `/wrap-up` — Master Brain 保存

セッション終了前に必ず実行:

```text
/wrap-up
```

セッションの成功パターン・失敗・発見を `memory/` に保存し、次回セッションで自動参照される。

## 仕組み

```text
あなた → Claude Code → notebooklm_research.py → NotebookLM (Gemini)
                ↑                                        ↓
          軽い編集・統合                         重い分析・要約 (無料)
```

Claude はトークンを「判断・コード生成・統合」だけに使い、
「大量文書の読み込み・要約」は Google 側に任せる。

## 注意事項

- `notebooklm-py` は非公式ライブラリ (Google公式ではない)
- 本番重要処理には使わず、分析・リサーチ目的に限定する
- Google アカウントへの依存あり — ログイン切れたら `notebooklm login` を再実行
