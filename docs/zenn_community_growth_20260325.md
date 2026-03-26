---
title: "登録者2人から始めるユーザー獲得戦略：LP全面刷新・価格比較・コミュニティ機能をFlutter+Supabaseで実装した話"
emoji: "📈"
type: "tech"
topics: ["flutter", "supabase", "個人開発", "グロースハック", "ランディングページ"]
published: true
---

## はじめに

「自分株式会社」というAI統合プラットフォームを個人開発しています。Notion・Evernote・MoneyForward・Slack・X など**13の競合製品を凌駕する**という無謀な目標を掲げ、**現在の登録者数は2人**という状態から出発しています。

前回の記事（[FlutterとSupabase Edge Functionsで、13の競合を打倒する「本物の」グロースダッシュボードを作った話](https://zenn.dev)）では、バックエンド移行とデータ駆動ダッシュボードについて書きました。今回は「いかにして新規ユーザーを獲得するか」という**ユーザー獲得側の実装**を中心に解説します。

## 実装した施策の全体像

今回は以下の4つを実装しました。

1. **LPヒーローセクション全面刷新** — 競合比較訴求コピーと二段階CTA
2. **価格比較セクション** — 「他社は有料、自分株式会社は完全無料」の可視化
3. **メールウェイトリスト + 機能リクエストフォーム** — 未登録ユーザーのメール捕捉
4. **機能リクエスト公開ページ** — Supabase anon RLSを活用したコミュニティ投票機能

---

## 1. LPヒーローセクション全面刷新

### Before

以前のヒーローセクションは「AIが今日の最優先タスクを整理するアプリ」という汎用的な訴求でした。

### After

```dart
// lib/pages/landing_page.dart (抜粋)
Widget _buildHeroSection() {
  return Column(
    children: [
      // 競合比較キャッチコピー
      Text(
        'Notion・Evernote・MoneyForward\nSlack を1つに。完全無料。',
        style: TextStyle(
          fontFamily: 'Noto Serif JP',
          fontSize: 42,
          fontWeight: FontWeight.w700,
        ),
      ),
      // 実装済み件数バッジ（DBリアルタイム取得）
      _AchievementCountBadge(count: _achievementCount),
      // 主要CTA: 登録誘導
      FilledButton.icon(
        onPressed: _scrollToAuthSection,
        icon: const Icon(Icons.rocket_launch),
        label: const Text('無料で始める（30秒）'),
      ),
      // セカンダリCTA: 登録不要のお試し
      OutlinedButton(
        onPressed: _scrollToTrialSection,
        child: const Text('登録なしで1件試す'),
      ),
    ],
  );
}
```

**ポイント:** 「競合より優れている」という主張は言葉ではなく、後続の価格比較セクションとコンテキストで証明します。ヒーローは「来た人を離脱させない」ための最初の判断材料に徹しています。

---

## 2. 価格比較セクション

価格比較は**コンバージョン率に最も直結するセクション**です。競合他社の月額料金と「自分株式会社 = 完全無料」を並べることで、判断コストを下げます。

```dart
// lib/pages/landing_page.dart (抜粋)
class _CompetitorRow {
  final String name;
  final String price;
  final String note;
  final bool isSelf;

  const _CompetitorRow({
    required this.name,
    required this.price,
    required this.note,
    this.isSelf = false,
  });
}

Widget _buildPricingComparisonSection() {
  final rows = [
    const _CompetitorRow(name: 'Notion',       price: '¥1,100〜/月', note: 'Plus プラン'),
    const _CompetitorRow(name: 'Evernote',     price: '¥600〜/月',   note: 'Personal'),
    const _CompetitorRow(name: 'MoneyForward', price: '¥500〜/月',   note: 'プレミアム'),
    const _CompetitorRow(name: 'Slack',        price: '¥925〜/月',   note: 'Pro プラン'),
    const _CompetitorRow(name: 'Chatwork',     price: '¥700〜/月',   note: 'ビジネス'),
    const _CompetitorRow(name: 'ジョブカン',    price: '¥200〜/月/人', note: '勤怠のみ'),
    const _CompetitorRow(
      name: '自分株式会社',
      price: '完全無料',
      note: '全機能・制限なし',
      isSelf: true,
    ),
  ];
  // ...
}
```

これらを縦並びの `Card` で比較表示し、最後行の「自分株式会社」だけ `indigo` 背景にして視覚的な差別化を図っています。

---

## 3. メールウェイトリスト + 機能リクエストフォーム

### Supabase テーブル設計

登録前ユーザーのメールを取得するためのテーブルと、コミュニティからの要望を受け取るテーブルを作成しました。

```sql
-- newsletter_waitlist: anon が INSERT 可能
create table public.newsletter_waitlist (
  id           bigserial primary key,
  email        text not null,
  source       text default 'landing_page',
  note         text,
  created_at   timestamptz default now()
);

alter table public.newsletter_waitlist enable row level security;

-- anon ユーザーがメールを登録できる
create policy "anon can insert waitlist"
  on public.newsletter_waitlist for insert
  to anon, authenticated
  with check (true);

-- 管理者のみ参照可能
create policy "service_role can select waitlist"
  on public.newsletter_waitlist for select
  to service_role
  using (true);
```

```sql
-- feature_requests: anon が INSERT / SELECT 可能
create table public.feature_requests (
  id           bigserial primary key,
  user_id      uuid references auth.users(id),
  email        text,
  title        text not null,
  description  text,
  votes        int default 0,
  status       text default 'open',
  created_at   timestamptz default now()
);

alter table public.feature_requests enable row level security;

create policy "anyone can insert feature_requests"
  on public.feature_requests for insert
  to anon, authenticated
  with check (true);

-- status = 'open' のリクエストは誰でも閲覧可能
create policy "open requests are public"
  on public.feature_requests for select
  to anon, authenticated
  using (status = 'open');

create index idx_feature_requests_status on public.feature_requests(status);
create index idx_feature_requests_votes  on public.feature_requests(votes desc);
```

### Flutter 側の実装

```dart
// lib/pages/landing_page.dart (抜粋)
Future<void> _submitWaitlist() async {
  final email = _waitlistEmailController.text.trim();
  if (email.isEmpty) return;
  setState(() => _waitlistSubmitted = true);

  await supabase.from('newsletter_waitlist').insert({
    'email': email,
    'source': 'landing_page',
  });
}

Future<void> _submitFeatureRequest() async {
  final title = _featureRequestTitleController.text.trim();
  if (title.isEmpty) return;
  setState(() => _featureRequestSubmitted = true);

  await supabase.from('feature_requests').insert({
    'title': title,
    'status': 'open',
  });
}
```

`supabase.auth.currentUser` が null（未登録ユーザー）でも RLS で anon INSERT が通るため、登録前のユーザーからも情報を取得できます。

---

## 4. 機能リクエスト公開ページ (`/feature-requests`)

コミュニティ主導の開発優先度決定のため、**誰でも投稿・投票できる公開ページ**を実装しました。Supabase の anon RLS を活用することで、認証なしで読み書きできます。

```dart
// lib/pages/feature_requests_page.dart (抜粋)
class _FeatureRequestsPageState extends State<FeatureRequestsPage> {
  List<Map<String, dynamic>> _requests = [];
  final Set<int> _votedIds = {};  // セッション内重複投票防止

  Future<void> _load() async {
    final data = await supabase
        .from('feature_requests')
        .select()
        .eq('status', 'open')
        .order('votes', ascending: false)
        .limit(50);
    setState(() => _requests = List<Map<String, dynamic>>.from(data));
  }

  Future<void> _upvote(int id, int currentVotes) async {
    if (_votedIds.contains(id)) return;  // 二重投票防止
    setState(() => _votedIds.add(id));

    await supabase
        .from('feature_requests')
        .update({'votes': currentVotes + 1})
        .eq('id', id);
    await _load();
  }
}
```

### 上位3件のハイライト表示

```dart
Widget _buildRequestCard(Map<String, dynamic> req, int rank) {
  final isTop3 = rank < 3;
  return Card(
    color: isTop3 ? const Color(0xFFFFF8E1) : null,  // 金色背景
    child: ListTile(
      leading: CircleAvatar(
        backgroundColor: isTop3 ? Colors.amber : Colors.grey[200],
        child: Text('${req['votes'] ?? 0}'),
      ),
      title: Text(req['title'] as String),
      trailing: IconButton(
        icon: Icon(
          _votedIds.contains(req['id']) ? Icons.thumb_up : Icons.thumb_up_outlined,
        ),
        onPressed: () => _upvote(req['id'] as int, (req['votes'] as int?) ?? 0),
      ),
    ),
  );
}
```

---

## Supabase RLS と anon ロールの使い分け

今回の実装で重要だったのは **anon ロールへの最小権限付与**です。

| テーブル | anon INSERT | anon SELECT | 備考 |
|---|---|---|---|
| `newsletter_waitlist` | ✅ | ❌ | メールは管理者のみ閲覧 |
| `feature_requests` | ✅ | status='open' のみ | 公開リクエストのみ表示 |

`anon` ロールへの SELECT を制限することで、メールアドレスの不正取得を防ぎつつ、登録前ユーザーからも情報収集できます。

---

## flutter analyze を常に0に保つ

今回も `flutter analyze` は **0件**を維持しました。

主なポイント：

- `_CompetitorRow` クラスを `_LandingPageState` の外（ファイル末尾）で定義し、`const` コンストラクタで使用
- TextEditingController は必ず `dispose()` でクリーンアップ
- State の boolean フラグは `bool _waitlistSubmitted = false;` のように明示的に初期化
- 非同期メソッド内の `mounted` チェックを忘れずに実施

---

## まとめ

今回の施策をまとめると：

| 施策 | 目的 | 期待効果 |
|---|---|---|
| LPヒーロー刷新 | 競合比較訴求で初期離脱を減らす | 直帰率改善 |
| 価格比較セクション | 「完全無料」の差別化を可視化 | CVR向上 |
| メールウェイトリスト | 未登録ユーザーのメール捕捉 | 後続フォローアップ |
| 機能リクエストページ | コミュニティ主導の優先度決定 | エンゲージメント向上 |

登録者2人の段階でこれだけの施策を打つのは「過剰では？」と思われるかもしれませんが、**土台を早く整備するほどスケール時のコスト増分が減る**という考えのもと、構造から設計しています。

次回は、ユーザーが増えた後の**リテンション施策（オンボーディング改善・ウェルカムメール自動送信・リファラル報酬）**について書く予定です。

## リポジトリ

`flutter analyze` 0件・deno lint 0件を保ちながら毎日開発しています。興味があればスターをいただけると励みになります！

- GitHub: (private / working toward open-source)
- App URL: https://my-web-app-b67f4.web.app/
- 機能リクエスト: https://my-web-app-b67f4.web.app/feature-requests
