---
title: "Flutter Web でギターSNSギャラリーを Supabase Edge Function × share_plus で実装した話"
tags: Flutter,Supabase,個人開発,buildinpublic,ギター
published: true
---

# ブログ下書き 2026-04-06 — 2026-04-06-public-guitar-gallery

## タイトル案
1. Flutter WebでギターSNSギャラリーを作った話 — 既存Edge Functionを使い倒す実装パターン
2. 登録者4人でもコミュニティ機能を先に作る理由：公開録音ギャラリーで「見せる場所」を設計した
3. Supabase Edge Functionの上限94をキープしながら新機能を追加する「アクション拡張」パターン

## 投稿先候補
- [x] Zenn
- [x] Qiita
- [ ] note
- [ ] はてなブログ
- [ ] X Article

## 本文下書き (約2000字)

### はじめに

自分株式会社の現在の登録者数は4人です。

「それでも公開ギャラリーを作るの？」と思われるかもしれません。でも私はこれが正しいタイミングだと考えています。ユーザーが増えてから「公開・シェアできる場所」を作っても遅い。**公開できる場所が最初からあることで、最初のユーザーが「自分のコンテンツが見られる」と体感できる**からです。

今回は、Supabase Edge Functionの94デプロイ上限を守りながら、既存の `guitar-recording-studio` 関数に `public_gallery` アクションを追加して公開ギターギャラリーを実装した話をします。

---

### 背景：なぜギャラリーか

自分株式会社のメイン機能のひとつが「ギター録音スタジオ」です。ブラウザのWeb Audio API + MediaRecorder APIを使ってマイクでギター演奏を録音し、WAV/WebMで保存できます。

録音した音声は `is_public = true` に設定すると公開URLが生成されます。でも今まで「公開されても、それを誰かが発見できる場所がない」状態でした。

公開ギャラリーがあれば：
- **ユーザーは自分の録音を世界に見せられる**（シェアのモチベーション）
- **訪問者が録音を聴いて興味を持ち、登録する**（バイラル流入）
- **SEOコンテンツになる**（dailyで更新されるページ）

---

### 実装の核心：既存Edge Functionへのアクション追加

自分株式会社のSupabase Edge Functionは現在93個デプロイ済みで、上限は94です（Supabase Freeプランの制約）。新しいFunctionを追加できません。

そこで既存の `guitar-recording-studio` Functionに `public_gallery` アクションを追加しました：

```typescript
// 追加したアクション
case "public_gallery":
  return jsonResponse(
    await listPublicRecordings(auth.adminClient, url),
  );
```

```typescript
async function listPublicRecordings(
  adminClient: SupabaseClient,
  url: URL,
) {
  const limit = Math.min(parseInt(url.searchParams.get("limit") ?? "20", 10), 50);
  const offset = parseInt(url.searchParams.get("offset") ?? "0", 10);
  const sortBy = url.searchParams.get("sortBy") ?? "created_at";
  const validSorts = ["created_at", "likes", "plays"];
  const orderColumn = validSorts.includes(sortBy) ? sortBy : "created_at";

  const { data, error, count } = await adminClient
    .from("guitar_recordings")
    .select("*", { count: "exact" })
    .eq("is_public", true)
    .order(orderColumn, { ascending: false })
    .range(offset, offset + limit - 1);

  if (error) throw error;

  return {
    success: true,
    recordings: ((data ?? []) as GuitarRecordingRow[]).map(mapRecordingRow),
    total: count ?? 0,
    offset,
    limit,
  };
}
```

ポイントは3つ：

1. **sortBy バリデーション**：`validSorts` でホワイトリスト検証してSQLインジェクションを防ぐ
2. **件数上限**：最大50件にキャップしてSupabaseのRow Limitを節約
3. **count: "exact"**：ページネーション用の合計件数を一度に取得

---

### Flutter側：ダークテーマのギャラリーUI

```dart
class PublicGuitarGalleryPage extends StatefulWidget {
  const PublicGuitarGalleryPage({super.key});
  // ...
}
```

カード1枚のデザイン要件：
- タイトル、録音日
- プリセット（acoustic_fingerpicking等）、BPM、チューニング、タグ
- いいね数・再生数の表示
- いいねボタン（未ログインでも押せる）
- 「再生」ボタンでギタースタジオの共有ビューへ遷移

ソートは「新着順 / いいね順 / 再生数順」をPopupMenuで切り替えられます。

---

### ランディングページへの導線追加

```dart
GestureDetector(
  onTap: () =>
      Navigator.of(context).pushNamed('/public-guitar-gallery'),
  child: Container(
    // ギャラリーリンクカード
    child: const Row(
      children: [
        Icon(Icons.library_music_outlined, color: Color(0xFFFF6B35)),
        SizedBox(width: 8),
        Text('公開ギャラリーで録音を聴く →'),
      ],
    ),
  ),
),
```

LPのギタースタジオバナーの直下にギャラリーリンクを配置。訪問者が「録音を聴く」→「自分もやりたい」と思えるフローを設計しました。

---

### 詰まったポイント

**withOpacity vs withValues**

Flutter 3.x では `Color.withOpacity()` が deprecated になっています。代わりに：

```dart
// 旧: deprecated
color: const Color(0xFFFF6B35).withOpacity(0.2),

// 新: recommended
color: const Color(0xFFFF6B35).withValues(alpha: 0.2),
```

`flutter analyze` でこれを検出できるので、常に0件を維持する運用が重要です。

---

### まとめ

- **Quota制約の中での機能追加**：既存Functionへのアクション追加で新規デプロイなしに機能拡張
- **バイラル設計**：登録者が少なくても「見せる場所」を先に作ることで成長の種を植える
- **SEO**：`/public-guitar-gallery` を sitemap.xml に追加。毎日更新されるコンテンツページとして検索エンジンに認識させる

登録者4人の段階で「コミュニティ機能」を作るのは過剰に見えますが、**公開される場所があることが最初のユーザーの「シェアしたい」という動機を生む**と私は信じています。

---

URL: https://my-web-app-b67f4.web.app/
公開ギャラリー: https://my-web-app-b67f4.web.app/#/public-guitar-gallery
#FlutterWeb #Supabase #buildinpublic #guitar
