# ブログ下書き 2026-03-30 — チームワークスペース実装

## タイトル案

1. FlutterとSupabaseでNotionライクなチームワークスペースを実装した話
2. 招待コード方式のチーム共有機能をSupabase RLSで安全に作る方法
3. B2Bエンタープライズ対応の第一歩：チームワークスペース機能の設計と実装

## 投稿先候補

- [x] Zenn (技術実装詳細)
- [x] Qiita (Supabase RLS実践)
- [ ] note (エッセイ風)
- [ ] dev.to (英語)
- [ ] Hashnode

## 本文下書き

### はじめに

「自分株式会社」を個人向けのAI統合ライフマネジメントアプリとして構築してきましたが、
B2B・チームでの導入を見据えて、チームワークスペース機能を実装しました。

Notionのチームワークスペースに相当する機能を、FlutterWebとSupabaseで
**RLS（行レベルセキュリティ）を活用して**安全に構築した実装を解説します。

### 設計方針

チームワークスペースに必要なのは以下の3テーブル:

```
teams               -- チーム本体（名前・説明・招待コード）
team_memberships    -- チームメンバーの所属管理
team_shared_notes   -- チームへの共有ノート
```

#### 招待コード方式を選んだ理由

メール招待はResend APIが必要で実装が複雑。
招待コード（8文字ランダム英数字）方式なら:
- オーナーがコードをSlackやLINEで送れる
- メール設定不要で即導入可能
- スパム招待リスクが低い

### Supabase RLS 設計

```sql
-- チームはオーナーまたはメンバーだけが閲覧可能
CREATE POLICY "teams_select" ON teams FOR SELECT
  USING (
    owner_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM team_memberships tm
      WHERE tm.team_id = teams.id AND tm.user_id = auth.uid()
    )
  );
```

ポイントは `EXISTS` サブクエリで **team_memberships を結合** することです。
これにより「そのチームのメンバー」だけがチーム情報を閲覧できます。

共有ノートのRLSも同様に:

```sql
CREATE POLICY "team_shared_notes_select" ON team_shared_notes FOR SELECT
  USING (
    shared_by = auth.uid() OR
    EXISTS (
      SELECT 1 FROM team_memberships tm
      WHERE tm.team_id = team_shared_notes.team_id AND tm.user_id = auth.uid()
    ) OR
    EXISTS (
      SELECT 1 FROM teams t
      WHERE t.id = team_shared_notes.team_id AND t.owner_id = auth.uid()
    )
  );
```

### Flutter 実装

`TeamWorkspacePage` は `TabController` で「自分のチーム」「参加中」の2タブ構成。

招待コードのコピー機能:

```dart
InkWell(
  onTap: () {
    Clipboard.setData(ClipboardData(text: inviteCode));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('招待コードをコピーしました')),
    );
  },
  child: const Icon(Icons.copy, size: 16, color: Colors.grey),
),
```

### 詰まったポイント

**Supabase の `select('*, nested(*)')` の型推論**

```dart
// ❌ dynamic_calls エラー
final ownedIds = (owned as List).map((t) => t['id']).toSet();

// ✅ 明示的型変換
final ownedList = List<Map<String, dynamic>>.from(owned as List);
final ownedIds = ownedList.map((t) => t['id'] as String).toSet();
```

Dartの `flutter analyze` の `avoid_dynamic_calls` ルールに引っかかるため、
Supabaseのレスポンスは必ず `List<Map<String, dynamic>>` に変換してから使います。

### 比較ページSEO改善も同時実装

14社の競合比較ページ（`/vs-notion` 〜 `/vs-amazon`）に個別のOGPメタタグを追加。
index.html のSEOシェルスクリプトを拡張し、URLパスに応じて動的に
`og:title` / `og:description` を切り替えるようにしました。

```js
var vsMatch = path.match(/\/vs-([a-z0-9\-]+)$/);
if (vsMatch) {
  var competitor = vsMatch[1];
  var meta = competitorMeta[competitor];
  if (meta) {
    document.title = meta.title;
    setMeta('og:title', meta.title);
    setMeta('og:description', meta.desc);
    // ...
  }
}
```

### まとめ

- **チームワークスペース**: Supabase RLS + 招待コード方式で安全な共有基盤を構築
- **比較ページOGP**: 14社分の個別OGPをJSで動的切り替え
- **flutter analyze 0件維持**: `avoid_dynamic_calls` に注意してSupabaseレスポンスを型変換

---

URL: https://my-web-app-b67f4.web.app/team-workspace
#FlutterWeb #Supabase #buildinpublic #チームワーク #RLS
