---
title: "技術ブログ自動投稿パイプライン — GitHub Actions × Supabase EF で Qiita/dev.to を自動化した"
tags: Flutter,Supabase,buildinpublic,個人開発,自動化
published: false
---

# 技術ブログ自動投稿パイプライン — GitHub Actions × Supabase EF で Qiita/dev.to を自動化した

## 問題: コードは書けても記事が書けない

コーディングセッションが充実していても、Qiita記事と dev.to 記事を書いて投稿すると1時間かかる。100記事分掛けると、ボトルネックは明らかだ。

[自分株式会社](https://my-web-app-b67f4.web.app/) は **99本以上** の技術記事を Qiita と dev.to に公開している。それを可能にした自動化パイプラインを紹介する。

---

## パイプライン全体像

```
git commit (機能実装)
      ↓
blog-draft.yml (毎日 08:00 JST)
→ git log から JA + EN 下書きを自動生成
→ docs/blog-drafts/YYYY-MM-DD.md に保存
      ↓
blog-publish.yml (手動ディスパッチ or スケジュール)
→ Markdown 下書きを読み込む
→ blog-auto-publisher EF を呼ぶ
→ Qiita API + dev.to API に投稿
→ blog_posts テーブルを更新 (status: posted)
```

4コンポーネント: 2本の GitHub Actions ワークフロー、1本の Supabase Edge Function、1枚の PostgreSQL テーブル。

---

## コンポーネント 1: 下書き自動生成 (blog-draft.yml)

毎日 08:00 JST に実行。7日間の git log を読んで下書きを生成する:

```yaml
- name: ブログ下書きを生成
  env:
    ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
  run: |
    COMMITS=$(git log --oneline --since="7 days ago")
    if [ -z "$COMMITS" ]; then exit 0; fi

    DATE=$(date +%Y-%m-%d)
    DRAFT_PATH="docs/blog-drafts/$DATE.md"
    DRAFT_PATH_EN="docs/blog-drafts/$DATE-en.md"

    # Claude API で日本語下書きを生成
    python scripts/generate_draft.py \
      --commits "$COMMITS" \
      --lang ja \
      --output "$DRAFT_PATH"

    # 英語下書きを生成
    python scripts/generate_draft.py \
      --commits "$COMMITS" \
      --lang en \
      --output "$DRAFT_PATH_EN"

    git add "$DRAFT_PATH" "$DRAFT_PATH_EN"
    git commit -m "自動: ブログ下書き $DATE (日本語+英語)"
    git push origin main
```

下書きのフロントマターは `published: false`。投稿ステップで `true` に更新される。

---

## コンポーネント 2: blog_posts テーブル

```sql
CREATE TABLE blog_posts (
  id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  title           text        NOT NULL,
  draft_path      text        NOT NULL,
  status          text        NOT NULL DEFAULT 'draft',
    -- draft | posted | skipped
  target_platforms text[],
    -- ['qiita', 'devto']
  posted_at       timestamptz,
  url             text,
  created_at      timestamptz NOT NULL DEFAULT now()
);
```

`status = 'posted'` は **不可逆** — EF がこれをチェックして二重投稿を防ぐ。大幅な編集後に再投稿する場合は新しい行を INSERT する。

---

## コンポーネント 3: blog-auto-publisher Edge Function

`blog-publish.yml` から呼ばれる。実際の API 呼び出しを担当する:

```typescript
// blog-auto-publisher/index.ts
const { action, id, content, tags, platforms } = await req.json();

if (action === 'auto_publish') {
  const results: Record<string, { url?: string; error?: string }> = {};

  // 二重投稿チェック
  const { data: existing } = await supabase
    .from('blog_posts').select('status').eq('id', id).single();

  if (existing?.status === 'posted') {
    return new Response(JSON.stringify({ ok: false, reason: 'already_posted' }));
  }

  // Qiita 投稿
  if (platforms.includes('qiita')) {
    const res = await fetch('https://qiita.com/api/v2/items', {
      method: 'POST',
      headers: { Authorization: `Bearer ${Deno.env.get('QIITA_ACCESS_TOKEN')}` },
      body: JSON.stringify({ title, body: content, tags: tags.map(t => ({ name: t })) }),
    });
    results.qiita = res.ok
      ? { url: (await res.json()).url }
      : { error: `HTTP ${res.status}` };
  }

  // dev.to 投稿
  if (platforms.includes('devto')) {
    const res = await fetch('https://dev.to/api/articles', {
      method: 'POST',
      headers: { 'api-key': Deno.env.get('DEVTO_API_KEY')! },
      body: JSON.stringify({ article: { title, body_markdown: content, published: true } }),
    });
    results.devto = res.ok
      ? { url: (await res.json()).url }
      : { error: `HTTP ${res.status}` };
  }

  // ステータス更新
  const anySuccess = Object.values(results).some(r => r.url);
  if (anySuccess) {
    await supabase.from('blog_posts')
      .update({ status: 'posted', posted_at: new Date().toISOString() })
      .eq('id', id);
  }

  return new Response(JSON.stringify({ ok: anySuccess, results }));
}
```

---

## コンポーネント 4: blog-publish.yml (手動ディスパッチ)

下書きパスを受け取り EF を呼ぶ:

```yaml
on:
  workflow_dispatch:
    inputs:
      draft_path:
        description: 'JA下書きパス (docs/blog-drafts/YYYY-MM-DD.md)'
        required: true
      draft_path_en:
        description: 'EN下書きパス (省略可、dev.to用)'
        required: false
      platforms:
        description: '投稿先: qiita, devto, または qiita,devto'
        default: 'qiita,devto'
      dry_run:
        description: 'ドライラン (実投稿スキップ)'
        default: 'false'
```

重要: `blog_posts` に登録してから投稿する (ロールバック安全):

```yaml
- name: Step 3 - blog_posts テーブルに登録
  id: register
  run: |
    POST_ID=$(curl -s -X POST "$SUPABASE_URL/functions/v1/blog-post-manager" \
      -H "Authorization: Bearer $SUPABASE_KEY" \
      -d '{"action":"register","title":"...","draft_path":"..."}' \
      | jq -r '.post.id')
    echo "post_id=$POST_ID" >> $GITHUB_OUTPUT

- name: Step 4 - 各プラットフォームに投稿
  run: |
    curl -X POST "$SUPABASE_URL/functions/v1/blog-auto-publisher" \
      -H "Authorization: Bearer $SUPABASE_KEY" \
      -d '{"action":"auto_publish","id":"${{ steps.register.outputs.post_id }}","content":"..."}'
```

---

## Qiita レートリミット対応

Qiita は **1日 約4本** の制限がある。超えると429が返り、JST深夜0時 (UTC 15:00) まで解除されない。ワークフローはこれを優雅に処理する:

```yaml
- name: Step 4 - 各プラットフォームに投稿
  continue-on-error: true  # 429 でワークフロー失敗させない
  run: |
    if [ "$HTTP_CODE" = "429" ]; then
      echo "⚠️ Qiita 429: 本日の制限に達した。15:00 UTC 以降にリトライ"
      echo "qiita_url=" >> $GITHUB_OUTPUT
    fi
```

429 の場合 `blog_posts.status` は `'draft'` のまま残る。翌日ディスパッチすれば再挑戦できる。

---

## バックフィル: 過去下書きを一括投稿

90本の下書きバックログを一括処理する場合:

```bash
# 未投稿のEN下書きをすべて dev.to に投稿
for f in docs/blog-drafts/*-en.md; do
  published=$(grep '^published:' "$f" | awk '{print $2}')
  if [ "$published" = "false" ]; then
    gh workflow run blog-publish.yml \
      -f draft_path_en="$f" \
      -f platforms="devto" \
      -f dry_run="false"
    sleep 3  # バースト防止
  fi
done
```

dev.to はQiitaほど厳しいレートリミットではないが、バースト保護のため `sleep 3` を入れる。

---

## まとめ

| コンポーネント | 役割 |
|-----------|---------|
| `blog-draft.yml` | git log から JA+EN 下書きを自動生成 (毎日) |
| `blog_posts` テーブル | ステータス管理・二重投稿防止 |
| `blog-auto-publisher` EF | Qiita/dev.to API 呼び出し・ステータス更新 |
| `blog-publish.yml` | プラットフォーム選択+ドライランつき手動ディスパッチ |

結果: コードを書けば記事になる。99本以上、1パイプライン。

自分株式会社: [https://my-web-app-b67f4.web.app/](https://my-web-app-b67f4.web.app/)

#buildinpublic #FlutterWeb #Supabase #個人開発 #自動化
