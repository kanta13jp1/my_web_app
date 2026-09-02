# X (Twitter) 公式アカウント運用設計

**作成**: PS#2 S32 / 2026-04-25  
**WBS task**: 57009177-0ad5-46cd-98e6-5fa3de5934d6 (business-marketing)  
**アカウント**: @kanta13jp1  
**EF**: `post-x-update` (OAuth 1.0a / schedule-hub 統合)

---

## 目標 KPI (6ヶ月)

| KPI | 現状 | 3ヶ月目標 | 6ヶ月目標 |
|-----|------|----------|----------|
| フォロワー数 | — | 500 | 2,000 |
| 月間インプレッション | — | 50,000 | 200,000 |
| プロフィールクリック率 | — | 2% | 5% |
| dev.to/Qiita 流入比率 | — | 10% | 25% |

---

## 投稿カテゴリ × 週次スケジュール

| 曜日 | カテゴリ | 内容 | 自動化 |
|------|---------|------|--------|
| 月 | **AI大学 Today** | 今週注目のAIプロバイダー紹介 (1社) | ✅ GHA cron |
| 火 | **競合情報** | 競合190社の最新アップデート速報 | ✅ competitor-monitoring |
| 水 | **T-1 記事告知** | dev.to/Qiita 新着記事を告知 | ✅ blog-publish後トリガー |
| 木 | **開発tips** | Flutter/Supabase/Deno の実装知見 | 手動 (週次) |
| 金 | **週次振り返り** | WBS 進捗 + 今週の学び | ✅ GHA weekly-summary |
| 土 | **コミュニティ** | フォロワーの質問 / Mention 返信 | 手動 |
| 日 | **来週予告** | 次週のT-1記事タイトル公開 | 半自動 |

---

## 自動投稿フロー (実装済みEFを活用)

### 1. T-1 記事告知 (最優先)

`blog-publish.yml` 完了後に自動 X 投稿:

```yaml
# .github/workflows/blog-publish.yml に追加
- name: Post X announcement
  if: steps.devto.conclusion == 'success'
  run: |
    curl -X POST "$TOOLS_HUB_URL" \
      -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
      -H "Content-Type: application/json" \
      -d "{
        \"action\": \"x.post\",
        \"text\": \"📝 新記事: $ARTICLE_TITLE\n\n$DEVTO_URL\n\n#自分株式会社 #Flutter #Supabase #BuildInPublic\"
      }"
```

### 2. AI大学 Today (月曜 09:00 JST 自動)

`wbs-user-tasks-notify.yml` と同様の GHA cron:

```yaml
# .github/workflows/x-ai-university-today.yml
schedule:
  - cron: '0 0 * * 1'  # 月曜 09:00 JST
steps:
  - name: Pick today's AI provider
    run: |
      # tools-hub:ai_university.get_random → post-x-update EF
      PROVIDER=$(curl -s "$TOOLS_HUB_URL" -d '{"action":"ai_university.get_random"}')
      TEXT="🎓 AI大学 Today: $(echo $PROVIDER | jq -r .name)\n\n$(echo $PROVIDER | jq -r .tagline)\n\n#AI大学 #AIツール"
      curl -X POST "$POST_X_URL" -d "{\"text\": \"$TEXT\"}"
```

### 3. 競合情報速報 (火曜 手動→自動化予定)

`competitor-monitoring.yml` 実行後、threat_level=HIGH の競合情報を自動投稿:

```bash
# competitor-monitoring.yml の末尾に追加 (Phase 2)
if [ "$HIGH_THREAT_COUNT" -gt 0 ]; then
  curl ... -d '{"action":"x.post","text":"🚨 競合情報: '"$HIGH_THREAT_SUMMARY"'"}'
fi
```

---

## コンテンツルール

### 投稿フォーマット

```
[絵文字] [タイトル/概要 50文字以内]

[本文 2-3行 / 読者の課題→解決の構造]

[URL]

#タグ1 #タグ2 #タグ3 (最大5個)
```

### タグ戦略 (固定ローテーション)

