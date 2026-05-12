---
title: "個人開発の Build in Public — X でフォロワーを増やす投稿戦略"
tags: AI,個人開発,buildinpublic,automation
published: true
---

# 個人開発の Build in Public — X でフォロワーを増やす投稿戦略

Build in Public は透明性で信頼を積む戦略。投稿パターンを体系化する。

## 7 種の投稿テンプレート

```
1. マイルストーン報告
   「○○機能をリリースしました。
    作るのに難しかった点: [技術的な課題]
    ユーザーへの価値: [具体的なメリット]」

2. 数字の公開 (週次)
   「今週の数字:
    ユーザー: 247 (+12)
    MRR: ¥34,580 (+¥2,100)
    解約: 2人
    主な改善: [何を直した]」

3. 失敗の共有
   「今週やらかしたこと: [具体的な失敗]
    原因: [根本原因]
    次回の対策: [学び]
    これを共有する理由: 同じミスを防いでほしい」

4. 意思決定プロセス
   「[機能A] vs [機能B] どちらを先に作るか迷った。
    決め手: [理由]
    こういう思考プロセスで決めています」

5. 技術 tips (短縮版)
   「Flutter で [課題] を解決した方法:
    [3行のコード or 図]
    詳しくは →」

6. 質問・フィードバック依頼
   「[機能X] の UI を改善しています。
    A案 / B案、どちらが直感的ですか?
    実際のユーザーの意見が欲しい」

7. 感謝・コミュニティ
   「[フォロワー名] のフィードバックで [機能] が改善されました。
    ありがとうございます。変更前後の比較:」
```

## 週次投稿スケジュール

```
月: 先週の数字 (MRR/ユーザー数)
水: 技術 tips or 失敗談
金: 今週リリースしたもの or 作業中スクリーンショット
日: 来週の目標 (accountability)
```

## GHA で自動投稿準備

```typescript
// supabase/functions/post-x-update/index.ts
// weekly-sns-draft が生成した下書きを週1回確認して投稿
const { data: draft } = await supabase
  .from('sns_drafts')
  .select('content')
  .eq('platform', 'x')
  .eq('status', 'approved')
  .order('created_at')
  .limit(1)
  .single();

if (draft) {
  await postToX(draft.content);
  await supabase.from('sns_drafts')
    .update({ status: 'posted' })
    .eq('id', draft.id);
}
```

## まとめ

```
核心         → 透明性で信頼を稼ぐ (完璧じゃなくていい)
投稿種別     → 数字・失敗・技術・意思決定の4軸を回す
頻度         → 週4本が持続可能な上限
自動化       → 週次 GHA で下書き生成 → 手動確認 → 投稿
```

Build in Public は「成功した話」より「失敗した話」の方がエンゲージメントが高い。
