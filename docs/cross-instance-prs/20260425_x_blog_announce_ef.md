# Cross-Instance PR: blog-publish 後 X 自動告知 EF action

**From**: PS#2 S32  
**To**: Win版 or VSCode版  
**Priority**: Medium  
**Created**: 2026-04-25

---

## 依頼内容

`blog-publish.yml` 完了後に dev.to 投稿 URL を X に自動告知する action を `schedule-hub` に追加。

## 実装案

```typescript
// supabase/functions/schedule-hub/index.ts
case 'x.post_blog_announcement': {
  const { title, devto_url, qiita_url, tags } = body;
  const tagStr = (tags as string[] || []).slice(0, 3).map(t => `#${t}`).join(' ');
  const text = `📝 新記事: ${title}\n\n${devto_url || qiita_url}\n\n${tagStr} #BuildInPublic`;
  // post-x-update EF を呼び出す (OAuth 1.0a 設定済み)
  const xResp = await fetch(`${Deno.env.get('SUPABASE_URL')}/functions/v1/post-x-update`, {
    method: 'POST',
    headers: { 'Authorization': `Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')}` },
    body: JSON.stringify({ text })
  });
  return new Response(JSON.stringify({ success: xResp.ok }));
}
```

## blog-publish.yml への追加

```yaml
# Step 末尾に追加 (devto URL 取得後)
- name: Post X announcement
  if: env.DEVTO_URL != ''
  env:
    SUPABASE_ANON_KEY: ${{ secrets.SUPABASE_ANON_KEY }}
  run: |
    curl -s -X POST "${{ env.TOOLS_HUB_URL }}" \
      -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
      -H "Content-Type: application/json" \
      -d "{\"action\":\"x.post_blog_announcement\",\"title\":\"$ARTICLE_TITLE\",\"devto_url\":\"$DEVTO_URL\",\"tags\":[\"flutter\",\"BuildInPublic\"]}"
```

## 関連

- `docs/marketing/x-account-strategy.md` — 全体戦略 (PS#2 S32 作成)
- `supabase/functions/post-x-update/` — X 投稿 EF (OAuth 1.0a 設定済み)
- `docs/SCHEDULE_TASKS.md` — X 投稿先 @kanta13jp1