- **技術系**: `#Flutter` `#Supabase` `#Deno` `#ClaudeCode` `#生成AI`
- **ビジネス系**: `#自分株式会社` `#スタートアップ` `#SaaS` `#BuildInPublic`
- **コンテンツ系**: `#AI大学` `#AIツール` `#競合調査`

### 禁止事項

- 競合企業の名指し批判 (事実報告のみ)
- 未リリース機能の告知
- 24時間以内に同じ URL を 2 回投稿

---

## X Analytics CSV の取り込み (R24 / 月次)

`x.performance_context` の学習母集団は、既定では `x_post_log` = **アプリの AI シェア経由で
投稿したものだけ**。実測 (2026-04-27〜07-25 / 350 投稿) では、サイトへの URL クリック 304 件
のうち **302 件がアプリ外の手動投稿**から出ていた。取り込まない限り、学習ループはアカウント
最大の勝ち筋を一度も見ない。

手順:

1. [X Analytics のコンテンツ画面](https://x.com/i/account_analytics/content?type=posts&sort=impressions&dir=desc&days=90)
   右上のダウンロードから CSV をエクスポートする。
2. 本番サイトにログインした状態の DevTools > Application > Local Storage から
   `sb-<ref>-auth-token` の `access_token` をコピーし、環境変数に入れる。
3. まず dry-run で件数を確認し、問題なければ `--commit` を付けて取り込む。

```bash
python scripts/x_analytics_import.py "path/to/account_analytics_content.csv"
```

```bash
python scripts/x_analytics_import.py "path/to/account_analytics_content.csv" --commit
```

取り込んだ行は `learning_cohort='historical_benchmark'` になる。CSV は投稿からの経過時間が
バラバラな lifetime cumulative なので、投稿年齢を揃えた勝ち exemplar のランキングには
入れず、アカウント水準の獲得事実の供給に使う。

`x.analytics_import` は X operator ロールを要求する。スクリプトはパスワードを扱わず、
呼び出し側が渡したアクセストークンを Bearer で中継するだけ。トークンは短命なので 401 が
返ったら取り直す。

---

## 投稿テンプレート集

### T-1 記事告知

```
📝 新記事を公開しました！

{記事タイトル}

{URL}

#BuildInPublic #Flutter #Supabase
```

### AI大学 Today

```
🎓 AI大学 Today: {プロバイダー名}

{一言説明}

評価: ★{星}/9 | カテゴリ: {category}

ai-university ページで詳細確認👇
https://my-web-app-b67f4.web.app/ai-university

#AI大学 #AIツール
```

### 競合速報

```
🚨 競合情報: {企業名}

{アップデート内容 2行}

自分株式会社での代替機能: {ページURL}

#SaaS #競合調査
```

### 週次振り返り

```
📊 今週の進捗 ({日付})

✅ {完了1}
✅ {完了2}  
🔄 {進行中}

WBS: https://my-web-app-b67f4.web.app/project-gantt

#BuildInPublic #スタートアップ
```

---

## 実装優先度

| 優先度 | 実装 | 担当 | 期限 |
|--------|------|------|------|
| 🔴 即時 | T-1 記事告知 (blog-publish後) | PS#2 | 次回T-1 dispatch |
| 🟡 近日 | AI大学 Today 月曜 cron | Win版/PS#2 | 5月末 |
| 🟡 近日 | 競合速報 (HIGH threat自動) | PS#4 連携 | 5月末 |
| 🟢 中期 | 週次振り返り GHA | Win版 | 6月末 |

---

## blog-publish × X 連携 実装 (Phase 1)

T-1 dispatch 後に X 自動告知するための `schedule-hub:x.post_blog_announcement` action:

```typescript
// schedule-hub/index.ts に追加
case 'x.post_blog_announcement': {
  const { title, devto_url, qiita_url, tags } = body;
  const tagStr = (tags as string[]).slice(0, 3).map(t => `#${t}`).join(' ');
  const text = `📝 新記事: ${title}\n\n${devto_url || qiita_url}\n\n${tagStr} #BuildInPublic`;
  // post-x-update EF を呼び出し
  return callPostX(text);
}
```

→ VSCode版 cross-instance-pr: `docs/cross-instance-prs/20260425_x_blog_announce_ef.md`
