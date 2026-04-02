# ブログ下書き 2026-04-01

## タイトル案

1. 「FlutterとSupabase Edge Functionsで3競合SaaSを同時に攻める — AIワークフロー・SNSスケジューラー・ビデオ会議を1日で実装した話」
2. 「Zapier / Zoom / Hootsuite 競合をFlutter Webで手作りしてみた — 215 Edge Functions体制への道」
3. 「自分株式会社215 Edge Functions達成 — ワークフロー自動化・SNS投稿管理・ビデオ会議を自前実装した理由」

## 投稿先候補

- [x] Zenn (技術詳細)
- [x] Qiita (実装解説)
- [ ] note (エッセイ)
- [ ] dev.to (英語版)
- [ ] Hashnode

## 本文下書き (1800字)

### はじめに

「自分株式会社」は21の競合SaaSを1つに統合することを目指しているフルスタックWebアプリです。

今日は一気に3つの大型機能を実装しました:

- **AIワークフロー自動化** (Zapier / Power Automate 競合)
- **SNS投稿スケジューラー** (Hootsuite / Buffer 競合)
- **ビデオ会議管理** (Zoom / Google Meet 競合)

そしてバックエンドには5つの新しいEdge Functionを追加し、合計215本体制になりました。

### 実装方法

#### 1. AIワークフロー自動化ページ

```dart
// TabController で3タブ構成
class _WorkflowAutomationPageState extends State<WorkflowAutomationPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    _tabController = TabController(length: 3, vsync: this);
    _fetchData();
  }

  Future<void> _fetchData() async {
    final res = await _supabase.functions.invoke(
      'ai-workflow-automation',
      body: {'action': 'list'},
    );
    // workflows / templates / stats を一度に取得
  }
}
```

Edge Functionからワークフロー一覧・テンプレート・統計を一度に取得するのがポイントです。
フロントエンドは「表示する」だけに集中し、ロジックはすべてバックエンドに。

#### 2. SNS投稿スケジューラー

```dart
// プラットフォーム別カラーとアイコン
Color _platformColor(String? platform) {
  switch (platform) {
    case 'x': return Colors.black;
    case 'linkedin': return const Color(0xFF0077B5);
    case 'instagram': return const Color(0xFFE1306C);
    case 'facebook': return const Color(0xFF1877F2);
    default: return Colors.grey;
  }
}
```

X・LinkedIn・Instagram・Facebookの4プラットフォームに対応。
投稿内容・プラットフォーム選択のダイアログからワンタップで下書き保存できます。

#### 3. ビデオ会議管理

```dart
// 会議タイプ別アイコン
IconData _meetingTypeIcon(String? type) {
  switch (type) {
    case 'video': return Icons.videocam;
    case 'audio': return Icons.mic;
    case 'webinar': return Icons.cast;
    case 'screen_share': return Icons.screen_share;
    default: return Icons.meeting_room;
  }
}
```

AI議事録機能がミソで、`video-meeting-manager` Edge FunctionがGemini APIを呼び出して
会議の要約とアクションアイテムを自動抽出します。

#### 4. 新規Edge Functions (210→215)

| Function | 競合 | 機能 |
|---|---|---|
| bookmark-sync | Pocket/Instapaper | タグ付きブックマーク同期 |
| note-sharing-enhanced | Notion Share | パスワード保護・期限付き共有 |
| focus-timer | Forest/Focusmate | ポモドーロ + ストリーク追跡 |
| task-dependency | Asana | タスク依存グラフ管理 |
| ai-writing-assistant | Grammarly/Notion AI | 文章改善・要約・翻訳 |

`focus-timer` のストリーク計算ロジックは純粋なTypeScriptで実装:

```typescript
function _calculateStreak(sessions: Array<{...}>): number {
  const dates = sessions
    .filter((s) => s.status === "completed")
    .map((s) => new Date(s.started_at!).toDateString());
  const unique = [...new Set(dates)];
  let streak = 0;
  const today = new Date();
  for (let i = 0; i < 30; i++) {
    const d = new Date(today);
    d.setDate(today.getDate() - i);
    if (unique.includes(d.toDateString())) streak++;
    else if (i > 0) break;
  }
  return streak;
}
```

### 詰まったポイント

**並列gitコミット競合**

4つの開発インスタンス (VSCode/Web/Windows/PowerShell) が同時に動いているため、
`git merge origin/main` で `edge_function_summary_card.dart` がコンフリクト。
`git checkout --theirs` で解決してから新しい変更を追記する手順が確立しました。

**EdgeFunctionSummaryCard の同期**

supabase/functions/ が215本になっても、FlutterのUIカードが追いついていないと
管理者が全体像を把握できません。今回は30本分まとめて追記しました。

### まとめ

「自分株式会社」は今日で **215 Edge Functions** 体制になりました。

- Zapier相当のワークフロー自動化
- Hootsuite相当のSNSスケジューラー
- Zoom相当のビデオ会議

これらを1つのSupabaseプロジェクトで管理し、Flutter Webから呼び出せる状態です。

次のターゲットは220 Edge Functionsと、実際のユーザーへの機能開放です。

---
URL: https://my-web-app-b67f4.web.app/
#FlutterWeb #Supabase #buildinpublic #EdgeFunctions
