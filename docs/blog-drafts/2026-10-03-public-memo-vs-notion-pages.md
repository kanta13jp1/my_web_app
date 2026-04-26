---
title: "パブリックメモ vs Notion Pages — 「公開する」設計の違いが生産性を変える"
tags: notion,productivity,saas,個人開発
published: false
---

# パブリックメモ vs Notion Pages — 「公開する」設計の違いが生産性を変える

## メモを「公開する」ことのコスト

Notion で何かを公開するとき、どんな手順を踏くか:

1. ページを作る
2. 整形する (見出し・テーブル・コールアウト...)
3. カバー画像を設定する
4. Share → Publish on web
5. リンクをコピーする

5ステップ。完璧に整ったページを公開する設計だ。

自分株式会社のパブリックメモは別の思想から設計されている。**「今思っていること」をそのまま公開できる**ことが目的だ。

---

## パブリックメモとは

自分株式会社のパブリックメモは、Twitter/X の「つぶやき」と Notion ページの中間にある機能:

- **文字数制限なし** (X の 280文字制限なし)
- **整形不要** (Notion のリッチエディタ不要)
- **即時公開** (承認フロー・公開設定なし)
- **URLで共有可能** (固有の公開URL)
- **更新可能** (投稿後に編集できる)

用途:

```
・学習ログ (今日学んだこと)
・アイデアメモ (まだ整理されていない思考)
・作業日誌 (何をやったか)
・短い技術ノート (コマンドメモ・設定値)
・読書メモ (気になった一節)
```

---

## Notion Pages との設計比較

| 観点 | Notion Pages | パブリックメモ |
|------|-------------|--------------|
| 公開までの手順 | 5〜8ステップ | 1ステップ (書いて送信) |
| 必要な整形 | 推奨 (見出し・構造) | 不要 |
| URL形式 | notion.so/workspace/xxx | my-web-app.web.app/memo/xxx |
| 編集後の公開 | 即時反映 | 即時反映 |
| 検索インデックス | Notion 内のみ | 公開URL → Google インデックス可 |
| バージョン履歴 | あり (Pro以上) | なし (現状) |
| コメント機能 | あり | なし (現状) |
| 画像埋め込み | ◎ | △ (テキスト中心) |
| テンプレート | あり | なし |
| 月額コスト | $16/月 | $0 (自分株式会社内) |

---

## 「整形しなくていい」がなぜ重要か

Notion Pages の問題は「公開するなら綺麗にしなければ」という心理的プレッシャーが生まれること。

結果:
- 整形に時間を使う (本質ではない作業)
- 「まだ整形が終わっていない」と公開を先延ばしにする
- 結局公開されないまま下書きが溜まる

パブリックメモはこの問題を根本から解決する。「未完成でいい、思考の断片でいい」という設計前提を持っている。

Austin Kleon の "Show Your Work" が言う「完成品ではなく過程を共有する」に近い思想だ。

---

## 実装: Supabase × Flutter

```sql
-- page_shares テーブル (公開メモの実体)
CREATE TABLE page_shares (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users,
  title TEXT,
  content TEXT NOT NULL,
  slug TEXT UNIQUE,           -- URL用スラッグ
  is_public BOOLEAN DEFAULT true,
  view_count INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 公開メモは RLS で全員が読める
CREATE POLICY "public memos are readable by all"
  ON page_shares FOR SELECT
  USING (is_public = true);

-- 自分のメモのみ編集可
CREATE POLICY "users can edit own memos"
  ON page_shares FOR ALL
  USING (auth.uid() = user_id);
```

```dart
// Flutter: メモ投稿 (1ステップ)
Future<void> publishMemo(String content) async {
  final slug = generateSlug(); // UUID短縮形
  await supabase.from('page_shares').insert({
    'content': content,
    'slug': slug,
    'user_id': supabase.auth.currentUser!.id,
  });
  // 即時公開 URL: /memo/$slug
}
```

---

## SEO 観点からの価値

Notion の公開ページは `notion.so` ドメインになる。SEO 評価は Notion のドメインに付く。

自分株式会社のパブリックメモは `my-web-app-b67f4.web.app/memo/xxx` になる。**自分のドメインに SEO 評価が蓄積される**。

長期的に多数のメモを公開すれば、ロングテールキーワードで自分のドメインが検索に引っかかる確率が上がる。

---

## いつ Notion Pages を使うべきか

パブリックメモが全てを解決するわけではない。Notion Pages が適切な場面:

- **整えられたドキュメントを共有したい** (仕様書・提案書・ポートフォリオ)
- **画像・動画・埋め込みが必要** (リッチコンテンツ)
- **コメントで議論したい** (フィードバック収集)
- **テンプレートを使いたい** (繰り返し使う構造)
- **チームで共同編集する** (複数人での作業)

「思考の断片を記録・共有する」用途ならパブリックメモ、「整ったコンテンツを共有する」用途なら Notion Pages。

---

## まとめ

- Notion Pages は「整ったコンテンツ公開」に最適化されている
- パブリックメモは「未整理の思考を即座に公開」に最適化されている
- 整形コストがなくなると、公開頻度が上がり、思考の外部化が進む
- SEO 観点では自ドメインに評価が付くパブリックメモが有利

「完璧なページを公開する」より「不完全でも今の思考を公開する」方が、長期的に積み重なる。

---

## 関連記事

- [WBS × AI タスク管理設計](./2026-09-12-wbs-task-management-ai-assistant.md)
- [AI大学 236社の学び方](./2026-09-19-ai-university-how-to-learn-providers.md)
- [なぜ Notion から Supabase+Flutter に移行したか](./2026-05-23-why-i-left-notion-for-supabase-flutter.md)

---

*自分株式会社 — 21社競合のベストを1つに統合するライフマネジメントアプリ*  
*本番: https://my-web-app-b67f4.web.app/*
