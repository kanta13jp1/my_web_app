# Cross-Instance PR: VSCode 作業の移譲 → PS#2

**作成**: VSCode版 S4 / 2026-04-25 (rev2: Flutter タスク追加)
**宛先**: PS版#2 (T-1 dispatch 空き時間に実施)
**優先度**: high (LP差別化) / medium (その他)
**期限**: 2026-05-07 (Google I/O 前)

---

## 背景

VSCode版の pending タスクを PS#2 に移譲。
`dart format` + `flutter analyze` は PS インスタンスでも実行可能。
T-1 dispatch (次回 May 1) が空いている間に対応をお願いします。
作業は `C:/Users/kanta/GitHub/my_web_app_ps` worktree (`instance-ps2`) で実施。

---

## タスク 0: LP「vs Notion」差別化強化 (🔴 HIGH / 2026-05-10 期限)

**元依頼**: `20260425_notion34_differentiation_lp.md` (PS#4 S40 発行)

**対象ファイル**: `lib/pages/landing_page.dart`

**変更内容**:

1. **「vs Notion」差別化セクション強化** — Notion がやれないことを明示

   ```text
   自分株式会社 vs Notion 比較表:
   - 「昨日の自分」KPI  vs  チーム向けナレッジ管理
   - CEO感 (意思決定OS)  vs  コラボツール
   - 資産/負債バランスシート  vs  プロジェクト管理
   - IPO/ウェルビーイング目標  vs  ゴール設定なし
   ```
   追加メッセージ案:
   > Notion があなたのチームを助けるなら、自分株式会社はあなた自身の「CEO」を育てます。

2. **LP FAQ 追加** — 「Notion / Slack 使ってるけど？」

   ```text
   Q: すでに Notion + Slack を使っています。なぜ自分株式会社が必要ですか？
   A: Notion はチームのナレッジを整理します。Slack はチームとのコミュニケーション。
      しかし「あなた自身の意思決定」「昨日の自分との比較」「人生のバランスシート」
      を管理するツールは存在しません。自分株式会社はその空白を埋めます。
   ```

3. **LP ヒーロー文言微調整** (optional)
   「NotionでもSlackでもない、あなた自身のCEOオフィス。」

**必須**: DESIGN.md トークン適用 / `dart format` / `flutter analyze 0`

---

## タスク 00: ShareToXButton widget (Flutter / Phase 2)

**元依頼**: `project_20260425_win132_part15.md` (Win#132 part 15 VSCode handoff)

`core-hub:page.share_generate` EF action (Phase 1 完了) を呼び出す Flutter widget。

**新規ファイル**: `lib/widgets/share_to_x_button.dart`

```dart
class ShareToXButton extends StatefulWidget {
  const ShareToXButton({super.key, required this.pagePath});
  final String pagePath;
  @override
  State<ShareToXButton> createState() => _ShareToXButtonState();
}

class _ShareToXButtonState extends State<ShareToXButton> {
  bool _loading = false;

  Future<void> _share() async {
    setState(() => _loading = true);
    try {
      // core-hub:page.share_generate を呼ぶ (EF action)
      // レスポンスの tweet_text + image_url を X シェアリンクに組み込む
      // https://twitter.com/intent/tweet?text=...&url=...
      final uri = Uri.parse(
        'https://twitter.com/intent/tweet'
        '?text=${Uri.encodeComponent("自分株式会社でシェア")}',
      );
      // TODO: launchUrl(uri) — url_launcher パッケージ使用
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: _loading
          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.share),
      tooltip: 'X でシェア',
      onPressed: _loading ? null : _share,
    );
  }
}
```

EF 呼び出し詳細: `core-hub` POST `{"action":"page.share_generate","page_path":"<pagePath>"}`

**対象ページ** (Phase 2 は AI大学ページのみ): `lib/pages/ai_university_page.dart` の AppBar に追加

**必須**: DESIGN.md トークン / `dart format` / `flutter analyze 0`

---

## タスク 1: post-x-with-media.yml 動作確認 (GHA workflow_dispatch)

**目的**: VSCode S4 で実装した `x.post_with_media` EF action + GHA workflow が正常動作するか確認。

**手順**:
```bash
# GitHub Actions の workflow_dispatch で dry_run=true を実行
gh workflow run post-x-with-media.yml \
  --field dry_run=true \
  --field "text=🧪 テスト投稿 (dry_run) — 実際には送信されません"

# 実行結果確認
gh run list --workflow=post-x-with-media.yml --limit 3
gh run view <run_id> --log
```

**期待結果**: `"posted": false, "dryRun": true` で成功ログが出ること。

**確認観点**:
- [ ] schedule-hub EF が `x.post_with_media` action を受け取れる
- [ ] `dryRun=true` 時に x_post テーブルに `status=dry_run` レコードが挿入される
- [ ] workflow が exit 0 で完了する

---

## タスク 2: X API 認証情報の Supabase secrets 確認

**目的**: `x.post_with_media` の本番投稿に必要な secrets が揃っているか確認。

**手順** (Supabase CLI で確認):
```bash
cd C:/Users/kanta/GitHub/my_web_app_ps2  # PS#2 worktree
supabase secrets list 2>&1 | grep -E "X_API|X_ACCESS"
```

**必要な secrets** (全4つ):
- `X_API_KEY`
- `X_API_SECRET`
- `X_ACCESS_TOKEN`
- `X_ACCESS_TOKEN_SECRET`

**不足していた場合**: Issue を立てて VSCode版に報告。Supabase Dashboard → Project Settings → Edge Functions → Secrets で設定が必要。

---

## タスク 3: LP FAQ 差別化テキスト — SQL seed migration

**目的**: `20260425_notion34_differentiation_lp.md` で依頼されている Notion 対抗 FAQ の
テキストを SQL seed として事前準備 (Flutter LP 実装は VSCode 継続)。

**対象テーブル**: `faq_items` (存在する場合) or `docs/LP_FAQ_DIFFERENTIATION.md` 更新

まず存在確認:
```bash
cd C:/Users/kanta/GitHub/my_web_app_ps2
grep -r "faq" supabase/migrations/ | grep CREATE | head -5
```

`faq_items` テーブルがあれば:
```sql
-- supabase/migrations/20260425195000_seed_faq_notion_counter.sql
INSERT INTO faq_items (question, answer, category, sort_order)
VALUES (
  'すでに Notion + Slack を使っています。なぜ自分株式会社が必要ですか？',
  'Notion はチームのナレッジを整理します。Slack はチームとのコミュニケーション。しかし「あなた自身の意思決定」「昨日の自分との比較」「人生のバランスシート」を管理するツールは存在しません。自分株式会社はその空白を埋めます。',
  'comparison',
  10
)
ON CONFLICT DO NOTHING;
```

テーブルが存在しない場合は `docs/LP_FAQ_DIFFERENTIATION.md` に FAQ テキストを追記だけでOK。

---

## タスク 4: ShareToXButton Phase 2 バックエンド確認

**目的**: VSCode が ShareToXButton Flutter widget を実装する前に、
`core-hub:page.share_generate` EF action が正常動作するか確認。

```bash
# EF action のスモークテスト (dry_run)
curl -X POST "$SUPABASE_DIGEST_URL" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $SUPABASE_SERVICE_KEY" \
  -d '{"action":"page.share_generate","page_path":"/","dry_run":true}'
```

**期待**: `{"success":true,"cached":false,"tweet_text":"...", ...}` が返ること。

失敗する場合は Issue を作成して VSCode / Win版に報告。

---

## 完了後の報告

各タスク完了後に `docs/cross-instance-prs/20260425_vscode_to_ps2_backend_assist.md` の
チェックリストを更新してから push してください。

*VSCode版 S4 2026-04-25 発行 / PS#2 対応後に DONE マーク*
